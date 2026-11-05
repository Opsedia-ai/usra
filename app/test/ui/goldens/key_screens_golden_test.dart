@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../ui_harness.dart';

/// Screenshots of the key screens with the demo family, in Arabic, English
/// and Arabic at large text (1.6×), compared with the PNGs in `images/`.
/// A change that moves anything on these screens fails here until the
/// images are updated on purpose (test/ui/README.md).
void main() {
  const keyScreens = {
    'home',
    'family',
    'member-toddler',
    'emergency-card',
    'child-vaccines',
    'pregnancy',
    'labs',
    'fever',
    'medicines-today',
    'simple-home',
  };
  const variants = [
    (Locale('ar'), 1.0, 'ar'),
    (Locale('en'), 1.0, 'en'),
    (Locale('ar'), 1.6, 'ar-large'),
  ];
  for (final screen in mainScreens.where((s) => keyScreens.contains(s.name))) {
    for (final (locale, scale, tag) in variants) {
      testWidgets('golden: $screen ($tag)', (tester) async {
        await atDemoTime(() async {
          await pumpDemoScreen(
            tester,
            screen,
            locale: locale,
            textScale: scale,
          );
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('images/${screen.name}-$tag.png'),
          );
        });
      });
    }
  }
}
