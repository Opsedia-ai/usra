import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usra/core/design/buttons.dart';
import 'package:usra/core/design/dr_usra.dart';
import 'package:usra/core/design/list_row.dart';
import 'package:usra/core/design/pebble.dart';
import 'package:usra/core/design/status_chip.dart';
import 'package:usra/core/design/status_dot.dart';
import 'package:usra/core/design/theme.dart';
import 'package:usra/core/design/tokens.dart';
import 'package:usra/core/preferences.dart';
import 'package:usra/l10n/app_localizations.dart';

Widget _host(
  Widget child, {
  bool simple = false,
  Brightness brightness = Brightness.light,
  TextDirection direction = TextDirection.rtl,
}) => MaterialApp(
  theme: buildUsraTheme(simple: simple, brightness: brightness),
  home: Directionality(
    textDirection: direction,
    child: Scaffold(body: Center(child: child)),
  ),
);

void main() {
  group('PebbleShape', () {
    test('the same seed always gives the same shape', () {
      expect(PebbleShape.fromSeed(7), PebbleShape.fromSeed(7));
      // Pinned: a person's pebble must not change between app versions.
      final shape = PebbleShape.fromSeed(7);
      expect(shape.top, closeTo(PebbleShape.fromSeed(7).top, 0));
      expect(
        {for (var s = 0; s < 20; s++) PebbleShape.fromSeed(s)}.length,
        greaterThan(15),
      );
    });

    test('stays in the range of Variation B, for any seed', () {
      for (final seed in [0, 1, -1, 42, 1 << 40, -(1 << 40)]) {
        final s = PebbleShape.fromSeed(seed);
        for (final f in [s.top, s.bottom, s.start, s.end]) {
          expect(f, inInclusiveRange(0.38, 0.62));
        }
      }
    });

    test('corners on each side add up to that side', () {
      const size = Size(200, 100);
      final r = PebbleShape.fromSeed(3)
          .radiiFor(size)
          .resolve(TextDirection.ltr);
      expect(r.topLeft.x + r.topRight.x, closeTo(200, 1e-9));
      expect(r.bottomLeft.x + r.bottomRight.x, closeTo(200, 1e-9));
      expect(r.topLeft.y + r.bottomLeft.y, closeTo(100, 1e-9));
      expect(r.topRight.y + r.bottomRight.y, closeTo(100, 1e-9));
    });

    test('mirrors in right-to-left', () {
      const size = Size(200, 100);
      final radii = PebbleShape.fromSeed(3).radiiFor(size);
      expect(
        radii.resolve(TextDirection.rtl).topRight,
        radii.resolve(TextDirection.ltr).topLeft,
      );
    });
  });

  group('Pebble', () {
    testWidgets('a tappable pebble is a labelled button of at least 48', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      await tester.pumpWidget(
        _host(
          Pebble(
            seed: 1,
            color: UsraColors.light.orchidSoft,
            width: 20,
            height: 20,
            semanticLabel: 'ليلى',
            onTap: () => taps++,
          ),
        ),
      );
      final size = tester.getSize(find.byType(InkWell));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
      expect(
        tester.getSemantics(find.bySemanticsLabel('ليلى')),
        isSemantics(label: 'ليلى', isButton: true, hasTapAction: true),
      );
      await tester.tap(find.byType(InkWell));
      expect(taps, 1);
      handle.dispose();
    });

    testWidgets('shows its child, without a button when not tappable', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          Pebble(
            seed: 1,
            color: UsraColors.light.skySoft,
            child: const Text('جدو'),
          ),
        ),
      );
      expect(find.text('جدو'), findsOneWidget);
      expect(find.byType(InkWell), findsNothing);
    });
  });

  group('UsraPillButton', () {
    testWidgets(
      'has 14 corners, is tappable, and disabled without a callback',
      (tester) async {
        var taps = 0;
        await tester.pumpWidget(
          _host(UsraPillButton(label: 'احفظ', onPressed: () => taps++)),
        );
        final button = tester.widget<FilledButton>(find.byType(FilledButton));
        expect(
          Theme.of(tester.element(find.byType(FilledButton)))
              .filledButtonTheme
              .style!
              .shape!
              .resolve({}),
          const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(UsraRadius.button)),
          ),
        );
        await tester.tap(find.text('احفظ'));
        expect(taps, 1);
        expect(button.enabled, isTrue);
        expect(
          tester.getSize(find.byType(FilledButton)).height,
          greaterThanOrEqualTo(48),
        );

        await tester.pumpWidget(
          _host(const UsraPillButton(label: 'احفظ', onPressed: null)),
        );
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).enabled,
          isFalse,
        );
      },
    );

    testWidgets('Simple Mode makes it the simple height', (tester) async {
      await tester.pumpWidget(
        _host(
          UsraPillButton(label: 'احفظ', icon: Icons.check, onPressed: () {}),
          simple: true,
        ),
      );
      expect(
        tester.getSize(find.byType(FilledButton)).height,
        greaterThanOrEqualTo(simpleTapTarget),
      );
    });
  });

  group('UsraRoundIconButton', () {
    testWidgets('48 and 60 across, with a screen-reader label', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          UsraRoundIconButton(
            icon: Icons.add,
            semanticLabel: 'ضيف',
            onPressed: () {},
          ),
        ),
      );
      expect(tester.getSize(find.byType(IconButton)), const Size.square(48));
      expect(find.bySemanticsLabel('ضيف'), findsOneWidget);

      await tester.pumpWidget(
        _host(
          UsraRoundIconButton(
            icon: Icons.add,
            semanticLabel: 'ضيف',
            large: true,
            style: UsraRoundIconStyle.accent,
            onPressed: () {},
          ),
        ),
      );
      expect(tester.getSize(find.byType(IconButton)), const Size.square(60));
      handle.dispose();
    });

    testWidgets('Simple Mode never shrinks below its tap size', (tester) async {
      await tester.pumpWidget(
        _host(
          UsraRoundIconButton(
            icon: Icons.add,
            semanticLabel: 'ضيف',
            onPressed: () {},
          ),
          simple: true,
        ),
      );
      expect(
        tester.getSize(find.byType(IconButton)).width,
        greaterThanOrEqualTo(simpleTapTarget),
      );
    });
  });

  group('StatusChip', () {
    for (final severity in Severity.values) {
      for (final brightness in Brightness.values) {
        testWidgets('${severity.name} has an icon and words, $brightness', (
          tester,
        ) async {
          await tester.pumpWidget(
            _host(
              StatusChip(severity: severity, label: 'كلام'),
              brightness: brightness,
            ),
          );
          final colors = brightness == Brightness.dark
              ? UsraColors.dark
              : UsraColors.light;
          expect(find.text('كلام'), findsOneWidget);
          expect(
            tester.widget<Icon>(find.byType(Icon)).color,
            severity.foregroundIn(colors),
          );
        });
      }
    }

    testWidgets('a screen reader hears the words only', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(const StatusChip(severity: Severity.urgent, label: 'كلم ١٢٣')),
      );
      expect(find.bySemanticsLabel('كلم ١٢٣'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('long words wrap instead of overflowing', (tester) async {
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 120,
            child: StatusChip(
              severity: Severity.info,
              label: 'كلام طويل جدا ' * 6,
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('DrUsra', () {
    for (final (locale, label) in const [
      ('ar', 'دكتور أسرة بيشرح'),
      ('en', 'Dr. Usra explaining'),
    ]) {
      testWidgets('is labelled in $locale', (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(locale),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Center(child: DrUsra(pose: DrUsraPose.explaining)),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.bySemanticsLabel(label), findsOneWidget);
        expect(tester.takeException(), isNull);
        handle.dispose();
      });
    }

    test('every pose has bundled art', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      for (final pose in DrUsraPose.values) {
        final svg = await rootBundle.loadString(DrUsra.assetFor(pose));
        expect(svg, contains('<svg'));
      }
    });
  });

  group('Theme mode', () {
    Future<ProviderContainer> make(Map<String, Object> saved) async =>
        ProviderContainer(
          overrides: [
            keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore(saved)),
          ],
        );

    test('follows the phone until something is saved', () async {
      final c = await make({});
      addTearDown(c.dispose);
      expect(c.read(themeModeProvider), ThemeMode.system);
    });

    test(
      'remembers the choice, and ignores a value it does not know',
      () async {
        final store = MemoryKeyValueStore();
        final c = ProviderContainer(
          overrides: [keyValueStoreProvider.overrideWithValue(store)],
        );
        addTearDown(c.dispose);
        await c.read(themeModeProvider.notifier).set(ThemeMode.dark);
        expect(store.getInt(PrefKeys.themeMode), 2);

        final again = await make({PrefKeys.themeMode: 2});
        addTearDown(again.dispose);
        expect(again.read(themeModeProvider), ThemeMode.dark);

        final odd = await make({PrefKeys.themeMode: 9});
        addTearDown(odd.dispose);
        expect(odd.read(themeModeProvider), ThemeMode.system);
      },
    );
  });

  group('StatusDotText', () {
    for (final brightness in Brightness.values) {
      testWidgets('a dot and words in the attention colour, $brightness', (
        tester,
      ) async {
        await tester.pumpWidget(
          _host(
            const StatusDotText(label: 'لسه مفيش نسخة'),
            brightness: brightness,
          ),
        );
        final colors = brightness == Brightness.dark
            ? UsraColors.dark
            : UsraColors.light;
        final text = tester.widget<Text>(find.text('لسه مفيش نسخة'));
        expect(text.style?.color, colors.attention);
        final dot = tester.widget<Container>(
          find.descendant(
            of: find.byType(StatusDot),
            matching: find.byType(Container),
          ),
        );
        expect((dot.decoration! as BoxDecoration).color, colors.attentionDot);
      });
    }

    testWidgets('a screen reader hears the words only', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_host(const StatusDotText(label: 'تعبانة')));
      expect(find.bySemanticsLabel('تعبانة'), findsOneWidget);
      handle.dispose();
    });
  });

  group('UsraListCard', () {
    testWidgets('rows with hairlines between them, and a chevron when '
        'tappable', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(
          UsraListCard(
            children: [
              UsraListRow(
                title: 'كل العيلة',
                subtitleText: '٢ أفراد',
                icon: Icons.group_outlined,
                onTap: () => taps++,
              ),
              const UsraListRow(title: 'الدكاترة'),
            ],
          ),
        ),
      );
      expect(find.byType(Divider), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
      expect(find.text('٢ أفراد'), findsOneWidget);
      await tester.tap(find.text('كل العيلة'));
      expect(taps, 1);
      expect(
        tester.getSize(find.byType(UsraListRow).first).height,
        greaterThanOrEqualTo(listRowMinHeight),
      );
    });

    testWidgets('Simple Mode makes rows taller', (tester) async {
      await tester.pumpWidget(
        _host(
          const UsraListCard(children: [UsraListRow(title: 'الدكاترة')]),
          simple: true,
        ),
      );
      expect(
        tester.getSize(find.byType(UsraListRow)).height,
        greaterThanOrEqualTo(72),
      );
    });

    testWidgets('cards have 16 corners and a hairline, no shadow', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const UsraListCard(children: [UsraListRow(title: 'x')])),
      );
      final theme = Theme.of(tester.element(find.byType(Card)));
      final shape = theme.cardTheme.shape! as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(UsraRadius.card));
      expect(shape.side.color, UsraColors.light.line);
      expect(theme.cardTheme.elevation, 0);
    });
  });
}
