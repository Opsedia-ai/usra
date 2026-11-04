import '../../core/database/app_database.dart';
import '../../l10n/app_localizations.dart';
import '../medicines/reminders.dart' show PlannedReminder, snoozeIdBase;
import 'child_vaccines.dart';
import 'egypt_vaccines.dart';

/// The records vaccine reminders are planned from.
const vaccineRecordTypes = {'vaccine', VaccinePlanFields.type};

/// Vaccine reminders use ids from here, under [snoozeIdBase], so they are
/// "planned" reminders and never collide with medicine ones (1-60).
const vaccineReminderIdBase = 900000;

/// At most this many vaccine reminders are scheduled at once.
const maxVaccineReminders = 20;

/// Reminders are planned for visits up to this many days ahead; the app
/// re-plans every time it opens.
const vaccineReminderHorizonDays = 60;

/// The reminder before a visit rings this many days ahead.
const vaccineReminderLeadDays = 7;

class VaccineReminderSettings {
  const VaccineReminderSettings({this.enabled = true, this.minutes = 600});

  final bool enabled;

  /// Time of day, in minutes after midnight (10:00 by default).
  final int minutes;
}

/// Vaccine reminder text in the app's language. Discreet: no child's or
/// vaccine's name, here or on the lock screen.
class VaccineReminderTexts {
  const VaccineReminderTexts(this.l, {required this.discreet});

  final AppLocalizations l;
  final bool discreet;

  String title(Profile child, {required bool today}) =>
      switch ((discreet, today)) {
        (true, false) => l.vaccineReminderDiscreetTitle,
        (true, true) => l.vaccineReminderDiscreetTodayTitle,
        (false, false) => l.vaccineReminderWeekTitle(child.displayName),
        (false, true) => l.vaccineReminderTodayTitle(child.displayName),
      };

  String body(List<ScheduledDose> doses) => discreet
      ? l.vaccineReminderDiscreetBody
      : {for (final d in doses) vaccineName(l, d.kind)}.join('، ');
}

/// The vaccine reminders to have scheduled at [now]: for every visit in the
/// next [vaccineReminderHorizonDays] days with doses still to give, one a
/// week before and one on the day, at the chosen time. Overdue doses get
/// none (Home shows them). Soonest first, at most [max].
List<PlannedReminder> planVaccineReminders(
  List<ChildVaccines> children, {
  required DateTime now,
  required VaccineReminderSettings settings,
  required VaccineReminderTexts texts,
  int max = maxVaccineReminders,
}) {
  if (!settings.enabled) return const [];
  final today = DateTime(now.year, now.month, now.day);
  final horizon = today.add(const Duration(days: vaccineReminderHorizonDays));
  final hour = settings.minutes ~/ 60, minute = settings.minutes % 60;
  final out =
      <
        ({
          DateTime at,
          Profile child,
          DateTime dueOn,
          bool today,
          List<ScheduledDose> doses,
        })
      >[];
  for (final c in children) {
    final byDate = <DateTime, List<ScheduledDose>>{};
    for (final s in c.statuses) {
      if (!s.open || s.dueOn.isBefore(today) || s.dueOn.isAfter(horizon)) {
        continue;
      }
      (byDate[s.dueOn] ??= []).add(s.dose);
    }
    for (final MapEntry(key: due, value: doses) in byDate.entries) {
      for (final (lead, isToday) in [
        (vaccineReminderLeadDays, false),
        (0, true),
      ]) {
        final at = DateTime(due.year, due.month, due.day - lead, hour, minute);
        if (!at.isAfter(now)) continue;
        out.add((
          at: at,
          child: c.profile,
          dueOn: due,
          today: isToday,
          doses: doses,
        ));
      }
    }
  }
  out.sort((a, b) => a.at.compareTo(b.at));
  return [
    for (final (i, r) in out.take(max).indexed)
      PlannedReminder.vaccine(
        id: vaccineReminderIdBase + i + 1,
        at: r.at,
        profileId: r.child.id,
        dueOn: r.dueOn,
        title: texts.title(r.child, today: r.today),
        body: texts.body(r.doses),
        locale: texts.l.localeName,
      ),
  ];
}

/// Reads every child's plan and vaccine records and plans their reminders.
Future<List<PlannedReminder>> loadVaccineReminders(
  AppDatabase db, {
  required DateTime now,
  required VaccineReminderSettings settings,
  required VaccineReminderTexts texts,
}) async {
  if (!settings.enabled) return const [];
  final profiles = await db.watchProfiles().first;
  final events = await db.eventsOfTypes(vaccineRecordTypes);
  final byProfile = <String, List<MedicalEvent>>{};
  for (final e in events) {
    (byProfile[e.profileId] ??= []).add(e);
  }
  return planVaccineReminders(
    [
      for (final p in profiles)
        ?childVaccines(p, byProfile[p.id] ?? const [], now),
    ],
    now: now,
    settings: settings,
    texts: texts,
  );
}
