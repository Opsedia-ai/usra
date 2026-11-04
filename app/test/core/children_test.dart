import 'package:flutter_test/flutter_test.dart';
import 'package:usra/core/design/tokens.dart';
import 'package:usra/features/children/children_module.dart';
import 'package:usra/features/children/egypt_vaccines.dart';
import 'package:usra/features/children/growth.dart';
import 'package:usra/features/children/who_growth_data.dart' show Lms;

void main() {
  group('WHO LMS maths', () {
    Lms lms(GrowthIndicator i, bool male, double months) =>
        whoLms(i, male: male, months: months)!;

    test('boys weight at birth matches the WHO percentile table', () {
      final birth = lms(GrowthIndicator.weight, true, 0);
      // WHO/CDC table: 5th 2.603994, 50th 3.3464, 95th 4.214527 kg.
      expect(lmsValue(birth, -1.644854), closeTo(2.603994, 1e-4));
      expect(lmsValue(birth, 0), 3.3464);
      expect(lmsZScore(birth, 4.214527), closeTo(1.644854, 1e-4));
      expect(zToPercentile(lmsZScore(birth, 4.214527)), closeTo(95, 0.01));
    });

    test('girls length at 12 months matches the WHO percentile table', () {
      final m12 = lms(GrowthIndicator.height, false, 12);
      // 2nd (z = -2) 68.8650363, 25th 72.2782, 98th 79.1649637 cm.
      expect(lmsValue(m12, -2), closeTo(68.865, 1e-3));
      expect(zToPercentile(lmsZScore(m12, 72.2782)), closeTo(25, 0.01));
      expect(lmsZScore(m12, 79.1649637), closeTo(2, 1e-4));
    });

    test('at 5 years: boys weight and girls height SD lines', () {
      final w = lms(GrowthIndicator.weight, true, 60);
      // WHO z-score table, rounded to 0.1: -2 SD 14.1, +2 SD 24.2 kg.
      expect(lmsValue(w, -2), closeTo(14.1, 0.05));
      expect(lmsValue(w, 2), closeTo(24.2, 0.05));
      final h = lms(GrowthIndicator.height, false, 60);
      expect(lmsValue(h, 3), closeTo(123.7, 0.05));
    });

    test('height is used from 24 months, length before', () {
      expect(lms(GrowthIndicator.height, true, 23.99).$2, closeTo(87.8, 0.1));
      expect(lms(GrowthIndicator.height, true, 24).$2, 87.1161);
    });

    test('ages between months are interpolated', () {
      final a = lms(GrowthIndicator.weight, true, 0);
      final b = lms(GrowthIndicator.weight, true, 1);
      expect(lms(GrowthIndicator.weight, true, 0.5).$2, (a.$2 + b.$2) / 2);
    });

    test('outside 0-60 months there is no reading', () {
      expect(whoLms(GrowthIndicator.weight, male: true, months: -1), isNull);
      expect(whoLms(GrowthIndicator.weight, male: true, months: 61), isNull);
    });

    test('weight beyond 3 SD uses the WHO adjustment', () {
      final w = lms(GrowthIndicator.weight, true, 60);
      final sd2 = lmsValue(w, 2), sd3 = lmsValue(w, 3);
      expect(lmsZScore(w, sd3 + (sd3 - sd2)), closeTo(4, 1e-9));
      final sdm2 = lmsValue(w, -2), sdm3 = lmsValue(w, -3);
      expect(lmsZScore(w, sdm3 - (sdm2 - sdm3)), closeTo(-4, 1e-9));
    });

    test('percentiles of standard z-scores', () {
      expect(zToPercentile(0), closeTo(50, 1e-6));
      expect(zToPercentile(1.880794), closeTo(97, 1e-3));
      expect(zToPercentile(-1.880794), closeTo(3, 1e-3));
    });

    test('status: 3rd to 97th is good, outside is act soon', () {
      GrowthReading read(double kg) =>
          readGrowth(GrowthIndicator.weight, male: true, months: 0, value: kg)!;
      expect(read(3.3).severity, Severity.good);
      expect(read(3.3).percentileLabel, '46');
      expect(read(2.0).severity, Severity.actSoon);
      expect(read(2.0).percentileLabel, '<1');
      expect(read(5.0).severity, Severity.actSoon);
      expect(
        readGrowth(GrowthIndicator.weight, male: true, months: 0, value: 0),
        isNull,
      );
    });
  });

  test('a growth record needs at least one measurement', () {
    final growth = const ChildrenModule().recordTypes.firstWhere(
      (t) => t.key == 'growth',
    );
    expect(growth.validate({}), isNotEmpty);
    expect(growth.validate({'heightCm': 70}), isEmpty);
  });

  group('dates', () {
    test('addMonths keeps the day, or the month end', () {
      expect(addMonths(DateTime(2026, 1, 31), 1), DateTime(2026, 2, 28));
      expect(addMonths(DateTime(2027, 12, 31), 2), DateTime(2028, 2, 29));
      expect(addMonths(DateTime(2026, 3, 15), 18), DateTime(2027, 9, 15));
    });

    test('isUnderFive', () {
      final now = DateTime(2026, 11, 3);
      expect(isUnderFive(DateTime(2021, 11, 4), now), isTrue);
      expect(isUnderFive(DateTime(2021, 11, 3), now), isFalse);
      expect(isUnderFive(DateTime(2026, 11, 3), now), isTrue);
      expect(isUnderFive(DateTime(2026, 11, 4), now), isFalse);
      expect(isUnderFive(null, now), isFalse);
    });
  });

  group('vaccine names', () {
    test('Arabic and English names map to the schedule', () {
      expect(vaccineKindsOf('شلل أطفال'), {VaccineKind.opv});
      expect(vaccineKindsOf('نقط شلل الأطفال (سابين)'), {VaccineKind.opv});
      expect(vaccineKindsOf('سولك'), {VaccineKind.ipv});
      expect(vaccineKindsOf('IPV'), {VaccineKind.ipv});
      expect(vaccineKindsOf('الخماسي'), {VaccineKind.penta});
      expect(vaccineKindsOf('Hexavalent'), {
        VaccineKind.hexa,
        VaccineKind.penta,
        VaccineKind.ipv,
      });
      expect(vaccineKindsOf('الثلاثي الفيروسي'), {VaccineKind.mmr});
      expect(vaccineKindsOf('الحصبة'), {VaccineKind.mmr});
      expect(vaccineKindsOf('الثلاثي البكتيري'), {VaccineKind.dtp});
      expect(vaccineKindsOf('الالتهاب الكبدي ب'), {VaccineKind.hepB});
      expect(vaccineKindsOf('بي سي جي'), {VaccineKind.bcg});
      expect(vaccineKindsOf('BCG'), {VaccineKind.bcg});
      expect(vaccineKindsOf('شلل الأطفال بالحقن'), {VaccineKind.ipv});
      expect(vaccineKindsOf('شلل اطفال حقن'), {VaccineKind.ipv});
      expect(vaccineKindsOf('Polio injection'), {VaccineKind.ipv});
      expect(vaccineKindsOf('Flu'), {VaccineKind.flu});
      expect(vaccineKindsOf('Measles vitamin'), {VaccineKind.mmr});
      expect(vaccineKindsOf('vitamin A'), isEmpty);
      expect(vaccineKindsOf('  '), isEmpty);
    });
  });

  group('schedule matching', () {
    final birth = DateTime(2026, 1, 1);
    Map<String, DoseState> states(List<VaccineRecord> records, DateTime now) =>
        {
          for (final s in matchSchedule(
            birthDate: birth,
            records: records,
            now: now,
          ))
            '${s.dose.kind.name}${s.dose.dose}': s.state,
        };

    test('done, overdue, due and later', () {
      final s = states([
        (id: null, name: 'BCG', dose: null, date: DateTime(2026, 1, 2)),
        (id: null, name: 'شلل', dose: null, date: DateTime(2026, 1, 2)),
        (id: null, name: 'خماسي', dose: 1, date: DateTime(2026, 3, 1)),
        (id: null, name: 'شلل', dose: null, date: DateTime(2026, 3, 1)),
      ], DateTime(2026, 5, 10));
      expect(s['bcg1'], DoseState.done);
      expect(s['opv0'], DoseState.done);
      expect(s['opv1'], DoseState.done);
      expect(s['penta1'], DoseState.done);
      expect(s['hepB0'], DoseState.overdue);
      expect(s['ipv1'], DoseState.overdue); // due 1 March, 70 days ago
      expect(s['penta2'], DoseState.due); // due 1 May, 9 days ago
      expect(s['opv3'], DoseState.later); // due 1 July
      expect(s['mmr2'], DoseState.later);
    });

    test('due two weeks before the date, overdue a month after', () {
      expect(states([], DateTime(2026, 2, 15))['penta1'], DoseState.due);
      expect(states([], DateTime(2026, 2, 14))['penta1'], DoseState.later);
      expect(states([], DateTime(2026, 3, 31))['penta1'], DoseState.due);
      expect(states([], DateTime(2026, 4, 1))['penta1'], DoseState.overdue);
    });

    test('a numbered dose takes that dose, unnumbered fill the earliest', () {
      final s = states([
        (id: null, name: 'MMR', dose: 2, date: DateTime(2027, 7, 1)),
        (id: null, name: 'Pentavalent', dose: null, date: DateTime(2026, 3, 1)),
        (id: null, name: 'Pentavalent', dose: null, date: DateTime(2026, 5, 1)),
      ], DateTime(2027, 7, 2));
      expect(s['mmr1'], DoseState.overdue);
      expect(s['mmr2'], DoseState.done);
      expect(s['penta1'], DoseState.done);
      expect(s['penta2'], DoseState.done);
      expect(s['penta3'], DoseState.overdue);
    });

    test('a hexavalent dose counts for pentavalent and IPV', () {
      final s = states([
        (id: null, name: 'Hexa', dose: 1, date: DateTime(2026, 3, 1)),
      ], DateTime(2026, 3, 2));
      expect(s['penta1'], DoseState.done);
      expect(s['ipv1'], DoseState.done);
    });

    test('a numbered dose recorded twice is not the next dose', () {
      final s = states([
        (id: null, name: 'IPV', dose: 1, date: DateTime(2026, 3, 1)),
        (id: null, name: 'IPV', dose: 1, date: DateTime(2026, 3, 2)),
      ], DateTime(2026, 3, 3));
      expect(s['ipv1'], DoseState.done);
      expect(s['ipv2'], DoseState.later);
    });
  });
}
