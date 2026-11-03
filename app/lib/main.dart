import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/database/app_database.dart';
import 'core/database/connection.dart';
import 'core/files/photo_store.dart';
import 'core/preferences.dart';
import 'core/providers.dart';
import 'core/routing/app_router.dart';
import 'features/follow_ups/dismissals.dart';
import 'features/medicines/dose_widget.dart';
import 'features/medicines/local_notification_scheduler.dart';
import 'features/medicines/medicines_providers.dart';
import 'features/medicines/reminder_sync.dart';
import 'features/medicines/reminders.dart';
import 'l10n/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final key = await DatabaseKeyStore().readOrCreate();
  final file = await defaultDatabaseFile();
  final outcome = prepareDatabaseFile(file, key);
  final database = AppDatabase(openEncryptedDatabase(file, key));
  final (
    preferences,
    cardPhotos,
    attachments,
    medicinePhotos,
    inbox,
    dismissals,
  ) = await (
    SharedPreferencesStore.open(),
    PhotoStore.open(PhotoStore.cardsFolder),
    PhotoStore.open(PhotoStore.attachmentsFolder),
    PhotoStore.open(PhotoStore.medicinesFolder),
    DoseActionInbox.open(),
    FileDismissalStore.open(),
  ).wait;

  late final ProviderContainer container;
  late final ReminderSync reminders;
  AppLocalizations l() =>
      lookupAppLocalizations(container.read(localeProvider));
  void onDoseResponse(DoseResponse r) {
    final status = r.status;
    if (status == null) {
      container.read(routerProvider).go('/medicines');
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
  container = ProviderContainer(
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
    ],
  );
  reminders = ReminderSync(
    db: database,
    scheduler: scheduler,
    inbox: inbox,
    texts: () => ReminderTexts(l()),
    widget: const HomeWidgetSnapshotPublisher(),
  );
  runApp(
    UncontrolledProviderScope(container: container, child: const UsraApp()),
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
  await HomeWidgetSnapshotPublisher.onTap(
    () => container.read(routerProvider).go('/medicines'),
  );
  await reminders.start();
  // Notification text follows the app's language.
  container.listen(localeProvider, (_, _) => reminders.resync());
}
