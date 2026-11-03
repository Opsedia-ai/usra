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
  late File picked;
  late SyncPhotoStore photos;
  late FakeReminderScheduler scheduler;
  final now = DateTime(2026, 11, 3, 9, 30);

  setUp(() {
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    dir = Directory.systemTemp.createTempSync('usra_medicines');
    picked = File('${dir.path}/picked.jpg')..writeAsBytesSync([0, 1, 2]);
    photos = SyncPhotoStore(
      Directory('${dir.path}/support'),
      PhotoStore.medicinesFolder,
    );
    scheduler = FakeReminderScheduler();
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
      medicinePhotoStoreProvider.overrideWithValue(photos),
      reminderSchedulerProvider.overrideWithValue(scheduler),
      clockProvider.overrideWithValue(() => now),
      photoPickerProvider.overrideWithValue((_) async => picked.path),
    ],
    child: const UsraApp(),
  );

  Future<void> tapKey(WidgetTester tester, String key) async {
    await tester.ensureVisible(find.byKey(ValueKey(key)));
    await tester.tap(find.byKey(ValueKey(key)));
    await tester.pumpAndSettle();
  }

  void tallScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1170, 3600);
    tester.view.devicePixelRatio = 1.5;
    addTearDown(tester.view.reset);
  }

  testWidgets('today\'s doses for the family; mark one taken, then undo', (
    tester,
  ) async {
    tallScreen(tester);
    // Database calls outside the widgets run on real time, not fake time.
    final ids = (await tester.runAsync(() async {
      final omar = await db.addProfile('عمر');
      final mona = await db.addProfile('منى');
      final panadol = await db.saveMedicine(
        profileId: omar,
        name: 'باراسيتامول',
        strength: '500 مجم',
        startOn: DateTime(2026, 11, 1),
        schedule: const DoseScheduleInput(
          times: ['08:00', '20:00'],
          amount: 'قرص واحد',
        ),
      );
      await db.saveMedicine(
        profileId: mona,
        name: 'ميتفورمين',
        startOn: DateTime(2026, 11, 1),
        schedule: const DoseScheduleInput(times: ['08:00']),
      );
      // Every other day from tomorrow: nothing today.
      await db.saveMedicine(
        profileId: mona,
        name: 'فيتامين د',
        startOn: DateTime(2026, 11, 4),
        schedule: const DoseScheduleInput(times: ['08:00'], everyNDays: 2),
      );
      return (omar: omar, panadol: panadol);
    }))!;
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('الأدوية').last);
    await tester.pumpAndSettle();
    expect(find.text('أدوية النهارده'), findsOneWidget);
    expect(find.text('باراسيتامول 500 مجم'), findsNWidgets(2));
    expect(find.text('ميتفورمين'), findsOneWidget);
    expect(find.text('فيتامين د'), findsNothing);
    expect(find.text('قرص واحد'), findsNWidgets(2));

    final eight = DateTime(2026, 11, 3, 8);
    final key = '${ids.panadol}-${eight.millisecondsSinceEpoch}';
    await tapKey(tester, 'dose-taken-$key');
    final log = (await tester.runAsync(
      () => db.watchMedicineDoseLogs(ids.panadol).first,
    ))!.single;
    expect(log.status, DoseOutcome.taken);
    expect(log.scheduledAt.isAtSameMomentAs(eight), isTrue);
    expect(log.at.isAtSameMomentAs(now), isTrue);
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('dose-taken-$key')), findsNothing);
    expect(find.textContaining('اتاخد الساعة'), findsOneWidget);

    await tapKey(tester, 'dose-undo-$key');
    expect(
      await tester.runAsync(() => db.watchMedicineDoseLogs(ids.panadol).first),
      isEmpty,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('dose-taken-$key')), findsOneWidget);
  });

  testWidgets('add a medicine with a photo and a time from a person\'s page', (
    tester,
  ) async {
    tallScreen(tester);
    scheduler.granted = const ReminderAccess(notifications: false);
    scheduler.afterRequest = const ReminderAccess(
      notifications: true,
      exactAlarms: false,
    );
    final omar = (await tester.runAsync(() => db.addProfile('عمر')))!;
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.byType(Scaffold).first))
        .go('/family/$omar');
    await tester.pumpAndSettle();

    await tapKey(tester, 'member-medicines');
    expect(find.text('أدوية عمر'), findsOneWidget);
    await tapKey(tester, 'medicine-add');
    // The medicine needs a name.
    await tapKey(tester, 'medicine-save');
    expect(find.text('مطلوب'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('medicine-name')),
      'أموكسيسيلين',
    );
    await tester.enterText(
      find.byKey(const ValueKey('medicine-instructions')),
      'كل 8 ساعات لمدة أسبوع',
    );
    await tapKey(tester, 'medicine-form-capsule');
    await tapKey(tester, 'medicine-photo-camera');
    expect(
      find.byKey(const ValueKey('medicine-photo-preview-0')),
      findsOneWidget,
    );

    await tapKey(tester, 'medicine-add-time');
    // The time picker opens at 08:00; accept it.
    final ok = MaterialLocalizations.of(tester.element(find.byType(Dialog)))
        .okButtonLabel;
    await tester.tap(find.text(ok));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('medicine-time-08:00')), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('medicine-amount')),
      'كبسولة',
    );
    await tapKey(tester, 'medicine-save');

    final m = (await tester.runAsync(() => db.watchMedicines(omar).first))!
        .single;
    expect(m.name, 'أموكسيسيلين');
    expect(m.form, 'capsule');
    expect(m.instructions, 'كل 8 ساعات لمدة أسبوع');
    final stored = decodeMedicinePhotos(m.photosJson).single;
    expect(photos.fileOf(stored).existsSync(), isTrue);
    expect(picked.existsSync(), isFalse);
    final s = (await tester.runAsync(() => db.watchDoseSchedule(m.id).first))!;
    expect(s.times, '08:00');
    expect(s.amount, 'كبسولة');
    // Saving times asked to show notifications.
    expect(scheduler.requests, 1);

    // On the medicine's page.
    expect(find.text('كل 8 ساعات لمدة أسبوع'), findsOneWidget);
    expect(find.textContaining('الجرعة الجاية'), findsOneWidget);

    // Exact alarms still off: the Medicines tab asks for them.
    await tester.tap(find.text('الأدوية').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('reminders-off')), findsOneWidget);
    scheduler.afterRequest = const ReminderAccess(notifications: true);
    await tester.tap(find.text('اسمح'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('reminders-off')), findsNothing);
  });

  testWidgets('Simple Mode\'s "My medicines" opens today\'s doses', (
    tester,
  ) async {
    tallScreen(tester);
    await tester.runAsync(() async {
      final dad = await db.addProfile('بابا');
      await db.saveMedicine(
        profileId: dad,
        name: 'كونكور',
        startOn: DateTime(2026, 11, 1),
        schedule: const DoseScheduleInput(times: ['08:00']),
      );
    });
    await tester.pumpWidget(app(simple: true));
    await tester.pumpAndSettle();

    await tapKey(tester, 'simple-medicines');
    expect(find.text('أدوية النهارده'), findsOneWidget);
    expect(find.text('كونكور'), findsOneWidget);
  });

  testWidgets('edit keeps the weekdays and photos; delete removes them', (
    tester,
  ) async {
    tallScreen(tester);
    final ids = (await tester.runAsync(() async {
      final omar = await db.addProfile('عمر');
      final photo = await photos.import(picked.path);
      final id = await db.saveMedicine(
        profileId: omar,
        name: 'ميثوتريكسات',
        startOn: DateTime(2026, 11, 1),
        photos: [photo],
        // Monday and Thursday.
        schedule: const DoseScheduleInput(
          times: ['09:00'],
          weekdays: 1 << 0 | 1 << 3,
          amount: '4 أقراص',
        ),
      );
      return (omar: omar, id: id, photo: photo);
    }))!;
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
    router.go('/family/${ids.omar}/medicines/${ids.id}');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('medicine-edit')));
    await tester.pump();
    // The form loads the medicine from the database, which needs real time;
    // its spinner never lets pumpAndSettle finish meanwhile.
    for (var i = 0; i < 50; i++) {
      if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
    await tester.pumpAndSettle();

    FilterChip day(int i) =>
        tester.widget(find.byKey(ValueKey('medicine-weekday-$i')));
    expect(day(0).selected, isTrue);
    expect(day(1).selected, isFalse);
    expect(day(3).selected, isTrue);
    expect(
      find.byKey(const ValueKey('medicine-photo-preview-0')),
      findsOneWidget,
    );

    // No day picked is refused.
    await tapKey(tester, 'medicine-weekday-0');
    await tapKey(tester, 'medicine-weekday-3');
    await tapKey(tester, 'medicine-save');
    expect(find.text('اختار يوم واحد على الأقل'), findsOneWidget);

    await tapKey(tester, 'medicine-weekday-3');
    await tapKey(tester, 'medicine-save');
    final s = (await tester.runAsync(
      () => db.watchDoseSchedule(ids.id).first,
    ))!;
    expect(s.weekdays, 1 << 3);
    expect(s.amount, '4 أقراص');
    final m = (await tester.runAsync(() => db.watchMedicine(ids.id).first))!;
    expect(decodeMedicinePhotos(m.photosJson), [ids.photo]);

    await tapKey(tester, 'medicine-toggle-active');
    expect(
      (await tester.runAsync(() => db.watchMedicine(ids.id).first))!.active,
      isFalse,
    );
    await tester.pumpAndSettle();
    expect(find.text('متوقف'), findsOneWidget);

    await tapKey(tester, 'medicine-delete');
    await tapKey(tester, 'medicine-delete-confirm');
    expect(find.text('أدوية عمر'), findsOneWidget);
    expect(photos.fileOf(ids.photo).existsSync(), isFalse);
  });
}
