import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../core/database/app_database.dart';
import '../../core/design/tokens.dart';
import '../../core/design/type.dart';
import '../../core/util/localized_digits.dart';
import '../../l10n/app_localizations.dart';
import 'fever.dart';

/// A sick day's temperatures over time, in the unit of the latest reading,
/// with a labelled dashed line where a fever starts. Time runs one way, the
/// way the language reads: right to left in Arabic, left to right in English.
class TemperatureChart extends StatelessWidget {
  const TemperatureChart({super.key, required this.readings});

  /// Oldest first.
  final List<TemperatureReading> readings;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final unit = readings.last.unit;
    final scaler = MediaQuery.textScalerOf(context);
    final feverLabel = feverLineLabel(context, unit);
    // Over most of a day an hour alone could be either day, so the day shows.
    final hasLongSpan =
        readings.last.takenAt.difference(readings.first.takenAt) >
        const Duration(hours: 20);
    String axisLabel(DateTime at) {
      final t = at.toLocal();
      // "٩ م", or "٨:٥٥ ص": a label never rounds a reading's time.
      final time = t.minute == 0 ? DateFormat.j(locale) : DateFormat.jm(locale);
      return hasLongSpan
          ? '${DateFormat.E(locale).format(t)} ${time.format(t)}'
          : time.format(t);
    }

    final spoken = DateFormat.MMMd(locale).add_jm();
    return Semantics(
      image: true,
      label: l.sickDayChartSemantics(
        spoken.format(readings.first.takenAt.toLocal()),
        spoken.format(readings.last.takenAt.toLocal()),
        [
          for (final r in readings)
            localizedReading(context, fromCelsius(readingC(r), unit)),
        ].join(l.sickDayChartThen),
        feverLabel,
      ),
      excludeSemantics: true,
      child: SizedBox(
        key: const ValueKey('sick-day-chart'),
        // Taller with bigger text, so the time labels never squeeze the line.
        height: 96 + scaler.scale(TemperatureChartPainter.labelSize) * 1.6,
        width: double.infinity,
        child: CustomPaint(
          painter: TemperatureChartPainter(
            colors: context.usra,
            readings: readings,
            unit: unit,
            feverLabel: feverLabel,
            direction: Directionality.of(context),
            textScaler: scaler,
            timeLabel: axisLabel,
          ),
        ),
      ),
    );
  }
}

/// Where a fever starts, in [unit]: ٣٨° or ١٠٠٫٤°.
String feverLineLabel(BuildContext context, String unit) {
  final value = fromCelsius(feverC, unit);
  final text = value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
  return '${localizedDigitsIn(context, text)}°';
}

class TemperatureChartPainter extends CustomPainter {
  TemperatureChartPainter({
    required this.colors,
    required this.readings,
    required this.unit,
    required this.feverLabel,
    required this.direction,
    required this.textScaler,
    required this.timeLabel,
  });

  final UsraColors colors;
  final List<TemperatureReading> readings;
  final String unit;
  final String feverLabel;
  final TextDirection direction;
  final TextScaler textScaler;
  final String Function(DateTime) timeLabel;

  static const labelSize = 14.0;
  static const _dot = 5.0;

  /// Room for the half of a dot that sticks out, and the line's own label
  /// past the newest reading.
  late final double _trailing = _measure(feverLabel) + 12;

  late final double _span = () {
    final start = readings.first.takenAt;
    final span = readings.last.takenAt.difference(start).inMinutes.toDouble();
    return span < 60 ? 60.0 : span;
  }();

  /// How far across [t] is, measured from the side time starts on.
  double _along(DateTime t, double width) {
    final used = width - _dot * 2 - _trailing;
    return _dot + used * t.difference(readings.first.takenAt).inMinutes / _span;
  }

  /// Where [t] falls: oldest on the side the language starts reading from.
  double xOf(DateTime t, double width) => direction == TextDirection.rtl
      ? width - _along(t, width)
      : _along(t, width);

  @override
  void paint(Canvas canvas, Size size) {
    if (readings.isEmpty) return;
    final values = [for (final r in readings) fromCelsius(readingC(r), unit)];
    final fever = fromCelsius(feverC, unit);
    // The line stays put as readings come in, whatever they are.
    final low = math.min(values.reduce(math.min), fromCelsius(36.5, unit));
    final high = math.max(values.reduce(math.max), fromCelsius(39.5, unit));
    final sample = _text('0');
    final bottom = size.height - sample.height - 8;
    sample.dispose();
    const top = _dot + 2;
    double yOf(double v) =>
        bottom - _dot - (bottom - _dot - top) * (v - low) / (high - low);

    _paintFeverLine(canvas, size, yOf(fever));
    _paintTimes(canvas, size, bottom + 6);

    final line = Path();
    for (final (i, r) in readings.indexed) {
      final x = xOf(r.takenAt, size.width);
      final y = yOf(values[i]);
      i == 0 ? line.moveTo(x, y) : line.lineTo(x, y);
    }
    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = colors.primary,
    );
    for (final (i, r) in readings.indexed) {
      canvas.drawCircle(
        Offset(xOf(r.takenAt, size.width), yOf(values[i])),
        i == readings.length - 1 ? _dot + 1 : _dot,
        Paint()..color = isFever(r) ? colors.actSoon : colors.primary,
      );
    }
  }

  void _paintFeverLine(Canvas canvas, Size size, double y) {
    final dash = Paint()
      ..color = colors.lineStrong
      ..strokeWidth = 1.5;
    for (var x = 0.0; x < size.width; x += 10) {
      canvas.drawLine(
        Offset(x, y),
        Offset(math.min(x + 5, size.width), y),
        dash,
      );
    }
    // The degree sign stays on the number's right in Arabic too.
    final label = _text(
      feverLabel,
      weight: FontWeight.w600,
      textDirection: TextDirection.ltr,
    );
    // Past the newest reading, so a dot can't land on it.
    label.paint(
      canvas,
      Offset(
        direction == TextDirection.rtl ? 0 : size.width - label.width,
        y - label.height - 1,
      ),
    );
    label.dispose();
  }

  /// The newest and oldest times always; others only where they fit.
  void _paintTimes(Canvas canvas, Size size, double y) {
    final order = [
      readings.length - 1,
      if (readings.length > 1) 0,
      for (var i = 1; i < readings.length - 1; i++) i,
    ];
    final used = <Rect>[];
    for (final i in order) {
      final label = _text(timeLabel(readings[i].takenAt));
      final half = label.width / 2;
      final x = xOf(
        readings[i].takenAt,
        size.width,
      ).clamp(half, math.max(size.width - half, half)).toDouble();
      final box = Rect.fromCenter(
        center: Offset(x, y + label.height / 2),
        width: label.width + 12,
        height: label.height,
      );
      if (!used.any(box.overlaps)) {
        used.add(box);
        label.paint(canvas, Offset(x - half, y));
      }
      label.dispose();
    }
  }

  double _measure(String s) {
    final painter = _text(s);
    final width = painter.width;
    painter.dispose();
    return width;
  }

  TextPainter _text(
    String s, {
    FontWeight weight = FontWeight.w400,
    TextDirection? textDirection,
  }) => TextPainter(
    text: TextSpan(
      text: s,
      style: TextStyle(
        fontFamily: UsraFonts.body,
        fontSize: labelSize,
        fontWeight: weight,
        color: colors.inkMuted,
      ),
    ),
    textDirection: textDirection ?? direction,
    textScaler: textScaler,
  )..layout();

  @override
  bool shouldRepaint(TemperatureChartPainter old) =>
      old.colors != colors ||
      old.readings != readings ||
      old.unit != unit ||
      old.direction != direction ||
      old.textScaler != textScaler;
}
