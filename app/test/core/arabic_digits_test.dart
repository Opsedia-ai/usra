import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:usra/core/records/record_type.dart';
import 'package:usra/core/util/localized_digits.dart';
import 'package:usra/core/util/localized_numbers.dart';
import 'package:usra/features/family/record_display.dart';
import 'package:usra/l10n/app_localizations.dart';

final _latin = RegExp('[0-9]');

/// [source] without what ICU reads rather than prints: plural and select
/// keys such as `=1{` or `m2_social{`.
String _printedText(String source) =>
    source.replaceAll(RegExp(r'[=\w]*\d\w*\{'), '{');

void main() {
  final ar = lookupAppLocalizations(const Locale('ar'));
  final en = lookupAppLocalizations(const Locale('en'));

  test('Arabic counts use Arabic-Indic digits, English keeps its own', () {
    expect(ar.pregnancyWeek(22, 2), '٢٢ أسبوع ويومين');
    expect(ar.pregnancyWeek(22, 0), '٢٢ أسبوع و٠ يوم');
    expect(ar.pregnancyDaysLeft(124), contains('فاضل ١٢٤ يوم'));
    expect(ar.prescriptionEveryNHours(8), 'كل ٨ ساعات');
    expect(ar.reportPage(1, 12), isNot(contains(_latin)));
    expect(ar.courseDayOf(3, 7), isNot(contains(_latin)));
    expect(en.pregnancyDaysLeft(124), contains('124'));
  });

  test('Plural forms are still chosen from the number', () {
    expect(ar.prescriptionEveryNHours(2), 'كل ساعتين');
    expect(ar.prescriptionEveryNHours(11), 'كل ١١ ساعة');
    expect(en.prescriptionEveryNHours(1), 'Every hour');
  });

  test('Numbers formatted for Arabic match the Arabic-Indic dates', () async {
    // Loads the same date data the app runs with.
    await GlobalMaterialLocalizations.delegate.load(const Locale('ar'));
    expect(formatMoney(40000, locale: 'ar', currency: 'ج.م'), '٤٠٠ ج.م');
    expect(formatMoney(123450, locale: 'ar', currency: 'ج.م'), '١٬٢٣٤٫٥٠ ج.م');
    expect(formatMoney(40000, locale: 'en', currency: 'EGP'), '400 EGP');
    expect(NumberFormat.decimalPattern('ar').format(68.5), '٦٨٫٥');
    expect(DateFormat.y('ar').format(DateTime(2026)), '٢٠٢٦');
  });

  group('Strings can not bring the mix back', () {
    final arabic = jsonDecode(
      File('lib/l10n/app_ar.arb').readAsStringSync(),
    ) as Map<String, dynamic>;

    // gen-l10n writes an int placeholder with no format as a bare `$count`,
    // which is always Latin. Reads what it generated, because a placeholder's
    // details in either ARB file can decide it. The group number names a
    // place in the recovery key, which stays as written.
    test('No generated text prints a bare number', () {
      final method = RegExp(
        r'String (\w+)\(([^)]*)\) \{(.*?)\n  \}\n',
        dotAll: true,
      );
      for (final language in ['ar', 'en']) {
        final generated = File('lib/l10n/app_localizations_$language.dart')
            .readAsStringSync();
        final bare = <String>[
          for (final m in method.allMatches(generated))
            if (m[1] != 'recoveryKeyGroupLabel')
              for (final int in RegExp(r'int (\w+)').allMatches(m[2]!))
                if (RegExp('\\\$${int[1]}\\b').hasMatch(m[3]!))
                  '${m[1]}.${int[1]}',
        ];
        expect(bare, isEmpty, reason: language);
      }
    });

    test('Arabic text has no Latin digits of its own', () {
      // An example of what to type: lab ranges are typed and read in Latin.
      const typedInLatin = {'labTestRangeHint'};
      final found = <String>[
        for (final MapEntry(:key, :value) in arabic.entries)
          if (!key.startsWith('@') &&
              !typedInLatin.contains(key) &&
              _printedText(value as String).contains(_latin))
            key,
      ];
      expect(found, isEmpty);
    });
  });

  test('Each way into the app turns the digits on first', () {
    for (final (file, opening) in [
      ('lib/main.dart', 'useArabicIndicNumbers();'),
      (
        'lib/features/medicines/local_notification_scheduler.dart',
        'useArabicIndicNumbers();',
      ),
    ]) {
      expect(File(file).readAsStringSync(), contains(opening), reason: file);
    }
  });

  group('A record field', () {
    Future<String> shown(
      WidgetTester tester,
      Locale locale,
      FieldSpec field,
      Object value,
    ) async {
      late String text;
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Builder(
            builder: (context) {
              text = displayFieldValue(context, field, value);
              return const SizedBox();
            },
          ),
        ),
      );
      return text;
    }

    const number = FieldSpec(key: 'w', kind: FieldKind.number);
    const lab = FieldSpec(
      key: 'v',
      kind: FieldKind.number,
      keepsLatinDigits: true,
    );
    const typed = FieldSpec(key: 't', kind: FieldKind.text);

    testWidgets('A number follows the language', (tester) async {
      expect(await shown(tester, const Locale('ar'), number, 68.5), '٦٨٫٥');
      expect(await shown(tester, const Locale('en'), number, 68.5), '68.5');
    });

    testWidgets('A lab value and typed text stay as they are', (tester) async {
      expect(await shown(tester, const Locale('ar'), lab, 5.4), '5.4');
      expect(
        await shown(tester, const Locale('ar'), typed, 'Ferro 500'),
        'Ferro 500',
      );
    });
  });

  test('digitsIn leaves text already in Arabic-Indic digits alone', () {
    expect(digitsIn('ar', '٦٨٫٥'), '٦٨٫٥');
  });
}
