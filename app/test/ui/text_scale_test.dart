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
            errors.map(describeLayoutError).toList(),
            isEmpty,
            reason: 'layout errors on $screen at 2×',
          );
        });
      });
    }
  }
}

/// Scrolls the page to the bottom and back, so rows built lazily are laid
/// out too.
Future<void> scrollThrough(WidgetTester tester) async {
  // Drags from the middle of the screen (not a found Scrollable: a page
  // with tabs has viewports that aren't laid out).
  final middle = tester.view.physicalSize / tester.view.devicePixelRatio;
  for (var i = 0; i < 8; i++) {
    await tester.dragFrom(
      Offset(middle.width / 2, middle.height * 0.6),
      const Offset(0, -500),
    );
    await settle(tester);
  }
}

/// "A RenderFlex overflowed by 75 pixels on the right. (lib/...dart:120)":
/// the message and where the widget that overflowed is in the code.
String describeLayoutError(FlutterErrorDetails e) {
  final where = RegExp(r'lib/[\w/]+\.dart:\d+')
      .firstMatch(e.toString())
      ?.group(0);
  return '${e.exceptionAsString().trim()}${where == null ? '' : ' ($where)'}';
}
