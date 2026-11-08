import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usra/core/design/dismiss_keyboard.dart';

void main() {
  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => DismissKeyboardOnTap(child: child!),
        home: Scaffold(
          body: Column(
            children: [
              const TextField(
                key: Key('hours'),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(key: Key('empty'), height: 200, width: 200),
            ],
          ),
        ),
      ),
    );
  }

  bool focused(WidgetTester tester, String key) => tester
      .widget<EditableText>(
        find.descendant(
          of: find.byKey(Key(key)),
          matching: find.byType(EditableText),
        ),
      )
      .focusNode
      .hasFocus;

  testWidgets('a tap on empty space closes the keyboard', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('hours')));
    await tester.pump();
    expect(focused(tester, 'hours'), isTrue);

    await tester.tap(find.byKey(const Key('empty')));
    await tester.pump();
    expect(focused(tester, 'hours'), isFalse);
  });

  testWidgets('buttons and other fields still get their taps', (tester) async {
    var pressed = 0;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => DismissKeyboardOnTap(child: child!),
        home: Scaffold(
          body: Column(
            children: [
              const TextField(key: Key('hours')),
              const TextField(key: Key('other')),
              ElevatedButton(
                key: const Key('save'),
                onPressed: () => pressed++,
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('hours')));
    await tester.pump();

    await tester.tap(find.byKey(const Key('other')));
    await tester.pump();
    expect(focused(tester, 'other'), isTrue);

    await tester.tap(find.byKey(const Key('save')));
    await tester.pump();
    expect(pressed, 1);
  });
}
