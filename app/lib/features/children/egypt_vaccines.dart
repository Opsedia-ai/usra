import 'dart:convert';

import '../../core/design/tokens.dart';
import '../../core/follow_ups/follow_up.dart' show dayOf;
import 'growth.dart';

/// A vaccine on Egypt's childhood schedules: the ministry's required ones
/// and the optional ones families buy privately.
enum VaccineKind {
  hepB,
  bcg,
  opv,
  ipv,
  penta,
  hexa,
  mmr,
  dtp,
  pcv,
  rota,
  varicella,
  hepA,
  mening,
  flu,
}

/// Vaccines a family can choose to follow on top of the required ones.
const optionalVaccines = <VaccineKind>[
  VaccineKind.pcv,
  VaccineKind.rota,
  VaccineKind.varicella,
  VaccineKind.hepA,
  VaccineKind.mening,
  VaccineKind.flu,
];

/// How the required injections are given.
enum VaccineRoute {
  /// Free at the health office: pentavalent and IPV as separate shots.
  government,

  /// Private: one hexavalent shot instead of pentavalent + IPV.
  hexavalent,
}

/// One dose a schedule expects at [ageMonths] (0 = at birth).
class ScheduledDose {
  const ScheduledDose(
    this.kind,
    this.dose,
    this.ageMonths, {
    this.required = true,
    this.alsoCountedBy = const {},
    this.aliasFromMonths = 0,
    this.minIntervalDays = 0,
    this.minIntervalMonths = 0,
    this.maxAgeDays,
  });

  final VaccineKind kind;

  /// Dose number as the health office card counts it; oral polio and
  /// hepatitis B start at the "zero" dose given at birth.
  final int dose;
  final int ageMonths;

  /// Required by the ministry (or replacing a required dose); false for an
  /// optional vaccine.
  final bool required;

  /// Records of these vaccines count for this dose too (a DTP booster for
  /// the hexavalent booster).
  final Set<VaccineKind> alsoCountedBy;

  /// [alsoCountedBy] applies only to records given from this age (months):
  /// a hexavalent shot counts as the DTP booster only when given as a
  /// booster, not as an infant dose.
  final int aliasFromMonths;

  /// The least time after the previous dose of the same vaccine (CDC
  /// catch-up minimum intervals): this dose is never due earlier.
  final int minIntervalDays;
  final int minIntervalMonths;

  /// The last age (days from birth) this dose may be given, for vaccines
  /// with an upper age limit (rotavirus). Later, it's "too late".
  final int? maxAgeDays;

  /// Stable id, e.g. `penta-2`; what notes are saved under.
  String get key => '${kind.name}-$dose';

  DateTime dueOn(DateTime birthDate) => addMonths(birthDate, ageMonths);

  /// Whether a record of [recorded] given at [ageMonths] counts for this
  /// dose.
  bool accepts(VaccineKind recorded, {int ageMonths = 0}) =>
      recorded == kind ||
      (alsoCountedBy.contains(recorded) && ageMonths >= aliasFromMonths);

  /// The earliest day after a previous dose given (or giveable) on [prev].
  DateTime earliestAfter(DateTime prev) =>
      plusDays(addMonths(prev, minIntervalMonths), minIntervalDays);

  bool get hasInterval => minIntervalDays > 0 || minIntervalMonths > 0;

  @override
  String toString() => 'ScheduledDose($key @ $ageMonths m)';
}

/// When the schedule data below was last checked against its sources; see
/// docs/research/egypt-vaccine-schedule.md.
const egyptScheduleCheckedOn = '2026-11-04';

/// Egypt's Ministry of Health and Population (MoHP) mandatory schedule, free
/// at health offices: birth, 2, 4, 6, 9, 12 and 18 months.
///
/// Sources: docs/research/egypt-vaccine-schedule.md. Schedules change; the
/// child's health office card is authoritative.
const egyptMandatorySchedule = <ScheduledDose>[
  ScheduledDose(VaccineKind.hepB, 0, 0),
  ScheduledDose(VaccineKind.bcg, 1, 0),
  ScheduledDose(VaccineKind.opv, 0, 0),
  // The birth dose doesn't count towards the interval of the series.
  ScheduledDose(VaccineKind.opv, 1, 2),
  ScheduledDose(VaccineKind.ipv, 1, 2),
  ScheduledDose(VaccineKind.penta, 1, 2),
  ScheduledDose(VaccineKind.opv, 2, 4, minIntervalDays: 28),
  ScheduledDose(VaccineKind.ipv, 2, 4, minIntervalDays: 28),
  ScheduledDose(VaccineKind.penta, 2, 4, minIntervalDays: 28),
  ScheduledDose(VaccineKind.opv, 3, 6, minIntervalDays: 28),
  ScheduledDose(VaccineKind.ipv, 3, 6, minIntervalDays: 28),
  ScheduledDose(VaccineKind.penta, 3, 6, minIntervalDays: 28),
  ScheduledDose(VaccineKind.opv, 4, 9, minIntervalDays: 28),
  ScheduledDose(VaccineKind.opv, 5, 12, minIntervalDays: 28),
  ScheduledDose(VaccineKind.mmr, 1, 12),
  ScheduledDose(VaccineKind.opv, 6, 18, minIntervalDays: 28),
  ScheduledDose(VaccineKind.mmr, 2, 18, minIntervalDays: 28),
  // DTP-containing dose 4: at least 6 months after dose 3. A hexavalent
  // booster counts for it.
  ScheduledDose(
    VaccineKind.dtp,
    1,
    18,
    alsoCountedBy: {VaccineKind.hexa},
    aliasFromMonths: 12,
  ),
];

/// The private hexavalent route: the hexavalent shot at 2, 4 and 6 months
/// replaces pentavalent and IPV, and a fourth (booster) dose at 18 months
/// replaces the DTP booster. Oral polio, BCG, hepatitis B at birth and MMR
/// stay as on the government card.
const _hexavalentDoses = <ScheduledDose>[
  ScheduledDose(VaccineKind.hexa, 1, 2),
  ScheduledDose(VaccineKind.hexa, 2, 4, minIntervalDays: 28),
  ScheduledDose(VaccineKind.hexa, 3, 6, minIntervalDays: 28),
  ScheduledDose(
    VaccineKind.hexa,
    4,
    18,
    alsoCountedBy: {VaccineKind.dtp},
    minIntervalMonths: 6,
  ),
];

/// The DTP booster comes 6 months after the third pentavalent dose; kept
/// apart from the data above because its interval runs from another
/// vaccine (see [matchSchedule]).
const _dtpBoosterAfterMonths = 6;

/// Optional vaccines, as commonly given in Egyptian private practice. One
/// usual schedule each; the child's doctor may use another.
const egyptOptionalDoses = <ScheduledDose>[
  // Pneumococcal conjugate (PCV13 / PCV10): 3 + 1; the booster from 12
  // months, 8 weeks after the previous dose. Children who start late need
  // fewer doses (see [pcvDosesNeeded]).
  ScheduledDose(VaccineKind.pcv, 1, 2, required: false),
  ScheduledDose(VaccineKind.pcv, 2, 4, required: false, minIntervalDays: 28),
  ScheduledDose(VaccineKind.pcv, 3, 6, required: false, minIntervalDays: 28),
  ScheduledDose(VaccineKind.pcv, 4, 12, required: false, minIntervalDays: 56),
  // Rotavirus (Rotarix, by mouth): dose 1 by 14 weeks 6 days (not started
  // later), the series finished by 24 weeks.
  ScheduledDose(VaccineKind.rota, 1, 2, required: false, maxAgeDays: 104),
  ScheduledDose(
    VaccineKind.rota,
    2,
    4,
    required: false,
    minIntervalDays: 28,
    maxAgeDays: 168,
  ),
  // Varicella (chickenpox): second dose at least 3 months later (some
  // doctors give it at 4-6 years).
  ScheduledDose(VaccineKind.varicella, 1, 12, required: false),
  ScheduledDose(
    VaccineKind.varicella,
    2,
    15,
    required: false,
    minIntervalMonths: 3,
  ),
  // Hepatitis A: 2 doses at least 6 months apart.
  ScheduledDose(VaccineKind.hepA, 1, 12, required: false),
  ScheduledDose(VaccineKind.hepA, 2, 18, required: false, minIntervalMonths: 6),
  // Meningococcal ACWY conjugate: one dose from 12 months (ages vary by
  // brand; needs the doctor's confirmation).
  ScheduledDose(VaccineKind.mening, 1, 12, required: false),
  // Influenza: from 6 months; 2 doses at least 4 weeks apart the first
  // season, then once a year.
  ScheduledDose(VaccineKind.flu, 1, 6, required: false),
  ScheduledDose(VaccineKind.flu, 2, 7, required: false, minIntervalDays: 28),
];

/// The full schedule for [route]: the required doses, then every optional
/// one (whether or not the family follows it), by age.
List<ScheduledDose> egyptSchedule(VaccineRoute route) {
  final required = switch (route) {
    VaccineRoute.government => egyptMandatorySchedule,
    VaccineRoute.hexavalent => [
      for (final d in egyptMandatorySchedule)
        if (d.kind != VaccineKind.penta &&
            d.kind != VaccineKind.ipv &&
            d.kind != VaccineKind.dtp)
          d,
      ..._hexavalentDoses,
    ],
  };
  // Stable: same-age doses keep the order above.
  return _byAge([...required, ...egyptOptionalDoses]);
}

/// What a family has chosen for one child: the route and which optional
/// vaccines they follow, plus their notes per dose. Saved as the child's
/// hidden `vaccinePlan` record.
class VaccinePlan {
  const VaccinePlan({
    this.route = VaccineRoute.government,
    this.optional = const {},
    this.notes = const {},
  });

  /// Required only, government route: what a child without a plan gets.
  static const standard = VaccinePlan();

  final VaccineRoute route;

  /// Optional vaccines followed; see [optionalVaccines].
  final Set<VaccineKind> optional;

  /// Free-text notes by [ScheduledDose.key].
  final Map<String, String> notes;

  /// A dose is in the plan when it's required on this route or its
  /// vaccine was chosen.
  bool follows(ScheduledDose d) => d.required || optional.contains(d.kind);

  VaccinePlan copyWith({
    VaccineRoute? route,
    Set<VaccineKind>? optional,
    Map<String, String>? notes,
  }) => VaccinePlan(
    route: route ?? this.route,
    optional: optional ?? this.optional,
    notes: notes ?? this.notes,
  );

  /// With [note] for [key]; an empty note removes it.
  VaccinePlan withNote(String key, String note) => copyWith(
    notes: {
      for (final e in notes.entries)
        if (e.key != key) e.key: e.value,
      if (note.trim().isNotEmpty) key: note.trim(),
    },
  );

  Map<String, Object?> toData() => {
    VaccinePlanFields.route: route.name,
    VaccinePlanFields.optional: [
      for (final k in optionalVaccines)
        if (optional.contains(k)) k.name,
    ],
    if (notes.isNotEmpty) VaccinePlanFields.notes: notes,
  };

  String toJson() => jsonEncode(toData());

  /// Reads [toData]; anything unknown or malformed falls back to
  /// [standard], so a damaged record never hides required doses.
  static VaccinePlan fromData(Map<String, Object?> data) {
    final route = VaccineRoute.values
        .where((r) => r.name == data[VaccinePlanFields.route])
        .firstOrNull;
    final optional = switch (data[VaccinePlanFields.optional]) {
      final List<Object?> names => {
        for (final k in optionalVaccines)
          if (names.contains(k.name)) k,
      },
      _ => const <VaccineKind>{},
    };
    final notes = switch (data[VaccinePlanFields.notes]) {
      final Map<Object?, Object?> m => {
        for (final e in m.entries)
          if (e.key case final String k)
            if (e.value case final String v when v.trim().isNotEmpty) k: v,
      },
      _ => const <String, String>{},
    };
    return VaccinePlan(
      route: route ?? VaccineRoute.government,
      optional: optional,
      notes: notes,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is VaccinePlan &&
      other.route == route &&
      other.optional.length == optional.length &&
      other.optional.containsAll(optional) &&
      other.notes.length == notes.length &&
      notes.entries.every((e) => other.notes[e.key] == e.value);

  @override
  int get hashCode => Object.hash(
    route,
    Object.hashAllUnordered(optional),
    Object.hashAllUnordered(notes.entries.map((e) => '${e.key}=${e.value}')),
  );
}

/// The hidden record type a [VaccinePlan] is saved as, and its keys.
abstract final class VaccinePlanFields {
  static const type = 'vaccinePlan';
  static const route = 'route';
  static const optional = 'optional';
  static const notes = 'notes';
}

/// A vaccine record as the person typed it (or the setup checklist wrote
/// it). [id] is the record's, when it has one.
typedef VaccineRecord = ({String? id, String name, int? dose, DateTime date});

/// Names people write for each vaccine, in Arabic and English, already
/// [normalizeVaccineName]d. Checked in order: the first group that matches
/// wins, so "ثلاثي فيروسي" (MMR) is never read as "ثلاثي" (DTP).
const _aliases = <(Set<VaccineKind>, List<String>)>[
  // A hexavalent shot is pentavalent + IPV in one: on the government
  // route it counts for both.
  (
    {VaccineKind.hexa, VaccineKind.penta, VaccineKind.ipv},
    ['hexa', 'سداسي', 'infanrix', 'hexyon', 'انفانريكس', 'هكسيون'],
  ),
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
  (
    {VaccineKind.pcv},
    [
      'pcv',
      'pneumo',
      'prevenar',
      'prevnar',
      'synflorix',
      'رئوي',
      'الرئويه',
      'نيموكوك',
      'بريفينار',
      'بريفنار',
    ],
  ),
  ({VaccineKind.rota}, ['rota', 'روتا']),
  (
    {VaccineKind.varicella},
    [
      'varicella',
      'chickenpox',
      'chicken pox',
      'varivax',
      'varilrix',
      'جديري',
      'جدري مائي',
      'جدري الماء',
    ],
  ),
  (
    {VaccineKind.mening},
    [
      'mening',
      'menacwy',
      'nimenrix',
      'menactra',
      'menveo',
      'mencevax',
      'سحائي',
      'السحائيه',
      'شوكي',
      'الشوكيه',
    ],
  ),
  (
    {VaccineKind.flu},
    ['flu', 'influenza', 'vaxigrip', 'انفلونزا', 'الانفلونزا', 'انفلوانزا'],
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

/// Hepatitis A, told apart from B: "hepatitis a", "hep a", "havrix",
/// "الالتهاب الكبدي (الوبائي) أ", "كبدي A".
final _hepA = RegExp(
  r'(hep(atitis)? ?a( |$)|havrix|avaxim|كبدي (الوبائي )?(ا|a)( |$))',
);

/// Lower case, no Arabic diacritics or tatweel, one form of alef, yeh and
/// teh marbuta, no brackets, and single spaces.
String normalizeVaccineName(String raw) => raw
    .toLowerCase()
    .replaceAll(RegExp('[ً-ْـ]'), '')
    .replaceAll(RegExp('[أإآ]'), 'ا')
    .replaceAll('ى', 'ي')
    .replaceAll('ة', 'ه')
    .replaceAll(RegExp(r'[-_/()،,]'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// The vaccines a typed name stands for; empty when unknown.
Set<VaccineKind> vaccineKindsOf(String name) {
  final n = normalizeVaccineName(name);
  if (n.isEmpty) return const {};
  // "شلل الأطفال بالحقن", "polio injection": the injected (IPV) one, however
  // the words are ordered.
  if (_polioWords.any(n.contains) && _injectionWords.any(n.contains)) {
    return const {VaccineKind.ipv};
  }
  if (_hepA.hasMatch(n)) return const {VaccineKind.hepA};
  for (final (kinds, words) in _aliases) {
    if (words.any(n.contains)) return kinds;
  }
  return const {};
}

/// Where a scheduled dose stands for one child.
enum DoseState {
  done,
  overdue,
  due,
  later,

  /// Past the age this vaccine may be given (rotavirus): ask the doctor.
  /// Never due, overdue or reminded.
  tooLate,

  /// Not needed at this age: a late start needs fewer doses (PCV).
  notNeeded,
}

extension DoseStateSeverity on DoseState {
  Severity get severity => switch (this) {
    DoseState.done => Severity.good,
    DoseState.overdue => Severity.actSoon,
    DoseState.due => Severity.headsUp,
    DoseState.later ||
    DoseState.tooLate ||
    DoseState.notNeeded => Severity.info,
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
    DateTime? plannedOn,
    required this.state,
    this.givenOn,
    this.recordIds = const [],
    this.followed = true,
    this.pastItsAge = false,
  }) : plannedOn = plannedOn ?? dueOn;

  /// The child is more than [overdueAfterDays] past this dose's age on the
  /// schedule (it would be overdue by age alone), and its date moved later
  /// than that age (an earlier dose was missing or late).
  final bool pastItsAge;

  final ScheduledDose dose;

  /// When it's due: its age on the schedule, or later when the previous
  /// dose came late (minimum interval).
  final DateTime dueOn;

  /// When it was due as the plan would have run: its age on the schedule,
  /// or later only when a dose before it was given late. Unlike [dueOn], a
  /// missing earlier dose doesn't move it. A past dose ticked without a
  /// date is taken to have been given on this day (callers clamp it to
  /// today with `givenDateOn`; for a dose still ahead it's in the future).
  final DateTime plannedOn;

  final DoseState state;
  final DateTime? givenOn;

  /// The records that count for this dose (more than one when a dose was
  /// recorded twice).
  final List<String> recordIds;

  /// In the family's plan: required, or an optional vaccine they chose.
  final bool followed;

  bool get done => state == DoseState.done;

  /// Still to give and not yet overdue, but the child is already past the
  /// age it's for on the schedule and its date moved later (an earlier dose
  /// was missing or late): a catch-up dose, never "at 4 months".
  /// Optional doses the family doesn't follow say so too: their date
  /// assumes the series starts today.
  bool get catchUp =>
      (state == DoseState.due || state == DoseState.later) && pastItsAge;

  /// Still to be given, in the plan: due, overdue or later.
  bool get open =>
      followed &&
      (state == DoseState.overdue ||
          state == DoseState.due ||
          state == DoseState.later);
}

/// The calendar day [days] after [date] (local, so clock changes don't
/// shift it by an hour).
DateTime plusDays(DateTime date, int days) =>
    DateTime(date.year, date.month, date.day + days);

/// Whole months from [birth] to [on].
int fullMonths(DateTime birth, DateTime on) {
  var m = (on.year - birth.year) * 12 + on.month - birth.month;
  if (addMonths(birth, m).isAfter(DateTime(on.year, on.month, on.day))) m--;
  return m;
}

/// How many PCV doses a healthy child needs, by the age they started
/// (CDC catch-up guidance): before 7 months 4 (3 + booster), 7-11 months 3,
/// 12-23 months 2, from 24 months 1. A child 24 months or older with an
/// unfinished series needs one more dose, and is done once a dose was given
/// from 24 months.
int pcvDosesNeeded(DateTime birth, List<DateTime> given, DateTime today) {
  final dates = [...given]..sort();
  final start = fullMonths(birth, dates.firstOrNull ?? today);
  var needed = start < 7
      ? 4
      : start < 12
      ? 3
      : start < 24
      ? 2
      : 1;
  if (fullMonths(birth, today) >= 24 && dates.length < needed) {
    final afterTwo = dates.any((d) => fullMonths(birth, d) >= 24);
    needed = afterTwo ? dates.length : dates.length + 1;
  }
  return needed;
}

/// Matches records to [schedule]: a record with a dose number takes that
/// dose; one without (or with a number the schedule doesn't have) takes the
/// earliest dose of its vaccine still open, oldest record first.
Map<ScheduledDose, ({DateTime date, List<String> ids})> _match(
  List<ScheduledDose> schedule,
  List<VaccineRecord> records,
  DateTime birthDate,
) {
  final given = <ScheduledDose, ({DateTime date, List<String> ids})>{};
  void give(ScheduledDose d, VaccineRecord r) {
    final g = given[d] ??= (date: r.date, ids: <String>[]);
    if (r.id case final id?) g.ids.add(id);
  }

  final sorted = [...records]..sort((a, b) => a.date.compareTo(b.date));
  final unnumbered = <(VaccineKind, VaccineRecord)>[];
  for (final r in sorted) {
    final age = fullMonths(birthDate, r.date);
    for (final kind in vaccineKindsOf(r.name)) {
      final match = r.dose == null
          ? null
          : schedule
                .where(
                  (d) => d.dose == r.dose && d.accepts(kind, ageMonths: age),
                )
                .firstOrNull;
      if (match == null) {
        unnumbered.add((kind, r));
      } else {
        // A second record of the same dose is a repeat, not the next dose.
        give(match, r);
      }
    }
  }
  for (final (kind, r) in unnumbered) {
    final age = fullMonths(birthDate, r.date);
    final open = schedule
        .where((d) => d.accepts(kind, ageMonths: age) && !given.containsKey(d))
        .firstOrNull;
    if (open != null) give(open, r);
  }
  return given;
}

/// On the hexavalent route, infant positions (1-3) where the child had
/// pentavalent or IPV from the health office instead: those positions show
/// pentavalent + IPV, so a switch mid-way never marks covered doses as
/// missing, and a missing IPV shows as just that.
List<ScheduledDose> _mixedHexavalent(
  List<ScheduledDose> schedule,
  List<VaccineRecord> records,
  DateTime birthDate,
) {
  final separate = [
    for (final r in records)
      if (!vaccineKindsOf(r.name).contains(VaccineKind.hexa)) r,
  ];
  if (separate.isEmpty) return schedule;
  final gov = _match(egyptMandatorySchedule, separate, birthDate);
  final positions = {
    for (final d in gov.keys)
      if (d.kind == VaccineKind.penta || d.kind == VaccineKind.ipv) d.dose,
  };
  if (positions.isEmpty) return schedule;
  final mixed = [
    for (final d in schedule)
      if (d.kind == VaccineKind.hexa && positions.contains(d.dose))
        ...egyptMandatorySchedule.where(
          (g) =>
              (g.kind == VaccineKind.penta || g.kind == VaccineKind.ipv) &&
              g.dose == d.dose,
        )
      else
        d,
  ];
  return _byAge(mixed);
}

List<ScheduledDose> _byAge(List<ScheduledDose> doses) => [
  for (final (_, d)
      in (doses.indexed.toList()..sort((a, b) {
        final byAge = a.$2.ageMonths.compareTo(b.$2.ageMonths);
        return byAge != 0 ? byAge : a.$1.compareTo(b.$1);
      })))
    d,
];

/// Matches a child's vaccine records to the schedule for [plan].
///
/// Records of optional vaccines count whether or not the plan follows
/// them, and every optional dose gets its date and state too: one the
/// family doesn't follow is shown, but never "open" (no reminder, overdue
/// card, next visit or count). Each dose is due at its age on the schedule, but never before its
/// minimum interval after the previous dose of the same vaccine (given, or
/// at the earliest today when still missing), so a late start becomes a
/// catch-up rather than a list of overdue doses. Doses past their upper age
/// are "too late", and PCV doses a late starter doesn't need are "not
/// needed".
List<DoseStatus> matchSchedule({
  required DateTime birthDate,
  required List<VaccineRecord> records,
  required DateTime now,
  VaccinePlan plan = VaccinePlan.standard,
}) {
  var schedule = egyptSchedule(plan.route);
  if (plan.route == VaccineRoute.hexavalent) {
    schedule = _mixedHexavalent(schedule, records, birthDate);
  }
  final given = _match(schedule, records, birthDate);
  final today = DateTime(now.year, now.month, now.day);
  final pcvNeeded = pcvDosesNeeded(birthDate, [
    for (final e in given.entries)
      if (e.key.kind == VaccineKind.pcv) e.value.date,
  ], today);

  final series = <VaccineKind, List<ScheduledDose>>{};
  for (final d in schedule) {
    (series[d.kind] ??= []).add(d);
  }
  for (final doses in series.values) {
    doses.sort((a, b) => a.dose.compareTo(b.dose));
  }
  // Penta, IPV and OPV first: the DTP and hexavalent boosters count from
  // them.
  final order = [...series.keys]
    ..sort((a, b) {
      int rank(VaccineKind k) =>
          k == VaccineKind.dtp || k == VaccineKind.hexa ? 1 : 0;
      return rank(a).compareTo(rank(b));
    });

  // Due dates, dose by dose within each vaccine. With [catchUp], a missing
  // dose can be given today at the earliest, so the doses after it move
  // later (the catch-up plan); without, a missing dose is placed on its own
  // due date (the plan as it would have run, for dating past doses ticked
  // without a date).
  Map<ScheduledDose, DateTime> chain({required bool catchUp}) {
    final due = <ScheduledDose, DateTime>{};
    // Earliest day each dose was or can be given, for the next dose.
    final earliest = <ScheduledDose, DateTime>{};
    DateTime? earliestOf(VaccineKind kind, int dose) => series[kind]
        ?.where((d) => d.dose == dose)
        .map((d) => earliest[d])
        .firstOrNull;
    for (final kind in order) {
      DateTime? prev;
      for (final d in series[kind]!) {
        var date = d.dueOn(birthDate);
        if (prev != null && d.hasInterval) {
          date = _later(date, d.earliestAfter(prev));
        }
        // The boosters: 6 months after the third DTP-containing dose,
        // whichever product it was (mixed routes).
        if (d.kind == VaccineKind.dtp ||
            (d.kind == VaccineKind.hexa && d.dose == 4)) {
          final third =
              earliestOf(VaccineKind.hexa, 3) ??
              earliestOf(VaccineKind.penta, 3);
          if (third != null) {
            date = _later(date, addMonths(third, _dtpBoosterAfterMonths));
          }
        }
        // PCV for a late starter: the last dose needed is the booster, from
        // 12 months and 8 weeks after the previous one.
        if (d.kind == VaccineKind.pcv && d.dose == pcvNeeded && pcvNeeded > 1) {
          date = _later(date, addMonths(birthDate, 12));
          if (prev != null) {
            date = _later(date, plusDays(prev, 56));
          }
        }
        due[d] = date;
        final g = given[d];
        earliest[d] = g != null
            ? DateTime(g.date.year, g.date.month, g.date.day)
            : catchUp
            ? _later(date, today)
            : date;
        prev = earliest[d];
      }
    }
    return due;
  }

  final due = chain(catchUp: true);
  final planned = chain(catchUp: false);

  // Upper ages (rotavirus): a dose is too late once its last day has passed
  // or its catch-up date falls after it, and so is every dose after it.
  final tooLate = <ScheduledDose>{};
  for (final doses in series.values) {
    var prevTooLate = false;
    for (final d in doses) {
      final last = d.maxAgeDays == null
          ? null
          : plusDays(birthDate, d.maxAgeDays!);
      final late =
          !given.containsKey(d) &&
          (prevTooLate ||
              (last != null && (today.isAfter(last) || due[d]!.isAfter(last))));
      if (late) tooLate.add(d);
      prevTooLate = late;
    }
  }

  DoseState stateOf(ScheduledDose dose) {
    if (given.containsKey(dose)) return DoseState.done;
    if (dose.kind == VaccineKind.pcv && dose.dose > pcvNeeded) {
      return DoseState.notNeeded;
    }
    if (tooLate.contains(dose)) return DoseState.tooLate;
    final days = dayOf(today).difference(dayOf(due[dose]!)).inDays;
    if (days > overdueAfterDays) return DoseState.overdue;
    if (days >= -dueSoonDays) return DoseState.due;
    return DoseState.later;
  }

  return [
    for (final dose in schedule)
      DoseStatus(
        dose: dose,
        dueOn: due[dose]!,
        plannedOn: planned[dose]!,
        state: stateOf(dose),
        pastItsAge:
            today.isAfter(plusDays(dose.dueOn(birthDate), overdueAfterDays)) &&
            dayOf(due[dose]!).isAfter(dayOf(dose.dueOn(birthDate))),
        givenOn: given[dose]?.date,
        recordIds: given[dose]?.ids ?? const [],
        followed: plan.follows(dose),
      ),
  ];
}

DateTime _later(DateTime a, DateTime b) => a.isAfter(b) ? a : b;

/// Progress through the plan: "10/12 required done".
typedef VaccineProgress = ({
  int requiredDone,
  int requiredTotal,
  int optionalDone,
  int optionalTotal,
});

VaccineProgress vaccineProgress(List<DoseStatus> statuses) {
  var (rd, rt, od, ot) = (0, 0, 0, 0);
  for (final s in statuses) {
    if (s.state == DoseState.notNeeded || s.state == DoseState.tooLate) {
      continue;
    }
    if (s.dose.required) {
      rt++;
      if (s.done) rd++;
    } else if (s.followed) {
      ot++;
      if (s.done) od++;
    }
  }
  return (
    requiredDone: rd,
    requiredTotal: rt,
    optionalDone: od,
    optionalTotal: ot,
  );
}

/// The next vaccine visit: the earliest date with doses still to give that
/// isn't overdue yet, and how many doses are overdue.
class NextVaccineVisit {
  const NextVaccineVisit({
    required this.date,
    required this.doses,
    required this.overdue,
  });

  /// Null when nothing more is planned (all given, or only overdue ones).
  final DateTime? date;

  /// The doses due on [date].
  final List<ScheduledDose> doses;

  /// Doses past their date by more than a month, not given.
  final List<DoseStatus> overdue;

  /// Days from [today] to [date]; negative when it has passed (still
  /// within the month's grace).
  int? daysFrom(DateTime today) =>
      date == null ? null : dayOf(date!).difference(dayOf(today)).inDays;

  bool get isEmpty => date == null && overdue.isEmpty;

  static NextVaccineVisit of(List<DoseStatus> statuses) {
    final open = [
      for (final s in statuses)
        if (s.open && s.state != DoseState.overdue) s,
    ]..sort((a, b) => a.dueOn.compareTo(b.dueOn));
    final date = open.firstOrNull?.dueOn;
    return NextVaccineVisit(
      date: date,
      doses: [
        for (final s in open)
          if (s.dueOn == date) s.dose,
      ],
      overdue: [
        for (final s in statuses)
          if (s.open && s.state == DoseState.overdue) s,
      ],
    );
  }
}
