import 'package:flutter/painting.dart';

/// Usra brand colours (Nile blue scheme). See design/README.md.
abstract final class UsraColors {
  static const primary = Color(0xFF1F5FA8);
  static const primaryDark = Color(0xFF174A85);
  static const primaryTint = Color(0xFFE6EEF8);
  static const background = Color(0xFFF3F6FA);
  static const surface = Color(0xFFFFFFFF);
  static const text = Color(0xFF14263D);
  static const textMuted = Color(0xFF55657A);
  static const sand = Color(0xFFF6EEDF);
  static const cheek = Color(0xFFF3B8A6);
  static const line = Color(0xFFDDE5EF);
  static const emergency = Color(0xFFC62828);
}

/// How urgent or important something is. Always shown with a word too.
enum Severity { info, good, headsUp, actSoon, urgent }

extension SeverityColors on Severity {
  Color get background => switch (this) {
    Severity.info => const Color(0xFFE6EEF8),
    Severity.good => const Color(0xFFE6F4EA),
    Severity.headsUp => const Color(0xFFFFF6CC),
    Severity.actSoon => const Color(0xFFFFE8D6),
    Severity.urgent => const Color(0xFFFDECEA),
  };

  Color get foreground => switch (this) {
    Severity.info => const Color(0xFF174A85),
    Severity.good => const Color(0xFF1F6B3F),
    Severity.headsUp => const Color(0xFF7A5B00),
    Severity.actSoon => const Color(0xFFA14A00),
    Severity.urgent => const Color(0xFFB42318),
  };
}
