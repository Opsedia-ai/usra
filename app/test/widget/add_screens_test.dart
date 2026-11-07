import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:usra/app.dart';
import 'package:usra/core/database/app_database.dart';
import 'package:usra/core/preferences.dart';
import 'package:usra/core/providers.dart';
import 'package:usra/features/add/add_sheet.dart';
import 'package:usra/features/medicines/medicines_providers.dart';

import '../support/fake_reminder_scheduler.dart';
import '../support/fits.dart';

void main() {
  late AppDatabase db;
  late MemoryKeyValueStore prefs;
  var theme = ThemeMode.light;

  setUp(() {
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    prefs = MemoryKeyValueStore({
      PrefKeys.tutorialSeen: true,
      PrefKeys.elderTutorialSeen: true,
    });
    theme = ThemeMode.light;
  });
  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
    await tester.pumpAndSettle();
  }

  Future<void> open(WidgetTester tester, String path) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          keyValueStoreProvider.overrideWithValue(prefs),
          reminderSchedulerProvider.overrideWithValue(FakeReminderScheduler()),
          themeModeProvider.overrideWith(() => _FixedTheme(theme)),
        ],
        child: const UsraApp(),
      ),
    );
    await settle(tester);
    GoRouter.of(tester.element(find.byType(Scaffold).first)).go(path);
    await settle(tester);
  }

  void tall(WidgetTester tester) {
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = const Size(780, 3000);
    addTearDown(tester.view.reset);
  }

  Finder key(String k) => find.byKey(ValueKey(k));

  Future<void> openSheet(WidgetTester tester) async {
    showAddSheet(tester.element(find.byType(Scaffold).first));
    await settle(tester);
  }

  testWidgets('offers only what has a form, each leading to it', (
    tester,
  ) async {
    tall(tester);
    await tester.runAsync(() => db.addProfile('ليلى'));
    await open(tester, '/records');
    await openSheet(tester);
    for (final path in [
      'medicines/new',
      'add/vaccine',
      'add/visit',
      'labs',
      'add/scan',
      'sick-days',
      'add/growth',
      'add/surgery',
      'insurance/new',
    ]) {
      expect(key('add-$path'), findsOneWidget, reason: path);
    }
    expect(find.byKey(const ValueKey('add-add/vitals')), findsNothing);
    expect(find.text('حساسية'), findsNothing);
    expect(find.text('مرض مزمن'), findsNothing);
    expect(find.text('ضغط وسكر'), findsNothing);

    await tester.tap(key('add-add/surgery'));
    await settle(tester);
    expect(key('field-procedure'), findsOneWidget);
  });

  testWidgets('with several people nothing opens until one is picked', (
    tester,
  ) async {
    tall(tester);
    final laila = await tester.runAsync(() => db.addProfile('ليلى'));
    await tester.runAsync(() => db.addProfile('جدو'));
    await open(tester, '/records');
    await openSheet(tester);
    expect(key('add-pick-person'), findsOneWidget);
    await tester.tap(key('add-photo'));
    await settle(tester);
    expect(key('add-photo'), findsOneWidget);

    await tester.tap(key('add-person-$laila'));
    await settle(tester);
    expect(key('add-pick-person'), findsNothing);
  });

  testWidgets('a new person starts short, and the button names them', (
    tester,
  ) async {
    tall(tester);
    await open(tester, '/family/new');
    expect(key('profile-relationship-son'), findsOneWidget);
    expect(key('profile-simple-mode'), findsNothing);
    expect(key('profile-more'), findsOneWidget);
    expect(
      tester.getTopLeft(key('profile-relationship-son')).dy,
      lessThan(tester.getTopLeft(key('profile-name')).dy),
    );

    expect(find.text('حفظ'), findsOneWidget);
    await tester.enterText(key('profile-name'), 'ليلى');
    await settle(tester);
    expect(find.text('حفظ ليلى'), findsOneWidget);

    await tester.tap(key('profile-more'));
    await settle(tester);
    await tester.tap(key('profile-simple-mode'));
    await settle(tester);
    await tester.ensureVisible(key('profile-save'));
    await settle(tester);
    await tester.tap(key('profile-save'));
    await settle(tester);
    final saved = await tester.runAsync(() => db.watchProfiles().first);
    expect(saved!.single.displayName, 'ليلى');
    expect(saved.single.simpleMode, isTrue);
  });

  testWidgets('changing a saved person shows everything already saved', (
    tester,
  ) async {
    tall(tester);
    final id = await tester.runAsync(
      () => db.addProfile('جدو', allergies: 'بنسلين'),
    );
    await open(tester, '/family/$id/edit');
    expect(find.text('بنسلين'), findsOneWidget);
    expect(key('profile-simple-mode'), findsOneWidget);
    expect(find.text('حفظ'), findsOneWidget);
  });

  group('fits a small phone at double text', () {
    for (final locale in const ['ar', 'en']) {
      for (final mode in const [ThemeMode.light, ThemeMode.dark]) {
        testWidgets('$locale, ${mode.name}', (tester) async {
          smallPhoneDoubleText(tester);
          theme = mode;
          await prefs.setString(PrefKeys.language, locale);
          await tester.runAsync(() async {
            await db.addProfile('ليلى');
            await db.addProfile('جدو');
          });
          await open(tester, '/family/new');
          await walkScreen(tester);
          await openSheet(tester);
          expect(tester.takeException(), isNull);
          expectNoTinyText(tester);
          final tile = tester.getSize(key('add-insurance/new'));
          expect(tile.height, greaterThanOrEqualTo(48));
          expect(tile.width, greaterThanOrEqualTo(48));
        });
      }
    }
  });
}

class _FixedTheme extends ThemeModeController {
  _FixedTheme(this.mode);

  final ThemeMode mode;

  @override
  ThemeMode build() => mode;
}
