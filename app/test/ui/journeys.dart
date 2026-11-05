import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usra/core/util/bidi.dart';
import 'package:usra/demo/demo_family.dart';

import 'ui_harness.dart';

/// The four things a family does most, from the Home tab, tapping like a
/// person would. Shared by `journeys_test.dart` (in CI) and
/// `integration_test/journeys_test.dart` (on a simulator or phone).
/// [Journey.taps] is the most taps each may take: more means the way got
/// longer, which should be a decision, not an accident.
class Journey {
  const Journey(this.name, this.taps, this.run);

  final String name;
  final int taps;
  final Future<void> Function(JourneyDriver d) run;

  @override
  String toString() => name;
}

/// Taps and types, counting the taps.
class JourneyDriver {
  JourneyDriver(this.tester, this.family);

  final WidgetTester tester;
  final DemoFamily family;
  var taps = 0;

  Future<void> tap(Finder finder) async {
    await reveal(finder);
    await settle(tester);
    await tester.tap(finder);
    taps++;
    await settle(tester);
  }

  /// Scrolls the page until [finder] is built, then fully into view (the
  /// way a person scrolls; scrolling isn't counted as a tap).
  Future<void> reveal(Finder finder) async {
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        finder,
        300,
        scrollable: pageScrollable(),
      );
    }
    await tester.ensureVisible(finder);
  }

  /// Waits up to [max] for [finder] to show, then expects it.
  Future<void> waitFor(
    Finder finder, {
    Duration max = const Duration(seconds: 10),
  }) async {
    for (var waited = Duration.zero; waited < max; waited += _step) {
      if (finder.evaluate().isNotEmpty) break;
      // On a device pump() ignores the duration: wait in real time.
      if (tester.binding is LiveTestWidgetsFlutterBinding) {
        await Future<void>.delayed(_step);
      }
      await tester.pump(_step);
    }
    expect(
      finder,
      findsWidgets,
      reason:
          'On screen: '
          '${find.byType(Text).evaluate().map((e) => (e.widget as Text).data).whereType<String>().take(30).join(' | ')}'
          '; fields: '
          '${find.byType(EditableText).evaluate().map((e) => (e.widget as EditableText).controller.text).join(' | ')}',
    );
  }

  static const _step = Duration(milliseconds: 200);

  Future<void> tapKey(String key) => tap(find.byKey(ValueKey(key)));

  /// A bottom-bar tab by position (0 = Home).
  Future<void> tab(int index) =>
      tap(find.byType(NavigationDestination).at(index));

  Future<void> type(String key, String text) async {
    final field = find.byKey(ValueKey(key));
    await reveal(field);
    await tester.enterText(field, text);
    await settle(tester);
    expect(
      tester
          .widget<EditableText>(
            find.descendant(of: field, matching: find.byType(EditableText)),
          )
          .controller
          .text,
      text,
      reason: 'typing into $key',
    );
    // Close the keyboard, as a person does before looking for Save; on a
    // phone it slides away over a few frames Flutter doesn't drive.
    FocusManager.instance.primaryFocus?.unfocus();
    if (tester.binding is LiveTestWidgetsFlutterBinding) {
      await Future<void>.delayed(const Duration(milliseconds: 800));
    }
    await settle(tester);
  }
}

final journeys = <Journey>[
  Journey('record a vaccine', 5, (d) async {
    // Home shows children's vaccines; Youssef's 18-month doses are late.
    await d.tapKey('home-vaccines-${d.family.youssef}');
    await d.tapKey('vaccine-filter-overdue');
    final late = find.byWidgetPredicate(
      (w) =>
          w is ListTile &&
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('dose-'),
    );
    expect(late, findsWidgets);
    final key = late.evaluate().first.widget.key!;
    await d.tap(find.byKey(key));
    await d.tapKey('dose-given');
    await d.tapKey('dose-save');
    // The dose is no longer in the overdue list.
    expect(find.byKey(key), findsNothing);
  }),
  Journey('add a medicine from a prescription photo', 6, (d) async {
    await d.tab(1);
    await d.tap(find.text('يوسف').first);
    await d.tapKey('member-medicines');
    await d.tapKey('prescription-add');
    await d.tapKey('rx-photo-camera');
    await d.type('rx-item-0-name', 'Panadol 120 mg/5 ml');
    await d.type('rx-item-0-dose', '5 مل كل 6 ساعات');
    await d.tapKey('rx-save');
    // Saving seals the photo first; on a phone that takes a moment.
    await d.waitFor(find.textContaining('Panadol'));
  }),
  Journey('find the emergency card', 1, (d) async {
    await d.tapKey('home-emergency-${d.family.fatma}');
    expect(find.byKey(const ValueKey('emergency-blood')), findsOneWidget);
    expect(find.text(ltr('A+')), findsOneWidget);
    expect(find.text('بنسلين'), findsOneWidget);
  }),
  Journey('mark a dose taken', 2, (d) async {
    await d.tab(2);
    final taken = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('dose-taken-'),
    );
    expect(taken, findsWidgets);
    final id = (taken.evaluate().first.widget.key! as ValueKey<String>).value
        .substring('dose-taken-'.length);
    await d.tap(taken.first);
    // Marked: the dose now offers Undo instead.
    expect(find.byKey(ValueKey('dose-undo-$id')), findsOneWidget);
  }),
];

/// Opens Home with the demo family and runs [journey], checking its taps.
Future<int> runJourney(
  WidgetTester tester,
  Journey journey, {
  Size? size = phoneSize,
  DateTime? now,
}) async {
  final family = await pumpDemoScreen(
    tester,
    UiScreen('home', (_) => '/home'),
    size: size,
    now: now,
  );
  final driver = JourneyDriver(tester, family);
  await journey.run(driver);
  expect(
    driver.taps,
    lessThanOrEqualTo(journey.taps),
    reason: '"$journey" now takes ${driver.taps} taps',
  );
  return driver.taps;
}
