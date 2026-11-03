import '../../core/database/app_database.dart';
import '../../core/records/record_type.dart' show decodeRecordData;
import 'growth.dart';

/// The infant log's record types and data keys.
abstract final class InfantLog {
  static const feed = 'feed';
  static const sleep = 'sleep';
  static const diaper = 'diaper';
  static const types = {feed, sleep, diaper};

  /// feed: breast, bottle or solids; diaper: wet, dirty or both.
  static const kind = 'kind';
  static const amountMl = 'amountMl';
  static const minutes = 'minutes';

  static const feedKinds = ['breast', 'bottle', 'solids'];
  static const diaperKinds = ['wet', 'dirty', 'both'];
}

/// Whether someone born on [birthDate] is under one on [now].
bool isUnderOne(DateTime? birthDate, DateTime now) =>
    birthDate != null &&
    !birthDate.isAfter(now) &&
    now.isBefore(addMonths(birthDate, 12));

/// One day of the infant log, added up.
class DaySummary {
  int breast = 0;
  int bottle = 0;
  int solids = 0;
  int bottleMl = 0;
  int sleepMinutes = 0;
  int wet = 0;
  int dirty = 0;

  int get feeds => breast + bottle + solids;
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// The log entries of [day] (local time), newest first as [events] are.
List<MedicalEvent> entriesOn(List<MedicalEvent> events, DateTime day) => [
  for (final e in events)
    if (InfantLog.types.contains(e.type) &&
        _sameDay(e.occurredAt.toLocal(), day))
      e,
];

/// Adds up [day]'s feeds, sleep and diapers. A "both" diaper counts as wet
/// and dirty.
DaySummary summarizeDay(List<MedicalEvent> events, DateTime day) {
  final sum = DaySummary();
  int whole(Object? v) => v is num && v > 0 ? v.round() : 0;
  for (final e in entriesOn(events, day)) {
    final data = decodeRecordData(e.dataJson);
    switch ((e.type, data[InfantLog.kind])) {
      case (InfantLog.feed, 'breast'):
        sum.breast++;
      case (InfantLog.feed, 'bottle'):
        sum.bottle++;
        sum.bottleMl += whole(data[InfantLog.amountMl]);
      case (InfantLog.feed, _):
        sum.solids++;
      case (InfantLog.sleep, _):
        sum.sleepMinutes += whole(data[InfantLog.minutes]);
      case (InfantLog.diaper, 'wet'):
        sum.wet++;
      case (InfantLog.diaper, 'dirty'):
        sum.dirty++;
      case (InfantLog.diaper, _):
        sum.wet++;
        sum.dirty++;
    }
  }
  return sum;
}
