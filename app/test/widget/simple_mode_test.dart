import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:usra/core/design/bottom_bar.dart';
import 'package:usra/app.dart';
import 'package:usra/core/database/app_database.dart';
import 'package:usra/core/preferences.dart';
import 'package:usra/core/providers.dart';

void main() {
  late AppDatabase db;
  late MemoryKeyValueStore store;

  setUp(() {
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    store = MemoryKeyValueStore();
  });
  tearDown(() => db.close());

  // A new scope each time is like opening the app again.
  Widget app() => ProviderScope(
    key: UniqueKey(),
    overrides: [
      databaseProvider.overrideWithValue(db),
      keyValueStoreProvider.overrideWithValue(store),
    ],
    child: const UsraApp(),
  );

  Finder tabs() => find.byType(NavigationDestination);
  Finder regularBar() => find.byType(UsraBottomBar);

  // Simple Home's More link is below the big buttons.
  Future<void> openMoreFromSimpleHome(WidgetTester tester) async {
    final link = find.byKey(const ValueKey('simple-settings'));
    await tester.scrollUntilVisible(
      link,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    // scrollUntilVisible stops once it's partly in view; bring it all in.
    await tester.ensureVisible(link);
    await tester.pumpAndSettle();
    await tester.tap(link);
    await tester.pumpAndSettle();
  }

  Future<void> finishTour(WidgetTester tester) async {
    while (find.text('يلا نبدأ').evaluate().isEmpty) {
      await tester.tap(find.byKey(const ValueKey('tutorial-next')));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byKey(const ValueKey('tutorial-next')));
    await tester.pumpAndSettle();
    // The first-run tour ends with the offer to lock the app.
    if (find.byKey(const ValueKey('app-lock-offer')).evaluate().isNotEmpty) {
      final skip = find.byKey(const ValueKey('app-lock-offer-skip'));
      await tester.ensureVisible(skip);
      await tester.pumpAndSettle();
      await tester.tap(skip);
      await tester.pumpAndSettle();
    }
  }

  testWidgets('the tour shows on first run only, and reopens from More', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('أهلاً، أنا دكتور أسرة'), findsOneWidget);
    expect(find.text('١ من ٥'), findsNothing);
    expect(find.text('1 من 5'), findsOneWidget);
    expect(tabs(), findsNothing);

    // A stray back press doesn't skip the first-run tour for good.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('1 من 5'), findsOneWidget);
    await finishTour(tester);

    expect(find.text('أهلاً! أنا دكتور أسرة'), findsOneWidget);
    expect(store.getBool(PrefKeys.tutorialSeen), isTrue);
    expect(store.getBool(PrefKeys.appLockOffered), isTrue);

    // Opening the app again goes straight Home.
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('أهلاً! أنا دكتور أسرة'), findsOneWidget);
    expect(find.byKey(const ValueKey('tutorial-step')), findsNothing);

    // Reopened from More, skipped, and back on More.
    await tester.tap(find.text('المزيد').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('settings-tutorial')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings-tutorial')));
    await tester.pumpAndSettle();
    expect(find.text('1 من 5'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('tutorial-skip')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('settings-simple-mode')), findsOneWidget);
  });

  testWidgets('Simple Mode: three tabs, bigger text, big Home buttons', (
    tester,
  ) async {
    store = MemoryKeyValueStore({PrefKeys.tutorialSeen: true});
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(regularBar(), findsOneWidget);
    expect(tabs(), findsNothing);
    double scale() =>
        MediaQuery.textScalerOf(tester.element(find.byType(Scaffold).first))
            .scale(10) /
        10;
    expect(scale(), 1.0);

    await tester.tap(find.text('المزيد').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings-simple-mode')));
    await tester.pumpAndSettle();

    // The short elder tour comes first, once.
    expect(find.text('1 من 3'), findsOneWidget);
    await finishTour(tester);
    expect(store.getBool(PrefKeys.elderTutorialSeen), isTrue);
    expect(store.getBool(PrefKeys.simpleMode), isTrue);

    expect(tabs(), findsNWidgets(3));
    expect(find.text('اتصال'), findsOneWidget);
    expect(find.text('الفلوس'), findsNothing);
    expect(scale(), closeTo(1.3, 0.001));

    // Home is four big buttons.
    await tester.tap(find.text('الرئيسية'));
    await tester.pumpAndSettle();
    for (final key in [
      'simple-medicines',
      'simple-call-doctor',
      'simple-family',
      'simple-emergency',
    ]) {
      final button = find.byKey(ValueKey(key));
      expect(button, findsOneWidget);
      expect(tester.getSize(button).height, greaterThanOrEqualTo(56));
    }
    await tester.tap(find.byKey(const ValueKey('simple-call-doctor')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('doctor-add')), findsOneWidget);

    // Opening the app again keeps Simple Mode, without the tour.
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(tabs(), findsNWidgets(3));
    expect(find.byKey(const ValueKey('simple-greeting')), findsOneWidget);

    // Turning it off brings everything back.
    await openMoreFromSimpleHome(tester);
    await tester.tap(find.byKey(const ValueKey('settings-simple-mode')));
    await tester.pumpAndSettle();
    expect(regularBar(), findsOneWidget);
    expect(tabs(), findsNothing);
    expect(scale(), 1.0);
  });

  testWidgets('a person marked for Simple Mode is greeted by name', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 3000);
    tester.view.devicePixelRatio = 1.5;
    addTearDown(tester.view.reset);
    store = MemoryKeyValueStore({
      PrefKeys.tutorialSeen: true,
      PrefKeys.elderTutorialSeen: true,
    });
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('home-add-first')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('profile-name')), 'فاطمة');
    await tester.tap(find.byKey(const ValueKey('profile-simple-mode')));
    await tester.tap(find.byKey(const ValueKey('profile-save')));
    await tester.pumpAndSettle();
    final saved = (await tester.runAsync(() => db.watchProfiles().first))!;
    expect(saved.single.simpleMode, isTrue);

    // Simple Mode on this phone: no spending link, a named greeting.
    final fatma = saved.single.id;
    await tester.ensureVisible(find.byKey(const ValueKey('member-spending')));
    expect(find.byKey(const ValueKey('member-spending')), findsOneWidget);
    final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
    router.go('/settings');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings-simple-mode')));
    await tester.pumpAndSettle();
    router.go('/family/$fatma');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('member-spending')), findsNothing);
    await tester.tap(find.text('الرئيسية'));
    await tester.pumpAndSettle();
    expect(find.text('أهلاً يا فاطمة'), findsOneWidget);

    // Her emergency card is one tap away, even with others in the family.
    await tester.runAsync(() => db.addProfile('عمر'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('simple-emergency')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('emergency-blood')), findsOneWidget);
    expect(find.text('فاطمة'), findsWidgets);
  });

  testWidgets('with several people and none marked, Emergency asks whose', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 3000);
    tester.view.devicePixelRatio = 1.5;
    addTearDown(tester.view.reset);
    store = MemoryKeyValueStore({
      PrefKeys.simpleMode: true,
      PrefKeys.elderTutorialSeen: true,
    });
    final omar = (await tester.runAsync(() async {
      await db.addProfile('فاطمة');
      return db.addProfile('عمر');
    }))!;
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('أهلاً بيك!'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('simple-emergency')));
    await tester.pumpAndSettle();
    expect(find.text('كارت الطوارئ بتاع مين؟'), findsOneWidget);
    await tester.tap(find.byKey(ValueKey('simple-emergency-$omar')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('emergency-blood')), findsOneWidget);
  });

  testWidgets('Simple Mode screens fit with 2× phone text', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    store = MemoryKeyValueStore({PrefKeys.simpleMode: true});
    await tester.runAsync(() => db.addProfile('فاطمة', simpleMode: true));
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    // The elder tour, every page.
    expect(find.text('1 من 3'), findsOneWidget);
    expect(
      MediaQuery.textScalerOf(
        tester.element(find.byKey(const ValueKey('tutorial-step'))),
      ).scale(10),
      closeTo(26, 0.01),
    );
    await finishTour(tester);
    expect(tester.takeException(), isNull);

    // Home, Family and More.
    expect(find.byKey(const ValueKey('simple-greeting')), findsOneWidget);
    await tester.tap(find.text('العيلة').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('اتصال').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('الرئيسية').last);
    await tester.pumpAndSettle();
    await openMoreFromSimpleHome(tester);
    expect(find.byKey(const ValueKey('settings-simple-mode')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a phone with text above 2.6× keeps its own size', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    store = MemoryKeyValueStore({
      PrefKeys.simpleMode: true,
      PrefKeys.elderTutorialSeen: true,
    });
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(
      MediaQuery.textScalerOf(
        tester.element(find.byKey(const ValueKey('simple-greeting'))),
      ).scale(10),
      closeTo(30, 0.01),
    );
  });
}
