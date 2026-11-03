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

  void tallScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1170, 12000);
    tester.view.devicePixelRatio = 1.5;
    addTearDown(tester.view.reset);
  }

  String iso(DateTime d) => d.toIso8601String().substring(0, 10);

  /// Lets real database work started by a tap finish.
  Future<void> settleDb(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a pregnancy shows its week, schedule and danger signs', (
    tester,
  ) async {
    tallScreen(tester);
    final today = DateUtils.dateOnly(DateTime.now());
    final (mona, ali) = (await tester.runAsync(() async {
      final mona = await db.addProfile(
        'منى',
        birthDate: DateTime(1994, 3, 1),
        sex: 'female',
      );
      final ali = await db.addProfile(
        'علي',
        birthDate: DateTime(1990, 3, 1),
        sex: 'male',
      );
      // 25 weeks pregnant.
      await db.addEvent(
        profileId: mona,
        type: 'pregnancy',
        occurredAt: today,
        dataJson: jsonEncode({
          'lmp': iso(today.subtract(const Duration(days: 175))),
        }),
      );
      await db.addEvent(
        profileId: mona,
        type: 'pregnancyCheck',
        occurredAt: today,
        dataJson: jsonEncode({
          'weightKg': 70,
          'systolic': 150,
          'diastolic': 95,
        }),
      );
      return (mona, ali);
    }))!;
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    final router = GoRouter.of(tester.element(find.byType(Scaffold).first));

    // Home shows the pregnancy, and the visits due feed the follow-ups.
    expect(find.byKey(ValueKey('pregnancy-summary-$mona')), findsOneWidget);
    expect(find.textContaining('منى · 25 أسبوع'), findsOneWidget);

    // Men get no pregnancy button or record type.
    router.go('/family/$ali');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('member-pregnancy')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('add-record')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('type-visit')), findsOneWidget);
    expect(find.byKey(const ValueKey('type-pregnancy')), findsNothing);
    expect(find.byKey(const ValueKey('type-feed')), findsNothing);
    Navigator.of(tester.element(find.byKey(const ValueKey('type-visit'))))
        .pop();
    await tester.pumpAndSettle();

    router.go('/family/$mona');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('member-pregnancy')), findsOneWidget);
    expect(find.text('تحليل سكر الحمل (منحنى السكر)'), findsWidgets);

    await tester.tap(find.byKey(ValueKey('pregnancy-summary-$mona')));
    await tester.pumpAndSettle();
    expect(find.text('متابعة الحمل'), findsOneWidget);
    expect(find.text('التلت التاني'), findsWidgets);
    expect(
      find.byKey(const ValueKey('pregnancy-danger-signs')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('pregnancy-ambulance')), findsOneWidget);
    expect(find.text('نزيف من المهبل'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('anc-anomalyScan')),
        matching: find.text('مش متسجل'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('pregnancy-bp-status')),
        matching: find.textContaining('كلّمي دكتورك'),
      ),
      findsOneWidget,
    );

    // The outcome ends the follow-up.
    await tester.tap(find.byKey(const ValueKey('pregnancy-end')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('field-outcome')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ولادة').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('record-save')));
    await settleDb(tester);
    expect(find.byKey(ValueKey('pregnancy-summary-$mona')), findsNothing);
    router.go('/family/$mona/pregnancy');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('pregnancy-start')), findsOneWidget);
  });

  testWidgets('a baby gets the day log, milestones and a quick check', (
    tester,
  ) async {
    tallScreen(tester);
    final today = DateUtils.dateOnly(DateTime.now());
    final birth = addMonths(today, -3);
    final kid = (await tester.runAsync(() async {
      final kid = await db.addProfile('ليلى', birthDate: birth, sex: 'female');
      await db.addEvent(
        profileId: kid,
        type: 'milestone',
        occurredAt: addMonths(birth, 2),
        dataJson: jsonEncode({'milestone': 'm2_movement'}),
      );
      return kid;
    }))!;
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    final router = GoRouter.of(tester.element(find.byType(Scaffold).first));

    router.go('/family/$kid');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('member-pregnancy')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('member-baby-log')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('log-breast')));
    await settleDb(tester);
    await tester.tap(find.byKey(const ValueKey('log-bottle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pick-90')));
    await settleDb(tester);
    await tester.tap(find.byKey(const ValueKey('log-wet')));
    await settleDb(tester);
    final todayCard = find.byKey(const ValueKey('log-summary-today'));
    expect(
      find.descendant(of: todayCard, matching: find.textContaining('رضعتين')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: todayCard, matching: find.text('90 مل من الببرونة')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: todayCard,
        matching: find.text('الحفاضات: 1 مبلولة، 0 فيها براز'),
      ),
      findsOneWidget,
    );

    // Quick logs stay off the timeline.
    router.go('/family/$kid');
    await tester.pumpAndSettle();
    expect(find.textContaining('رضعة'), findsNothing);
    expect(find.textContaining('مهارة'), findsNothing);

    // Milestones: the 2-month list is a month overdue except what's ticked.
    await tester.tap(find.byKey(const ValueKey('member-development')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('dev-late-banner')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('milestone-m2_social')),
        matching: find.text('اتكلم مع دكتور الأطفال'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('milestone-m2_movement')),
        matching: find.textContaining('من '),
      ),
      findsOneWidget,
    );
    // Unticking deletes the record.
    await tester.tap(find.byKey(const ValueKey('milestone-check-m2_movement')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('milestone-untick')));
    await settleDb(tester);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('milestone-m2_movement')),
        matching: find.text('اتكلم مع دكتور الأطفال'),
      ),
      findsOneWidget,
    );

    // "Give me the weight and I'll check".
    router.go('/family/$kid/growth');
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('check-weight')), '٦');
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('check-status-weight')),
        matching: find.textContaining('في المدى المعتاد'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('check-save')));
    await settleDb(tester);
    expect(find.textContaining('آخر قياس: 6'), findsOneWidget);
  });
}
