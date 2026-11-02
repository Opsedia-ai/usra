import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usra/core/database/app_database.dart';
import 'package:usra/core/util/periods.dart';

void main() {
  group('periods', () {
    test('weeks start on Saturday', () {
      const week = SpendingPeriod.week;
      // Tuesday 3 Nov 2026.
      expect(week.startOf(DateTime(2026, 11, 3, 15)), DateTime(2026, 10, 31));
      // A Saturday starts its own week; the Friday after is still in it.
      expect(week.startOf(DateTime(2026, 10, 31)), DateTime(2026, 10, 31));
      expect(week.startOf(DateTime(2026, 11, 6, 23)), DateTime(2026, 10, 31));
      expect(week.startOf(DateTime(2026, 11, 7)), DateTime(2026, 11, 7));
      // Across a year end.
      expect(week.startOf(DateTime(2027, 1, 1)), DateTime(2026, 12, 26));
    });

    test('months and years, and shifting across the year end', () {
      expect(
        SpendingPeriod.month.startOf(DateTime(2026, 11, 30, 23)),
        DateTime(2026, 11),
      );
      expect(
        SpendingPeriod.month.shift(DateTime(2026, 11), 2),
        DateTime(2027, 1),
      );
      expect(
        SpendingPeriod.week.shift(DateTime(2026, 12, 26), 1),
        DateTime(2027, 1, 2),
      );
      expect(
        SpendingPeriod.year.startOf(DateTime(2026, 6, 15)),
        DateTime(2026),
      );
      expect(SpendingPeriod.month.boundsEndingAt(DateTime(2026, 2), 3), [
        DateTime(2025, 12),
        DateTime(2026, 1),
        DateTime(2026, 2),
        DateTime(2026, 3),
      ]);
    });
  });

  group('spending queries', () {
    late AppDatabase db;
    late String omar;
    late String mona;
    late String doctor;

    // The week of Saturday 31 Oct 2026 and the one before it.
    final bounds = SpendingPeriod.week.boundsEndingAt(
      DateTime(2026, 10, 31),
      2,
    );
    final thisWeek = (from: bounds[1], to: bounds[2]);

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      omar = await db.addProfile('Omar');
      mona = await db.addProfile('Mona');
      final gone = await db.addProfile('Gone');
      doctor = await db.saveDoctor(name: 'Dr. Hany');

      // Last week: Friday just before midnight.
      await db.addEvent(
        profileId: omar,
        type: 'visit',
        occurredAt: DateTime(2026, 10, 30, 23, 59),
        costMinor: 30000,
        currency: 'EGP',
        doctorId: doctor,
      );
      // This week, on its first and last moments.
      await db.addEvent(
        profileId: omar,
        type: 'lab',
        occurredAt: DateTime(2026, 10, 31),
        costMinor: 10000,
        currency: 'EGP',
      );
      await db.addEvent(
        profileId: omar,
        type: 'visit',
        occurredAt: DateTime(2026, 11, 6, 23, 59),
        costMinor: 45000,
        currency: 'EGP',
        doctorId: doctor,
      );
      await db.addEvent(
        profileId: mona,
        type: 'visit',
        occurredAt: DateTime(2026, 11, 2),
        costMinor: 20000,
        // No currency saved counts as pounds.
      );
      // Next Saturday belongs to next week.
      await db.addEvent(
        profileId: mona,
        type: 'scan',
        occurredAt: DateTime(2026, 11, 7),
        costMinor: 99900,
        currency: 'EGP',
      );

      // None of these count.
      final deleted = await db.addEvent(
        profileId: omar,
        type: 'scan',
        occurredAt: DateTime(2026, 11, 1),
        costMinor: 50000,
        currency: 'EGP',
      );
      await db.softDeleteEvent(deleted);
      await db.addEvent(
        profileId: omar,
        type: 'vaccine',
        occurredAt: DateTime(2026, 11, 1),
      );
      await db.addEvent(
        profileId: mona,
        type: 'visit',
        occurredAt: DateTime(2026, 11, 1),
        costMinor: 7000,
        currency: 'USD',
      );
      await db.addEvent(
        profileId: gone,
        type: 'visit',
        occurredAt: DateTime(2026, 11, 1),
        costMinor: 80000,
        currency: 'EGP',
        doctorId: doctor,
      );
      await db.softDeleteProfile(gone);
    });
    tearDown(() => db.close());

    test('totals per period include both boundaries correctly', () async {
      expect(await db.watchSpendingTotals(bounds).first, [30000, 75000]);
      expect(await db.watchSpendingTotals(bounds, profileId: omar).first, [
        30000,
        55000,
      ]);
      expect(await db.watchSpendingTotals(bounds, profileId: mona).first, [
        0,
        20000,
      ]);
    });

    test('months and years split on calendar boundaries', () async {
      final month = SpendingPeriod.month.boundsEndingAt(DateTime(2026, 11), 2);
      expect(await db.watchSpendingTotals(month).first, [40000, 164900]);
      final year = SpendingPeriod.year.boundsEndingAt(DateTime(2026), 1);
      expect(await db.watchSpendingTotals(year).first, [204900]);
    });

    test('split by type, person and doctor', () async {
      List<(String, String?, int, int)> rows(List<SpendingSlice> s) => [
        for (final x in s) (x.key, x.label, x.totalMinor, x.count),
      ];

      final byType = await db
          .watchSpendingBy(
            SpendingGroup.type,
            from: thisWeek.from,
            to: thisWeek.to,
          )
          .first;
      expect(rows(byType), [
        ('visit', null, 65000, 2),
        ('lab', null, 10000, 1),
      ]);

      final byPerson = await db
          .watchSpendingBy(
            SpendingGroup.person,
            from: thisWeek.from,
            to: thisWeek.to,
          )
          .first;
      expect(rows(byPerson), [
        (omar, 'Omar', 55000, 2),
        (mona, 'Mona', 20000, 1),
      ]);

      final byDoctor = await db
          .watchSpendingBy(
            SpendingGroup.doctor,
            from: bounds.first,
            to: bounds.last,
          )
          .first;
      expect(rows(byDoctor), [(doctor, 'Dr. Hany', 75000, 2)]);

      // A removed doctor keeps their name in the split.
      await db.softDeleteDoctor(doctor);
      final omarOnly = await db
          .watchSpendingBy(
            SpendingGroup.doctor,
            from: bounds.first,
            to: bounds.last,
            profileId: omar,
          )
          .first;
      expect(rows(omarOnly), [(doctor, 'Dr. Hany', 75000, 2)]);
    });

    test('the totals update when a record is added', () async {
      final totals = db.watchSpendingTotals(bounds, profileId: mona);
      expect(await totals.first, [0, 20000]);
      await db.addEvent(
        profileId: mona,
        type: 'lab',
        occurredAt: DateTime(2026, 10, 25),
        costMinor: 1500,
        currency: 'EGP',
      );
      expect(await totals.first, [1500, 20000]);
    });
  });
}
