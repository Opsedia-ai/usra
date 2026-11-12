// The founder's full-app walk of 12 Nov 2026: she ("أنا") and her daughter
// جميلة, born 12 Nov 2024 and two years old today. Every expected value
// below is worked out by hand or from a published source, never from the
// app's own calculation, and each is explained where it is used.
//
// Where a step is too costly to drive (a date picker's calendar), the
// picker is closed with the date, as a person would pick it; the tap counts
// say how many taps the calendar itself takes.

import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:usra/app.dart';
import 'package:usra/core/backup/backup_service.dart';
import 'package:usra/core/database/app_database.dart';
import 'package:usra/core/files/photo_store.dart';
import 'package:usra/core/preferences.dart';
import 'package:usra/core/providers.dart';
import 'package:usra/features/backup/backup_providers.dart';
import 'package:usra/features/family/person_status.dart' show doseMissedAfter;
import 'package:usra/features/follow_ups/follow_ups_providers.dart';
import 'package:usra/features/medicines/dose_schedule.dart';
import 'package:usra/features/medicines/medicines_providers.dart';
import 'package:usra/features/settings/about_privacy_screen.dart';
import 'package:usra/l10n/app_localizations_ar.dart';

import '../support/fake_reminder_scheduler.dart';
import '../support/screen_harness.dart';
import '../support/sync_photo_store.dart';

final ar = AppLocalizationsAr();

/// 10:00 on the day of the report.
final today10 = DateTime(2026, 11, 12, 10);
final birth = DateTime(2024, 11, 12);

/// Taps per common task, printed at the end of the file's tests.
final tapCounts = <String, String>{};

Finder key(String k) => find.byKey(ValueKey(k));

/// Every piece of text on screen, joined, so a failing `contains` shows it.
String screenText(WidgetTester tester) => [
  for (final e in find.byType(RichText).evaluate())
    (e.widget as RichText).text.toPlainText(),
].join(' | ');

/// Arabic-Indic digits, as the app writes its own numbers in Arabic.
String arDigits(String s) => String.fromCharCodes(
  s.codeUnits.map(
    (u) => u >= 0x30 && u <= 0x39
        ? u + 0x0660 - 0x30
        : u == 0x2E
        ? 0x066B
        : u,
  ),
);

/// Closes the open date picker on [date], as if it had been picked.
Future<void> pickDate(WidgetTester tester, DateTime date) async {
  Navigator.of(tester.element(find.byType(DatePickerDialog))).pop(date);
  await tester.pumpAndSettle();
}

class _NoBackupService extends Fake implements BackupService {}

void main() {
  tearDownAll(
    () => debugPrint(
      'TAPS\n${[for (final e in tapCounts.entries) '${e.key}: ${e.value}'].join('\n')}',
    ),
  );

  // ---------------------------------------------------------------------
  // 1. First run, then adding Gamila, all through the UI.
  // ---------------------------------------------------------------------
  group('1. first run and adding Gamila', () {
    late AppDatabase db;
    late MemoryKeyValueStore store;
    var now = today10;
    var taps = 0;

    setUp(() {
      db = AppDatabase(
        DatabaseConnection(
          NativeDatabase.memory(),
          closeStreamsSynchronously: true,
        ),
      );
      store = MemoryKeyValueStore();
      now = today10;
      taps = 0;
    });
    tearDown(() => db.close());

    Widget app() => ProviderScope(
      key: UniqueKey(),
      overrides: [
        databaseProvider.overrideWithValue(db),
        keyValueStoreProvider.overrideWithValue(store),
        clockProvider.overrideWithValue(() => now),
        todayProvider.overrideWithValue(today10),
        reminderSchedulerProvider.overrideWithValue(FakeReminderScheduler()),
        backupServiceProvider.overrideWithValue(_NoBackupService()),
        openLinkProvider.overrideWithValue((uri) async => true),
      ],
      child: const UsraApp(),
    );

    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 20));
      }
      await tester.pumpAndSettle();
    }

    Future<void> tap(WidgetTester tester, Finder f) async {
      await tester.ensureVisible(f);
      await tester.pumpAndSettle();
      await tester.tap(f);
      taps++;
      await settle(tester);
    }

    testWidgets('Welcome, country, About you, Home; then Gamila is added '
        'from Home and shows there and on her page as two years old', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 2;
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(app());
      await settle(tester);
      expect(key('welcome-headline'), findsOneWidget);

      await tap(tester, key('welcome-start'));
      await tap(tester, key('country-next'));
      expect(store.getString(PrefKeys.country), 'EG');
      await tester.tap(key('about-name'));
      taps++;
      await tester.enterText(key('about-name'), 'أنا');
      await tap(tester, key('about-sex-female'));
      await tap(tester, key('about-birthDate'));
      // The picker opens on 1990; OK takes it.
      await tap(
        tester,
        find
            .descendant(
              of: find.byType(DatePickerDialog),
              matching: find.byType(TextButton),
            )
            .last,
      );
      await tap(tester, key('about-done'));
      tapCounts['first run (Welcome to Home, birth date 1990 as offered)'] =
          '$taps';

      final me = (await tester.runAsync(() => db.watchProfiles().first))!;
      expect(me.single.displayName, 'أنا');
      // 10:00 is morning.
      expect(find.text('صباح الخير يا أنا'), findsOneWidget);

      // Add Gamila from Home.
      taps = 0;
      await tap(tester, key('home-new-person'));
      await tap(tester, key('profile-relationship-daughter'));
      await tester.tap(key('profile-name'));
      taps++;
      await tester.enterText(key('profile-name'), 'جميلة');
      await tap(
        tester,
        find.descendant(
          of: find.byType(SegmentedButton<String>),
          matching: find.text(ar.sexFemale),
        ),
      );
      await tap(tester, key('profile-birthDate'));
      final picker = tester.widget<DatePickerDialog>(
        find.byType(DatePickerDialog),
      );
      // BUG: a new person's date-of-birth picker opens on 1 Jan 1990 for
      // everyone, a child too: to reach 12 Nov 2024 in the calendar takes
      // the year switch, the year, ten "next month" taps, the day and OK
      // (14 taps), or the pencil, typing and OK.
      expect(picker.initialDate, DateTime(1990));
      final tapsBeforeCalendar = taps;
      await pickDate(tester, birth);
      taps += 1; // OK, counted; the calendar taps are added below.
      expect(
        tester.widget<Text>(key('profile-birthDate-text')).data,
        contains(ar.personAgeYears(2, '٢')),
      );
      await tap(tester, key('profile-save'));
      // A child under five goes to the vaccine checklist first.
      // "Not now" is at the bottom of the checklist, past every dose.
      await tester.scrollUntilVisible(
        key('vaccine-setup-skip'),
        400,
        scrollable: find.byType(Scrollable).last,
      );
      expect(key('vaccine-setup-skip'), findsOneWidget);
      await tap(tester, key('vaccine-setup-skip'));
      tapCounts['add a person (Gamila, from Home, skipping the vaccine '
              'checklist)'] =
          '$taps with the date typed via the pencil (+1 pencil), or '
          '${taps - 1 + 14} picking 12 Nov 2024 in the calendar '
          '($tapsBeforeCalendar before the picker)';

      final people = (await tester.runAsync(() => db.watchProfiles().first))!;
      final gamila = people.firstWhere((p) => p.displayName == 'جميلة');
      expect(gamila.sex, 'female');
      expect(gamila.relationship, 'daughter');
      expect(gamila.birthDate, birth);

      // Her page: two years old (24 months 0 days: 12 Nov 2024 to
      // 12 Nov 2026), and "your daughter".
      expect(find.text('جميلة'), findsWidgets);
      expect(tester.widget<Text>(key('member-details')).data, 'سنتين · بنتك');

      // Home shows her.
      GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/home');
      await settle(tester);
      expect(key('home-person-${gamila.id}'), findsOneWidget);
      expect(
        find.descendant(
          of: key('home-person-${gamila.id}'),
          matching: find.textContaining('جميلة'),
        ),
        findsWidgets,
      );
    });
  });

  // ---------------------------------------------------------------------
  // 2-11 share one family: the founder and Gamila, seeded in the database.
  // ---------------------------------------------------------------------
  late ScreenHarness h;
  var now = today10;
  late String meId;
  late String gamilaId;
  var taps = 0;

  setUp(() {
    now = today10;
    taps = 0;
    h = ScreenHarness();
    h.overrides = [
      cardPhotoStoreProvider.overrideWithValue(
        SyncPhotoStore(Directory(h.dir.path), PhotoStore.cardsFolder),
      ),
      medicinePhotoStoreProvider.overrideWithValue(
        SyncPhotoStore(Directory(h.dir.path), PhotoStore.medicinesFolder),
      ),
      reminderSchedulerProvider.overrideWithValue(FakeReminderScheduler()),
      todayProvider.overrideWithValue(today10),
      clockProvider.overrideWithValue(() => now),
      backupServiceProvider.overrideWithValue(_NoBackupService()),
    ];
  });
  tearDown(() => h.dispose());

  Future<void> family(WidgetTester tester) async {
    final ids = (await tester.runAsync(() async {
      final me = await h.db.addProfile(
        'أنا',
        sex: 'female',
        birthDate: DateTime(1990),
      );
      final g = await h.db.addProfile(
        'جميلة',
        sex: 'female',
        birthDate: birth,
        relationship: 'daughter',
      );
      return (me, g);
    }))!;
    (meId, gamilaId) = ids;
    await h.prefs.setString(PrefKeys.meProfileId, meId);
  }

  Future<void> tap(WidgetTester tester, String k) async {
    taps++;
    await h.tapKey(tester, k);
  }

  Future<void> tapFinder(WidgetTester tester, Finder f) async {
    taps++;
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await h.settle(tester);
  }

  Future<void> type(WidgetTester tester, String k, String text) async {
    taps++; // to focus the field
    await tester.ensureVisible(key(k));
    await tester.pumpAndSettle();
    await tester.enterText(key(k), text);
    await tester.pumpAndSettle();
  }

  // ---------------------------------------------------------------------
  // 2. Age.
  // ---------------------------------------------------------------------
  testWidgets('2. her page and emergency card say two years', (tester) async {
    h.tall(tester);
    await family(tester);
    await h.open(tester, '/family/$gamilaId');
    // 12 Nov 2024 -> 12 Nov 2026: 24 completed months, 0 days = 2 years.
    expect(tester.widget<Text>(key('member-details')).data, 'سنتين · بنتك');
    await h.go(tester, '/family/$gamilaId/emergency');
    expect(
      tester.widget<Text>(key('emergency-details')).data,
      contains('سنتين'),
    );
    // One day before the birthday she is still 23 months.
    now = DateTime(2026, 11, 11, 10);
    await h.go(tester, '/family/$meId');
    await h.go(tester, '/family/$gamilaId');
    expect(tester.widget<Text>(key('member-details')).data, '٢٣ شهر · بنتك');
  });

  // ---------------------------------------------------------------------
  // 3. Vaccines (smoke), and logging one dose.
  // ---------------------------------------------------------------------
  testWidgets('3. vaccines: catch-up wording, two due dates by hand, and '
      'logging MMR 1', (tester) async {
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = const Size(780, 24000);
    addTearDown(tester.view.reset);
    await family(tester);
    await h.open(tester, '/family/$gamilaId');
    taps = 0;
    await tap(tester, 'member-vaccines');
    // Nothing recorded: the next visit is catch-up.
    expect(
      tester.widget<Text>(key('vaccine-next-doses')).data,
      startsWith('جرعات تعويضية'),
    );
    // Overdue (by hand, MoHP schedule, nothing given): Hep B 0, BCG, OPV 0
    // (birth), OPV 1, IPV 1, Penta 1 (2 months) and MMR 1 (12 months) = 7.
    // The later doses wait on these, so they are catch-up, not overdue.
    expect(screenText(tester), contains('٧ جرعات متأخرة'));
    // Only the first few are cards; the rest open from the count.
    expect(key('vaccine-overdue-card-mmr-1'), findsNothing);
    await tap(tester, 'vaccine-overdue-all');
    final text = screenText(tester);
    // MMR 1 at 12 months: 12 Nov 2025.
    expect(key('vaccine-overdue-card-mmr-1'), findsOneWidget);
    expect(text, contains('كان ميعادها ١٢ نوفمبر ٢٠٢٥'));
    // BCG at birth: 12 Nov 2024.
    expect(text, contains('كان ميعادها ١٢ نوفمبر ٢٠٢٤'));
    // OPV 2 as catch-up: 28 days after OPV 1 given today = 10 Dec 2026.
    expect(text, contains('١٠ ديسمبر ٢٠٢٦'));
    await tap(tester, 'vaccine-log-mmr-1');
    expect(key('dose-save'), findsOneWidget);
    await tap(tester, 'dose-save');
    tapCounts['log a vaccine dose (MMR 1 given today, from her page)'] =
        '$taps from her page (+1 from Home)';
    final events = (await tester.runAsync(
      () => h.db.watchTimeline(gamilaId).first,
    ))!;
    expect(events.where((e) => e.type == 'vaccine'), isNotEmpty);
    expect(key('vaccine-overdue-card-mmr-1'), findsNothing);
  });

  // ---------------------------------------------------------------------
  // 4. Growth against WHO.
  // ---------------------------------------------------------------------
  testWidgets('4. growth: 12.0 kg, 86.0 cm, 47.0 cm today read against the '
      'WHO girls tables', (tester) async {
    h.tall(tester);
    await family(tester);
    await h.open(tester, '/family/$gamilaId');
    taps = 0;
    await tap(tester, 'member-growth');
    await tap(tester, 'growth-add');
    await tap(tester, 'field-occurredAt');
    await pickDate(tester, DateTime(2026, 11, 12));
    await type(tester, 'field-weightKg', '12.0');
    await type(tester, 'field-heightCm', '86.0');
    await type(tester, 'field-headCm', '47.0');
    await tap(tester, 'record-save');
    tapCounts['add a growth measurement (3 values, from her page)'] =
        '$taps from her page incl. the date (+1 from Home; '
        '${taps - 2} when the date is left as today)';
    expect(key('growth-history'), findsOneWidget);

    // Age 730 days = 23.98 WHO months (30.4375 days each): the WHO
    // length-for-age (lying down, 0-2 y) table applies, interpolated
    // between months 23 and 24 (t = 0.98357). LMS for girls, WHO Child
    // Growth Standards (2006), tables wfa_girls_0_5_zscores,
    // lhfa_girls_0_2_zscores, hcfa_girls_0_5_zscores (read from the
    // pygrowup copy of the WHO files):
    //   weight m23 (-0.2903, 11.2688, 0.12369), m24 (-0.2941, 11.4775, 0.1239)
    //   length m23 (1, 85.5202, 0.03711),       m24 (1, 86.4153, 0.03734)
    //   head   m23 (1, 47.0391, 0.02962),       m24 (1, 47.1822, 0.02957)
    // z = ((X/M)^L - 1)/(L*S); percentile = Phi(z):
    //   weight 12.0 kg: z = +0.359 -> 64.0th
    //   length 86.0 cm: z = -0.124 -> 45.1st
    //     (height-for-age 2-5 y at 24 m, M 85.7153: z = +0.088 -> 53.5th)
    //   head 47.0 cm:   z = -0.129 -> 44.9th
    String status(String indicator) => tester
        .widgetList<Text>(
          find.descendant(
            of: key('growth-status-$indicator'),
            matching: find.byType(Text),
          ),
        )
        .map((t) => t.data)
        .join();
    expect(status('weight'), contains('جوه المعدل المرجعي'));
    expect(status('weight'), contains('(المئين ٦٤)'));
    expect(
      tester.widget<Text>(key('growth-source')).data,
      contains('منظمة الصحة العالمية'),
    );
    await tap(tester, 'growth-tab-height');
    expect(status('height'), contains('(المئين ٤٥)'));
    await tap(tester, 'growth-tab-head');
    expect(status('head'), contains('(المئين ٤٥)'));
  });

  // ---------------------------------------------------------------------
  // 5. A sick day with three readings.
  // ---------------------------------------------------------------------
  testWidgets('5. sick day: 38.5 at 08:00, 39.1 at 12:00, 37.8 at 18:00', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = const Size(780, 4000);
    addTearDown(tester.view.reset);
    await family(tester);
    now = DateTime(2026, 11, 12, 8);
    await h.open(tester, '/family/$gamilaId');
    taps = 0;
    await tap(tester, 'member-sick-days');
    await tap(tester, 'sick-day-start');
    expect(key('sick-day-add-reading'), findsOneWidget);
    Future<void> reading(DateTime at, String value) async {
      now = at;
      await tap(tester, 'sick-day-add-reading');
      await type(tester, 'reading-value', value);
      await tap(tester, 'reading-save');
    }

    await reading(DateTime(2026, 11, 12, 8), '38.5');
    tapCounts['start a sick day and add a temperature (from her page)'] =
        '$taps (+1 from Home)';
    await reading(DateTime(2026, 11, 12, 12), '39.1');
    await reading(DateTime(2026, 11, 12, 18), '37.8');
    // Re-open the page at 18:00 so it reads the clock again.
    final episode = (await tester.runAsync(
      () => h.db.watchEpisodes(gamilaId).first,
    ))!.single;
    await h.go(tester, '/family/$gamilaId');
    await h.go(tester, '/family/$gamilaId/sick-days/${episode.id}');

    final readings = (await tester.runAsync(
      () => h.db.watchReadings(episode.id).first,
    ))!;
    expect(readings.map((r) => r.value), [38.5, 39.1, 37.8]);

    // Latest reading.
    expect(tester.widget<Text>(key('sick-day-latest')).data, contains('٣٧٫٨'));
    // Fever = 38.0 or more. First fever reading 08:00, last 12:00, and the
    // latest (18:00) is no longer a fever: 4 hours logged.
    expect(
      tester.widget<Text>(key('sick-day-fever-duration')).data,
      'سخونية متسجلة: ٤ ساعات',
    );
    // Highest: 39.1 (by eye from the three readings). BUG: the page never
    // says it: the card shows the latest (37.8) and the chart, and 39.1 is
    // only in "All readings", closed by default.
    final text = screenText(tester);
    expect(text, isNot(contains('٣٩٫١')));
    expect(text, isNot(contains('أعلى')));
    await tapFinder(tester, find.text('كل القراءات'));
    expect(screenText(tester), contains('٣٩٫١'));
    // At exactly two she is in the 2+ group (AAP): "more than 3 days", not
    // the under-2 "more than 24 hours"; nothing logged matches a sign.
    expect(key('warning-longChild'), findsOneWidget);
    expect(key('warning-longUnder2'), findsNothing);
    expect(key('warning-matched'), findsNothing);
  });

  // ---------------------------------------------------------------------
  // 6. A twice-daily medicine for 5 days.
  // ---------------------------------------------------------------------
  group('6. paracetamol syrup 5 ml at 08:00 and 20:00 for 5 days', () {
    Future<String> addMedicine(WidgetTester tester) async {
      await h.open(tester, '/family/$gamilaId');
      taps = 0;
      await tap(tester, 'member-medicines');
      await tap(tester, 'medicine-add');
      await type(tester, 'medicine-name', 'باراسيتامول شراب');
      await type(tester, 'medicine-instructions', '5 مل');
      await tap(tester, 'medicine-frequency-twice');
      expect(key('medicine-time-08:00'), findsOneWidget);
      expect(key('medicine-time-20:00'), findsOneWidget);
      await tap(tester, 'medicine-duration-until');
      // 5 days from 12 Nov, counting both ends: 12, 13, 14, 15, 16 Nov.
      await pickDate(tester, DateTime(2026, 11, 16));
      await tap(tester, 'medicine-save');
      final m = (await tester.runAsync(
        () => h.db.watchMedicines(gamilaId).first,
      ))!.single;
      return m.id;
    }

    testWidgets('course: 2 a day, 10 in all, last day 16 Nov', (tester) async {
      h.tall(tester);
      await family(tester);
      now = DateTime(2026, 11, 12, 7, 30);
      final id = await addMedicine(tester);
      tapCounts['add a twice-daily medicine with a last day (from her '
              'page)'] =
          '$taps incl. the last-day picker (+1 from Home)';
      final (m, s) = (await tester.runAsync(
        () async => (
          (await h.db.watchMedicine(id).first)!,
          (await h.db.watchDoseSchedule(id).first)!,
        ),
      ))!;
      expect(s.times, '08:00,20:00');
      expect(storedDay(m.startOn), DateTime(2026, 11, 12));
      expect(storedDay(m.endOn!), DateTime(2026, 11, 16));
      final rule = DoseRule.of(m, s);
      // Doses per day: 2. Whole course 12-16 Nov: 5 x 2 = 10.
      expect(
        rule
            .occurrencesBetween(DateTime(2026, 11, 13), DateTime(2026, 11, 14))
            .length,
        2,
      );
      expect(
        rule
            .occurrencesBetween(DateTime(2026, 11, 1), DateTime(2026, 12, 1))
            .length,
        10,
      );
      // Its page: day 1 of 5.
      await h.go(tester, '/family/$gamilaId/medicines/$id');
      expect(tester.widget<Text>(key('medicine-course')).data, 'اليوم ١ من ٥');
      // On 16 Nov, day 5 of 5; on 17 Nov it has ended.
      now = DateTime(2026, 11, 16, 9);
      await h.go(tester, '/family/$gamilaId');
      await h.go(tester, '/family/$gamilaId/medicines/$id');
      expect(tester.widget<Text>(key('medicine-course')).data, 'اليوم ٥ من ٥');
      now = DateTime(2026, 11, 17, 9);
      await h.go(tester, '/family/$gamilaId');
      await h.go(tester, '/family/$gamilaId/medicines/$id');
      expect(key('medicine-course'), findsNothing);
      expect(find.text(ar.medicineEnded), findsOneWidget);
    });

    testWidgets('Today: now, later, done; 20:00 missed only after 21:00', (
      tester,
    ) async {
      h.tall(tester);
      await family(tester);
      now = DateTime(2026, 11, 12, 7, 50);
      final id = await addMedicine(tester);
      String card(DateTime at) => 'dose-$id-${at.millisecondsSinceEpoch}';
      final eight = DateTime(2026, 11, 12, 8);
      final twenty = DateTime(2026, 11, 12, 20);

      await h.go(tester, '/medicines');
      String t() => screenText(tester);
      // 07:50: 08:00 is within 15 minutes, so "now"; 20:00 is "later".
      expect(key(card(eight)), findsOneWidget);
      expect(key(card(twenty)), findsOneWidget);
      expect(t(), contains('${ar.doseGroupNow} · ٨:٠٠ ص'));
      expect(t(), contains('${ar.dayPartNight} · ٨:٠٠ م'));
      expect(t(), isNot(contains(ar.doseGroupMissed)));

      taps = 0;
      await tap(tester, 'dose-taken-$id-${eight.millisecondsSinceEpoch}');
      tapCounts['mark a dose taken (Medicines tab)'] = '$taps';
      expect(t(), contains(ar.doseGroupDone));

      Future<void> at(DateTime when) async {
        now = when;
        await h.go(tester, '/home');
        await h.go(tester, '/medicines');
      }

      // doseMissedAfter is one hour: 20:00 is missed only after 21:00.
      expect(doseMissedAfter, const Duration(hours: 1));
      await at(DateTime(2026, 11, 12, 20, 59));
      expect(t(), isNot(contains(ar.doseGroupMissed)));
      expect(t(), contains('${ar.doseGroupNow} · ٨:٠٠ م'));
      await at(DateTime(2026, 11, 12, 21));
      expect(t(), isNot(contains(ar.doseGroupMissed)));
      await at(DateTime(2026, 11, 12, 21, 1));
      expect(t(), contains(ar.doseGroupMissed));
      expect(t(), contains(ar.doseGroupDone));
    });

    testWidgets('added at 10:00, the 08:00 dose of the first day is '
        'already "missed"', (tester) async {
      h.tall(tester);
      await family(tester);
      now = today10;
      final id = await addMedicine(tester);
      await h.go(tester, '/medicines');
      // BUG: a course started at 10:00 shows that morning's 08:00 dose,
      // which was never planned, as missed.
      expect(screenText(tester), contains(ar.doseGroupMissed));
      expect(
        key('dose-$id-${DateTime(2026, 11, 12, 8).millisecondsSinceEpoch}'),
        findsOneWidget,
      );
    });
  });

  // ---------------------------------------------------------------------
  // 7. Spending.
  // ---------------------------------------------------------------------
  testWidgets('7. a 300 EGP visit and an 85 EGP record: 385 for November', (
    tester,
  ) async {
    h.tall(tester);
    await family(tester);
    // The founder's own visit in October, 200 EGP, to check the split.
    await tester.runAsync(
      () => h.db.addEvent(
        profileId: meId,
        type: 'visit',
        occurredAt: DateTime(2026, 10, 20),
        dataJson: jsonEncode({'doctorName': 'د. سامي'}),
        costMinor: 20000,
        currency: 'EGP',
      ),
    );
    await h.open(tester, '/family/$gamilaId');
    taps = 0;
    await tap(tester, 'add-record');
    await tap(tester, 'type-visit');
    await tap(tester, 'field-occurredAt');
    await pickDate(tester, DateTime(2026, 11, 12));
    await type(tester, 'field-doctorName', 'د. منى');
    await type(tester, 'field-cost', '300');
    await tap(tester, 'record-save');
    tapCounts['record a doctor visit with a cost (from her page)'] =
        '$taps incl. the date (${taps - 2} when left as today; +1 from Home)';

    // No pharmacy or medicine-purchase record exists; an X-ray stands in.
    await h.go(tester, '/family/$gamilaId');
    await tap(tester, 'add-record');
    await tap(tester, 'type-scan');
    await tap(tester, 'field-occurredAt');
    await pickDate(tester, DateTime(2026, 11, 12));
    await tap(tester, 'field-kind');
    await tapFinder(tester, find.text(ar.scanXray).last);
    await type(tester, 'field-cost', '85');
    await tap(tester, 'record-save');

    await h.go(tester, '/money');
    // Spending opens on the real month, not the app's clock.
    final real = DateTime.now();
    final back = (real.year - 2026) * 12 + real.month - 11;
    for (var i = 0; i < back; i++) {
      await h.tapKey(tester, 'spending-previous');
    }
    String total() => tester.widget<Text>(key('spending-total')).data!;
    // 300 + 85 = 385 in November, the whole family.
    expect(total(), contains('٣٨٥'));
    await h.tapKey(tester, 'spending-person-$gamilaId');
    expect(total(), contains('٣٨٥'));
    await h.tapKey(tester, 'spending-person-$meId');
    expect(total(), contains('٠'));
    await h.tapKey(tester, 'spending-person-all');
    // October: the founder's 200 only.
    await h.tapKey(tester, 'spending-previous');
    expect(total(), contains('٢٠٠'));
    await h.tapKey(tester, 'spending-person-$gamilaId');
    expect(total(), contains('٠'));
  });

  // ---------------------------------------------------------------------
  // 8a. Emergency card and insurance.
  // ---------------------------------------------------------------------
  testWidgets('8a. emergency card shows her blood type and allergy', (
    tester,
  ) async {
    h.tall(tester);
    await family(tester);
    await h.open(tester, '/family/$gamilaId');
    await h.tapKey(tester, 'member-edit');
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('A+').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, ar.profileAllergies),
      'بنسلين',
    );
    await h.tapKey(tester, 'profile-save');
    await h.go(tester, '/family/$gamilaId/emergency');
    final t = screenText(tester);
    expect(t, contains('جميلة'));
    expect(t, contains('A+'));
    expect(t, contains('بنسلين'));
    expect(t, contains('١٢٣'));
  });

  testWidgets('8b. insurance: expired, expires soon and valid by the date', (
    tester,
  ) async {
    h.tall(tester);
    await family(tester);
    // BUG: the expiry chip reads the phone's clock (DateTime.now), not the
    // app's, so the dates here are relative to the real day.
    final real = DateUtils.dateOnly(DateTime.now());
    await h.open(tester, '/family/$gamilaId');
    taps = 0;
    await tap(tester, 'member-insurance');
    await tap(tester, 'insurance-add');
    await type(tester, 'insurance-label', 'شغل ماما');
    await tap(tester, 'insurance-expiry');
    // Yesterday: expired.
    await pickDate(tester, real.subtract(const Duration(days: 1)));
    await tap(tester, 'insurance-save');
    tapCounts['add an insurance card with an expiry date'] =
        '$taps from her page (+1 from Home; the expiry picker counted as 1)';
    final cards = (await tester.runAsync(
      () => h.db.watchInsuranceCards(gamilaId).first,
    ))!;
    final id = cards.single.id;
    String chip() => screenText(tester);
    await h.go(tester, '/family/$gamilaId/insurance');
    expect(chip(), contains('انتهى'));
    Future<void> expiry(DateTime day) async {
      await tester.runAsync(
        () => h.db.saveInsuranceCard(
          id: id,
          profileId: gamilaId,
          label: 'شغل ماما',
          expiresOn: DateTime.utc(day.year, day.month, day.day),
        ),
      );
      await h.go(tester, '/family/$gamilaId');
      await h.go(tester, '/family/$gamilaId/insurance');
    }

    // Today itself: still valid today, and within 30 days.
    await expiry(real);
    expect(chip(), contains('بينتهي'));
    // 30 days ahead: "expires soon"; 31: "valid until".
    await expiry(real.add(const Duration(days: 30)));
    expect(chip(), contains('بينتهي'));
    await expiry(real.add(const Duration(days: 31)));
    expect(chip(), contains('ساري لحد'));
  });
}
