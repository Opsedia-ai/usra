import 'dart:io';
import 'dart:math';
import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../core/database/app_database.dart';
import 'reminders.dart';

const _channelId = 'doses';
const _category = 'dose';
const takenActionId = 'taken';
const snoozeActionId = 'snooze';

/// What a tap on a dose notification asks for: `status` is
/// [DoseOutcome.taken] or [DoseOutcome.snoozed] for the action buttons, null
/// when the notification itself was tapped.
typedef DoseResponse = ({PlannedReminder reminder, String? status});

/// [ReminderScheduler] on the phone's notifications
/// (flutter_local_notifications).
///
/// Every reminder is a one-off at an exact instant (in UTC, so the phone's
/// time zone database doesn't matter); the app plans the next week and
/// re-plans on start, on resume and whenever medicines or doses change.
/// Android re-arms them after a reboot (ScheduledNotificationBootReceiver).
class LocalNotificationScheduler implements ReminderScheduler {
  LocalNotificationScheduler._(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;
  static const _battery = MethodChannel('usra/battery');

  /// Sets up notifications. Taps and actions handled while the app runs
  /// call [onResponse]; the ones that launched the app are returned by
  /// [launchResponse]. [channelName] and the action labels are in the
  /// app's language (iOS fixes action labels here, once per launch).
  static Future<LocalNotificationScheduler> init({
    required String channelName,
    required String takenLabel,
    required String snoozeLabel,
    required void Function(DoseResponse response) onResponse,
  }) async {
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(
      settings: _settings(takenLabel: takenLabel, snoozeLabel: snoozeLabel),
      onDidReceiveNotificationResponse: (r) {
        final response = _read(r);
        if (response != null) onResponse(response);
      },
      onDidReceiveBackgroundNotificationResponse: onBackgroundDoseResponse,
    );
    final android = plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.createNotificationChannel(
      AndroidNotificationChannel(
        _channelId,
        channelName,
        importance: Importance.max,
      ),
    );
    return LocalNotificationScheduler._(plugin);
  }

  /// The tap or action that launched the app, if any.
  Future<DoseResponse?> launchResponse() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details == null || !details.didNotificationLaunchApp) return null;
    final r = details.notificationResponse;
    return r == null ? null : _read(r);
  }

  static InitializationSettings _settings({
    required String takenLabel,
    required String snoozeLabel,
  }) => InitializationSettings(
    android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
    iOS: DarwinInitializationSettings(
      // Asked from the Medicines tab, when reminders are first needed.
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      notificationCategories: [
        DarwinNotificationCategory(
          _category,
          actions: [
            DarwinNotificationAction.plain(takenActionId, takenLabel),
            DarwinNotificationAction.plain(snoozeActionId, snoozeLabel),
          ],
        ),
      ],
    ),
  );

  static DoseResponse? _read(NotificationResponse r) {
    final reminder = PlannedReminder.fromPayload(r.payload);
    if (reminder == null) return null;
    return (reminder: reminder, status: _statusOf(r.actionId));
  }

  static String? _statusOf(String? actionId) => switch (actionId) {
    takenActionId => DoseOutcome.taken,
    snoozeActionId => DoseOutcome.snoozed,
    _ => null,
  };

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  IOSFlutterLocalNotificationsPlugin? get _ios => _plugin
      .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin
      >();

  @override
  Future<ReminderAccess> access() async {
    final android = _android;
    if (android != null) {
      return ReminderAccess(
        notifications: await android.areNotificationsEnabled() ?? false,
        exactAlarms: await android.canScheduleExactNotifications() ?? false,
        batteryUnrestricted: await _batteryUnrestricted(),
      );
    }
    final ios = _ios;
    if (ios != null) {
      final p = await ios.checkPermissions();
      return ReminderAccess(notifications: p?.isEnabled ?? false);
    }
    return const ReminderAccess(notifications: false);
  }

  Future<bool?> _batteryUnrestricted() async {
    try {
      return await _battery.invokeMethod<bool>('isIgnoringOptimizations');
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Future<ReminderAccess> requestAccess({bool exactAlarms = true}) async {
    final android = _android;
    if (android != null) {
      // Android 13+ asks; older versions allow notifications by default.
      await android.requestNotificationsPermission();
      // Android 12+: opens the "Alarms & reminders" screen if not allowed.
      if (exactAlarms &&
          await android.canScheduleExactNotifications() == false) {
        await android.requestExactAlarmsPermission();
      }
    }
    await _ios?.requestPermissions(alert: true, badge: false, sound: true);
    return access();
  }

  @override
  Future<void> openBatterySettings() async {
    try {
      await _battery.invokeMethod<void>('openSettings');
    } on PlatformException {
      // No such screen on this phone.
    } on MissingPluginException {
      // Not Android.
    }
  }

  @override
  Future<void> replaceAll(
    List<PlannedReminder> reminders, {
    Set<int> doneSnoozes = const {},
  }) async {
    final pending = await _plugin.pendingNotificationRequests();
    final snoozes = pending.where((p) => p.id >= snoozeIdBase).length;
    // iOS keeps only 64 pending notifications, snoozes included.
    final room = Platform.isIOS ? max(0, _iosLimit - snoozes) : _androidLimit;
    final wanted = {for (final r in reminders.take(room)) r.id: r};
    // Leave unchanged reminders alone: cancelling and re-adding one that's
    // about to ring could lose it.
    final kept = <int>{};
    for (final p in pending) {
      if (p.id >= snoozeIdBase) {
        if (doneSnoozes.contains(p.id)) await _plugin.cancel(id: p.id);
        continue;
      }
      if (wanted[p.id]?.toPayload() == p.payload) {
        kept.add(p.id);
      } else {
        await _plugin.cancel(id: p.id);
      }
    }
    final mode = await _mode();
    // Planned a moment ago; one that's due by now would be refused.
    final soonest = DateTime.now().add(const Duration(seconds: 1));
    for (final r in wanted.values) {
      if (kept.contains(r.id) || r.at.isBefore(soonest)) continue;
      await _schedule(_plugin, r, mode);
    }
  }

  static const _iosLimit = 64;

  /// Well under Samsung's 500 alarms per app.
  static const _androidLimit = 200;

  @override
  Future<void> add(PlannedReminder reminder) async {
    await _schedule(_plugin, reminder, await _mode());
  }

  /// Exact when allowed; otherwise Android may ring a few minutes late.
  Future<AndroidScheduleMode> _mode() async =>
      await _android?.canScheduleExactNotifications() == false
      ? AndroidScheduleMode.inexactAllowWhileIdle
      : AndroidScheduleMode.exactAllowWhileIdle;
}

Future<void> _schedule(
  FlutterLocalNotificationsPlugin plugin,
  PlannedReminder r,
  AndroidScheduleMode mode,
) {
  return plugin.zonedSchedule(
    id: r.id,
    scheduledDate: tz.TZDateTime.from(r.at.toUtc(), tz.UTC),
    title: r.title,
    body: r.body,
    payload: r.toPayload(),
    androidScheduleMode: mode,
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        // Only used if the channel was never created; init creates it.
        _channelId,
        importance: Importance.max,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
        // Medicine names are health data: hidden on a secure lock screen.
        visibility: NotificationVisibility.private,
        actions: [
          AndroidNotificationAction(takenActionId, r.takenLabel),
          AndroidNotificationAction(snoozeActionId, r.snoozeLabel),
        ],
      ),
      iOS: const DarwinNotificationDetails(categoryIdentifier: _category),
    ),
  );
}

/// Taken / Snooze pressed while the app wasn't running, in a background
/// isolate that can't open the encrypted database: the action is left in
/// the inbox for the app, and a snooze is scheduled right here.
@pragma('vm:entry-point')
Future<void> onBackgroundDoseResponse(NotificationResponse response) async {
  final reminder = PlannedReminder.fromPayload(response.payload);
  final status = LocalNotificationScheduler._statusOf(response.actionId);
  if (reminder == null || status == null) return;
  DartPluginRegistrant.ensureInitialized();
  final now = DateTime.now();
  (await DoseActionInbox.open()).add(
    DoseAction(
      medicineId: reminder.medicineId,
      scheduledAt: reminder.scheduledAt,
      status: status,
      at: now,
    ),
  );
  if (status != DoseOutcome.snoozed) return;
  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(
    settings: LocalNotificationScheduler._settings(
      takenLabel: reminder.takenLabel,
      snoozeLabel: reminder.snoozeLabel,
    ),
    onDidReceiveBackgroundNotificationResponse: onBackgroundDoseResponse,
  );
  final exact =
      await plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.canScheduleExactNotifications() !=
      false;
  await _schedule(
    plugin,
    reminder.snoozed(now),
    exact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle,
  );
}
