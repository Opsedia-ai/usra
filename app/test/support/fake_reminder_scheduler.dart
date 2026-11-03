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

  @override
  Future<void> replaceAll(List<PlannedReminder> reminders) async =>
      planned = List.of(reminders);

  @override
  Future<void> add(PlannedReminder reminder) async => snoozes.add(reminder);
}
