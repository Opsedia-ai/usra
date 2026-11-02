/// A span of time spending is added up over.
enum SpendingPeriod { week, month, year }

extension SpendingPeriodMath on SpendingPeriod {
  /// Local midnight at the start of the period holding [day]. Weeks start on
  /// Saturday, as they do in Egypt.
  DateTime startOf(DateTime day) => switch (this) {
    // Saturday is 6 in Dart, so this is the number of days since Saturday.
    SpendingPeriod.week => DateTime(
      day.year,
      day.month,
      day.day - (day.weekday + 1) % 7,
    ),
    SpendingPeriod.month => DateTime(day.year, day.month),
    SpendingPeriod.year => DateTime(day.year),
  };

  /// The start of the period [count] periods after the one starting at
  /// [start] (before it when negative). Built from calendar fields, not
  /// durations, so daylight-saving changes never shift a boundary.
  DateTime shift(DateTime start, int count) => switch (this) {
    SpendingPeriod.week => DateTime(
      start.year,
      start.month,
      start.day + 7 * count,
    ),
    SpendingPeriod.month => DateTime(start.year, start.month + count),
    SpendingPeriod.year => DateTime(start.year + count),
  };

  /// Boundaries of the [count] periods ending with the one starting at
  /// [start], oldest first: `count + 1` dates, the last one exclusive.
  List<DateTime> boundsEndingAt(DateTime start, int count) => [
    for (var i = count - 1; i >= -1; i--) shift(start, -i),
  ];
}
