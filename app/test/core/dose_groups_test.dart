import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usra/core/database/app_database.dart';
import 'package:usra/features/family/person_status.dart';
import 'package:usra/features/medicines/dose_schedule.dart';
import 'package:usra/features/medicines/reminders.dart';
import 'package:usra/features/medicines/today_screen.dart';
import 'package:usra/l10n/app_localizations_ar.dart';

void main() {
  late AppDatabase db;
  final now = DateTime(2026, 11, 3, 14);

  setUp(() {
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
  });
  tearDown(() => db.close());

  /// A dose planned at [at], with a [status] logged at [logAt] if given.
  Future<PlannedDose> dose(
    DateTime at, {
    String? status,
    DateTime? logAt,
  }) async {
    final person = await db.addProfile('جدو');
    final time =
        '${at.hour.toString().padLeft(2, '0')}:'
        '${at.minute.toString().padLeft(2, '0')}';
    final id = await db.saveMedicine(
      profileId: person,
      name: 'كونكور',
      startOn: DateTime(2026, 11, 1),
      schedule: DoseScheduleInput(times: [time]),
    );
    if (status != null) {
      await db.logDose(id, at.toUtc(), status, at: logAt ?? now);
    }
    final regimens = await db.watchRegimens().first;
    final logs = await db.watchMedicineDoseLogs(id).first;
    return plannedDoses(
      regimens,
      logs,
      from: DateTime(2026, 11, 3),
      to: DateTime(2026, 11, 4),
    ).singleWhere((d) => d.regimen.medicine.id == id);
  }

  test('an hour after its time a dose is missed, not before', () async {
    final justDue = await dose(DateTime(2026, 11, 3, 13));
    expect(isDoseMissed(justDue, now), isFalse);
    expect(doseGroupOf(justDue, now), DoseGroup.now);
    expect(isDoseMissed(justDue, now.add(const Duration(minutes: 1))), isTrue);
    expect(
      doseGroupOf(justDue, now.add(const Duration(minutes: 1))),
      DoseGroup.missed,
    );
  });

  test('a dose minutes away is now, one further off is later', () async {
    final soon = await dose(DateTime(2026, 11, 3, 14, 15));
    expect(doseGroupOf(soon, now), DoseGroup.now);
    final later = await dose(DateTime(2026, 11, 3, 14, 16));
    expect(doseGroupOf(later, now), DoseGroup.later);
  });

  test('a snooze puts off missed until an hour after it rings', () async {
    final snoozed = await dose(
      DateTime(2026, 11, 3, 13),
      status: DoseOutcome.snoozed,
    );
    expect(doseSnoozedUntil(snoozed), now.add(snoozeDuration));
    final atTheLimit = now.add(snoozeDuration).add(doseMissedAfter);
    expect(doseGroupOf(snoozed, atTheLimit), DoseGroup.now);
    expect(
      doseGroupOf(snoozed, atTheLimit.add(const Duration(minutes: 1))),
      DoseGroup.missed,
    );
  });

  test('snoozed a little before its time, it rings after its time', () async {
    final at = DateTime(2026, 11, 3, 14, 10);
    final snoozed = await dose(at, status: DoseOutcome.snoozed);
    expect(doseSnoozedUntil(snoozed), at.add(snoozeDuration));
    expect(doseGroupOf(snoozed, now), DoseGroup.now);
  });

  test('taken or not taken, a dose is done and never missed', () async {
    final taken = await dose(
      DateTime(2026, 11, 3, 8),
      status: DoseOutcome.taken,
    );
    expect(doseGroupOf(taken, now), DoseGroup.done);
    expect(isDoseMissed(taken, now), isFalse);
    final skipped = await dose(
      DateTime(2026, 11, 3, 9),
      status: DoseOutcome.skipped,
    );
    expect(doseGroupOf(skipped, now), DoseGroup.done);
  });

  test('a dose marked taken early gets no reminder at its time', () async {
    final person = await db.addProfile('ليلى');
    final at = DateTime(2026, 11, 3, 20);
    final id = await db.saveMedicine(
      profileId: person,
      name: 'شراب الحديد',
      startOn: DateTime(2026, 11, 1),
      endOn: DateTime(2026, 11, 3),
      schedule: const DoseScheduleInput(times: ['20:00']),
    );
    final regimens = await db.watchRegimens().first;
    final texts = ReminderTexts(AppLocalizationsAr(), discreet: false);
    expect(
      planReminders(regimens, const [], now: now, texts: texts),
      hasLength(1),
    );
    await db.logDose(id, at.toUtc(), DoseOutcome.taken, at: now);
    final logs = await db.watchMedicineDoseLogs(id).first;
    expect(planReminders(regimens, logs, now: now, texts: texts), isEmpty);
  });

  test('the parts of the day read the way the family says them', () {
    final l = AppLocalizationsAr();
    expect(dosePartOfDay(l, DateTime(2026, 11, 3, 8)), 'الصبح');
    expect(dosePartOfDay(l, DateTime(2026, 11, 3, 13)), 'الضهر');
    expect(dosePartOfDay(l, DateTime(2026, 11, 3, 16)), 'العصر');
    expect(dosePartOfDay(l, DateTime(2026, 11, 3, 20)), 'بالليل');
    expect(dosePartOfDay(l, DateTime(2026, 11, 3, 2)), 'بالليل');
  });
}
