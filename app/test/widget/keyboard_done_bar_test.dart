import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/screen_harness.dart';

/// iPhone number pads have no return key: a bar with "تم" sits on them
/// (end-to-end test #9).
void main() {
  late ScreenHarness h;

  setUp(() => h = ScreenHarness());
  tearDown(() => h.dispose());

  Finder key(String k) => find.byKey(ValueKey(k));

  Future<String> openGrowth(WidgetTester tester) async {
    final id = (await tester.runAsync(
      () => h.db.addProfile(
        'ليلى',
        sex: 'female',
        birthDate: DateTime(2024, 11, 1),
      ),
    ))!;
    await h.open(tester, '/family/$id/add/growth');
    return id;
  }

  void keyboardUp(WidgetTester tester) {
    tester.view.viewInsets = const FakeViewPadding(bottom: 600);
    addTearDown(tester.view.resetViewInsets);
  }

  testWidgets('on an iPhone a number field gets Done, which closes the pad', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    h.tall(tester);
    await openGrowth(tester);
    expect(key('keyboard-done-bar'), findsNothing);

    await tester.tap(key('field-weightKg'));
    keyboardUp(tester);
    await tester.pumpAndSettle();
    expect(key('keyboard-done-bar'), findsOneWidget);
    expect(find.text('تم'), findsOneWidget);
    // Typing goes on as before.
    await tester.enterText(key('field-weightKg'), '12');
    await tester.pump();
    expect(find.text('12'), findsOneWidget);

    await tester.tap(key('keyboard-done'));
    await tester.pump();
    expect(
      FocusManager.instance.primaryFocus?.context?.widget,
      isNot(isA<EditableText>()),
    );
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    expect(key('keyboard-done-bar'), findsNothing);
    // What was typed is still there.
    expect(find.text('12'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('Android gets no bar: its number pad has a Done key', (
    tester,
  ) async {
    h.tall(tester);
    await openGrowth(tester);
    await tester.tap(key('field-weightKg'));
    keyboardUp(tester);
    await tester.pumpAndSettle();
    // Android (the test default): its pad has its own Done key.
    expect(key('keyboard-done-bar'), findsNothing);
  });
}
