import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usra/core/providers.dart';
import 'package:usra/core/util/localized_digits.dart';

import '../support/screen_harness.dart';

/// Small text fixes from the final end-to-end test: #12 greeting, #15 growth
/// rows, #16 whose record, #17 full stops.
void main() {
  late ScreenHarness h;

  setUp(() => h = ScreenHarness());
  tearDown(() => h.dispose());

  Finder key(String k) => find.byKey(ValueKey(k));

  test(
    'a full stop stays a full stop; only a decimal point becomes ٫ (#17)',
    () {
      expect(digitsIn('ar', 'مش النهارده. ٦٨.5'), 'مش النهارده. ٦٨٫٥');
      expect(digitsIn('ar', '18 جرعة.'), '١٨ جرعة.');
      expect(digitsIn('ar', '38.5'), '٣٨٫٥');
      expect(digitsIn('ar', 'v1.'), 'v١.');
      expect(digitsIn('en', '38.5.'), '38.5.');
    },
  );

  for (final (hour, want) in [
    (9, 'صباح الخير'),
    (12, 'صباح الخير'),
    (13, 'مساء الخير'),
    (21, 'مساء الخير'),
  ]) {
    testWidgets('greeting at $hour:41 says $want (#12)', (tester) async {
      h.tall(tester);
      h.overrides = [
        clockProvider.overrideWithValue(() => DateTime(2026, 11, 13, hour, 41)),
      ];
      await tester.runAsync(() => h.db.addProfile('منى', sex: 'female'));
      await h.open(tester, '/home');
      expect(tester.widget<Text>(key('home-greeting')).data, contains(want));
    });
  }

  testWidgets('a growth row shows each measure with its unit (#15)', (
    tester,
  ) async {
    h.tall(tester);
    final id = (await tester.runAsync(() async {
      final id = await h.db.addProfile(
        'ليلى',
        sex: 'female',
        birthDate: DateTime(2024, 11, 1),
      );
      await h.db.addEvent(
        profileId: id,
        type: 'growth',
        occurredAt: DateTime(2026, 11, 13),
        dataJson: jsonEncode({'weightKg': 12, 'heightCm': 86}),
      );
      return id;
    }))!;
    await h.open(tester, '/family/$id');
    await tester.scrollUntilVisible(
      find.textContaining('١٢ كجم – ٨٦ سم'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('١٢ كجم – ٨٦ سم'), findsWidgets);
  });

  testWidgets('a visit form says whose visit it is (#16)', (tester) async {
    h.tall(tester);
    final id = (await tester.runAsync(
      () => h.db.addProfile('حسن', sex: 'male'),
    ))!;
    await h.open(tester, '/family/$id/add/visit');
    expect(find.text('السجل ده لحسن'), findsOneWidget);
  });
}
