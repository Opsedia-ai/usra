import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'core/backup/backup_service.dart';
import 'core/backup/recovery_key.dart';
import 'core/database/app_database.dart';
import 'core/database/connection.dart';
import 'core/files/photo_store.dart';
import 'core/preferences.dart';
import 'core/providers.dart';
import 'core/routing/app_router.dart';
import 'features/backup/backup_providers.dart';
import 'features/follow_ups/dismissals.dart';
import 'features/medicines/local_notification_scheduler.dart';
import 'features/medicines/medicines_providers.dart';
import 'features/medicines/reminder_sync.dart';
import 'features/medicines/reminders.dart';
import 'l10n/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final key = await DatabaseKeyStore().readOrCreate();
  final file = await defaultDatabaseFile();
  final (temporary, version) = await (
    getTemporaryDirectory(),
    PackageInfo.fromPlatform(),
  ).wait;
  final backup = BackupService(
    root: file.parent,
    databaseName: p.basename(file.path),
    deviceKey: key,
    temporary: temporary,
    folders: const [
      PhotoStore.cardsFolder,
      PhotoStore.attachmentsFolder,
      PhotoStore.medicinesFolder,
    ],
    files: const [FileDismissalStore.fileName],
    excludeFromBackup: PhotoStore.excludeFromBackup,
  );
  try {
    // A restore the app was killed in the middle of: put the old data back.
    await backup.recoverInterrupted();
  } catch (e, s) {
    FlutterError.reportError(
      FlutterErrorDetails(exception: e, stack: s, library: 'backup'),
    );
  }
  var outcome = prepareDatabaseFile(file, key);
  var database = AppDatabase(openEncryptedDatabase(file, key));
  final (
    preferences,
    cardPhotos,
    attachments,
    medicinePhotos,
    inbox,
    firstDismissals,
  ) = await (
    SharedPreferencesStore.open(),
    PhotoStore.open(PhotoStore.cardsFolder),
    PhotoStore.open(PhotoStore.attachmentsFolder),
    PhotoStore.open(PhotoStore.medicinesFolder),
    DoseActionInbox.open(),
    FileDismissalStore.open(),
  ).wait;

  var dismissals = firstDismissals;
  final recoveryKeys = SecureRecoveryKeyStore();

  // Null while a restore swaps the data underneath.
  final app = ValueNotifier<ProviderContainer?>(null);
  ProviderContainer container() => app.value!;
  late ReminderSync reminders;
  AppLocalizations l() =>
      lookupAppLocalizations(container().read(localeProvider));
  void onDoseResponse(DoseResponse r) {
    // Mid-restore: the notification is still there to press again.
    if (app.value == null) return;
    final status = r.status;
    if (status == null) {
      container().read(routerProvider).go('/medicines');
    } else {
      reminders.handleAction(r.reminder, status);
    }
  }

  // The app starts in Arabic; iOS fixes action labels at start-up.
  final startup = lookupAppLocalizations(const Locale('ar'));
  LocalNotificationScheduler? notifications;
  try {
    notifications = await LocalNotificationScheduler.init(
      channelName: startup.doseChannelName,
      takenLabel: startup.doseTaken,
      snoozeLabel: startup.doseSnooze,
      onResponse: onDoseResponse,
    );
  } catch (e, s) {
    // Records and the emergency card must open even if reminders can't.
    FlutterError.reportError(
      FlutterErrorDetails(exception: e, stack: s, library: 'reminders'),
    );
  }
  final ReminderScheduler scheduler =
      notifications ?? const UnavailableReminderScheduler();
  late final Future<void> Function() restoreAndRestart;
  ProviderContainer build({RestoreOutcome? restore}) => ProviderContainer(
    overrides: [
      databaseProvider.overrideWithValue(database),
      keyValueStoreProvider.overrideWithValue(preferences),
      cardPhotoStoreProvider.overrideWithValue(cardPhotos),
      attachmentStoreProvider.overrideWithValue(attachments),
      medicinePhotoStoreProvider.overrideWithValue(medicinePhotos),
      reminderSchedulerProvider.overrideWithValue(scheduler),
      dismissalStoreProvider.overrideWithValue(dismissals),
      databaseRecoveredProvider.overrideWithValue(
        outcome == DatabaseOpenOutcome.recoveredFromUnreadableFile,
      ),
      backupServiceProvider.overrideWithValue(backup),
      recoveryKeyStoreProvider.overrideWithValue(recoveryKeys),
      appVersionProvider.overrideWithValue(
        '${version.version}+${version.buildNumber}',
      ),
      restoreAndRestartProvider.overrideWithValue(restoreAndRestart),
      restoreOutcomeProvider.overrideWithValue(restore),
    ],
  );
  ReminderSync newReminders() => ReminderSync(
    db: database,
    scheduler: scheduler,
    inbox: inbox,
    texts: () => ReminderTexts(l()),
  );

  // Swaps a staged backup in and starts the app again on it. The old
  // providers go first, so nothing reads the database while it's replaced.
  restoreAndRestart = () async {
    final old = app.value!;
    final locale = old.read(localeProvider);
    app.value = null;
    await WidgetsBinding.instance.endOfFrame;
    old.dispose();
    reminders.dispose();
    await database.close();
    var restored = true;
    try {
      await backup.commit();
    } catch (e, s) {
      // Rolled back: the phone keeps what it had.
      restored = false;
      FlutterError.reportError(
        FlutterErrorDetails(exception: e, stack: s, library: 'backup'),
      );
    }
    outcome = prepareDatabaseFile(file, key);
    database = AppDatabase(openEncryptedDatabase(file, key));
    dismissals = await FileDismissalStore.open();
    final fresh = build(
      restore: restored ? RestoreOutcome.restored : RestoreOutcome.failed,
    );
    fresh.read(localeProvider.notifier).change(locale);
    app.value = fresh;
    if (restored) {
      try {
        await backup.discardAside();
      } catch (_) {
        // Cleared at the next start instead.
      }
    }
    reminders = newReminders();
    await reminders.start();
  };

  app.value = build();
  reminders = newReminders();
  runApp(
    ValueListenableBuilder<ProviderContainer?>(
      valueListenable: app,
      builder: (_, container, _) => container == null
          ? const MaterialApp(
              debugShowCheckedModeBanner: false,
              home: Scaffold(body: Center(child: CircularProgressIndicator())),
            )
          : UncontrolledProviderScope(
              key: ObjectKey(container),
              container: container,
              child: const UsraApp(),
            ),
    ),
  );
  // After the first frame is queued: reminders never delay start-up.
  try {
    final launch = await notifications?.launchResponse();
    if (launch != null) onDoseResponse(launch);
  } catch (_) {
    // Opened from a notification we can't read: just start normally.
  }
  await reminders.start();
  // Notification text follows the app's language.
  // (Set up again for each restart's container.)
  void followLocale() =>
      container().listen(localeProvider, (_, _) => reminders.resync());
  followLocale();
  app.addListener(() {
    if (app.value != null) followLocale();
  });
}
