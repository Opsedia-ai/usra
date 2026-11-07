import 'package:intl/intl.dart';

import '../../core/database/app_database.dart';
import '../../core/records/record_type.dart' show decodeRecordData;
import '../../core/util/dates.dart';
import '../../l10n/app_localizations.dart';
import '../children/child_vaccines.dart';
import '../children/egypt_vaccines.dart';
import '../children/growth.dart';
import '../family/family_screen.dart' show ageInYears;
import '../labs/lab_report.dart';
import '../medicines/medicine_text.dart' show medicineEnded, scheduleSummaryIn;
import 'report.dart';
import 'vaccination_record.dart' show givenDoses;

/// What the family can put in the doctor summary (C10).
enum SummarySection {
  basics,
  allergies,
  conditions,
  medicines,
  visits,
  labs,

  /// Children only.
  growth,

  /// Children only.
  vaccines,
}

/// Growth and vaccines are offered for children (under 18 with a birth
/// date); everything else for everyone.
List<SummarySection> summarySectionsFor(Profile profile, DateTime now) {
  final age = ageInYears(profile.birthDate, now);
  final child = age != null && age < 18;
  return [
    for (final s in SummarySection.values)
      if (child || (s != SummarySection.growth && s != SummarySection.vaccines))
        s,
  ];
}

/// Everything the summary reads, loaded once when it's made.
class SummaryInputs {
  const SummaryInputs({
    required this.profile,
    required this.events,
    this.medicines = const [],
    this.doctors = const {},
  });

  final Profile profile;

  /// Live records, newest first (the timeline order).
  final List<MedicalEvent> events;

  /// The person's medicines with their schedule (null: taken as needed).
  final List<(Medicine, DoseSchedule?)> medicines;

  /// Saved doctors by id, for visits linked to one.
  final Map<String, Doctor> doctors;

  /// Only the person and their records (enough for the vaccination
  /// record).
  static Future<SummaryInputs?> loadRecords(
    AppDatabase db,
    String profileId,
  ) async {
    final (profile, events) = await (
      db.watchProfile(profileId).first,
      db.watchTimeline(profileId).first,
    ).wait;
    return profile == null
        ? null
        : SummaryInputs(profile: profile, events: events);
  }

  static Future<SummaryInputs?> load(AppDatabase db, String profileId) async {
    final profile = await db.watchProfile(profileId).first;
    if (profile == null) return null;
    final (events, medicines, doctors) = await (
      db.watchTimeline(profileId).first,
      db.watchMedicines(profileId).first,
      db.watchDoctors().first,
    ).wait;
    return SummaryInputs(
      profile: profile,
      events: events,
      medicines: [
        for (final (i, s) in (await [
          for (final m in medicines) db.watchDoseSchedule(m.id).first,
        ].wait).indexed)
          (medicines[i], s),
      ],
      doctors: {for (final d in doctors) d.id: d},
    );
  }
}

/// How many visits, lab reports and vaccine doses the summary lists (the
/// latest ones), to keep it short.
const summaryVisits = 5;
const summaryLabReports = 3;

/// A medicine the summary lists as current: the page's preview says the same.
bool summaryCountsMedicine(Medicine m, DateTime today) =>
    m.active &&
    !medicineEnded(m, today) &&
    !today.isBefore(storedDay(m.startOn));

/// A lab report the summary lists: past, with results.
bool summaryCountsLab(MedicalEvent e, DateTime today) =>
    e.type == 'lab' &&
    !_after(e.occurredAt, today) &&
    LabReport.of(e).tests.isNotEmpty;
const summaryVaccines = 6;

/// The doctor summary for [inputs] in [l]'s language, with only the
/// [sections] the family picked (in their usual order). Doses are copied
/// as written; nothing is worked out.
Report doctorSummary({
  required AppLocalizations l,
  required SummaryInputs inputs,
  required Set<SummarySection> sections,
  required DateTime now,
}) {
  final locale = l.localeName;
  final profile = inputs.profile;
  String date(DateTime d) => DateFormat.yMMMd(locale).format(d);
  String number(num n) => NumberFormat.decimalPattern(locale).format(n);
  final comma = locale.startsWith('ar') ? '، ' : ', ';
  final today = DateTime(now.year, now.month, now.day);
  final offered = summarySectionsFor(profile, today);
  final birth = profile.birthDate;

  ReportSection basics() {
    final age = ageInYears(birth, today);
    return ReportSection(
      id: 'basics',
      heading: l.reportSectionBasics,
      fields: [
        if (birth != null)
          ReportField(l.profileBirthDate, date(storedDay(birth))),
        if (age != null) ReportField(l.reportAge, _age(l, birth!, today, age)),
        if (profile.sex case final sex?)
          ReportField(
            l.profileSex,
            sex == 'male' ? l.sexMale : (sex == 'female' ? l.sexFemale : sex),
          ),
        ReportField(l.profileBloodType, profile.bloodType ?? l.reportNothing),
      ],
    );
  }

  ReportSection freeText(String id, String heading, String? value) =>
      ReportSection(
        id: id,
        heading: heading,
        rows: [
          for (final line in (value ?? '').split('\n'))
            if (line.trim().isNotEmpty) [line.trim()],
        ],
        empty: l.reportNothing,
      );

  ReportSection medicines() {
    final rows = <List<String>>[];
    for (final (m, schedule) in inputs.medicines) {
      if (!summaryCountsMedicine(m, today)) continue;
      final how = <String>[
        if (schedule == null)
          l.reportAsNeeded
        else ...[
          // Amount first: "1 tablet · Every day · 8:00 AM".
          ?schedule.amount,
          scheduleSummaryIn(l, schedule, withAmount: false),
        ],
        ?m.instructions,
        [
          l.reportSince(date(storedDay(m.startOn))),
          if (m.endOn != null) l.reportUntil(date(storedDay(m.endOn!))),
        ].join(' '),
      ];
      rows.add([
        [m.name, ?m.strength].join(' '),
        how.where((s) => s.trim().isNotEmpty).join(' · '),
      ]);
    }
    return ReportSection(
      id: 'medicines',
      heading: l.reportSectionMedicines,
      columns: [l.reportColMedicine, l.reportColHowTaken],
      rows: rows,
      empty: l.reportNothing,
    );
  }

  ReportSection visits() {
    final rows = <List<String>>[];
    for (final e in inputs.events) {
      if (rows.length == summaryVisits) break;
      if (e.type != 'visit' || _after(e.occurredAt, today)) continue;
      final data = decodeRecordData(e.dataJson);
      final doctor =
          _text(data['doctorName']) ?? inputs.doctors[e.doctorId]?.name;
      rows.add([
        date(e.occurredAt),
        doctor ?? '',
        [?_text(data['reason']), ?_text(data['diagnosis'])].join(' · '),
      ]);
    }
    return ReportSection(
      id: 'visits',
      heading: l.reportSectionVisits,
      columns: [l.reportColDate, l.reportColDoctor, l.reportColDetails],
      rows: rows,
      empty: l.reportNothing,
    );
  }

  ReportSection labs() {
    final rows = <List<String>>[];
    var reports = 0;
    for (final e in inputs.events) {
      if (reports == summaryLabReports) break;
      if (!summaryCountsLab(e, today)) continue;
      final tests = LabReport.of(e).tests;
      reports++;
      for (final t in tests) {
        final flag = switch (t.flag) {
          LabFlag.high => l.reportFlagHigh,
          LabFlag.low => l.reportFlagLow,
          _ => null,
        };
        rows.add([
          date(e.occurredAt),
          t.name,
          [
            [t.shownValue, ?t.unit].where((s) => s.isNotEmpty).join(' '),
            ?flag,
          ].join(' · '),
          labRangeText(t.range),
        ]);
      }
    }
    return ReportSection(
      id: 'labs',
      heading: l.reportSectionLabs,
      columns: [
        l.reportColDate,
        l.reportColTest,
        l.reportColResult,
        l.reportColRange,
      ],
      rows: rows,
      empty: l.reportNothing,
    );
  }

  ReportSection growth() {
    final sex = profile.sex;
    final rows = <List<String>>[];
    var anyPercentile = false;
    for (final (indicator, label) in [
      (GrowthIndicator.weight, l.fieldWeightKg),
      (GrowthIndicator.height, l.fieldHeightCm),
      (GrowthIndicator.head, l.fieldHeadCm),
    ]) {
      for (final e in inputs.events) {
        if (e.type != 'growth' || _after(e.occurredAt, today)) continue;
        final value = decodeRecordData(e.dataJson)[GrowthFields.of(indicator)];
        if (value is! num || value <= 0) continue;
        final reading = birth == null || (sex != 'male' && sex != 'female')
            ? null
            : readGrowth(
                indicator,
                male: sex == 'male',
                months: ageInMonths(birth, e.occurredAt),
                value: value.toDouble(),
              );
        if (reading != null) anyPercentile = true;
        rows.add([
          label,
          number(value),
          date(e.occurredAt),
          reading?.percentileLabel ?? '',
        ]);
        break;
      }
    }
    return ReportSection(
      id: 'growth',
      heading: l.reportSectionGrowth,
      columns: [
        l.reportColMeasure,
        l.reportColValue,
        l.reportColDate,
        l.reportColPercentile,
      ],
      rows: rows,
      empty: l.reportNothing,
      note: anyPercentile ? l.reportGrowthNote : null,
    );
  }

  ReportSection vaccines() {
    final fields = <ReportField>[];
    final rows = <List<String>>[];
    if (birth != null) {
      final plan = vaccinePlanOf(inputs.events);
      final statuses = matchSchedule(
        birthDate: birth,
        records: vaccineRecords(inputs.events),
        now: today,
        plan: plan,
      );
      final underFive = isUnderFive(birth, today);
      final p = vaccineProgress(statuses);
      // Counts, next and overdue doses only while the schedule applies
      // (under 5): for an older child, "2 of 20 given" would read as
      // missed vaccines when the family just didn't enter them.
      fields.add(
        ReportField(
          l.reportRoute,
          plan.route == VaccineRoute.government
              ? l.reportRouteGovernment
              : l.reportRoutePrivate,
        ),
      );
      final tooLate = [
        for (final s in statuses)
          if (s.followed && s.state == DoseState.tooLate) doseName(l, s.dose),
      ];
      if (underFive) {
        fields.add(
          ReportField(
            l.reportSectionVaccines,
            l.reportVaccineProgress(
              p.requiredDone + p.optionalDone,
              p.requiredTotal + p.optionalTotal,
            ),
          ),
        );
        final next = NextVaccineVisit.of(statuses);
        if (next.date case final d?) {
          fields.add(
            ReportField(
              l.reportVaccineNext,
              '${date(d)}: ${next.doses.map((x) => doseName(l, x)).join(comma)}',
            ),
          );
        }
        if (next.overdue.isNotEmpty) {
          fields.add(
            ReportField(
              l.reportVaccineOverdue,
              next.overdue.map((s) => doseName(l, s.dose)).join(comma),
            ),
          );
        }
        if (tooLate.isNotEmpty) {
          fields.add(ReportField(l.reportTooLateLabel, tooLate.join(comma)));
        }
      }
      // Latest first, travel vaccines and other off-schedule records too.
      final given = givenDoses(
        l,
        statuses,
        vaccineRecords(inputs.events),
        plan,
      ).reversed;
      for (final g in given.take(summaryVaccines)) {
        rows.add([g.name, date(g.date)]);
      }
    }
    return ReportSection(
      id: 'vaccines',
      heading: l.reportSectionVaccines,
      fields: fields,
      columns: [l.reportColVaccine, l.reportColDate],
      rows: rows,
      empty: l.reportNothing,
    );
  }

  return Report(
    languageCode: locale.split('_').first,
    title: l.reportSummaryTitle,
    appLine: l.reportAppLine,
    generated: l.reportGenerated(date(today)),
    disclaimer: l.reportSummaryDisclaimer,
    pageLabel: l.reportPage,
    fields: [ReportField(l.reportName, profile.displayName)],
    sections: [
      for (final s in offered)
        if (sections.contains(s))
          switch (s) {
            SummarySection.basics => basics(),
            SummarySection.allergies => freeText(
              'allergies',
              l.profileAllergies,
              profile.allergies,
            ),
            SummarySection.conditions => freeText(
              'conditions',
              l.profileConditions,
              profile.conditions,
            ),
            SummarySection.medicines => medicines(),
            SummarySection.visits => visits(),
            SummarySection.labs => labs(),
            SummarySection.growth => growth(),
            SummarySection.vaccines => vaccines(),
          },
    ],
  );
}

/// [at]'s calendar day is after [today]: a record dated in the future.
bool _after(DateTime at, DateTime today) =>
    DateTime(at.year, at.month, at.day).isAfter(today);

/// Under 2: months ("18 months"); then years.
String _age(AppLocalizations l, DateTime birth, DateTime today, int years) {
  if (years >= 2) return l.ageYears(years);
  final months = fullMonths(storedDay(birth), today);
  return months < 1 ? l.ageYears(0) : l.fuAgeMonths(months);
}

String? _text(Object? v) =>
    v is String && v.trim().isNotEmpty ? v.trim() : (v is num ? '$v' : null);

/// The lab's range as printed, else written with characters the PDF font
/// has ("<=" rather than "≤"); empty when there's none.
String labRangeText(LabRange range) {
  if (range.isEmpty && (range.printed ?? '').trim().isEmpty) return '';
  return range.format().replaceAll('≤', '<=').replaceAll('≥', '>=');
}
