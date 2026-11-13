import 'package:flutter_test/flutter_test.dart';
import 'package:usra/core/database/app_database.dart';
import 'package:usra/features/sick_days/fever_summary.dart';
import 'package:usra/l10n/app_localizations_ar.dart';
import 'package:usra/l10n/app_localizations_en.dart';

TemperatureReading reading(int hour, double value, {String unit = 'c'}) =>
    TemperatureReading(
      id: 'r$hour',
      episodeId: 'e',
      takenAt: DateTime(2026, 11, 12, hour),
      value: value,
      unit: unit,
      updatedAt: DateTime(2026, 11, 12, hour),
    );

void main() {
  String fmt(TemperatureReading r) => '${r.value}${r.unit}';
  String time(DateTime at) => '${at.hour}:00';

  test('the highest reading compares across units', () {
    final readings = [reading(8, 38.5), reading(12, 102.6, unit: 'f')];
    // 102.6 °F is 39.2 °C.
    expect(highestReading(readings)!.value, 102.6);
    expect(highestReading([]), isNull);
  });

  test('the two-year-old report: 38.5 at 08:00, 39.1 at 12:00, 37.8 at '
      '18:00', () {
    final readings = [reading(8, 38.5), reading(12, 39.1), reading(18, 37.8)];
    expect(
      feverSummary(AppLocalizationsAr(), readings, reading: fmt, time: time),
      'أعلى قراءة: 39.1c – 12:00\nسخونية متسجلة من 8:00 لـ 12:00',
    );
    expect(
      feverSummary(AppLocalizationsEn(), readings, reading: fmt, time: time),
      'Highest reading: 39.1c – 12:00\nFever readings from 8:00 to 12:00',
    );
  });

  test('one fever reading gives its time, not a span', () {
    final readings = [reading(8, 37.2), reading(12, 38.4)];
    expect(
      feverSummary(AppLocalizationsAr(), readings, reading: fmt, time: time),
      'أعلى قراءة: 38.4c – 12:00\nسخونية متسجلة: 12:00',
    );
  });

  test('a single reading is already the latest: no highest line', () {
    expect(
      feverSummary(
        AppLocalizationsAr(),
        [reading(8, 38.4)],
        reading: fmt,
        time: time,
      ),
      'سخونية متسجلة: 8:00',
    );
    expect(
      feverSummary(
        AppLocalizationsAr(),
        [reading(8, 37.0)],
        reading: fmt,
        time: time,
      ),
      isNull,
    );
  });

  test('no fever: only the highest line', () {
    final readings = [reading(8, 37.0), reading(12, 37.5)];
    expect(
      feverSummary(AppLocalizationsAr(), readings, reading: fmt, time: time),
      'أعلى قراءة: 37.5c – 12:00',
    );
  });
}
