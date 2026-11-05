import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ui_harness.dart';

/// Phones set to very large text (iOS Dynamic Type, Android font size):
/// every main screen must lay out without overflow at 2×, in Arabic and
/// English. A yellow-and-black overflow stripe fails the test.
void main() {
  for (final locale in const [Locale('ar'), Locale('en')]) {
    for (final screen in mainScreens) {
      testWidgets('$screen fits at text size 2.0 (${locale.languageCode})', (
        tester,
      ) async {
        await atDemoTime(() async {
          final errors = await collectFlutterErrors(() async {
            await pumpDemoScreen(
              tester,
              screen,
              locale: locale,
              textScale: 2.0,
            );
            await scrollThrough(tester);
          });
          expect(
            errors.map((e) => e.exceptionAsString().trim()).toList(),
            isEmpty,
            reason: 'layout errors on $screen at 2×',
          );
        });
      });
    }
  }
}

/// Scrolls the page to the bottom, so rows built lazily are laid out too.
Future<void> scrollThrough(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    final page = pageScrollable();
    if (page.evaluate().isEmpty) return;
    await tester.drag(page, const Offset(0, -500), warnIfMissed: false);
    await settle(tester);
  }
}
