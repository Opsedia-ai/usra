import '../../core/design/tokens.dart';
import 'growth.dart';

/// A vaccine in Egypt's mandatory childhood schedule.
enum VaccineKind { hepB, bcg, opv, ipv, penta, mmr, dtp }

/// One dose the schedule expects at [ageMonths] (0 = at birth).
class ScheduledDose {
  const ScheduledDose(this.kind, this.dose, this.ageMonths);

  final VaccineKind kind;

  /// Dose number as the health office card counts it; oral polio starts at
  /// the "zero" dose given at birth.
  final int dose;
  final int ageMonths;

  DateTime dueOn(DateTime birthDate) => addMonths(birthDate, ageMonths);
}

/// Egypt's Ministry of Health and Population (MoHP) mandatory schedule, free
/// at health offices: birth, 2, 4, 6, 9, 12 and 18 months.
///
/// Source: MoHP Expanded Programme on Immunization, as published by the
/// ministry (statement of October 2026: seven oral polio doses and three
/// injected IPV doses) and youm7.com's MoHP schedule of May 2025. Schedules
/// change; the child's health office card is authoritative.
const egyptMandatorySchedule = <ScheduledDose>[
  ScheduledDose(VaccineKind.hepB, 0, 0),
  ScheduledDose(VaccineKind.bcg, 1, 0),
  ScheduledDose(VaccineKind.opv, 0, 0),
  ScheduledDose(VaccineKind.opv, 1, 2),
  ScheduledDose(VaccineKind.ipv, 1, 2),
  ScheduledDose(VaccineKind.penta, 1, 2),
  ScheduledDose(VaccineKind.opv, 2, 4),
  ScheduledDose(VaccineKind.ipv, 2, 4),
  ScheduledDose(VaccineKind.penta, 2, 4),
  ScheduledDose(VaccineKind.opv, 3, 6),
  ScheduledDose(VaccineKind.ipv, 3, 6),
  ScheduledDose(VaccineKind.penta, 3, 6),
  ScheduledDose(VaccineKind.opv, 4, 9),
  ScheduledDose(VaccineKind.opv, 5, 12),
  ScheduledDose(VaccineKind.mmr, 1, 12),
  ScheduledDose(VaccineKind.opv, 6, 18),
  ScheduledDose(VaccineKind.mmr, 2, 18),
  ScheduledDose(VaccineKind.dtp, 1, 18),
];

/// A vaccine record as the person typed it.
typedef VaccineRecord = ({String name, int? dose, DateTime date});

/// Names people write for each vaccine, in Arabic and English, already
/// [normalizeVaccineName]d. Checked in order: the first group that matches
/// wins, so "ثلاثي فيروسي" (MMR) is never read as "ثلاثي" (DTP).
const _aliases = <(Set<VaccineKind>, List<String>)>[
  ({VaccineKind.penta, VaccineKind.ipv}, ['hexa', 'سداسي']),
  ({VaccineKind.penta}, ['penta', 'خماسي']),
  (
    {VaccineKind.mmr},
    [
      'mmr',
      'measles',
      'mumps',
      'rubella',
      'حصبه',
      'ثلاثي الفيروسي',
      'ثلاثي فيروسي',
    ],
  ),
  ({VaccineKind.dtp}, ['dtp', 'dpt', 'dtap', 'diphtheria', 'دفتيريا', 'ثلاثي']),
  (
    {VaccineKind.ipv},
    ['ipv', 'salk', 'inactivated polio', 'سولك', 'شلل بالحقن', 'شلل حقن'],
  ),
  ({VaccineKind.opv}, ['opv', 'sabin', 'polio', 'سابين', 'شلل']),
  ({VaccineKind.hepB}, ['hep b', 'hepb', 'hepatitis b', 'hbv', 'كبدي']),
  ({VaccineKind.bcg}, ['bcg', 'tuberculosis', 'درن', 'بي سي جي']),
];

const _polioWords = ['شلل', 'polio'];
const _injectionWords = ['حقن', 'inject', 'shot'];

/// Lower case, no Arabic diacritics or tatweel, one form of alef, yeh and
/// teh marbuta, and single spaces.
String normalizeVaccineName(String raw) => raw
    .toLowerCase()
    .replaceAll(RegExp('[ً-ْـ]'), '')
    .replaceAll(RegExp('[أإآ]'), 'ا')
    .replaceAll('ى', 'ي')
    .replaceAll('ة', 'ه')
    .replaceAll(RegExp(r'[-_/]'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// The scheduled vaccines a typed name stands for; empty when unknown.
Set<VaccineKind> vaccineKindsOf(String name) {
  final n = normalizeVaccineName(name);
  if (n.isEmpty) return const {};
  // "شلل الأطفال بالحقن", "polio injection": the injected (IPV) one, however
  // the words are ordered.
  if (_polioWords.any(n.contains) && _injectionWords.any(n.contains)) {
    return const {VaccineKind.ipv};
  }
  for (final (kinds, words) in _aliases) {
    if (words.any(n.contains)) return kinds;
  }
  return const {};
}

/// Where a scheduled dose stands for one child.
enum DoseState { done, overdue, due, later }

extension DoseStateSeverity on DoseState {
  Severity get severity => switch (this) {
    DoseState.done => Severity.good,
    DoseState.overdue => Severity.actSoon,
    DoseState.due => Severity.headsUp,
    DoseState.later => Severity.info,
  };
}

/// A dose is "due" from two weeks before its date until a month after;
/// later than that it's overdue.
const dueSoonDays = 14;
const overdueAfterDays = 30;

class DoseStatus {
  const DoseStatus({
    required this.dose,
    required this.dueOn,
    required this.state,
    this.givenOn,
  });

  final ScheduledDose dose;
  final DateTime dueOn;
  final DoseState state;
  final DateTime? givenOn;
}

/// Matches a child's vaccine records to the schedule.
///
/// A record with a dose number takes that dose; one without (or with a
/// number the schedule doesn't have) takes the earliest dose of its vaccine
/// still open, oldest record first.
List<DoseStatus> matchSchedule({
  required DateTime birthDate,
  required List<VaccineRecord> records,
  required DateTime now,
  List<ScheduledDose> schedule = egyptMandatorySchedule,
}) {
  final given = <ScheduledDose, DateTime>{};
  final sorted = [...records]..sort((a, b) => a.date.compareTo(b.date));
  final unnumbered = <(VaccineKind, DateTime)>[];
  for (final r in sorted) {
    for (final kind in vaccineKindsOf(r.name)) {
      final match = r.dose == null
          ? null
          : schedule
                .where((d) => d.kind == kind && d.dose == r.dose)
                .firstOrNull;
      if (match == null) {
        unnumbered.add((kind, r.date));
      } else {
        // A second record of the same dose is a repeat, not the next dose.
        given.putIfAbsent(match, () => r.date);
      }
    }
  }
  for (final (kind, date) in unnumbered) {
    final open = schedule
        .where((d) => d.kind == kind && !given.containsKey(d))
        .firstOrNull;
    if (open != null) given[open] = date;
  }

  final today = DateTime.utc(now.year, now.month, now.day);
  DoseState stateOf(ScheduledDose dose, DateTime due) {
    if (given.containsKey(dose)) return DoseState.done;
    final days = today
        .difference(DateTime.utc(due.year, due.month, due.day))
        .inDays;
    if (days > overdueAfterDays) return DoseState.overdue;
    if (days >= -dueSoonDays) return DoseState.due;
    return DoseState.later;
  }

  return [
    for (final dose in schedule)
      DoseStatus(
        dose: dose,
        dueOn: dose.dueOn(birthDate),
        state: stateOf(dose, dose.dueOn(birthDate)),
        givenOn: given[dose],
      ),
  ];
}
