import 'package:flutter/material.dart';

import 'tokens.dart';

/// A small label for how something stands. It always has both an icon and
/// words: the colour carries urgency, but never alone, so it still works for
/// colour-blind and older users.
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.severity,
    required this.label,
    this.icon,
  });

  final Severity severity;

  /// The words, which are also what a screen reader says.
  final String label;

  /// Replaces the severity's usual icon.
  final IconData? icon;

  static IconData defaultIcon(Severity severity) => switch (severity) {
    Severity.info => Icons.info_outline,
    Severity.good => Icons.check,
    Severity.headsUp => Icons.schedule,
    Severity.actSoon => Icons.warning_amber_rounded,
    Severity.urgent => Icons.error_outline,
  };

  @override
  Widget build(BuildContext context) {
    final foreground = severity.foregroundOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: UsraSpacing.s3,
        vertical: UsraSpacing.s1,
      ),
      decoration: ShapeDecoration(
        color: severity.backgroundOf(context),
        shape: const StadiumBorder(),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: Icon(
              icon ?? defaultIcon(severity),
              size: 16,
              color: foreground,
            ),
          ),
          const SizedBox(width: UsraSpacing.s1),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: foreground,
                fontSize: 14,
                height: 20 / 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
