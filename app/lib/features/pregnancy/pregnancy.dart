import 'dart:math' as math;

import '../../core/database/app_database.dart';
import '../../core/design/tokens.dart';
import '../../core/follow_ups/follow_up.dart';
import '../family/family_screen.dart' show ageInYears;
import '../follow_ups/rules/record_rules.dart' show dateField;

/// The pregnancy records' data keys.
abstract final class PregnancyFields {
  /// First day of the last menstrual period (`yyyy-MM-dd`).
  static const lmp = 'lmp';

  /// The due date the doctor gave, when known (`yyyy-MM-dd`).
  static const dueDate = 'dueDate';

  /// On `pregnancyEnd`: birth, loss or other.
  static const outcome = 'outcome';

  /// On `pregnancyCheck`.
  static const weightKg = 'weightKg';
  static const systolic = 'systolic';
  static const diastolic = 'diastolic';
}

abstract final class PregnancyTypes {
  static const start = 'pregnancy';
  static const end = 'pregnancyEnd';
  static const check = 'pregnancyCheck';
}

/// A full-term pregnancy counted from the last period: 40 weeks.
const pregnancyDays = 280;

/// Past this, a pregnancy with no outcome recorded is taken as over.
const maxPregnancyWeeks = 44;

/// Naegele's rule: the first day of the last period, plus seven days, minus
/// three months, plus a year.
DateTime naegeleDueDate(DateTime lmp) {
  final d = dayOf(lmp).add(const Duration(days: 7));
  final first = DateTime.utc(d.year, d.month + 9);
  final lastDay = DateTime.utc(first.year, first.month + 1, 0).day;
  return DateTime.utc(first.year, first.month, math.min(d.day, lastDay));
}

/// Whether the app offers pregnancy follow-up for [p]: women, and girls and
/// women of an age where pregnancy is possible when the birthday is known.
bool canBePregnant(Profile p, DateTime today) {
  if (p.sex != 'female') return false;
  final age = ageInYears(p.birthDate, today);
  return age == null || (age >= 10 && age <= 55);
}

/// One pregnancy, dated from the last period or the due date.
class Pregnancy {
  Pregnancy({required this.eventId, required this.dueDate, DateTime? start})
    : start = start ?? dueDate.subtract(const Duration(days: pregnancyDays));

  /// The `pregnancy` record it comes from.
  final String eventId;

  /// The estimated due date (UTC calendar date).
  final DateTime dueDate;

  /// Day 0 of the pregnancy: the last period, or 280 days before the due
  /// date when the doctor gave one (as doctors date it once a scan sets it).
  final DateTime start;

  /// Read from a `pregnancy` record: the due date wins when both are given,
  /// since a doctor's due date is usually corrected by a scan.
  static Pregnancy? fromRecord(String eventId, Map<String, Object?> data) {
    final due = dateField(data[PregnancyFields.dueDate]);
    final lmp = dateField(data[PregnancyFields.lmp]);
    if (due == null && lmp == null) return null;
    if (due != null) return Pregnancy(eventId: eventId, dueDate: dayOf(due));
    return Pregnancy(
      eventId: eventId,
      dueDate: naegeleDueDate(lmp!),
      start: dayOf(lmp),
    );
  }

  int daysOn(DateTime today) => dayOf(today).difference(start).inDays;

  /// Completed weeks and days, e.g. 24 weeks + 3 days.
  ({int weeks, int days}) ageOn(DateTime today) {
    final d = daysOn(today);
    return (weeks: d ~/ 7, days: d % 7);
  }

  /// 1st trimester: weeks 0-13; 2nd: 14-27; 3rd: 28 on.
  int trimesterOn(DateTime today) {
    final weeks = ageOn(today).weeks;
    return weeks < 14 ? 1 : (weeks < 28 ? 2 : 3);
  }

  /// The first day of pregnancy week [week].
  DateTime weekStart(int week) => start.add(Duration(days: week * 7));

  int daysLeft(DateTime today) => dueDate.difference(dayOf(today)).inDays;
}

/// The pregnancy still going on [today]: the latest `pregnancy` record with
/// no `pregnancyEnd` on or after its start, not in the future, and not past
/// [maxPregnancyWeeks].
Pregnancy? activePregnancy(Iterable<SubjectRecord> records, DateTime today) {
  Pregnancy? latest;
  final ends = <DateTime>[];
  for (final r in records) {
    if (r.event.type == PregnancyTypes.end) {
      ends.add(dayOf(r.event.occurredAt));
    } else if (r.event.type == PregnancyTypes.start) {
      final p = Pregnancy.fromRecord(r.event.id, r.data);
      if (p != null && (latest == null || p.start.isAfter(latest.start))) {
        latest = p;
      }
    }
  }
  if (latest == null) return null;
  final days = latest.daysOn(today);
  if (days < 0 || days > maxPregnancyWeeks * 7) return null;
  if (ends.any((e) => !e.isBefore(latest!.start))) return null;
  return latest;
}

/// One weight or blood-pressure reading, at a pregnancy week.
typedef PregnancyReading = ({
  double week,
  DateTime date,
  double? weightKg,
  int? systolic,
  int? diastolic,
});

/// The `pregnancyCheck` readings taken during [pregnancy], oldest first.
List<PregnancyReading> pregnancyReadings(
  Iterable<SubjectRecord> records,
  Pregnancy pregnancy,
) {
  int? whole(Object? v) => v is num && v > 0 ? v.round() : null;
  return [
    for (final r in records)
      if (r.event.type == PregnancyTypes.check)
        if (pregnancy.daysOn(r.event.occurredAt) case final d
            when d >= 0 && d <= maxPregnancyWeeks * 7)
          (
            week: d / 7,
            date: r.event.occurredAt,
            weightKg: switch (r.data[PregnancyFields.weightKg]) {
              final num w when w > 0 => w.toDouble(),
              _ => null,
            },
            systolic: whole(r.data[PregnancyFields.systolic]),
            diastolic: whole(r.data[PregnancyFields.diastolic]),
          ),
  ];
}

/// How a blood-pressure reading in pregnancy compares with WHO's thresholds
/// for hypertension (140/90) and severe hypertension (160/110). Informational
/// only: one reading never diagnoses anything.
enum BloodPressureLevel {
  usual(Severity.good),
  high(Severity.actSoon),
  veryHigh(Severity.urgent);

  const BloodPressureLevel(this.severity);

  final Severity severity;

  static BloodPressureLevel? of(int? systolic, int? diastolic) {
    if (systolic == null && diastolic == null) return null;
    final s = systolic ?? 0;
    final d = diastolic ?? 0;
    if (s >= 160 || d >= 110) return veryHigh;
    if (s >= 140 || d >= 90) return high;
    return usual;
  }
}
