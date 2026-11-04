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
  });

  final Profile profile;
  final VaccinePlan plan;
  final List<DoseStatus> statuses;

  late final VaccineProgress progress = vaccineProgress(statuses);
  late final NextVaccineVisit next = NextVaccineVisit.of(statuses);
}

/// The `vaccine` record the checklist writes for [dose] given on [date]:
/// the vaccine's name in the app's language (which [vaccineKindsOf] reads
/// back) and the dose number.
({String type, DateTime occurredAt, String dataJson}) vaccineRecordFor(
  AppLocalizations l,
  ScheduledDose dose,
  DateTime date,
) => (
  type: 'vaccine',
  occurredAt: DateTime(date.year, date.month, date.day, 12),
  dataJson: jsonEncode({
    'vaccine': vaccineName(l, dose.kind),
    'dose': dose.dose,
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
