import '../../core/follow_ups/follow_up.dart';
import '../../l10n/app_localizations.dart';
import 'child_screen.dart' show vaccineName, vaccineRecords;
import 'egypt_vaccines.dart';
import 'growth.dart';

/// The next mandatory doses on Egypt's schedule a child under five hasn't
/// had: one follow-up for the earliest age with open doses.
class EgyptVaccineRule extends FollowUpRule {
  const EgyptVaccineRule();

  @override
  String get id => 'vaccines.egypt';

  @override
  List<FollowUp> evaluate(FollowUpSubject subject, DateTime today) {
    final birth = subject.profile.birthDate;
    if (!isUnderFive(birth, today)) return const [];
    final open = matchSchedule(
      birthDate: birth!,
      records: vaccineRecords([for (final r in subject.records) r.event]),
      now: today,
    ).where((s) => s.state != DoseState.done).toList();
    if (open.isEmpty) return const [];
    final months = open.first.dose.ageMonths;
    final doses = [
      for (final s in open)
        if (s.dose.ageMonths == months) s.dose,
    ];
    return [
      FollowUp(
        ruleId: '$id.$months',
        profileId: subject.profile.id,
        dueOn: open.first.dueOn,
        title: (c) => AppLocalizations.of(c).fuVaccinesDue,
        reason: (c) {
          final l = AppLocalizations.of(c);
          return l.fuVaccinesAt(
            months == 0 ? l.vaccineAtBirth : l.vaccineAtMonths(months),
            {for (final d in doses) vaccineName(l, d.kind)}.join('، '),
          );
        },
        recordType: 'vaccine',
        source: 'Egypt MoHP mandatory schedule',
        graceDays: overdueAfterDays,
      ),
    ];
  }
}
