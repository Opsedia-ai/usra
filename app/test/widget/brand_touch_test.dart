import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usra/core/design/tokens.dart';

import '../support/fits.dart';
import '../support/screen_harness.dart';

// The brand touch of 13 Nov 2026: warm background, orchid + button with a
// ring in light, and the selected tab on a soft pill.
void main() {
  late ScreenHarness h;

  setUp(() => h = ScreenHarness());
  tearDown(() => h.dispose());

  Finder inAdd(Finder f) => find.descendant(
    of: find.byKey(const ValueKey('tab-action-/add')),
    matching: f,
  );

  Future<void> seed(WidgetTester tester) async {
    await tester.runAsync(() => h.db.addProfile('منى', sex: 'female'));
  }

  ShapeDecoration? pillOf(WidgetTester tester, String path) {
    final box = tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.byKey(ValueKey('tab-$path')),
        matching: find.byType(AnimatedContainer),
      ),
    );
    return box.decoration as ShapeDecoration?;
  }

  for (final (mode, colors) in [
    (ThemeMode.light, UsraColors.light),
    (ThemeMode.dark, UsraColors.dark),
  ]) {
    testWidgets('${mode.name}: the + button is orchid with an on-orchid icon', (
      tester,
    ) async {
      h.theme = mode;
      await seed(tester);
      await h.open(tester, '/home');
      final circle =
          tester
                  .widget<Container>(inAdd(find.byType(Container)).first)
                  .decoration!
              as ShapeDecoration;
      expect(circle.color, colors.orchid);
      final side = (circle.shape as CircleBorder).side;
      if (mode == ThemeMode.light) {
        // Orchid on the white bar is 2.71:1; the ring gives the circle 3:1.
        expect(side.color, colors.orchidInk);
        expect(side.width, 1);
      } else {
        expect(side, BorderSide.none);
      }
      final icon = tester.widget<Icon>(inAdd(find.byIcon(Icons.add)));
      expect(icon.color, colors.onOrchid);
    });

    testWidgets('${mode.name}: the selected tab sits on the soft pill', (
      tester,
    ) async {
      h.theme = mode;
      await seed(tester);
      await h.open(tester, '/home');
      expect(pillOf(tester, '/home')!.color, colors.primarySoft);
      expect(pillOf(tester, '/settings')?.color, isNull);
      final page = tester.element(find.byType(Scaffold).first);
      expect(Theme.of(page).scaffoldBackgroundColor, colors.bg);
    });
  }

  group('Home with the new bar fits 320 px at double text', () {
    forEachSmallLayout(() => h, (tester) async {
      await seed(tester);
      await h.open(tester, '/home');
      await walkScreen(tester);
    });
  });
}
