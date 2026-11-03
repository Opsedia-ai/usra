import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/backup/backup_service.dart';
import '../../core/backup/recovery_key.dart';
import '../../core/preferences.dart';
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
      () async => (await FilePicker.pickFile())?.path,
);

/// Opens the share sheet for a backup file and says whether it was saved
/// or sent somewhere (dismissed means not). Overridden in tests.
final backupShareProvider =
    Provider<Future<ShareResultStatus> Function(ShareParams)>(
      (ref) =>
          (params) async => (await SharePlus.instance.share(params)).status,
    );

/// Swaps the staged backup in, then restarts the app on it. Provided in
/// `main.dart`, which owns the database connection.
final restoreAndRestartProvider = Provider<Future<void> Function()>(
  (ref) =>
      throw UnimplementedError('restoreAndRestartProvider must be overridden'),
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
/// is missing or more than [backupReminderDays] old.
const backupReminderDays = 30;

final backupDueProvider = Provider<bool>((ref) {
  final people = ref.watch(profilesProvider).value ?? const [];
  if (people.isEmpty) return false;
  final last = ref.watch(lastBackupProvider);
  return last == null ||
      DateTime.now().difference(last) >
          const Duration(days: backupReminderDays);
});
