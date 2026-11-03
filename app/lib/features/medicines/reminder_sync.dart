import 'dart:async';

import 'package:drift/drift.dart' show TableUpdateQuery;
import 'package:flutter/widgets.dart';

import '../../core/database/app_database.dart';
import 'dose_widget.dart';
import 'reminders.dart';

/// Keeps the phone's scheduled reminders in step with the database.
///
/// Re-plans the next week of reminders when the app starts, when it comes
/// back to the foreground, every few hours while open, and shortly after
/// any change to people, medicines, schedules or doses. Also saves doses
/// marked from notifications or the home-screen widget while the app
/// wasn't running, and hands the widget the doses still due.
class ReminderSync with WidgetsBindingObserver {
  ReminderSync({
    required this.db,
    required this.scheduler,
    required this.inbox,
    required this.texts,
    this.widget,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final AppDatabase db;
  final ReminderScheduler scheduler;
  final DoseActionInbox inbox;

  /// Notification text in the app's current language.
  final ReminderTexts Function() texts;

  /// The home-screen widget; none in tests that don't need it.
  final WidgetSnapshotPublisher? widget;
  final DateTime Function() _clock;

  StreamSubscription<void>? _changes;
  Timer? _debounce;
  Timer? _periodic;
  Future<void>? _running;
  bool _again = false;

  Future<void> start() async {
    WidgetsBinding.instance.addObserver(this);
    _changes = db
        .tableUpdates(
          TableUpdateQuery.onAllTables([
            db.profiles,
            db.medicines,
            db.doseSchedules,
            db.doseLogs,
          ]),
        )
        .listen((_) => _soon());
    // Re-plan as the week moves on, and pick up actions from notifications
    // pressed while the app is open (Android handles those in the
    // background too).
    var ticks = 0;
    _periodic = Timer.periodic(const Duration(minutes: 1), (_) {
      if (++ticks % 360 == 0 || inbox.hasActions) resync();
    });
    await resync();
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _changes?.cancel();
    _debounce?.cancel();
    _periodic?.cancel();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) resync();
  }

  void _soon() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), resync);
  }

  /// Saves waiting notification actions, then re-plans. Calls made while
  /// one runs are folded into one more run after it.
  Future<void> resync() {
    if (_running != null) {
      _again = true;
      return _running!;
    }
    return _running = _run().whenComplete(() {
      _running = null;
      if (_again) {
        _again = false;
        resync();
      }
    });
  }

  Future<void> _run() async {
    // Read before the inbox: a Taken pressed on the widget after this
    // isn't in the snapshot, and the widget keeps hiding it.
    final now = _clock();
    final List<Regimen> regimens;
    final List<DoseLog> logs;
    try {
      await saveInbox();
      regimens = await db.watchRegimens().first;
      logs = await db
          .watchDoseLogs(
            from: now.subtract(const Duration(days: 1)),
            to: now.add(const Duration(days: 8)),
          )
          .first;
    } catch (e, s) {
      _report(e, s);
      return;
    }
    // Each on its own: a broken widget never stops reminders.
    try {
      await scheduler.replaceAll(
        planReminders(regimens, logs, now: now, texts: texts()),
      );
    } catch (e, s) {
      _report(e, s);
    }
    final widget = this.widget;
    if (widget == null) return;
    try {
      final l = texts().l;
      await ensureWidgetDateFormatting(l.localeName);
      await widget.publish(buildWidgetSnapshot(regimens, logs, now: now, l: l));
    } catch (e, s) {
      _report(e, s);
    }
  }

  /// Reminders must never take the app down; the next run retries.
  void _report(Object e, StackTrace s) => FlutterError.reportError(
    FlutterErrorDetails(exception: e, stack: s, library: 'reminders'),
  );

  /// Moves doses marked from notifications into the database.
  Future<void> saveInbox() async {
    // Twice: an earlier, interrupted run may have left a batch behind.
    for (var i = 0; i < 2; i++) {
      final actions = inbox.take();
      if (actions.isEmpty) return;
      for (final a in actions) {
        await _save(a.medicineId, a.scheduledAt, a.status, a.at);
      }
      inbox.done();
    }
  }

  /// A Taken or Snooze action handled while the app is running.
  Future<void> handleAction(PlannedReminder reminder, String status) async {
    final now = _clock();
    final saved = await _save(
      reminder.medicineId,
      reminder.scheduledAt,
      status,
      now,
    );
    if (saved && status == DoseOutcome.snoozed) {
      await scheduler.add(reminder.snoozed(now));
    }
  }

  Future<bool> _save(
    String medicineId,
    DateTime scheduledAt,
    String status,
    DateTime at,
  ) async {
    try {
      return await db.logDose(medicineId, scheduledAt, status, at: at);
    } on Exception {
      // The medicine was deleted since; nothing to record.
      return false;
    }
  }
}
