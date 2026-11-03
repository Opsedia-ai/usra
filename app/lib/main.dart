import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import 'app.dart';
import 'core/database/app_database.dart';
import 'core/database/connection.dart';
import 'core/files/photo_store.dart';
import 'core/providers.dart';
import 'core/routing/app_router.dart';
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
  final cardPhotos = await PhotoStore.open(PhotoStore.cardsFolder);
  final attachments = await PhotoStore.open(PhotoStore.attachmentsFolder);
  final medicinePhotos = await PhotoStore.open(PhotoStore.medicinesFolder);
  final inbox = DoseActionInbox(
    File(p.join(medicinePhotos.root.path, DoseActionInbox.fileName)),
  );

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
  final scheduler = await LocalNotificationScheduler.init(
    inbox: inbox,
    channelName: startup.doseChannelName,
    takenLabel: startup.doseTaken,
    snoozeLabel: startup.doseSnooze,
    onResponse: onDoseResponse,
  );
  container = ProviderContainer(
    overrides: [
      databaseProvider.overrideWithValue(database),
      cardPhotoStoreProvider.overrideWithValue(cardPhotos),
      attachmentStoreProvider.overrideWithValue(attachments),
      medicinePhotoStoreProvider.overrideWithValue(medicinePhotos),
      reminderSchedulerProvider.overrideWithValue(scheduler),
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
  );
  runApp(
    UncontrolledProviderScope(container: container, child: const UsraApp()),
  );
  // After the first frame is queued: reminders never delay start-up.
  final launch = await scheduler.launchResponse();
  if (launch != null) onDoseResponse(launch);
  await reminders.start();
  // Notification text follows the app's language.
  container.listen(localeProvider, (_, _) => reminders.resync());
}
