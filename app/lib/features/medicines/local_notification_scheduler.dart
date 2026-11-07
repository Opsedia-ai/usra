import 'dart:io';
import 'dart:math';
import 'dart:ui' show DartPluginRegistrant, Locale;

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../core/database/app_database.dart';
import '../../core/security/app_lock.dart';
import '../../core/util/localized_digits.dart';
import '../../l10n/app_localizations.dart';
import 'reminders.dart';

const _channelId = 'doses';

/// Vaccine visits ring on their own channel, so either can be silenced.
const _vaccineChannelId = 'vaccines';
const takenActionId = 'taken';
const snoozeActionId = 'snooze';
const skipActionId = 'skip';

/// What a tap on a dose notification asks for: `status` is
/// [DoseOutcome.taken], [DoseOutcome.snoozed] or [DoseOutcome.skipped] for
/// the action buttons, null when the notification itself was tapped.
typedef DoseResponse = ({ReminderRef dose, String? status});

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
    required String vaccineChannelName,
    required String takenLabel,
    required String snoozeLabel,
    required String skipLabel,
    required String hiddenPreviewText,
    required void Function(DoseResponse response) onResponse,
  }) async {
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(
      settings: _settings(
        takenLabel: takenLabel,
        snoozeLabel: snoozeLabel,
        skipLabel: skipLabel,
      ),
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
    await android?.createNotificationChannel(
      AndroidNotificationChannel(
        _vaccineChannelId,
        vaccineChannelName,
        importance: Importance.high,
      ),
    );
    if (Platform.isIOS) await _hideLockScreenText(hiddenPreviewText);
    return LocalNotificationScheduler._(plugin);
  }

  static const _privacy = MethodChannel('usra/notification_privacy');

  /// iOS hides previews on the lock screen by default; this is what shows
  /// instead (rather than "Notification"). Android: see [_details].
  static Future<void> _hideLockScreenText(String text) async {
    try {
      await _privacy.invokeMethod<void>('setHiddenPreviewText', text);
    } on PlatformException {
      // The default placeholder is generic too.
    } on MissingPluginException {
      // The default placeholder is generic too.
    }
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
    required String skipLabel,
  }) => InitializationSettings(
    android: const AndroidInitializationSettings('@drawable/ic_stat_usra'),
    iOS: DarwinInitializationSettings(
      // Asked from the Medicines tab, when reminders are first needed.
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      notificationCategories: [
        DarwinNotificationCategory(
          namedCategory,
          actions: [
            DarwinNotificationAction.plain(takenActionId, takenLabel),
            DarwinNotificationAction.plain(snoozeActionId, snoozeLabel),
            DarwinNotificationAction.plain(skipActionId, skipLabel),
          ],
        ),
        // From the lock screen, a button with no name near it could be
        // pressed by anyone: iOS asks to unlock the phone first, then runs
        // it without opening the app. Snooze records nothing about the dose.
        DarwinNotificationCategory(
          discreetLoneCategory,
          actions: [
            DarwinNotificationAction.plain(
              takenActionId,
              takenLabel,
              options: {DarwinNotificationActionOption.authenticationRequired},
            ),
            DarwinNotificationAction.plain(snoozeActionId, snoozeLabel),
            DarwinNotificationAction.plain(
              skipActionId,
              skipLabel,
              options: {DarwinNotificationActionOption.authenticationRequired},
            ),
          ],
        ),
        DarwinNotificationCategory(
          discreetCategory,
          actions: [
            DarwinNotificationAction.plain(snoozeActionId, snoozeLabel),
          ],
        ),
      ],
    ),
  );

  static DoseResponse? _read(NotificationResponse r) {
    final dose = ReminderRef.fromPayload(r.payload);
    if (dose == null) return null;
    return (dose: dose, status: _statusOf(r.actionId));
  }

  static String? _statusOf(String? actionId) => switch (actionId) {
    takenActionId => DoseOutcome.taken,
    snoozeActionId => DoseOutcome.snoozed,
    skipActionId => DoseOutcome.skipped,
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
      await whileInOtherApp(() => _battery.invokeMethod<void>('openSettings'));
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
    ReminderRebuild? rebuild,
  }) async {
    final pending = await _plugin.pendingNotificationRequests();
    final snoozes = pending.where((p) => p.id >= snoozeIdBase).length;
    // iOS keeps only 64 pending notifications, snoozes included.
    final room = Platform.isIOS ? max(0, _iosLimit - snoozes) : _androidLimit;
    final changes = diffReminders(
      pending: [
        for (final p in pending)
          (id: p.id, title: p.title, body: p.body, payload: p.payload),
      ],
      shown: rebuild == null ? const [] : await _shown(),
      wanted: reminders.take(room).toList(),
      doneSnoozes: doneSnoozes,
      rebuild: rebuild,
      now: DateTime.now(),
    );
    for (final id in changes.cancel) {
      await _plugin.cancel(id: id);
    }
    final mode = await _mode();
    for (final r in changes.schedule) {
      await _schedule(_plugin, r, mode);
    }
    for (final r in changes.repost) {
      await _plugin.show(
        id: r.id,
        title: r.title,
        body: r.body,
        payload: r.toPayload(),
        notificationDetails: _details(r, silent: true),
      );
    }
  }

  /// Dose notifications on screen now.
  Future<List<PhoneReminder>> _shown() async {
    try {
      return [
        for (final n in await _plugin.getActiveNotifications())
          if (n.id != null &&
              (n.channelId == null ||
                  n.channelId == _channelId ||
                  n.channelId == _vaccineChannelId))
            (id: n.id!, title: n.title, body: n.body, payload: n.payload),
      ];
    } on Object {
      // Older Android, or not allowed: they stay as they are.
      return const [];
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
    notificationDetails: _details(r),
  );
}

NotificationDetails _details(PlannedReminder r, {bool silent = false}) =>
    NotificationDetails(
      android: AndroidNotificationDetails(
        r.isVaccine ? _vaccineChannelId : _channelId,
        // Only used if the channel was never created; init creates it.
        r.isVaccine ? _vaccineChannelId : _channelId,
        importance: r.isVaccine ? Importance.high : Importance.max,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
        // Hidden on a secure lock screen when the phone hides sensitive
        // content; discreet text says nothing either way.
        visibility: NotificationVisibility.private,
        silent: silent,
        actions: [
          if (r.takenLabel case final taken?)
            AndroidNotificationAction(takenActionId, taken),
          if (r.snoozeLabel case final snooze?)
            AndroidNotificationAction(snoozeActionId, snooze),
          if (r.skipLabel case final skip?)
            AndroidNotificationAction(skipActionId, skip),
        ],
      ),
      iOS: DarwinNotificationDetails(
        // Vaccine visits and next-dose reminders have no buttons: no
        // category.
        categoryIdentifier: r.iosCategory,
        presentSound: silent ? false : null,
        presentBanner: silent ? false : null,
      ),
    );

/// Taken / Snooze / Skip pressed while the app wasn't running, in a background
/// isolate that can't open the encrypted database: the action is left in
/// the inbox for the app, and a snooze is scheduled right here.
@pragma('vm:entry-point')
Future<void> onBackgroundDoseResponse(NotificationResponse response) async {
  useArabicIndicNumbers();
  final dose = ReminderRef.fromPayload(response.payload);
  final status = LocalNotificationScheduler._statusOf(response.actionId);
  if (dose == null || status == null) return;
  DartPluginRegistrant.ensureInitialized();
  final now = DateTime.now();
  (await DoseActionInbox.open()).add(
    DoseAction(
      medicineId: dose.medicineId,
      scheduledAt: dose.scheduledAt,
      status: status,
      at: now,
    ),
  );
  if (status != DoseOutcome.snoozed) return;
  // The database (and so the names) can't be read here: the snooze is
  // discreet, and gets its full text when the app next runs.
  final snooze = ReminderTexts.generic(dose, at: now.add(snoozeDuration));
  final l = lookupAppLocalizations(Locale(snooze.locale));
  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(
    settings: LocalNotificationScheduler._settings(
      takenLabel: l.doseTaken,
      snoozeLabel: l.doseSnooze,
      skipLabel: l.doseSkip,
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
    snooze,
    exact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle,
  );
}
