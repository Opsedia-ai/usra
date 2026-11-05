import 'package:intl/intl.dart';

import '../../core/database/app_database.dart';
import '../../core/util/dates.dart';
import '../../l10n/app_localizations.dart';
import '../children/child_vaccines.dart';
import '../children/egypt_vaccines.dart';
import '../children/growth.dart' show isUnderFive;
import 'report.dart';

/// The vaccination record (C4) for [profile] in [l]'s language: name, date
/// of birth, route, every dose given with its date (and the family's note
/// when [includeNotes]), the doses still to come, and a disclaimer that
/// it isn't an official certificate. Null without a birth date (the
/// schedule can't be matched).
///
/// Vaccine names come from the schedule in the report's language, so a
/// dose ticked in Arabic reads in English in the English record. Records
/// that don't match the schedule (travel vaccines, extra doses) are listed
/// as the family wrote them.
Report? vaccinationRecord({
  required AppLocalizations l,
  required Profile profile,
  required List<MedicalEvent> events,
  required DateTime now,
  bool includeNotes = false,
}) {
  final birth = profile.birthDate;
  if (birth == null) return null;
  final locale = l.localeName;
  String date(DateTime d) => DateFormat.yMMMd(locale).format(d);
  final today = DateTime(now.year, now.month, now.day);
  final plan = vaccinePlanOf(events);
  final records = vaccineRecords(events);
  final statuses = matchSchedule(
    birthDate: birth,
    records: records,
    now: today,
    plan: plan,
  );

  final matched = {for (final s in statuses) ...s.recordIds};
  final given = <(DateTime, List<String>)>[
    for (final s in statuses)
      if (s.done && s.givenOn != null)
        (
          s.givenOn!,
          [
            doseName(l, s.dose),
            date(s.givenOn!),
            if (includeNotes) plan.notes[s.dose.key] ?? '',
          ],
        ),
    for (final r in records)
      if (r.id != null && !matched.contains(r.id))
        (
          r.date,
          [
            r.dose == null ? r.name : l.vaccineDoseName(r.name, r.dose!),
            date(r.date),
            if (includeNotes) '',
          ],
        ),
  ]..sort((a, b) => a.$1.compareTo(b.$1));

  final underFive = isUnderFive(birth, today);
  final upcoming = [
    if (underFive)
      for (final s in [
        ...statuses.where((s) => s.open),
      ]..sort((a, b) => a.dueOn.compareTo(b.dueOn)))
        [
          doseName(l, s.dose),
          s.state == DoseState.overdue
              ? '${date(s.dueOn)} · ${l.reportOverdue}'
              : date(s.dueOn),
        ],
  ];

  return Report(
    languageCode: l.localeName.split('_').first,
    title: l.reportVaccinationTitle,
    appLine: l.reportAppLine,
    generated: l.reportGenerated(date(today)),
    disclaimer: l.reportVaccinationDisclaimer,
    pageLabel: l.reportPage,
    fields: [
      ReportField(l.reportName, profile.displayName),
      ReportField(l.profileBirthDate, date(storedDay(birth))),
      ReportField(
        l.reportRoute,
        plan.route == VaccineRoute.government
            ? l.reportRouteGovernment
            : l.reportRoutePrivate,
      ),
    ],
    sections: [
      ReportSection(
        id: 'given',
        heading: l.reportDosesGiven,
        columns: [
          l.reportColVaccine,
          l.reportColDate,
          if (includeNotes) l.reportColNotes,
        ],
        rows: [for (final g in given) g.$2],
        empty: l.reportNoDosesGiven,
      ),
      ReportSection(
        id: 'upcoming',
        heading: l.reportUpcoming,
        columns: [l.reportColVaccine, l.reportColDue],
        rows: upcoming,
        empty: underFive ? l.reportNoUpcoming : l.reportUpcomingOverFive,
      ),
    ],
  );
}
