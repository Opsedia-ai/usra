import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usra/core/design/pill_chip.dart';
import 'package:usra/features/children/child_vaccines.dart';
import 'package:usra/features/children/egypt_vaccines.dart';
import 'package:usra/features/follow_ups/follow_ups_providers.dart';
import 'package:usra/features/medicines/medicines_providers.dart';
import 'package:usra/l10n/app_localizations.dart';

import '../support/fake_reminder_scheduler.dart';
import '../support/fits.dart';
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

  String scanTitle(WidgetTester tester) =>
      lookupAppLocalizations(const Locale('ar')).vaccineScanTitle;

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
        .widget<Text>(
          find.descendant(
            of: find.byKey(ValueKey('dose-state-$key')),
            matching: find.byType(Text),
          ),
        )
        .data!;

    testWidgets('always listed with their dates and state, marked optional, '
        'never counted or on a card', (tester) async {
      veryTall(tester);
      final id = await seed(tester);
      await h.open(tester, '/family/$id/vaccines');
      // PCV at 2 months: due 12 Jan 2025, not followed.
      expect(chip(tester, 'pcv-1'), startsWith('اختياري – كان ميعادها'));
      expect(chip(tester, 'pcv-1'), contains('٢٠٢٥'));
      // A 2-year-old starting PCV needs one dose: the rest aren't needed.
      expect(chip(tester, 'pcv-2'), 'اختياري – مش محتاجها في السن ده');
      // Rotavirus is past its upper age.
      expect(chip(tester, 'rota-1'), startsWith('اختياري – فات السن المسموح'));
      expect(chip(tester, 'varicella-1'), startsWith('اختياري –'));
      // Its second dose's date assumes the first is given today: catch-up.
      expect(chip(tester, 'varicella-2'), startsWith('اختياري – جرعة تعويضية'));
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

  group('mark everything due so far (D, founder 13 Nov)', () {
    String body(WidgetTester tester) => text(tester, 'vaccine-mark-past-body');

    /// The optional doses a girl of exactly two would have had on time,
    /// worked out by hand from the usual private schedule
    /// ([egyptOptionalDoses]): PCV 2, 4, 6 and 12 months; rotavirus 2 and 4
    /// months; flu 6 and 7 months; varicella 12 and 15; hepatitis A 12
    /// and 18; meningococcal 12.
    final optionalDay = {
      'pcv-1': d(2025, 1, 12),
      'pcv-2': d(2025, 3, 12),
      'pcv-3': d(2025, 5, 12),
      'pcv-4': d(2025, 11, 12),
      'rota-1': d(2025, 1, 12),
      'rota-2': d(2025, 3, 12),
      'flu-1': d(2025, 5, 12),
      'flu-2': d(2025, 6, 12),
      'varicella-1': d(2025, 11, 12),
      'varicella-2': d(2026, 2, 12),
      'hepA-1': d(2025, 11, 12),
      'hepA-2': d(2026, 5, 12),
      'mening-1': d(2025, 11, 12),
    };

    Future<VaccinePlan> planOf(WidgetTester tester, String id) async =>
        vaccinePlanOf(
          (await tester.runAsync(() => h.db.watchTimeline(id).first))!,
        );

    test('a 2-year-old girl: every required and optional dose due by 24 '
        'months, on its day, nothing in the future', () {
      final l = lookupAppLocalizations(const Locale('ar'));
      final doses = dosesDueSoFar(
        birthDate: birth,
        records: const [],
        plan: VaccinePlan.standard,
        today: today,
        nameOf: (k) => vaccineName(l, k),
      );
      expect(
        {for (final x in doses) x.dose.key: x.date},
        {...scheduleDay, ...optionalDay},
      );
      for (final x in doses) {
        expect(x.date.isAfter(today), isFalse, reason: x.dose.key);
      }
    });

    test('a dose already recorded stays; the ones after it go by her age', () {
      final l = lookupAppLocalizations(const Locale('ar'));
      final doses = dosesDueSoFar(
        birthDate: birth,
        records: [(id: 'x', name: 'Pentavalent', dose: 1, date: d(2025, 3, 1))],
        plan: VaccinePlan.standard,
        today: today,
        nameOf: (k) => vaccineName(l, k),
      );
      final byKey = {for (final x in doses) x.dose.key: x.date};
      expect(byKey.containsKey('penta-1'), isFalse);
      expect(byKey['penta-2'], scheduleDay['penta-2']);
    });

    test('doses ticked by hand today don\'t push the rest past today '
        '(founder, 13 Nov 2026)', () {
      final l = lookupAppLocalizations(const Locale('ar'));
      // Ticked by hand, so dated today: OPV 1-3 and MMR 1.
      final doses = dosesDueSoFar(
        birthDate: birth,
        records: [
          for (var n = 1; n <= 3; n++)
            (id: 'o$n', name: 'OPV', dose: n, date: today),
          (id: 'm1', name: 'MMR', dose: 1, date: today),
        ],
        plan: VaccinePlan.standard,
        today: today,
        nameOf: (k) => vaccineName(l, k),
      );
      final byKey = {for (final x in doses) x.dose.key: x.date};
      for (final k in ['opv-1', 'opv-2', 'opv-3', 'mmr-1']) {
        expect(byKey.containsKey(k), isFalse, reason: k);
      }
      // Every other required dose by two: on its own day, except that a
      // later OPV or MMR dose is never dated before the ones ticked today.
      for (final e in scheduleDay.entries) {
        if (['opv-1', 'opv-2', 'opv-3', 'mmr-1'].contains(e.key)) continue;
        final later = ['opv-4', 'opv-5', 'opv-6', 'mmr-2'].contains(e.key);
        expect(
          byKey[e.key],
          later ? DateUtils.dateOnly(today) : e.value,
          reason: e.key,
        );
      }
    });

    test('a 3-month-old: rotavirus within its age, nothing due later', () {
      final l = lookupAppLocalizations(const Locale('ar'));
      final doses = dosesDueSoFar(
        birthDate: d(2026, 8, 12),
        records: const [],
        plan: VaccinePlan.standard,
        today: today,
        nameOf: (k) => vaccineName(l, k),
      );
      expect(
        {for (final x in doses) x.dose.key},
        {
          'hepB-0', 'bcg-1', 'opv-0', //
          'opv-1', 'ipv-1', 'penta-1', 'pcv-1', 'rota-1',
        },
      );
    });

    testWidgets('a 2-year-old girl: from the vaccine page, her age, 18 '
        'required and 13 optional ticked, the optional vaccines added to '
        'her plan, then all undone', (tester) async {
      veryTall(tester);
      final id = await seed(tester);
      await h.open(tester, '/family/$id/vaccines');
      expect(find.text('خدت كل اللي فات؟ علّمها مرة واحدة'), findsOneWidget);
      await h.tapKey(tester, 'vaccine-mark-past');
      expect(text(tester, 'vaccine-mark-past-age'), 'عندها سنتين دلوقتي.');
      expect(body(tester), contains('١٨ جرعة إجبارية لحد السن ده'));
      expect(body(tester), contains('مش النهارده'));
      expect(
        text(tester, 'vaccine-mark-past-safety'),
        contains('الكارت ودكتور الطفل هما المرجع'),
      );
      expect(
        text(tester, 'vaccine-mark-past-optional-title'),
        contains('(١٣ جرعة)'),
      );
      expect(
        text(tester, 'vaccine-mark-past-optional-hint'),
        'الاختيارية هي التطعيمات الخاصة اللي بفلوس. شيل العلامة لو '
        'ماخدتهاش.',
      );
      // Ticked to start with.
      expect(
        tester
            .widget<CheckboxListTile>(key('vaccine-mark-past-optional'))
            .value,
        isTrue,
      );
      await h.tapKey(tester, 'vaccine-mark-past-ok');
      expect(await given(tester, id), {...scheduleDay, ...optionalDay});
      expect(find.text('اتعلّم على ٣١ جرعة'), findsOneWidget);
      expect((await planOf(tester, id)).optional, optionalVaccines.toSet());
      await tester.tap(find.text('تراجع'));
      await h.settle(tester);
      expect(await given(tester, id), isEmpty);
      expect(await planOf(tester, id), VaccinePlan.standard);
      // No plan record left behind: there wasn't one before.
      final plans = (await tester.runAsync(
        () => h.db.eventsOfTypes({VaccinePlanFields.type}),
      ))!;
      expect(plans.where((e) => e.profileId == id), isEmpty);
    });

    testWidgets('unticking the optional ones marks the required only and '
        'leaves the plan as it was', (tester) async {
      veryTall(tester);
      final id = await seed(tester);
      await h.open(tester, '/family/$id/vaccines');
      await h.tapKey(tester, 'vaccine-mark-past');
      await h.tapKey(tester, 'vaccine-mark-past-optional');
      expect(
        tester
            .widget<CheckboxListTile>(key('vaccine-mark-past-optional'))
            .value,
        isFalse,
      );
      await h.tapKey(tester, 'vaccine-mark-past-ok');
      expect(await given(tester, id), scheduleDay);
      expect(find.text('اتعلّم على ١٨ جرعة'), findsOneWidget);
      expect(await planOf(tester, id), VaccinePlan.standard);
    });

    testWidgets('optional vaccines not in the plan are added; undo puts back '
        'the plan the family had', (tester) async {
      veryTall(tester);
      final id = await seed(tester);
      const chosen = VaccinePlan(
        route: VaccineRoute.government,
        optional: {VaccineKind.pcv},
        notes: {'pcv-1': 'عند دكتور العيلة'},
      );
      await tester.runAsync(
        () => h.db.saveSingletonEvent(
          profileId: id,
          type: VaccinePlanFields.type,
          dataJson: chosen.toJson(),
        ),
      );
      await h.open(tester, '/family/$id/vaccines');
      await h.tapKey(tester, 'vaccine-mark-past');
      await h.tapKey(tester, 'vaccine-mark-past-ok');
      final after = await planOf(tester, id);
      expect(after.optional, optionalVaccines.toSet());
      expect(after.notes, chosen.notes);
      expect(after.route, chosen.route);
      await tester.tap(find.text('تراجع'));
      await h.settle(tester);
      expect(await planOf(tester, id), chosen);
      expect(await given(tester, id), isEmpty);
    });

    testWidgets('cancelled: nothing saved', (tester) async {
      veryTall(tester);
      final id = await seed(tester);
      await h.open(tester, '/family/$id/vaccines');
      await h.tapKey(tester, 'vaccine-mark-past');
      await tester.tap(find.text('إلغاء'));
      await h.settle(tester);
      expect(await given(tester, id), isEmpty);
      expect(await planOf(tester, id), VaccinePlan.standard);
    });

    testWidgets('a 7-month-old: never a dose not due yet', (tester) async {
      veryTall(tester);
      final born = DateTime(2026, 4, 12);
      final id = (await tester.runAsync(
        () => h.db.addProfile('ليلى', sex: 'female', birthDate: born),
      ))!;
      await h.open(tester, '/family/$id/vaccines');
      await h.tapKey(tester, 'vaccine-mark-past');
      expect(text(tester, 'vaccine-mark-past-age'), 'عندها ٧ شهور دلوقتي.');
      // Birth, 2, 4 and 6 months: 12 doses. OPV 4 at 9 months isn't due.
      expect(body(tester), contains('١٢ جرعة إجبارية'));
      await h.tapKey(tester, 'vaccine-mark-past-ok');
      final dates = await given(tester, id);
      expect(dates['penta-3'], d(2026, 10, 12));
      expect(dates.containsKey('opv-4'), isFalse);
      // PCV 1-3, rotavirus 1-2 and flu 1 (6 months); flu 2 at 7 months is
      // 12 Nov, today.
      expect(
        {
          for (final k in dates.keys)
            if (!scheduleDay.containsKey(k)) k,
        },
        {'pcv-1', 'pcv-2', 'pcv-3', 'rota-1', 'rota-2', 'flu-1', 'flu-2'},
      );
      for (final date in dates.values) {
        expect(date.isAfter(today), isFalse);
      }
    });

    testWidgets('a boy: the label and the hint say him', (tester) async {
      veryTall(tester);
      final id = (await tester.runAsync(
        () => h.db.addProfile('عمر', sex: 'male', birthDate: birth),
      ))!;
      await h.open(tester, '/family/$id/vaccines');
      expect(find.text('خد كل اللي فات؟ علّمها مرة واحدة'), findsOneWidget);
      await h.tapKey(tester, 'vaccine-mark-past');
      expect(text(tester, 'vaccine-mark-past-age'), 'عنده سنتين دلوقتي.');
      expect(
        text(tester, 'vaccine-mark-past-optional-hint'),
        endsWith('ماخدهاش.'),
      );
    });

    testWidgets('one dose left is enough to show the button; none, and it '
        'goes', (tester) async {
      veryTall(tester);
      final id = await seed(tester);
      final l = lookupAppLocalizations(const Locale('ar'));
      final all = dosesDueSoFar(
        birthDate: birth,
        records: const [],
        plan: VaccinePlan.standard,
        today: today,
        nameOf: (k) => vaccineName(l, k),
      );
      // Everything but meningococcal recorded.
      await tester.runAsync(
        () => h.db.replaceEvents(
          profileId: id,
          add: [
            for (final x in all)
              if (x.dose.key != 'mening-1') vaccineRecordFor(l, x.dose, x.date),
          ],
        ),
      );
      await h.open(tester, '/family/$id/vaccines');
      await h.tapKey(tester, 'vaccine-mark-past');
      expect(body(tester), contains('مفيش جرعات إجبارية فاضلة'));
      expect(
        text(tester, 'vaccine-mark-past-optional-title'),
        contains('(جرعة واحدة)'),
      );
      // Unticked, there's nothing left to mark.
      await h.tapKey(tester, 'vaccine-mark-past-optional');
      expect(
        tester.widget<FilledButton>(key('vaccine-mark-past-ok')).onPressed,
        isNull,
      );
      await h.tapKey(tester, 'vaccine-mark-past-optional');
      await h.tapKey(tester, 'vaccine-mark-past-ok');
      expect((await given(tester, id))['mening-1'], d(2025, 11, 12));
      expect(key('vaccine-mark-past'), findsNothing);
    });

    testWidgets('from the setup checklist: ticked on the schedule with the '
        'optional ones, the ticks and plan undone, then saved on Save', (
      tester,
    ) async {
      veryTall(tester);
      final id = await seed(tester);
      await h.open(tester, '/family/$id/vaccines/setup');
      expect(find.text('خدت كل اللي فات؟ علّمها مرة واحدة'), findsOneWidget);
      await h.tapKey(tester, 'setup-mark-past');
      expect(body(tester), contains('١٨ جرعة إجبارية'));
      await h.tapKey(tester, 'vaccine-mark-past-ok');
      expect(tester.widget<CheckboxListTile>(key('setup-dtp-1')).value, isTrue);
      expect(tester.widget<CheckboxListTile>(key('setup-pcv-4')).value, isTrue);
      expect(
        tester.widget<UsraPill>(key('vaccine-optional-pcv')).selected,
        isTrue,
      );
      // Undo puts the ticks and the plan back as they were.
      await tester.tap(find.text('تراجع'));
      await h.settle(tester);
      expect(
        tester.widget<CheckboxListTile>(key('setup-dtp-1')).value,
        isFalse,
      );
      expect(key('setup-pcv-4'), findsNothing);
      expect(
        tester.widget<UsraPill>(key('vaccine-optional-pcv')).selected,
        isFalse,
      );
      await h.tapKey(tester, 'setup-mark-past');
      await h.tapKey(tester, 'vaccine-mark-past-ok');
      await h.tapKey(tester, 'vaccine-setup-save');
      expect(await given(tester, id), {...scheduleDay, ...optionalDay});
      expect((await planOf(tester, id)).optional, optionalVaccines.toSet());
    });

    testWidgets('the founder\'s case: doses ticked by hand in setup, and '
        'the button stays on both screens while any dose due is open', (
      tester,
    ) async {
      veryTall(tester);
      final id = await seed(tester);
      await h.open(tester, '/family/$id/vaccines/setup');
      // Birth and 2 months ticked by hand: 12 required left.
      await h.tapKey(tester, 'setup-all-0');
      await h.tapKey(tester, 'setup-all-2');
      expect(key('setup-mark-past'), findsOneWidget);
      // Outlined, at the top of "given", above the scan card.
      expect(
        find.ancestor(
          of: find.text('خدت كل اللي فات؟ علّمها مرة واحدة'),
          matching: find.byType(OutlinedButton),
        ),
        findsOneWidget,
      );
      expect(
        tester.getTopLeft(key('setup-mark-past')).dy,
        lessThan(tester.getTopLeft(find.text(scanTitle(tester))).dy),
      );
      await h.tapKey(tester, 'setup-mark-past');
      expect(body(tester), contains('١٢ جرعة إجبارية'));
      await tester.tap(find.text('إلغاء'));
      await h.settle(tester);
      // Every required age ticked by hand: only optional ones are left, and
      // the button still shows.
      for (final age in [4, 6, 9, 12, 18]) {
        await h.tapKey(tester, 'setup-all-$age');
      }
      expect(key('setup-mark-past'), findsOneWidget);
      await h.tapKey(tester, 'vaccine-setup-save');
      expect(await given(tester, id), scheduleDay);
      // On the vaccine page too: one dose due so far is enough.
      expect(key('vaccine-mark-past'), findsOneWidget);
      await h.tapKey(tester, 'vaccine-mark-past');
      expect(body(tester), contains('مفيش جرعات إجبارية فاضلة'));
      await h.tapKey(tester, 'vaccine-mark-past-ok');
      expect(await given(tester, id), {...scheduleDay, ...optionalDay});
      expect(key('vaccine-mark-past'), findsNothing);
    });

    testWidgets('setup: a dose ticked by hand as given late: the next one is '
        'still marked, never dated before it (founder, 13 Nov 2026)', (
      tester,
    ) async {
      veryTall(tester);
      final id = await seed(tester);
      await h.open(tester, '/family/$id/vaccines/setup');
      await h.tapKey(tester, 'setup-mmr-1');
      await h.tapKey(tester, 'setup-date-mmr-1');
      Navigator.of(tester.element(find.byType(DatePickerDialog)))
          .pop(d(2026, 11, 1));
      await h.settle(tester);
      await h.tapKey(tester, 'setup-mark-past');
      // MMR 1 ticked; MMR 2 is marked too, dated 1 Nov at the earliest.
      expect(body(tester), contains('١٧ جرعة إجبارية'));
      await h.tapKey(tester, 'vaccine-mark-past-optional');
      await h.tapKey(tester, 'vaccine-mark-past-ok');
      await h.tapKey(tester, 'vaccine-setup-save');
      final dates = await given(tester, id);
      expect(dates['mmr-1'], d(2026, 11, 1));
      // Never before MMR 1, never after today.
      expect(dates['mmr-2']!.isBefore(d(2026, 11, 1)), isFalse);
      expect(dates['mmr-2']!.isAfter(today), isFalse);
      expect(dates.length, 18);
    });

    testWidgets('a child of 4 years 11 months, from the setup with the '
        'optional ones unticked: the 18 required on the schedule', (
      tester,
    ) async {
      veryTall(tester);
      final born = DateTime(2021, 12, 12);
      final id = (await tester.runAsync(
        () => h.db.addProfile('سلمى', sex: 'female', birthDate: born),
      ))!;
      await h.open(tester, '/family/$id/vaccines/setup');
      await h.tapKey(tester, 'setup-mark-past');
      expect(body(tester), contains('١٨ جرعة إجبارية'));
      await h.tapKey(tester, 'vaccine-mark-past-optional');
      await h.tapKey(tester, 'vaccine-mark-past-ok');
      await h.tapKey(tester, 'vaccine-setup-save');
      final dates = await given(tester, id);
      DateTime at(int months) {
        final m = DateTime(born.year, born.month + months, born.day);
        return DateTime(m.year, m.month, m.day);
      }

      expect(dates, {
        for (final e in scheduleDay.entries)
          e.key: at(
            const {
              'hepB-0': 0, 'bcg-1': 0, 'opv-0': 0, //
              'opv-1': 2, 'ipv-1': 2, 'penta-1': 2,
              'opv-2': 4, 'ipv-2': 4, 'penta-2': 4,
              'opv-3': 6, 'ipv-3': 6, 'penta-3': 6,
              'opv-4': 9, 'opv-5': 12, 'mmr-1': 12,
              'opv-6': 18, 'mmr-2': 18, 'dtp-1': 18,
            }[e.key]!,
          ),
      });
      expect(await planOf(tester, id), VaccinePlan.standard);
    });

    testWidgets('at 5, the vaccine page is for under-fives only', (
      tester,
    ) async {
      veryTall(tester);
      final id = (await tester.runAsync(
        () => h.db.addProfile(
          'سلمى',
          sex: 'female',
          birthDate: DateTime(2021, 11, 12),
        ),
      ))!;
      await h.open(tester, '/family/$id/vaccines');
      expect(key('vaccine-mark-past'), findsNothing);
      expect(key('vaccine-progress'), findsNothing);
    });

    group('the dialog at double text on a small phone', () {
      forEachSmallLayout(() => h, (tester) async {
        final id = await seed(tester);
        await h.open(tester, '/family/$id/vaccines');
        await h.tapKey(tester, 'vaccine-mark-past');
        expect(key('vaccine-mark-past-dialog'), findsOneWidget);
        await walkScreen(
          tester,
          scrollable: find
              .descendant(
                of: key('vaccine-mark-past-dialog'),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        // Every part reachable, the buttons too.
        await tester.ensureVisible(key('vaccine-mark-past-safety'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(key('vaccine-mark-past-ok').hitTestable(), findsOneWidget);
      });
    });
  });

  testWidgets('everything she is missing shows, apart from what can be '
      'given now (F)', (tester) async {
    veryTall(tester);
    final id = await seed(tester);
    await h.open(tester, '/family/$id');
    // 18 required doses missing; 7 can be given today (birth, 2 months and
    // MMR 1), the rest wait for the doses before them.
    // One dot row in the attention card.
    expect(find.text('١٨ جرعة تطعيم ناقصة'), findsOneWidget);
    expect(text(tester, 'person-vaccine-now'), '٧ ممكن تتاخد دلوقتي');
    await h.go(tester, '/family/$id/vaccines');
    expect(find.textContaining('الدكتور يحدد إمتى تتاخد'), findsOneWidget);
    // The vaccine page lists the 7 under one heading.
    expect(
      tester
          .widget<Text>(
            find.descendant(
              of: key('vaccine-now-heading'),
              matching: find.byType(Text),
            ),
          )
          .data,
      'ممكن تتاخد دلوقتي – ٧',
    );
  });
}
