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
import 'package:usra/features/account/save_gate.dart';
import 'package:usra/features/add/add_sheet.dart';
import 'package:usra/features/children/child_vaccines.dart';
import 'package:usra/features/follow_ups/follow_ups_providers.dart';
import 'package:usra/features/medicines/medicines_providers.dart';
import 'package:usra/features/medicines/reminders.dart';

import '../support/fake_ocr_service.dart';
import '../support/fake_reminder_scheduler.dart';
import '../support/sync_photo_store.dart';

void main() {
  late AppDatabase db;
  late Directory dir;
  late SyncPhotoStore photos;
  late FakeOcrService ocr;
  late MedicineNameExtractor names;
  late List<String> pickedPaths;
  final now = DateTime(2026, 11, 3, 9, 30);

  setUpAll(() {
    names = MedicineNameExtractor.fromList(
      File(MedicineNameExtractor.asset).readAsStringSync(),
    );
  });

  setUp(() {
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    dir = Directory.systemTemp.createTempSync('usra_doc_scan');
    photos = SyncPhotoStore(
      Directory('${dir.path}/support'),
      PhotoStore.medicinesFolder,
    );
    ocr = FakeOcrService(OcrResult.empty);
    pickedPaths = [];
  });
  tearDown(() async {
    await db.close();
    dir.deleteSync(recursive: true);
  });

  /// Each pick is a new plain temporary file, like the picker's.
  Future<String?> pick(_) async {
    final f = File('${dir.path}/picked-${pickedPaths.length}.jpg')
      ..writeAsBytesSync([0, 1, 2]);
    pickedPaths.add(f.path);
    return f.path;
  }

  Widget app({bool simple = false, SaveGate? gate}) => ProviderScope(
    overrides: [
      if (gate != null) saveGateProvider.overrideWithValue(gate),
      databaseProvider.overrideWithValue(db),
      keyValueStoreProvider.overrideWithValue(
        MemoryKeyValueStore({
          PrefKeys.tutorialSeen: true,
          PrefKeys.elderTutorialSeen: true,
          if (simple) PrefKeys.simpleMode: true,
        }),
      ),
      medicinePhotoStoreProvider.overrideWithValue(photos),
      reminderSchedulerProvider.overrideWithValue(
        FakeReminderScheduler(
          granted: const ReminderAccess(notifications: true),
        ),
      ),
      clockProvider.overrideWithValue(() => now),
      todayProvider.overrideWithValue(now),
      photoPickerProvider.overrideWithValue(pick),
      ocrServiceProvider.overrideWithValue(ocr),
      medicineNameExtractorProvider.overrideWith((ref) async => names),
    ],
    child: const UsraApp(),
  );

  Future<void> tapKey(WidgetTester tester, String key) async {
    final f = find.byKey(ValueKey(key));
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  void tallScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1170, 12000);
    tester.view.devicePixelRatio = 1.5;
    addTearDown(tester.view.reset);
  }

  String fieldText(WidgetTester tester, String key) =>
      tester.widget<TextField>(find.byKey(ValueKey(key))).controller!.text;

  bool enabled(WidgetTester tester, String key) =>
      tester.widget<ButtonStyleButton>(find.byKey(ValueKey(key))).enabled;

  Future<void> go(WidgetTester tester, String path, {SaveGate? gate}) async {
    await tester.pumpWidget(app(gate: gate));
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.byType(Scaffold).first)).go(path);
    await tester.pumpAndSettle();
  }

  group('prescription photo', () {
    testWidgets('fills the form; nothing saves until each part is checked', (
      tester,
    ) async {
      tallScreen(tester);
      final (omar, doctor) = (await tester.runAsync(() async {
        final doctor = await db.saveDoctor(name: 'Dr. Ahmed Samir');
        return (await db.addProfile('عمر'), doctor);
      }))!;
      ocr.result = ocrOf([
        'Dr. Ahmed Samir Mostafa',
        'Consultant of Pediatrics',
        'Date: 12/03/2026',
        'R/',
        '1- Augmentin 457mg/5ml susp',
        '5 ml every 12 hours for 7 days',
        '2- Cetal syrup',
        '5 ml 1x3 after meals',
        'Tel: 0123 456 7890',
      ]);
      await go(tester, '/family/$omar/prescriptions/new');

      await tapKey(tester, 'rx-scan-camera');
      expect(ocr.read, [pickedPaths.single]);
      expect(find.byKey(const ValueKey('rx-scan-result')), findsOneWidget);
      expect(find.textContaining('لقينا دوائين'), findsOneWidget);
      // The photo, to check against, and kept with the prescription.
      expect(find.byKey(const ValueKey('rx-scan-photo')), findsOneWidget);
      expect(find.byKey(const ValueKey('rx-photo-preview-0')), findsOneWidget);

      // The blank first medicine was replaced by what was read.
      expect(fieldText(tester, 'rx-item-0-name'), 'Augmentin');
      expect(fieldText(tester, 'rx-item-0-strength'), '457mg/5ml');
      expect(
        fieldText(tester, 'rx-item-0-dose'),
        '5 ml every 12 hours for 7 days',
      );
      expect(fieldText(tester, 'rx-item-0-days'), '7');
      for (final t in ['08:00', '20:00']) {
        expect(find.byKey(ValueKey('rx-item-0-time-$t')), findsOneWidget);
      }
      expect(fieldText(tester, 'rx-item-1-name'), 'Cetal');
      expect(fieldText(tester, 'rx-item-1-dose'), '5 ml 1x3 after meals');
      // No course length printed: left for the person.
      expect(fieldText(tester, 'rx-item-1-days'), '');
      expect(
        find.byKey(const ValueKey('rx-item-1-time-14:00')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('rx-item-2-name')), findsNothing);

      // Date and saved doctor suggested, marked to check.
      expect(find.byKey(const ValueKey('rx-unsure-date')), findsOneWidget);
      expect(find.byKey(const ValueKey('rx-unsure-doctor')), findsOneWidget);
      expect(find.text('Dr. Ahmed Samir'), findsOneWidget);

      // Save waits for every check.
      expect(find.byKey(const ValueKey('rx-confirm-needed')), findsOneWidget);
      expect(enabled(tester, 'rx-save'), isFalse);

      await tapKey(tester, 'rx-unsure-date');
      await tapKey(tester, 'rx-unsure-doctor');
      // Each dose came from the line under its name: checked first.
      final confirm0 = tester.widget<CheckboxListTile>(
        find.byKey(const ValueKey('rx-item-0-confirm')),
      );
      expect(confirm0.onChanged, isNull);
      await tapKey(tester, 'rx-item-0-unsure-dose');
      await tapKey(tester, 'rx-item-0-confirm');
      expect(enabled(tester, 'rx-save'), isFalse);
      await tapKey(tester, 'rx-item-1-unsure-dose');
      await tapKey(tester, 'rx-item-1-confirm');
      await tester.enterText(find.byKey(const ValueKey('rx-item-1-days')), '5');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('rx-confirm-needed')), findsNothing);
      await tapKey(tester, 'rx-save');

      final p = (await tester.runAsync(
        () => db.watchPrescriptions(omar).first,
      ))!.single;
      expect(p.prescribedOn.toUtc(), DateTime.utc(2026, 3, 12));
      expect(p.doctorId, doctor);
      // The photo is stored encrypted; the plain copy is gone.
      final photo = decodeMedicinePhotos(p.photosJson).single;
      expect(photos.fileOf(photo).existsSync(), isTrue);
      expect(File(pickedPaths.single).existsSync(), isFalse);
      final meds = (await tester.runAsync(
        () => db.watchPrescriptionMedicines(p.id).first,
      ))!;
      expect(meds.map((m) => m.name), ['Augmentin', 'Cetal']);
      expect(meds.map((m) => m.strength), ['457mg/5ml', null]);
      // The dose exactly as read.
      expect(meds.map((m) => m.instructions), [
        '5 ml every 12 hours for 7 days',
        '5 ml 1x3 after meals',
      ]);
    });

    testWidgets('handwriting: nothing filled in, the photo kept', (
      tester,
    ) async {
      tallScreen(tester);
      final omar = (await tester.runAsync(() => db.addProfile('عمر')))!;
      ocr.result = ocrOf(
        ['Dr. Hany Fouad', 'Augmentin 1g', '1x2', 'Cetal'],
        confidences: [0.9, 0.4, 0.3, 0.35],
      );
      await go(tester, '/family/$omar/prescriptions/new');
      await tapKey(tester, 'rx-scan-gallery');

      expect(find.textContaining('بخط الإيد'), findsOneWidget);
      expect(fieldText(tester, 'rx-item-0-name'), '');
      expect(find.byKey(const ValueKey('rx-item-0-confirm')), findsNothing);
      expect(find.byKey(const ValueKey('rx-photo-preview-0')), findsOneWidget);
      // The printed doctor isn't saved yet: offered to add.
      expect(find.textContaining('Dr. Hany Fouad'), findsOneWidget);
      await tapKey(tester, 'rx-doctor-add');
      final doctors = (await tester.runAsync(() => db.watchDoctors().first))!;
      expect(doctors.single.name, 'Dr. Hany Fouad');
      expect(find.byKey(const ValueKey('rx-doctor-on-paper')), findsNothing);
      expect(find.text('Dr. Hany Fouad'), findsOneWidget);
      expect(enabled(tester, 'rx-save'), isTrue);
    });

    testWidgets('a marked box must be looked at before confirming', (
      tester,
    ) async {
      tallScreen(tester);
      final omar = (await tester.runAsync(() => db.addProfile('عمر')))!;
      ocr.result = ocrOf(['Telfast 120mg']);
      await go(tester, '/family/$omar/prescriptions/new');
      await tapKey(tester, 'rx-scan-camera');

      expect(fieldText(tester, 'rx-item-0-name'), 'Telfast');
      // No instructions read: the dose box is marked.
      expect(
        find.byKey(const ValueKey('rx-item-0-unsure-dose')),
        findsOneWidget,
      );
      final confirm = tester.widget<CheckboxListTile>(
        find.byKey(const ValueKey('rx-item-0-confirm')),
      );
      expect(confirm.onChanged, isNull);
      // Typing it from the paper clears the mark.
      await tester.enterText(
        find.byKey(const ValueKey('rx-item-0-dose')),
        'قرص قبل النوم',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('rx-item-0-unsure-dose')), findsNothing);
      await tapKey(tester, 'rx-item-0-confirm');
      expect(find.byKey(const ValueKey('rx-confirm-needed')), findsNothing);
    });

    testWidgets('a near spelling stays as read; the listed name is offered', (
      tester,
    ) async {
      tallScreen(tester);
      final omar = (await tester.runAsync(() => db.addProfile('عمر')))!;
      ocr.result = ocrOf(['Microvlax 10mg tab'], confidences: [0.9]);
      await go(tester, '/family/$omar/prescriptions/new');
      await tapKey(tester, 'rx-scan-camera');

      expect(fieldText(tester, 'rx-item-0-name'), 'Microvlax');
      expect(find.text('تقصد Microvlar؟'), findsOneWidget);
      await tapKey(tester, 'rx-item-0-did-you-mean');
      expect(fieldText(tester, 'rx-item-0-name'), 'Microvlar');
      expect(
        find.byKey(const ValueKey('rx-item-0-did-you-mean')),
        findsNothing,
      );
      // Still the person's to check against the paper.
      expect(
        find.byKey(const ValueKey('rx-item-0-unsure-name')),
        findsOneWidget,
      );
    });

    testWidgets('unsure times can be confirmed without changing them', (
      tester,
    ) async {
      tallScreen(tester);
      final omar = (await tester.runAsync(() => db.addProfile('عمر')))!;
      ocr.result = ocrOf(['Tobradex eye drops', '1 drop OD']);
      await go(tester, '/family/$omar/prescriptions/new');
      await tapKey(tester, 'rx-scan-camera');

      // "OD" could be once daily or the right eye: no times, marked.
      expect(find.byKey(const ValueKey('rx-item-0-time-08:00')), findsNothing);
      expect(
        find.byKey(const ValueKey('rx-item-0-unsure-times')),
        findsOneWidget,
      );
      await tapKey(tester, 'rx-item-0-unsure-dose');
      await tapKey(tester, 'rx-item-0-unsure-times');
      expect(
        find.byKey(const ValueKey('rx-item-0-unsure-times')),
        findsNothing,
      );
      final confirm = tester.widget<CheckboxListTile>(
        find.byKey(const ValueKey('rx-item-0-confirm')),
      );
      expect(confirm.onChanged, isNotNull);
    });

    testWidgets('a failed read says so and keeps the photo', (tester) async {
      tallScreen(tester);
      final omar = (await tester.runAsync(() => db.addProfile('عمر')))!;
      ocr.error = Exception('no model');
      await go(tester, '/family/$omar/prescriptions/new');
      await tapKey(tester, 'rx-scan-camera');
      expect(find.text('مقدرناش نقرا الصورة'), findsOneWidget);
      expect(find.byKey(const ValueKey('rx-photo-preview-0')), findsOneWidget);
    });
  });

  group('vaccination card photo', () {
    final birth = DateTime(2025, 3, 1);

    testWidgets('ticks the dated doses; each confirmed before saving', (
      tester,
    ) async {
      tallScreen(tester);
      final kid = (await tester.runAsync(
        () => db.addProfile('ليلى', birthDate: birth, sex: 'female'),
      ))!;
      ocr.result = ocrOf([
        'بطاقة التطعيمات',
        'تاريخ الميلاد: ١/٣/٢٠٢٥',
        'At birth  OPV 0  HBV  1/3/2025',
        'BCG  5/3/2025',
        '2 months  OPV + IPV + Penta  3/5/2025',
        'Prevenar  3/5/2025',
        'Xq lluo  5/7/2025',
        '٢/٩/٢٠٢٥',
      ]);
      await go(tester, '/family/$kid/vaccines/setup');

      await tapKey(tester, 'vaccine-scan-camera');
      // Read on the phone, then the plain copy is deleted.
      expect(ocr.read, [pickedPaths.single]);
      expect(File(pickedPaths.single).existsSync(), isFalse);
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('vaccine-scan-result')))
            .data,
        startsWith('لقينا ٧ جرعات'),
      );

      const read = [
        'opv-0',
        'hepB-0',
        'bcg-1',
        'opv-1',
        'ipv-1',
        'penta-1',
        'pcv-1',
      ];
      for (final key in read) {
        expect(
          tester
              .widget<CheckboxListTile>(find.byKey(ValueKey('setup-$key')))
              .value,
          isTrue,
          reason: key,
        );
        expect(find.byKey(ValueKey('setup-confirm-$key')), findsOneWidget);
      }
      // No dose word or age on the PCV row: its number is a guess.
      expect(find.byKey(const ValueKey('setup-guessed-pcv-1')), findsOneWidget);
      // Rows the phone couldn't name.
      expect(
        find.byKey(const ValueKey('setup-unknown-label-0')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('setup-unknown-label-1')),
        findsOneWidget,
      );
      expect(enabled(tester, 'vaccine-setup-save'), isFalse);

      // The first is the second pentavalent dose; the other is skipped.
      await tapKey(tester, 'setup-unknown-pick-0');
      await tester.tap(
        find
            .byWidgetPredicate(
              (w) => w is DropdownMenuItem<String> && w.value == 'penta-2',
            )
            .last,
      );
      await tester.pumpAndSettle();
      await tapKey(tester, 'setup-unknown-skip-0');
      expect(find.byKey(const ValueKey('setup-unknown-label-0')), findsNothing);

      // PCV turns out not to be on the card: untick it instead.
      await tapKey(tester, 'setup-pcv-1');
      expect(find.byKey(const ValueKey('setup-confirm-pcv-1')), findsNothing);
      for (final key in [...read.where((k) => k != 'pcv-1'), 'penta-2']) {
        expect(enabled(tester, 'vaccine-setup-save'), isFalse);
        await tapKey(tester, 'setup-confirm-$key');
      }
      expect(enabled(tester, 'vaccine-setup-save'), isTrue);
      await tapKey(tester, 'vaccine-setup-save');

      final events = (await tester.runAsync(
        () => db.watchTimeline(kid).first,
      ))!;
      final records = vaccineRecords(events);
      expect(records, hasLength(7));
      DateTime day(DateTime d) => DateTime(d.year, d.month, d.day);
      expect(records.map((r) => day(r.date)).toSet(), {
        DateTime(2025, 3, 1),
        DateTime(2025, 3, 5),
        DateTime(2025, 5, 3),
        DateTime(2025, 7, 5),
      });
    });

    testWidgets('nothing readable: says so, nothing ticked', (tester) async {
      tallScreen(tester);
      final kid = (await tester.runAsync(
        () => db.addProfile('ليلى', birthDate: birth),
      ))!;
      ocr.result = ocrOf([
        'Vaccination card',
        'OPV  IPV  Penta',
        // Only a next visit: not ticked, but said.
        'MMR  12 months  1/12/2026',
      ]);
      await go(tester, '/family/$kid/vaccines/setup');
      await tapKey(tester, 'vaccine-scan-gallery');
      expect(find.textContaining('ملقيناش جرعات'), findsOneWidget);
      expect(find.textContaining('لسه مجاش'), findsOneWidget);
      expect(find.byKey(const ValueKey('setup-confirm-opv-0')), findsNothing);
      expect(enabled(tester, 'vaccine-setup-save'), isTrue);
      expect(File(pickedPaths.single).existsSync(), isFalse);
    });
  });

  group('the rebuilt screens', () {
    final birthDate = DateTime(2025, 3, 1);
    const prescription = ['R/', '1- Augmentin 1g tab', '1x2 for 7 days'];
    const card = ['BCG  5/3/2025', 'At birth  OPV 0  1/3/2025'];

    Future<void> openSheet(WidgetTester tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      showAddSheet(tester.element(find.byType(Scaffold).first));
      await tester.pumpAndSettle();
    }

    testWidgets('Add: the prescription button reads, and saves nothing yet', (
      tester,
    ) async {
      tallScreen(tester);
      final omar = (await tester.runAsync(() => db.addProfile('عمر')))!;
      ocr.result = ocrOf(prescription);
      await openSheet(tester);
      expect(find.text('صوّر روشتة أو علبة دوا'), findsOneWidget);

      await tapKey(tester, 'add-photo-prescription');

      expect(ocr.read, [pickedPaths.single]);
      expect(fieldText(tester, 'rx-item-0-name'), 'Augmentin');
      expect(find.byKey(const ValueKey('rx-for')), findsOneWidget);
      expect(find.text('احفظ لعمر'), findsOneWidget);
      expect(enabled(tester, 'rx-save'), isFalse);
      final saved = await tester.runAsync(
        () => db.watchPrescriptions(omar).first,
      );
      expect(saved, isEmpty);
    });

    testWidgets('Add: the box button opens the box reader', (tester) async {
      tallScreen(tester);
      await tester.runAsync(() => db.addProfile('عمر'));
      await openSheet(tester);
      await tapKey(tester, 'add-photo-box');
      expect(find.byKey(const ValueKey('rx-for')), findsNothing);
      expect(find.text('صوّر علبة الدوا'), findsWidgets);
    });

    testWidgets('Add: with no one picked neither button opens', (tester) async {
      tallScreen(tester);
      await tester.runAsync(() => db.addProfile('عمر'));
      await tester.runAsync(() => db.addProfile('ليلى'));
      await openSheet(tester);
      expect(enabled(tester, 'add-photo-prescription'), isFalse);
      expect(enabled(tester, 'add-photo-box'), isFalse);
      expect(pickedPaths, isEmpty);
    });

    testWidgets('Add medicine leads to the prescription reader, when new', (
      tester,
    ) async {
      tallScreen(tester);
      final omar = (await tester.runAsync(() => db.addProfile('عمر')))!;
      ocr.result = ocrOf(prescription);
      await go(tester, '/family/$omar/medicines/new');
      await tapKey(tester, 'medicine-scan-prescription');
      expect(fieldText(tester, 'rx-item-0-name'), 'Augmentin');
      expect(enabled(tester, 'rx-save'), isFalse);
    });

    testWidgets(
      'signed out: the gate stops a checked save, and it can resume',
      (tester) async {
        tallScreen(tester);
        final omar = (await tester.runAsync(() => db.addProfile('عمر')))!;
        ocr.result = ocrOf(['R/', '1- Augmentin 1g tab 1x2']);
        final gate = _Gate();
        await go(tester, '/family/$omar/prescriptions/new', gate: gate);
        await tapKey(tester, 'rx-scan-camera');
        await tester.enterText(
          find.byKey(const ValueKey('rx-item-0-days')),
          '7',
        );
        await tester.pumpAndSettle();
        for (final field in ['name', 'strength', 'dose', 'times', 'days']) {
          final check = 'rx-item-0-unsure-$field';
          if (find.byKey(ValueKey(check)).evaluate().isNotEmpty) {
            await tapKey(tester, check);
          }
        }
        await tapKey(tester, 'rx-item-0-confirm');
        expect(enabled(tester, 'rx-save'), isTrue);
        await tapKey(tester, 'rx-save');
        expect(gate.asked, 1);
        expect(
          await tester.runAsync(() => db.watchPrescriptions(omar).first),
          isEmpty,
        );
        // Still there, and the photo still only the picker's copy.
        expect(fieldText(tester, 'rx-item-0-name'), 'Augmentin');
        expect(File(pickedPaths.single).existsSync(), isTrue);

        gate.open = true;
        await tapKey(tester, 'rx-save');
        expect(
          await tester.runAsync(() => db.watchPrescriptions(omar).first),
          hasLength(1),
        );
        expect(File(pickedPaths.single).existsSync(), isFalse);
      },
    );

    testWidgets('signed out: adding the doctor on the paper waits too', (
      tester,
    ) async {
      tallScreen(tester);
      final omar = (await tester.runAsync(() => db.addProfile('عمر')))!;
      ocr.result = ocrOf(['Dr. Hany Fouad', 'R/', '1- Augmentin 1g tab 1x2']);
      final gate = _Gate();
      await go(tester, '/family/$omar/prescriptions/new', gate: gate);
      await tapKey(tester, 'rx-scan-camera');
      await tapKey(tester, 'rx-doctor-add');
      expect(gate.asked, 1);
      expect(await tester.runAsync(() => db.watchDoctors().first), isEmpty);
    });

    testWidgets('New vaccine: a child can photograph the card', (tester) async {
      tallScreen(tester);
      final kid = (await tester.runAsync(
        () => db.addProfile('ليلى', birthDate: birthDate, sex: 'female'),
      ))!;
      ocr.result = ocrOf(card);
      await go(tester, '/family/$kid/add/vaccine');
      expect(find.text('صوّر كارت التطعيم'), findsOneWidget);

      await tapKey(tester, 'new-vaccine-scan');

      // Read and let go of at once; each dose still waits for its check.
      expect(ocr.read, [pickedPaths.single]);
      expect(File(pickedPaths.single).existsSync(), isFalse);
      expect(find.byKey(const ValueKey('setup-confirm-bcg-1')), findsOneWidget);
      expect(enabled(tester, 'vaccine-setup-save'), isFalse);
      final events = await tester.runAsync(() => db.watchTimeline(kid).first);
      expect(vaccineRecords(events!), isEmpty);
    });

    testWidgets('New vaccine: an adult has no schedule to read a card to', (
      tester,
    ) async {
      tallScreen(tester);
      final adult = (await tester.runAsync(
        () => db.addProfile('جدو', birthDate: DateTime(1950, 1, 1)),
      ))!;
      await go(tester, '/family/$adult/add/vaccine');
      expect(find.byKey(const ValueKey('new-vaccine-scan')), findsNothing);
    });

    testWidgets('changing the route drops what the card matched', (
      tester,
    ) async {
      tallScreen(tester);
      final kid = (await tester.runAsync(
        () => db.addProfile('ليلى', birthDate: birthDate),
      ))!;
      ocr.result = ocrOf(card);
      await go(tester, '/family/$kid/vaccines/setup');
      await tapKey(tester, 'vaccine-scan-camera');
      expect(enabled(tester, 'vaccine-setup-save'), isFalse);

      await tapKey(tester, 'vaccine-route-hexavalent');

      expect(find.byKey(const ValueKey('setup-confirm-bcg-1')), findsNothing);
      expect(find.textContaining('الجدول اتغيّر'), findsOneWidget);
      expect(enabled(tester, 'vaccine-setup-save'), isTrue);
    });
  });

  testWidgets('Simple Mode: the scan card is there, with big buttons', (
    tester,
  ) async {
    tallScreen(tester);
    final omar = (await tester.runAsync(() => db.addProfile('عمر')))!;
    await tester.pumpWidget(app(simple: true));
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.byType(Scaffold).first))
        .go('/family/$omar/prescriptions/new');
    await tester.pumpAndSettle();
    final camera = find.byKey(const ValueKey('rx-scan-camera'));
    expect(camera, findsOneWidget);
    expect(tester.getSize(camera).height, greaterThanOrEqualTo(48));
    expect(tester.takeException(), isNull);
  });
}

/// Signed out with login on, until [open].
class _Gate implements SaveGate {
  bool open = false;
  int asked = 0;

  @override
  Future<bool> allow({SaveGateReason reason = SaveGateReason.record}) async {
    asked++;
    return open;
  }
}
