import 'dart:math' as math;

import '../../core/design/tokens.dart';
import 'who_growth_data.dart';

/// Children are followed on the WHO charts until their 5th birthday.
const whoMaxMonths = 60;

/// What a growth chart measures.
enum GrowthIndicator { weight, height }

/// The growth record's data keys.
abstract final class GrowthFields {
  static const weightKg = 'weightKg';
  static const heightCm = 'heightCm';
  static const headCm = 'headCm';

  static String of(GrowthIndicator i) => switch (i) {
    GrowthIndicator.weight => weightKg,
    GrowthIndicator.height => heightCm,
  };
}

/// Percentile lines drawn on the charts, with their z-scores.
const chartPercentiles = <(int, double)>[
  (3, -1.880794),
  (15, -1.036433),
  (50, 0),
  (85, 1.036433),
  (97, 1.880794),
];

/// Calendar date of [date] in UTC, so day counts ignore clock changes.
DateTime _day(DateTime date) => DateTime.utc(date.year, date.month, date.day);

/// Age in (fractional) months at [on]; WHO's month is 30.4375 days.
double ageInMonths(DateTime birthDate, DateTime on) =>
    _day(on).difference(_day(birthDate)).inDays / 30.4375;

/// [months] calendar months after [date]; the 31st becomes the month's end.
DateTime addMonths(DateTime date, int months) {
  final first = DateTime(date.year, date.month + months);
  final lastDay = DateTime(first.year, first.month + 1, 0).day;
  return DateTime(first.year, first.month, math.min(date.day, lastDay));
}

/// Whether someone born on [birthDate] is under 5 on [now].
bool isUnderFive(DateTime? birthDate, DateTime now) =>
    birthDate != null &&
    !_day(birthDate).isAfter(_day(now)) &&
    _day(now).isBefore(_day(addMonths(birthDate, whoMaxMonths)));

/// The WHO LMS parameters at [months] of age, interpolated between months;
/// null outside 0-60 months.
Lms? whoLms(
  GrowthIndicator indicator, {
  required bool male,
  required double months,
}) {
  if (months.isNaN || months < 0 || months > whoMaxMonths) return null;
  final List<Lms> table;
  final int offset;
  if (indicator == GrowthIndicator.weight) {
    (table, offset) = (whoWeightForAge(male: male), 0);
  } else if (months < 24) {
    (table, offset) = (whoLengthForAge(male: male), 0);
  } else {
    (table, offset) = (whoHeightForAge(male: male), 24);
  }
  final at = months - offset;
  final i = math.min(at.floor(), table.length - 1);
  final next = math.min(i + 1, table.length - 1);
  final t = at - i;
  final (l0, m0, s0) = table[i];
  final (l1, m1, s1) = table[next];
  return (l0 + (l1 - l0) * t, m0 + (m1 - m0) * t, s0 + (s1 - s0) * t);
}

/// The measurement at z-score [z]: M(1 + LSz)^(1/L), or M·e^(Sz) when L = 0.
double lmsValue(Lms lms, double z) {
  final (l, m, s) = lms;
  if (l == 0) return m * math.exp(s * z);
  return m * math.pow(1 + l * s * z, 1 / l);
}

/// z-score of [value] with WHO's adjustment beyond ±3 SD for skewed
/// indicators (WHO Child Growth Standards, methods report, ch. 7).
double lmsZScore(Lms lms, double value) {
  final (l, m, s) = lms;
  final z = l == 0
      ? math.log(value / m) / s
      : (math.pow(value / m, l) - 1) / (l * s);
  if (l == 1 || z.abs() <= 3) return z;
  if (z > 3) {
    final sd3 = lmsValue(lms, 3);
    return 3 + (value - sd3) / (sd3 - lmsValue(lms, 2));
  }
  final sd3 = lmsValue(lms, -3);
  return -3 + (value - sd3) / (lmsValue(lms, -2) - sd3);
}

/// Percentile (0-100) of a z-score, from the standard normal distribution.
double zToPercentile(double z) => 50 * (1 + _erf(z / math.sqrt2));

// Abramowitz & Stegun 7.1.26; error below 1.5e-7, plenty for percentiles.
double _erf(double x) {
  final sign = x < 0 ? -1.0 : 1.0;
  final a = x.abs();
  final t = 1 / (1 + 0.3275911 * a);
  final y =
      1 -
      (((((1.061405429 * t - 1.453152027) * t) + 1.421413741) * t -
                      0.284496736) *
                  t +
              0.254829592) *
          t *
          math.exp(-a * a);
  return sign * y;
}

/// Where one measurement falls on the WHO curves. Informational only.
class GrowthReading {
  const GrowthReading({required this.z, required this.percentile});

  final double z;
  final double percentile;

  /// Between the 3rd and 97th percentile is the usual range.
  bool get withinUsualRange => percentile >= 3 && percentile <= 97;

  Severity get severity => withinUsualRange ? Severity.good : Severity.actSoon;

  /// Rounded for people: "<1" and ">99" at the extremes.
  String get percentileLabel {
    if (percentile < 1) return '<1';
    if (percentile > 99) return '>99';
    return '${percentile.round()}';
  }
}

/// Reads [value] against the WHO standard; null when the age is outside
/// 0-60 months or the value isn't a positive number.
GrowthReading? readGrowth(
  GrowthIndicator indicator, {
  required bool male,
  required double months,
  required double value,
}) {
  if (value <= 0 || !value.isFinite) return null;
  final lms = whoLms(indicator, male: male, months: months);
  if (lms == null) return null;
  final z = lmsZScore(lms, value);
  return GrowthReading(z: z, percentile: zToPercentile(z));
}
