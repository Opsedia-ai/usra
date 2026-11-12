import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usra/features/children/child_screen.dart'
    show growthAxisFontSize, lastGrowthChart;
import 'package:usra/features/children/growth.dart';

import '../support/fits.dart';
import '../support/screen_harness.dart';

void main() {
  late ScreenHarness h;

  setUp(() => h = ScreenHarness());
  tearDown(() => h.dispose());

  Finder key(String k) => find.byKey(ValueKey(k));

  /// A girl of seven months with two measurements, both ordinary for her age.
  Future<(String, String)> seed(WidgetTester tester) async {
    return (await tester.runAsync(() async {
      final today = DateUtils.dateOnly(DateTime.now());
      final id = await h.db.addProfile(
        'ليلى',
        sex: 'female',
        birthDate: addMonths(today, -7),
      );
      await h.db.addEvent(
        profileId: id,
        type: 'growth',
        occurredAt: today.subtract(const Duration(days: 60)),
        dataJson: jsonEncode({'weightKg': 6.5, 'heightCm': 63, 'headCm': 40.5}),
      );
      final latest = await h.db.addEvent(
        profileId: id,
        type: 'growth',
        occurredAt: today,
        dataJson: jsonEncode({'weightKg': 7.6, 'heightCm': 67}),
      );
      return (id, latest);
    }))!;
  }

  testWidgets('says "within the reference range" with its source, never a '
      'verdict', (tester) async {
    h.tall(tester);
    final (id, _) = await seed(tester);
    await h.open(tester, '/family/$id/growth');
    expect(find.text('نمو ليلى'), findsOneWidget);
    expect(
      find.descendant(
        of: key('growth-status-weight'),
        matching: find.textContaining('جوه المعدل المرجعي'),
      ),
      findsOneWidget,
    );
    expect(
      tester.widget<Text>(key('growth-source')).data,
      contains('منظمة الصحة العالمية'),
    );
    expect(find.textContaining('ماشي كويس'), findsNothing);
    expect(find.textContaining('المدى المعتاد للسن'), findsNothing);
  });

  testWidgets('each percentile label sits on its own curve (G)', (
    tester,
  ) async {
    h.tall(tester);
    // A 2-year-old girl's weight: her chart runs to 24 months, where the
    // curves are close together.
    final id = (await tester.runAsync(() async {
      final today = DateUtils.dateOnly(DateTime.now());
      final id = await h.db.addProfile(
        'جميلة',
        sex: 'female',
        birthDate: addMonths(today, -24),
      );
      await h.db.addEvent(
        profileId: id,
        type: 'growth',
        occurredAt: today,
        dataJson: jsonEncode({'weightKg': 12.0}),
      );
      return id;
    }))!;
    lastGrowthChart = null;
    await h.open(tester, '/family/$id/growth');
    final chart = lastGrowthChart!;
    expect([for (final l in chart.labels) l.percentile], [3, 50, 97]);
    for (final l in chart.labels) {
      // Centred on its curve's end...
      expect(
        l.label.center.dy,
        closeTo(l.curveY, 1),
        reason: '${l.percentile}',
      );
      // ...and nearer its own curve than any other.
      final nearest = chart.curveEnds.reduce(
        (a, b) => (a - l.label.center.dy).abs() <= (b - l.label.center.dy).abs()
            ? a
            : b,
      );
      expect(nearest, l.curveY, reason: '${l.percentile}');
      // Left of the curve's end, inside the chart.
      expect(l.label.left, greaterThan(0));
    }
  });

  testWidgets('a value far outside says so and points to the doctor', (
    tester,
  ) async {
    h.tall(tester);
    final (id, _) = await seed(tester);
    await tester.runAsync(
      () => h.db.addEvent(
        profileId: id,
        type: 'growth',
        occurredAt: DateUtils.dateOnly(DateTime.now()),
        dataJson: jsonEncode({'weightKg': 3.0}),
      ),
    );
    await h.open(tester, '/family/$id/growth');
    expect(
      find.descendant(
        of: key('growth-status-weight'),
        matching: find.textContaining('اتكلم مع دكتور الأطفال'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('opens on a measure outside the range and marks its tab', (
    tester,
  ) async {
    h.tall(tester);
    final (id, _) = await seed(tester);
    await tester.runAsync(
      () => h.db.addEvent(
        profileId: id,
        type: 'growth',
        occurredAt: DateUtils.dateOnly(DateTime.now()),
        dataJson: jsonEncode({'headCm': 60.0}),
      ),
    );
    await h.open(tester, '/family/$id/growth');
    expect(key('growth-card-head'), findsOneWidget);
    expect(
      find.descendant(
        of: key('growth-tab-head'),
        matching: find.byIcon(Icons.warning_amber_rounded),
      ),
      findsOneWidget,
    );
    await h.tapKey(tester, 'growth-tab-weight');
    expect(key('growth-card-weight'), findsOneWidget);
  });

  testWidgets('a new measurement comes back to Growth', (tester) async {
    h.tall(tester);
    final (id, _) = await seed(tester);
    await h.open(tester, '/family/$id/growth');
    await h.tapKey(tester, 'growth-add');
    await tester.enterText(key('field-weightKg'), '7.7');
    await h.tapKey(tester, 'record-save');
    expect(key('growth-history'), findsOneWidget);
  });

  testWidgets('an impossible value asks first, and can be fixed (H)', (
    tester,
  ) async {
    h.tall(tester);
    final (id, _) = await seed(tester);
    await h.open(tester, '/family/$id/growth');
    await h.tapKey(tester, 'growth-add');
    // 896 cm for a 7-month-old: a typing mistake for 89.6? Even that is
    // far off; 67 is ordinary.
    await tester.enterText(key('field-heightCm'), '896');
    await h.tapKey(tester, 'record-save');
    expect(key('growth-implausible'), findsOneWidget);
    expect(find.textContaining('٨٩٦'), findsWidgets);
    await h.tapKey(tester, 'growth-implausible-fix');
    // Back in the form, nothing saved.
    expect(key('field-heightCm'), findsOneWidget);
    final events = (await tester.runAsync(() => h.db.watchTimeline(id).first))!;
    expect(events.where((e) => e.type == 'growth'), hasLength(2));
    await tester.enterText(key('field-heightCm'), '68');
    await h.tapKey(tester, 'record-save');
    expect(key('growth-implausible'), findsNothing);
    expect(key('growth-history'), findsOneWidget);
  });

  testWidgets('a saved impossible value keeps the axis readable (H)', (
    tester,
  ) async {
    h.tall(tester);
    final (id, _) = await seed(tester);
    await tester.runAsync(
      () => h.db.addEvent(
        profileId: id,
        type: 'growth',
        occurredAt: DateUtils.dateOnly(DateTime.now()),
        dataJson: jsonEncode({'heightCm': 896}),
      ),
    );
    await h.open(tester, '/family/$id/growth');
    await h.tapKey(tester, 'growth-tab-height');
    expect(tester.takeException(), isNull);
  });

  test('WHO implausible-value flags, by hand', () {
    // A 24-month-old girl: median weight about 11.5 kg, height 86.4 cm,
    // head 47.2 cm.
    bool odd(GrowthIndicator i, double v) =>
        implausibleGrowth(i, male: false, months: 24, value: v);
    expect(odd(GrowthIndicator.weight, 12), isFalse);
    expect(odd(GrowthIndicator.weight, 120), isTrue);
    expect(odd(GrowthIndicator.height, 86), isFalse);
    expect(odd(GrowthIndicator.height, 896), isTrue);
    expect(odd(GrowthIndicator.height, 8.6), isTrue);
    expect(odd(GrowthIndicator.head, 47), isFalse);
    expect(odd(GrowthIndicator.head, 4.7), isTrue);
  });

  testWidgets('no sex recorded: measurements still listed', (tester) async {
    h.tall(tester);
    final id = (await tester.runAsync(() async {
      final id = await h.db.addProfile(
        'سما',
        birthDate: addMonths(DateUtils.dateOnly(DateTime.now()), -7),
      );
      await h.db.addEvent(
        profileId: id,
        type: 'growth',
        occurredAt: DateUtils.dateOnly(DateTime.now()),
        dataJson: jsonEncode({'weightKg': 7.6}),
      );
      return id;
    }))!;
    await h.open(tester, '/family/$id/growth');
    expect(key('growth-card-weight'), findsNothing);
    expect(key('growth-history'), findsOneWidget);
    expect(find.textContaining('٧٫٦ كجم'), findsOneWidget);
  });

  testWidgets('one measure at a time, and every measurement in the history', (
    tester,
  ) async {
    h.tall(tester);
    final (id, latest) = await seed(tester);
    await h.open(tester, '/family/$id/growth');
    expect(key('growth-card-weight'), findsOneWidget);
    expect(key('growth-card-head'), findsNothing);
    await h.tapKey(tester, 'growth-tab-head');
    expect(key('growth-card-head'), findsOneWidget);
    expect(key('growth-card-weight'), findsNothing);
    expect(key('growth-head-note'), findsOneWidget);

    expect(key('growth-history-$latest'), findsOneWidget);
    expect(
      find.descendant(
        of: key('growth-history'),
        matching: find.byType(InkWell),
      ),
      findsNWidgets(2),
    );
    expect(find.textContaining('٤٠٫٥ سم'), findsWidgets);
    await h.tapKey(tester, 'growth-history-$latest');
    expect(key('record-edit'), findsOneWidget);
  });

  testWidgets('the check before saving stays, and axis text is 14 or more', (
    tester,
  ) async {
    expect(growthAxisFontSize, greaterThanOrEqualTo(14));
    h.tall(tester);
    final (id, _) = await seed(tester);
    await h.open(tester, '/family/$id/growth');
    expect(key('growth-check'), findsOneWidget);
    expect(key('growth-add'), findsOneWidget);
    await tester.enterText(key('check-weight'), '7.5');
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: key('check-status-weight'),
        matching: find.textContaining('جوه المعدل المرجعي'),
      ),
      findsOneWidget,
    );
  });

  group('fits 320 px at double text', () {
    forEachSmallLayout(() => h, (tester) async {
      final (id, _) = await seed(tester);
      await h.open(tester, '/family/$id/growth');
      await walkScreen(tester);
    });
  });
}
