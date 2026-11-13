import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usra/core/backup/recovery_key.dart';
import 'package:usra/core/design/theme.dart';
import 'package:usra/core/design/tokens.dart';
import 'package:usra/core/design/usra_mark.dart';
import 'package:usra/core/preferences.dart';
import 'package:usra/features/backup/backup_providers.dart';

import '../support/fits.dart';
import '../support/screen_harness.dart';

// Dr. Usra's house mark (brand touch, 13 Nov 2026): where it shows, where it
// never shows, and that it is decorative.
void main() {
  group('UsraMark', () {
    testWidgets('is decorative: screen readers skip it', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          theme: buildUsraTheme(),
          home: const Scaffold(body: Center(child: UsraMark())),
        ),
      );
      expect(
        find.descendant(
          of: find.byType(UsraMark),
          matching: find.byType(ExcludeSemantics),
        ),
        findsOneWidget,
      );
      final node = tester.getSemantics(find.byType(Scaffold));
      var labelled = false;
      node.visitChildren((child) {
        if (child.label.isNotEmpty) labelled = true;
        return true;
      });
      expect(labelled, isFalse);
      handle.dispose();
    });

    for (final size in [UsraMark.small, UsraMark.medium, UsraMark.large]) {
      testWidgets('draws at $size', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: buildUsraTheme(),
            home: Scaffold(
              body: Center(child: UsraMark(size: size)),
            ),
          ),
        );
        expect(tester.getSize(find.byType(UsraMark)), Size.square(size));
      });
    }

    test('the outline reaches 3:1 on bg and surface in both themes', () {
      for (final c in [UsraColors.light, UsraColors.dark]) {
        expect(contrastRatio(c.primary, c.bg), greaterThanOrEqualTo(3));
        expect(contrastRatio(c.primary, c.surface), greaterThanOrEqualTo(3));
      }
    });

    test('the heart reaches 3:1: orchid in dark, an orchid-ink edge in '
        'light and on white paper', () {
      const l = UsraColors.light;
      const d = UsraColors.dark;
      for (final bg in [l.bg, l.surface]) {
        final edge = UsraMark.heartEdgeOn(bg, l)!;
        expect(contrastRatio(edge, bg), greaterThanOrEqualTo(3));
      }
      for (final bg in [d.bg, d.surface]) {
        expect(UsraMark.heartEdgeOn(bg, d), isNull);
        expect(contrastRatio(d.orchid, bg), greaterThanOrEqualTo(3));
      }
      // The backup snack bar: ink in light, light ink in dark.
      for (final c in [l, d]) {
        final bar = c.ink;
        expect(contrastRatio(c.bg, bar), greaterThanOrEqualTo(3));
        final edge = UsraMark.heartEdgeOn(bar, c);
        expect(contrastRatio(edge ?? c.orchid, bar), greaterThanOrEqualTo(3));
      }
    });
  });

  group('shows on', () {
    late ScreenHarness h;
    setUp(
      () => h = ScreenHarness()
        ..overrides = [
          recoveryKeyStoreProvider.overrideWithValue(MemoryRecoveryKeyStore()),
        ],
    );
    tearDown(() => h.dispose());

    Future<String> person(WidgetTester tester) async =>
        (await tester.runAsync(() => h.db.addProfile('منى', sex: 'female')))!;

    final mark = find.byType(UsraMark);

    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('the Home greeting, ${mode.name}', (tester) async {
        h.theme = mode;
        await person(tester);
        await h.open(tester, '/home');
        expect(
          find.ancestor(
            of: find.byKey(const ValueKey('home-greeting')),
            matching: find.byType(UsraMarkTitle),
          ),
          findsOneWidget,
        );
      });
    }

    testWidgets('the main tab titles: Medicines, Records and More', (
      tester,
    ) async {
      await person(tester);
      await h.open(tester, '/home');
      for (final path in ['/medicines', '/records', '/settings']) {
        await h.go(tester, path);
        expect(find.byType(UsraMarkTitle), findsOneWidget, reason: path);
      }
    });

    testWidgets('Welcome, beside the app name', (tester) async {
      h.tall(tester);
      await h.prefs.setBool(PrefKeys.tutorialSeen, false);
      await h.open(tester, '/welcome');
      expect(find.byKey(const ValueKey('welcome-brand')), findsOneWidget);
      expect(
        tester
            .widget<UsraMark>(
              find.descendant(
                of: find.byKey(const ValueKey('welcome-brand')),
                matching: mark,
              ),
            )
            .size,
        UsraMark.hero,
      );
    });

    testWidgets('the consent header', (tester) async {
      await h.open(tester, '/consent');
      expect(
        find.ancestor(
          of: find.byKey(const ValueKey('consent-title')),
          matching: find.byType(UsraMarkTitle),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the About and privacy header', (tester) async {
      await h.open(tester, '/settings/about');
      expect(find.byType(UsraMarkTitle), findsOneWidget);
    });

    testWidgets('friendly empty states: family, records, medicines', (
      tester,
    ) async {
      await h.open(tester, '/family');
      expect(find.byType(UsraMarkedEmpty), findsOneWidget, reason: 'family');
      final id = await person(tester);
      await h.go(tester, '/records');
      expect(find.byType(UsraMarkedEmpty), findsOneWidget, reason: 'records');
      await h.go(tester, '/medicines');
      expect(find.byType(UsraMarkedEmpty), findsOneWidget, reason: 'today');
      await h.go(tester, '/family/$id/medicines');
      expect(find.byType(UsraMarkedEmpty), findsOneWidget, reason: 'list');
    });
  });

  // Dr. Usra never appears on emergency or warning screens, and neither
  // does his mark.
  group('never shows on', () {
    late ScreenHarness h;
    setUp(
      () => h = ScreenHarness()
        ..overrides = [
          recoveryKeyStoreProvider.overrideWithValue(MemoryRecoveryKeyStore()),
        ],
    );
    tearDown(() => h.dispose());

    testWidgets('the emergency card, sick days, delete all and recovery key', (
      tester,
    ) async {
      final id = (await tester.runAsync(
        () => h.db.addProfile('منى', sex: 'female'),
      ))!;
      for (final path in [
        '/family/$id/emergency',
        '/family/$id/sick-days',
        '/settings/delete-all',
        '/settings/backup/key',
      ]) {
        await h.open(tester, path);
        expect(find.byType(UsraMark), findsNothing, reason: path);
      }
    });

    test('the source of screens that warn or alert never uses it', () {
      const excluded = [
        'lib/features/family/emergency_card_screen.dart',
        'lib/features/sick_days',
        'lib/features/pregnancy/pregnancy_screen.dart',
        'lib/features/pregnancy/pregnancy_widgets.dart',
        'lib/features/settings/delete_data_screen.dart',
        'lib/features/settings/database_recovery.dart',
        'lib/features/settings/key_unavailable.dart',
        'lib/features/settings/wipe_restart.dart',
        'lib/features/app_lock',
        'lib/features/backup/recovery_key_screen.dart',
        'lib/features/backup/backup_notices.dart',
        'lib/features/labs',
      ];
      for (final path in excluded) {
        final files = FileSystemEntity.isDirectorySync(path)
            ? Directory(path)
                  .listSync(recursive: true)
                  .whereType<File>()
                  .where((f) => f.path.endsWith('.dart'))
            : [File(path)];
        expect(files, isNotEmpty, reason: path);
        for (final f in files) {
          expect(
            f.readAsStringSync(),
            isNot(contains('UsraMark')),
            reason: f.path,
          );
        }
      }
    });
  });

  group('screens with the mark fit 320 px at double text', () {
    late ScreenHarness h;
    setUp(() => h = ScreenHarness());
    tearDown(() => h.dispose());

    for (final path in [
      '/home',
      '/medicines',
      '/records',
      '/settings',
      '/settings/about',
      '/consent',
      '/welcome',
    ]) {
      group(path, () {
        forEachSmallLayout(() => h, (tester) async {
          await tester.runAsync(() => h.db.addProfile('منى', sex: 'female'));
          // Welcome shows only on the first run.
          if (path == '/welcome') {
            await h.prefs.setBool(PrefKeys.tutorialSeen, false);
          }
          await h.open(tester, path);
          if (path == '/welcome') {
            expect(find.byKey(const ValueKey('welcome-brand')), findsOneWidget);
          }
          await walkScreen(tester);
        });
      });
    }

    group('/family empty', () {
      forEachSmallLayout(() => h, (tester) async {
        await h.open(tester, '/family');
        await walkScreen(tester);
      });
    });
  });
}
