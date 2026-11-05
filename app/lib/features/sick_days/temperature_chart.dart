import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../core/database/app_database.dart';
import '../../core/design/tokens.dart';
import '../../l10n/app_localizations.dart';
import 'fever.dart';

/// A sick day's temperatures over time, in the unit of the latest reading,
/// with a dashed line where a fever starts.
class TemperatureChart extends StatelessWidget {
  const TemperatureChart({super.key, required this.readings});

  /// Oldest first.
  final List<TemperatureReading> readings;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final unit = readings.last.unit;
    return Card(
      key: const ValueKey('sick-day-chart'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.sickDayChartTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            // Time runs left to right in both languages, like printed charts.
            Directionality(
              textDirection: TextDirection.ltr,
              child: AspectRatio(
                aspectRatio: 1.6,
                child: CustomPaint(
                  painter: TemperatureChartPainter(
                    readings: readings,
                    unit: unit,
                    unitLabel: unit == TemperatureUnit.fahrenheit
                        ? l.readingFahrenheit
                        : l.readingCelsius,
                    timeLabel: (t) =>
                        DateFormat('E HH:mm', locale).format(t.toLocal()),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l.sickDayChartNote,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: UsraColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class TemperatureChartPainter extends CustomPainter {
  TemperatureChartPainter({
    required this.readings,
    required this.unit,
    required this.unitLabel,
    required this.timeLabel,
  });

  final List<TemperatureReading> readings;
  final String unit;
  final String unitLabel;
  final String Function(DateTime) timeLabel;

  static const _left = 36.0;
  static const _bottom = 20.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (readings.isEmpty) return;
    final values = [for (final r in readings) fromCelsius(readingC(r), unit)];
    final fever = fromCelsius(feverC, unit);
    var low = math.min(values.reduce(math.min), fromCelsius(36, unit));
    var high = math.max(values.reduce(math.max), fromCelsius(40, unit));
    low = low.floorToDouble();
    high = high.ceilToDouble();

    final start = readings.first.takenAt;
    var span = readings.last.takenAt.difference(start).inMinutes.toDouble();
    if (span < 60) span = 60;

    final chart = Rect.fromLTRB(
      _left,
      8,
      size.width - 8,
      size.height - _bottom,
    );
    Offset at(DateTime t, double v) => Offset(
      chart.left + chart.width * t.difference(start).inMinutes / span,
      chart.bottom - chart.height * (v - low) / (high - low),
    );

    final grid = Paint()
      ..color = UsraColors.line
      ..strokeWidth = 1;
    final step = (high - low) > 8 ? 2 : 1;
    for (var v = low; v <= high + 1e-9; v += step) {
      final y = at(start, v).dy;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), grid);
      _label(canvas, v.toStringAsFixed(0), Offset(2, y - 7));
    }
    _label(canvas, unitLabel, const Offset(2, -4));

    // Where a fever starts, dashed.
    final fy = at(start, fever).dy;
    final dash = Paint()
      ..color = Severity.urgent.foreground
      ..strokeWidth = 1.5;
    for (var x = chart.left; x < chart.right; x += 8) {
      canvas.drawLine(
        Offset(x, fy),
        Offset(math.min(x + 4, chart.right), fy),
        dash,
      );
    }

    _label(canvas, timeLabel(start), Offset(chart.left, chart.bottom + 3));
    if (readings.length > 1) {
      final end = timeLabel(readings.last.takenAt);
      _label(canvas, end, Offset(chart.right - _width(end), chart.bottom + 3));
    }

    final line = Path();
    for (final (i, r) in readings.indexed) {
      final o = at(r.takenAt, values[i]);
      i == 0 ? line.moveTo(o.dx, o.dy) : line.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = UsraColors.primary,
    );
    for (final (i, r) in readings.indexed) {
      canvas.drawCircle(
        at(r.takenAt, values[i]),
        4,
        Paint()
          ..color = isFever(r)
              ? Severity.urgent.foreground
              : UsraColors.primary,
      );
    }
  }

  TextPainter _text(String s) => TextPainter(
    text: TextSpan(
      text: s,
      style: const TextStyle(fontSize: 10, color: UsraColors.textMuted),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  double _width(String s) => _text(s).width;

  void _label(Canvas canvas, String s, Offset at) => _text(s).paint(canvas, at);

  @override
  bool shouldRepaint(TemperatureChartPainter old) =>
      old.readings != readings || old.unit != unit;
}
