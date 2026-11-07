import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/backup/backup_service.dart';
import '../../core/backup/recovery_key.dart';
import '../../core/database/connection.dart';
import '../../core/design/theme.dart';
import '../../core/preferences.dart';
import '../../core/security/app_lock.dart';
import '../../core/security/data_wipe.dart';
import '../../l10n/app_localizations.dart';
import '../app_lock/app_lock_module.dart';
import '../backup/backup_providers.dart';
import '../backup/backup_screen.dart';
import 'delete_data_screen.dart';
import 'key_unavailable.dart';

/// Why the records can't be reached, for [DatabaseKeyUnavailable]'s text.
enum DatabaseProblem { keyUnavailable, openFailed }

/// Swaps a staged backup in while the normal app isn't running, and proves it
/// opens before anything old is given up:
///
/// 1. The backup goes in, with the old data kept aside. A marker stays on disk,
///    so a restart at any point up to step 3 puts the old data back.
/// 2. The new database must open with [deviceKey].
/// 3. If [saveDeviceKey] is given, the new key is saved. Only now, because
///    saving it is what gives up the old key.
/// 4. The old data goes. [remember] can't undo the restore if it fails.
///
/// Throws if the backup couldn't go in, with the old data back in place.
Future<void> replaceDamagedData({
  required BackupService backup,
  required File file,
  required String deviceKey,
  Future<void> Function()? saveDeviceKey,
  Future<void> Function()? remember,
  @visibleForTesting
  void Function(File, String) checkOpens = prepareDatabaseFile,
}) async {
  await backup.commit(hold: true);
  try {
    checkOpens(file, deviceKey);
    await saveDeviceKey?.call();
    await backup.finishCommit();
  } catch (_) {
    await backup.undoCommit();
    rethrow;
  }
  try {
    await remember?.call();
  } finally {
    await backup.discardAside();
  }
}

/// The whole app when the records can't be reached: try again, restore from a
/// backup, write to support, or start fresh. It has none of the normal app's
/// shell (no router, no database), only what those need.
class DatabaseRecoveryApp extends StatelessWidget {
  const DatabaseRecoveryApp({
    super.key,
    required this.problem,
    required this.onRetry,
    required this.backup,
    required this.recoveryKeys,
    required this.lock,
    required this.restore,
    required this.startFresh,
    this.preferences,
    this.restoreFailed = false,
    @visibleForTesting this.pickBackup,
  });

  final DatabaseProblem problem;
  final Future<void> Function() onRetry;
  final BackupService backup;
  final RecoveryKeyStore recoveryKeys;

  /// A lock that's on and can be read asks for the PIN first, as "Delete all
  /// my data" does. One that can't be read can't check anything, and must not
  /// strand a family with a backup: the phone's own settings can clear the app
  /// anyway.
  final AppLock lock;
  final Future<void> Function(StagedRestore, RecoveryKey) restore;
  final Future<void> Function() startFresh;

  /// Null if the phone's settings couldn't be opened either.
  final KeyValueStore? preferences;

  /// The last try to restore didn't go in.
  final bool restoreFailed;

  final Future<String?> Function()? pickBackup;

  @override
  Widget build(BuildContext context) {
    final saved = preferences;
    final pick = pickBackup;
    return ProviderScope(
      overrides: [
        backupServiceProvider.overrideWithValue(backup),
        recoveryKeyStoreProvider.overrideWithValue(recoveryKeys),
        restoreAndRestartProvider.overrideWithValue(restore),
        wipeAndRestartProvider.overrideWithValue(startFresh),
        appLockProvider.overrideWithValue(
          lock.unreadable ? AppLock.off() : lock,
        ),
        if (saved != null) keyValueStoreProvider.overrideWithValue(saved),
        if (pick != null) backupFilePickerProvider.overrideWithValue(pick),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildUsraTheme(simple: false),
        darkTheme: buildUsraTheme(simple: false, brightness: Brightness.dark),
        locale: Locale(saved?.getString(PrefKeys.language) ?? 'ar'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: _RecoveryHome(
          problem: problem,
          onRetry: onRetry,
          restoreFailed: restoreFailed,
        ),
      ),
    );
  }
}

class _RecoveryHome extends ConsumerWidget {
  const _RecoveryHome({
    required this.problem,
    required this.onRetry,
    required this.restoreFailed,
  });

  final DatabaseProblem problem;
  final Future<void> Function() onRetry;
  final bool restoreFailed;

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    if (ref.read(appLockProvider).enabled && !await confirmItsYou(context)) {
      return;
    }
    if (!context.mounted) return;
    await Navigator.of(context)
        .push<void>(MaterialPageRoute(builder: (_) => const RestoreScreen()));
  }

  Future<void> _startFresh(BuildContext context) => Navigator.of(context)
      .push<void>(
        MaterialPageRoute(
          builder: (_) => const DeleteDataScreen(startFresh: true),
        ),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          child: switch (problem) {
            DatabaseProblem.keyUnavailable => DatabaseKeyUnavailable(
              onRetry: onRetry,
              onRestore: () => _restore(context, ref),
              onStartFresh: () => _startFresh(context),
              restoreFailed: restoreFailed,
            ),
            DatabaseProblem.openFailed => DatabaseKeyUnavailable.openFailed(
              onRetry: onRetry,
              onRestore: () => _restore(context, ref),
              onStartFresh: () => _startFresh(context),
              restoreFailed: restoreFailed,
            ),
          },
        ),
      ),
    ),
  );
}
