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
    this.vaccines,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final AppDatabase db;
  final ReminderScheduler scheduler;
  final DoseActionInbox inbox;

  /// Notification and widget text in the app's current language and
  /// discreet setting.
  final ReminderTexts Function() texts;

  /// The home-screen widget; none in tests that don't need it.
  final WidgetSnapshotPublisher? widget;

  /// Vaccine visit reminders to schedule alongside the doses (see
  /// `children/vaccine_reminders.dart`); none when null.
  final Future<List<PlannedReminder>> Function(DateTime now)? vaccines;
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
            // Vaccine doses ticked and vaccine plans changed.
            db.medicalEvents,
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
    final t = texts();
    var vaccineReminders = const <PlannedReminder>[];
    try {
      vaccineReminders = await vaccines?.call(now) ?? const [];
    } catch (e, s) {
      // Dose reminders still go out.
      _report(e, s);
    }
    try {
      await scheduler.replaceAll(
        [
          ...planReminders(regimens, logs, now: now, texts: t),
          ...vaccineReminders,
        ]..sort((a, b) => a.at.compareTo(b.at)),
        doneSnoozes: doneSnoozeIds(logs),
        // Snoozes and notifications on screen follow the settings too.
        rebuild: (id, ref, at) {
          if (ref.isVaccine) {
            return vaccineReminders.where((r) => r.id == id).firstOrNull;
          }
          final r = _regimenOf(regimens, ref.medicineId);
          return r == null
              ? null
              : t.reminder(r, id: id, at: at, scheduledAt: ref.scheduledAt);
        },
      );
    } catch (e, s) {
      _report(e, s);
    }
    final widget = this.widget;
    if (widget == null) return;
    try {
      await ensureWidgetDateFormatting(t.l.localeName);
      await widget.publish(
        buildWidgetSnapshot(
          regimens,
          logs,
          now: now,
          l: t.l,
          discreet: t.discreet,
        ),
      );
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
  Future<void> handleAction(ReminderRef dose, String status) async {
    // Vaccine visits have no buttons.
    if (dose.isVaccine) return;
    final now = _clock();
    final saved = await _save(dose.medicineId, dose.scheduledAt, status, now);
    if (!saved || status != DoseOutcome.snoozed) return;
    final r = _regimenOf(await db.watchRegimens().first, dose.medicineId);
    if (r == null) return;
    await scheduler.add(
      texts().reminder(
        r,
        id: snoozeIdFor(dose.medicineId, dose.scheduledAt),
        at: now.add(snoozeDuration),
        scheduledAt: dose.scheduledAt,
      ),
    );
  }

  static Regimen? _regimenOf(List<Regimen> regimens, String medicineId) {
    for (final r in regimens) {
      if (r.medicine.id == medicineId) return r;
    }
    return null;
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
