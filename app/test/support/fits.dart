import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// The smallest phone we design for, at double text size.
void smallPhoneDoubleText(WidgetTester tester) {
  tester.view.devicePixelRatio = 2;
  tester.view.physicalSize = const Size(640, 1280);
  tester.platformDispatcher.textScaleFactorTestValue = 2;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

/// No text on screen under [min] before the phone's own text scale.
void expectNoTinyText(WidgetTester tester, {double min = 14}) {
  for (final p in tester.renderObjectList<RenderParagraph>(
    find.byType(RichText),
  )) {
    p.text.visitChildren((span) {
      final size = span.style?.fontSize;
      if (size != null && span is TextSpan && (span.text ?? '').isNotEmpty) {
        expect(size, greaterThanOrEqualTo(min), reason: '"${span.text}"');
      }
      return true;
    });
  }
}

/// Scrolls [scrollable] end to end, failing on any overflow or tiny text.
Future<void> walkScreen(
  WidgetTester tester, {
  Finder? scrollable,
  double min = 14,
}) async {
  expect(tester.takeException(), isNull);
  expectNoTinyText(tester, min: min);
  final list = scrollable ?? find.byType(Scrollable).last;
  if (list.evaluate().isEmpty) return;
  for (var i = 0; i < 30; i++) {
    final position = tester.state<ScrollableState>(list).position;
    if (position.pixels >= position.maxScrollExtent) break;
    await tester.drag(list, const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expectNoTinyText(tester, min: min);
  }
}
