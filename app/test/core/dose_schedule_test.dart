import 'package:flutter_test/flutter_test.dart';
import 'package:usra/features/medicines/dose_schedule.dart';

void main() {
  const eight = DoseTime(8, 0);
  const eightPm = DoseTime(20, 0);

  group('DoseTime', () {
    test('parses HH:mm and refuses anything else', () {
      expect(DoseTime.tryParse('08:05'), const DoseTime(8, 5));
      expect(DoseTime.tryParse('8:05'), const DoseTime(8, 5));
      expect(DoseTime.tryParse('24:00'), isNull);
      expect(DoseTime.tryParse('12:60'), isNull);
      expect(DoseTime.tryParse('noon'), isNull);
    });

    test('a stored list is sorted, without repeats or junk', () {
      expect(DoseTime.parseList('20:00,08:00,08:00,x'), [eight, eightPm]);
      expect(DoseTime.parseList(''), isEmpty);
      expect(const DoseTime(7, 5).key, '07:05');
    });
  });

  group('occurrencesBetween', () {
    test('every day at each time, from inclusive to exclusive', () {
      final rule = DoseRule(
        times: [eightPm, eight],
        startOn: DateTime(2026, 3, 1),
      );
      final doses = rule.occurrencesBetween(
        DateTime(2026, 3, 1, 8),
        DateTime(2026, 3, 2, 20),
      );
      expect(doses, [
        DateTime(2026, 3, 1, 8),
        DateTime(2026, 3, 1, 20),
        DateTime(2026, 3, 2, 8),
      ]);
    });

    test('nothing before the first day or after the last', () {
      final rule = DoseRule(
        times: [eight],
        startOn: DateTime(2026, 3, 2),
        endOn: DateTime(2026, 3, 4),
      );
      final doses = rule.occurrencesBetween(
        DateTime(2026, 3, 1),
        DateTime(2026, 3, 10),
      );
      expect(doses, [
        DateTime(2026, 3, 2, 8),
        DateTime(2026, 3, 3, 8),
        DateTime(2026, 3, 4, 8),
      ]);
    });

    test('every N days counts from the first day, across months', () {
      final rule = DoseRule(
        times: [eight],
        startOn: DateTime(2026, 1, 30),
        everyNDays: 3,
      );
      final doses = rule.occurrencesBetween(
        DateTime(2026, 1, 29),
        DateTime(2026, 2, 9),
      );
      expect(doses, [
        DateTime(2026, 1, 30, 8),
        DateTime(2026, 2, 2, 8),
        DateTime(2026, 2, 5, 8),
        DateTime(2026, 2, 8, 8),
      ]);
    });

    test('only on the chosen weekdays', () {
      // Monday and Thursday.
      final rule = DoseRule(
        times: [eight],
        startOn: DateTime(2026, 1, 1),
        weekdays: 1 << 0 | 1 << 3,
      );
      final doses = rule.occurrencesBetween(
        DateTime(2026, 11, 2), // a Monday
        DateTime(2026, 11, 16),
      );
      expect(doses.map((d) => d.weekday), [
        DateTime.monday,
        DateTime.thursday,
        DateTime.monday,
        DateTime.thursday,
      ]);
      expect(doses.first, DateTime(2026, 11, 2, 8));
    });

    test('stays at the same local time across a whole year', () {
      // Covers any daylight saving change in the machine's time zone.
      final rule = DoseRule(times: [eight], startOn: DateTime(2026, 1, 1));
      final doses = rule.occurrencesBetween(
        DateTime(2026, 1, 1),
        DateTime(2027, 1, 1),
      );
      expect(doses, hasLength(365));
      expect(doses.every((d) => d.hour == 8 && d.minute == 0), isTrue);
      expect(
        doses.map((d) => DateTime(d.year, d.month, d.day)).toSet(),
        hasLength(365),
      );
    });

    test('accepts UTC bounds and answers in local time', () {
      final rule = DoseRule(times: [eight], startOn: DateTime(2026, 3, 1));
      final from = DateTime(2026, 3, 5);
      final doses = rule.occurrencesBetween(
        from.toUtc(),
        from.add(const Duration(days: 1)).toUtc(),
      );
      expect(doses, [DateTime(2026, 3, 5, 8)]);
      expect(doses.single.isUtc, isFalse);
    });

    test('no times, no doses', () {
      final rule = DoseRule(times: const [], startOn: DateTime(2026));
      expect(rule.occurrencesBetween(DateTime(2026), DateTime(2027)), isEmpty);
      expect(rule.nextAfter(DateTime(2026)), isNull);
    });
  });

  group('nextAfter', () {
    test('later today, else the first time tomorrow', () {
      final rule = DoseRule(
        times: [eight, eightPm],
        startOn: DateTime(2026, 3, 1),
      );
      expect(rule.nextAfter(DateTime(2026, 3, 3, 9)), DateTime(2026, 3, 3, 20));
      expect(rule.nextAfter(DateTime(2026, 3, 3, 20)), DateTime(2026, 3, 4, 8));
    });

    test('waits for the first day', () {
      final rule = DoseRule(times: [eight], startOn: DateTime(2026, 6, 1));
      expect(rule.nextAfter(DateTime(2026, 5, 1)), DateTime(2026, 6, 1, 8));
    });

    test('skips to the next every-N day', () {
      final rule = DoseRule(
        times: [eight],
        startOn: DateTime(2026, 3, 1),
        everyNDays: 7,
      );
      expect(rule.nextAfter(DateTime(2026, 3, 1, 9)), DateTime(2026, 3, 8, 8));
    });

    test('none once the last day has passed', () {
      final rule = DoseRule(
        times: [eight],
        startOn: DateTime(2026, 3, 1),
        endOn: DateTime(2026, 3, 5),
      );
      expect(rule.nextAfter(DateTime(2026, 3, 5, 7)), DateTime(2026, 3, 5, 8));
      expect(rule.nextAfter(DateTime(2026, 3, 5, 8)), isNull);
    });
  });
}
