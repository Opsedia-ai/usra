import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:usra/app.dart';
import 'package:usra/core/database/app_database.dart';
import 'package:usra/core/files/photo_store.dart';
import 'package:usra/core/preferences.dart';
import 'package:usra/core/providers.dart';

import '../support/fits.dart';
import '../support/sync_photo_store.dart';

void main() {
  late AppDatabase db;
  late Directory dir;
  late SyncPhotoStore photos;
  late MemoryKeyValueStore prefs;
  var theme = ThemeMode.light;

  setUp(() {
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    dir = Directory.systemTemp.createTempSync('usra_records_screen');
    photos = SyncPhotoStore(
      Directory('${dir.path}/support'),
      PhotoStore.attachmentsFolder,
    );
    prefs = MemoryKeyValueStore({
      PrefKeys.tutorialSeen: true,
      PrefKeys.elderTutorialSeen: true,
    });
    theme = ThemeMode.light;
  });
  tearDown(() async {
    await db.close();
    dir.deleteSync(recursive: true);
  });

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
          attachmentStoreProvider.overrideWithValue(photos),
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
    tester.view.physicalSize = const Size(780, 4000);
    addTearDown(tester.view.reset);
  }

  /// Two people; a visit in October, a scan in September, a visit for her.
  Future<(String, String, String, String)> seed(WidgetTester tester) async =>
      (await tester.runAsync(() async {
        final laila = await db.addProfile('ليلى');
        final grandpa = await db.addProfile('جدو');
        final visit = await db.addEvent(
          profileId: laila,
          type: 'visit',
          occurredAt: DateTime(2026, 10, 20),
          dataJson: jsonEncode({
            'doctorName': 'سارة',
            'reason': 'كشف دوري',
            'hidden': 'keep me',
          }),
          costMinor: 40000,
        );
        final scan = await db.addEvent(
          profileId: grandpa,
          type: 'scan',
          occurredAt: DateTime(2026, 9, 12),
          dataJson: jsonEncode({'center': 'البرج'}),
        );
        return (laila, grandpa, visit, scan);
      }))!;

  Finder key(String k) => find.byKey(ValueKey(k));

  testWidgets('filters by person and type, each with "All", under months', (
    tester,
  ) async {
    tall(tester);
    final (laila, grandpa, visit, scan) = await seed(tester);
    await open(tester, '/records');
    expect(key('event-$visit'), findsOneWidget);
    expect(key('event-$scan'), findsOneWidget);
    expect(find.text('سجل جديد'), findsOneWidget);
    expect(key('records-month-0'), findsOneWidget);
    expect(key('records-month-1'), findsOneWidget);

    await tester.tap(key('records-type-visit'));
    await settle(tester);
    expect(key('event-$visit'), findsOneWidget);
    expect(key('event-$scan'), findsNothing);

    await tester.tap(key('records-type-all'));
    await settle(tester);
    await tester.tap(key('records-filter-$grandpa'));
    await settle(tester);
    expect(key('event-$visit'), findsNothing);
    expect(key('event-$scan'), findsOneWidget);
    // He has one type only, so there's nothing to filter by.
    expect(key('records-type-all'), findsNothing);

    await tester.tap(key('records-filter-all'));
    await settle(tester);
    expect(key('event-$visit'), findsOneWidget);
    expect(laila, isNotEmpty);
  });

  testWidgets('a type the chosen person lacks falls back to everything', (
    tester,
  ) async {
    tall(tester);
    final (_, grandpa, visit, scan) = await seed(tester);
    await open(tester, '/records');
    await tester.tap(key('records-type-visit'));
    await settle(tester);
    expect(key('event-$scan'), findsNothing);
    await tester.tap(key('records-filter-$grandpa'));
    await settle(tester);
    expect(key('event-$visit'), findsNothing);
    expect(key('event-$scan'), findsOneWidget);
  });

  testWidgets('a record with a photo shows it as a thumbnail', (tester) async {
    tall(tester);
    final (laila, _, visit, _) = await seed(tester);
    final path = await tester.runAsync(() async {
      final picked = File('${dir.path}/picked.jpg')..writeAsBytesSync([1]);
      final stored = await photos.import(picked.path);
      await db.addAttachments(visit, [stored]);
      return stored;
    });
    final first = await tester.runAsync(() => db.watchFirstPhotos(laila).first);
    expect(first, {visit: path});
    await open(tester, '/records');
    expect(key('event-thumb-$visit'), findsOneWidget);
    expect(key('event-photos-$visit'), findsOneWidget);
  });

  testWidgets('correcting a record keeps its person and anything the form '
      'doesn\'t show', (tester) async {
    tall(tester);
    final (laila, _, visit, _) = await seed(tester);
    await open(tester, '/records');
    await tester.tap(key('event-$visit'));
    await settle(tester);
    expect(find.textContaining('ليلى'), findsWidgets);
    // No way to move a record to someone else, and no way to do it by saving.
    expect(find.textContaining('فرد تاني'), findsNothing);

    await tester.tap(key('record-edit'));
    await settle(tester);
    expect(
      tester.widget<TextFormField>(key('field-reason')).controller!.text,
      'كشف دوري',
    );
    await tester.enterText(key('field-reason'), 'متابعة');
    await tester.ensureVisible(find.byType(FilledButton).last);
    await settle(tester);
    await tester.tap(find.byType(FilledButton).last);
    await settle(tester);

    final saved = await tester.runAsync(() => db.watchEvent(visit).first);
    expect(saved!.profileId, laila);
    expect(saved.costMinor, 40000);
    expect(saved.occurredAt, DateTime(2026, 10, 20));
    final data = jsonDecode(saved.dataJson) as Map<String, dynamic>;
    expect(data['reason'], 'متابعة');
    expect(data['doctorName'], 'سارة');
    expect(data['hidden'], 'keep me');
    // Back on the record, showing the correction.
    expect(key('record-delete'), findsOneWidget);
    expect(find.text('متابعة'), findsOneWidget);
  });

  testWidgets('a record can be deleted after confirming', (tester) async {
    tall(tester);
    final (_, _, visit, _) = await seed(tester);
    await open(tester, '/records');
    await tester.tap(key('event-$visit'));
    await settle(tester);
    await tester.ensureVisible(key('record-delete'));
    await settle(tester);
    await tester.tap(key('record-delete'));
    await settle(tester);
    await tester.tap(key('record-delete-confirm'));
    await settle(tester);
    expect(await tester.runAsync(() => db.watchEvent(visit).first), isNull);
  });

  group('fits a small phone at double text', () {
    for (final locale in const ['ar', 'en']) {
      for (final mode in const [ThemeMode.light, ThemeMode.dark]) {
        testWidgets('$locale, ${mode.name}', (tester) async {
          smallPhoneDoubleText(tester);
          theme = mode;
          await prefs.setString(PrefKeys.language, locale);
          final (laila, _, visit, _) = await seed(tester);
          await open(tester, '/records');
          await walkScreen(tester);
          GoRouter.of(tester.element(find.byType(Scaffold).first))
              .go('/family/$laila/record/$visit');
          await settle(tester);
          await walkScreen(tester);
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
