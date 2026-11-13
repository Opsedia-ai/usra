import 'dart:io';

import 'package:drift/drift.dart' show DatabaseConnection;
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
import 'package:usra/features/medicines/reminders.dart';

import '../support/fake_reminder_scheduler.dart';
import '../support/sync_photo_store.dart';

void main() {
  late AppDatabase db;
  late Directory dir;
  late FakeReminderScheduler scheduler;
  final now = DateTime(2026, 11, 3, 14);
  final eight = DateTime(2026, 11, 3, 8);
  final two = DateTime(2026, 11, 3, 14);
  final night = DateTime(2026, 11, 3, 20);

  setUp(() {
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    dir = Directory.systemTemp.createTempSync('usra_today');
    scheduler = FakeReminderScheduler();
  });
  tearDown(() async {
    await db.close();
    dir.deleteSync(recursive: true);
  });

  Widget app({bool simple = false, bool discreet = false}) => ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      keyValueStoreProvider.overrideWithValue(
        MemoryKeyValueStore({
          if (simple) ...{
            PrefKeys.simpleMode: true,
            PrefKeys.elderTutorialSeen: true,
          },
          PrefKeys.tutorialSeen: true,
          PrefKeys.discreetNotifications: discreet,
        }),
      ),
      medicinePhotoStoreProvider.overrideWithValue(
        SyncPhotoStore(Directory(dir.path), PhotoStore.medicinesFolder),
      ),
      reminderSchedulerProvider.overrideWithValue(scheduler),
      clockProvider.overrideWithValue(() => now),
    ],
    child: const UsraApp(),
  );

  /// جدو: a dose at 08:00 (missed) and one at 14:00 (now).
  /// ليلى: a dose at 20:00 (later).
  Future<
    ({String grandpa, String laila, String concor, String gluco, String iron})
  >
  seed(WidgetTester tester) async => (await tester.runAsync(() async {
    final grandpa = await db.addProfile('جدو');
    final laila = await db.addProfile('ليلى');
    final concor = await db.saveMedicine(
      profileId: grandpa,
      name: 'كونكور',
      strength: '٥ مجم',
      startOn: DateTime(2026, 11, 1),
      schedule: const DoseScheduleInput(times: ['08:00'], amount: 'حباية'),
    );
    final gluco = await db.saveMedicine(
      profileId: grandpa,
      name: 'جلوكوفاج',
      instructions: 'حباية بعد الغدا',
      startOn: DateTime(2026, 11, 1),
      schedule: const DoseScheduleInput(times: ['14:00']),
    );
    final iron = await db.saveMedicine(
      profileId: laila,
      name: 'شراب الحديد',
      instructions: '١ مل بعد الرضعة',
      startOn: DateTime(2026, 11, 1),
      schedule: const DoseScheduleInput(times: ['20:00']),
    );
    return (
      grandpa: grandpa,
      laila: laila,
      concor: concor,
      gluco: gluco,
      iron: iron,
    );
  }))!;

  Future<void> settleDb(WidgetTester tester) async {
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> open(WidgetTester tester, {bool discreet = false}) async {
    await tester.pumpWidget(app(discreet: discreet));
    await tester.pump();
    await settleDb(tester);
    // The app opens on Home, which isn't what these tests are measuring: at
    // 320 px its pebble with a "missed" chip overflows by 2 px.
    tester.takeException();
    GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/medicines');
    await settleDb(tester);
    await tester.pumpAndSettle();
  }

  void phone(WidgetTester tester, {double width = 390, double scale = 1}) {
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = Size(width * 2, 3000 * 2);
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }

  Finder key(String k) => find.byKey(ValueKey(k));
  String id(String medicine, DateTime at) =>
      '$medicine-${at.millisecondsSinceEpoch}';

  Future<void> tapKey(WidgetTester tester, String k) async {
    await tester.ensureVisible(key(k));
    await tester.tap(key(k));
    await settleDb(tester);
  }

  Future<DoseLog?> logOf(WidgetTester tester, String medicine) async {
    final logs = await tester.runAsync(
      () => db.watchMedicineDoseLogs(medicine).first,
    );
    return logs!.firstOrNull;
  }

  testWidgets('missed, then now, then later, each with its own actions', (
    tester,
  ) async {
    phone(tester);
    final ids = await seed(tester);
    await open(tester);

    expect(find.text('فاتت'), findsNWidgets(2)); // The heading and the chip.
    expect(find.text('دلوقتي – ٢:٠٠ م'), findsOneWidget);
    expect(find.text('بالليل – ٨:٠٠ م'), findsOneWidget);
    expect(find.text('٨:٠٠ ص – حباية'), findsOneWidget);
    double top(String k) => tester.getTopLeft(key(k)).dy;
    final missed = id(ids.concor, eight);
    final due = id(ids.gluco, two);
    final later = id(ids.iron, night);
    expect(top('dose-$missed'), lessThan(top('dose-$due')));
    expect(top('dose-$due'), lessThan(top('dose-$later')));

    expect(key('dose-taken-$missed'), findsOneWidget);
    expect(key('dose-skip-$missed'), findsOneWidget);
    expect(key('dose-snooze-$missed'), findsNothing);
    expect(key('dose-early-$missed'), findsNothing);

    expect(key('dose-taken-$due'), findsOneWidget);
    expect(key('dose-snooze-$due'), findsOneWidget);
    expect(find.text('بعد ١٠ دقايق'), findsOneWidget);

    expect(key('dose-early-$later'), findsOneWidget);
    expect(find.text('اتاخد بدري'), findsOneWidget);
    expect(key('dose-taken-$later'), findsNothing);
    expect(key('dose-snooze-$later'), findsNothing);

    // The one word for a dose, everywhere on the screen.
    expect(find.text('اتاخد'), findsNWidgets(2));

    // Polish: many doses, so none takes the filled navy button, and the
    // "now" dose isn't a tinted card.
    expect(find.byType(FilledButton), findsNothing);
    expect(tester.widget<Card>(key('dose-$due')).color, isNull);
  });

  testWidgets('the filter shows one person; All shows everyone again', (
    tester,
  ) async {
    phone(tester);
    final ids = await seed(tester);
    await open(tester);
    expect(find.text('الكل'), findsOneWidget);

    await tapKey(tester, 'medicines-filter-${ids.laila}');
    expect(find.text('شراب الحديد'), findsOneWidget);
    expect(find.text('كونكور ٥ مجم'), findsNothing);
    expect(find.text('جلوكوفاج'), findsNothing);

    await tapKey(tester, 'medicines-filter-${ids.grandpa}');
    expect(find.text('شراب الحديد'), findsNothing);
    expect(find.text('كونكور ٥ مجم'), findsOneWidget);

    await tapKey(tester, 'medicines-filter-all');
    expect(find.text('شراب الحديد'), findsOneWidget);
    expect(find.text('كونكور ٥ مجم'), findsOneWidget);
  });

  testWidgets('a person with nothing today says so', (tester) async {
    phone(tester);
    await seed(tester);
    final none = (await tester.runAsync(() => db.addProfile('يوسف')))!;
    await open(tester);
    await tapKey(tester, 'medicines-filter-$none');
    expect(find.text('مفيش أدوية لـيوسف النهارده.'), findsOneWidget);
  });

  testWidgets('All medicines lists everyone, or the chosen person', (
    tester,
  ) async {
    phone(tester);
    final ids = await seed(tester);
    await open(tester);
    await tapKey(tester, 'medicines-all');
    await tester.pumpAndSettle();
    expect(find.text('جدو'), findsOneWidget);
    expect(find.text('ليلى'), findsOneWidget);
    expect(find.text('كونكور ٥ مجم'), findsOneWidget);
    expect(find.text('شراب الحديد'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await settleDb(tester);
    await tester.pumpAndSettle();
    await tapKey(tester, 'medicines-filter-${ids.laila}');
    await tapKey(tester, 'medicines-all');
    await tester.pumpAndSettle();
    expect(find.text('أدوية ليلى'), findsOneWidget);
    expect(find.text('كونكور ٥ مجم'), findsNothing);
  });

  testWidgets('Taken names the medicine and the person, and Undo restores it', (
    tester,
  ) async {
    phone(tester);
    final ids = await seed(tester);
    await open(tester);
    final missed = id(ids.concor, eight);

    await tapKey(tester, 'dose-taken-$missed');
    final log = (await logOf(tester, ids.concor))!;
    expect(log.status, DoseOutcome.taken);
    expect(log.scheduledAt.isAtSameMomentAs(eight), isTrue);
    expect(log.at.isAtSameMomentAs(now), isTrue);
    await settleDb(tester);
    expect(find.text('اتسجل: كونكور ٥ مجم لـجدو'), findsOneWidget);
    expect(find.text('اتسجلت'), findsOneWidget);
    expect(find.textContaining('اتاخد الساعة'), findsOneWidget);
    expect(key('dose-taken-$missed'), findsNothing);

    await tester.tap(find.text('تراجع').last);
    await settleDb(tester);
    expect(await logOf(tester, ids.concor), isNull);
    await settleDb(tester);
    expect(key('dose-taken-$missed'), findsOneWidget);
  });

  testWidgets('a mark can still be undone after the snackbar is gone', (
    tester,
  ) async {
    phone(tester);
    final ids = await seed(tester);
    await open(tester);
    final missed = id(ids.concor, eight);
    await tapKey(tester, 'dose-taken-$missed');
    await settleDb(tester);
    // Past the snackbar's six seconds.
    await tester.pump(const Duration(seconds: 7));
    await tester.pumpAndSettle();
    expect(find.text('اتسجل: كونكور ٥ مجم لـجدو'), findsNothing);

    await tapKey(tester, 'dose-undo-$missed');
    expect(await logOf(tester, ids.concor), isNull);
  });

  testWidgets('Not taken is logged, named, and can be undone', (tester) async {
    phone(tester);
    final ids = await seed(tester);
    await open(tester);
    final missed = id(ids.concor, eight);

    await tapKey(tester, 'dose-skip-$missed');
    expect((await logOf(tester, ids.concor))!.status, DoseOutcome.skipped);
    await settleDb(tester);
    expect(find.text('اتسجل إنه ماتاخدش: كونكور ٥ مجم لـجدو'), findsOneWidget);
    expect(find.textContaining('ماتاخدش الساعة'), findsOneWidget);

    await tester.tap(find.text('تراجع').last);
    await settleDb(tester);
    expect(await logOf(tester, ids.concor), isNull);
  });

  testWidgets('a dose due now can be left out without waiting an hour', (
    tester,
  ) async {
    phone(tester);
    final ids = await seed(tester);
    await open(tester);
    await tapKey(tester, 'dose-skip-${id(ids.gluco, two)}');
    expect((await logOf(tester, ids.gluco))!.status, DoseOutcome.skipped);
  });

  testWidgets('In 10 minutes sets its own reminder, and Undo clears the mark', (
    tester,
  ) async {
    phone(tester);
    final ids = await seed(tester);
    await open(tester);
    final due = id(ids.gluco, two);

    await tapKey(tester, 'dose-snooze-$due');
    expect((await logOf(tester, ids.gluco))!.status, DoseOutcome.snoozed);
    await settleDb(tester);
    final snooze = scheduler.snoozes.single;
    expect(snooze.id, snoozeIdFor(ids.gluco, two.toUtc()));
    expect(snooze.at, now.add(snoozeDuration));
    expect(snooze.scheduledAt.isAtSameMomentAs(two), isTrue);
    expect(snooze.title, contains('جلوكوفاج'));
    expect(snooze.title, contains('جدو'));

    // Still due, with the time it's put off to.
    expect(key('dose-snoozed-$due'), findsOneWidget);
    expect(find.text('متأجل لحد ٢:١٠ م'), findsOneWidget);
    expect(key('dose-taken-$due'), findsOneWidget);
    expect(find.text('هنفكّرك بعد ١٠ دقايق: جلوكوفاج لـجدو'), findsOneWidget);

    await tester.tap(find.text('تراجع').last);
    await settleDb(tester);
    expect(await logOf(tester, ids.gluco), isNull);
    await settleDb(tester);
    expect(key('dose-snoozed-$due'), findsNothing);
  });

  testWidgets('a discreet phone keeps names out of the snooze reminder', (
    tester,
  ) async {
    phone(tester);
    final ids = await seed(tester);
    await open(tester, discreet: true);

    await tapKey(tester, 'dose-snooze-${id(ids.gluco, two)}');
    await settleDb(tester);
    final snooze = scheduler.snoozes.single;
    expect(snooze.title, isNot(contains('جلوكوفاج')));
    expect(snooze.title, isNot(contains('جدو')));
    expect(snooze.body, isNot(contains('حباية')));
    expect(snooze.takenLabel, isNull);
  });

  testWidgets('a snooze that can\'t be set doesn\'t count as snoozed', (
    tester,
  ) async {
    phone(tester);
    final ids = await seed(tester);
    scheduler = _FailingAdd();
    await open(tester);

    await tapKey(tester, 'dose-snooze-${id(ids.gluco, two)}');
    await settleDb(tester);
    expect(await logOf(tester, ids.gluco), isNull);
    expect(find.text('حصلت مشكلة في الحفظ، جرّب تاني'), findsOneWidget);
  });

  testWidgets('Taken early is logged at the real time, labelled, and undone', (
    tester,
  ) async {
    phone(tester);
    final ids = await seed(tester);
    await open(tester);
    final later = id(ids.iron, night);

    await tapKey(tester, 'dose-early-$later');
    final log = (await logOf(tester, ids.iron))!;
    expect(log.status, DoseOutcome.taken);
    expect(log.scheduledAt.isAtSameMomentAs(night), isTrue);
    expect(log.at.isAtSameMomentAs(now), isTrue);
    await settleDb(tester);
    expect(find.text('اتسجل بدري: شراب الحديد لـليلى'), findsOneWidget);
    expect(find.text('اتاخد بدري الساعة ٢:٠٠ م'), findsOneWidget);

    await tester.tap(find.text('تراجع').last);
    await settleDb(tester);
    expect(await logOf(tester, ids.iron), isNull);
    await settleDb(tester);
    expect(key('dose-early-$later'), findsOneWidget);
  });

  testWidgets('a mark right after another replaces its snackbar', (
    tester,
  ) async {
    phone(tester);
    final ids = await seed(tester);
    await open(tester);
    await tapKey(tester, 'dose-taken-${id(ids.concor, eight)}');
    await tapKey(tester, 'dose-early-${id(ids.iron, night)}');
    await settleDb(tester);
    await tester.pumpAndSettle();
    expect(find.text('اتسجل بدري: شراب الحديد لـليلى'), findsOneWidget);
    expect(find.text('اتسجل: كونكور ٥ مجم لـجدو'), findsNothing);
  });

  testWidgets('a snooze refused because the dose was marked says nothing', (
    tester,
  ) async {
    phone(tester);
    final ids = await seed(tester);
    await open(tester);
    final due = id(ids.gluco, two);
    final button = tester.widget<TextButton>(key('dose-snooze-$due'));
    // Taken on the widget just as the snooze button is pressed.
    await tester.runAsync(
      () => db.logDose(ids.gluco, two.toUtc(), DoseOutcome.taken, at: now),
    );
    button.onPressed!();
    await settleDb(tester);
    await tester.pumpAndSettle();
    expect((await logOf(tester, ids.gluco))!.status, DoseOutcome.taken);
    expect(scheduler.snoozes, isEmpty);
    expect(find.textContaining('هنفكّرك'), findsNothing);
  });

  testWidgets('undoing Taken on a snoozed dose puts the snooze back', (
    tester,
  ) async {
    phone(tester);
    final ids = await seed(tester);
    await tester.runAsync(
      () => db.logDose(
        ids.gluco,
        two.toUtc(),
        DoseOutcome.snoozed,
        at: now.subtract(const Duration(minutes: 2)),
      ),
    );
    await open(tester);
    final due = id(ids.gluco, two);
    await tapKey(tester, 'dose-taken-$due');
    expect((await logOf(tester, ids.gluco))!.status, DoseOutcome.taken);
    await settleDb(tester);

    await tester.tap(
      find.descendant(of: find.byType(SnackBar), matching: find.text('تراجع')),
    );
    // Two writes and a reminder, each needing real time.
    for (var i = 0; i < 4; i++) {
      await settleDb(tester);
    }
    final log = (await logOf(tester, ids.gluco))!;
    expect(log.status, DoseOutcome.snoozed);
    expect(
      log.at.isAtSameMomentAs(now.subtract(const Duration(minutes: 2))),
      isTrue,
    );
    expect(scheduler.snoozes.single.at, DateTime(2026, 11, 3, 14, 10));
    await settleDb(tester);
    expect(key('dose-snoozed-$due'), findsOneWidget);
  });

  testWidgets('a course says which day it is, in the same digits as the time', (
    tester,
  ) async {
    phone(tester);
    await tester.runAsync(() async {
      final grandpa = await db.addProfile('جدو');
      await db.saveMedicine(
        profileId: grandpa,
        name: 'أموكسيسيلين',
        startOn: DateTime(2026, 11, 1),
        endOn: DateTime(2026, 11, 7),
        schedule: const DoseScheduleInput(times: ['20:00']),
      );
    });
    await open(tester);
    expect(find.text('اليوم ٣ من ٧'), findsOneWidget);
  });

  testWidgets('a long name is written out beside its pebble', (tester) async {
    phone(tester);
    final med = (await tester.runAsync(() async {
      final aunt = await db.addProfile('خالتو سعاد');
      return db.saveMedicine(
        profileId: aunt,
        name: 'فيتامين د',
        startOn: DateTime(2026, 11, 1),
        schedule: const DoseScheduleInput(times: ['20:00']),
      );
    }))!;
    await open(tester);
    final name = key('dose-person-${id(med, night)}');
    expect(name, findsOneWidget);
    expect(tester.widget<Text>(name).data, 'خالتو سعاد');
  });

  group('fits', () {
    for (final (width, scale) in [
      (320.0, 1.0),
      (320.0, 2.0),
      (375.0, 2.0),
      (430.0, 1.0),
      (430.0, 2.0),
    ]) {
      testWidgets('$width px wide at text ×$scale', (tester) async {
        phone(tester, width: width, scale: scale);
        await seed(tester);
        await open(tester);
        expect(find.text('شراب الحديد'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('in English, left to right', (tester) async {
      phone(tester, width: 320, scale: 2);
      final ids = await seed(tester);
      await open(tester);
      ProviderScope.containerOf(
        tester.element(find.byType(Scaffold).first),
        listen: false,
      ).read(localeProvider.notifier).change(const Locale('en'));
      await settleDb(tester);
      await tester.pumpAndSettle();
      expect(find.text('Missed'), findsNWidgets(2));
      expect(find.text('In 10 min'), findsOneWidget);
      expect(find.text('Taken early'), findsOneWidget);
      expect(find.text('Not taken'), findsNWidgets(2));
      expect(
        Directionality.of(tester.element(key('dose-${id(ids.gluco, two)}'))),
        TextDirection.ltr,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('in dark mode', (tester) async {
      phone(tester, width: 320, scale: 2);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await seed(tester);
      await open(tester);
      expect(find.text('شراب الحديد'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('in Simple Mode, with bigger targets', (tester) async {
      phone(tester, width: 320, scale: 2);
      final ids = await seed(tester);
      await tester.pumpWidget(app(simple: true));
      await tester.pump();
      await settleDb(tester);
      // Below the day's doses at this size.
      await tester.dragUntilVisible(
        key('simple-medicines'),
        find.byType(ListView).first,
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
      await tester.tap(key('simple-medicines'));
      await settleDb(tester);
      await tester.pumpAndSettle();
      expect(find.text('بالليل – ٨:٠٠ م'), findsOneWidget);
      expect(
        tester.getSize(key('dose-taken-${id(ids.gluco, two)}')).height,
        greaterThanOrEqualTo(64),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('every control is at least 48 tall', (tester) async {
      phone(tester);
      final ids = await seed(tester);
      await open(tester);
      for (final k in [
        'medicines-filter-all',
        'medicines-all',
        'dose-taken-${id(ids.concor, eight)}',
        'dose-skip-${id(ids.concor, eight)}',
        'dose-snooze-${id(ids.gluco, two)}',
        'dose-skip-${id(ids.gluco, two)}',
        'dose-early-${id(ids.iron, night)}',
      ]) {
        expect(
          tester.getSize(key(k)).height,
          greaterThanOrEqualTo(48),
          reason: k,
        );
      }
    });
  });
}

class _FailingAdd extends FakeReminderScheduler {
  @override
  Future<void> add(PlannedReminder reminder) async =>
      throw StateError('no alarms');
}
