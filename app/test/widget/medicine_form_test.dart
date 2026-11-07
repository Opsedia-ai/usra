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
import 'package:usra/core/ocr/medicine_name_extractor.dart';
import 'package:usra/core/ocr/ocr_service.dart';
import 'package:usra/core/preferences.dart';
import 'package:usra/core/providers.dart';
import 'package:usra/features/medicines/medicines_providers.dart';
import 'package:usra/l10n/app_localizations_ar.dart';
import 'package:usra/l10n/app_localizations_en.dart';

import '../support/fake_ocr_service.dart';
import '../support/fake_reminder_scheduler.dart';
import '../support/sync_photo_store.dart';

void main() {
  late AppDatabase db;
  late Directory dir;
  late File picked;
  late FakeReminderScheduler scheduler;
  late FakeOcrService ocr;
  final extractor = MedicineNameExtractor(['Panadol', 'Concor']);
  final now = DateTime(2026, 11, 3, 14);

  setUp(() {
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    dir = Directory.systemTemp.createTempSync('usra_medicine_form');
    picked = File('${dir.path}/box.jpg')..writeAsBytesSync([0, 1, 2]);
    scheduler = FakeReminderScheduler();
    ocr = FakeOcrService(OcrResult.empty);
  });
  tearDown(() async {
    await db.close();
    dir.deleteSync(recursive: true);
  });

  Widget app({bool simple = false}) => ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      keyValueStoreProvider.overrideWithValue(
        MemoryKeyValueStore({
          if (simple) ...{
            PrefKeys.simpleMode: true,
            PrefKeys.elderTutorialSeen: true,
          },
          PrefKeys.tutorialSeen: true,
        }),
      ),
      medicinePhotoStoreProvider.overrideWithValue(
        SyncPhotoStore(Directory(dir.path), PhotoStore.medicinesFolder),
      ),
      reminderSchedulerProvider.overrideWithValue(scheduler),
      clockProvider.overrideWithValue(() => now),
      photoPickerProvider.overrideWithValue((_) async => picked.path),
      ocrServiceProvider.overrideWithValue(ocr),
      medicineNameExtractorProvider.overrideWith((ref) async => extractor),
    ],
    child: const UsraApp(),
  );

  Future<void> settleDb(WidgetTester tester) async {
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  void phone(WidgetTester tester, {double width = 390, double scale = 1}) {
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = Size(width * 2, 3000 * 2);
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }

  Finder key(String k) => find.byKey(ValueKey(k));

  /// Far down the form at large text, it may not be built yet.
  Future<void> reveal(WidgetTester tester, String k) async {
    if (key(k).evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        key(k),
        200,
        scrollable: find.byType(Scrollable).first,
      );
    }
    await tester.ensureVisible(key(k));
    await tester.pumpAndSettle();
  }

  Future<void> tapKey(WidgetTester tester, String k) async {
    await reveal(tester, k);
    await tester.tap(key(k));
    await settleDb(tester);
    await tester.pumpAndSettle();
  }

  Future<void> go(WidgetTester tester, String path) async {
    await tester.pumpWidget(app());
    await tester.pump();
    await settleDb(tester);
    tester.takeException(); // Home, which these tests aren't measuring.
    GoRouter.of(tester.element(find.byType(Scaffold).first)).go(path);
    await settleDb(tester);
    await tester.pumpAndSettle();
  }

  Future<({String grandpa, String laila})> family(WidgetTester tester) async =>
      (await tester.runAsync(() async {
        final grandpa = await db.addProfile('جدو');
        final laila = await db.addProfile('ليلى');
        return (grandpa: grandpa, laila: laila);
      }))!;

  Future<List<Medicine>> medicinesOf(
    WidgetTester tester,
    String person,
  ) async => (await tester.runAsync(() => db.watchMedicines(person).first))!;

  Future<void> acceptTime(WidgetTester tester) async {
    final ok = MaterialLocalizations.of(tester.element(find.byType(Dialog)))
        .okButtonLabel;
    await tester.tap(find.text(ok));
    await tester.pumpAndSettle();
  }

  testWidgets('the banner names the person and Save does too', (tester) async {
    phone(tester);
    final ids = await family(tester);
    await go(tester, '/family/${ids.grandpa}/medicines/new');

    expect(find.text('الدوا ده لجدو'), findsOneWidget);
    expect(key('medicine-person-change'), findsOneWidget);
    expect(find.text('احفظ لجدو'), findsOneWidget);

    await tapKey(tester, 'medicine-add-time');
    await acceptTime(tester);
    expect(find.text('احفظ لجدو وفكّرني'), findsOneWidget);
    await tester.tap(key('medicine-time-remove-08:00'));
    await tester.pumpAndSettle();
    expect(find.text('احفظ لجدو'), findsOneWidget);
  });

  testWidgets('a new medicine can go to someone else, and says so', (
    tester,
  ) async {
    phone(tester);
    final ids = await family(tester);
    await go(tester, '/family/${ids.grandpa}/medicines/new');

    await tapKey(tester, 'medicine-person');
    expect(find.text('الدوا ده لمين؟'), findsOneWidget);
    await tapKey(tester, 'medicine-person-pick-${ids.laila}');
    expect(find.text('الدوا ده لليلى'), findsOneWidget);
    expect(find.text('احفظ لليلى'), findsOneWidget);

    await tester.enterText(key('medicine-name'), 'شراب الحديد');
    await tapKey(tester, 'medicine-save');
    expect(await medicinesOf(tester, ids.grandpa), isEmpty);
    expect((await medicinesOf(tester, ids.laila)).single.name, 'شراب الحديد');
    await settleDb(tester);
    expect(find.text('اتحفظ: شراب الحديد لـليلى'), findsOneWidget);
    expect(
      GoRouter.of(tester.element(find.byType(Scaffold).first)).state.uri.path,
      startsWith('/family/${ids.laila}/medicines/'),
    );
  });

  testWidgets('a saved medicine stays with its person', (tester) async {
    phone(tester);
    final ids = await family(tester);
    final id = (await tester.runAsync(
      () => db.saveMedicine(
        profileId: ids.grandpa,
        name: 'كونكور',
        startOn: DateTime(2026, 11, 1),
      ),
    ))!;
    await tester.pumpWidget(app());
    await tester.pump();
    await settleDb(tester);
    GoRouter.of(tester.element(find.byType(Scaffold).first))
        .go('/family/${ids.grandpa}/medicines/$id/edit');
    for (var i = 0; i < 50; i++) {
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 20));
      if (find.byType(TextField).evaluate().isNotEmpty) break;
    }
    await tester.pumpAndSettle();

    expect(find.text('الدوا ده لجدو'), findsOneWidget);
    expect(key('medicine-person-change'), findsNothing);
    await tester.tap(key('medicine-person'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('الدوا ده لمين؟'), findsNothing);
  });

  testWidgets('with one person there is nothing to change', (tester) async {
    phone(tester);
    final only = (await tester.runAsync(() => db.addProfile('جدو')))!;
    await go(tester, '/family/$only/medicines/new');
    expect(key('medicine-person-change'), findsNothing);
  });

  testWidgets('the form has no tab bar to lose it to, and closes', (
    tester,
  ) async {
    phone(tester);
    final ids = await family(tester);
    await go(tester, '/family/${ids.grandpa}/medicines/new');
    expect(key('tab-/medicines'), findsNothing);

    await tapKey(tester, 'medicine-close');
    expect(find.text('أدوية جدو'), findsOneWidget);
    expect(key('tab-/medicines'), findsOneWidget);
  });

  testWidgets('frequency lays out times the family can change', (tester) async {
    phone(tester);
    final ids = await family(tester);
    await go(tester, '/family/${ids.grandpa}/medicines/new');
    await tester.enterText(key('medicine-name'), 'جلوكوفاج');
    // Nothing is chosen for the family: no reminder until they ask for one.
    expect(key('medicine-time-08:00'), findsNothing);

    await tapKey(tester, 'medicine-frequency-once');
    expect(key('medicine-time-08:00'), findsOneWidget);

    await tapKey(tester, 'medicine-frequency-thrice');
    for (final t in ['08:00', '14:00', '20:00']) {
      expect(key('medicine-time-$t'), findsOneWidget);
    }

    await tapKey(tester, 'medicine-frequency-as-needed');
    expect(key('medicine-time-08:00'), findsNothing);
    expect(find.text('احفظ لجدو'), findsOneWidget);

    await tapKey(tester, 'medicine-frequency-every-hours');
    await tapKey(tester, 'rx-hours-ok');
    for (final t in ['00:00', '08:00', '16:00']) {
      expect(key('medicine-time-$t'), findsOneWidget);
    }

    await tapKey(tester, 'medicine-frequency-twice');
    expect(key('medicine-time-08:00'), findsOneWidget);
    expect(key('medicine-time-20:00'), findsOneWidget);

    // Tap a time to change it; 8:00 stays as the picker opens on it, so a
    // change to a time already there does nothing.
    await tapKey(tester, 'medicine-time-change-08:00');
    await acceptTime(tester);
    expect(key('medicine-time-08:00'), findsOneWidget);

    await tapKey(tester, 'medicine-save');
    final m = (await medicinesOf(tester, ids.grandpa)).single;
    final s = (await tester.runAsync(() => db.watchDoseSchedule(m.id).first))!;
    expect(s.times, '08:00,20:00');
    expect(scheduler.requests, 0);
  });

  testWidgets('dose is saved word for word; an edit finds it there', (
    tester,
  ) async {
    phone(tester);
    final ids = await family(tester);
    await go(tester, '/family/${ids.grandpa}/medicines/new');
    expect(find.text('الجرعة زي ما الدكتور كتبها'), findsOneWidget);
    await tester.enterText(key('medicine-name'), 'جلوكوفاج');
    await tester.enterText(key('medicine-instructions'), 'حباية بعد الغدا');
    await tapKey(tester, 'medicine-save');
    final m = (await medicinesOf(tester, ids.grandpa)).single;
    expect(m.instructions, 'حباية بعد الغدا');
  });

  group('dates', () {
    Future<void> choose(WidgetTester tester, DateTime date) async {
      Navigator.of(tester.element(find.byType(DatePickerDialog))).pop(date);
      await tester.pumpAndSettle();
    }

    testWidgets(
      'a last day comes from a date picker that starts at the first',
      (tester) async {
        phone(tester);
        final ids = await family(tester);
        await go(tester, '/family/${ids.grandpa}/medicines/new');
        await tester.enterText(key('medicine-name'), 'أموكسيسيلين');
        expect(key('medicine-end'), findsNothing);

        await tapKey(tester, 'medicine-duration-until');
        final picker = tester.widget<DatePickerDialog>(
          find.byType(DatePickerDialog),
        );
        expect(DateUtils.isSameDay(picker.firstDate, now), isTrue);
        await choose(tester, DateTime(2026, 11, 10));
        expect(key('medicine-end'), findsOneWidget);

        await tapKey(tester, 'medicine-save');
        final m = (await medicinesOf(tester, ids.grandpa)).single;
        expect(m.endOn, isNotNull);
      },
    );

    testWidgets('leaving the picker keeps it ongoing', (tester) async {
      phone(tester);
      final ids = await family(tester);
      await go(tester, '/family/${ids.grandpa}/medicines/new');
      await tapKey(tester, 'medicine-duration-until');
      await tester.tap(
        find.text(
          MaterialLocalizations.of(
            tester.element(find.byType(DatePickerDialog)),
          ).cancelButtonLabel,
        ),
      );
      await tester.pumpAndSettle();
      expect(key('medicine-end'), findsNothing);
    });

    testWidgets('a first day moved past the last day is refused', (
      tester,
    ) async {
      phone(tester);
      final ids = await family(tester);
      await go(tester, '/family/${ids.grandpa}/medicines/new');
      await tester.enterText(key('medicine-name'), 'أموكسيسيلين');
      await tapKey(tester, 'medicine-duration-until');
      await choose(tester, DateTime(2026, 11, 10));

      await tapKey(tester, 'medicine-start');
      await choose(tester, DateTime(2026, 11, 20));
      expect(find.text('آخر يوم قبل أول يوم'), findsOneWidget);

      await tapKey(tester, 'medicine-save');
      expect(await medicinesOf(tester, ids.grandpa), isEmpty);

      // Ongoing clears it.
      await tapKey(tester, 'medicine-duration-ongoing');
      expect(find.text('آخر يوم قبل أول يوم'), findsNothing);
      await tapKey(tester, 'medicine-save');
      expect(await medicinesOf(tester, ids.grandpa), hasLength(1));
    });
  });

  group('scan', () {
    /// Scans a box from the form and returns to it.
    Future<void> scan(WidgetTester tester, List<String> lines) async {
      ocr.result = ocrOf(lines);
      await tapKey(tester, 'medicine-scan');
      await tapKey(tester, 'scan-camera');
      await settleDb(tester);
      await tester.pumpAndSettle();
      await tapKey(tester, 'scan-use');
    }

    testWidgets('saves nothing, sets no reminder, until it is confirmed', (
      tester,
    ) async {
      phone(tester);
      final ids = await family(tester);
      await go(tester, '/family/${ids.grandpa}/medicines/new');

      await scan(tester, ['Panadol 500mg']);
      expect(find.text('اتقرا من صورة العلبة'), findsOneWidget);
      TextField field(String k) => tester.widget(key('medicine-$k'));
      expect(field('name').controller!.text, 'Panadol');
      expect(field('strength').controller!.text, '500mg');
      // Read cleanly, so nothing is highlighted, but it still has to be checked.
      expect(key('medicine-name-unsure'), findsNothing);
      expect(key('medicine-strength-unsure'), findsNothing);

      await tapKey(tester, 'medicine-frequency-once');
      await tapKey(tester, 'medicine-save');
      expect(await medicinesOf(tester, ids.grandpa), isEmpty);
      expect((await tester.runAsync(() => db.watchRegimens().first))!, isEmpty);
      expect(key('medicine-scan-confirm-needed'), findsOneWidget);

      await tapKey(tester, 'medicine-scan-confirm');
      expect(key('medicine-scan-confirm-needed'), findsNothing);
      await tapKey(tester, 'medicine-save');
      final m = (await medicinesOf(tester, ids.grandpa)).single;
      expect(m.name, 'Panadol');
      expect(m.strength, '500mg');
      final regimens = (await tester.runAsync(() => db.watchRegimens().first))!;
      expect(regimens, hasLength(1));
    });

    testWidgets('a new scan has to be confirmed again', (tester) async {
      phone(tester);
      final ids = await family(tester);
      await go(tester, '/family/${ids.grandpa}/medicines/new');
      await scan(tester, ['Panadol 500mg']);
      await tapKey(tester, 'medicine-scan-confirm');

      await scan(tester, ['Concor 5mg']);
      final box = tester.widget<CheckboxListTile>(key('medicine-scan-confirm'));
      expect(box.value, isFalse);
      await tapKey(tester, 'medicine-save');
      expect(await medicinesOf(tester, ids.grandpa), isEmpty);
    });

    testWidgets('unsure values are highlighted until they are corrected', (
      tester,
    ) async {
      phone(tester);
      final ids = await family(tester);
      await go(tester, '/family/${ids.grandpa}/medicines/new');

      // A near match, with its strength on the next line.
      await scan(tester, ['Panadoi', '500mg']);
      TextField field(String k) => tester.widget(key('medicine-$k'));
      expect(field('name').controller!.text, 'Panadol');
      expect(key('medicine-name-unsure'), findsOneWidget);
      expect(key('medicine-strength-unsure'), findsOneWidget);
      expect(
        find.text('مش متأكدين من القراية، راجعها على العلبة'),
        findsNWidgets(2),
      );

      await tester.enterText(key('medicine-strength'), '1g');
      await tester.pumpAndSettle();
      expect(key('medicine-strength-unsure'), findsNothing);
      expect(key('medicine-name-unsure'), findsOneWidget);
      // Correcting a value isn't the same as confirming the reading.
      await tapKey(tester, 'medicine-save');
      expect(await medicinesOf(tester, ids.grandpa), isEmpty);
    });

    testWidgets('a strength it could not read asks for one', (tester) async {
      phone(tester);
      final ids = await family(tester);
      await go(tester, '/family/${ids.grandpa}/medicines/new');
      await tester.enterText(key('medicine-strength'), '20mg');
      await scan(tester, ['Concor']);
      TextField field(String k) => tester.widget(key('medicine-$k'));
      // The old strength doesn't stay beside the new name.
      expect(field('strength').controller!.text, isEmpty);
      expect(key('medicine-strength-unsure'), findsOneWidget);
    });
  });

  testWidgets('no dose hint the family did not enter', (tester) async {
    phone(tester);
    final ids = await family(tester);
    await go(tester, '/family/${ids.grandpa}/medicines/new');
    await tapKey(tester, 'medicine-more');
    await tapKey(tester, 'medicine-frequency-once');
    expect(find.textContaining('مثلاً'), findsNothing);

    final ar = AppLocalizationsAr();
    final en = AppLocalizationsEn();
    for (final hint in [
      ar.medicineAmountHint,
      ar.prescriptionDoseHint,
      ar.prescriptionTimesHint,
      ar.scanMedicineStrength,
    ]) {
      expect(hint, isNot(contains('مثلاً')));
      expect(hint, isNot(matches(RegExp(r'[0-9٠-٩]'))));
    }
    for (final hint in [
      en.medicineAmountHint,
      en.prescriptionDoseHint,
      en.prescriptionTimesHint,
      en.scanMedicineStrength,
    ]) {
      expect(hint, isNot(contains('e.g.')));
      expect(hint, isNot(matches(RegExp(r'[0-9]'))));
    }
  });

  group('fits', () {
    for (final (width, scale) in [
      (320.0, 1.0),
      (320.0, 2.0),
      (375.0, 2.0),
      (430.0, 1.0),
      (430.0, 2.0),
    ]) {
      testWidgets('$width px wide at text ×$scale, everything open', (
        tester,
      ) async {
        phone(tester, width: width, scale: scale);
        final ids = await family(tester);
        await go(tester, '/family/${ids.grandpa}/medicines/new');
        await tester.enterText(key('medicine-instructions'), 'كل 8 ساعات');
        await tapKey(tester, 'medicine-frequency-thrice');
        await tapKey(tester, 'medicine-more');
        await tapKey(tester, 'medicine-repeat-weekdays');
        await reveal(tester, 'medicine-min-hours-suggestion');
        expect(tester.takeException(), isNull);
        await reveal(tester, 'medicine-photo-camera');
        await reveal(tester, 'medicine-save');
        expect(key('medicine-save'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('a small phone keeps Save pinned at normal text', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 2;
      tester.view.physicalSize = const Size(640, 1136);
      addTearDown(tester.view.reset);
      final ids = await family(tester);
      await go(tester, '/family/${ids.grandpa}/medicines/new');
      final bottom = tester.getBottomRight(key('medicine-save')).dy;
      expect(bottom, lessThanOrEqualTo(568));
      expect(bottom, greaterThan(480));
      expect(tester.takeException(), isNull);
    });

    testWidgets('in English, left to right', (tester) async {
      phone(tester, width: 320, scale: 2);
      final ids = await family(tester);
      await go(tester, '/family/${ids.grandpa}/medicines/new');
      ProviderScope.containerOf(
        tester.element(find.byType(Scaffold).first),
        listen: false,
      ).read(localeProvider.notifier).change(const Locale('en'));
      await settleDb(tester);
      await tester.pumpAndSettle();
      expect(find.text('This medicine is for جدو'), findsOneWidget);
      await reveal(tester, 'medicine-save');
      expect(find.text('Save for جدو'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('in dark mode', (tester) async {
      phone(tester, width: 320, scale: 2);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      final ids = await family(tester);
      await go(tester, '/family/${ids.grandpa}/medicines/new');
      await tapKey(tester, 'medicine-more');
      expect(tester.takeException(), isNull);
    });

    testWidgets('in Simple Mode, with bigger targets', (tester) async {
      phone(tester, width: 320, scale: 2);
      final ids = await family(tester);
      await tester.pumpWidget(app(simple: true));
      await tester.pump();
      await settleDb(tester);
      GoRouter.of(tester.element(find.byType(Scaffold).first))
          .go('/family/${ids.grandpa}/medicines/new');
      await settleDb(tester);
      await tester.pumpAndSettle();
      await tapKey(tester, 'medicine-more');
      expect(
        tester.getSize(key('medicine-frequency-once')).height,
        greaterThanOrEqualTo(64),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('every control is at least 48 tall', (tester) async {
      phone(tester);
      final ids = await family(tester);
      await go(tester, '/family/${ids.grandpa}/medicines/new');
      await tapKey(tester, 'medicine-frequency-once');
      for (final k in [
        'medicine-person',
        'medicine-scan',
        'medicine-frequency-once',
        'medicine-add-time',
        'medicine-time-change-08:00',
        'medicine-time-remove-08:00',
        'medicine-duration-ongoing',
        'medicine-more',
        'medicine-save',
        'medicine-close',
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
