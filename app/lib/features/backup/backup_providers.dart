import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/backup/auto_backup.dart';
import '../../core/backup/auto_backup_runner.dart';
import '../../core/backup/backup_folder.dart';
import '../../core/backup/backup_service.dart';
import '../../core/backup/recovery_key.dart';
import '../../core/log.dart';
import '../../core/preferences.dart';
import '../../core/providers.dart';
import '../../core/security/app_lock.dart';
import '../family/family_screen.dart';

/// Where the recovery key is kept; overridden in `main.dart` with
/// [SecureRecoveryKeyStore].
final recoveryKeyStoreProvider = Provider<RecoveryKeyStore>(
  (ref) => MemoryRecoveryKeyStore(),
);

/// The key saved on this phone, if one was made or used to restore.
final savedRecoveryKeyProvider = FutureProvider<RecoveryKey?>(
  (ref) => ref.watch(recoveryKeyStoreProvider).read(),
);

/// Makes and restores backups; provided in `main.dart`.
final backupServiceProvider = Provider<BackupService>(
  (ref) => throw UnimplementedError('backupServiceProvider must be overridden'),
);

/// The app's version, written in each backup; provided in `main.dart`.
final appVersionProvider = Provider<String>((ref) => 'dev');

/// Picks a backup file and returns its path, or null if cancelled.
/// Overridden in tests.
final backupFilePickerProvider = Provider<Future<String?> Function()>(
  (ref) =>
      () async => (await whileInOtherApp(FilePicker.pickFile))?.path,
);

/// Opens the share sheet for a backup file and says whether it was saved
/// or sent somewhere (dismissed means not). Overridden in tests.
final backupShareProvider =
    Provider<Future<ShareResultStatus> Function(ShareParams)>(
      (ref) =>
          (params) async =>
              (await whileInOtherApp(() => SharePlus.instance.share(params)))
                  .status,
    );

/// Swaps the staged backup in, then restarts the app on it. Once it's in,
/// the key that opened it becomes this phone's recovery key (one key for
/// the family to keep) and its date the last backup. Provided in
/// `main.dart`, which owns the database connection.
final restoreAndRestartProvider =
    Provider<Future<void> Function(StagedRestore, RecoveryKey)>(
      (ref) => throw UnimplementedError(
        'restoreAndRestartProvider must be overridden',
      ),
    );

/// How the last restore went, shown once on Home after the app restarts.
enum RestoreOutcome { restored, failed }

final restoreOutcomeProvider = Provider<RestoreOutcome?>((ref) => null);

/// When the last backup was made (or the backup this phone was restored
/// from), or null if never.
final lastBackupProvider = NotifierProvider<LastBackupController, DateTime?>(
  LastBackupController.new,
);

class LastBackupController extends Notifier<DateTime?> {
  @override
  DateTime? build() {
    final ms = ref.watch(keyValueStoreProvider).getInt(PrefKeys.lastBackupAt);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> set(DateTime at) async {
    state = at;
    await ref
        .read(keyValueStoreProvider)
        .setInt(PrefKeys.lastBackupAt, at.millisecondsSinceEpoch);
  }
}

/// A backup is due once the family has someone in it and the last backup
/// is missing or more than [backupReminderDays] old. Only a copy known to be
/// off this phone counts, because that's what the reminder is for: with
/// automatic backup on, it counts from when that was turned on, and then
/// says why a folder on the phone isn't enough.
const backupReminderDays = 30;

final backupDueProvider = Provider<bool>((ref) {
  final people = ref.watch(profilesProvider).value ?? const [];
  if (people.isEmpty) return false;
  var last = ref.watch(lastBackupProvider);
  final auto = ref.watch(autoBackupProvider).settings;
  if (auto.enabled) {
    final since = auto.enabledAt;
    if (since != null && (last == null || since.isAfter(last))) last = since;
  }
  return last == null ||
      DateTime.now().difference(last) >
          const Duration(days: backupReminderDays);
});

/// One backup at a time; shared across restarts of the app's providers, so
/// provided in `main.dart`, which waits on it before closing the database.
final backupGateProvider = Provider<BackupGate>((ref) => BackupGate());

/// The system's folder picker and the folder itself. Overridden in tests.
final backupFolderAccessProvider = Provider<BackupFolderAccess>(
  (ref) => const ChannelBackupFolderAccess(),
);

/// Where the automatic backup settings are kept; provided in `main.dart`.
final autoBackupStoreProvider = Provider<AutoBackupStore>(
  (ref) => AutoBackupStore.memory(),
);

/// How long after opening the app a due backup starts: the app's own start
/// comes first on a budget phone.
final autoBackupStartDelayProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 4),
);

/// The settings, and whether a backup is being made right now.
class AutoBackupStatus {
  const AutoBackupStatus(this.settings, {this.running = false});

  final AutoBackupSettings settings;
  final bool running;
}

/// What came of asking for a folder.
enum FolderChoice { chosen, cancelled, inICloud, cantUse }

final autoBackupProvider =
    NotifierProvider<AutoBackupController, AutoBackupStatus>(
      AutoBackupController.new,
    );

class AutoBackupController extends Notifier<AutoBackupStatus> {
  Timer? _start;

  /// Turning it back on after the pause is the person's choice, and sticks.
  var _pausedForRecovery = false;

  @override
  AutoBackupStatus build() {
    ref.onDispose(() => _start?.cancel());
    return AutoBackupStatus(ref.watch(autoBackupStoreProvider).current);
  }

  Future<void> _save(AutoBackupSettings settings) async {
    state = AutoBackupStatus(settings, running: state.running);
    await ref.read(autoBackupStoreProvider).save(settings);
  }

  /// Asks for a folder and saves it, unless it's refused.
  Future<FolderChoice> chooseFolder() async {
    final folders = ref.read(backupFolderAccessProvider);
    final PickedFolder? picked;
    try {
      picked = await whileInOtherApp(folders.pick);
    } on BackupFolderException {
      return FolderChoice.cantUse;
    }
    if (picked == null) return FolderChoice.cancelled;
    if (isInICloud(path: picked.path, isUbiquitous: picked.isUbiquitous)) {
      return FolderChoice.inICloud;
    }
    final settings = state.settings;
    final old = settings.folder;
    await _save(
      settings.copyWith(
        folder: picked.folder,
        failure: switch (settings.failure) {
          AutoBackupFailure.folderMissing ||
          AutoBackupFailure.iCloudFolder => null,
          final other => other,
        },
      ),
    );
    if (old != null && old.id != picked.folder.id) {
      try {
        await folders.release(old.id);
      } catch (e) {
        Log.error('Old backup folder not released', e);
      }
    }
    return FolderChoice.chosen;
  }

  Future<void> setFrequency(BackupFrequency frequency) =>
      _save(state.settings.copyWith(frequency: frequency));

  Future<void> enable() => _save(
    state.settings.copyWith(
      enabled: true,
      enabledAt: DateTime.now(),
      failure: null,
    ),
  );

  /// Stops new backups. What's in the folder stays there.
  Future<void> disable() =>
      _save(state.settings.copyWith(enabled: false, failure: null));

  /// "Back up now" and "Try again": runs whatever the schedule says.
  Future<void> runNow() async {
    final gate = ref.read(backupGateProvider);
    final store = ref.read(autoBackupStoreProvider);
    final service = ref.read(backupServiceProvider);
    final db = ref.read(databaseProvider);
    final appVersion = ref.read(appVersionProvider);
    final runner = AutoBackupRunner(
      folders: ref.read(backupFolderAccessProvider),
      keys: ref.read(recoveryKeyStoreProvider),
      store: store,
      make: (key, now) =>
          service.create(db, key, appVersion: appVersion, now: now),
      discard: service.discardCreated,
      onChange: (settings) {
        if (ref.mounted) {
          state = AutoBackupStatus(settings, running: state.running);
        }
      },
    );
    final result = await gate.tryRun(() {
      state = AutoBackupStatus(state.settings, running: true);
      return runner.run();
    });
    // Busy (the share sheet has a backup open), or closed for a restore.
    if (result == null || !ref.mounted) return;
    state = AutoBackupStatus(result.settings);
    // Home's reminder is about a copy off this phone: a folder on the
    // phone, or one that may be, doesn't quiet it.
    if (result.landed && result.settings.folder?.onThisPhone == false) {
      await ref.read(lastBackupProvider.notifier).set(DateTime.now());
    }
  }

  /// When the app comes to the front. Cheap and returns at once: if a backup
  /// is due it starts a moment later, in the background. There is nothing
  /// else starting backups: Usra doesn't run in the background for this.
  void runIfDue() {
    if (_start?.isActive ?? false) return;
    final settings = state.settings;
    if (!settings.enabled) return;
    if (ref.read(databaseRecoveredProvider) && !_pausedForRecovery) {
      _pausedForRecovery = true;
      // Near-empty backups must not push out the ones with the records.
      // Off until a restore or the person turns it back on.
      _save(
        settings.copyWith(
          enabled: false,
          failure: AutoBackupFailure.pausedForRecovery,
        ),
      ).ignore();
      return;
    }
    if (!shouldStartAutoBackup(settings, DateTime.now())) return;
    _start = Timer(ref.read(autoBackupStartDelayProvider), _startIfStillDue);
  }

  Future<void> _startIfStillDue() async {
    if (!ref.mounted) return;
    if (!shouldStartAutoBackup(state.settings, DateTime.now())) return;
    try {
      // Nobody in the family yet: nothing worth pushing older backups out.
      if ((await ref.read(profilesProvider.future)).isEmpty) return;
    } catch (e) {
      Log.error('Auto backup family check failed', e);
      return;
    }
    if (ref.mounted) await runNow();
  }
}
