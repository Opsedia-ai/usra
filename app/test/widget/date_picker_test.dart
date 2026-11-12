import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usra/core/util/date_picker.dart';

void main() {
  group('parseTypedDate', () {
    final may14 = DateTime(1991, 5, 14);
    for (final typed in [
      '١٩٩١/٥/١٤',
      '١٤/٥/١٩٩١',
      '14/5/1991',
      '1991/5/14',
      '1991-05-14',
      '14.5.1991',
      '۱۴/۵/۱۹۹۱',
      '‏١٤‏/٥‏/١٩٩١',
      ' ١٤ / ٥ / ١٩٩١ ',
    ]) {
      test('reads "$typed"', () => expect(parseTypedDate(typed), may14));
    }
    for (final typed in [
      '',
      '١٤/٥',
      '٣١/٢/١٩٩١',
      '14/13/1991',
      '0/5/1991',
      'abc',
      '14/5/91',
    ]) {
      test('refuses "$typed"', () => expect(parseTypedDate(typed), isNull));
    }
  });

  group('typing a date in Arabic (bug E)', () {
    Future<(DateTime?, bool)> typeInto(
      WidgetTester tester,
      String typed,
    ) async {
      DateTime? result;
      var closed = false;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Builder(
            builder: (c) => TextButton(
              onPressed: () async {
                result = await pickDate(
                  c,
                  initialDate: DateTime(1990),
                  firstDate: DateTime(1900),
                  lastDate: DateTime(2026, 11, 12),
                );
                closed = true;
              },
              child: const Text('go'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();
      // It starts with a date it can read back: no hidden marks.
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '١/١/١٩٩٠',
      );
      await tester.enterText(find.byType(TextField), typed);
      await tester.pumpAndSettle();
      await tester.tap(
        find
            .descendant(
              of: find.byType(Dialog),
              matching: find.byType(TextButton),
            )
            .last,
      );
      await tester.pumpAndSettle();
      return (result, closed);
    }

    for (final typed in ['١٩٩١/٥/١٤', '١٤/٥/١٩٩١', '14/5/1991']) {
      testWidgets('"$typed" is taken', (tester) async {
        final (result, closed) = await typeInto(tester, typed);
        expect(closed, isTrue);
        expect(result, DateTime(1991, 5, 14));
      });
    }

    testWidgets('a date that doesn\'t exist says so, and keeps the dialog', (
      tester,
    ) async {
      final (result, closed) = await typeInto(tester, '٣١/٢/١٩٩١');
      expect(closed, isFalse);
      expect(result, isNull);
      expect(find.byType(Dialog), findsOneWidget);
    });
  });
}
