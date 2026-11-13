import '../../core/preferences.dart';
import 'reminders.dart';

/// Asking for notifications, and what to do after a "no".
///
/// The phone shows its prompt once: iOS never again, Android not after the
/// second "no". After the first answer the cards open the app's page in the
/// phone's Settings instead, and say so: one rule for both, and Android's page
/// there turns notifications on with one switch.

/// Shows the phone's prompt and remembers it was shown.
Future<ReminderAccess> requestReminderAccess(
  ReminderScheduler scheduler,
  KeyValueStore prefs, {
  bool exactAlarms = true,
}) async {
  final access = await scheduler.requestAccess(exactAlarms: exactAlarms);
  await prefs.setBool(PrefKeys.notificationsAsked, true);
  return access;
}

/// Notifications are off and the phone won't ask again: only its Settings
/// can turn them back on.
bool notificationsBlocked(ReminderAccess access, KeyValueStore prefs) =>
    !access.notifications &&
    (prefs.getBool(PrefKeys.notificationsAsked) ?? false);

/// What a card's "Allow" does: the prompt the first time, the phone's
/// Settings once the prompt has been answered "no".
Future<void> allowReminders(
  ReminderScheduler scheduler,
  KeyValueStore prefs, {
  bool exactAlarms = true,
}) async {
  if (notificationsBlocked(await scheduler.access(), prefs)) {
    await scheduler.openNotificationSettings();
    return;
  }
  await requestReminderAccess(scheduler, prefs, exactAlarms: exactAlarms);
}
