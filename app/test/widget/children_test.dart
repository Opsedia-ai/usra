import 'dart:convert';

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:usra/app.dart';
import 'package:usra/core/database/app_database.dart';
import 'package:usra/core/providers.dart';
import 'package:usra/features/children/growth.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
  });
  tearDown(() => db.close());

  Widget app() => ProviderScope(
    overrides: [databaseProvider.overrideWithValue(db)],
    child: const UsraApp(),
  );

  Finder chipText(String key, String text) => find.descendant(
    of: find.byKey(ValueKey(key)),
    matching: find.textContaining(text),
  );

  testWidgets('a baby gets growth status and the vaccination schedule', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 9000);
    tester.view.devicePixelRatio = 1.5;
    addTearDown(tester.view.reset);
    final today = DateUtils.dateOnly(DateTime.now());
    final birth = addMonths(today, -8);
    final (kid, adult) = (await tester.runAsync(() async {
      final kid = await db.addProfile('ليلى', birthDate: birth, sex: 'female');
      final adult = await db.addProfile(
        'منى',
        birthDate: DateTime(1990, 5, 1),
        sex: 'female',
      );
      // At 6 months: a usual weight, and a length far below the curves.
      await db.addEvent(
        profileId: kid,
        type: 'growth',
        occurredAt: addMonths(birth, 6),
        dataJson: jsonEncode({'weightKg': 7.3, 'heightCm': 55, 'headCm': 42.2}),
      );
      await db.addEvent(
        profileId: kid,
        type: 'vaccine',
        occurredAt: birth,
        dataJson: jsonEncode({'vaccine': 'شلل الأطفال'}),
      );
      // Malformed data from elsewhere must not break the page.
      await db.addEvent(
        profileId: kid,
        type: 'vaccine',
        occurredAt: birth,
        dataJson: jsonEncode({'vaccine': 'BCG', 'dose': '1'}),
      );
      return (kid, adult);
    }))!;
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    final router = GoRouter.of(tester.element(find.byType(Scaffold).first));

    // Grown-ups have no growth page.
    router.go('/family/$adult');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('member-growth')), findsNothing);
    router.go('/family/$adult/growth');
    await tester.pumpAndSettle();
    expect(find.textContaining('أقل من ٥ سنين'), findsOneWidget);

    router.go('/family/$kid');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('member-growth')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('member-growth')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('vaccine-summary')), findsOneWidget);
    // Opens on the measure outside the range; the others are a tap away.
    await tester.tap(find.byKey(const ValueKey('growth-tab-weight')));
    await tester.pumpAndSettle();
    expect(
      chipText('growth-status-weight', 'جوه المعدل المرجعي'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('growth-tab-height')));
    await tester.pumpAndSettle();
    expect(
      chipText('growth-status-height', 'اتكلم مع دكتور الأطفال'),
      findsOneWidget,
    );
    // Head circumference is charted too (near the WHO median for girls at 6 months).
    await tester.tap(find.byKey(const ValueKey('growth-tab-head')));
    await tester.pumpAndSettle();
    expect(find.text('محيط الراس حسب السن'), findsOneWidget);
    expect(
      chipText('growth-status-head', 'جوه المعدل المرجعي'),
      findsOneWidget,
    );
    // No prematurity correction, and it says so.
    expect(find.byKey(const ValueKey('growth-head-note')), findsOneWidget);
    // Two of the 18 required doses are recorded.
    expect(chipText('vaccine-required-$kid', '٢/١٨'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('vaccine-open-all')));
    await tester.pumpAndSettle();
    expect(chipText('dose-opv-0', 'اتاخد'), findsOneWidget);
    expect(chipText('dose-hepB-0', 'متأخر'), findsOneWidget);
    expect(chipText('dose-bcg-1', 'اتاخد'), findsOneWidget);
    expect(chipText('dose-mmr-1', 'معاده'), findsNothing);
    expect(find.textContaining('كارت التطعيم'), findsOneWidget);
    // Optional vaccines aren't followed by default: never overdue.
    expect(find.byKey(const ValueKey('dose-pcv-1')), findsNothing);

    router.go('/family/$kid/growth');
    await tester.pumpAndSettle();

    // A new measurement goes through the generic record form.
    await tester.tap(find.byKey(const ValueKey('growth-add')));
    await tester.pumpAndSettle();
    // An empty measurement isn't saved.
    await tester.tap(find.byKey(const ValueKey('record-save')));
    await tester.pumpAndSettle();
    expect(find.text('مطلوب'), findsNWidgets(3));
    await tester.enterText(find.byKey(const ValueKey('field-weightKg')), '٨');
    await tester.tap(find.byKey(const ValueKey('record-save')));
    await tester.pumpAndSettle();
    // Back on Growth, in the history.
    expect(find.byKey(const ValueKey('growth-history')), findsOneWidget);
    expect(find.textContaining('٨ كجم'), findsWidgets);
  });
}
