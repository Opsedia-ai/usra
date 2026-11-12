import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usra/core/design/status_chip.dart';
import 'package:usra/features/children/child_vaccines.dart';
import 'package:usra/features/children/egypt_vaccines.dart';
import 'package:usra/features/follow_ups/follow_ups_providers.dart';
import 'package:usra/features/medicines/medicines_providers.dart';

import '../support/fake_reminder_scheduler.dart';
import '../support/screen_harness.dart';

/// The founder's report of 12 Nov 2026: Gamila, a girl born 12 Nov 2024, is
/// two today. Every date below is worked out by hand from the MoHP schedule
/// (birth, 2, 4, 6, 9, 12 and 18 months), not from the app's own code.
final today = DateTime(2026, 11, 12, 10);
final birth = DateTime(2024, 11, 12);

DateTime d(int y, int m, int day) => DateTime(y, m, day);

/// The day each required dose falls due on the schedule.
final scheduleDay = {
  'hepB-0': d(2024, 11, 12),
  'bcg-1': d(2024, 11, 12),
  'opv-0': d(2024, 11, 12),
  'opv-1': d(2025, 1, 12),
  'ipv-1': d(2025, 1, 12),
  'penta-1': d(2025, 1, 12),
  'opv-2': d(2025, 3, 12),
  'ipv-2': d(2025, 3, 12),
  'penta-2': d(2025, 3, 12),
  'opv-3': d(2025, 5, 12),
  'ipv-3': d(2025, 5, 12),
  'penta-3': d(2025, 5, 12),
  'opv-4': d(2025, 8, 12),
  'opv-5': d(2025, 11, 12),
  'mmr-1': d(2025, 11, 12),
  'opv-6': d(2026, 5, 12),
  'mmr-2': d(2026, 5, 12),
  'dtp-1': d(2026, 5, 12),
};

void main() {
  late ScreenHarness h;

  setUp(() {
    h = ScreenHarness()
      ..overrides = [
        reminderSchedulerProvider.overrideWithValue(FakeReminderScheduler()),
        todayProvider.overrideWithValue(today),
        clockProvider.overrideWithValue(() => today),
      ];
  });
  tearDown(() => h.dispose());

  Finder key(String k) => find.byKey(ValueKey(k));

  // Every dose of every past age on one page, so nothing is left unbuilt.
  void veryTall(WidgetTester tester) {
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = const Size(780, 24000);
    addTearDown(tester.view.reset);
  }

  Future<String> seed(WidgetTester tester) async => (await tester.runAsync(
    () => h.db.addProfile('جميلة', sex: 'female', birthDate: birth),
  ))!;

  Future<Map<String, DateTime>> given(WidgetTester tester, String id) async {
    final events = (await tester.runAsync(() => h.db.watchTimeline(id).first))!;
    final records = vaccineRecords(events);
    final statuses = matchSchedule(
      birthDate: birth,
      records: records,
      now: today,
    );
    return {
      for (final s in statuses)
        if (s.givenOn != null)
          s.dose.key: DateTime(
            s.givenOn!.year,
            s.givenOn!.month,
            s.givenOn!.day,
          ),
    };
  }

  String text(WidgetTester tester, String k) =>
      tester.widget<Text>(key(k)).data!;

  group('no vaccines recorded', () {
    test('the doses after a missing one are catch-up, planned on their '
        'schedule day', () {
      final s = {
        for (final x in matchSchedule(
          birthDate: birth,
          records: const [],
          now: today,
        ))
          x.dose.key: x,
      };
      // Overdue: birth, 2 months and MMR 1 (no interval before it).
      final overdue = [
        for (final x in s.values)
          if (x.open && x.state == DoseState.overdue) x.dose.key,
      ];
      expect(overdue, [
        'hepB-0', 'bcg-1', 'opv-0', //
        'opv-1', 'ipv-1', 'penta-1', 'mmr-1',
      ]);
      // OPV 2, IPV 2, Penta 2: 28 days after dose 1 given today. MMR 2: 28
      // days after MMR 1. The catch-up plan, not "at 4 months".
      for (final k in ['opv-2', 'ipv-2', 'penta-2', 'mmr-2']) {
        expect(s[k]!.dueOn, d(2026, 12, 10), reason: k);
        expect(s[k]!.catchUp, isTrue, reason: k);
      }
      for (final e in scheduleDay.entries) {
        expect(s[e.key]!.plannedOn, e.value, reason: e.key);
      }
    });

    test('a baby on time is never catch-up', () {
      final baby = matchSchedule(
        birthDate: DateTime(2026, 9, 12),
        records: const [],
        now: today,
      );
      final opv2 = baby.firstWhere((x) => x.dose.key == 'opv-2');
      expect(opv2.dueOn, d(2027, 1, 12));
      expect(opv2.catchUp, isFalse);
    });

    testWidgets('next visit says catch-up, and the checklist offers every '
        'past age', (tester) async {
      veryTall(tester);
      final id = await seed(tester);
      await h.open(tester, '/family/$id/vaccines');
      final next = text(tester, 'vaccine-next-doses');
      expect(next, startsWith('جرعات تعويضية'));
      expect(next, isNot(contains('عند ٤ شهور')));
      expect(next, isNot(contains('عند 4 شهور')));
      expect(key('vaccine-overdue-card-hepB-0'), findsOneWidget);
      await h.go(tester, '/family/$id/vaccines/setup');
      for (final age in [0, 2, 4, 6, 9, 12, 18]) {
        expect(key('setup-group-$age'), findsOneWidget, reason: '$age');
      }
      for (final k in scheduleDay.keys) {
        expect(key('setup-$k'), findsOneWidget, reason: k);
      }
    });
  });

  testWidgets('birth and 2 months ticked without dates: dated on the '
      'schedule, the rest overdue or catch-up', (tester) async {
    veryTall(tester);
    final id = await seed(tester);
    await h.open(tester, '/family/$id/vaccines/setup');
    await h.tapKey(tester, 'setup-all-0');
    await h.tapKey(tester, 'setup-all-2');
    await h.tapKey(tester, 'vaccine-setup-save');
    final dates = await given(tester, id);
    expect(dates, {
      for (final k in [
        'hepB-0', 'bcg-1', 'opv-0', 'opv-1', 'ipv-1', 'penta-1', //
      ])
        k: scheduleDay[k]!,
    });
    // 4 months: due 12 Mar 2025, so overdue now; never "in 28 days".
    // Three cards show; the rest open from the count under them.
    expect(key('vaccine-overdue-card-opv-2'), findsOneWidget);
    expect(key('vaccine-overdue-card-penta-2'), findsOneWidget);
    expect(text(tester, 'vaccine-next-doses'), startsWith('جرعات تعويضية'));
    expect(text(tester, 'vaccine-progress-line'), contains('٦ من ١٨'));
  });

  testWidgets('everything up to 18 months ticked with "tick all": all on '
      'their schedule days, nothing left', (tester) async {
    veryTall(tester);
    final id = await seed(tester);
    await h.open(tester, '/family/$id/vaccines/setup');
    for (final age in [0, 2, 4, 6, 9, 12, 18]) {
      await h.tapKey(tester, 'setup-all-$age');
    }
    await h.tapKey(tester, 'vaccine-setup-save');
    expect(await given(tester, id), scheduleDay);
    expect(text(tester, 'vaccine-progress-line'), contains('١٨ من ١٨'));
    expect(
      find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith(
              'vaccine-overdue-card-',
            ),
      ),
      findsNothing,
    );
    expect(find.text('كل التطعيمات اللي في الخطة اتاخدت'), findsOneWidget);
  });

  testWidgets('logged one by one from the overdue cards: each on its '
      'schedule day, never today', (tester) async {
    veryTall(tester);
    final id = await seed(tester);
    await h.open(tester, '/family/$id/vaccines');
    final card = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('vaccine-log-'),
    );
    for (var i = 0; i < 30 && card.evaluate().isNotEmpty; i++) {
      final k = (tester.widget(card.first).key! as ValueKey<String>).value;
      await h.tapKey(tester, k);
      // Opened to log it: on, dated on the schedule, and saying so.
      expect(find.textContaining('ده ميعادها على الجدول'), findsOneWidget);
      await h.tapKey(tester, 'dose-save');
    }
    final dates = await given(tester, id);
    expect(dates, scheduleDay);
    expect(dates.values.where((v) => v == d(2026, 11, 12)), isEmpty);
  });

  testWidgets('a dose ticked without a date never comes before the one '
      'before it, dated later in the same checklist', (tester) async {
    veryTall(tester);
    final id = await seed(tester);
    await h.open(tester, '/family/$id/vaccines/setup');
    await h.tapKey(tester, 'setup-penta-1');
    await h.tapKey(tester, 'setup-date-penta-1');
    Navigator.of(tester.element(find.byType(DatePickerDialog)))
        .pop(d(2025, 6, 1));
    await h.settle(tester);
    await h.tapKey(tester, 'setup-penta-2');
    await h.tapKey(tester, 'setup-penta-3');
    await h.tapKey(tester, 'vaccine-setup-save');
    final dates = await given(tester, id);
    expect(dates['penta-1'], d(2025, 6, 1));
    // 28 days apart at least, not their schedule days (March and May).
    expect(dates['penta-2'], d(2025, 6, 29));
    expect(dates['penta-3'], d(2025, 7, 27));
  });

  testWidgets('the founder\'s records, already dated today: catch-up, not '
      '"at 4 months"', (tester) async {
    veryTall(tester);
    final id = await seed(tester);
    final now = DateTime(2026, 11, 12, 12);
    for (final (name, dose) in [
      ('BCG', 1),
      ('Hep B', 0),
      ('OPV', 0),
      ('OPV', 1),
      ('IPV', 1),
      ('Penta', 1),
      ('MMR', 1),
    ]) {
      await tester.runAsync(
        () => h.db.addEvent(
          profileId: id,
          type: 'vaccine',
          occurredAt: now,
          dataJson: '{"vaccine":"$name","dose":$dose}',
        ),
      );
    }
    await h.open(tester, '/family/$id/vaccines');
    expect(text(tester, 'vaccine-progress-line'), contains('٧ من ١٨'));
    final next = text(tester, 'vaccine-next-doses');
    expect(next, startsWith('جرعات تعويضية'));
    expect(next, contains('الثلاثي الفيروسي (MMR)، جرعة ٢'));
  });

  group('optional vaccines (bug B)', () {
    String chip(WidgetTester tester, String key) => tester
        .widget<StatusChip>(find.byKey(ValueKey('dose-state-$key')))
        .label;

    testWidgets('always listed with their dates and state, marked optional, '
        'never counted or on a card', (tester) async {
      veryTall(tester);
      final id = await seed(tester);
      await h.open(tester, '/family/$id/vaccines');
      // PCV at 2 months: due 12 Jan 2025, not followed.
      expect(chip(tester, 'pcv-1'), startsWith('اختياري · كان ميعادها'));
      expect(chip(tester, 'pcv-1'), contains('٢٠٢٥'));
      // A 2-year-old starting PCV needs one dose: the rest aren't needed.
      expect(chip(tester, 'pcv-2'), 'اختياري · مش محتاجها في السن ده');
      // Rotavirus is past its upper age.
      expect(chip(tester, 'rota-1'), startsWith('اختياري · فات السن المسموح'));
      expect(chip(tester, 'varicella-1'), startsWith('اختياري ·'));
      // Its second dose's date assumes the first is given today: catch-up.
      expect(chip(tester, 'varicella-2'), startsWith('اختياري · جرعة تعويضية'));
      expect(find.text('مش في خطتك'), findsNothing);
      expect(key('vaccine-overdue-card-pcv-1'), findsNothing);
      expect(text(tester, 'vaccine-progress-line'), contains('٠ من ١٨'));
    });

    testWidgets('can be recorded, dated on its schedule day', (tester) async {
      veryTall(tester);
      final id = await seed(tester);
      await h.open(tester, '/family/$id/vaccines');
      await h.tapKey(tester, 'dose-pcv-1');
      await h.tapKey(tester, 'dose-given');
      await h.tapKey(tester, 'dose-save');
      expect((await given(tester, id))['pcv-1'], d(2025, 1, 12));
      expect(chip(tester, 'pcv-1'), startsWith('اتاخد'));
    });

    test('reminded only when the family follows it', () {
      final none = matchSchedule(
        birthDate: DateTime(2026, 9, 12),
        records: const [],
        now: today,
      );
      final pcv = matchSchedule(
        birthDate: DateTime(2026, 9, 12),
        records: const [],
        now: today,
        plan: const VaccinePlan(optional: {VaccineKind.pcv}),
      );
      bool openPcv(List<DoseStatus> s) =>
          s.any((x) => x.dose.kind == VaccineKind.pcv && x.open);
      expect(openPcv(none), isFalse);
      expect(openPcv(pcv), isTrue);
    });
  });

  testWidgets('the dose sheet\'s switch says given or not given (bug C)', (
    tester,
  ) async {
    veryTall(tester);
    final id = await seed(tester);
    await h.open(tester, '/family/$id/vaccines');
    await h.tapKey(tester, 'dose-pcv-1');
    String title() =>
        (tester.widget<SwitchListTile>(key('dose-given')).title! as Text).data!;
    expect(tester.widget<SwitchListTile>(key('dose-given')).value, isFalse);
    expect(title(), 'ماتاخدتش');
    await h.tapKey(tester, 'dose-given');
    expect(tester.widget<SwitchListTile>(key('dose-given')).value, isTrue);
    expect(title(), 'اتاخدت');
    await h.tapKey(tester, 'dose-given');
    expect(title(), 'ماتاخدتش');
  });
}
