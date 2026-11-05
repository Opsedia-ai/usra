import '../../core/database/app_database.dart';

/// What the app knows about fever, all of it informational and sourced
/// (see `docs/research/fever-warning-signs.md`, which needs medical
/// review). Nothing here suggests a medicine, an amount or a time.

/// 38.0 °C (100.4 °F) or higher is a fever (NHS, AAP).
const feverC = 38.0;

/// Readings outside this range are refused as typos.
const lowestPlausibleC = 30.0;
const highestPlausibleC = 43.0;

/// Readings outside this range are saved only after "Is this right?".
const lowestUsualC = 34.0;
const highestUsualC = 42.0;

/// Under 3 months: an armpit reading at or above this is worth a call to
/// the doctor (armpit readings run lower). Needs medical review.
const armpitBabyC = 37.5;

/// Under 3 months: a temperature below this is a warning sign too. Needs
/// medical review.
const lowBabyC = 36.0;

double toCelsius(double value, String unit) =>
    unit == TemperatureUnit.fahrenheit ? (value - 32) * 5 / 9 : value;

double fromCelsius(double celsius, String unit) =>
    unit == TemperatureUnit.fahrenheit ? celsius * 9 / 5 + 32 : celsius;

double readingC(TemperatureReading r) => toCelsius(r.value, r.unit);

bool isFever(TemperatureReading r) => readingC(r) >= feverC - 1e-9;

bool isPlausible(double value, String unit) {
  final c = toCelsius(value, unit);
  return c >= lowestPlausibleC - 1e-9 && c <= highestPlausibleC + 1e-9;
}

/// Plausible but so unusual that the form asks before saving.
bool needsConfirm(double value, String unit) {
  final c = toCelsius(value, unit);
  return c < lowestUsualC - 1e-9 || c > highestUsualC + 1e-9;
}

/// A reading as saved: one decimal, like a thermometer shows, so the value
/// on screen and the "Fever" label always agree.
double roundReading(double value) => (value * 10).round() / 10;

/// The symptoms checklist, in the order shown.
abstract final class Symptom {
  static const cough = 'cough';
  static const runnyNose = 'runnyNose';
  static const soreThroat = 'soreThroat';
  static const earPain = 'earPain';
  static const headache = 'headache';
  static const vomiting = 'vomiting';
  static const diarrhea = 'diarrhea';
  static const rash = 'rash';
  static const aches = 'aches';
  static const poorFeeding = 'poorFeeding';
  static const dehydration = 'dehydration';
  static const breathing = 'breathing';
  static const drowsy = 'drowsy';
  static const seizure = 'seizure';
  static const rashNotFading = 'rashNotFading';
  static const stiffNeck = 'stiffNeck';

  static const all = [
    cough,
    runnyNose,
    soreThroat,
    earPain,
    headache,
    vomiting,
    diarrhea,
    rash,
    aches,
    poorFeeding,
    dehydration,
    breathing,
    drowsy,
    seizure,
    rashNotFading,
    stiffNeck,
  ];
}

/// How urgent a warning sign is. Both say to get help now.
enum WarningLevel {
  /// Call an ambulance (123 in Egypt) now.
  emergency,

  /// Contact a doctor now.
  doctorNow,
}

/// Who a source is.
enum WarningSource { nhs, aap, who, stlouis, womans }

const warningSourceUrls = {
  WarningSource.nhs: 'https://www.nhs.uk/conditions/fever-in-children/',
  WarningSource.aap: 'https://www.healthychildren.org/English/health-issues/conditions/fever/Pages/When-to-Call-the-Pediatrician.aspx',
  WarningSource.who: 'https://www.who.int/publications/i/item/9789241506823',
  WarningSource.stlouis: 'https://www.stlouischildrens.org/health-resources/symptom-checker/fever-how-take-temperature',
  WarningSource.womans: 'https://www.womans.org/services/pregnancy-childbirth/new-parent/newborn/temp-fever',
};

/// Age groups the warning signs differ by.
enum AgeGroup { under3Months, months3to6, under2, child, adult, unknown }

AgeGroup ageGroupOf(DateTime? birthDate, DateTime on) {
  if (birthDate == null) return AgeGroup.unknown;
  final b = DateTime(birthDate.year, birthDate.month, birthDate.day);
  // Born on the 31st: a month later is the last day of a shorter month.
  DateTime plusMonths(int m) {
    final last = DateTime(b.year, b.month + m + 1, 0).day;
    return DateTime(b.year, b.month + m, b.day > last ? last : b.day);
  }

  final day = DateTime(on.year, on.month, on.day);
  if (day.isBefore(plusMonths(3))) return AgeGroup.under3Months;
  if (day.isBefore(plusMonths(6))) return AgeGroup.months3to6;
  if (day.isBefore(plusMonths(24))) return AgeGroup.under2;
  if (day.isBefore(plusMonths(18 * 12))) return AgeGroup.child;
  return AgeGroup.adult;
}

/// One warning sign on the card.
class WarningSign {
  const WarningSign(this.key, this.level, this.sources, {this.symptom});

  /// The text key (`warnSign` in the ARB files).
  final String key;
  final WarningLevel level;
  final List<WarningSource> sources;

  /// The checklist symptom that is this sign, if any.
  final String? symptom;
}

const _emergencySigns = [
  WarningSign('breathing', WarningLevel.emergency, [
    WarningSource.nhs,
    WarningSource.aap,
    WarningSource.who,
  ], symptom: Symptom.breathing),
  WarningSign('seizure', WarningLevel.emergency, [
    WarningSource.nhs,
    WarningSource.aap,
    WarningSource.who,
  ], symptom: Symptom.seizure),
  WarningSign('rashGlass', WarningLevel.emergency, [
    WarningSource.nhs,
  ], symptom: Symptom.rashNotFading),
  WarningSign('drowsy', WarningLevel.emergency, [
    WarningSource.nhs,
    WarningSource.aap,
    WarningSource.who,
  ], symptom: Symptom.drowsy),
  WarningSign('stiffNeck', WarningLevel.emergency, [
    WarningSource.nhs,
    WarningSource.aap,
  ], symptom: Symptom.stiffNeck),
  WarningSign('skinColour', WarningLevel.emergency, [WarningSource.nhs]),
  WarningSign('confused', WarningLevel.emergency, [WarningSource.nhs]),
  // NHS lists "not interested in feeding" under 999; WHO IMCI: unable to
  // drink or breastfeed, and vomits everything, are general danger signs.
  WarningSign('notDrinking', WarningLevel.emergency, [
    WarningSource.nhs,
    WarningSource.who,
  ], symptom: Symptom.poorFeeding),
  WarningSign('vomitsEverything', WarningLevel.emergency, [
    WarningSource.aap,
    WarningSource.who,
  ]),
];

/// Signs that depend on age come first, then those for everyone. Without
/// a date of birth, the signs of every age.
List<WarningSign> warningSignsFor(AgeGroup age) {
  final unknown = age == AgeGroup.unknown;
  final under3Months = age == AgeGroup.under3Months || unknown;
  final under2 =
      under3Months || age == AgeGroup.months3to6 || age == AgeGroup.under2;
  final child = age != AgeGroup.adult;
  return [
    ..._emergencySigns,
    if (under3Months) ...const [
      WarningSign('under3Months', WarningLevel.doctorNow, [
        WarningSource.nhs,
        WarningSource.aap,
      ]),
      WarningSign('armpitUnder3Months', WarningLevel.doctorNow, [
        WarningSource.aap,
        WarningSource.stlouis,
      ]),
      WarningSign('lowUnder3Months', WarningLevel.doctorNow, [
        WarningSource.womans,
      ]),
    ],
    if (age == AgeGroup.months3to6 || unknown)
      const WarningSign('months3to6', WarningLevel.doctorNow, [
        WarningSource.nhs,
      ]),
    if (under2)
      const WarningSign('longUnder2', WarningLevel.doctorNow, [
        WarningSource.aap,
      ]),
    if (age == AgeGroup.child || unknown)
      const WarningSign('longChild', WarningLevel.doctorNow, [
        WarningSource.aap,
      ]),
    if (child)
      const WarningSign('fiveDays', WarningLevel.doctorNow, [
        WarningSource.nhs,
      ]),
    if (child)
      const WarningSign('veryHigh', WarningLevel.doctorNow, [
        WarningSource.aap,
      ]),
    if (age == AgeGroup.adult || unknown)
      const WarningSign('notImproving', WarningLevel.doctorNow, [
        WarningSource.nhs,
      ]),
    const WarningSign('dehydration', WarningLevel.doctorNow, [
      WarningSource.nhs,
      WarningSource.who,
    ], symptom: Symptom.dehydration),
  ];
}

/// How long a fever has been going on: from the first reading at or above
/// [feverC] to the last one, or to [now] when the latest reading is still
/// a fever in a sick day that hasn't ended. Null without a fever reading.
Duration? feverDuration(
  SickEpisode episode,
  List<TemperatureReading> readings,
  DateTime now,
) {
  final sorted = [...readings]..sort((a, b) => a.takenAt.compareTo(b.takenAt));
  final fevers = sorted.where(isFever).toList();
  if (fevers.isEmpty) return null;
  final ongoing = episode.endedAt == null && isFever(sorted.last);
  final end = ongoing ? now : fevers.last.takenAt;
  final d = end.difference(fevers.first.takenAt);
  return d.isNegative ? Duration.zero : d;
}

/// The signs on [warningSignsFor] that what was logged matches: ticked
/// symptoms, readings for the age, and how long the fever has lasted.
/// Never a diagnosis: the card shows them so the family gets help.
Set<String> matchedWarnings({
  required SickEpisode episode,
  required List<TemperatureReading> readings,
  required DateTime? birthDate,
  required DateTime now,
}) {
  final out = <String>{};
  final symptoms = decodeSymptoms(episode.symptomsJson).toSet();
  for (final s in warningSignsFor(ageGroupOf(birthDate, now))) {
    if (s.symptom != null && symptoms.contains(s.symptom)) out.add(s.key);
  }
  for (final r in readings) {
    final age = ageGroupOf(birthDate, r.takenAt);
    final c = readingC(r);
    if (age == AgeGroup.under3Months) {
      if (c >= feverC - 1e-9) out.add('under3Months');
      if (r.site == TemperatureSite.armpit && c >= armpitBabyC - 1e-9) {
        out.add('armpitUnder3Months');
      }
      if (c < lowBabyC - 1e-9) out.add('lowUnder3Months');
    }
    if (age == AgeGroup.months3to6 && c >= 39 - 1e-9) out.add('months3to6');
  }
  final age = ageGroupOf(birthDate, now);
  if (age != AgeGroup.adult &&
      age != AgeGroup.unknown &&
      readings.where((r) => readingC(r) > 40).length >= 2) {
    out.add('veryHigh');
  }
  final lasted = feverDuration(episode, readings, now);
  if (lasted != null) {
    final under2 =
        age == AgeGroup.under3Months ||
        age == AgeGroup.months3to6 ||
        age == AgeGroup.under2;
    if (under2 && lasted > const Duration(hours: 24)) out.add('longUnder2');
    if (age == AgeGroup.child && lasted > const Duration(hours: 72)) {
      out.add('longChild');
    }
    if (age != AgeGroup.adult && lasted >= const Duration(days: 5)) {
      out.add('fiveDays');
    }
  }
  return out;
}
