import '../../core/database/app_database.dart';
import '../../core/design/tokens.dart';
import '../../core/records/record_type.dart' show decodeRecordData;
import 'growth.dart';

/// The milestone record's type and data key.
const milestoneType = 'milestone';
const milestoneField = 'milestone';

/// The checklist is shown until the 6th birthday, a year past its last age.
const developmentMaxMonths = 72;

enum MilestoneArea { social, language, cognitive, movement }

/// Something most children (75% or more) can do by [months] of age.
class Milestone {
  const Milestone(this.id, this.months, this.area);

  /// Also the key of its text in the translations.
  final String id;
  final int months;
  final MilestoneArea area;
}

/// A selection from CDC's "Learn the Signs. Act Early." checklists (2022
/// revision), one per area at each well-child age from 2 months to 5 years.
const cdcMilestones = [
  Milestone('m2_social', 2, MilestoneArea.social),
  Milestone('m2_language', 2, MilestoneArea.language),
  Milestone('m2_cognitive', 2, MilestoneArea.cognitive),
  Milestone('m2_movement', 2, MilestoneArea.movement),
  Milestone('m4_social', 4, MilestoneArea.social),
  Milestone('m4_language', 4, MilestoneArea.language),
  Milestone('m4_cognitive', 4, MilestoneArea.cognitive),
  Milestone('m4_movement', 4, MilestoneArea.movement),
  Milestone('m6_social', 6, MilestoneArea.social),
  Milestone('m6_language', 6, MilestoneArea.language),
  Milestone('m6_cognitive', 6, MilestoneArea.cognitive),
  Milestone('m6_movement', 6, MilestoneArea.movement),
  Milestone('m9_social', 9, MilestoneArea.social),
  Milestone('m9_language', 9, MilestoneArea.language),
  Milestone('m9_cognitive', 9, MilestoneArea.cognitive),
  Milestone('m9_movement', 9, MilestoneArea.movement),
  Milestone('m12_social', 12, MilestoneArea.social),
  Milestone('m12_language', 12, MilestoneArea.language),
  Milestone('m12_cognitive', 12, MilestoneArea.cognitive),
  Milestone('m12_movement', 12, MilestoneArea.movement),
  Milestone('m15_social', 15, MilestoneArea.social),
  Milestone('m15_language', 15, MilestoneArea.language),
  Milestone('m15_cognitive', 15, MilestoneArea.cognitive),
  Milestone('m15_movement', 15, MilestoneArea.movement),
  Milestone('m18_social', 18, MilestoneArea.social),
  Milestone('m18_language', 18, MilestoneArea.language),
  Milestone('m18_cognitive', 18, MilestoneArea.cognitive),
  Milestone('m18_movement', 18, MilestoneArea.movement),
  Milestone('m24_social', 24, MilestoneArea.social),
  Milestone('m24_language', 24, MilestoneArea.language),
  Milestone('m24_cognitive', 24, MilestoneArea.cognitive),
  Milestone('m24_movement', 24, MilestoneArea.movement),
  Milestone('m30_social', 30, MilestoneArea.social),
  Milestone('m30_language', 30, MilestoneArea.language),
  Milestone('m30_cognitive', 30, MilestoneArea.cognitive),
  Milestone('m30_movement', 30, MilestoneArea.movement),
  Milestone('m36_social', 36, MilestoneArea.social),
  Milestone('m36_language', 36, MilestoneArea.language),
  Milestone('m36_cognitive', 36, MilestoneArea.cognitive),
  Milestone('m36_movement', 36, MilestoneArea.movement),
  Milestone('m48_social', 48, MilestoneArea.social),
  Milestone('m48_language', 48, MilestoneArea.language),
  Milestone('m48_cognitive', 48, MilestoneArea.cognitive),
  Milestone('m48_movement', 48, MilestoneArea.movement),
  Milestone('m60_social', 60, MilestoneArea.social),
  Milestone('m60_language', 60, MilestoneArea.language),
  Milestone('m60_cognitive', 60, MilestoneArea.cognitive),
  Milestone('m60_movement', 60, MilestoneArea.movement),
];

/// The checklist ages, youngest first.
final milestoneAges = {for (final m in cdcMilestones) m.months}.toList()
  ..sort();

/// After reaching a checklist age, a month to watch for its milestones
/// before suggesting a talk with the pediatrician.
const milestoneWatchMonths = 1;

enum MilestoneState {
  /// Ticked.
  done(Severity.good),

  /// Not that age yet.
  upcoming(Severity.info),

  /// Just reached that age: watch for it.
  watch(Severity.headsUp),

  /// A month past that age and not ticked: talk to the pediatrician.
  late(Severity.actSoon),

  /// An earlier age's milestone not ticked; the current age's list is what
  /// counts now.
  notTicked(Severity.info);

  const MilestoneState(this.severity);

  final Severity severity;
}

/// The latest checklist age a child of [ageMonths] has reached; null
/// before 2 months.
int? currentMilestoneAge(double ageMonths) {
  int? current;
  for (final a in milestoneAges) {
    if (a <= ageMonths) current = a;
  }
  return current;
}

/// Where [m] stands for a child of [ageMonths]: only the current age's
/// unticked milestones turn "talk to your pediatrician", so a family who
/// starts the checklist late isn't flooded by earlier ages.
MilestoneState milestoneState(
  Milestone m, {
  required double ageMonths,
  required bool ticked,
}) {
  if (ticked) return MilestoneState.done;
  if (ageMonths < m.months) return MilestoneState.upcoming;
  if (m.months != currentMilestoneAge(ageMonths)) {
    return MilestoneState.notTicked;
  }
  return ageMonths < m.months + milestoneWatchMonths
      ? MilestoneState.watch
      : MilestoneState.late;
}

/// The ticked milestones: id to the day it was first seen, with every
/// record ticking it (all are deleted when unticking).
Map<String, ({DateTime date, List<String> eventIds})> tickedMilestones(
  List<MedicalEvent> events,
) {
  final ticked = <String, ({DateTime date, List<String> eventIds})>{};
  for (final e in events) {
    if (e.type != milestoneType) continue;
    if (decodeRecordData(e.dataJson)[milestoneField] case final String id) {
      final seen = ticked[id];
      ticked[id] = (
        date: seen == null || e.occurredAt.isBefore(seen.date)
            ? e.occurredAt
            : seen.date,
        eventIds: [...?seen?.eventIds, e.id],
      );
    }
  }
  return ticked;
}

/// Whether the checklist is offered for someone born on [birthDate].
bool showsMilestones(DateTime? birthDate, DateTime now) =>
    birthDate != null &&
    !birthDate.isAfter(now) &&
    now.isBefore(addMonths(birthDate, developmentMaxMonths));
