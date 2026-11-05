import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/ui/ui_harness.dart';

/// Opens every main screen with the demo family and saves a screenshot of
/// each, for UX reviews. Not a pass/fail check. Language and text size come
/// from `--dart-define=TOUR_LOCALE=ar|en` and `TOUR_TEXT_SCALE=1.0|1.6|2.0`.
/// See integration_test/README.md for the command.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const language = String.fromEnvironment('TOUR_LOCALE', defaultValue: 'ar');
  final scale = double.parse(
    const String.fromEnvironment('TOUR_TEXT_SCALE', defaultValue: '1.0'),
  );

  for (final screen in mainScreens) {
    testWidgets('tour: $screen', (tester) async {
      await pumpDemoScreen(
        tester,
        screen,
        locale: Locale(language),
        textScale: scale,
        size: null,
      );
      await binding.takeScreenshot('$language-x$scale-${screen.name}');
    });
  }
}
