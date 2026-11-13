import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usra/core/database/app_database.dart';
import 'package:usra/features/family/person_status.dart';
import 'package:usra/features/medicines/dose_schedule.dart';

/// A UUID version 7 made at [at], the way medicine ids are.
String idMadeAt(DateTime at) {
  final hex = at.millisecondsSinceEpoch.toRadixString(16).padLeft(12, '0');
  return '${hex.substring(0, 8)}-${hex.substring(8)}-7abc-8def-0123456789ab';
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
  });
  tearDown(() => db.close());

  /// The doses on [day] of a twice-daily medicine (08:00 and 20:00) whose
  /// first day is [startOn], added at [addedAt]. The clock is fixed: every
  /// time here is given, none read from the phone.
  Future<List<PlannedDose>> dosesOn(
    DateTime day, {
    required DateTime startOn,
    required DateTime addedAt,
    List<DoseLog> Function(String id)? logs,
  }) async {
    final person = await db.addProfile('بنتي');
    await db.saveMedicine(
      profileId: person,
      name: 'أموكسيسيلين',
      startOn: startOn,
      schedule: const DoseScheduleInput(times: ['08:00', '20:00']),
    );
    final r = (await db.watchRegimens().first).single;
    final id = idMadeAt(addedAt);
    final regimen = Regimen(
      medicine: r.medicine.copyWith(id: id),
      schedule: r.schedule,
      person: r.person,
    );
    return plannedDoses(
      [regimen],
      logs?.call(id) ?? const [],
      from: DateTime(day.year, day.month, day.day),
      to: DateTime(day.year, day.month, day.day + 1),
    );
  }

  test('reads when a medicine was added from its id', () {
    final at = DateTime(2026, 11, 12, 10);
    expect(medicineAddedAt(idMadeAt(at)), at);
    expect(medicineAddedAt('m1'), isNull);
    // Version 4: random, no time in it.
    expect(medicineAddedAt('0f8fad5b-d9cb-469f-a165-70867728950e'), isNull);
  });

  test(
    'added at 10:00 on its first day, the 08:00 dose is not missed',
    () async {
      final now = DateTime(2026, 11, 12, 10, 30);
      final doses = await dosesOn(
        now,
        startOn: DateTime(2026, 11, 12),
        addedAt: DateTime(2026, 11, 12, 10),
      );
      expect(doses.map((d) => d.at), [DateTime(2026, 11, 12, 20)]);
      expect(doses.any((d) => isDoseMissed(d, now)), isFalse);
      // The 20:00 dose can still be missed as usual.
      expect(isDoseMissed(doses.single, DateTime(2026, 11, 12, 21, 1)), isTrue);
    },
  );

  test('the next day has both doses', () async {
    final doses = await dosesOn(
      DateTime(2026, 11, 13),
      startOn: DateTime(2026, 11, 12),
      addedAt: DateTime(2026, 11, 12, 10),
    );
    expect(doses.map((d) => d.at), [
      DateTime(2026, 11, 13, 8),
      DateTime(2026, 11, 13, 20),
    ]);
  });

  test('a first day in the past keeps every dose, today too', () async {
    final now = DateTime(2026, 11, 12, 10, 30);
    final doses = await dosesOn(
      now,
      startOn: DateTime(2026, 11, 10),
      addedAt: DateTime(2026, 11, 12, 10),
    );
    expect(doses.map((d) => d.at), [
      DateTime(2026, 11, 12, 8),
      DateTime(2026, 11, 12, 20),
    ]);
    expect(isDoseMissed(doses.first, now), isTrue);
  });

  test('a dose already logged still shows', () async {
    final doses = await dosesOn(
      DateTime(2026, 11, 12),
      startOn: DateTime(2026, 11, 12),
      addedAt: DateTime(2026, 11, 12, 10),
      logs: (id) => [
        DoseLog(
          id: 'l1',
          medicineId: id,
          scheduledAt: DateTime(2026, 11, 12, 8).toUtc(),
          status: DoseOutcome.taken,
          at: DateTime(2026, 11, 12, 8, 5).toUtc(),
          updatedAt: DateTime(2026, 11, 12, 10, 1).toUtc(),
        ),
      ],
    );
    expect(doses.map((d) => d.at), [
      DateTime(2026, 11, 12, 8),
      DateTime(2026, 11, 12, 20),
    ]);
    expect(doses.first.isDone, isTrue);
  });
}
