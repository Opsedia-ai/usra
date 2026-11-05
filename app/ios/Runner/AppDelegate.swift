import Flutter
import MachO
import UIKit
import UserNotifications
import flutter_local_notifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Medicine reminders: show them while the app is open too, and let the
    // Taken / Snooze buttons run without opening the app.
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "UsraFiles") {
      registerFilesChannel(messenger: registrar.messenger())
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "UsraClock") {
      registerClockChannel(messenger: registrar.messenger())
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "UsraPrivacy") {
      registerPrivacyChannels(messenger: registrar.messenger())
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "UsraSecurity") {
      registerSecurityChannels(messenger: registrar.messenger())
    }
  }

  /// The recovery key on the pasteboard, and the jailbreak warning (see
  /// lib/core/security/).
  private func registerSecurityChannels(messenger: FlutterBinaryMessenger) {
    // Local only (never handed to the family's Mac or iPad through
    // Universal Clipboard), and iOS itself removes it after a minute if
    // it's still there.
    FlutterMethodChannel(name: "usra/clipboard", binaryMessenger: messenger)
      .setMethodCallHandler { call, result in
        guard call.method == "copySensitive", let text = call.arguments as? String else {
          result(FlutterMethodNotImplemented)
          return
        }
        UIPasteboard.general.setItems(
          [["public.utf8-plain-text": text]],
          options: [
            .localOnly: true,
            .expirationDate: Date().addingTimeInterval(60),
          ])
        result(nil)
      }
    FlutterMethodChannel(name: "usra/integrity", binaryMessenger: messenger)
      .setMethodCallHandler { call, result in
        guard call.method == "signs" else {
          result(FlutterMethodNotImplemented)
          return
        }
        result(AppDelegate.jailbreakSigns())
      }
  }

  /// Signs of a jailbroken phone, checked here only and never sent
  /// anywhere. Heuristics, not proof: Usra only warns.
  static func jailbreakSigns() -> [String] {
    #if targetEnvironment(simulator)
      return []
    #else
      var signs: [String] = []
      let paths = [
        "/Applications/Cydia.app", "/Applications/Sileo.app", "/Applications/Zebra.app",
        "/Library/MobileSubstrate/MobileSubstrate.dylib", "/usr/sbin/sshd", "/usr/bin/ssh",
        "/bin/bash", "/etc/apt", "/private/var/lib/apt/", "/var/jb", "/private/var/jb",
        "/var/binpack", "/usr/lib/libjailbreak.dylib",
      ]
      if paths.contains(where: { FileManager.default.fileExists(atPath: $0) }) {
        signs.append("files")
      }
      // Apps can't write outside their own folder unless the sandbox is broken.
      let probe = "/private/usra-check-\(UUID().uuidString)"
      if (try? "x".write(toFile: probe, atomically: false, encoding: .utf8)) != nil {
        try? FileManager.default.removeItem(atPath: probe)
        signs.append("sandbox")
      }
      // Tweak loaders injected into the app.
      let injected = ["MobileSubstrate", "substrate", "TweakInject", "libhooker", "ellekit", "SubstrateLoader"]
      for i in 0..<_dyld_image_count() {
        guard let name = _dyld_get_image_name(i) else { continue }
        let image = String(cString: name)
        if injected.contains(where: { image.localizedCaseInsensitiveContains($0) }) {
          signs.append("injected")
          break
        }
      }
      return signs
    #endif
  }

  /// The app lock measures time away with this: CLOCK_MONOTONIC on iOS keeps
  /// counting while the phone sleeps and can't be changed in Settings.
  private func registerClockChannel(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "usra/clock", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "elapsedRealtime" else {
        result(FlutterMethodNotImplemented)
        return
      }
      result(Int(clock_gettime_nsec_np(CLOCK_MONOTONIC) / 1_000_000))
    }
  }

  /// The app-switcher cover (SceneDelegate) and the text a hidden
  /// notification preview shows. Screenshots can't be blocked on iOS, so
  /// `setSecure` isn't handled.
  private func registerPrivacyChannels(messenger: FlutterBinaryMessenger) {
    FlutterMethodChannel(name: "usra/screen_privacy", binaryMessenger: messenger)
      .setMethodCallHandler { call, result in
        switch call.method {
        case "coverUntilReady":
          let on = call.arguments as? Bool ?? false
          SceneDelegate.current?.coverUntilReady = on
          if !on { SceneDelegate.current?.uncover() }
          result(nil)
        case "uncover":
          SceneDelegate.current?.uncover()
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    // The lock screen hides previews by default ("When Unlocked"); this
    // replaces "Notification" with generic reminder text there.
    FlutterMethodChannel(name: "usra/notification_privacy", binaryMessenger: messenger)
      .setMethodCallHandler { call, result in
        guard call.method == "setHiddenPreviewText", let text = call.arguments as? String else {
          result(FlutterMethodNotImplemented)
          return
        }
        let center = UNUserNotificationCenter.current()
        center.getNotificationCategories { categories in
          let replaced = categories.map {
            UNNotificationCategory(
              identifier: $0.identifier,
              actions: $0.actions,
              intentIdentifiers: $0.intentIdentifiers,
              hiddenPreviewsBodyPlaceholder: text,
              options: $0.options)
          }
          center.setNotificationCategories(Set(replaced))
          DispatchQueue.main.async { result(nil) }
        }
      }
  }

  /// Keeps private folders (insurance card photos) out of iCloud backup.
  private func registerFilesChannel(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "usra/files", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      if call.method == "protect" {
        AppDelegate.protect(call.arguments, result: result)
        return
      }
      guard call.method == "excludeFromBackup", let path = call.arguments as? String else {
        result(FlutterMethodNotImplemented)
        return
      }
      do {
        var url = URL(fileURLWithPath: path, isDirectory: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try url.setResourceValues(values)
        result(nil)
      } catch {
        result(FlutterError(code: "exclude_failed", message: error.localizedDescription, details: nil))
      }
    }
  }

  /// iOS Data Protection for a folder (lib/core/security/file_protection.dart):
  /// `complete` for photos, `untilFirstUnlock` for the database folder.
  /// New files in the folder inherit it; with `contents`, files already in
  /// it are set too. Off the main thread: a folder can hold many photos.
  private static func protect(_ arguments: Any?, result: @escaping FlutterResult) {
    guard let args = arguments as? [String: Any], let path = args["path"] as? String,
      let level = args["level"] as? String
    else {
      result(FlutterError(code: "bad_args", message: nil, details: nil))
      return
    }
    let type: FileProtectionType =
      level == "complete" ? .complete : .completeUntilFirstUserAuthentication
    let contents = args["contents"] as? Bool ?? true
    let skipFolders = args["skipFolders"] as? Bool ?? false
    DispatchQueue.global(qos: .utility).async {
      let manager = FileManager.default
      var failed = false
      do {
        try manager.setAttributes([.protectionKey: type], ofItemAtPath: path)
      } catch {
        failed = true
      }
      if contents, let items = manager.enumerator(atPath: path) {
        for case let item as String in items {
          if skipFolders, items.fileAttributes?[.type] as? FileAttributeType == .typeDirectory {
            items.skipDescendants()
            continue
          }
          let full = (path as NSString).appendingPathComponent(item)
          do {
            try manager.setAttributes([.protectionKey: type], ofItemAtPath: full)
          } catch {
            failed = true
          }
        }
      }
      DispatchQueue.main.async {
        result(failed ? FlutterError(code: "protect_failed", message: nil, details: nil) : nil)
      }
    }
  }
}
