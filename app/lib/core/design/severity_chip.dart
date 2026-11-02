import 'package:flutter/material.dart';

import 'tokens.dart';

/// A small coloured label. The colour carries urgency; the text carries
/// meaning, so it still works for colour-blind and older users.
class SeverityChip extends StatelessWidget {
  const SeverityChip({super.key, required this.severity, required this.label});

  final Severity severity;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: severity.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: severity.foreground,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
