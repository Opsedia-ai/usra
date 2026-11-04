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
import 'core/log.dart';
import 'core/preferences.dart';
import 'core/providers.dart';
import 'core/routing/app_router.dart';
import 'core/security/app_lock.dart';
import 'features/backup/backup_providers.dart';
import 'features/children/vaccine_reminders.dart';
import 'features/follow_ups/dismissals.dart';
import 'features/medicines/dose_widget.dart';
import 'features/medicines/local_notification_scheduler.dart';
import 'features/medicines/medicines_providers.dart';
import 'features/medicines/reminder_sync.dart';
import 'features/medicines/reminders.dart';
import 'l10n/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Log.installErrorHandlers();
  final key = await DatabaseKeyStore().readOrCreate();
  final file = await defaultDatabaseFile();
  const photoFolders = [
    PhotoStore.cardsFolder,
    PhotoStore.attachmentsFolder,
    PhotoStore.medicinesFolder,
  ];
  final photoKeyStore = SecurePhotoKeyStore();
  // Never throws: without a key the app still opens, and photos say they
  // can't be opened here until a backup is restored.
  final photoKeys = await photoKeyStore.load(
    sealedPhotosExist: () => anySealedPhoto(file.parent, photoFolders),
  );
  try {
    await excludeDatabaseFromBackup(file, PhotoStore.excludeFromBackup);
  } catch (e, s) {
    FlutterError.reportError(
      FlutterErrorDetails(exception: e, stack: s, library: 'database'),
    );
  }
  final (temporary, version) = await (
    getTemporaryDirectory(),
    PackageInfo.fromPlatform(),
  ).wait;
  final backup = BackupService(
    root: file.parent,
    databaseName: p.basename(file.path),
    deviceKey: key,
    photoKeys: photoKeys,
    photoKeyStore: photoKeyStore,
    temporary: temporary,
    folders: photoFolders,
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
    PhotoStore.open(PhotoStore.cardsFolder, photoKeys),
    PhotoStore.open(PhotoStore.attachmentsFolder, photoKeys),
    PhotoStore.open(PhotoStore.medicinesFolder, photoKeys),
    DoseActionInbox.open(),
    FileDismissalStore.open(),
  ).wait;

  // Once, for photos saved before they were encrypted; resumes if the app
  // was killed half way. Not awaited: the app opens meanwhile, showing
  // those photos as they are until they're done.
  final photoMigration = () async {
    try {
      await [
        for (final store in [cardPhotos, attachments, medicinePhotos])
          store.sealPlainFiles(),
      ].wait;
    } catch (e, s) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: e, stack: s, library: 'photos'),
      );
    }
  }();
  try {
    // Decrypted copies a share left behind.
    await SharedPhotoCache(temporary).clear();
  } catch (e, s) {
    FlutterError.reportError(
      FlutterErrorDetails(exception: e, stack: s, library: 'photos'),
    );
  }

  var dismissals = firstDismissals;
  // Read before the first frame, so the app never shows unlocked.
  final freshInstall = preferences.getBool(PrefKeys.installed) != true;
  final lock = await AppLock.open(
    store: SecureLockStore(),
    biometrics: LocalAuthBiometrics(),
    uptime: const PlatformUptime(),
    freshInstall: freshInstall,
  );
  if (freshInstall) await preferences.setBool(PrefKeys.installed, true);
  final recoveryKeys = SecureRecoveryKeyStore();

  // Null while a restore swaps the data underneath.
  final app = ValueNotifier<ProviderContainer?>(null);
  ProviderContainer container() => app.value!;
  late ReminderSync reminders;
  // Pressed while a restore swaps the data: replayed once it's back.
  final waiting = <DoseResponse>[];
  void onDoseResponse(DoseResponse r) {
    if (app.value == null) {
      waiting.add(r);
      return;
    }
    final status = r.status;
    if (status == null) {
      // Opening the app from a reminder waits for the lock.
      final child = r.dose.profileId;
      lock.runWhenUnlocked(
        () => container()
            .read(routerProvider)
            .go(child == null ? '/medicines' : '/family/$child/vaccines'),
      );
    } else {
      // Taken / Snooze only saves the dose and shows nothing: no unlock.
      reminders.handleAction(r.dose, status);
    }
  }

  // The app starts in Arabic; iOS fixes action labels at start-up.
  final startup = lookupAppLocalizations(const Locale('ar'));
  LocalNotificationScheduler? notifications;
  try {
    notifications = await LocalNotificationScheduler.init(
      channelName: startup.doseChannelName,
      vaccineChannelName: startup.vaccineChannelName,
      takenLabel: startup.doseTaken,
      snoozeLabel: startup.doseSnooze,
      hiddenPreviewText: startup.reminderHiddenPreview,
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
  late final Future<void> Function(StagedRestore, RecoveryKey)
  restoreAndRestart;
  ProviderContainer build({RestoreOutcome? restore}) => ProviderContainer(
    overrides: [
      databaseProvider.overrideWithValue(database),
      keyValueStoreProvider.overrideWithValue(preferences),
      appLockProvider.overrideWithValue(lock),
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
    texts: () => reminderTextsOf(container()),
    widget: const HomeWidgetSnapshotPublisher(),
    vaccineChanges: database.watchEventChanges(vaccineRecordTypes),
    vaccines: (now) {
      final c = container();
      final texts = reminderTextsOf(c);
      return loadVaccineReminders(
        database,
        now: now,
        settings: VaccineReminderSettings(
          enabled: c.read(vaccineRemindersProvider),
          minutes: c.read(vaccineReminderMinutesProvider),
        ),
        texts: VaccineReminderTexts(texts.l, discreet: texts.discreet),
      );
    },
  );

  // Swaps a staged backup in and starts the app again on it. The old
  // providers go first, so nothing reads the database while it's replaced.
  restoreAndRestart = (staged, recoveryKey) async {
    final old = app.value!;
    final locale = old.read(localeProvider);
    app.value = null;
    var restored = false;
    try {
      await WidgetsBinding.instance.endOfFrame;
      old.dispose();
      reminders.dispose();
      await database.close();
      // The restore replaces the photo folders the migration works in.
      await photoMigration;
      await backup.commit();
      restored = true;
    } catch (e, s) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: e, stack: s, library: 'backup'),
      );
      try {
        // commit() rolls back itself; this finishes the job if that failed
        // too, so the old data is what reopens.
        await backup.recoverInterrupted();
      } catch (e, s) {
        FlutterError.reportError(
          FlutterErrorDetails(exception: e, stack: s, library: 'backup'),
        );
      }
    }
    outcome = prepareDatabaseFile(file, key);
    database = AppDatabase(openEncryptedDatabase(file, key));
    dismissals = await FileDismissalStore.open();
    if (restored) {
      try {
        await recoveryKeys.write(recoveryKey);
        await preferences.setInt(
          PrefKeys.lastBackupAt,
          staged.manifest.createdAt.millisecondsSinceEpoch,
        );
        await backup.discardAside();
      } catch (e, s) {
        // The records are back; these only matter for the next backup.
        FlutterError.reportError(
          FlutterErrorDetails(exception: e, stack: s, library: 'backup'),
        );
      }
    }
    final fresh = build(
      restore: restored ? RestoreOutcome.restored : RestoreOutcome.failed,
    );
    fresh.read(localeProvider.notifier).change(locale);
    app.value = fresh;
    reminders = newReminders();
    for (final r in waiting) {
      onDoseResponse(r);
    }
    waiting.clear();
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
  try {
    await HomeWidgetSnapshotPublisher.init();
  } catch (_) {
    // No widget on this platform; the app works without it.
  }
  // Waits for the lock. During a restore there is briefly no container;
  // the tap is dropped.
  await HomeWidgetSnapshotPublisher.onTap(
    () => lock.runWhenUnlocked(
      () => app.value?.read(routerProvider).go('/medicines'),
    ),
  );
  await reminders.start();
  // Notification and widget text follow the app's language and the
  // discreet setting. (Set up again for each restart's container.)
  void followTexts() =>
      resyncOnTextChange(container(), () => reminders.resync());
  followTexts();
  app.addListener(() {
    if (app.value != null) followTexts();
  });
}
