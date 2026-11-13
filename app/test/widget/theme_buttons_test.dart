import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usra/core/design/theme.dart';
import 'package:usra/core/design/tokens.dart';

double _luminance(Color c) {
  double ch(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

double _contrast(Color a, Color b) {
  final (x, y) = (_luminance(a), _luminance(b));
  return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
}

/// Outlined buttons and selected segments read clearly in both themes (QA
/// M9, M10): ink, not dark mode's light-blue primary.
void main() {
  for (final brightness in Brightness.values) {
    test('$brightness: outlined and segmented buttons use ink', () {
      final theme = buildUsraTheme(brightness: brightness);
      final c = theme.extension<UsraColors>()!;
      final outlined = theme.outlinedButtonTheme.style!.foregroundColor!
          .resolve(const {})!;
      expect(outlined, c.ink);
      expect(_contrast(outlined, c.surface), greaterThan(7));
      expect(_contrast(outlined, c.bg), greaterThan(7));

      final segment = theme.segmentedButtonTheme.style!;
      final selected = segment.foregroundColor!.resolve(const {
        WidgetState.selected,
      })!;
      final fill = segment.backgroundColor!.resolve(const {
        WidgetState.selected,
      })!;
      expect(selected, c.ink);
      expect(_contrast(selected, fill), greaterThan(7));
    });
  }
}
