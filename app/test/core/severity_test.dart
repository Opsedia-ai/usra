import 'dart:math';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usra/core/design/tokens.dart';

double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (max(la, lb) + 0.05) / (min(la, lb) + 0.05);
}

void main() {
  test('every severity label is readable (WCAG AA 4.5:1)', () {
    for (final s in Severity.values) {
      expect(
        contrast(s.foreground, s.background),
        greaterThanOrEqualTo(4.5),
        reason: s.name,
      );
    }
  });

  test('severity backgrounds are all different', () {
    final backgrounds = Severity.values.map((s) => s.background).toSet();
    expect(backgrounds, hasLength(Severity.values.length));
  });

  test('brand text is readable on the app background', () {
    expect(
      contrast(UsraColors.text, UsraColors.background),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      contrast(UsraColors.textMuted, UsraColors.background),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      contrast(const Color(0xFFFFFFFF), UsraColors.primary),
      greaterThanOrEqualTo(4.5),
    );
  });
}
