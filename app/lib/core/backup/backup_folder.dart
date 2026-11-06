import 'dart:io' show Platform;

import 'package:flutter/services.dart';

import 'auto_backup.dart';

/// What went wrong reaching the backup folder.
enum BackupFolderProblem {
  /// Moved, removed, unplugged, or access was taken away.
  missing,

  /// The folder is (now) in iCloud, so nothing may be written there.
  iCloud,

  /// No space left there.
  noSpace,

  /// iOS: the phone is locked and files can't be opened.
  locked,

  /// This place can't hold backups: it refused a small test file, or
  /// won't let the app rename or delete its own files.
  cantUse,

  /// Anything else.
  failed,
}

class BackupFolderException implements Exception {
  const BackupFolderException(this.problem);

  final BackupFolderProblem problem;

  @override
  String toString() => 'BackupFolderException(${problem.name})';
}

/// A folder the person just chose, before deciding whether to use it.
class PickedFolder {
  const PickedFolder({
    required this.folder,
    this.path,
    this.isUbiquitous = false,
  });

  final BackupFolder folder;

  /// Where it is on disk; only on iOS, only to look for iCloud.
  final String? path;

  /// iOS says it's kept in iCloud.
  final bool isUbiquitous;
}

/// A folder's state when a backup is about to go in.
class FolderStatus {
  const FolderStatus({this.path, this.isUbiquitous = false, this.renewedId});

  final String? path;
  final bool isUbiquitous;

  /// iOS: a fresh bookmark, when the old one went stale. Save it.
  final String? renewedId;
}

/// A file in the folder.
class FolderEntry {
  const FolderEntry(this.name, this.size);

  final String name;
  final int? size;
}

/// iCloud Drive keeps its files under `Mobile Documents`, also when iOS
/// doesn't report them as ubiquitous (a folder not yet synced, say).
bool isICloudPath(String path) {
  final lower = path.toLowerCase();
  return lower.contains('/mobile documents/') ||
      lower.endsWith('/mobile documents') ||
      lower.contains('/com~apple~clouddocs') ||
      lower.contains('/icloud~');
}

/// Apple 5.1.3 and this repo's own rule: no health data in iCloud, encrypted
/// or not. Checked when a folder is picked and again before every backup,
/// because a folder can be moved there later.
bool isInICloud({String? path, required bool isUbiquitous}) =>
    isUbiquitous || (path != null && isICloudPath(path));

/// The system's folder picker and file operations inside the chosen folder:
/// Storage Access Framework on Android, a security-scoped bookmark on iOS.
///
/// These are small steps on purpose. The order that makes a write atomic
/// lives in `AutoBackupRunner`, where it can be tested.
abstract class BackupFolderAccess {
  /// The picker. Null if cancelled. Throws [BackupFolderException] with
  /// [BackupFolderProblem.cantUse] if the place can't hold backups.
  Future<PickedFolder?> pick();

  /// Throws [BackupFolderProblem.missing] if it can't be reached.
  Future<FolderStatus> inspect(String id);

  /// Copies [sourcePath] to a new file [name] in the folder and flushes it
  /// to storage where the place allows.
  Future<void> write(String id, String sourcePath, String name);

  /// Reads [name] back from the folder and compares it with [sourcePath],
  /// byte for byte; its size. Throws if they differ.
  Future<int> verify(String id, String sourcePath, String name);

  Future<void> rename(String id, String from, String to);

  Future<void> delete(String id, String name);

  Future<List<FolderEntry>> list(String id);

  /// Gives up access to a folder no longer used.
  Future<void> release(String id);

  /// iOS: false while the phone is locked. Always true on Android.
  Future<bool> protectedDataAvailable();
}

/// Talks to `BackupFolderChannel` on each platform.
class ChannelBackupFolderAccess implements BackupFolderAccess {
  const ChannelBackupFolderAccess();

  static const _channel = MethodChannel('usra/backup_folder');

  static BackupFolderProblem _problem(String code) => switch (code) {
    'missing' => BackupFolderProblem.missing,
    'icloud' => BackupFolderProblem.iCloud,
    'no_space' => BackupFolderProblem.noSpace,
    'locked' => BackupFolderProblem.locked,
    'cant_use' => BackupFolderProblem.cantUse,
    _ => BackupFolderProblem.failed,
  };

  Future<T?> _call<T>(String method, [Map<String, Object?>? args]) async {
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on PlatformException catch (e) {
      throw BackupFolderException(_problem(e.code));
    } on MissingPluginException {
      throw const BackupFolderException(BackupFolderProblem.failed);
    }
  }

  Future<Map<String, Object?>> _map(
    String method,
    Map<String, Object?> args,
  ) async => (await _call<Map<Object?, Object?>>(
    method,
    args,
  ))!.cast<String, Object?>();

  @override
  Future<PickedFolder?> pick() async {
    final json = await _call<Map<Object?, Object?>>('pick');
    if (json == null) return null;
    return PickedFolder(
      folder: BackupFolder(
        id: json['id'] as String,
        name: json['name'] as String,
        onThisPhone: json['onThisPhone'] as bool?,
      ),
      path: json['path'] as String?,
      isUbiquitous: json['ubiquitous'] as bool? ?? false,
    );
  }

  @override
  Future<FolderStatus> inspect(String id) async {
    final json = await _map('inspect', {'id': id});
    return FolderStatus(
      path: json['path'] as String?,
      isUbiquitous: json['ubiquitous'] as bool? ?? false,
      renewedId: json['renewedId'] as String?,
    );
  }

  @override
  Future<void> write(String id, String sourcePath, String name) =>
      _call<void>('write', {'id': id, 'source': sourcePath, 'name': name});

  @override
  Future<int> verify(String id, String sourcePath, String name) async =>
      (await _call<int>('verify', {
        'id': id,
        'source': sourcePath,
        'name': name,
      }))!;

  @override
  Future<void> rename(String id, String from, String to) =>
      _call<void>('rename', {'id': id, 'from': from, 'to': to});

  @override
  Future<void> delete(String id, String name) =>
      _call<void>('delete', {'id': id, 'name': name});

  @override
  Future<List<FolderEntry>> list(String id) async {
    final rows = await _call<List<Object?>>('list', {'id': id});
    return [
      for (final row in rows!)
        if (row case final Map<Object?, Object?> json)
          FolderEntry(json['name'] as String, json['size'] as int?),
    ];
  }

  @override
  Future<void> release(String id) => _call<void>('release', {'id': id});

  @override
  Future<bool> protectedDataAvailable() async {
    if (!Platform.isIOS) return true;
    return await _call<bool>('protectedDataAvailable') ?? true;
  }
}
