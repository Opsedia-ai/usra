import '../../core/database/app_database.dart';
import '../../l10n/app_localizations.dart';
import 'fever.dart';

/// The highest reading of a sick day, or null without readings. Readings in
/// different units are compared in °C; the first of equal ones wins.
TemperatureReading? highestReading(List<TemperatureReading> readings) {
  TemperatureReading? top;
  for (final r in readings) {
    if (top == null || readingC(r) > readingC(top) + 1e-9) top = r;
  }
  return top;
}

/// The first and last readings at or above [feverC], in time order, or null
/// without one. Only what was recorded: not how long the fever lasted.
({TemperatureReading first, TemperatureReading last})? feverReadingSpan(
  List<TemperatureReading> readings,
) {
  final fevers = readings.where(isFever).toList()
    ..sort((a, b) => a.takenAt.compareTo(b.takenAt));
  if (fevers.isEmpty) return null;
  return (first: fevers.first, last: fevers.last);
}

/// The lines under the sick day's chart, as the family reads them:
///
/// - "أعلى قراءة: ٣٩٫١° · ١٢:٠٠ م", when there's more than one reading (with
///   one, it's the latest reading shown above);
/// - "سخونية متسجلة من ٨:٠٠ ص لـ ١٢:٠٠ م", the first and last fever readings,
///   or "سخونية متسجلة: ٨:٠٠ ص" for one.
///
/// [reading] and [time] format a reading and a time the way the card does.
/// Null when there's nothing to say.
String? feverSummary(
  AppLocalizations l,
  List<TemperatureReading> readings, {
  required String Function(TemperatureReading) reading,
  required String Function(DateTime) time,
}) {
  final top = readings.length > 1 ? highestReading(readings) : null;
  final span = feverReadingSpan(readings);
  final lines = [
    if (top != null) l.sickDayHighestReading(reading(top), time(top.takenAt)),
    if (span != null)
      identical(span.first, span.last)
          ? l.sickDayFeverOnce(time(span.first.takenAt))
          : l.sickDayFeverSpan(
              time(span.first.takenAt),
              time(span.last.takenAt),
            ),
  ];
  return lines.isEmpty ? null : lines.join('\n');
}
