import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usra/features/children/child_vaccines.dart';
import 'package:usra/features/children/growth.dart';
import 'package:usra/features/medicines/medicines_providers.dart';

import '../support/fake_reminder_scheduler.dart';
import '../support/fits.dart';
import '../support/screen_harness.dart';

void main() {
  late ScreenHarness h;

  setUp(() {
    h = ScreenHarness()
      ..overrides = [
        reminderSchedulerProvider.overrideWithValue(FakeReminderScheduler()),
      ];
  });
  tearDown(() => h.dispose());

  Finder key(String k) => find.byKey(ValueKey(k));

  /// Seven months old with nothing recorded, so the early doses are overdue.
  Future<String> seed(WidgetTester tester, {int months = 7}) async =>
      (await tester.runAsync(
        () => h.db.addProfile(
          'ليلى',
          sex: 'female',
          birthDate: addMonths(DateUtils.dateOnly(DateTime.now()), -months),
        ),
      ))!;

  testWidgets('shows the bar, the schedule and its source, one card per '
      'overdue dose', (tester) async {
    h.tall(tester);
    final id = await seed(tester);
    await h.open(tester, '/family/$id/vaccines');
    expect(find.text('تطعيمات ليلى'), findsOneWidget);
    expect(key('vaccine-progress-bar'), findsOneWidget);
    expect(
      tester.widget<Text>(key('vaccine-schedule-source')).data,
      contains('جدول التطعيمات في مصر'),
    );
    expect(key('vaccine-overdue-card-bcg-1'), findsOneWidget);
    expect(find.text('اتاخدت؟ سجّلها'), findsWidgets);
    final bar = tester.widget<LinearProgressIndicator>(
      key('vaccine-progress-bar'),
    );
    expect(bar.value, 0);
  });

  testWidgets('logging an overdue dose from its card saves it and moves the '
      'bar', (tester) async {
    h.tall(tester);
    final id = await seed(tester);
    await h.open(tester, '/family/$id/vaccines');
    await h.tapKey(tester, 'vaccine-log-bcg-1');
    // Opened to log it: "given" is already on.
    expect(tester.widget<SwitchListTile>(key('dose-given')).value, isTrue);
    await h.tapKey(tester, 'dose-save');
    expect(key('vaccine-overdue-card-bcg-1'), findsNothing);
    final events = await tester.runAsync(() => h.db.watchTimeline(id).first);
    final records = vaccineRecords(events!);
    expect(records, hasLength(1));
    expect(records.single.date.day, DateTime.now().day);
    await tester.drag(find.byType(ListView).first, const Offset(0, 3000));
    await tester.pumpAndSettle();
    expect(
      tester.widget<LinearProgressIndicator>(key('vaccine-progress-bar')).value,
      greaterThan(0),
    );
  });

  testWidgets('ages already given fold into one line that opens', (
    tester,
  ) async {
    h.tall(tester);
    final id = await seed(tester, months: 1);
    await h.open(tester, '/family/$id/vaccines/setup');
    await h.tapKey(tester, 'setup-all-0');
    await h.tapKey(tester, 'vaccine-setup-save');
    expect(key('vaccine-done-group'), findsOneWidget);
    expect(key('dose-bcg-1'), findsNothing);
    await h.tapKey(tester, 'vaccine-done-group');
    expect(key('dose-bcg-1'), findsOneWidget);
    // Every other filter still lists them.
    await h.tapKey(tester, 'vaccine-done-group');
    await h.tapKey(tester, 'vaccine-filter-required');
    expect(key('dose-bcg-1'), findsOneWidget);
  });

  testWidgets('tick all covers one age only, and counts', (tester) async {
    h.tall(tester);
    final id = await seed(tester);
    await h.open(tester, '/family/$id/vaccines/setup');
    expect(key('vaccine-setup-source'), findsOneWidget);
    await h.tapKey(tester, 'setup-all-0');
    expect(tester.widget<CheckboxListTile>(key('setup-bcg-1')).value, isTrue);
    expect(
      tester.widget<CheckboxListTile>(key('setup-penta-1')).value,
      isFalse,
    );
    expect(key('setup-all-0'), findsNothing);
    expect(key('setup-all-2'), findsOneWidget);
  });

  testWidgets('the new vaccine form starts on the first dose waiting and saves '
      'it to the schedule as the family\'s own record', (tester) async {
    h.tall(tester);
    final id = await seed(tester);
    await h.open(tester, '/family/$id/vaccines');
    await h.tapKey(tester, 'vaccine-new');
    expect(find.text('تطعيم جديد'), findsWidgets);
    expect(key('field-vaccine'), findsNothing);
    await tester.enterText(key('field-place'), 'مكتب الصحة');
    await tester.enterText(key('field-note'), 'سخونية خفيفة بعدها');
    await h.tapKey(tester, 'record-save');
    final events = (await tester.runAsync(() => h.db.watchTimeline(id).first))!;
    final saved = events.singleWhere((e) => e.type == 'vaccine');
    final data = jsonDecode(saved.dataJson) as Map<String, dynamic>;
    expect(data['vaccine'], isNotEmpty);
    expect(data['dose'], isA<int>());
    expect(data['place'], 'مكتب الصحة');
    // The note goes where the schedule shows it.
    expect(data.containsKey('note'), isFalse);
    expect(vaccinePlanOf(events).notes.values, contains('سخونية خفيفة بعدها'));
    expect(data.containsKey(checklistSourceKey), isFalse);
    expect(userVaccineRecordIds(events), {saved.id});
    // It counts: that dose isn't overdue any more.
    expect(key('vaccine-progress-bar'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, 3000));
    await tester.pumpAndSettle();
    expect(
      tester.widget<LinearProgressIndicator>(key('vaccine-progress-bar')).value,
      greaterThan(0),
    );
  });

  testWidgets('another vaccine asks for its name; the person can change, and '
      'their schedule goes with them', (tester) async {
    h.tall(tester);
    final id = await seed(tester);
    final adult = (await tester.runAsync(
      () => h.db.addProfile('جدو', birthDate: DateTime(1950), sex: 'male'),
    ))!;
    await h.open(tester, '/family/$id/add/vaccine');
    await h.tapKey(tester, 'new-vaccine-other');
    expect(key('field-vaccine'), findsOneWidget);
    await tester.enterText(key('field-note'), 'ملاحظتي');
    await h.tapKey(tester, 'new-vaccine-person-$adult');
    // No schedule for him: straight to the name, what was typed still there.
    expect(key('new-vaccine-other'), findsNothing);
    expect(find.text('ملاحظتي'), findsOneWidget);
    // Nothing named: refused.
    await h.tapKey(tester, 'record-save');
    final none = (await tester.runAsync(
      () => h.db.watchTimeline(adult).first,
    ))!;
    expect(none, isEmpty);
    await tester.enterText(key('field-vaccine'), 'الإنفلونزا');
    await h.tapKey(tester, 'record-save');
    final saved = (await tester.runAsync(
      () => h.db.watchTimeline(adult).first,
    ))!;
    expect(saved.single.type, 'vaccine');
    final hers = (await tester.runAsync(() => h.db.watchTimeline(id).first))!;
    expect(hers, isEmpty);
  });

  testWidgets('never starts on a dose that isn\'t due yet', (tester) async {
    h.tall(tester);
    // Just born and already logged: the next visit is two months off.
    final id = await seed(tester, months: 0);
    await h.open(tester, '/family/$id/vaccines/setup');
    await h.tapKey(tester, 'setup-all-0');
    await h.tapKey(tester, 'vaccine-setup-save');
    await h.go(tester, '/family/$id/add/vaccine');
    expect(key('field-vaccine'), findsOneWidget);
    expect(key('new-vaccine-other'), findsOneWidget);
    expect(key('new-vaccine-penta-1'), findsOneWidget);
  });

  testWidgets('a saved vaccine can still be corrected', (tester) async {
    h.tall(tester);
    final id = await seed(tester);
    final event = (await tester.runAsync(
      () => h.db.addEvent(
        profileId: id,
        type: 'vaccine',
        occurredAt: DateTime(2026, 10, 1),
        dataJson: jsonEncode({'vaccine': 'الإنفلونزا'}),
      ),
    ))!;
    await h.open(tester, '/family/$id/record/$event');
    await h.tapKey(tester, 'record-edit');
    expect(key('field-vaccine'), findsOneWidget);
    expect(key('new-vaccine-other'), findsNothing);
  });

  group('fits 320 px at double text', () {
    forEachSmallLayout(() => h, (tester) async {
      final id = await seed(tester);
      await h.open(tester, '/family/$id/vaccines');
      await walkScreen(tester);
      await h.go(tester, '/family/$id/vaccines/setup?first=1');
      await walkScreen(tester);
      await h.go(tester, '/family/$id/add/vaccine');
      await walkScreen(tester);
    });

    testWidgets('dose sheet scrolls', (tester) async {
      smallPhoneDoubleText(tester);
      final id = await seed(tester);
      await h.open(tester, '/family/$id/vaccines');
      final log = find.text('اتاخدت؟ سجّلها');
      for (var i = 0; i < 10 && log.evaluate().isEmpty; i++) {
        await tester.drag(find.byType(ListView).first, const Offset(0, -300));
        await tester.pumpAndSettle();
      }
      await tester.ensureVisible(log.first);
      await tester.pumpAndSettle();
      await tester.tap(log.first);
      await h.settle(tester);
      expect(tester.takeException(), isNull);
      expect(key('dose-save'), findsOneWidget);
    });
  });
}
