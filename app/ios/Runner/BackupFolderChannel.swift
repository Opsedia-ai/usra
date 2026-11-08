import Flutter
import UIKit
import UniformTypeIdentifiers

/// The folder automatic backups go to (lib/core/backup/backup_folder.dart):
/// the document picker, a security-scoped bookmark to keep access, and small
/// file steps inside it.
///
/// Errors carry a fixed code and no message: file and folder names stay out
/// of anything that could be logged.
final class BackupFolderChannel: NSObject, UIDocumentPickerDelegate {
  private static var shared: BackupFolderChannel?
  private var pending: FlutterResult?
  private let queue = DispatchQueue(label: "usra.backup-folder", qos: .utility)
  private static let chunk = 256 * 1024

  private enum Failure: Error {
    case missing, cantUse, failed, iCloud
  }

  static func register(messenger: FlutterBinaryMessenger) {
    let instance = BackupFolderChannel()
    shared = instance
    FlutterMethodChannel(name: "usra/backup_folder", binaryMessenger: messenger)
      .setMethodCallHandler(instance.handle)
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "pick":
      pick(result)
    case "protectedDataAvailable":
      result(UIApplication.shared.isProtectedDataAvailable)
    case "release":
      // A bookmark is only data: dropping it, in Dart, is all there is.
      result(nil)
    case "inspect":
      work(result) { try self.inspect(args) }
    case "write":
      work(result) {
        try self.write(args)
        return nil
      }
    case "verify":
      work(result) { try self.verify(args) }
    case "rename":
      work(result) {
        try self.rename(args)
        return nil
      }
    case "delete":
      work(result) {
        try self.delete(args)
        return nil
      }
    case "list":
      work(result) { try self.list(args) }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// Off the main thread: a copy can take a while, and a provider's folder
  /// can be slow even to list.
  private func work(_ result: @escaping FlutterResult, _ job: @escaping () throws -> Any?) {
    queue.async {
      do {
        let value = try job()
        DispatchQueue.main.async { result(value) }
      } catch {
        let code = BackupFolderChannel.code(of: error)
        DispatchQueue.main.async { result(FlutterError(code: code, message: nil, details: nil)) }
      }
    }
  }

  // MARK: - Picker

  private func pick(_ result: @escaping FlutterResult) {
    guard pending == nil, let root = SceneDelegate.current?.window?.rootViewController else {
      result(FlutterError(code: "cant_use", message: nil, details: nil))
      return
    }
    pending = result
    let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
    picker.delegate = self
    picker.allowsMultipleSelection = false
    var top = root
    while let presented = top.presentedViewController { top = presented }
    top.present(picker, animated: true)
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    pending?(nil)
    pending = nil
  }

  func documentPicker(
    _ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]
  ) {
    guard let result = pending else { return }
    pending = nil
    guard let url = urls.first else {
      result(nil)
      return
    }
    // Started here, while the picker's grant is certainly alive.
    let scoped = url.startAccessingSecurityScopedResource()
    work(result) {
      defer { if scoped { url.stopAccessingSecurityScopedResource() } }
      // The top of a Files location is this on disk, whichever location it
      // is, which means nothing to a person. Empty: Dart says it in words.
      let name = url.lastPathComponent == "File Provider Storage" ? "" : url.lastPathComponent
      let path = url.resolvingSymlinksInPath().path
      // Told to Dart, which refuses it (and tests that). Nothing is written
      // there, not even the small test file below.
      if BackupFolderChannel.isUbiquitous(url) {
        let refused: [String: Any] = ["id": "", "name": name, "path": path, "ubiquitous": true]
        return refused
      }
      do {
        try self.probe(url)
        let bookmark = try url.bookmarkData(
          options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
        // iOS can't tell On My iPhone from another Files provider, so
        // "onThisPhone" is left out: unknown.
        let picked: [String: Any] = [
          "id": bookmark.base64EncodedString(), "name": name, "path": path,
          "ubiquitous": false,
        ]
        return picked
      } catch {
        throw Failure.cantUse
      }
    }
  }

  /// Everything a backup will do, tried once with a small file: some places
  /// can't read back, rename or delete, and a safe write needs all three.
  private func probe(_ folder: URL) throws {
    let token = UUID().uuidString
    let first = folder.appendingPathComponent("usra-check-\(token).partial")
    let second = folder.appendingPathComponent("usra-check-\(token).tmp")
    try coordinate(.forReplacing, first) { url in
      try Data([0]).write(to: url, options: .atomic)
    }
    defer {
      for url in [first, second] { try? FileManager.default.removeItem(at: url) }
    }
    try move(first, to: second)
    guard try Data(contentsOf: second) == Data([0]) else { throw Failure.failed }
    try coordinate(.forDeleting, second) { url in
      try FileManager.default.removeItem(at: url)
    }
  }

  // MARK: - Inside the folder

  /// Runs [job] with access to the bookmarked folder. Fails with `missing`
  /// when it can't be found, and with `locked` when the phone is locked.
  private func withFolder<T>(
    _ args: [String: Any], _ job: (URL, Bool) throws -> T
  ) throws -> T {
    guard let id = args["id"] as? String, let bookmark = Data(base64Encoded: id) else {
      throw Failure.missing
    }
    var stale = false
    let folder: URL
    do {
      folder = try URL(
        resolvingBookmarkData: bookmark, options: [], relativeTo: nil,
        bookmarkDataIsStale: &stale)
    } catch {
      throw Failure.missing
    }
    let scoped = folder.startAccessingSecurityScopedResource()
    defer { if scoped { folder.stopAccessingSecurityScopedResource() } }
    var isFolder: ObjCBool = false
    guard FileManager.default.fileExists(atPath: folder.path, isDirectory: &isFolder),
      isFolder.boolValue
    else {
      throw Failure.missing
    }
    return try job(folder, stale)
  }

  private func inspect(_ args: [String: Any]) throws -> Any? {
    try withFolder(args) { folder, stale in
      var status: [String: Any] = [
        "path": folder.resolvingSymlinksInPath().path,
        "ubiquitous": BackupFolderChannel.isUbiquitous(folder),
      ]
      if stale,
        let renewed = try? folder.bookmarkData(
          options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
      {
        status["renewedId"] = renewed.base64EncodedString()
      }
      return status
    }
  }

  private func write(_ args: [String: Any]) throws {
    guard let source = args["source"] as? String else { throw Failure.failed }
    let name = try BackupFolderChannel.fileName(args["name"])
    try withFolder(args) { folder, _ in
      // Checked here as well as before the backup was made, which can take
      // a while: nothing is written once the folder is in iCloud.
      try BackupFolderChannel.refuseICloud(folder)
      let target = folder.appendingPathComponent(name)
      try coordinate(.forReplacing, target) { url in
        let manager = FileManager.default
        if manager.fileExists(atPath: url.path) { try manager.removeItem(at: url) }
        try manager.copyItem(at: URL(fileURLWithPath: source), to: url)
        // Excluded from the start, not only once it has its real name.
        try BackupFolderChannel.excludeFromBackup(url)
        let handle = try FileHandle(forUpdating: url)
        defer { try? handle.close() }
        try handle.synchronize()
      }
    }
  }

  /// Reads the file back and compares every byte with the original: what the
  /// place really has, not what it was handed. Its size.
  private func verify(_ args: [String: Any]) throws -> Any? {
    guard let source = args["source"] as? String else { throw Failure.failed }
    let name = try BackupFolderChannel.fileName(args["name"])
    return try withFolder(args) { folder, _ in
      var total: Int64 = 0
      var coordination: NSError?
      var failure: Error?
      NSFileCoordinator().coordinate(
        readingItemAt: folder.appendingPathComponent(name), options: [], error: &coordination
      ) { actual in
        do {
          total = try BackupFolderChannel.compare(URL(fileURLWithPath: source), actual)
        } catch {
          failure = error
        }
      }
      if let error = coordination ?? failure { throw error }
      return total
    }
  }

  private static func compare(_ original: URL, _ landed: URL) throws -> Int64 {
    let left = try FileHandle(forReadingFrom: original)
    defer { try? left.close() }
    let right = try FileHandle(forReadingFrom: landed)
    defer { try? right.close() }
    var total: Int64 = 0
    while true {
      // Drained each time: these can be many large reads on a small phone.
      let done: Bool = try autoreleasepool {
        let a = try left.read(upToCount: chunk) ?? Data()
        let b = try right.read(upToCount: chunk) ?? Data()
        guard a == b else { throw Failure.failed }
        total += Int64(a.count)
        return a.isEmpty
      }
      if done { return total }
    }
  }

  private func rename(_ args: [String: Any]) throws {
    let from = try BackupFolderChannel.fileName(args["from"])
    let to = try BackupFolderChannel.fileName(args["to"])
    try withFolder(args) { folder, _ in
      try BackupFolderChannel.refuseICloud(folder)
      let target = folder.appendingPathComponent(to)
      try move(folder.appendingPathComponent(from), to: target)
      try BackupFolderChannel.excludeFromBackup(target)
    }
  }

  private func delete(_ args: [String: Any]) throws {
    let name = try BackupFolderChannel.fileName(args["name"])
    try withFolder(args) { folder, _ in
      let target = folder.appendingPathComponent(name)
      guard FileManager.default.fileExists(atPath: target.path) else { return }
      try coordinate(.forDeleting, target) { url in
        try FileManager.default.removeItem(at: url)
      }
    }
  }

  private func list(_ args: [String: Any]) throws -> Any? {
    try withFolder(args) { folder, _ in
      let items = try FileManager.default.contentsOfDirectory(
        at: folder, includingPropertiesForKeys: [.fileSizeKey], options: [])
      return items.map { item -> [String: Any?] in
        let size = (try? item.resourceValues(forKeys: [.fileSizeKey]))?.fileSize
        return ["name": item.lastPathComponent, "size": size]
      }
    }
  }

  // MARK: - File coordination, which other apps' folders expect

  private func coordinate(
    _ options: NSFileCoordinator.WritingOptions, _ url: URL, _ job: (URL) throws -> Void
  ) throws {
    var coordination: NSError?
    var failure: Error?
    NSFileCoordinator().coordinate(writingItemAt: url, options: options, error: &coordination) {
      actual in
      do { try job(actual) } catch { failure = error }
    }
    if let error = coordination ?? failure { throw error }
  }

  private func move(_ from: URL, to: URL) throws {
    var coordination: NSError?
    var failure: Error?
    NSFileCoordinator().coordinate(
      writingItemAt: from, options: .forMoving, writingItemAt: to, options: .forReplacing,
      error: &coordination
    ) { actualFrom, actualTo in
      do { try FileManager.default.moveItem(at: actualFrom, to: actualTo) } catch {
        failure = error
      }
    }
    if let error = coordination ?? failure { throw error }
  }

  // MARK: - Helpers

  /// iOS says so, for iCloud Drive and folders shared through it. Dart also
  /// checks the path (`isICloudPath`).
  private static func isUbiquitous(_ url: URL) -> Bool {
    if FileManager.default.isUbiquitousItem(at: url) { return true }
    return (try? url.resourceValues(forKeys: [.isUbiquitousItemKey]))?.isUbiquitousItem == true
  }

  private static func refuseICloud(_ folder: URL) throws {
    let path = folder.resolvingSymlinksInPath().path.lowercased()
    if isUbiquitous(folder) || path.contains("/mobile documents") {
      throw Failure.iCloud
    }
  }

  /// On My iPhone is part of the phone's iCloud device backup unless told
  /// otherwise, and no health backup goes to iCloud (5.1.3). A place without
  /// this setting isn't in that device backup; any other failure stops the
  /// run. Set again after the rename, in case a provider dropped it.
  private static func excludeFromBackup(_ file: URL) throws {
    var url = file
    url.removeAllCachedResourceValues()
    let current = try url.resourceValues(forKeys: [.isExcludedFromBackupKey])
    if current.isExcludedFromBackup == true { return }
    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    do {
      try url.setResourceValues(values)
    } catch let error as NSError
      where error.domain == NSCocoaErrorDomain && error.code == NSFeatureUnsupportedError
    {
      return
    }
  }

  /// Only ever a plain file name: nothing outside the folder.
  private static func fileName(_ value: Any?) throws -> String {
    guard let name = value as? String, !name.contains("/"), name != ".", name != ".." else {
      throw Failure.failed
    }
    return name
  }

  private static func code(of error: Error) -> String {
    if let failure = error as? Failure {
      switch failure {
      case .missing: return "missing"
      case .cantUse: return "cant_use"
      case .failed: return "failed"
      case .iCloud: return "icloud"
      }
    }
    let ns = error as NSError
    if ns.domain == NSCocoaErrorDomain {
      switch ns.code {
      case NSFileWriteOutOfSpaceError: return "no_space"
      case NSFileNoSuchFileError, NSFileReadNoSuchFileError: return "missing"
      default: break
      }
    }
    if ns.domain == NSPOSIXErrorDomain, ns.code == Int(ENOSPC) { return "no_space" }
    if let posix = ns.userInfo[NSUnderlyingErrorKey] as? NSError,
      posix.domain == NSPOSIXErrorDomain, posix.code == Int(ENOSPC)
    {
      return "no_space"
    }
    if !UIApplication.isProtectedDataAvailableOnMain { return "locked" }
    return "failed"
  }
}

extension UIApplication {
  /// `isProtectedDataAvailable` must be read on the main thread.
  fileprivate static var isProtectedDataAvailableOnMain: Bool {
    if Thread.isMainThread { return shared.isProtectedDataAvailable }
    return DispatchQueue.main.sync { shared.isProtectedDataAvailable }
  }
}
