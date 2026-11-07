import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import 'tokens.dart';
import 'type.dart';

/// A pill to choose with: person filters, how often, for how long. As tall as
/// a touch target (more in Simple Mode), and the label wraps instead of
/// overflowing at large text. [dashed] marks an optional extra, such as
/// another dose time.
class UsraPill extends StatelessWidget {
  const UsraPill({
    super.key,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.dashed = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onTap;
  final bool selected;
  final bool dashed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.usra;
    final foreground = selected
        ? c.onPrimary
        : dashed
        ? c.primary
        : c.ink;
    // Simple Mode's theme asks for bigger targets; never go below those.
    final height =
        Theme.of(context).textButtonTheme.style?.minimumSize
            ?.resolve(const {})
            ?.height ??
        UsraSizes.touchTarget;
    final Widget content = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: UsraSpacing.s4,
        vertical: UsraSpacing.s1,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            ExcludeSemantics(child: Icon(icon, size: 20, color: foreground)),
            const SizedBox(width: UsraSpacing.s1),
          ],
          Flexible(
            child: Text(
              label,
              style: UsraType.body.copyWith(
                color: foreground,
                fontWeight: selected || dashed
                    ? FontWeight.w600
                    : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
    return Semantics(
      button: true,
      selected: selected,
      enabled: onTap != null,
      child: CustomPaint(
        foregroundPainter: dashed ? _DashedPill(c.lineStrong) : null,
        child: Material(
          color: selected
              ? c.primary
              : dashed
              ? Colors.transparent
              : c.surface,
          shape: StadiumBorder(
            side: selected || dashed
                ? BorderSide.none
                : BorderSide(color: c.lineStrong),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: height, minWidth: height),
              child: Center(widthFactor: 1, child: content),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedPill extends CustomPainter {
  const _DashedPill(this.color);

  final Color color;

  static const _dash = 6.0;
  static const _gap = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final outline = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(1),
          const Radius.circular(UsraRadius.pill),
        ),
      );
    for (final PathMetric metric in outline.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += _dash + _gap) {
        canvas.drawPath(metric.extractPath(d, d + _dash), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedPill old) => old.color != color;
}
