import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:usra/app.dart';
import 'package:usra/core/database/app_database.dart';
import 'package:usra/core/design/bottom_bar.dart';
import 'package:usra/core/design/dr_usra.dart';
import 'package:usra/core/design/status_chip.dart';
import 'package:usra/core/design/tokens.dart';
import 'package:usra/core/providers.dart';
import 'package:usra/features/medicines/medicines_providers.dart';
import 'package:usra/features/sick_days/temperature_chart.dart';

import '../support/fake_reminder_scheduler.dart';

void main() {
  late AppDatabase db;
  final now = DateTime(2026, 11, 7, 14);
  final yesterday9pm = DateTime(2026, 11, 6, 21);

  setUp(() {
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
  });
  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
    await tester.pumpAndSettle();
  }

  /// A person with a sick day and four readings ending at 37.6 under the arm.
  Future<(String, String)> seed(
    WidgetTester tester, {
    String name = 'يوسف',
    String? sex = 'male',
    DateTime? birthDate,
    bool withGiven = false,
  }) async => (await tester.runAsync(() async {
    final person = await db.addProfile(
      name,
      sex: sex,
      birthDate: birthDate ?? DateTime(2020, 5, 1),
    );
    final episode = await db.saveEpisode(
      profileId: person,
      startedAt: yesterday9pm,
    );
    for (final (at, value) in [
      (yesterday9pm, 38.6),
      (DateTime(2026, 11, 7, 3), 38.9),
      (DateTime(2026, 11, 7, 9), 38.2),
      (DateTime(2026, 11, 7, 14), 37.6),
    ]) {
      await db.saveReading(
        episodeId: episode,
        takenAt: at,
        value: value,
        unit: 'c',
        site: 'armpit',
      );
    }
    if (withGiven) {
      await db.saveGivenMedicine(
        episodeId: episode,
        name: 'باراسيتامول شراب',
        amount: '٧٫٥ مل',
        givenAt: DateTime(2026, 11, 7, 10),
      );
    }
    return (person, episode);
  }))!;

  Future<void> open(
    WidgetTester tester,
    String person,
    String episode, {
    Locale locale = const Locale('ar'),
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [
          databaseProvider.overrideWithValue(db),
          reminderSchedulerProvider.overrideWithValue(FakeReminderScheduler()),
          clockProvider.overrideWithValue(() => now),
          localeProvider.overrideWith(() => _FixedLocale(locale)),
        ],
        child: const UsraApp(),
      ),
    );
    await settle(tester);
    GoRouter.of(tester.element(find.byType(Scaffold).first))
        .go('/family/$person/sick-days/$episode');
    await settle(tester);
  }

  void phone(WidgetTester tester, {double width = 390, double height = 844}) {
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = Size(width * 2, height * 2);
    addTearDown(tester.view.reset);
  }

  String textOf(WidgetTester tester, String key) =>
      tester.widget<Text>(find.byKey(ValueKey(key))).data!;

  testWidgets('title and since line follow the person and the day', (
    tester,
  ) async {
    phone(tester, height: 2000);
    final (person, episode) = await seed(tester);
    await open(tester, person, episode);
    expect(textOf(tester, 'sick-day-title'), 'يوسف تعبان');
    expect(textOf(tester, 'sick-day-since'), contains('من امبارح'));
    expect(textOf(tester, 'sick-day-since'), contains('٦ سنين'));
    expect(textOf(tester, 'sick-day-latest'), '٣٧٫٦°');
    expect(textOf(tester, 'sick-day-latest-meta'), contains('آخر قراءة'));
    expect(textOf(tester, 'sick-day-latest-meta'), contains('تحت الباط'));

    // No tab bar here: the screen's own two actions take its place.
    expect(find.byType(UsraBottomBar), findsNothing);
    expect(find.byKey(const ValueKey('sick-day-add-reading')), findsOneWidget);
    expect(find.byKey(const ValueKey('sick-day-add-medicine')), findsOneWidget);

    // Marked as over, it stops saying they're ill now.
    await tester.ensureVisible(find.byKey(const ValueKey('sick-day-end')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('sick-day-end')));
    await settle(tester);
    expect(textOf(tester, 'sick-day-title'), 'يوسف كان تعبان');
  });

  testWidgets('a woman or girl reads in the feminine', (tester) async {
    phone(tester);
    final (person, episode) = await seed(tester, name: 'ليلى', sex: 'female');
    await open(tester, person, episode);
    expect(textOf(tester, 'sick-day-title'), 'ليلى تعبانة');
  });

  testWidgets('with no sex on the profile the title stays neutral', (
    tester,
  ) async {
    phone(tester);
    final (person, episode) = await seed(tester, name: 'نور', sex: null);
    await open(tester, person, episode);
    expect(textOf(tester, 'sick-day-title'), 'نور: يوم تعب');
  });

  testWidgets('never reassures: under 38 is only a number, with nothing '
      'green, no "no fever", and no Dr. Usra', (tester) async {
    phone(tester, height: 2600);
    final (person, episode) = await seed(tester);
    await open(tester, person, episode);
    expect(find.byType(DrUsra), findsNothing);
    expect(find.textContaining('مفيش سخونية'), findsNothing);
    expect(find.textContaining('كله تمام'), findsNothing);
    final chips = tester.widgetList<StatusChip>(find.byType(StatusChip));
    expect(chips.where((c) => c.severity == Severity.good), isEmpty);

    // Help is still there, in full, under a reading below the line.
    expect(find.byKey(const ValueKey('warning-breathing')), findsOneWidget);
    expect(find.text('اتصل بالإسعاف ١٢٣'), findsOneWidget);
    expect(find.byKey(const ValueKey('warning-source-nhs')), findsOneWidget);
  });

  testWidgets('under the chart: the highest reading, and the first and last '
      'fever readings as times, not a duration (bug 15)', (tester) async {
    phone(tester);
    final (person, episode) = await seed(tester);
    await open(tester, person, episode);
    final lines = textOf(tester, 'sick-day-fever-duration').split('\n');
    // 38.9 at 03:00 is the highest of the four; the latest is 37.6.
    expect(lines.first, startsWith('أعلى قراءة: ٣٨٫٩°'));
    expect(lines.first, contains('٣:٠٠'));
    // Fever readings from 21:00 yesterday (with its date) to 09:00 today; the
    // 14:00 reading of 37.6 is under the line.
    expect(lines.last, startsWith('سخونية متسجلة من '));
    expect(lines.last, contains('٩:٠٠ م'));
    expect(lines.last, endsWith('لـ ٩:٠٠ ص'));
    expect(lines.last, isNot(contains('ساعة')));
  });

  testWidgets('what was given shows as recorded, in the family\'s words', (
    tester,
  ) async {
    phone(tester);
    final (person, episode) = await seed(tester, withGiven: true);
    await open(tester, person, episode);
    expect(
      find.textContaining('مسجل: باراسيتامول شراب ٧٫٥ مل'),
      findsOneWidget,
    );
  });

  testWidgets('the doctor button calls the only doctor, or opens the list', (
    tester,
  ) async {
    phone(tester, height: 2600);
    final (person, episode) = await seed(tester);
    await tester.runAsync(
      () => db.saveDoctor(name: 'د. سارة', phone: '01000000000'),
    );
    await open(tester, person, episode);
    expect(find.text('كلّم د. سارة'), findsOneWidget);

    await tester.runAsync(
      () => db.saveDoctor(name: 'د. أحمد', phone: '01000000001'),
    );
    await settle(tester);
    expect(find.text('كلّم د. سارة'), findsNothing);
    expect(find.text('الدكاترة بتوعي'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('sick-day-doctors')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('sick-day-doctors')));
    await settle(tester);
    // Asks which, in place, so the Fever screen is still there to come back to.
    expect(find.text('د. أحمد'), findsOneWidget);
    expect(find.text('د. سارة'), findsOneWidget);
  });

  testWidgets('with no doctor the button opens the list, to add one', (
    tester,
  ) async {
    phone(tester, height: 2600);
    final (person, episode) = await seed(tester);
    await open(tester, person, episode);
    await tester.ensureVisible(find.byKey(const ValueKey('sick-day-doctors')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('sick-day-doctors')));
    await settle(tester);
    expect(find.byKey(const ValueKey('sick-day-title')), findsNothing);
  });

  testWidgets('a deleted sick day still has a way out', (tester) async {
    phone(tester);
    final (person, episode) = await seed(tester);
    await tester.runAsync(() => db.softDeleteEpisode(episode));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          reminderSchedulerProvider.overrideWithValue(FakeReminderScheduler()),
          clockProvider.overrideWithValue(() => now),
        ],
        child: const UsraApp(),
      ),
    );
    await settle(tester);
    GoRouter.of(tester.element(find.byType(Scaffold).first))
        .go('/family/$person/sick-days/$episode');
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
    await tester.tap(find.byKey(const ValueKey('sick-day-bare-back')));
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(find.byKey(const ValueKey('sick-days-empty')), findsOneWidget);
  });

  testWidgets('notes being typed survive folding the section', (tester) async {
    phone(tester, height: 2600);
    final (person, episode) = await seed(tester);
    await open(tester, person, episode);
    final section = find.byKey(const ValueKey('sick-day-notes-section'));
    await tester.ensureVisible(section);
    await settle(tester);
    await tester.tap(
      find.descendant(of: section, matching: find.byType(ListTile)).first,
    );
    await settle(tester);
    await tester.enterText(
      find.byKey(const ValueKey('sick-day-notes')),
      'بيكح بالليل',
    );
    await settle(tester);
    await tester.tap(
      find.descendant(of: section, matching: find.byType(ListTile)).first,
    );
    await settle(tester);
    await tester.tap(
      find.descendant(of: section, matching: find.byType(ListTile)).first,
    );
    await settle(tester);
    expect(find.text('بيكح بالليل'), findsOneWidget);
  });

  testWidgets('axis labels keep the minutes and, over most of a day, the day', (
    tester,
  ) async {
    phone(tester);
    late String person;
    late String episode;
    await tester.runAsync(() async {
      person = await db.addProfile('يوسف', sex: 'male');
      episode = await db.saveEpisode(
        profileId: person,
        startedAt: DateTime(2026, 11, 6, 15),
      );
      await db.saveReading(
        episodeId: episode,
        takenAt: DateTime(2026, 11, 6, 15),
        value: 38.1,
        unit: 'c',
      );
      await db.saveReading(
        episodeId: episode,
        takenAt: DateTime(2026, 11, 7, 12, 55),
        value: 38.2,
        unit: 'c',
      );
    });
    await open(tester, person, episode, locale: const Locale('en'));
    final painter = tester
        .widgetList<CustomPaint>(
          find.descendant(
            of: find.byKey(const ValueKey('sick-day-chart')),
            matching: find.byType(CustomPaint),
          ),
        )
        .map((c) => c.painter)
        .whereType<TemperatureChartPainter>()
        .single;
    expect(painter.timeLabel(DateTime(2026, 11, 7, 12, 55)), contains('12:55'));
    expect(painter.timeLabel(DateTime(2026, 11, 6, 15)), contains('Fri'));
  });

  testWidgets('time runs one way: right to left in Arabic, left to right in '
      'English', (tester) async {
    phone(tester);
    final (person, episode) = await seed(tester);
    TemperatureChartPainter painter() => tester
        .widgetList<CustomPaint>(
          find.descendant(
            of: find.byKey(const ValueKey('sick-day-chart')),
            matching: find.byType(CustomPaint),
          ),
        )
        .map((c) => c.painter)
        .whereType<TemperatureChartPainter>()
        .single;

    await open(tester, person, episode);
    var p = painter();
    expect(p.feverLabel, '٣٨°');
    expect(
      p.xOf(p.readings.last.takenAt, 318),
      lessThan(p.xOf(p.readings.first.takenAt, 318)),
    );

    await open(tester, person, episode, locale: const Locale('en'));
    p = painter();
    expect(p.feverLabel, '38°');
    expect(
      p.xOf(p.readings.last.takenAt, 318),
      greaterThan(p.xOf(p.readings.first.takenAt, 318)),
    );
    expect(find.text('Call ambulance 123'), findsOneWidget);
  });

  for (final (width, scale, locale, dark) in [
    (320.0, 2.0, const Locale('ar'), false),
    (320.0, 2.0, const Locale('en'), true),
    (430.0, 1.0, const Locale('ar'), true),
  ]) {
    testWidgets('fits at $width px, text x$scale, $locale, dark $dark', (
      tester,
    ) async {
      phone(tester);
      tester.platformDispatcher.platformBrightnessTestValue = dark
          ? Brightness.dark
          : Brightness.light;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      final (person, episode) = await seed(
        tester,
        name: 'عبد الرحمن محمد عبد العزيز',
        withGiven: true,
      );
      await open(tester, person, episode, locale: locale);
      // Only now, so this checks the Fever screen and not Home on the way.
      phone(tester, width: width, height: 700);
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await settle(tester);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(
        find.byKey(const ValueKey('sick-day-readings')),
      );
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('sick-day-readings')));
      await settle(tester);
      expect(tester.takeException(), isNull);
    });
  }
}

class _FixedLocale extends LocaleController {
  _FixedLocale(this.locale);
  final Locale locale;

  @override
  Locale build() => locale;
}
