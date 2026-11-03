import '../../core/database/app_database.dart';

/// A time of day a dose is due, in the phone's local time.
class DoseTime implements Comparable<DoseTime> {
  const DoseTime(this.hour, this.minute)
    : assert(hour >= 0 && hour < 24),
      assert(minute >= 0 && minute < 60);

  final int hour;
  final int minute;

  /// Reads "HH:mm"; null if it isn't a valid time.
  static DoseTime? tryParse(String text) {
    final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(text.trim());
    if (m == null) return null;
    final h = int.parse(m[1]!);
    final min = int.parse(m[2]!);
    if (h > 23 || min > 59) return null;
    return DoseTime(h, min);
  }

  /// Valid times in a comma-separated list, sorted, without repeats.
  static List<DoseTime> parseList(String text) =>
      {for (final part in text.split(',')) ?DoseTime.tryParse(part)}.toList()
        ..sort();

  int get minutesOfDay => hour * 60 + minute;

  /// "08:05", the way times are stored.
  String get key =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  /// This time on [day]'s local calendar date.
  DateTime on(DateTime day) =>
      DateTime(day.year, day.month, day.day, hour, minute);

  @override
  int compareTo(DoseTime other) => minutesOfDay - other.minutesOfDay;

  @override
  bool operator ==(Object other) =>
      other is DoseTime && other.minutesOfDay == minutesOfDay;

  @override
  int get hashCode => minutesOfDay;

  @override
  String toString() => key;
}

/// When a medicine's doses are due: its times, on which days, from its
/// first day to its last.
///
/// Days are local calendar days, so a dose at 08:00 stays at 08:00 across
/// daylight saving changes.
class DoseRule {
  DoseRule({
    required List<DoseTime> times,
    required DateTime startOn,
    this.endOn,
    this.weekdays,
    this.everyNDays,
  }) : times = List.unmodifiable([...times]..sort()),
       startOn = _date(startOn);

  factory DoseRule.of(Medicine medicine, DoseSchedule schedule) => DoseRule(
    times: DoseTime.parseList(schedule.times),
    startOn: medicine.startOn,
    endOn: medicine.endOn,
    weekdays: schedule.weekdays,
    everyNDays: schedule.everyNDays,
  );

  final List<DoseTime> times;

  /// First day, as a calendar date (UTC midnight).
  final DateTime startOn;

  /// Last day (inclusive); null when it goes on.
  final DateTime? endOn;

  /// Bit mask, bit 0 = Monday; null for every day of the week.
  final int? weekdays;

  /// Every N days counted from [startOn]; null or 1 for daily.
  final int? everyNDays;

  /// The calendar date of [d] as UTC midnight, for day arithmetic that
  /// daylight saving can't shift.
  static DateTime _date(DateTime d) => DateTime.utc(d.year, d.month, d.day);

  /// Whether doses are due on [day]'s local calendar date.
  bool isDueOn(DateTime day) {
    final date = _date(day);
    if (date.isBefore(startOn)) return false;
    final end = endOn;
    if (end != null && date.isAfter(_date(end))) return false;
    final mask = weekdays;
    if (mask != null && mask & (1 << (date.weekday - 1)) == 0) return false;
    final n = everyNDays;
    if (n != null && n > 1 && date.difference(startOn).inDays % n != 0) {
      return false;
    }
    return true;
  }

  /// Every dose due from [from] (inclusive) to [to] (exclusive), in order,
  /// as local times.
  List<DateTime> occurrencesBetween(DateTime from, DateTime to) {
    final out = <DateTime>[];
    if (times.isEmpty || !from.isBefore(to)) return out;
    final fromLocal = from.toLocal();
    final toLocal = to.toLocal();
    for (
      var day = DateTime(fromLocal.year, fromLocal.month, fromLocal.day);
      day.isBefore(toLocal);
      day = DateTime(day.year, day.month, day.day + 1)
    ) {
      if (!isDueOn(day)) continue;
      for (final t in times) {
        final at = t.on(day);
        if (!at.isBefore(fromLocal) && at.isBefore(toLocal)) out.add(at);
      }
    }
    return out;
  }

  /// The first dose due strictly after [after], or null if there is none
  /// left (the medicine has ended, or no day within a year matches).
  DateTime? nextAfter(DateTime after) {
    if (times.isEmpty) return null;
    final local = after.toLocal();
    var day = DateTime(local.year, local.month, local.day);
    // Every-N-days and weekday rules repeat within a year.
    for (var i = 0; i <= 366; i++) {
      final end = endOn;
      if (end != null && _date(day).isAfter(_date(end))) return null;
      if (isDueOn(day)) {
        for (final t in times) {
          final at = t.on(day);
          if (at.isAfter(local)) return at;
        }
      }
      day = DateTime(day.year, day.month, day.day + 1);
    }
    return null;
  }
}

/// One dose due at a planned time, with what happened to it (if anything).
class PlannedDose {
  const PlannedDose({required this.regimen, required this.at, this.log});

  final Regimen regimen;

  /// Local planned time.
  final DateTime at;
  final DoseLog? log;

  /// The key dose logs are saved under.
  DateTime get scheduledAt => at.toUtc();

  /// Marked taken or skipped; a snoozed dose is still due.
  bool get isDone =>
      log != null &&
      (log!.status == DoseOutcome.taken || log!.status == DoseOutcome.skipped);
}

/// Every dose due for the family from [from] to [to], in time order, each
/// with its log entry from [logs].
List<PlannedDose> plannedDoses(
  List<Regimen> regimens,
  List<DoseLog> logs, {
  required DateTime from,
  required DateTime to,
}) {
  final byKey = {for (final l in logs) _key(l.medicineId, l.scheduledAt): l};
  final doses = [
    for (final r in regimens)
      for (final at in DoseRule.of(
        r.medicine,
        r.schedule,
      ).occurrencesBetween(from, to))
        PlannedDose(regimen: r, at: at, log: byKey[_key(r.medicine.id, at)]),
  ];
  // Stable: same-time doses keep the person/medicine order.
  _stableSort(doses, (a, b) => a.at.compareTo(b.at));
  return doses;
}

String _key(String medicineId, DateTime at) =>
    '$medicineId@${at.millisecondsSinceEpoch}';

/// A stable insertion sort; lists here are a day or a week of doses.
void _stableSort<T>(List<T> list, int Function(T, T) compare) {
  for (var i = 1; i < list.length; i++) {
    final item = list[i];
    var j = i - 1;
    while (j >= 0 && compare(list[j], item) > 0) {
      list[j + 1] = list[j];
      j--;
    }
    list[j + 1] = item;
  }
}
