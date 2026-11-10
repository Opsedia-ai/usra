import 'dart:math' as math;

import 'ocr_service.dart';

/// A row of the page put back together: its text, cells two spaces apart,
/// and whether its cells sat loosely (more than half a line's height apart
/// up and down, once the tilt is undone), which can mean cells from two
/// rows were joined.
class OcrRow {
  const OcrRow(this.text, {this.loose = false, this.confidence});

  final String text;
  final bool loose;

  /// The least sure of its lines, when the recogniser says how sure it
  /// was (see [OcrLine.confidence]); null otherwise.
  final double? confidence;
}

/// The page's lines grouped into rows, top to bottom, each read left to
/// right with cells separated by two spaces.
List<OcrRow> ocrRows(OcrResult ocr) {
  final lines = [
    for (final l in ocr.lines)
      if (l.text.trim().isNotEmpty) l,
  ];
  if (lines.isEmpty) return const [];
  final slope = ocrPageSlope(lines);
  // Text height: the median line, so one tall (tilted, long) box doesn't
  // set the tolerance.
  final heights = [for (final l in lines) _textHeight(l, slope)]..sort();
  final height = math.max(1.0, heights[heights.length ~/ 2]);
  // Undo the tilt: where each line would sit on a level page.
  double level(OcrLine l) => l.box.center.dy - slope * l.box.center.dx;
  final sorted = [...lines]..sort((a, b) => level(a).compareTo(level(b)));

  final rows = <List<OcrLine>>[];
  final centres = <double>[];
  for (final line in sorted) {
    final y = level(line);
    if (rows.isNotEmpty && (y - centres.last).abs() <= height * 0.5) {
      rows.last.add(line);
      final n = rows.last.length;
      centres.last += (y - centres.last) / n;
    } else {
      rows.add([line]);
      centres.add(y);
    }
  }
  return [
    for (final row in rows)
      OcrRow(
        (row..sort((a, b) => a.box.left.compareTo(b.box.left)))
            .map((l) => l.text.trim())
            .join('  '),
        loose:
            row.length > 1 &&
            row.map(level).reduce(math.max) - row.map(level).reduce(math.min) >
                height * 0.5,
        confidence: [for (final l in row) ?l.confidence]
            .fold<double?>(null, (a, c) => a == null ? c : math.min(a, c)),
      ),
  ];
}

/// A line's text height on a level page: its box minus what the tilt
/// added (a box around a turned line is taller than the text).
double _textHeight(OcrLine l, double slope) =>
    math.max(1.0, l.box.height - slope.abs() * l.box.width);

/// The page's tilt as dy/dx: from the recogniser's line angles when it
/// gives them, else the tilt that best lines up cells in different
/// columns (tried in small steps up to about 12 degrees either way).
double ocrPageSlope(List<OcrLine> lines) {
  final angles = <double>[for (final l in lines) ?l.angle]..sort();
  if (angles.length >= 3) {
    return math.tan(angles[angles.length ~/ 2] * math.pi / 180);
  }
  if (lines.length < 4) return 0;
  final heights = [for (final l in lines) l.box.height]..sort();
  final h = math.max(1.0, heights[heights.length ~/ 2]);
  var best = 0.0;
  var bestScore = -1;
  for (var step = 0; step <= 2 * 44; step++) {
    // 0, then +-0.005, +-0.01 ... so ties keep the smaller tilt.
    final k = (step + 1) ~/ 2;
    final slope = (step.isOdd ? 1 : -1) * k * 0.005;
    final tolerance = 0.25 * math.max(1.0, h - slope.abs() * 80);
    var score = 0;
    for (var i = 0; i < lines.length; i++) {
      final a = lines[i].box;
      final ya = a.center.dy - slope * a.center.dx;
      for (var j = i + 1; j < lines.length; j++) {
        final b = lines[j].box;
        // Only cells side by side, in different columns, say anything.
        if (a.right > b.left && b.right > a.left) continue;
        final yb = b.center.dy - slope * b.center.dx;
        if ((ya - yb).abs() <= tolerance) score++;
      }
    }
    if (score > bestScore) {
      bestScore = score;
      best = slope;
    }
  }
  return best;
}
