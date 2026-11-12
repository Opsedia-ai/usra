import 'dart:io';

import 'package:drift/drift.dart' show DatabaseConnection, Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:usra/app.dart';
import 'package:usra/core/database/app_database.dart';
import 'package:usra/core/files/photo_store.dart';
import 'package:usra/core/preferences.dart';
import 'package:usra/core/providers.dart';
import 'package:usra/features/medicines/medicines_providers.dart';
import 'package:usra/features/sick_days/temperature_chart.dart';

import '../support/fake_reminder_scheduler.dart';
import '../support/sync_photo_store.dart';

void main() {
  late AppDatabase db;
  late Directory dir;
  late SyncPhotoStore photos;
  final now = DateTime(2026, 11, 4, 9, 30);

  setUp(() {
    dir = Directory.systemTemp.createTempSync('usra_sick_days');
    photos = SyncPhotoStore(
      Directory('${dir.path}/support'),
      PhotoStore.medicinesFolder,
    );
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
  });
  tearDown(() async {
    await db.close();
    dir.deleteSync(recursive: true);
  });

  Widget app({bool simple = false}) => ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      if (simple)
        keyValueStoreProvider.overrideWithValue(
          MemoryKeyValueStore({
            PrefKeys.simpleMode: true,
            PrefKeys.tutorialSeen: true,
            PrefKeys.elderTutorialSeen: true,
          }),
        ),
      reminderSchedulerProvider.overrideWithValue(FakeReminderScheduler()),
      clockProvider.overrideWithValue(() => now),
      medicinePhotoStoreProvider.overrideWithValue(photos),
    ],
    child: const UsraApp(),
  );

  void tallScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1170, 4200);
    tester.view.devicePixelRatio = 1.5;
    addTearDown(tester.view.reset);
  }

  /// Lets database writes and streams run (real time).
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
    await tester.pumpAndSettle();
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    await tester.ensureVisible(find.byKey(ValueKey(key)));
    await tester.tap(find.byKey(ValueKey(key)));
    await settle(tester);
  }

  void go(WidgetTester tester, String path) =>
      GoRouter.of(tester.element(find.byType(Scaffold).first)).go(path);

  testWidgets('a baby\'s fever: logged, charted and flagged as a warning '
      'sign, with the ambulance button', (tester) async {
    tallScreen(tester);
    final baby = (await tester.runAsync(
      () => db.addProfile('Nour', birthDate: DateTime(2026, 9, 20)),
    ))!;
    await tester.pumpWidget(app());
    await settle(tester);
    go(tester, '/family/$baby');
    await settle(tester);
    await tapKey(tester, 'member-sick-days');
    expect(find.byKey(const ValueKey('sick-days-empty')), findsOneWidget);
    await tapKey(tester, 'sick-day-start');

    // Nothing logged yet: the signs are there, none matched.
    expect(find.byKey(const ValueKey('sick-day-warnings')), findsOneWidget);
    expect(find.byKey(const ValueKey('warning-matched')), findsNothing);
    expect(find.byKey(const ValueKey('warning-under3Months')), findsOneWidget);
    expect(find.byKey(const ValueKey('sick-day-ambulance')), findsOneWidget);
    expect(find.byKey(const ValueKey('warning-source-nhs')), findsOneWidget);

    await tapKey(tester, 'sick-day-add-reading');
    await tester.enterText(find.byKey(const ValueKey('reading-value')), '٣٨٫٢');
    await tapKey(tester, 'reading-site-armpit');
    await tapKey(tester, 'reading-save');

    expect(find.byKey(const ValueKey('sick-day-chart')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('warning-matched-under3Months')),
      findsOneWidget,
    );
    final episode = (await tester.runAsync(() => db.watchEpisodes(baby).first))!
        .single;
    final reading = (await tester.runAsync(
      () => db.watchReadings(episode.id).first,
    ))!.single;
    expect((reading.value, reading.unit, reading.site), (38.2, 'c', 'armpit'));

    // A typo is caught, not saved.
    await tapKey(tester, 'sick-day-add-reading');
    await tester.enterText(find.byKey(const ValueKey('reading-value')), '382');
    await tapKey(tester, 'reading-save');
    expect(find.byKey(const ValueKey('reading-value')), findsOneWidget);
    expect(
      (await tester.runAsync(() => db.watchReadings(episode.id).first))!,
      hasLength(1),
    );
  });

  testWidgets('a medicine given: the amount as written, and "next dose '
      'allowed" only from its own instructions', (tester) async {
    tallScreen(tester);
    late String kid;
    late String withInterval;
    late String without;
    late String episode;
    await tester.runAsync(() async {
      kid = await db.addProfile('Omar', birthDate: DateTime(2020, 1, 1));
      withInterval = await db.saveMedicine(
        profileId: kid,
        name: 'Paracetamol syrup',
        instructions: '5 مل كل ٦ ساعات',
        startOn: DateTime(2026, 11, 1),
        minHoursBetweenDoses: const Value(6),
      );
      // Instructions that state hours, but none typed: no time shown.
      without = await db.saveMedicine(
        profileId: kid,
        name: 'Cough syrup',
        instructions: 'كل ٨ ساعات',
        startOn: DateTime(2026, 11, 1),
      );
      episode = await db.saveEpisode(profileId: kid, startedAt: now);
    });
    await tester.pumpWidget(app());
    await settle(tester);
    go(tester, '/family/$kid/sick-days/$episode');
    await settle(tester);

    // Without an interval: no reminder, and a pointer to the doctor.
    await tapKey(tester, 'sick-day-add-medicine');
    await tester.tap(find.byKey(const ValueKey('given-medicine')));
    await settle(tester);
    await tester.tap(find.text('Cough syrup').last);
    await settle(tester);
    expect(find.byKey(const ValueKey('given-no-interval')), findsOneWidget);
    expect(find.byKey(const ValueKey('given-remind')), findsNothing);
    // The app never fills in an amount.
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('given-amount')))
          .controller!
          .text,
      isEmpty,
    );
    await tapKey(tester, 'given-save');

    // With "every 6 hours" saved: the time, and the reminder on request.
    await tapKey(tester, 'sick-day-add-medicine');
    await tester.tap(find.byKey(const ValueKey('given-medicine')));
    await settle(tester);
    await tester.tap(find.text('Paracetamol syrup').last);
    await settle(tester);
    expect(find.byKey(const ValueKey('given-no-interval')), findsNothing);
    expect(find.byKey(const ValueKey('given-hours-after')), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('given-amount')),
      'نص معلقة',
    );
    await tapKey(tester, 'given-remind');
    await tapKey(tester, 'given-save');

    final given = (await tester.runAsync(
      () => db.watchGivenMedicines(episode).first,
    ))!;
    final paracetamol = given.firstWhere((g) => g.medicineId == withInterval);
    expect(paracetamol.amount, 'نص معلقة');
    expect(paracetamol.remindNext, isTrue);
    final cough = given.firstWhere((g) => g.medicineId == without);
    expect(cough.amount, isNull);
    expect(cough.remindNext, isFalse);
    expect(
      find.byKey(ValueKey('given-next-${paracetamol.id}')),
      findsOneWidget,
    );
    expect(find.byKey(ValueKey('given-next-${cough.id}')), findsNothing);

    // A typed medicine, not saved in the app: no next-dose time at all.
    await tapKey(tester, 'sick-day-add-medicine');
    await tester.tap(find.byKey(const ValueKey('given-medicine')));
    await settle(tester);
    await tester.tap(find.byType(DropdownMenuItem<String>).last);
    await settle(tester);
    expect(find.byKey(const ValueKey('given-remind')), findsNothing);
    await tester.enterText(
      find.byKey(const ValueKey('given-name')),
      'Ibuprofen',
    );
    await tapKey(tester, 'given-save');
    final typed = (await tester.runAsync(
      () => db.watchGivenMedicines(episode).first,
    ))!.firstWhere((g) => g.name == 'Ibuprofen');
    expect(typed.medicineId, isNull);
    expect(find.byKey(ValueKey('given-next-${typed.id}')), findsNothing);
  });

  testWidgets('minimum hours: typed, or a suggestion from the instructions '
      'accepted by a tap', (tester) async {
    tallScreen(tester);
    final p = (await tester.runAsync(() => db.addProfile('Omar')))!;
    await tester.pumpWidget(app());
    await settle(tester);
    go(tester, '/family/$p/medicines/new');
    await settle(tester);
    await tester.enterText(find.byKey(const ValueKey('medicine-name')), 'Adol');
    await tapKey(tester, 'medicine-more');
    await tester.enterText(
      find.byKey(const ValueKey('medicine-instructions')),
      'كل ٤-٦ ساعات',
    );
    await settle(tester);
    // A range: nothing offered.
    expect(
      find.byKey(const ValueKey('medicine-min-hours-suggestion')),
      findsNothing,
    );
    await tester.enterText(
      find.byKey(const ValueKey('medicine-instructions')),
      '5 مل كل ٦٫٥ ساعة',
    );
    await settle(tester);
    expect(
      find.byKey(const ValueKey('medicine-min-hours-suggestion')),
      findsOneWidget,
    );
    // Offered, not filled in.
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('medicine-min-hours')))
          .controller!
          .text,
      isEmpty,
    );
    await tapKey(tester, 'medicine-min-hours-use');
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('medicine-min-hours')))
          .controller!
          .text,
      '6.5',
    );
    // Typed with an Arabic comma instead.
    await tester.enterText(
      find.byKey(const ValueKey('medicine-min-hours')),
      '٧،٥',
    );
    await tapKey(tester, 'medicine-save');
    final m = (await tester.runAsync(() => db.watchMedicines(p).first))!.single;
    expect(m.minHoursBetweenDoses, 7.5);
  });

  testWidgets('Arabic, right to left: the card and a reading in Arabic '
      'digits with a comma', (tester) async {
    tallScreen(tester);
    late String baby;
    late String episode;
    await tester.runAsync(() async {
      baby = await db.addProfile('نور', birthDate: DateTime(2026, 9, 20));
      episode = await db.saveEpisode(profileId: baby, startedAt: now);
    });
    await tester.pumpWidget(app());
    await settle(tester);
    go(tester, '/family/$baby/sick-days/$episode');
    await settle(tester);
    final card = find.byKey(const ValueKey('sick-day-warnings'));
    expect(Directionality.of(tester.element(card)), TextDirection.rtl);
    expect(find.text('اتصل بالإسعاف (١٢٣) فورًا لو:'), findsOneWidget);
    expect(find.byKey(const ValueKey('warning-armpit-note')), findsOneWidget);

    await tapKey(tester, 'sick-day-add-reading');
    await tester.enterText(find.byKey(const ValueKey('reading-value')), '٣٧،٦');
    await tapKey(tester, 'reading-site-armpit');
    await tapKey(tester, 'reading-save');
    final r = (await tester.runAsync(() => db.watchReadings(episode).first))!
        .single;
    expect((r.value, r.site), (37.6, 'armpit'));
    expect(
      find.byKey(const ValueKey('warning-matched-armpitUnder3Months')),
      findsOneWidget,
    );

    // 42.5: plausible but unusual, so it asks first.
    await tapKey(tester, 'sick-day-add-reading');
    await tester.enterText(find.byKey(const ValueKey('reading-value')), '٤٢٫٥');
    await tapKey(tester, 'reading-save');
    expect(find.byKey(const ValueKey('reading-confirm-yes')), findsOneWidget);
    await tapKey(tester, 'reading-confirm-no');
    expect(
      (await tester.runAsync(() => db.watchReadings(episode).first))!,
      hasLength(1),
    );
  });

  testWidgets('the chart in °F', (tester) async {
    tallScreen(tester);
    late String kid;
    late String episode;
    await tester.runAsync(() async {
      kid = await db.addProfile('Omar', birthDate: DateTime(2020, 1, 1));
      episode = await db.saveEpisode(profileId: kid, startedAt: now);
      await db.saveReading(
        episodeId: episode,
        takenAt: now.subtract(const Duration(hours: 2)),
        value: 101.2,
        unit: 'f',
      );
      await db.saveReading(
        episodeId: episode,
        takenAt: now,
        value: 99.1,
        unit: 'f',
      );
    });
    await tester.pumpWidget(app());
    await settle(tester);
    go(tester, '/family/$kid/sick-days/$episode');
    await settle(tester);
    final chart = find.byKey(const ValueKey('sick-day-chart'));
    expect(chart, findsOneWidget);
    final painter = tester
        .widgetList<CustomPaint>(
          find.descendant(of: chart, matching: find.byType(CustomPaint)),
        )
        .map((c) => c.painter)
        .whereType<TemperatureChartPainter>()
        .single;
    expect(painter.unit, 'f');
    expect(painter.feverLabel, '١٠٠٫٤°');
    // The latest reading, large, in the unit it was read in.
    expect(find.text('٩٩٫١ °ف'), findsOneWidget);
    // Listed as read, in °F; only 101.2 is a fever (38.4 °C).
    await tapKey(tester, 'sick-day-readings');
    expect(find.text('١٠١٫٢ °ف · سخونية'), findsOneWidget);
    expect(find.text('٩٩٫١ °ف'), findsNWidgets(2));
  });

  testWidgets('symptoms are ticked, and in Simple Mode too', (tester) async {
    tallScreen(tester);
    late String grandma;
    late String episode;
    await tester.runAsync(() async {
      grandma = await db.addProfile(
        'Teta',
        birthDate: DateTime(1950, 1, 1),
        sex: 'female',
      );
      episode = await db.saveEpisode(profileId: grandma, startedAt: now);
    });
    await tester.pumpWidget(app(simple: true));
    await settle(tester);
    go(tester, '/family/$grandma');
    await settle(tester);
    expect(find.byKey(const ValueKey('member-sick-days')), findsOneWidget);
    go(tester, '/family/$grandma/sick-days/$episode');
    await settle(tester);
    // An adult's card has no baby signs.
    expect(find.byKey(const ValueKey('warning-under3Months')), findsNothing);
    await tapKey(tester, 'sick-day-symptoms');
    await tapKey(tester, 'symptom-breathing');
    final saved = (await tester.runAsync(
      () => db.watchEpisode(episode).first,
    ))!;
    expect(decodeSymptoms(saved.symptomsJson), ['breathing']);
    expect(
      find.byKey(const ValueKey('warning-matched-breathing')),
      findsOneWidget,
    );
    await tapKey(tester, 'sick-day-end');
    expect(
      (await tester.runAsync(() => db.watchEpisode(episode).first))!.endedAt,
      isNotNull,
    );
    // Reopening says she's still ill, in the feminine (bug C audit).
    expect(find.text('لسه تعبانة'), findsOneWidget);
    expect(find.text('لسه تعبان'), findsNothing);
  });
}
