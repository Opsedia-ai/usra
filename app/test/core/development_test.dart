import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:usra/core/database/app_database.dart';
import 'package:usra/core/design/tokens.dart';
import 'package:usra/features/children/infant_log.dart';
import 'package:usra/features/children/milestones.dart';

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

Milestone at(int months) => cdcMilestones.firstWhere((m) => m.months == months);

void main() {
  group('milestones', () {
    test('one per area at each CDC age from 2 months to 5 years', () {
      expect(milestoneAges, [2, 4, 6, 9, 12, 15, 18, 24, 30, 36, 48, 60]);
      for (final age in milestoneAges) {
        expect({
          for (final m in cdcMilestones)
            if (m.months == age) m.area,
        }, MilestoneArea.values.toSet());
      }
      expect({for (final m in cdcMilestones) m.id}, hasLength(48));
    });

    test('status by age', () {
      MilestoneState state(int months, double age, {bool ticked = false}) =>
          milestoneState(at(months), ageMonths: age, ticked: ticked);

      expect(state(6, 4.5), MilestoneState.upcoming);
      // Just reached: watch for it for a month.
      expect(state(6, 6.2), MilestoneState.watch);
      expect(state(6, 6.2).severity, Severity.headsUp);
      // A month past and not ticked: talk to the pediatrician.
      expect(state(6, 7.5), MilestoneState.late);
      expect(state(6, 7.5).severity, Severity.actSoon);
      expect(state(6, 7.5, ticked: true), MilestoneState.done);
      // Once the next age is reached, the earlier list stops nagging.
      expect(state(6, 9.5), MilestoneState.notTicked);
      expect(state(9, 9.5), MilestoneState.watch);
      expect(state(2, 1), MilestoneState.upcoming);
      expect(currentMilestoneAge(1.9), isNull);
      expect(currentMilestoneAge(27), 24);
    });

    test('ticks: earliest day, every record kept for unticking', () {
      final a = record(milestoneType, DateTime(2026, 5, 3), {
        milestoneField: 'm6_movement',
      });
      final b = record(milestoneType, DateTime(2026, 4, 1), {
        milestoneField: 'm6_movement',
      });
      final ticked = tickedMilestones([
        a,
        b,
        record('growth', DateTime(2026), {milestoneField: 'm2_social'}),
        record(milestoneType, DateTime(2026), {milestoneField: 3}),
      ]);
      expect(ticked.keys, ['m6_movement']);
      expect(ticked['m6_movement']!.date, DateTime(2026, 4, 1));
      expect(ticked['m6_movement']!.eventIds, [a.id, b.id]);
    });

    test('offered until the 6th birthday', () {
      final now = DateTime(2026, 11, 3);
      expect(showsMilestones(DateTime(2020, 11, 4), now), isTrue);
      expect(showsMilestones(DateTime(2020, 11, 3), now), isFalse);
      expect(showsMilestones(DateTime(2026, 12, 1), now), isFalse);
      expect(showsMilestones(null, now), isFalse);
    });
  });

  group('infant log', () {
    test('adds up one day', () {
      final day = DateTime(2026, 11, 3);
      DateTime at(int hour) => DateTime(2026, 11, 3, hour);
      final events = [
        record(InfantLog.feed, at(8), {InfantLog.kind: 'breast'}),
        record(InfantLog.feed, at(9), {
          InfantLog.kind: 'bottle',
          InfantLog.amountMl: 90,
        }),
        record(InfantLog.feed, at(10), {
          InfantLog.kind: 'bottle',
          InfantLog.amountMl: '?',
        }),
        record(InfantLog.feed, at(11), {InfantLog.kind: 'solids'}),
        record(InfantLog.sleep, at(12), {InfantLog.minutes: 90}),
        record(InfantLog.sleep, at(15), {InfantLog.minutes: 45}),
        record(InfantLog.diaper, at(13), {InfantLog.kind: 'wet'}),
        record(InfantLog.diaper, at(14), {InfantLog.kind: 'both'}),
        // Another day, and a record that isn't part of the log.
        record(InfantLog.diaper, DateTime(2026, 11, 2, 23), {
          InfantLog.kind: 'dirty',
        }),
        record('visit', at(9), const {}),
      ];
      final s = summarizeDay(events, day);
      expect((s.feeds, s.breast, s.bottle, s.solids), (4, 1, 2, 1));
      expect(s.bottleMl, 90);
      expect(s.sleepMinutes, 135);
      expect((s.wet, s.dirty), (2, 1));
      expect(entriesOn(events, day), hasLength(8));
      expect(summarizeDay(events, DateTime(2026, 11, 2)).dirty, 1);
    });

    test('for babies under one', () {
      final now = DateTime(2026, 11, 3);
      expect(isUnderOne(DateTime(2025, 11, 4), now), isTrue);
      expect(isUnderOne(DateTime(2025, 11, 3), now), isFalse);
      expect(isUnderOne(null, now), isFalse);
    });
  });
}
