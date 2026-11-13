import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Locale;

import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:path_provider_foundation/path_provider_foundation.dart';

import '../../core/database/app_database.dart';
import '../../l10n/app_localizations.dart';
import 'dose_schedule.dart';
import '../../core/util/separator.dart';

/// How long "Snooze" puts a reminder off.
const snoozeDuration = Duration(minutes: 10);

/// Reminder ids at or above this are snoozes, which outlive a re-plan;
/// planned reminders use the ids below it.
const snoozeIdBase = 1000000;

/// iOS fixes a category's buttons, so each set of buttons is its own
/// category, and a notification keeps the one it was scheduled with.
///
/// With names: Taken, Snooze and Skip.
const namedCategory = 'dose';

/// Neutral text, and this dose can be told from any other: Taken, Snooze
/// and Skip, the first and last only on an unlocked phone.
const discreetLoneCategory = 'dose_discreet_lone';

/// Neutral text that could be another dose's: Snooze only. Reminders
/// scheduled by older versions have this one too.
const discreetCategory = 'dose_discreet';

/// In discreet mode, doses this close together get no Taken or Skip: their
/// notifications and widget rows say nothing about who or what, so someone
/// who has just given one could press the other's button.
const doseClashWindow = Duration(hours: 1);

/// How far back to look for a dose that could still ring: one planned earlier
/// and snoozed can ring next to one due now. Inside the day of logs the app
/// reads, by [doseClashWindow].
const doseCompanyLookback = Duration(hours: 23);

/// Whether a dose's neutral notification can be told from other doses'.
enum DoseCompany {
  /// No other dose still due within [doseClashWindow]: its button can only
  /// mean this dose, and its text gives the planned time.
  alone,

  /// Another dose is still due within [doseClashWindow].
  several,

  /// Not known here (already marked, or outside what was read), so it's
  /// treated as if it could be another dose's.
  unknown,
}

/// The key for a dose in [doseCompanyOf].
String doseKey(String medicineId, DateTime scheduledAt) =>
    '$medicineId@${scheduledAt.millisecondsSinceEpoch}';

/// The company each dose still due from [from] to [to] keeps, by [doseKey];
/// a dose that isn't there is [DoseCompany.unknown]. A snoozed dose counts
/// both at its planned time and when its snooze rings. [logs] must reach
/// [doseClashWindow] beyond both ends: a dose whose log isn't read counts as
/// still due, which only ever takes buttons away.
Map<String, DoseCompany> doseCompanyOf(
  List<Regimen> regimens,
  List<DoseLog> logs, {
  required DateTime from,
  required DateTime to,
}) {
  final due = [
    for (final d in plannedDoses(
      regimens,
      logs,
      from: from.subtract(doseClashWindow),
      to: to.add(doseClashWindow),
    ))
      if (!d.isDone) d,
  ];
  // Every time a dose rings, in order, so only neighbours need comparing.
  final rings = [
    for (final (i, d) in due.indexed) ...[
      (at: d.at, dose: i),
      if (d.log?.status == DoseOutcome.snoozed)
        (at: d.log!.at.toLocal().add(snoozeDuration), dose: i),
    ],
  ]..sort((a, b) => a.at.compareTo(b.at));
  final close = <int>{};
  for (var a = 0; a < rings.length; a++) {
    for (var b = a + 1; b < rings.length; b++) {
      if (rings[b].at.difference(rings[a].at) > doseClashWindow) break;
      if (rings[a].dose != rings[b].dose) {
        close
          ..add(rings[a].dose)
          ..add(rings[b].dose);
      }
    }
  }
  return {
    for (final (i, d) in due.indexed)
      if (!d.at.isBefore(from) && d.at.isBefore(to))
        doseKey(d.regimen.medicine.id, d.at): close.contains(i)
            ? DoseCompany.several
            : DoseCompany.alone,
  };
}

/// [at] as "٨:٠٠ م" in [localeName]: Egyptian Arabic, whose times are big
/// and familiar; plain `ar` uses Western digits. Call
/// [ensureDoseTimeFormatting] first.
String doseTimeText(DateTime at, String localeName) =>
    DateFormat.jm(_timeLocale(localeName)).format(at.toLocal());

String _timeLocale(String localeName) =>
    localeName == 'ar' ? 'ar_EG' : localeName;

/// Date formats for [localeName]; reminders may be planned before the app's
/// localizations have loaded them.
Future<void> ensureDoseTimeFormatting(String localeName) =>
    initializeDateFormatting(_timeLocale(localeName));

/// Which dose a notification is for, and nothing else: what its payload
/// holds. The text is never saved there; it's rebuilt from the current
/// settings whenever the notification is scheduled.
class ReminderRef {
  const ReminderRef({
    required this.medicineId,
    required this.scheduledAt,
    required this.locale,
    this.at,
    this.profileId,
    this.episodeId,
  });

  /// Empty for a vaccine visit or a next-dose reminder.
  final String medicineId;

  /// The child, for a vaccine visit reminder; the person, for a next-dose
  /// reminder; null for a dose.
  final String? profileId;

  /// The sick day, for a next-dose reminder (see
  /// `sick_days/next_dose.dart`).
  final String? episodeId;

  bool get isVaccine => profileId != null && episodeId == null;

  bool get isNextDose => episodeId != null;

  /// The dose's planned time, the key its log is saved under.
  final DateTime scheduledAt;

  /// When it rings; unknown for payloads saved by older versions.
  final DateTime? at;

  /// The app's language when it was scheduled, for a snooze set from the
  /// notification while the app isn't running.
  final String locale;

  String toPayload() => jsonEncode({
    if (episodeId != null) ...{
      'f': episodeId,
      'p': profileId,
    } else if (profileId != null)
      'v': profileId
    else
      'm': medicineId,
    's': scheduledAt.toUtc().millisecondsSinceEpoch,
    if (at != null) 'a': at!.toUtc().millisecondsSinceEpoch,
    'l': locale,
  });

  /// Reads [toPayload], and the payloads of older versions (which also
  /// carried the text); null if [payload] isn't one of ours.
  static ReminderRef? fromPayload(String? payload) {
    if (payload == null) return null;
    try {
      final j = jsonDecode(payload);
      if (j is! Map) return null;
      DateTime utc(Object? ms) =>
          DateTime.fromMillisecondsSinceEpoch(ms! as int, isUtc: true);
      final episode = j['f'] as String?;
      if (episode != null) {
        return ReminderRef(
          medicineId: '',
          episodeId: episode,
          profileId: j['p'] as String?,
          scheduledAt: utc(j['s']),
          at: j['a'] == null ? null : utc(j['a']),
          locale: j['l'] as String? ?? 'ar',
        );
      }
      final child = j['v'] as String?;
      return ReminderRef(
        medicineId: child == null ? j['m'] as String : '',
        profileId: child,
        scheduledAt: utc(j['s']),
        at: j['a'] == null ? null : utc(j['a']),
        locale: j['l'] as String? ?? 'ar',
      );
    } on Object {
      return null;
    }
  }
}

/// One notification to show at [at], for one dose.
class PlannedReminder {
  const PlannedReminder({
    required this.id,
    required this.at,
    required this.medicineId,
    required this.scheduledAt,
    required this.title,
    required this.body,
    required this.takenLabel,
    required this.snoozeLabel,
    this.skipLabel,
    this.discreet = false,
    this.locale = 'ar',
    this.profileId,
  }) : episodeId = null;

  /// A vaccine visit for this child, with no buttons (see
  /// `vaccine_reminders.dart`); [medicineId] is empty then.
  PlannedReminder.vaccine({
    required this.id,
    required this.at,
    required String this.profileId,
    required DateTime dueOn,
    required this.title,
    required this.body,
    this.locale = 'ar',
  }) : medicineId = '',
       scheduledAt = dueOn,
       episodeId = null,
       takenLabel = null,
       snoozeLabel = null,
       skipLabel = null,
       discreet = false;

  /// "The next dose is allowed" for a medicine given in a sick day, with
  /// no buttons in either mode (see `sick_days/next_dose.dart`).
  /// [medicineId] is empty; [scheduledAt] is when it rings.
  PlannedReminder.nextDose({
    required this.id,
    required this.at,
    required String this.episodeId,
    required String this.profileId,
    required this.title,
    required this.body,
    this.locale = 'ar',
  }) : medicineId = '',
       scheduledAt = at,
       takenLabel = null,
       snoozeLabel = null,
       skipLabel = null,
       discreet = false;

  final int id;

  /// When to ring.
  final DateTime at;
  final String medicineId;

  /// The dose's planned time, the key its log is saved under.
  final DateTime scheduledAt;
  final String title;
  final String body;

  /// The Taken button. None on a neutral notification that could be another
  /// dose's (see [DoseCompany]), where it could mark someone else's dose,
  /// nor on a vaccine visit.
  final String? takenLabel;

  /// None on a vaccine visit: a week's notice needs no snooze.
  final String? snoozeLabel;

  /// The Skip button; none wherever there is no Taken, for the same reason.
  final String? skipLabel;

  /// Neutral text, with no person's or medicine's name.
  final bool discreet;
  final String locale;

  /// The child, for a vaccine visit; the person, for a next-dose reminder.
  final String? profileId;

  /// The sick day, for a next-dose reminder.
  final String? episodeId;

  bool get isVaccine => profileId != null && episodeId == null;

  bool get isNextDose => episodeId != null;

  /// Taken or Snooze; vaccine and next-dose reminders have none.
  bool get hasButtons => takenLabel != null || snoozeLabel != null;

  /// The iOS category with this reminder's buttons; none without buttons.
  String? get iosCategory => !hasButtons
      ? null
      : takenLabel == null
      ? discreetCategory
      : discreet
      ? discreetLoneCategory
      : namedCategory;

  ReminderRef get ref => ReminderRef(
    medicineId: medicineId,
    scheduledAt: scheduledAt,
    at: at,
    locale: locale,
    profileId: profileId,
    episodeId: episodeId,
  );

  String toPayload() => ref.toPayload();

  @override
  String toString() => 'PlannedReminder($id, $at, $title)';
}

/// A stable id for a dose's snooze, so snoozing it again replaces the
/// earlier one. FNV-1a: `String.hashCode` isn't guaranteed stable across
/// isolates or app versions.
int snoozeIdFor(String medicineId, DateTime scheduledAt) {
  var hash = 0x811c9dc5;
  for (final unit
      in '$medicineId@${scheduledAt.millisecondsSinceEpoch}'.codeUnits) {
    hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
  }
  return snoozeIdBase + hash % snoozeIdBase;
}

/// Turns doses into notification text in the app's language.
class ReminderTexts {
  const ReminderTexts(this.l, {required this.discreet});

  final AppLocalizations l;

  /// "Discreet notifications": no person's or medicine's name, here or on
  /// the home-screen widget, since both show on a phone others can see. A
  /// Taken button only where the dose can be told from others: see
  /// [DoseCompany].
  final bool discreet;

  String title(Regimen r) => discreet
      ? l.doseReminderDiscreetTitle
      : l.doseReminderTitle(
          r.person.displayName,
          [r.medicine.name, ?r.medicine.strength].join(' '),
        );

  /// The amount and the doctor's words, as written; nothing added.
  /// Discreet: the planned time when that tells the dose apart, otherwise
  /// where to see which, as the doctor's words can name a condition. Each
  /// [DoseCompany] reads differently, as text is all [diffReminders] can see
  /// of a reminder the phone holds.
  String body(
    Regimen r, {
    required DateTime scheduledAt,
    DoseCompany company = DoseCompany.unknown,
  }) {
    if (discreet) {
      return switch (company) {
        DoseCompany.alone => l.doseReminderDiscreetTimeBody(
          doseTimeText(scheduledAt, l.localeName),
        ),
        DoseCompany.several => l.doseReminderDiscreetSeveralBody,
        DoseCompany.unknown => l.doseReminderDiscreetBody,
      };
    }
    final parts = [?r.schedule.amount, ?r.medicine.instructions];
    return parts.isEmpty
        ? l.doseReminderBody(r.person.sex ?? 'other')
        : parts.join(partSeparator);
  }

  /// The reminder for [r]'s dose planned at [scheduledAt], ringing [at].
  /// Without [company], a discreet one gets no Taken.
  PlannedReminder reminder(
    Regimen r, {
    required int id,
    required DateTime at,
    required DateTime scheduledAt,
    DoseCompany company = DoseCompany.unknown,
  }) {
    final canMark = !discreet || company == DoseCompany.alone;
    return PlannedReminder(
      id: id,
      at: at,
      medicineId: r.medicine.id,
      scheduledAt: scheduledAt,
      title: title(r),
      body: body(r, scheduledAt: scheduledAt, company: company),
      takenLabel: canMark ? l.doseTaken : null,
      snoozeLabel: l.doseSnooze,
      skipLabel: canMark ? l.doseSkip : null,
      discreet: discreet,
      locale: l.localeName,
    );
  }

  /// [ref]'s dose without reading the database: always discreet, and with
  /// no Taken, as whether others are due can't be known here. For a snooze
  /// pressed while the app isn't running; the app adds what's missing when
  /// it next runs.
  static PlannedReminder generic(ReminderRef ref, {required DateTime at}) {
    final l = lookupAppLocalizations(Locale(ref.locale));
    return PlannedReminder(
      id: snoozeIdFor(ref.medicineId, ref.scheduledAt),
      at: at,
      medicineId: ref.medicineId,
      scheduledAt: ref.scheduledAt,
      title: l.doseReminderDiscreetTitle,
      body: l.doseReminderDiscreetBody,
      takenLabel: null,
      snoozeLabel: l.doseSnooze,
      discreet: true,
      locale: l.localeName,
    );
  }
}

/// The reminders to have scheduled at [now]: every dose due within
/// [window] that hasn't been marked, soonest first, at most [max] (iOS
/// keeps only 64 pending notifications).
List<PlannedReminder> planReminders(
  List<Regimen> regimens,
  List<DoseLog> logs, {
  required DateTime now,
  required ReminderTexts texts,
  Duration window = const Duration(days: 7),
  int max = 60,
}) {
  final to = now.add(window);
  final doses = plannedDoses(regimens, logs, from: now, to: to);
  final company = doseCompanyOf(
    regimens,
    logs,
    from: now.subtract(doseCompanyLookback),
    to: to,
  );
  final out = <PlannedReminder>[];
  for (final d in doses) {
    // A snoozed dose already has its own one-off reminder.
    if (d.log != null || !d.at.isAfter(now)) continue;
    if (out.length == max) break;
    out.add(
      texts.reminder(
        d.regimen,
        id: out.length + 1,
        at: d.at,
        scheduledAt: d.scheduledAt,
        company:
            company[doseKey(d.regimen.medicine.id, d.at)] ??
            DoseCompany.unknown,
      ),
    );
  }
  return out;
}

/// Dose and vaccine reminders in the order the phone should keep them when
/// it holds only so many (iOS: 64 pending): the [reserve] nearest vaccine
/// visits first, so a week of medicines can't crowd them all out, then the
/// rest by time.
List<PlannedReminder> prioritiseReminders(
  List<PlannedReminder> doses,
  List<PlannedReminder> vaccines, {
  int reserve = 4,
}) {
  final byTime = [...vaccines]..sort((a, b) => a.at.compareTo(b.at));
  return [
    ...byTime.take(reserve),
    ...[...doses, ...byTime.skip(reserve)]
      ..sort((a, b) => a.at.compareTo(b.at)),
  ];
}

/// The current text for the vaccine notification [ref] under [id], found
/// in [planned] by its child, visit and ringing time (ids are positions in
/// the plan, so they move when it changes); null if that visit isn't
/// planned any more, to leave it as it is.
PlannedReminder? vaccineReminderFor(
  List<PlannedReminder> planned,
  int id,
  ReminderRef ref,
) {
  for (final r in planned) {
    if (r.profileId != ref.profileId ||
        !r.scheduledAt.isAtSameMomentAs(ref.scheduledAt) ||
        (ref.at != null && !r.at.isAtSameMomentAs(ref.at!))) {
      continue;
    }
    return PlannedReminder.vaccine(
      id: id,
      at: r.at,
      profileId: r.profileId!,
      dueOn: r.scheduledAt,
      title: r.title,
      body: r.body,
      locale: r.locale,
    );
  }
  return null;
}

/// [ref]'s reminder with this [id] ringing [at], in the current text;
/// null to leave it as it is (its medicine was deleted).
typedef ReminderRebuild = PlannedReminder? Function(
  int id,
  ReminderRef ref,
  DateTime at,
);

/// A notification the phone has pending or on screen.
typedef PhoneReminder = ({
  int id,
  String? title,
  String? body,
  String? payload,
});

/// What [diffReminders] asks the phone to do.
class ReminderChanges {
  const ReminderChanges({
    this.cancel = const {},
    this.schedule = const [],
    this.repost = const [],
  });

  final Set<int> cancel;

  /// Scheduled after [cancel].
  final List<PlannedReminder> schedule;

  /// On screen with old text: shown again in place, silently.
  final List<PlannedReminder> repost;
}

/// How to make the phone's reminders match: planned reminders become
/// exactly [wanted] (unchanged ones left alone, so one about to ring is
/// never lost), snoozes in [doneSnoozes] are cancelled, and other snoozes
/// and notifications on screen whose text is out of date (the language or
/// discreet setting changed, or another dose now shares its time) are
/// rewritten with [rebuild].
ReminderChanges diffReminders({
  required List<PhoneReminder> pending,
  List<PhoneReminder> shown = const [],
  required List<PlannedReminder> wanted,
  Set<int> doneSnoozes = const {},
  ReminderRebuild? rebuild,
  required DateTime now,
}) {
  bool same(PlannedReminder r, PhoneReminder p) =>
      r.toPayload() == p.payload && r.title == p.title && r.body == p.body;
  final byId = {for (final r in wanted) r.id: r};
  final cancel = <int>{};
  final schedule = <PlannedReminder>[];
  final kept = <int>{};
  // Planned a moment ago; one that's due by now would be refused.
  final soonest = now.add(const Duration(seconds: 1));
  for (final p in pending) {
    if (p.id < snoozeIdBase) {
      final r = byId[p.id];
      if (r != null && same(r, p)) {
        kept.add(p.id);
      } else {
        cancel.add(p.id);
      }
      continue;
    }
    if (doneSnoozes.contains(p.id)) {
      cancel.add(p.id);
      continue;
    }
    final ref = ReminderRef.fromPayload(p.payload);
    if (ref == null || rebuild == null) continue;
    // Older versions didn't save when a snooze rings.
    final at = ref.at ?? now.add(snoozeDuration);
    final r = rebuild(p.id, ref, at.isBefore(soonest) ? soonest : at);
    if (r == null || same(r, p)) continue;
    cancel.add(p.id);
    schedule.add(r);
  }
  for (final r in wanted) {
    if (kept.contains(r.id) || r.at.isBefore(soonest)) continue;
    schedule.add(r);
  }
  final repost = <PlannedReminder>[];
  for (final s in shown) {
    final ref = ReminderRef.fromPayload(s.payload);
    // Already marked, in the app or on the widget: it leaves the screen, so a
    // dose that was given can't still read as due.
    if (ref != null &&
        !ref.isVaccine &&
        !ref.isNextDose &&
        doneSnoozes.contains(snoozeIdFor(ref.medicineId, ref.scheduledAt))) {
      cancel.add(s.id);
      continue;
    }
    final r = ref == null ? null : rebuild?.call(s.id, ref, ref.at ?? now);
    // A next-dose notification whose entry is gone (deleted, superseded by
    // a later dose, sick day over) leaves the screen too.
    if (r == null && ref != null && ref.isNextDose && rebuild != null) {
      cancel.add(s.id);
      continue;
    }
    if (r != null && (r.title != s.title || r.body != s.body)) repost.add(r);
  }
  return ReminderChanges(cancel: cancel, schedule: schedule, repost: repost);
}

/// Snooze ids of doses marked taken or skipped in [logs], however they
/// were marked (app, notification or widget), so a snooze set earlier
/// doesn't ring for a dose already taken.
Set<int> doneSnoozeIds(List<DoseLog> logs) => {
  for (final l in logs)
    if (l.status == DoseOutcome.taken || l.status == DoseOutcome.skipped)
      snoozeIdFor(l.medicineId, l.scheduledAt),
};

/// What the phone lets reminders do.
class ReminderAccess {
  const ReminderAccess({
    required this.notifications,
    this.exactAlarms = true,
    this.batteryUnrestricted,
  });

  /// Notifications may be shown at all.
  final bool notifications;

  /// Android 12+: alarms ring on the minute rather than within a window.
  final bool exactAlarms;

  /// Android: the app is exempt from battery optimisation; null where that
  /// doesn't apply.
  final bool? batteryUnrestricted;

  bool get complete => notifications && exactAlarms;
}

/// Schedules dose notifications on the phone. Tests use a fake.
abstract interface class ReminderScheduler {
  Future<ReminderAccess> access();

  /// Asks the user for what's missing; returns the result. Without
  /// [exactAlarms], only the notification prompt is shown (Android's
  /// exact-alarm permission is a whole settings screen).
  Future<ReminderAccess> requestAccess({bool exactAlarms = true});

  /// Opens the system screen where battery optimisation is switched off.
  Future<void> openBatterySettings();

  /// Makes the planned reminders (not snoozes) exactly [reminders]:
  /// unchanged ones are left alone, so one about to ring is never lost.
  /// Snoozes in [doneSnoozes] are cancelled: their dose was marked since.
  /// Other snoozes and notifications on screen get [rebuild]'s text if
  /// theirs is out of date. See [diffReminders].
  Future<void> replaceAll(
    List<PlannedReminder> reminders, {
    Set<int> doneSnoozes = const {},
    ReminderRebuild? rebuild,
  });

  /// Schedules one more reminder (a snooze), keeping the others.
  Future<void> add(PlannedReminder reminder);
}

/// A dose marked from a notification while the app wasn't running.
class DoseAction {
  const DoseAction({
    required this.medicineId,
    required this.scheduledAt,
    required this.status,
    required this.at,
  });

  final String medicineId;
  final DateTime scheduledAt;
  final String status;
  final DateTime at;

  Map<String, Object> toJson() => {
    'm': medicineId,
    's': scheduledAt.toUtc().millisecondsSinceEpoch,
    'st': status,
    'at': at.toUtc().millisecondsSinceEpoch,
  };

  static DoseAction? fromJson(Object? j) {
    if (j is! Map) return null;
    try {
      return DoseAction(
        medicineId: j['m'] as String,
        scheduledAt: DateTime.fromMillisecondsSinceEpoch(
          j['s'] as int,
          isUtc: true,
        ),
        status: j['st'] as String,
        at: DateTime.fromMillisecondsSinceEpoch(j['at'] as int, isUtc: true),
      );
    } on Object {
      return null;
    }
  }
}

/// Doses marked from notifications, waiting for the app to save them.
///
/// Notification actions can run in a background isolate that can't open
/// the encrypted database, so they append a line to this file, and the app
/// moves them into the database when it next runs.
class DoseActionInbox {
  DoseActionInbox(this.file);

  final File file;

  static const fileName = 'dose_actions.jsonl';

  /// The inbox for Taken on the iOS widget, in the App Group folder (an
  /// extension can't reach the app's private folder); null on other
  /// platforms or if the folder can't be found.
  static Future<DoseActionInbox?> openWidgetInbox(String appGroup) async {
    if (!Platform.isIOS) return null;
    final folder = await PathProviderFoundation().getContainerPath(
      appGroupIdentifier: appGroup,
    );
    return folder == null
        ? null
        : DoseActionInbox(File(p.join(folder, fileName)));
  }

  /// The inbox in the app's private folder. Looked up each time rather
  /// than saved in notifications: the iOS container path can change when
  /// the app is updated.
  static Future<DoseActionInbox> open() async => DoseActionInbox(
    File(p.join((await getApplicationSupportDirectory()).path, fileName)),
  );

  void add(DoseAction action) {
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(
      '${jsonEncode(action.toJson())}\n',
      mode: FileMode.append,
      flush: true,
    );
  }

  bool get hasActions =>
      file.existsSync() || File('${file.path}.taking').existsSync();

  /// The waiting actions, oldest first; the file is emptied.
  List<DoseAction> take() {
    // Rename first, so an action added meanwhile goes to a new file
    // instead of being deleted unread. A batch left by an interrupted run
    // is taken again first.
    final taken = File('${file.path}.taking');
    if (!taken.existsSync()) {
      if (!file.existsSync()) return const [];
      file.renameSync(taken.path);
    }
    final actions = <DoseAction>[];
    for (final line in taken.readAsLinesSync()) {
      if (line.trim().isEmpty) continue;
      try {
        final a = DoseAction.fromJson(jsonDecode(line));
        if (a != null) actions.add(a);
      } on FormatException {
        // A line cut short by a crash; skip it.
      }
    }
    return actions;
  }

  /// Call once [take]n actions are saved.
  void done() {
    final taken = File('${file.path}.taking');
    if (taken.existsSync()) taken.deleteSync();
  }

  /// Forgets everything waiting, for "Delete all my data".
  void clear() {
    for (final f in [file, File('${file.path}.taking')]) {
      if (f.existsSync()) f.deleteSync();
    }
  }
}

/// Used when the phone's notifications couldn't be set up: the app still
/// opens, and the Medicines tab shows reminders as off.
class UnavailableReminderScheduler implements ReminderScheduler {
  const UnavailableReminderScheduler();

  static const _none = ReminderAccess(notifications: false);

  @override
  Future<ReminderAccess> access() async => _none;

  @override
  Future<ReminderAccess> requestAccess({bool exactAlarms = true}) async =>
      _none;

  @override
  Future<void> openBatterySettings() async {}

  @override
  Future<void> replaceAll(
    List<PlannedReminder> reminders, {
    Set<int> doneSnoozes = const {},
    ReminderRebuild? rebuild,
  }) async {}

  @override
  Future<void> add(PlannedReminder reminder) async {}
}
