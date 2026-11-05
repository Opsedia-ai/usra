import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:home_widget/home_widget.dart';
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
import 'core/security/data_wipe.dart';
import 'core/security/file_protection.dart';
import 'features/account/account_providers.dart';
import 'features/account/account_secure_storage.dart';
import 'features/backup/backup_providers.dart';
import 'features/settings/wipe_restart.dart';
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
  final (file, temporary, version) = await (
    defaultDatabaseFile(),
    getTemporaryDirectory(),
    PackageInfo.fromPlatform(),
  ).wait;
  final root = file.parent;
  const photoFolders = [
    PhotoStore.cardsFolder,
    PhotoStore.attachmentsFolder,
    PhotoStore.medicinesFolder,
  ];
  SharedPreferencesStore? openPreferences;
  final wiper = DataWiper(
    root: root,
    temporary: temporary,
    // iOS pickers and the camera write to `tmp/`; Android's go to the cache.
    extraTemporary: [if (Platform.isIOS) Directory.systemTemp],
    secureStorage: const [
      // Every set of options a key is written with (iOS looks Keychain
      // items up by them).
      FlutterSecureStorage(
        iOptions: IOSOptions(
          accessibility: KeychainAccessibility.first_unlock_this_device,
        ),
        aOptions: AndroidOptions(resetOnError: false),
      ),
      accountSecureStorage,
      FlutterSecureStorage(),
    ],
    // The app's own store once it's open, so its cache is emptied too.
    clearPreferences: () async =>
        (openPreferences ?? await SharedPreferencesStore.open()).clearAll(),
    cancelNotifications: () => FlutterLocalNotificationsPlugin().cancelAll(),
    clearWidget: () async {
      await HomeWidgetSnapshotPublisher.init();
      await HomeWidget.saveWidgetData<String>(
        HomeWidgetSnapshotPublisher.dataKey,
        null,
      );
      await HomeWidget.updateWidget(
        qualifiedAndroidName: HomeWidgetSnapshotPublisher.androidProvider,
        iOSName: HomeWidgetSnapshotPublisher.iOSKind,
      );
    },
  );
  // "Delete all my data" the app was killed in the middle of: finished
  // before any key is read, so nothing from before opens again.
  try {
    await wiper.resumeIfInterrupted();
  } catch (e, s) {
    FlutterError.reportError(
      FlutterErrorDetails(exception: e, stack: s, library: 'wipe'),
    );
  }
  var key = await DatabaseKeyStore().readOrCreate();
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
  BackupService newBackup() => BackupService(
    root: root,
    databaseName: p.basename(file.path),
    deviceKey: key,
    photoKeys: photoKeys,
    photoKeyStore: photoKeyStore,
    temporary: temporary,
    folders: photoFolders,
    files: const [FileDismissalStore.fileName],
    excludeFromBackup: PhotoStore.excludeFromBackup,
  );
  var backup = newBackup();
  try {
    // A restore the app was killed in the middle of: put the old data back.
    await backup.recoverInterrupted();
  } catch (e, s) {
    FlutterError.reportError(
      FlutterErrorDetails(exception: e, stack: s, library: 'backup'),
    );
  }
  try {
    // A backup the app was killed while making or sharing (S11).
    await backup.clearLeftovers();
  } catch (e, s) {
    FlutterError.reportError(
      FlutterErrorDetails(exception: e, stack: s, library: 'backup'),
    );
  }
  // iOS Data Protection (S9). Not awaited: the app opens meanwhile.
  var protection = protectAppFiles(root, photoFolders);
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
    // iOS: plain photos pickers and the camera left in `tmp/` when the app
    // was killed with a form open (each form deletes its own on close).
    if (Platform.isIOS) await clearPickerLeftovers(Directory.systemTemp);
  } catch (e, s) {
    FlutterError.reportError(
      FlutterErrorDetails(exception: e, stack: s, library: 'photos'),
    );
  }

  openPreferences = preferences;
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
  late final Future<void> Function() wipeAndRestart;
  ProviderContainer build({RestoreOutcome? restore, WipeOutcome? wipe}) =>
      ProviderContainer(
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
          wipeAndRestartProvider.overrideWithValue(wipeAndRestart),
          wipeOutcomeProvider.overrideWithValue(wipe),
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
      await protection;
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
    // The restored files came in with the staging folder's class.
    protection = protectAppFiles(root, photoFolders);
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

  // Signs out, deletes everything (S10) and starts again as on first run:
  // new keys, empty database, settings back to their defaults.
  final wipeFailed = ValueNotifier(false);
  wipeAndRestart = WipeRestart(
    current: () => app.value,
    setCurrent: (c) => app.value = c,
    gatewayOf: (c) => c.read(authGatewayProvider),
    // While the session is still there, so the account's device row goes
    // too.
    signOut: (c) async {
      if (c.read(authGatewayProvider) == null) return;
      await c.read(accountProvider.future);
      await c.read(accountProvider.notifier).signOut();
    },
    close: (old) async {
      await WidgetsBinding.instance.endOfFrame;
      old.dispose();
      reminders.dispose();
      await database.close();
      // Nothing may still be writing in the folders being deleted.
      await photoMigration;
      await protection;
    },
    wipe: () async {
      try {
        return await wiper.wipe();
      } finally {
        waiting.clear();
        await lock.forgetAfterWipe();
      }
    },
    reopen: (result) async {
      key = await DatabaseKeyStore().readOrCreate();
      final fresh = await photoKeyStore.load(
        sealedPhotosExist: () async => false,
      );
      switch (fresh.cipher) {
        case final cipher?:
          photoKeys.replace(cipher);
        case null:
          // Never keep sealing with the key that was just deleted.
          photoKeys.markUnavailable(fresh.problem!);
      }
      backup = newBackup();
      outcome = prepareDatabaseFile(file, key);
      database = AppDatabase(openEncryptedDatabase(file, key));
      dismissals = await FileDismissalStore.open();
      try {
        await preferences.setBool(PrefKeys.installed, true);
      } catch (e) {
        Log.error('Wipe settings failed', e);
      }
      protection = protectAppFiles(root, photoFolders);
      app.value = build(wipe: result);
      reminders = newReminders();
      await reminders.start();
    },
    onReopenFailed: () => wipeFailed.value = true,
    signOutTimeout: _signOutTimeout,
  ).call;
  lock.onTooManyFailures = wipeAndRestart;

  app.value = build();
  reminders = newReminders();
  runApp(
    ValueListenableBuilder<ProviderContainer?>(
      valueListenable: app,
      builder: (_, container, _) => container == null
          ? ValueListenableBuilder<bool>(
              valueListenable: wipeFailed,
              builder: (_, failed, _) => MaterialApp(
                debugShowCheckedModeBanner: false,
                home: Scaffold(
                  body: Center(
                    child: failed
                        ? const WipeReopenFailed()
                        : const CircularProgressIndicator(),
                  ),
                ),
              ),
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

/// How long "Delete all my data" waits for the account to sign out.
const _signOutTimeout = Duration(seconds: 10);
