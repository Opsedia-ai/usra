import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ui_harness.dart';

/// Flutter's accessibility guidelines on every main screen, in Arabic and
/// English: tap targets (48×48 Android, 44×44 iOS), a label on everything
/// tappable, and text contrast (WCAG AA: 4.5:1, 3:1 for large text).
void main() {
  for (final locale in const [Locale('ar'), Locale('en')]) {
    for (final screen in mainScreens) {
      final lang = locale.languageCode;
      testWidgets('$screen meets accessibility guidelines ($lang)', (
        tester,
      ) async {
        await atDemoTime(() async {
          final semantics = tester.ensureSemantics();
          await pumpDemoScreen(tester, screen, locale: locale);
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await expectLater(tester, meetsGuideline(textContrastGuideline));
          semantics.dispose();
        });
      });
    }
  }
}
