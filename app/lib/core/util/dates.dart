/// A date saved as UTC midnight (birthdays, expiry and medicine days), as
/// that calendar day. Drift reads it back in local time, which west of UTC
/// is the evening before.
DateTime storedDay(DateTime stored) {
  final d = stored.toUtc();
  return DateTime(d.year, d.month, d.day);
}
