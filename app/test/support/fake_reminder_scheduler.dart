import 'package:usra/features/medicines/reminders.dart';

/// Remembers what would be scheduled on the phone.
class FakeReminderScheduler implements ReminderScheduler {
  FakeReminderScheduler({
    this.granted = const ReminderAccess(notifications: true),
  });

  ReminderAccess granted;
  ReminderAccess? afterRequest;
  var requests = 0;
  bool? lastRequestedExactAlarms;
  var batterySettingsOpened = 0;

  /// Planned reminders, as last replaced.
  List<PlannedReminder> planned = const [];
  final snoozes = <PlannedReminder>[];

  @override
  Future<ReminderAccess> access() async => granted;

  @override
  Future<ReminderAccess> requestAccess({bool exactAlarms = true}) async {
    requests++;
    lastRequestedExactAlarms = exactAlarms;
    granted = afterRequest ?? granted;
    return granted;
  }

  @override
  Future<void> openBatterySettings() async => batterySettingsOpened++;

  /// Snoozes cancelled at the last replace.
  Set<int> doneSnoozes = const {};

  /// How snoozes and notifications on screen were to be rewritten.
  ReminderRebuild? rebuild;

  @override
  Future<void> replaceAll(
    List<PlannedReminder> reminders, {
    Set<int> doneSnoozes = const {},
    ReminderRebuild? rebuild,
  }) async {
    planned = List.of(reminders);
    this.doneSnoozes = doneSnoozes;
    this.rebuild = rebuild;
  }

  @override
  Future<void> add(PlannedReminder reminder) async => snoozes.add(reminder);
}
