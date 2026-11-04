import 'dart:convert';

import '../../core/design/tokens.dart';
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

  /// Stable id, e.g. `penta-2`; what notes are saved under.
  String get key => '${kind.name}-$dose';

  DateTime dueOn(DateTime birthDate) => addMonths(birthDate, ageMonths);

  bool accepts(VaccineKind recorded) =>
      recorded == kind || alsoCountedBy.contains(recorded);

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

/// The private hexavalent route: the hexavalent shot at 2, 4 and 6 months
/// replaces pentavalent and IPV, and a fourth (booster) dose at 18 months
/// replaces the DTP booster. Oral polio, BCG, hepatitis B at birth and MMR
/// stay as on the government card.
const _hexavalentDoses = <ScheduledDose>[
  ScheduledDose(VaccineKind.hexa, 1, 2),
  ScheduledDose(VaccineKind.hexa, 2, 4),
  ScheduledDose(VaccineKind.hexa, 3, 6),
  ScheduledDose(VaccineKind.hexa, 4, 18, alsoCountedBy: {VaccineKind.dtp}),
];

/// Optional vaccines, as commonly given in Egyptian private practice. One
/// usual schedule each; the child's doctor may use another.
const egyptOptionalDoses = <ScheduledDose>[
  // Pneumococcal conjugate (PCV13 / PCV10): 3 + 1.
  ScheduledDose(VaccineKind.pcv, 1, 2, required: false),
  ScheduledDose(VaccineKind.pcv, 2, 4, required: false),
  ScheduledDose(VaccineKind.pcv, 3, 6, required: false),
  ScheduledDose(VaccineKind.pcv, 4, 12, required: false),
  // Rotavirus (Rotarix, by mouth): 2 doses, before 24 weeks of age.
  ScheduledDose(VaccineKind.rota, 1, 2, required: false),
  ScheduledDose(VaccineKind.rota, 2, 4, required: false),
  // Varicella (chickenpox): second dose at least 3 months later (some
  // doctors give it at 4-6 years).
  ScheduledDose(VaccineKind.varicella, 1, 12, required: false),
  ScheduledDose(VaccineKind.varicella, 2, 15, required: false),
  // Hepatitis A: 2 doses 6-12 months apart.
  ScheduledDose(VaccineKind.hepA, 1, 12, required: false),
  ScheduledDose(VaccineKind.hepA, 2, 18, required: false),
  // Meningococcal ACWY conjugate: one dose from 12 months (ages vary by
  // brand; needs the doctor's confirmation).
  ScheduledDose(VaccineKind.mening, 1, 12, required: false),
  // Influenza: from 6 months; 2 doses a month apart the first season, then
  // once a year.
  ScheduledDose(VaccineKind.flu, 1, 6, required: false),
  ScheduledDose(VaccineKind.flu, 2, 7, required: false),
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
  final all = [...required, ...egyptOptionalDoses];
  // Stable: same-age doses keep the order above.
  return [
    for (final (_, d)
        in (all.indexed.toList()..sort((a, b) {
          final byAge = a.$2.ageMonths.compareTo(b.$2.ageMonths);
          return byAge != 0 ? byAge : a.$1.compareTo(b.$1);
        })))
      d,
  ];
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

  /// An optional vaccine the family doesn't follow: never due or overdue.
  notFollowed,
}

extension DoseStateSeverity on DoseState {
  Severity get severity => switch (this) {
    DoseState.done => Severity.good,
    DoseState.overdue => Severity.actSoon,
    DoseState.due => Severity.headsUp,
    DoseState.later || DoseState.notFollowed => Severity.info,
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
    this.recordIds = const [],
    this.followed = true,
  });

  final ScheduledDose dose;
  final DateTime dueOn;
  final DoseState state;
  final DateTime? givenOn;

  /// The records that count for this dose (more than one when a dose was
  /// recorded twice).
  final List<String> recordIds;

  /// In the family's plan: required, or an optional vaccine they chose.
  final bool followed;

  bool get done => state == DoseState.done;

  /// Still to be given, in the plan.
  bool get open => followed && !done;
}

/// Matches a child's vaccine records to the schedule for [plan].
///
/// A record with a dose number takes that dose; one without (or with a
/// number the schedule doesn't have) takes the earliest dose of its vaccine
/// still open, oldest record first. Records of optional vaccines count
/// whether or not the plan follows them.
List<DoseStatus> matchSchedule({
  required DateTime birthDate,
  required List<VaccineRecord> records,
  required DateTime now,
  VaccinePlan plan = VaccinePlan.standard,
}) {
  final schedule = egyptSchedule(plan.route);
  final given = <ScheduledDose, DateTime>{};
  final ids = <ScheduledDose, List<String>>{};
  void give(ScheduledDose d, VaccineRecord r) {
    given.putIfAbsent(d, () => r.date);
    if (r.id case final id?) (ids[d] ??= []).add(id);
  }

  final sorted = [...records]..sort((a, b) => a.date.compareTo(b.date));
  final unnumbered = <(VaccineKind, VaccineRecord)>[];
  for (final r in sorted) {
    for (final kind in vaccineKindsOf(r.name)) {
      final match = r.dose == null
          ? null
          : schedule
                .where((d) => d.kind == kind && d.dose == r.dose)
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
    final open = schedule
        .where((d) => d.accepts(kind) && !given.containsKey(d))
        .firstOrNull;
    if (open != null) give(open, r);
  }

  final today = DateTime.utc(now.year, now.month, now.day);
  DoseState stateOf(ScheduledDose dose, DateTime due) {
    if (given.containsKey(dose)) return DoseState.done;
    if (!plan.follows(dose)) return DoseState.notFollowed;
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
        recordIds: ids[dose] ?? const [],
        followed: plan.follows(dose),
      ),
  ];
}

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
  int? daysFrom(DateTime today) => date == null
      ? null
      : DateTime.utc(
          date!.year,
          date!.month,
          date!.day,
        ).difference(DateTime.utc(today.year, today.month, today.day)).inDays;

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
