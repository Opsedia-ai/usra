import '../../core/database/app_database.dart';
import '../../l10n/app_localizations.dart';
import '../medicines/min_hours.dart' show formatHours;
import '../medicines/reminders.dart' show PlannedReminder;

/// "N hours after this dose: <time>" (C8), only from the minimum hours
/// between doses the family typed on the medicine, kept with each entry
/// when it was saved (`GivenMedicine.intervalHours`). The app never
/// proposes an interval or an amount: no hours saved, no time and no
/// reminder.

/// When [given]'s saved hours have passed; null without them.
DateTime? hoursAfter(GivenMedicine given) {
  final h = given.intervalHours;
  if (h == null) return null;
  return given.givenAt.add(Duration(minutes: (h * 60).round()));
}

/// Next-dose reminders use ids from [nextDoseReminderIdBase] up to (not
/// including) the vaccine range at 900000.
const nextDoseReminderIdBase = 800000;
const _idRange = 100000;

/// A stable id for the reminder of one medicine given (FNV-1a).
int nextDoseReminderId(String givenId) {
  var hash = 0x811c9dc5;
  for (final unit in givenId.codeUnits) {
    hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
  }
  return nextDoseReminderIdBase + hash % _idRange;
}

/// Notification text for next-dose reminders.
class NextDoseTexts {
  const NextDoseTexts(this.l, {required this.discreet});

  final AppLocalizations l;

  /// No person or medicine name: "A reminder from Usra".
  final bool discreet;

  String title(NextDoseSource s) => discreet
      ? l.nextDoseDiscreetTitle
      : l.nextDoseTitle(s.person.displayName, s.given.name);

  /// Facts only: how long it has been. Never "give".
  String body(NextDoseSource s) => discreet
      ? l.nextDoseDiscreetBody
      : l.nextDoseBody(formatHours(s.given.intervalHours!, l.localeName));
}

/// One reminder per medicine per sick day, from the latest time it was
/// given, and only if that entry asked for one (a later dose without a
/// reminder cancels an earlier one's), at its saved hours after the dose.
/// Includes times passed within [keepPast], so notifications on screen can
/// be rewritten; the caller schedules future ones. Soonest first.
List<PlannedReminder> planNextDoseReminders(
  List<NextDoseSource> sources, {
  required NextDoseTexts texts,
  required DateTime now,
  Duration keepPast = const Duration(days: 7),
}) {
  final latest = <(String, String), NextDoseSource>{};
  for (final s in sources) {
    final key = (s.episode.id, s.medicine.id);
    final seen = latest[key];
    if (seen == null || s.given.givenAt.isAfter(seen.given.givenAt)) {
      latest[key] = s;
    }
  }
  final out = <PlannedReminder>[];
  for (final s in latest.values) {
    if (!s.given.remindNext) continue;
    final at = hoursAfter(s.given);
    if (at == null || at.isBefore(now.subtract(keepPast))) continue;
    out.add(
      PlannedReminder.nextDose(
        id: nextDoseReminderId(s.given.id),
        at: at,
        episodeId: s.episode.id,
        profileId: s.person.id,
        title: texts.title(s),
        body: texts.body(s),
        locale: texts.l.localeName,
      ),
    );
  }
  out.sort((a, b) => a.at.compareTo(b.at));
  return out;
}

/// The reminders for [db]'s sick days now.
Future<List<PlannedReminder>> loadNextDoseReminders(
  AppDatabase db, {
  required DateTime now,
  required NextDoseTexts texts,
}) async => planNextDoseReminders(
  await db.watchNextDoseSources().first,
  texts: texts,
  now: now,
);
