import 'dart:convert';

import '../../core/database/app_database.dart';
import '../../core/records/record_type.dart' show decodeRecordData;
import '../../l10n/app_localizations.dart';
import 'egypt_vaccines.dart';
import 'growth.dart';

/// The child's `vaccine` records, for matching against the schedule.
List<VaccineRecord> vaccineRecords(List<MedicalEvent> events) => [
  for (final e in events)
    if (e.type == 'vaccine' && e.deletedAt == null)
      if (decodeRecordData(e.dataJson) case final data)
        if (data['vaccine'] case final String name)
          (
            id: e.id,
            name: name,
            dose: switch (data['dose']) {
              final num d => d.toInt(),
              _ => null,
            },
            date: e.occurredAt,
          ),
];

/// The child's vaccine plan: their latest live `vaccinePlan` record, or
/// [VaccinePlan.standard] (government route, required only) when the
/// family never set one, as for every child before plans existed.
VaccinePlan vaccinePlanOf(List<MedicalEvent> events) {
  MedicalEvent? latest;
  for (final e in events) {
    if (e.type != VaccinePlanFields.type || e.deletedAt != null) continue;
    if (latest == null || e.updatedAt.isAfter(latest.updatedAt)) latest = e;
  }
  return latest == null
      ? VaccinePlan.standard
      : VaccinePlan.fromData(decodeRecordData(latest.dataJson));
}

/// One child's vaccines as of [now]; null for someone without a birth date
/// or five and over.
ChildVaccines? childVaccines(
  Profile profile,
  List<MedicalEvent> events,
  DateTime now,
) {
  final birth = profile.birthDate;
  if (!isUnderFive(birth, now)) return null;
  final plan = vaccinePlanOf(events);
  return ChildVaccines(
    profile: profile,
    plan: plan,
    userRecordIds: userVaccineRecordIds(events),
    statuses: matchSchedule(
      birthDate: birth!,
      records: vaccineRecords(events),
      now: now,
      plan: plan,
    ),
  );
}

class ChildVaccines {
  ChildVaccines({
    required this.profile,
    required this.plan,
    required this.statuses,
    this.userRecordIds = const {},
  });

  /// The family's own vaccine records; see [userVaccineRecordIds].
  final Set<String> userRecordIds;

  final Profile profile;
  final VaccinePlan plan;
  final List<DoseStatus> statuses;

  late final VaccineProgress progress = vaccineProgress(statuses);
  late final NextVaccineVisit next = NextVaccineVisit.of(statuses);

  /// Doses in the plan not given whose day on the schedule has come: all
  /// she's missing, though a missing earlier dose may make some wait.
  int missing(DateTime today) =>
      pastDosesToMark(statuses, today, withOptional: true).length;

  /// Doses in the plan that can be given today: their date, after the
  /// minimum interval from the dose before, has come.
  int givableNow(DateTime today) {
    final day = DateTime(today.year, today.month, today.day);
    return statuses
        .where(
          (s) =>
              s.open &&
              !DateTime(s.dueOn.year, s.dueOn.month, s.dueOn.day).isAfter(day),
        )
        .length;
  }
}

/// The `vaccine` record the checklist writes for [dose] given on [date]:
/// the vaccine's name in the app's language (which [vaccineKindsOf] reads
/// back) and the dose number.
NewVaccineRecord vaccineRecordFor(
  AppLocalizations l,
  ScheduledDose dose,
  DateTime date,
) => (
  type: 'vaccine',
  occurredAt: DateTime(date.year, date.month, date.day, 12),
  dataJson: jsonEncode({
    'vaccine': vaccineName(l, dose.kind),
    'dose': dose.dose,
    checklistSourceKey: checklistSource,
  }),
);

String vaccineName(AppLocalizations l, VaccineKind kind) => switch (kind) {
  VaccineKind.hepB => l.vaccineHepB,
  VaccineKind.bcg => l.vaccineBcg,
  VaccineKind.opv => l.vaccineOpv,
  VaccineKind.ipv => l.vaccineIpv,
  VaccineKind.penta => l.vaccinePenta,
  VaccineKind.hexa => l.vaccineHexa,
  VaccineKind.mmr => l.vaccineMmr,
  VaccineKind.dtp => l.vaccineDtp,
  VaccineKind.pcv => l.vaccinePcv,
  VaccineKind.rota => l.vaccineRota,
  VaccineKind.varicella => l.vaccineVaricella,
  VaccineKind.hepA => l.vaccineHepA,
  VaccineKind.mening => l.vaccineMening,
  VaccineKind.flu => l.vaccineFlu,
};

/// "Pentavalent, dose 2", "Oral polio, birth dose", "Hexavalent, booster".
String doseName(AppLocalizations l, ScheduledDose dose) {
  final name = vaccineName(l, dose.kind);
  if (dose.dose == 0) return l.vaccineZeroDose(name);
  if (dose.kind == VaccineKind.hexa && dose.dose == 4) {
    return l.vaccineBoosterDose(name);
  }
  return l.vaccineDoseName(name, dose.dose);
}

/// "At birth", "At 4 months".
String doseAge(AppLocalizations l, ScheduledDose dose) =>
    dose.ageMonths == 0 ? l.vaccineAtBirth : l.vaccineAtMonths(dose.ageMonths);

/// What "mark everything due so far as given" marks: doses still to give
/// whose day on the plan has come (never one not due yet), required ones,
/// and the optional ones the family follows only with [withOptional]. Never
/// a dose past its upper age or not needed.
List<DoseStatus> pastDosesToMark(
  List<DoseStatus> statuses,
  DateTime today, {
  bool withOptional = false,
}) {
  final day = DateTime(today.year, today.month, today.day);
  return [
    for (final s in statuses)
      if (s.open &&
          (s.dose.required || withOptional) &&
          !DateTime(
            s.plannedOn.year,
            s.plannedOn.month,
            s.plannedOn.day,
          ).isAfter(day))
        s,
  ];
}

/// A record the vaccine screens add.
typedef NewVaccineRecord = ({
  String type,
  DateTime occurredAt,
  String dataJson,
});

/// [date] as a calendar day, never later than [today]: a dose can't have
/// been given in the future.
DateTime givenDateOn(DateTime date, DateTime today) {
  final day = DateTime(date.year, date.month, date.day);
  final last = DateTime(today.year, today.month, today.day);
  return day.isAfter(last) ? last : day;
}

/// Marks the `vaccine` records the checklist and dose sheet write, so
/// unticking one of those never needs asking; records the family typed
/// (perhaps with a photo of the card, a doctor or a cost) do.
const checklistSourceKey = 'source';
const checklistSource = 'checklist';

/// The family's own `vaccine` records (not written by the checklist).
Set<String> userVaccineRecordIds(List<MedicalEvent> events) => {
  for (final e in events)
    if (e.type == 'vaccine' && e.deletedAt == null)
      if (decodeRecordData(e.dataJson)[checklistSourceKey] != checklistSource)
        e.id,
};

/// What saving the vaccine screens does to the records.
typedef VaccineRecordChanges = ({
  List<NewVaccineRecord> add,
  Set<String> remove,
  Map<String, DateTime> redate,
});

/// The record changes that make each dose in [changes] given on its date
/// (non-null) or not given (null), and change nothing else.
///
/// - A new date moves the dose's records in place ([redate]), keeping their
///   photos, doctor, cost and notes. A shared record (one hexavalent shot
///   counting for pentavalent and IPV) moves with it: it was one shot.
/// - Unticking removes the dose's records; any other dose such a record also
///   covered gets a record of its own with the same date, so unticking one
///   dose never unticks another.
VaccineRecordChanges vaccineRecordChanges(
  AppLocalizations l,
  List<DoseStatus> statuses,
  Map<String, DateTime?> changes,
) {
  final remove = <String>{};
  final add = <NewVaccineRecord>[];
  final redate = <String, DateTime>{};
  for (final s in statuses) {
    if (!changes.containsKey(s.dose.key)) continue;
    final date = changes[s.dose.key];
    if (date == null) {
      if (s.done) remove.addAll(s.recordIds);
    } else if (!s.done) {
      add.add(vaccineRecordFor(l, s.dose, date));
    } else if (s.givenOn != null && !_sameDay(s.givenOn!, date)) {
      if (s.recordIds.isEmpty) {
        add.add(vaccineRecordFor(l, s.dose, date));
      } else {
        for (final id in s.recordIds) {
          redate[id] = DateTime(date.year, date.month, date.day, 12);
        }
      }
    }
  }
  for (final s in statuses) {
    if (!s.done || changes.containsKey(s.dose.key) || s.recordIds.isEmpty) {
      continue;
    }
    // Still given through a record that stays: nothing to do.
    if (!s.recordIds.every(remove.contains)) continue;
    add.add(vaccineRecordFor(l, s.dose, s.givenOn!));
  }
  return (add: add, remove: remove, redate: redate);
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
