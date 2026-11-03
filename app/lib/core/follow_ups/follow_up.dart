import '../database/app_database.dart';
import '../design/tokens.dart';
import '../records/record_type.dart';

/// Calendar date of [date] in UTC, so day counts ignore clock changes.
DateTime dayOf(DateTime date) => DateTime.utc(date.year, date.month, date.day);

/// From two weeks before its date a follow-up is "coming up"; after its date
/// it's overdue.
const followUpSoonDays = 14;

/// Something a person may want to do next: a check-up, a test, a dose.
///
/// Informational only: it says what public guidance or the person's own
/// records suggest, never a diagnosis. The UI always adds "ask your doctor".
class FollowUp {
  FollowUp({
    required this.ruleId,
    required this.profileId,
    required DateTime dueOn,
    required this.title,
    required this.reason,
    this.recordType,
    this.source,
    this.graceDays = 0,
  }) : dueOn = dayOf(dueOn);

  /// Stable for the same rule and person, e.g. `screening.colorectal` or
  /// `visit.<eventId>`.
  final String ruleId;
  final String profileId;

  /// The day it's due, as a UTC calendar date.
  final DateTime dueOn;
  final LabelBuilder title;

  /// Why it's suggested ("because she has diabetes").
  final LabelBuilder reason;

  /// The record type to add once it's done; null when there's none.
  final String? recordType;

  /// The public guidance it comes from, e.g. "USPSTF 2021".
  final String? source;

  /// Days after [dueOn] before it counts as overdue (the vaccine schedule
  /// allows a month).
  final int graceDays;

  /// Identifies this cycle: dismissing it hides it until the due date moves
  /// (a matching record is added, or the next cycle starts).
  String get cycleKey =>
      '$profileId|$ruleId|${dueOn.toIso8601String().substring(0, 10)}';

  /// Overdue (past [graceDays]): act soon. Within two weeks: heads-up. Later: info.
  Severity severityOn(DateTime today) {
    final days = dueOn.difference(dayOf(today)).inDays;
    if (days < -graceDays) return Severity.actSoon;
    if (days <= followUpSoonDays) return Severity.headsUp;
    return Severity.info;
  }
}

/// A record with its `dataJson` decoded.
typedef SubjectRecord = ({MedicalEvent event, Map<String, Object?> data});

/// One person and their records, decoded once for every rule.
class FollowUpSubject {
  FollowUpSubject(this.profile, List<MedicalEvent> events)
    : records = [
        for (final e in events)
          if (e.deletedAt == null)
            (event: e, data: decodeRecordData(e.dataJson)),
      ]..sort((a, b) => a.event.occurredAt.compareTo(b.event.occurredAt));

  final Profile profile;

  /// Oldest first.
  final List<SubjectRecord> records;

  Iterable<SubjectRecord> ofType(String type) =>
      records.where((r) => r.event.type == type);
}

/// Turns a person and their records into follow-ups.
///
/// One class per rule; modules contribute theirs through
/// `FeatureModule.followUpRules`, so the core never knows them.
abstract class FollowUpRule {
  const FollowUpRule();

  /// Unique among rules; prefixes the [FollowUp.ruleId]s it makes.
  String get id;

  List<FollowUp> evaluate(FollowUpSubject subject, DateTime today);
}

/// Runs every rule and sorts the result, soonest first.
List<FollowUp> followUpsFor(
  FollowUpSubject subject,
  DateTime today,
  Iterable<FollowUpRule> rules,
) =>
    [for (final rule in rules) ...rule.evaluate(subject, today)]
      ..sort((a, b) => a.dueOn.compareTo(b.dueOn));
