import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/files/photo_store.dart';
import '../../core/preferences.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import 'dose_schedule.dart';
import 'reminders.dart';

export '../../core/providers.dart' show clockProvider, nowOf;

/// Where photos of medicine boxes and prescriptions live; provided in
/// `main.dart`.
final medicinePhotoStoreProvider = Provider<PhotoStore>(
  (ref) =>
      throw UnimplementedError('medicinePhotoStoreProvider must be overridden'),
);

/// The phone's reminders; provided in `main.dart`, faked in tests.
final reminderSchedulerProvider = Provider<ReminderScheduler>(
  (ref) =>
      throw UnimplementedError('reminderSchedulerProvider must be overridden'),
);

/// Reminder and widget text as [container] has it now: the app's language
/// and the discreet setting.
ReminderTexts reminderTextsOf(ProviderContainer container) => ReminderTexts(
  lookupAppLocalizations(container.read(localeProvider)),
  discreet: container.read(discreetNotificationsProvider),
);

/// Calls [resync] whenever [reminderTextsOf] or the vaccine reminder
/// settings would change, so scheduled
/// reminders and the widget are rewritten in the new language or without
/// (or with) names.
void resyncOnTextChange(ProviderContainer container, void Function() resync) {
  container.listen(localeProvider, (_, _) => resync());
  container.listen(discreetNotificationsProvider, (_, _) => resync());
  container.listen(vaccineRemindersProvider, (_, _) => resync());
  container.listen(vaccineReminderMinutesProvider, (_, _) => resync());
}

final medicinesProvider = StreamProvider.family<List<Medicine>, String>(
  (ref, profileId) => ref.watch(databaseProvider).watchMedicines(profileId),
);

final medicineProvider = StreamProvider.family<Medicine?, String>(
  (ref, id) => ref.watch(databaseProvider).watchMedicine(id),
);

final doseScheduleProvider = StreamProvider.family<DoseSchedule?, String>(
  (ref, medicineId) =>
      ref.watch(databaseProvider).watchDoseSchedule(medicineId),
);

final medicineDoseLogsProvider = StreamProvider.family<List<DoseLog>, String>(
  (ref, medicineId) =>
      ref.watch(databaseProvider).watchMedicineDoseLogs(medicineId),
);

final regimensProvider = StreamProvider<List<Regimen>>(
  (ref) => ref.watch(databaseProvider).watchRegimens(),
);

/// Today, from local midnight to the next.
({DateTime from, DateTime to}) todayOf(DateTime now) => (
  from: DateTime(now.year, now.month, now.day),
  to: DateTime(now.year, now.month, now.day + 1),
);

/// Dose log entries for today's doses.
final todayLogsProvider = StreamProvider<List<DoseLog>>((ref) {
  final day = todayOf(ref.watch(clockProvider)());
  return ref
      .watch(databaseProvider)
      .watchDoseLogs(from: day.from.toUtc(), to: day.to.toUtc());
});

/// Every dose due today across the family, in time order.
final todayDosesProvider = Provider<AsyncValue<List<PlannedDose>>>((ref) {
  final regimens = ref.watch(regimensProvider);
  final logs = ref.watch(todayLogsProvider);
  for (final v in [regimens, logs]) {
    if (v.hasError) return AsyncError(v.error!, v.stackTrace!);
  }
  final r = regimens.value;
  final l = logs.value;
  if (r == null || l == null) return const AsyncLoading();
  final day = todayOf(ref.watch(clockProvider)());
  return AsyncData(plannedDoses(r, l, from: day.from, to: day.to));
});

/// What the phone lets reminders do; refreshed after asking.
final reminderAccessProvider = FutureProvider<ReminderAccess>(
  (ref) => ref.watch(reminderSchedulerProvider).access(),
);

final prescriptionsProvider = StreamProvider.family<List<Prescription>, String>(
  (ref, profileId) => ref.watch(databaseProvider).watchPrescriptions(profileId),
);

final prescriptionProvider = StreamProvider.family<Prescription?, String>(
  (ref, id) => ref.watch(databaseProvider).watchPrescription(id),
);

final prescriptionMedicinesProvider =
    StreamProvider.family<List<Medicine>, String>(
      (ref, id) => ref.watch(databaseProvider).watchPrescriptionMedicines(id),
    );
