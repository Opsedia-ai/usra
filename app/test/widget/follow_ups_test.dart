import 'dart:convert';

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:usra/app.dart';
import 'package:usra/core/database/app_database.dart';
import 'package:usra/core/design/list_row.dart';
import 'package:usra/core/design/status_chip.dart';
import 'package:usra/core/design/status_dot.dart';
import 'package:usra/core/providers.dart';
import 'package:usra/features/follow_ups/dismissals.dart';
import 'package:usra/features/follow_ups/follow_ups_section.dart';

void main() {
  late AppDatabase db;
  late MemoryDismissalStore store;

  setUp(() {
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    store = MemoryDismissalStore();
  });
  tearDown(() => db.close());

  Widget app() => ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      dismissalStoreProvider.overrideWithValue(store),
    ],
    child: const UsraApp(),
  );

  Finder tiles(String section) => find.descendant(
    of: find.byKey(ValueKey(section)),
    matching: find.byType(FollowUpTile),
  );

  testWidgets('follow-ups on Home and a person’s page: why, when, hide, add', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 12000);
    tester.view.devicePixelRatio = 1.5;
    addTearDown(tester.view.reset);
    final today = DateUtils.dateOnly(DateTime.now());
    final due = today.subtract(const Duration(days: 3));
    final (mona, visit) = (await tester.runAsync(() async {
      final mona = await db.addProfile(
        'منى',
        birthDate: DateTime(today.year - 50, 1, 1),
        sex: 'female',
        conditions: 'سكر',
      );
      await db.addProfile('أحمد', birthDate: DateTime(today.year - 30, 1, 1));
      final visit = await db.addEvent(
        profileId: mona,
        type: 'visit',
        occurredAt: today.subtract(const Duration(days: 40)),
        dataJson: jsonEncode({
          'doctorName': 'د. سامي',
          'nextVisit': DateFormat('yyyy-MM-dd').format(due),
        }),
      );
      return (mona, visit);
    }))!;
    final dueKey = '$mona|visit.$visit|${DateFormat('yyyy-MM-dd').format(due)}';

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    // Home: the next three across the family, most urgent first, by name.
    expect(tiles('home-follow-ups'), findsNWidgets(homeFollowUpCount));
    final first = find.byKey(ValueKey('follow-up-$dueKey'));
    expect(
      find.descendant(of: first, matching: find.text('منى · زيارة متابعة')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: first,
        matching: find.text('د. سامي حدد الميعاد ده في آخر زيارة'),
      ),
      findsOneWidget,
    );
    // Late: an amber dot and the words, no coloured border or chip.
    final when = tester.widget<StatusDotText>(
      find.descendant(of: first, matching: find.byType(StatusDotText)),
    );
    expect(when.label, startsWith('كان معاده'));
    expect(
      find.descendant(of: first, matching: find.byType(StatusChip)),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('home-follow-ups')),
        matching: find.byType(UsraListCard),
      ),
      findsOneWidget,
    );
    // The short action still says in full what it records.
    expect(
      find.descendant(
        of: find.byKey(ValueKey('follow-up-add-$dueKey')),
        matching: find.text('تسجيل'),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('مش تشخيص'), findsOneWidget);

    // Her page: everything, each saying why.
    final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
    router.go('/family/$mona/follow-ups');
    await tester.pumpAndSettle();
    final section = find.byKey(const ValueKey('member-follow-ups'));
    expect(
      find.descendant(
        of: section,
        matching: find.textContaining('لأن عندها سكر'),
      ),
      findsWidgets,
    );
    expect(
      find.descendant(of: section, matching: find.text('ماموجرام (فحص الثدي)')),
      findsOneWidget,
    );
    final count = tester.widgetList(tiles('member-follow-ups')).length;

    // Hidden for this cycle, saved, and back with Undo.
    await tester.tap(find.byKey(ValueKey('dismiss-$dueKey')));
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('follow-up-$dueKey')), findsNothing);
    expect(tiles('member-follow-ups'), findsNWidgets(count - 1));
    expect(store.load(), {dueKey});
    await tester.tap(find.text('رجّعها'));
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('follow-up-$dueKey')), findsOneWidget);
    expect(store.load(), isEmpty);

    // "Add a visit" opens the matching form for her.
    await tester.tap(find.byKey(ValueKey('follow-up-add-$dueKey')));
    await tester.pumpAndSettle();
    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      '/family/$mona/add/visit',
    );
  });

  testWidgets('follow-up rows at large text, dark and right to left', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 12000);
    tester.view.devicePixelRatio = 3;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    final today = DateUtils.dateOnly(DateTime.now());
    final due = today.subtract(const Duration(days: 3));
    final mona = (await tester.runAsync(() async {
      final mona = await db.addProfile(
        'منى',
        birthDate: DateTime(today.year - 50, 1, 1),
        sex: 'female',
      );
      await db.addEvent(
        profileId: mona,
        type: 'visit',
        occurredAt: today.subtract(const Duration(days: 40)),
        dataJson: jsonEncode({
          'doctorName': 'د. سامي',
          'nextVisit': DateFormat('yyyy-MM-dd').format(due),
        }),
      );
      return mona;
    }))!;

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
    router.go('/family/$mona/follow-ups');
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final reason = find.text('د. سامي حدد الميعاد ده في آخر زيارة');
    final row = find.ancestor(of: reason, matching: find.byType(FollowUpTile));
    expect(Directionality.of(tester.element(row)), TextDirection.rtl);
    expect(Theme.of(tester.element(row)).brightness, Brightness.dark);
    // The record action moves under the words instead of squeezing them.
    final add = find.descendant(of: row, matching: find.byType(TextButton));
    expect(
      tester.getTopLeft(add).dy,
      greaterThan(tester.getTopLeft(reason).dy),
    );
  });
}
