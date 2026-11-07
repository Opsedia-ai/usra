import 'dart:io';

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:usra/app.dart';
import 'package:usra/core/database/app_database.dart';
import 'package:usra/core/files/photo_store.dart';
import 'package:usra/core/preferences.dart';
import 'package:usra/core/providers.dart';

import 'fits.dart';
import 'sync_photo_store.dart';

/// The whole app over an in-memory database, opened on one page.
class ScreenHarness {
  ScreenHarness()
    : db = AppDatabase(
        DatabaseConnection(
          NativeDatabase.memory(),
          closeStreamsSynchronously: true,
        ),
      ),
      prefs = MemoryKeyValueStore({
        PrefKeys.tutorialSeen: true,
        PrefKeys.elderTutorialSeen: true,
      }),
      dir = Directory.systemTemp.createTempSync('usra_screen') {
    photos = SyncPhotoStore(
      Directory('${dir.path}/support'),
      PhotoStore.attachmentsFolder,
    );
  }

  final AppDatabase db;
  final MemoryKeyValueStore prefs;
  final Directory dir;
  late final SyncPhotoStore photos;
  ThemeMode theme = ThemeMode.light;

  /// Extra provider overrides for a screen's own fakes.
  List<Override> overrides = const [];

  Future<void> dispose() async {
    await db.close();
    dir.deleteSync(recursive: true);
  }

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
          ...overrides,
        ],
        child: const UsraApp(),
      ),
    );
    await settle(tester);
    await go(tester, path);
  }

  Future<void> go(WidgetTester tester, String path) async {
    GoRouter.of(tester.element(find.byType(Scaffold).first)).go(path);
    await settle(tester);
  }

  /// Tall enough that a page's tests don't depend on scrolling.
  void tall(WidgetTester tester) {
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = const Size(780, 6000);
    addTearDown(tester.view.reset);
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    final f = find.byKey(ValueKey(key));
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await settle(tester);
  }
}

/// [body] at 320 px wide and double text, in Arabic and English, light and
/// dark. It seeds and opens a page, then calls [walkScreen].
void forEachSmallLayout(
  ScreenHarness Function() harness,
  Future<void> Function(WidgetTester tester) body,
) {
  for (final locale in const ['ar', 'en']) {
    for (final mode in const [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('$locale, ${mode.name}', (tester) async {
        smallPhoneDoubleText(tester);
        final h = harness()..theme = mode;
        await h.prefs.setString(PrefKeys.language, locale);
        await body(tester);
      });
    }
  }
}

class _FixedTheme extends ThemeModeController {
  _FixedTheme(this.mode);

  final ThemeMode mode;

  @override
  ThemeMode build() => mode;
}
