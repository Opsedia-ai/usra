import 'dart:convert';
import 'dart:io';

import '../../core/database/app_database.dart';
import '../../l10n/app_localizations.dart';
import 'dose_schedule.dart';

/// How long "Snooze" puts a reminder off.
const snoozeDuration = Duration(minutes: 10);

/// Reminder ids at or above this are snoozes, which outlive a re-plan;
/// planned reminders use the ids below it.
const snoozeIdBase = 1000000;

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
  });

  final int id;

  /// When to ring.
  final DateTime at;
  final String medicineId;

  /// The dose's planned time, the key its log is saved under.
  final DateTime scheduledAt;
  final String title;
  final String body;

  /// The notification's action buttons, already in the app's language:
  /// a background action may run where no localizations are loaded.
  final String takenLabel;
  final String snoozeLabel;

  /// The same dose again, [snoozeDuration] after [now].
  PlannedReminder snoozed(DateTime now) => PlannedReminder(
    id: snoozeIdFor(medicineId, scheduledAt),
    at: now.add(snoozeDuration),
    medicineId: medicineId,
    scheduledAt: scheduledAt,
    title: title,
    body: body,
    takenLabel: takenLabel,
    snoozeLabel: snoozeLabel,
  );

  /// Everything needed to act on, or snooze, this reminder from a
  /// notification, plus where to leave the action for the app ([inbox]).
  String toPayload({String? inbox}) => jsonEncode({
    'm': medicineId,
    's': scheduledAt.toUtc().millisecondsSinceEpoch,
    't': title,
    'b': body,
    'tl': takenLabel,
    'sl': snoozeLabel,
    'i': ?inbox,
  });

  /// Reads [toPayload]; null if [payload] isn't one of ours.
  static ({PlannedReminder reminder, String? inbox})? fromPayload(
    String? payload,
  ) {
    if (payload == null) return null;
    try {
      final j = jsonDecode(payload);
      if (j is! Map) return null;
      final scheduledAt = DateTime.fromMillisecondsSinceEpoch(
        j['s'] as int,
        isUtc: true,
      );
      return (
        reminder: PlannedReminder(
          id: snoozeIdFor(j['m'] as String, scheduledAt),
          at: scheduledAt,
          medicineId: j['m'] as String,
          scheduledAt: scheduledAt,
          title: j['t'] as String,
          body: j['b'] as String,
          takenLabel: j['tl'] as String,
          snoozeLabel: j['sl'] as String,
        ),
        inbox: j['i'] as String?,
      );
    } on Object {
      return null;
    }
  }

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
  const ReminderTexts(this.l);

  final AppLocalizations l;

  String title(Regimen r) => l.doseReminderTitle(
    r.person.displayName,
    [r.medicine.name, ?r.medicine.strength].join(' '),
  );

  /// The amount and the doctor's words, as written; nothing added.
  String body(Regimen r) {
    final parts = [?r.schedule.amount, ?r.medicine.instructions];
    return parts.isEmpty ? l.doseReminderBody : parts.join(' · ');
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
  final doses = plannedDoses(regimens, logs, from: now, to: now.add(window));
  final out = <PlannedReminder>[];
  for (final d in doses) {
    // A snoozed dose already has its own one-off reminder.
    if (d.log != null || !d.at.isAfter(now)) continue;
    if (out.length == max) break;
    out.add(
      PlannedReminder(
        id: out.length + 1,
        at: d.at,
        medicineId: d.regimen.medicine.id,
        scheduledAt: d.scheduledAt,
        title: texts.title(d.regimen),
        body: texts.body(d.regimen),
        takenLabel: texts.l.doseTaken,
        snoozeLabel: texts.l.doseSnooze,
      ),
    );
  }
  return out;
}

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

  /// Asks the user for what's missing; returns the result.
  Future<ReminderAccess> requestAccess();

  /// Opens the system screen where battery optimisation is switched off.
  Future<void> openBatterySettings();

  /// Cancels every planned reminder (not snoozes) and schedules
  /// [reminders] instead.
  Future<void> replaceAll(List<PlannedReminder> reminders);

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
}
