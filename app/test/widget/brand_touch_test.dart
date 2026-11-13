import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usra/core/design/list_row.dart';
import 'package:usra/core/design/pebble.dart';
import 'package:usra/core/design/pill_chip.dart';
import 'package:usra/core/design/tokens.dart';
import 'package:usra/features/children/growth.dart' show addMonths;

import '../support/fits.dart';
import '../support/screen_harness.dart';

// The brand touch of 13 Nov 2026: warm background, orchid + button with a
// ring in light, and the selected tab on a soft pill.
void main() {
  late ScreenHarness h;

  setUp(() => h = ScreenHarness());
  tearDown(() => h.dispose());

  Finder inAdd(Finder f) => find.descendant(
    of: find.byKey(const ValueKey('tab-action-/add')),
    matching: f,
  );

  Future<void> seed(WidgetTester tester) async {
    await tester.runAsync(() => h.db.addProfile('منى', sex: 'female'));
  }

  ShapeDecoration? pillOf(WidgetTester tester, String path) {
    final box = tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.byKey(ValueKey('tab-$path')),
        matching: find.byType(AnimatedContainer),
      ),
    );
    return box.decoration as ShapeDecoration?;
  }

  for (final (mode, colors) in [
    (ThemeMode.light, UsraColors.light),
    (ThemeMode.dark, UsraColors.dark),
  ]) {
    testWidgets('${mode.name}: the + button is orchid with an on-orchid icon', (
      tester,
    ) async {
      h.theme = mode;
      await seed(tester);
      await h.open(tester, '/home');
      final circle =
          tester
                  .widget<Container>(inAdd(find.byType(Container)).first)
                  .decoration!
              as ShapeDecoration;
      expect(circle.color, colors.orchid);
      final side = (circle.shape as CircleBorder).side;
      if (mode == ThemeMode.light) {
        // Orchid on the white bar is 2.71:1; the ring gives the circle 3:1.
        expect(side.color, colors.orchidInk);
        expect(side.width, 1);
      } else {
        expect(side, BorderSide.none);
      }
      final icon = tester.widget<Icon>(inAdd(find.byIcon(Icons.add)));
      expect(icon.color, colors.onOrchid);
    });

    testWidgets('${mode.name}: the selected tab sits on the soft pill', (
      tester,
    ) async {
      h.theme = mode;
      await seed(tester);
      await h.open(tester, '/home');
      expect(pillOf(tester, '/home')!.color, colors.primarySoft);
      expect(pillOf(tester, '/settings')?.color, isNull);
      final page = tester.element(find.byType(Scaffold).first);
      expect(Theme.of(page).scaffoldBackgroundColor, colors.bg);
    });
  }

  group('Home with the new bar fits 320 px at double text', () {
    forEachSmallLayout(() => h, (tester) async {
      await seed(tester);
      await h.open(tester, '/home');
      await walkScreen(tester);
    });
  });

  // Section tints and the person's colour on their page.
  group('person page', () {
    Future<String> daughter(
      WidgetTester tester, {
      String sex = 'female',
    }) async => (await tester.runAsync(
      () => h.db.addProfile(
        'جميلة',
        sex: sex,
        relationship: sex == 'female' ? 'daughter' : 'son',
        birthDate: addMonths(DateUtils.dateOnly(DateTime.now()), -24),
      ),
    ))!;

    IconBox boxOf(WidgetTester tester, String row) => tester.widget<IconBox>(
      find.descendant(
        of: find.byKey(ValueKey(row)),
        matching: find.byType(IconBox),
      ),
    );

    for (final (mode, colors) in [
      (ThemeMode.light, UsraColors.light),
      (ThemeMode.dark, UsraColors.dark),
    ]) {
      testWidgets('${mode.name}: orchid avatar, orchid-ink relation word', (
        tester,
      ) async {
        h.theme = mode;
        h.tall(tester);
        final id = await daughter(tester);
        await h.open(tester, '/family/$id');
        final avatar = tester.widget<Pebble>(find.byType(Pebble).first);
        expect(avatar.color, colors.orchid);
        final details = tester.widget<Text>(
          find.byKey(const ValueKey('member-details')),
        );
        final relation = details.textSpan!.toPlainText();
        expect(relation, contains('بنتك'));
        final spans = (details.textSpan! as TextSpan).children!
            .cast<TextSpan>();
        expect(
          spans.firstWhere((t) => t.text == 'بنتك').style!.color,
          colors.orchidInk,
        );
        // The main action stays the navy filled button.
        expect(find.byType(FilledButton), findsWidgets);
      });

      testWidgets('${mode.name}: vaccines orchid, medicines sky, the rest '
          'neutral, sick days never tinted', (tester) async {
        h.theme = mode;
        h.tall(tester);
        final id = await daughter(tester);
        await h.open(tester, '/family/$id');
        expect(boxOf(tester, 'member-vaccines').tint, IconTint.vaccines);
        expect(boxOf(tester, 'member-medicines').tint, IconTint.medicines);
        for (final row in [
          'member-growth',
          'member-visits',
          'member-insurance',
          'member-sick-days',
          'member-documents',
        ]) {
          expect(boxOf(tester, row).tint, IconTint.neutral, reason: row);
          expect(boxOf(tester, row).color, isNull, reason: row);
        }
        expect(IconTint.vaccines.fillIn(colors), colors.orchidSoft);
        expect(IconTint.medicines.inkIn(colors), colors.skyInk);
      });
    }

    testWidgets('a son: sky avatar and sky-ink relation word', (tester) async {
      h.tall(tester);
      final id = await daughter(tester, sex: 'male');
      await h.open(tester, '/family/$id');
      expect(
        tester.widget<Pebble>(find.byType(Pebble).first).color,
        UsraColors.light.sky,
      );
      final spans =
          (tester
                      .widget<Text>(
                        find.byKey(const ValueKey('member-details')),
                      )
                      .textSpan!
                  as TextSpan)
              .children!
              .cast<TextSpan>();
      expect(
        spans.firstWhere((t) => t.text == 'ابنك').style!.color,
        UsraColors.light.skyInk,
      );
    });

    testWidgets('Home: the vaccines card box is orchid', (tester) async {
      h.tall(tester);
      final id = await daughter(tester);
      await h.open(tester, '/home');
      final box = find.descendant(
        of: find.byKey(ValueKey('home-vaccines-$id')),
        matching: find.byType(IconBox),
      );
      expect(tester.widget<IconBox>(box).tint, IconTint.vaccines);
    });

    testWidgets('Home: "new person" is an orchid-ink outlined link', (
      tester,
    ) async {
      await daughter(tester);
      await h.open(tester, '/home');
      final button = tester.widget<OutlinedButton>(
        find.byKey(const ValueKey('home-new-person')),
      );
      expect(
        button.style!.foregroundColor!.resolve({}),
        UsraColors.light.orchidInk,
      );
    });

    group('fits 320 px at double text', () {
      forEachSmallLayout(() => h, (tester) async {
        final id = await daughter(tester);
        await h.open(tester, '/family/$id');
        await walkScreen(tester);
      });
    });
  });

  // End-to-end findings 8 and 25.
  group('large text and filters', () {
    for (final locale in ['ar', 'en']) {
      testWidgets('$locale: tab labels stay whole at 320 px and double text', (
        tester,
      ) async {
        smallPhoneDoubleText(tester);
        await h.prefs.setString('language', locale);
        await seed(tester);
        await h.open(tester, '/home');
        for (final key in [
          'tab-/home',
          'tab-/medicines',
          'tab-action-/add',
          'tab-/records',
          'tab-/settings',
        ]) {
          final slot = find.byKey(ValueKey(key));
          final label = find.descendant(of: slot, matching: find.byType(Text));
          final text = tester.widget<Text>(label);
          // Grows to 1.3 at most, then shrinks to fit: never cut.
          expect(text.textScaler!.scale(10), closeTo(13, 0.01), reason: key);
          final paragraph = tester.renderObject<RenderParagraph>(
            find.descendant(of: label, matching: find.byType(RichText)),
          );
          expect(paragraph.didExceedMaxLines, isFalse, reason: key);
          final shown = tester.getRect(label);
          final room = tester.getRect(slot);
          expect(shown.left, greaterThanOrEqualTo(room.left - 0.5));
          expect(shown.right, lessThanOrEqualTo(room.right + 0.5));
        }
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Records: the selected filter is a soft pill', (tester) async {
      await tester.runAsync(() async {
        await h.db.addProfile('منى', sex: 'female');
        await h.db.addProfile('جميلة', sex: 'female');
      });
      await h.open(tester, '/records');
      final pill = tester.widget<UsraPill>(
        find.byKey(const ValueKey('records-filter-all')),
      );
      expect(pill.selected, isTrue);
      expect(pill.soft, isTrue);
      final material = tester.widget<Material>(
        find.descendant(
          of: find.byKey(const ValueKey('records-filter-all')),
          matching: find.byType(Material),
        ),
      );
      expect(material.color, UsraColors.light.primarySoft);
    });
  });
}
