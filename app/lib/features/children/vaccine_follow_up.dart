import '../../core/follow_ups/follow_up.dart';
import '../../l10n/app_localizations.dart';
import 'child_vaccines.dart';
import 'egypt_vaccines.dart';

/// The next doses in a child's vaccine plan (required ones, and the
/// optional vaccines the family chose) that a child under five hasn't had:
/// one follow-up for the earliest age with open doses.
class EgyptVaccineRule extends FollowUpRule {
  const EgyptVaccineRule();

  static const ruleId = 'vaccines.egypt';

  @override
  String get id => ruleId;

  @override
  List<FollowUp> evaluate(FollowUpSubject subject, DateTime today) {
    final child = childVaccines(subject.profile, [
      for (final r in subject.records) r.event,
    ], today);
    if (child == null) return const [];
    final open = [
      for (final s in child.statuses)
        if (s.open) s,
    ]..sort((a, b) => a.dueOn.compareTo(b.dueOn));
    if (open.isEmpty) return const [];
    final months = open.first.dose.ageMonths;
    // Doses due the same day (a catch-up dose's day can move from its age).
    final doses = [
      for (final s in open)
        if (dayOf(s.dueOn) == dayOf(open.first.dueOn)) s.dose,
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
        source: 'Egypt MoHP schedule (checked $egyptScheduleCheckedOn)',
        graceDays: overdueAfterDays,
      ),
    ];
  }
}
