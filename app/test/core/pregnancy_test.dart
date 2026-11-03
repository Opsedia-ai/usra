import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:usra/core/database/app_database.dart';
import 'package:usra/core/design/tokens.dart';
import 'package:usra/core/follow_ups/follow_up.dart';
import 'package:usra/features/pregnancy/antenatal_schedule.dart';
import 'package:usra/features/pregnancy/pregnancy.dart';

final today = DateTime(2026, 11, 3);

Profile woman({DateTime? birth, String? sex = 'female'}) => Profile(
  id: 'p1',
  displayName: 'منى',
  birthDate: birth ?? DateTime(1995, 1, 1),
  sex: sex,
  simpleMode: false,
  updatedAt: today,
);

var _ids = 0;

MedicalEvent record(String type, DateTime on, Map<String, Object?> data) =>
    MedicalEvent(
      id: 'e${_ids++}',
      profileId: 'p1',
      type: type,
      occurredAt: on,
      dataJson: jsonEncode(data),
      updatedAt: on,
    );

String iso(DateTime d) => d.toIso8601String().substring(0, 10);

/// A pregnancy record whose last period was [weeks] weeks before [today].
MedicalEvent pregnantFor(int weeks, {int days = 0}) => record(
  PregnancyTypes.start,
  today,
  {PregnancyFields.lmp: iso(today.subtract(Duration(days: weeks * 7 + days)))},
);

List<SubjectRecord> recs(List<MedicalEvent> events, [Profile? p]) =>
    FollowUpSubject(p ?? woman(), events).records;

void main() {
  group('due date', () {
    test("Naegele's rule: +7 days, -3 months, +1 year", () {
      expect(naegeleDueDate(DateTime(2026, 5, 1)), DateTime.utc(2027, 2, 8));
      expect(naegeleDueDate(DateTime(2026, 1, 10)), DateTime.utc(2026, 10, 17));
      // The 31st of a 30-day month becomes its last day.
      expect(naegeleDueDate(DateTime(2026, 7, 24)), DateTime.utc(2027, 4, 30));
      expect(naegeleDueDate(DateTime(2026, 5, 24)), DateTime.utc(2027, 2, 28));
    });

    test('weeks, trimester and days left from the last period', () {
      final p = Pregnancy.fromRecord('e', {
        PregnancyFields.lmp: iso(today.subtract(const Duration(days: 171))),
      })!;
      expect(p.ageOn(today), (weeks: 24, days: 3));
      expect(p.trimesterOn(today), 2);
      expect(p.daysLeft(today), greaterThan(100));
      expect(p.trimesterOn(today.subtract(const Duration(days: 80))), 1);
      expect(p.trimesterOn(today.add(const Duration(days: 30))), 3);
    });

    test("the doctor's due date wins over the last period", () {
      final p = Pregnancy.fromRecord('e', {
        PregnancyFields.lmp: '2026-01-01',
        PregnancyFields.dueDate: '2027-01-30',
      })!;
      expect(p.dueDate, DateTime.utc(2027, 1, 30));
      // 280 days before the due date.
      expect(p.start, DateTime.utc(2026, 4, 25));
      expect(Pregnancy.fromRecord('e', const {}), isNull);
      expect(Pregnancy.fromRecord('e', {PregnancyFields.lmp: 'x'}), isNull);
    });
  });

  group('active pregnancy', () {
    test('the latest one, until an outcome or 44 weeks', () {
      final now = pregnantFor(10);
      expect(activePregnancy(recs([now]), today)!.eventId, now.id);

      final old = record(PregnancyTypes.start, DateTime(2024, 1, 1), {
        PregnancyFields.lmp: '2024-01-01',
      });
      final oldEnd = record(PregnancyTypes.end, DateTime(2024, 9, 30), {
        PregnancyFields.outcome: 'birth',
      });
      // An earlier birth doesn't end this pregnancy.
      expect(activePregnancy(recs([old, oldEnd, now]), today)!.eventId, now.id);
      // An outcome on or after its start does.
      final end = record(PregnancyTypes.end, today, {
        PregnancyFields.outcome: 'loss',
      });
      expect(activePregnancy(recs([now, end]), today), isNull);
      // Too long ago with no outcome: taken as over.
      expect(activePregnancy(recs([pregnantFor(45)]), today), isNull);
      expect(activePregnancy(recs([old]), today), isNull);
    });

    test('women of a possible age only', () {
      expect(canBePregnant(woman(), today), isTrue);
      expect(canBePregnant(woman(sex: 'male'), today), isFalse);
      expect(canBePregnant(woman(sex: null), today), isFalse);
      expect(canBePregnant(woman(birth: DateTime(2020)), today), isFalse);
      expect(canBePregnant(woman(birth: DateTime(1950)), today), isFalse);
    });
  });

  group('blood pressure', () {
    test("WHO's 140/90 and 160/110", () {
      expect(BloodPressureLevel.of(null, null), isNull);
      expect(BloodPressureLevel.of(120, 80), BloodPressureLevel.usual);
      expect(BloodPressureLevel.of(140, 80), BloodPressureLevel.high);
      expect(BloodPressureLevel.of(null, 95), BloodPressureLevel.high);
      expect(BloodPressureLevel.of(150, 112), BloodPressureLevel.veryHigh);
      expect(BloodPressureLevel.veryHigh.severity, Severity.urgent);
    });
  });

  group('antenatal schedule', () {
    test('eight WHO contacts at the recommended weeks', () {
      final contacts = [
        for (final i in ancSchedule)
          if (i.kind == AncKind.contact) i.week,
      ];
      expect(contacts, [12, 20, 26, 30, 34, 36, 38, 40]);
    });

    test('records in the window close an item; keywords pick labs', () {
      final preg = pregnantFor(29);
      final p = activePregnancy(recs([preg]), today)!;
      DateTime week(int w) => p.weekStart(w).add(const Duration(days: 1));
      final events = [
        preg,
        record('visit', week(13), {'doctorName': 'د. سامي'}),
        record('scan', week(20), {'kind': 'ultrasound'}),
        // A scan that isn't an ultrasound doesn't count.
        record('scan', week(12), {'kind': 'xray'}),
        record('lab', week(25), {'test': 'منحنى السكر'}),
        // A lab outside the window doesn't count.
        record('lab', week(20), {'test': 'CBC'}),
      ];
      final states = {
        for (final s in ancStatuses(p, recs(events), today)) s.item.id: s.state,
      };
      expect(states['contact1'], AncState.done);
      expect(states['anomalyScan'], AncState.done);
      expect(states['firstScan'], AncState.missed);
      expect(states['glucoseTest'], AncState.done);
      expect(states['bloodCount'], AncState.open);
      expect(states['contact2'], AncState.missed);
      expect(states['contact8'], AncState.open);
    });

    test('the rule shows what is due soon or just overdue', () {
      // Week 25 + 0: contact 3 (week 26) and the glucose test (24-28) due,
      // the blood count (28) coming up; the anomaly scan window closed
      // more than two weeks ago.
      final events = [pregnantFor(25)];
      final items = const AncScheduleRule().evaluate(
        FollowUpSubject(woman(), events),
        today,
      );
      final ids = [for (final f in items) f.ruleId];
      expect(
        ids,
        containsAll([
          'pregnancy.anc.glucoseTest',
          'pregnancy.anc.contact3',
          'pregnancy.anc.bloodCount',
        ]),
      );
      expect(ids, isNot(contains('pregnancy.anc.anomalyScan')));
      expect(ids, isNot(contains('pregnancy.anc.contact8')));
      final glucose = items.firstWhere(
        (f) => f.ruleId == 'pregnancy.anc.glucoseTest',
      );
      expect(glucose.severityOn(today), Severity.headsUp);
      expect(glucose.recordType, 'lab');

      // Week 23 + 3 with no visit since week 17: contact 2 is overdue.
      final late = const AncScheduleRule().evaluate(
        FollowUpSubject(woman(), [pregnantFor(24, days: 1)]),
        today,
      );
      expect(
        late
            .firstWhere((f) => f.ruleId == 'pregnancy.anc.contact2')
            .severityOn(today),
        Severity.actSoon,
      );
    });

    test('nothing for men or without a pregnancy', () {
      const rule = AncScheduleRule();
      expect(rule.evaluate(FollowUpSubject(woman(), []), today), isEmpty);
      expect(
        rule.evaluate(
          FollowUpSubject(woman(sex: 'male'), [pregnantFor(20)]),
          today,
        ),
        isEmpty,
      );
    });
  });

  group('readings', () {
    test('weight and blood pressure by pregnancy week', () {
      final preg = pregnantFor(20);
      final p = activePregnancy(recs([preg]), today)!;
      final events = [
        preg,
        record(PregnancyTypes.check, p.weekStart(14), {
          PregnancyFields.weightKg: 68.5,
          PregnancyFields.systolic: 118,
          PregnancyFields.diastolic: 76,
        }),
        record(PregnancyTypes.check, p.weekStart(18), {
          PregnancyFields.systolic: 'bad',
        }),
        // Before this pregnancy.
        record(PregnancyTypes.check, DateTime(2020), {
          PregnancyFields.weightKg: 60,
        }),
      ];
      final readings = pregnancyReadings(recs(events), p);
      expect(readings, hasLength(2));
      expect(readings.first.week, 14);
      expect(readings.first.weightKg, 68.5);
      expect(readings.last.systolic, isNull);
    });
  });
}
