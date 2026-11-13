import 'package:flutter/material.dart';

import 'tokens.dart';
import 'usra_mark_svg.dart';

export 'usra_mark_svg.dart';

/// Dr. Usra's mark: a small house outline with his orchid heart inside.
///
/// Decorative, so screen readers skip it. Kept small and calm: beside a
/// greeting or a page title, over a friendly empty state, in a success
/// message. Like Dr. Usra himself, it never appears on emergency, warning,
/// sick-day, lock, error or delete screens.
///
/// The outline is primary (navy in light, light navy in dark). The heart is
/// orchid; where orchid is under 3:1 on [background] (light pages and the
/// white PDF), the heart takes a thin orchid-ink edge that is over 3:1.
class UsraMark extends StatelessWidget {
  const UsraMark({
    super.key,
    this.size = medium,
    this.outline,
    this.background,
  });

  static const small = 16.0;
  static const medium = 20.0;
  static const large = 24.0;

  /// The welcome screen's brand moment.
  static const hero = 32.0;

  final double size;

  /// The house's colour. Primary by default.
  final Color? outline;

  /// What the mark sits on, to keep the heart's edge at 3:1. The page
  /// background by default.
  final Color? background;

  /// The heart's edge on [background], or null when orchid alone is 3:1.
  static Color? heartEdgeOn(Color background, UsraColors c) {
    if (contrastRatio(c.orchid, background) >= 3) return null;
    // Orchid-ink of whichever theme stands out on this background.
    final a = UsraColors.light.orchidInk;
    final b = UsraColors.dark.orchidInk;
    return contrastRatio(a, background) >= contrastRatio(b, background) ? a : b;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.usra;
    final on = background ?? c.bg;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: UsraMarkPainter(
            outline: outline ?? c.primary,
            heart: c.orchid,
            heartEdge: heartEdgeOn(on, c),
          ),
        ),
      ),
    );
  }
}

/// WCAG 2.x contrast ratio between two opaque colours.
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

/// Draws the mark from the 30 × 30 artwork of the brand samples (the same
/// artwork as [usraMarkSvg], used in the PDF reports).
class UsraMarkPainter extends CustomPainter {
  const UsraMarkPainter({
    required this.outline,
    required this.heart,
    this.heartEdge,
  });

  final Color outline;
  final Color heart;
  final Color? heartEdge;

  static const _art = 30.0;

  /// The house: a pitched roof and walls with rounded bottom corners.
  static Path house() => Path()
    ..moveTo(4, 14)
    ..lineTo(15, 4.5)
    ..lineTo(26, 14)
    ..lineTo(26, 25.5)
    ..arcToPoint(const Offset(24.5, 27), radius: const Radius.circular(1.5))
    ..lineTo(5.5, 27)
    ..arcToPoint(const Offset(4, 25.5), radius: const Radius.circular(1.5))
    ..close();

  /// The heart inside the house.
  static Path heartPath() => Path()
    ..moveTo(15, 23)
    ..cubicTo(9.5, 19.2, 9.6, 14.6, 12.3, 14.2)
    ..cubicTo(13.6, 14, 14.5, 14.8, 15, 15.8)
    ..cubicTo(15.5, 14.8, 16.4, 14, 17.7, 14.2)
    ..cubicTo(20.4, 14.6, 20.5, 19.2, 15, 23)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / _art;
    canvas.save();
    canvas.scale(scale);
    // At least 1.3 px wide, so the outline holds up at 16.
    final stroke = (2.2 * scale).clamp(1.3, double.infinity) / scale;
    canvas.drawPath(
      house(),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeJoin = StrokeJoin.round
        ..color = outline
        ..isAntiAlias = true,
    );
    final h = heartPath();
    canvas.drawPath(h, Paint()..color = heart);
    final edge = heartEdge;
    if (edge != null) {
      canvas.drawPath(
        h,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.9 / scale
          ..strokeJoin = StrokeJoin.round
          ..color = edge,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(UsraMarkPainter old) =>
      old.outline != outline ||
      old.heart != heart ||
      old.heartEdge != heartEdge;
}

/// A page title with the mark at its start, for the main tabs and calm
/// headers. The title stays the only thing a screen reader hears.
class UsraMarkTitle extends StatelessWidget {
  const UsraMarkTitle(
    this.title, {
    super.key,
    this.style,
    this.markSize = UsraMark.large,
    this.textKey,
  });

  final String title;
  final TextStyle? style;
  final double markSize;
  final Key? textKey;

  @override
  // The title takes exactly the room left beside the mark. When there's
  // hardly any room (very large text beside another control), the mark
  // steps aside rather than push the title out.
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final text = Text(title, key: textKey, style: style);
      if (box.maxWidth < markSize * 4) return text;
      return Row(
        children: [
          UsraMark(size: markSize),
          const SizedBox(width: UsraSpacing.s2),
          Expanded(child: text),
        ],
      );
    },
  );
}

/// A friendly empty state: the mark over a short, muted line.
class UsraMarkedEmpty extends StatelessWidget {
  const UsraMarkedEmpty(this.text, {super.key, this.textKey, this.style});

  final String text;
  final Key? textKey;

  /// The line's style; the page's body text by default.
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const UsraMark(size: UsraMark.large),
      const SizedBox(height: UsraSpacing.s2),
      Text(
        text,
        key: textKey,
        textAlign: TextAlign.center,
        style: style ?? Theme.of(context).textTheme.bodyLarge,
      ),
    ],
  );
}
