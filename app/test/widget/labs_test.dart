import 'dart:async';
import 'dart:convert';
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
import 'package:usra/core/ocr/ocr_service.dart';
import 'package:usra/core/providers.dart';
import 'package:usra/features/labs/lab_providers.dart';
import 'package:usra/features/labs/lab_report.dart';

import '../support/fake_ocr_service.dart';
import '../support/sync_photo_store.dart';

void main() {
  late AppDatabase db;
  late Directory dir;
  late SyncPhotoStore photos;
  late FakeOcrService ocr;
  final picked = <File>[];
  var cleanups = 0;

  String pick([String ext = 'jpg']) {
    final f = File('${dir.path}/picked_${picked.length}.$ext')
      ..writeAsBytesSync([picked.length]);
    picked.add(f);
    return f.path;
  }

  setUp(() {
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    dir = Directory.systemTemp.createTempSync('usra_labs');
    photos = SyncPhotoStore(
      Directory('${dir.path}/support'),
      PhotoStore.attachmentsFolder,
    );
    ocr = FakeOcrService(OcrResult.empty);
    picked.clear();
    cleanups = 0;
  });
  tearDown(() async {
    await db.close();
    dir.deleteSync(recursive: true);
  });

  Widget app() => ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      attachmentStoreProvider.overrideWithValue(photos),
      photoPickerProvider.overrideWithValue((_) async => pick()),
      multiPhotoPickerProvider.overrideWithValue(() async => [pick()]),
      ocrServiceProvider.overrideWithValue(ocr),
      labPdfPickerProvider.overrideWithValue(() async => pick('pdf')),
      pickedFilesCleanupProvider.overrideWithValue(() async => cleanups++),
    ],
    child: const UsraApp(),
  );

  Future<void> start(WidgetTester tester, String path) async {
    tester.view.physicalSize = const Size(1170, 9000);
    tester.view.devicePixelRatio = 1.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.byType(Scaffold).first)).go(path);
    await tester.pumpAndSettle();
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    await tester.ensureVisible(find.byKey(ValueKey(key)));
    await tester.tap(find.byKey(ValueKey(key)));
    await tester.pumpAndSettle();
  }

  Future<void> type(WidgetTester tester, String key, String text) async {
    await tester.ensureVisible(find.byKey(ValueKey(key)));
    await tester.enterText(find.byKey(ValueKey(key)), text);
    await tester.pumpAndSettle();
  }

  String field(WidgetTester tester, String key) =>
      tester.widget<TextField>(find.byKey(ValueKey(key))).controller!.text;

  testWidgets('scan a report, check what was unsure, save it, see trends', (
    tester,
  ) async {
    final mom = (await tester.runAsync(() => db.addProfile('فاطمة')))!;
    // An HbA1c from last year, saved before reports existed.
    await tester.runAsync(
      () => db.addEvent(
        profileId: mom,
        type: 'lab',
        occurredAt: DateTime(2025, 9, 1),
        dataJson: jsonEncode({
          'test': 'السكر التراكمي',
          'value': 8.1,
          'unit': '%',
        }),
      ),
    );
    ocr.result = ocrOf([
      'ALFA LABORATORIES',
      'Ref. By: Dr. Hany Saleh',
      'Collection Date : 05-10-2026',
      'HbA1c  7.4  %  4.0 - 5.6',
      'Hemoglobin  1O.5  g/dL  12.0 - 15.5',
      'Fasting Blood Sugar  95  mg/dL  70 - 100',
      'Vitamin D  18.5  ng/mL  Deficiency < 20  Sufficiency 30 - 100',
    ]);
    await start(tester, '/family/$mom/add/lab');
    expect(find.byKey(const ValueKey('lab-info-note')), findsOneWidget);

    await tapKey(tester, 'lab-scan-camera');
    expect(ocr.read, [picked.first.path]);
    expect(find.byKey(const ValueKey('lab-scan-result')), findsOneWidget);
    expect(find.textContaining('لقينا ٤ نتيجة'), findsOneWidget);
    // Filled in, not saved, with the photo beside the rows to check.
    expect(field(tester, 'lab-name'), 'ALFA LABORATORIES');
    expect(field(tester, 'lab-doctor'), 'Dr. Hany Saleh');
    expect(field(tester, 'lab-test-name-0'), 'HbA1c');
    expect(field(tester, 'lab-test-value-1'), '10.5');
    expect(find.byKey(const ValueKey('lab-scan-photo')), findsOneWidget);
    expect(
      await tester.runAsync(() => db.eventsOfTypes({'lab'})),
      hasLength(1),
    );

    // Nothing is saved until every row read from the photo is confirmed
    // and every marked box checked.
    expect(find.byKey(const ValueKey('lab-confirm-needed')), findsOneWidget);
    await tapKey(tester, 'record-save');
    expect(
      await tester.runAsync(() => db.eventsOfTypes({'lab'})),
      hasLength(1),
    );
    // No flag on a row until it's confirmed.
    expect(find.byKey(const ValueKey('lab-test-flag-0')), findsNothing);

    // The date came from the photo: marked until checked.
    expect(find.byKey(const ValueKey('lab-unsure-date')), findsOneWidget);
    await tapKey(tester, 'lab-unsure-date');
    expect(find.byKey(const ValueKey('lab-unsure-date')), findsNothing);

    // The misread value is marked, with words; its row can't be confirmed
    // until it's edited or ticked as checked.
    expect(find.byKey(const ValueKey('lab-unsure-value-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('lab-unsure-value-0')), findsNothing);
    expect(find.text('راجع دي على الورقة'), findsWidgets);
    final confirm1 = tester.widget<CheckboxListTile>(
      find.byKey(const ValueKey('lab-confirm-1')),
    );
    expect(confirm1.onChanged, isNull);
    await type(tester, 'lab-test-value-1', '10.8');
    expect(find.byKey(const ValueKey('lab-unsure-value-1')), findsNothing);

    // Several ranges printed for vitamin D: none is taken until one is
    // picked.
    expect(field(tester, 'lab-test-range-3'), '');
    await tapKey(tester, 'lab-range-choice-3-1');
    expect(field(tester, 'lab-test-range-3'), '30 - 100');

    for (final i in [0, 1, 2, 3]) {
      await tapKey(tester, 'lab-confirm-$i');
    }
    expect(find.byKey(const ValueKey('lab-confirm-needed')), findsNothing);

    // Flags come from the printed range, in words.
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('lab-test-flag-0')),
        matching: find.text('أعلى من معدل المعمل'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('lab-test-flag-2')),
        matching: find.text('في حدود معدل المعمل'),
      ),
      findsOneWidget,
    );

    // The same page photographed again adds nothing new.
    await tapKey(tester, 'lab-scan-camera');
    expect(find.byKey(const ValueKey('lab-test-name-4')), findsNothing);
    // ...and says so, offering the new readings where they differ (the
    // corrected haemoglobin, the picked vitamin D range).
    expect(find.byKey(const ValueKey('lab-scan-skipped')), findsOneWidget);
    expect(find.byKey(const ValueKey('lab-scan-replace')), findsOneWidget);
    await tapKey(tester, 'record-photo-remove-1');

    // One more typed by hand, and a PDF.
    await tapKey(tester, 'lab-add-test');
    await type(tester, 'lab-test-name-4', 'TSH');
    await type(tester, 'lab-test-value-4', '2.1');
    await type(tester, 'lab-test-range-4', '0.27 - 4.2');
    await tapKey(tester, 'lab-attach-pdf');
    await tapKey(tester, 'record-save');

    final saved = (await tester.runAsync(() => db.eventsOfTypes({'lab'})))!
        .firstWhere((e) => e.occurredAt == DateTime(2026, 10, 5));
    final report = LabReport.of(saved);
    expect(report.lab, 'ALFA LABORATORIES');
    expect(report.tests.map((t) => t.name), [
      'HbA1c',
      'Hemoglobin',
      'Fasting Blood Sugar',
      'Vitamin D',
      'TSH',
    ]);
    expect(report.tests[1].value, 10.8);
    expect(report.tests[1].flag, LabFlag.low);
    expect(report.tests[3].range.format(), '30 - 100');
    // The scanned photo and the PDF are kept, encrypted.
    final files = (await tester.runAsync(
      () => db.watchAttachments(saved.id).first,
    ))!;
    expect(files.map((a) => a.kind), ['photo', 'pdf']);
    for (final a in files) {
      expect(
        PhotoCipher.isSealed(photos.fileOf(a.path).readAsBytesSync()),
        isTrue,
      );
    }
    // The PDF is the third file picked (after two photos of the page).
    expect(photos.readSync(files[1].path), [2]);
    // No plain photo copies left behind; the PDF picker's go via cleanup.
    expect(
      picked.where((f) => f.path.endsWith('.jpg') && f.existsSync()),
      isEmpty,
    );
    expect(cleanups, 1);

    // The record page: each result with its range and flag.
    await tapKey(tester, 'event-${saved.id}');
    expect(find.byKey(const ValueKey('lab-result-4')), findsOneWidget);
    expect(find.text('أقل من معدل المعمل'), findsNWidgets(2));
    expect(find.byKey(const ValueKey('record-pdf-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('record-thumb-0')), findsOneWidget);

    // HbA1c over time: the old record and the new report together.
    await tapKey(tester, 'lab-result-0');
    expect(find.byKey(const ValueKey('lab-chart')), findsOneWidget);
    expect(find.byKey(const ValueKey('lab-point-%-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('lab-point-%-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('lab-units-apart')), findsNothing);
  });

  testWidgets('results by test, units kept apart, an old record shown', (
    tester,
  ) async {
    final dad = (await tester.runAsync(() => db.addProfile('محمد')))!;
    final old = (await tester.runAsync(
      () => db.addEvent(
        profileId: dad,
        type: 'lab',
        occurredAt: DateTime(2025, 1, 1),
        dataJson: jsonEncode({
          'test': 'Glucose fasting',
          'value': 6.2,
          'unit': 'mmol/L',
        }),
      ),
    ))!;
    await tester.runAsync(
      () => db.addEvent(
        profileId: dad,
        type: 'lab',
        occurredAt: DateTime(2026, 1, 1),
        dataJson: jsonEncode(
          const LabReport(
            tests: [
              LabTest(
                name: 'FBS',
                value: 110,
                unit: 'mg/dL',
                range: LabRange(low: 70, high: 100),
              ),
            ],
          ).toData(),
        ),
      ),
    );
    await start(tester, '/family/$dad');
    await tapKey(tester, 'member-visits');
    await tapKey(tester, 'member-labs');
    expect(find.byKey(const ValueKey('lab-series-fbs|mg/dL')), findsOneWidget);
    expect(find.byKey(const ValueKey('lab-series-fbs|mmol/L')), findsOneWidget);

    await tapKey(tester, 'lab-series-fbs|mg/dL');
    expect(find.byKey(const ValueKey('lab-units-apart')), findsOneWidget);
    expect(find.byKey(const ValueKey('lab-trend-mg/dL')), findsOneWidget);
    expect(find.byKey(const ValueKey('lab-trend-mmol/L')), findsOneWidget);

    // The old record still opens, as one result with no range.
    await tapKey(tester, 'lab-point-mmol/L-0');
    expect(find.byKey(const ValueKey('lab-result-0')), findsOneWidget);
    expect(find.text('Glucose fasting'), findsOneWidget);
    expect(find.text('مفيش معدل نقارن بيه'), findsOneWidget);

    // Edited into a report with a range.
    await tester.tap(find.byKey(const ValueKey('record-edit')));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    expect(field(tester, 'lab-test-name-0'), 'Glucose fasting');
    await type(tester, 'lab-test-range-0', '3.9 - 5.5');
    await tapKey(tester, 'record-save');
    final event = await tester.runAsync(() => db.watchEvent(old).first);
    final edited = LabReport.of(event!);
    expect(edited.tests.single.flag, LabFlag.high);
    expect(find.text('أعلى من معدل المعمل'), findsOneWidget);
  });

  testWidgets('the results list fits 320 px at text x2, in dark', (
    tester,
  ) async {
    final dad = (await tester.runAsync(() => db.addProfile('محمد')))!;
    await tester.runAsync(
      () => db.addEvent(
        profileId: dad,
        type: 'lab',
        occurredAt: DateTime(2026, 1, 1),
        dataJson: jsonEncode(
          const LabReport(
            tests: [
              LabTest(
                name: 'FBS',
                value: 110,
                unit: 'mg/dL',
                range: LabRange(low: 70, high: 100),
              ),
            ],
          ).toData(),
        ),
      ),
    );
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    tester.view.physicalSize = const Size(640, 6000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.byType(Scaffold).first))
        .go('/family/$dad/labs');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('lab-series-fbs|mg/dL')), findsOneWidget);
    // Above the range: said in words, beside a dot, not a tinted chip.
    expect(find.text('أعلى من معدل المعمل'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('nothing is saved without a test name', (tester) async {
    final mom = (await tester.runAsync(() => db.addProfile('فاطمة')))!;
    await start(tester, '/family/$mom/add/lab');
    await tapKey(tester, 'record-save');
    expect(find.byKey(const ValueKey('lab-need-test')), findsOneWidget);
    await type(tester, 'lab-test-value-0', '13');
    await tapKey(tester, 'record-save');
    expect(find.text('مطلوب'), findsOneWidget);
    expect(await tester.runAsync(() => db.eventsOfTypes({'lab'})), isEmpty);

    // A PDF picked and taken back out still leaves no plain copy behind.
    await tapKey(tester, 'lab-attach-pdf');
    await tapKey(tester, 'lab-pdf-remove-0');
    expect(cleanups, 0);
    GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/family/$mom');
    await tester.pumpAndSettle();
    expect(cleanups, 1);
  });

  testWidgets('a test with a name and no result can be saved', (tester) async {
    final mom = (await tester.runAsync(() => db.addProfile('فاطمة')))!;
    await start(tester, '/family/$mom/add/lab');
    await type(tester, 'lab-test-name-0', 'CBC');
    await tapKey(tester, 'record-save');
    final saved = (await tester.runAsync(() => db.eventsOfTypes({'lab'})))!;
    final test = LabReport.of(saved.single).tests.single;
    expect((test.name, test.value, test.valueText), ('CBC', null, null));
  });

  testWidgets('a PDF picked as the form closes leaves no plain copy', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 9000);
    tester.view.devicePixelRatio = 1.5;
    addTearDown(tester.view.reset);
    final mom = (await tester.runAsync(() => db.addProfile('فاطمة')))!;
    final picking = Completer<String?>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          attachmentStoreProvider.overrideWithValue(photos),
          ocrServiceProvider.overrideWithValue(ocr),
          labPdfPickerProvider.overrideWithValue(() => picking.future),
          pickedFilesCleanupProvider.overrideWithValue(() async => cleanups++),
        ],
        child: const UsraApp(),
      ),
    );
    await tester.pumpAndSettle();
    final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
    router.go('/family/$mom/add/lab');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('lab-attach-pdf')));
    await tester.tap(find.byKey(const ValueKey('lab-attach-pdf')));
    await tester.pump();
    router.go('/family/$mom');
    await tester.pumpAndSettle();
    expect(cleanups, 0);
    picking.complete(pick('pdf'));
    await tester.pumpAndSettle();
    expect(cleanups, 1);
  });

  testWidgets('a new photo of a test already here can replace its row', (
    tester,
  ) async {
    final mom = (await tester.runAsync(() => db.addProfile('فاطمة')))!;
    ocr.result = ocrOf(['TSH  2.1  uIU/mL  0.27 - 4.2']);
    await start(tester, '/family/$mom/add/lab');
    await tapKey(tester, 'lab-scan-camera');
    await type(tester, 'lab-test-value-0', '2.4');
    await tapKey(tester, 'lab-confirm-0');
    expect(find.byKey(const ValueKey('lab-confirm-needed')), findsNothing);

    // A clearer photo reads it again.
    ocr.result = ocrOf(['TSH  2.7  uIU/mL  0.27 - 4.2']);
    await tapKey(tester, 'lab-scan-camera');
    expect(field(tester, 'lab-test-value-0'), '2.4');
    expect(find.byKey(const ValueKey('lab-test-name-1')), findsNothing);
    await tapKey(tester, 'lab-scan-replace');
    expect(field(tester, 'lab-test-value-0'), '2.7');
    expect(find.byKey(const ValueKey('lab-scan-replace')), findsNothing);
    // The new reading has to be confirmed again.
    expect(find.byKey(const ValueKey('lab-confirm-needed')), findsOneWidget);
  });
}
