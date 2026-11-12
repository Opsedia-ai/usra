import 'package:flutter/material.dart';

import 'tokens.dart';
import 'type.dart';

/// The small amber dot that marks something needing attention. Decorative:
/// the words next to it say what it means, so screen readers skip it.
class StatusDot extends StatelessWidget {
  const StatusDot({super.key, this.color});

  /// Defaults to the theme's attention dot.
  final Color? color;

  static const size = 8.0;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color ?? context.usra.attentionDot,
        shape: BoxShape.circle,
      ),
    ),
  );
}

/// A quiet status: a dot, then plain text. Replaces tinted chips and pills
/// for things that need attention but aren't an emergency.
class StatusDotText extends StatelessWidget {
  const StatusDotText({
    super.key,
    required this.label,
    this.style,
    this.color,
    this.dotColor,
  });

  final String label;

  /// Defaults to the label style in the attention colour.
  final TextStyle? style;

  /// Text colour; defaults to the theme's attention colour.
  final Color? color;

  /// Defaults to the theme's attention dot.
  final Color? dotColor;

  @override
  Widget build(BuildContext context) {
    final c = context.usra;
    final textStyle = (style ?? UsraType.label).copyWith(
      color: color ?? c.attention,
    );
    final line = (textStyle.fontSize ?? 14) * (textStyle.height ?? 1.4);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Centres the dot on the first line, however the text wraps.
        SizedBox(
          height: MediaQuery.textScalerOf(context).scale(line),
          child: Center(child: StatusDot(color: dotColor)),
        ),
        const SizedBox(width: UsraSpacing.s2),
        Flexible(child: Text(label, style: textStyle)),
      ],
    );
  }
}
