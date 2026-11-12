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
import 'package:usra/features/medicines/dose_schedule.dart';
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
    dir = Directory.systemTemp.createTempSync('usra_prescriptions');
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
    tester.view.physicalSize = const Size(1170, 6000);
    tester.view.devicePixelRatio = 1.5;
    addTearDown(tester.view.reset);
  }

  /// Waits for a form that loads from the database (real time).
  Future<void> waitForForm(WidgetTester tester) async {
    await tester.pump();
    for (var i = 0; i < 50; i++) {
      if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
    await tester.pumpAndSettle();
  }

  Finder inside(String key, String text) =>
      find.descendant(of: find.byKey(ValueKey(key)), matching: find.text(text));

  testWidgets('a prescription with two medicines, reminders in one save', (
    tester,
  ) async {
    tallScreen(tester);
    scheduler.granted = const ReminderAccess(notifications: false);
    scheduler.afterRequest = const ReminderAccess(notifications: true);
    final omar = (await tester.runAsync(() async {
      await db.saveDoctor(name: 'د. هالة');
      return db.addProfile('عمر');
    }))!;
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.byType(Scaffold).first))
        .go('/family/$omar/medicines');
    await tester.pumpAndSettle();

    await tapKey(tester, 'prescription-add');
    expect(find.text('روشتة جديدة'), findsOneWidget);
    // Says plainly that the app doesn't advise on doses.
    expect(find.textContaining('عمرها ما بتقترح'), findsOneWidget);

    // A medicine needs a name and a number of days.
    await tapKey(tester, 'rx-save');
    expect(find.text('مطلوب'), findsOneWidget);
    expect(find.text('اكتب عدد أيام، ١ أو أكتر'), findsOneWidget);

    await tapKey(tester, 'rx-doctor');
    await tester.tap(find.text('د. هالة').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('rx-diagnosis')),
      'التهاب لوز',
    );
    await tester.enterText(
      find.byKey(const ValueKey('rx-item-0-name')),
      'أموكسيسيلين',
    );
    await tester.enterText(
      find.byKey(const ValueKey('rx-item-0-dose')),
      '5 مل بعد الأكل',
    );
    await tapKey(tester, 'rx-item-0-per-day-3');
    expect(find.byKey(const ValueKey('rx-item-0-time-14:00')), findsOneWidget);
    // The doctor wrote "every 8 hours": lay that out from 08:00 instead.
    expect(find.textContaining('اتأكد إن المواعيد'), findsWidgets);
    await tapKey(tester, 'rx-item-0-every-hours');
    expect(find.text('كل ٨ ساعات'), findsOneWidget);
    await tapKey(tester, 'rx-hours-ok');
    for (final t in ['00:00', '08:00', '16:00']) {
      expect(find.byKey(ValueKey('rx-item-0-time-$t')), findsOneWidget);
    }
    expect(find.byKey(const ValueKey('rx-item-0-time-14:00')), findsNothing);
    // Arabic digits are fine.
    await tester.enterText(find.byKey(const ValueKey('rx-item-0-days')), '٧');

    await tapKey(tester, 'rx-add-medicine');
    await tester.enterText(
      find.byKey(const ValueKey('rx-item-1-name')),
      'نقط أنف',
    );
    await tapKey(tester, 'rx-item-1-per-day-2');
    await tester.ensureVisible(find.byKey(const ValueKey('rx-item-1-ongoing')));
    await tester.tap(inside('rx-item-1-ongoing', 'مستمر'));
    await tester.pumpAndSettle();

    await tapKey(tester, 'rx-photo-camera');
    expect(find.byKey(const ValueKey('rx-photo-preview-0')), findsOneWidget);
    await tapKey(tester, 'rx-save');

    final p = (await tester.runAsync(() => db.watchPrescriptions(omar).first))!
        .single;
    expect(p.diagnosis, 'التهاب لوز');
    expect(p.prescribedOn.toUtc(), DateTime.utc(2026, 11, 3));
    final photo = decodeMedicinePhotos(p.photosJson).single;
    expect(photos.fileOf(photo).existsSync(), isTrue);
    expect(picked.existsSync(), isFalse);
    final meds = (await tester.runAsync(
      () => db.watchPrescriptionMedicines(p.id).first,
    ))!;
    expect(meds.map((m) => m.name), ['أموكسيسيلين', 'نقط أنف']);
    expect(meds.first.instructions, '5 مل بعد الأكل');
    expect(meds.first.endOn!.toUtc(), DateTime.utc(2026, 11, 9));
    expect(meds.last.endOn, isNull);
    expect(meds.every((m) => m.doctorId == p.doctorId), isTrue);
    final regimens = (await tester.runAsync(() => db.watchRegimens().first))!;
    expect(regimens, hasLength(2));
    expect(scheduler.requests, 1);

    // The prescription's page: the course so far.
    expect(find.textContaining('روشتة'), findsWidgets);
    expect(find.text('د. هالة'), findsOneWidget);
    expect(
      inside('rx-course-${meds.first.id}', 'اليوم ١ من ٧'),
      findsOneWidget,
    );

    // On the medicine's page, with a way back to the prescription.
    await tapKey(tester, 'rx-medicine-${meds.first.id}');
    expect(find.byKey(const ValueKey('medicine-course')), findsOneWidget);
    expect(find.text('اليوم ١ من ٧'), findsOneWidget);
    await tapKey(tester, 'medicine-prescription');
    expect(find.byKey(const ValueKey('rx-toggle-active')), findsOneWidget);

    // Today's doses say how far the course has gone.
    await tester.tap(find.text('الأدوية').last);
    await tester.pumpAndSettle();
    final at = DateTime(2026, 11, 3, 16).millisecondsSinceEpoch;
    expect(
      find.byKey(ValueKey('dose-course-${meds.first.id}-$at')),
      findsOneWidget,
    );
    expect(find.text('5 مل بعد الأكل'), findsWidgets);
  });

  testWidgets('edit, stop and delete a prescription', (tester) async {
    tallScreen(tester);
    final ids = (await tester.runAsync(() async {
      final omar = await db.addProfile('عمر');
      final photo = await photos.import(picked.path);
      final rx = await db.savePrescription(
        profileId: omar,
        prescribedOn: DateTime(2026, 11, 1),
        diagnosis: 'برد',
        photos: [photo],
        items: const [
          PrescriptionItemInput(
            name: 'باراسيتامول',
            dose: '5 مل',
            times: ['08:00', '20:00'],
            days: 5,
          ),
          PrescriptionItemInput(name: 'فيتامين سي', times: ['09:00']),
        ],
      );
      return (omar: omar, rx: rx, photo: photo);
    }))!;
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
    router.go('/family/${ids.omar}/medicines');
    await tester.pumpAndSettle();
    // Listed on the person's medicines, with its medicines' courses.
    expect(find.byKey(ValueKey('prescription-${ids.rx}')), findsOneWidget);
    expect(find.textContaining('دوايين'), findsOneWidget);
    expect(find.text('اليوم ٣ من ٥'), findsOneWidget);

    await tapKey(tester, 'prescription-${ids.rx}');
    await tester.tap(find.byKey(const ValueKey('rx-edit')));
    await waitForForm(tester);
    expect(find.text('باراسيتامول'), findsOneWidget);
    expect(find.byKey(const ValueKey('rx-item-0-time-20:00')), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.byKey(const ValueKey('rx-photo-preview-0')), findsOneWidget);

    // Two more days, and the vitamin taken off.
    await tester.enterText(find.byKey(const ValueKey('rx-item-0-days')), '7');
    await tapKey(tester, 'rx-item-1-remove');
    // A saved medicine: ask, and say its history stays.
    expect(find.textContaining('سجل جرعاته هيفضل'), findsOneWidget);
    await tapKey(tester, 'rx-remove-confirm');
    expect(find.byKey(const ValueKey('rx-item-1-name')), findsNothing);
    await tapKey(tester, 'rx-save');
    final meds = (await tester.runAsync(
      () => db.watchPrescriptionMedicines(ids.rx).first,
    ))!;
    expect(meds.single.name, 'باراسيتامول');
    expect(meds.single.endOn!.toUtc(), DateTime.utc(2026, 11, 7));
    await tester.pumpAndSettle();
    expect(
      inside('rx-course-${meds.single.id}', 'اليوم ٣ من ٧'),
      findsOneWidget,
    );

    // Stop: no more reminders; resume brings them back.
    await tapKey(tester, 'rx-toggle-active');
    expect(await tester.runAsync(() => db.watchRegimens().first), isEmpty);
    await tester.pumpAndSettle();
    expect(find.text('وقّف الروشتة كلها'), findsNothing);
    // A prescription (روشتة) is feminine: متوقفة. Its medicines (دوا)
    // stay متوقف.
    expect(find.text('متوقفة'), findsWidgets);
    await tapKey(tester, 'rx-toggle-active');
    expect(await tester.runAsync(() => db.watchRegimens().first), hasLength(1));
    await tester.pumpAndSettle();

    await tapKey(tester, 'rx-delete');
    await tapKey(tester, 'rx-delete-confirm');
    expect(find.text('أدوية عمر'), findsOneWidget);
    expect(
      await tester.runAsync(() => db.watchPrescriptions(ids.omar).first),
      isEmpty,
    );
    // The medicine taken off earlier is still there, stopped, with its page.
    final left = (await tester.runAsync(
      () => db.watchMedicines(ids.omar).first,
    ))!;
    expect(left.single.name, 'فيتامين سي');
    expect(left.single.active, isFalse);
    expect(photos.fileOf(ids.photo).existsSync(), isFalse);
  });

  testWidgets('a new date moves running courses, never ended ones', (
    tester,
  ) async {
    tallScreen(tester);
    final ids = (await tester.runAsync(() async {
      final omar = await db.addProfile('عمر');
      final rx = await db.savePrescription(
        profileId: omar,
        prescribedOn: DateTime(2026, 11, 1),
        items: const [
          // Ended on 1 November.
          PrescriptionItemInput(name: 'حقنة', times: ['10:00'], days: 1),
          PrescriptionItemInput(name: 'شراب', times: ['20:00'], days: 7),
        ],
      );
      return (omar: omar, rx: rx);
    }))!;
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.byType(Scaffold).first))
        .go('/family/${ids.omar}/prescriptions/${ids.rx}/edit');
    await waitForForm(tester);

    await tapKey(tester, 'rx-date');
    final picker = find.byType(Dialog);
    final two = find.descendant(
      of: picker,
      matching: find.text(find.text('٢').evaluate().isNotEmpty ? '٢' : '2'),
    );
    await tester.tap(two.last);
    await tester.pumpAndSettle();
    final ok = MaterialLocalizations.of(tester.element(picker)).okButtonLabel;
    await tester.tap(find.descendant(of: picker, matching: find.text(ok)));
    await tester.pumpAndSettle();
    // Asked first.
    expect(find.text('تنقل مواعيد العلاج كمان؟'), findsOneWidget);
    await tapKey(tester, 'rx-move-courses');
    await tapKey(tester, 'rx-save');

    final p = (await tester.runAsync(
      () => db.watchPrescription(ids.rx).first,
    ))!;
    expect(p.prescribedOn.toUtc(), DateTime.utc(2026, 11, 2));
    final [ended, running] = (await tester.runAsync(
      () => db.watchPrescriptionMedicines(ids.rx).first,
    ))!;
    expect(ended.startOn.toUtc(), DateTime.utc(2026, 11, 1));
    expect(ended.endOn!.toUtc(), DateTime.utc(2026, 11, 1));
    expect(running.startOn.toUtc(), DateTime.utc(2026, 11, 2));
    expect(running.endOn!.toUtc(), DateTime.utc(2026, 11, 8));
    // Today (3 November) only the running course has a dose.
    final regimens = (await tester.runAsync(() => db.watchRegimens().first))!;
    final today = plannedDoses(
      regimens,
      const [],
      from: DateTime(2026, 11, 3),
      to: DateTime(2026, 11, 10),
    );
    expect(today.map((d) => d.regimen.medicine.name).toSet(), {'شراب'});
  });

  testWidgets('in Simple Mode, today\'s doses show the course day', (
    tester,
  ) async {
    tallScreen(tester);
    await tester.runAsync(() async {
      final dad = await db.addProfile('بابا');
      await db.savePrescription(
        profileId: dad,
        prescribedOn: DateTime(2026, 11, 2),
        items: const [
          PrescriptionItemInput(name: 'أوجمنتين', times: ['21:00'], days: 7),
        ],
      );
    });
    await tester.pumpWidget(app(simple: true));
    await tester.pumpAndSettle();
    await tapKey(tester, 'simple-medicines');
    expect(find.text('أوجمنتين'), findsOneWidget);
    expect(find.text('اليوم ٢ من ٧'), findsOneWidget);
  });
}
