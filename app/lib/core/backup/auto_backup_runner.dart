import 'dart:io';

import '../log.dart';
import 'auto_backup.dart';
import 'backup_folder.dart';
import 'backup_service.dart';
import 'recovery_key.dart';

/// One backup at a time, whoever asks, and none while a restore or a wipe
/// replaces the data underneath.
///
/// [BackupService.create] clears what earlier backups left in the temporary
/// folder, so a second one starting would delete the file of the first, for
/// example while the share sheet still has it. Coming back from the share
/// sheet is also what would start an automatic backup.
class BackupGate {
  Future<void>? _running;
  var _closed = false;

  /// A backup is being made, or the share sheet still has one.
  bool get busy => _running != null;

  /// Runs [job] unless the gate is busy or closed; then it returns null.
  Future<T?> tryRun<T extends Object>(Future<T> Function() job) async {
    if (_closed || _running != null) return null;
    final future = job();
    final done = future.then<void>((_) {}, onError: (_) {});
    _running = done;
    try {
      return await future;
    } finally {
      _running = null;
    }
  }

  /// Stops new backups and waits for the one running, but not for ever: a
  /// call stuck in another app's folder must not stop "Delete all my data" or
  /// the wipe after too many wrong PINs. A backup that outlives this stops at
  /// its next step, as its settings store is retired too.
  Future<void> close({Duration timeout = const Duration(minutes: 2)}) async {
    _closed = true;
    await _running?.timeout(timeout, onTimeout: () {});
  }

  void open() => _closed = false;
}

/// How a run ended.
class AutoBackupResult {
  const AutoBackupResult(this.settings, {this.landed = false});

  final AutoBackupSettings settings;

  /// A new backup is in the folder.
  final bool landed;
}

/// Makes a backup and puts it in the chosen folder. Never throws: how it
/// went is in the settings, saved so the Backup screen and Home can say.
///
/// The order is what keeps the folder safe, whatever happens part way:
///
/// 1. the file is made in the app's temporary folder ([BackupService.create],
///    in an isolate), so a failure there touches nothing in the folder;
/// 2. it's copied to the folder under a `.partial` name and flushed;
/// 3. it's read back and compared with the original, byte for byte, and only
///    then renamed to its real name;
/// 4. only then are older backups deleted, and not if the new one holds
///    materially less than expected ([hasContentDropped]).
///
/// A killed app leaves at most a `.partial`, which the next run removes.
class AutoBackupRunner {
  AutoBackupRunner({
    required this.folders,
    required this.keys,
    required this.store,
    required this.make,
    required this.discard,
    DateTime Function()? clock,
    this.onChange,
  }) : _clock = clock ?? DateTime.now;

  final BackupFolderAccess folders;

  /// The recovery key is only ever read from here. It goes into
  /// [make], which uses it to encrypt; it's never written to the folder.
  final RecoveryKeyStore keys;
  final AutoBackupStore store;
  final Future<CreatedBackup> Function(RecoveryKey key, DateTime now) make;
  final Future<void> Function(CreatedBackup backup) discard;
  final DateTime Function() _clock;

  /// Told each time the settings are saved.
  final void Function(AutoBackupSettings settings)? onChange;

  /// Applies a change to the settings as they are now, not as they were when
  /// the run started: the person may have chosen a folder or frequency since.
  Future<AutoBackupSettings> _update(
    AutoBackupSettings Function(AutoBackupSettings settings) change,
  ) async {
    if (store.retired) return store.current;
    final settings = change(store.current);
    try {
      await store.save(settings);
    } catch (e) {
      // The backup matters more than remembering how it went.
      Log.error('Auto backup settings not saved', e);
    }
    onChange?.call(settings);
    return settings;
  }

  Future<AutoBackupResult> run() async {
    final folder = store.current.folder;
    final now = _clock();
    // Only a finished run clears this: see [AutoBackupFailure.interrupted].
    final started = await _update(
      (s) => s.copyWith(
        tag: s.tag.isEmpty ? newBackupTag() : null,
        lastAttemptAt: now,
        failure: AutoBackupFailure.interrupted,
      ),
    );
    final tag = started.tag;
    try {
      if (folder == null) {
        throw const BackupFolderException(BackupFolderProblem.missing);
      }
      final key = await keys.read();
      if (key == null) {
        return AutoBackupResult(
          await _update(
            (s) => s.copyWith(failure: AutoBackupFailure.noRecoveryKey),
          ),
        );
      }
      if (!await folders.protectedDataAvailable()) {
        throw const BackupFolderException(BackupFolderProblem.locked);
      }
      final status = await folders.inspect(folder.id);
      if (isInICloud(path: status.path, isUbiquitous: status.isUbiquitous)) {
        throw const BackupFolderException(BackupFolderProblem.iCloud);
      }
      var id = folder.id;
      if (status.renewedId case final renewed?) {
        id = renewed;
        await _update(
          (s) => s.folder?.id == folder.id
              ? s.copyWith(folder: folder.withId(id))
              : s,
        );
      }
      final before = await _removeLeftovers(id, tag);

      final created = await make(key, now);
      try {
        if (store.retired) return AutoBackupResult(store.current);
        final missing = created.counts[backupMissingPhotosCount] ?? 0;
        final name = AutoBackupFileName.make(
          tag,
          now,
          complete: created.skippedPhotos == 0 && missing == 0,
        );
        final size = await _land(id, created.file, name);
        if (store.retired) return AutoBackupResult(store.current);
        final settings = await _update((s) {
          final dropped = hasContentDropped(s.baselineCounts, created.counts);
          return s.copyWith(
            lastAt: now,
            lastSize: size,
            lastSkippedPhotos: created.skippedPhotos,
            failure: null,
            latestCounts: created.counts,
            baselineCounts: dropped ? null : created.counts,
            contentDropped: dropped,
            heldBackups: !dropped
                ? const []
                : s.contentDropped
                ? s.heldBackups
                : ownBackups(before, tag),
          );
        });
        await _prune(id, tag, now, settings.heldBackups);
        return AutoBackupResult(settings, landed: true);
      } finally {
        await _discard(created);
      }
    } catch (e) {
      Log.error('Auto backup failed', e);
      final failure = await _classify(e);
      return AutoBackupResult(
        await _update((s) => s.copyWith(failure: failure)),
      );
    }
  }

  /// Steps 2 and 3; the landed file's size. The `.partial` is deleted if
  /// anything goes wrong; if the app dies instead, [_removeLeftovers] gets it
  /// next time.
  Future<int> _land(String id, File source, String name) async {
    final partial = AutoBackupFileName.partialOf(name);
    try {
      await folders.write(id, source.path, partial);
      final size = await folders.verify(id, source.path, partial);
      // A restore or wipe took over while this ran: nothing more lands.
      if (store.retired) {
        throw const BackupFolderException(BackupFolderProblem.failed);
      }
      await folders.rename(id, partial, name);
      return size;
    } catch (_) {
      try {
        await folders.delete(id, partial);
      } catch (e) {
        Log.error('Auto backup partial not deleted', e);
      }
      rethrow;
    }
  }

  /// Everything in the folder apart from the leftovers it removed.
  Future<List<String>> _removeLeftovers(String id, String tag) async {
    final names = [for (final entry in await folders.list(id)) entry.name];
    final leftovers = partialsToDelete(names, tag);
    for (final name in leftovers) {
      try {
        await folders.delete(id, name);
      } catch (e) {
        // Not worth stopping a new backup for; tried again next time.
        Log.error('Auto backup leftover not deleted', e);
      }
    }
    return [
      for (final name in names)
        if (!leftovers.contains(name)) name,
    ];
  }

  /// A new backup is safely in, so nothing here may fail the run: older
  /// files left behind are tried again next time.
  Future<void> _prune(
    String id,
    String tag,
    DateTime now,
    List<String> held,
  ) async {
    if (store.retired) return;
    try {
      final names = (await folders.list(id)).map((e) => e.name);
      for (final name in backupsToDelete(names, tag, now: now, held: held)) {
        await folders.delete(id, name);
      }
    } catch (e) {
      Log.error('Auto backup retention failed', e);
    }
  }

  Future<void> _discard(CreatedBackup created) async {
    try {
      await discard(created);
    } catch (e) {
      // Cleared at the next start or backup.
      Log.error('Auto backup temporary file not deleted', e);
    }
  }

  Future<AutoBackupFailure> _classify(Object e) async {
    if (e is BackupFolderException) {
      switch (e.problem) {
        case BackupFolderProblem.missing:
        case BackupFolderProblem.cantUse:
          return AutoBackupFailure.folderMissing;
        case BackupFolderProblem.iCloud:
          return AutoBackupFailure.iCloudFolder;
        case BackupFolderProblem.noSpace:
          return AutoBackupFailure.noSpace;
        case BackupFolderProblem.locked:
          return AutoBackupFailure.phoneLocked;
        case BackupFolderProblem.failed:
          break;
      }
    }
    if (isOutOfSpace(e)) return AutoBackupFailure.noSpace;
    // iOS says "not permitted" for a photo read after the phone locked.
    try {
      if (!await folders.protectedDataAvailable()) {
        return AutoBackupFailure.phoneLocked;
      }
    } catch (error) {
      Log.error('Auto backup lock check failed', error);
    }
    return AutoBackupFailure.failed;
  }
}

/// No space left, whichever layer noticed: the temporary file (errno 28 on
/// both platforms) or SQLite's snapshot (SQLITE_FULL, which can reach here
/// wrapped by the database's background isolate). Only for telling these
/// apart: the error's text is never logged or shown.
bool isOutOfSpace(Object e) {
  if (e is FileSystemException && e.osError?.errorCode == 28) return true;
  final text = e.toString();
  return text.contains('SQLITE_FULL') ||
      text.contains('database or disk is full') ||
      text.contains('No space left');
}
