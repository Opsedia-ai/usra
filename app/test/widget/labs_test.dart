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
    tester.view.physicalSize = const Size(1170, 4000);
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
    ]);
    await start(tester, '/family/$mom/add/lab');
    expect(find.byKey(const ValueKey('lab-info-note')), findsOneWidget);

    await tapKey(tester, 'lab-scan-camera');
    expect(ocr.read, [picked.first.path]);
    expect(find.byKey(const ValueKey('lab-scan-result')), findsOneWidget);
    expect(find.textContaining('لقينا 3 نتيجة'), findsOneWidget);
    // Filled in, not saved.
    expect(field(tester, 'lab-name'), 'ALFA LABORATORIES');
    expect(field(tester, 'lab-doctor'), 'Dr. Hany Saleh');
    expect(field(tester, 'lab-test-name-0'), 'HbA1c');
    expect(field(tester, 'lab-test-value-1'), '10.5');
    expect(
      await tester.runAsync(() => db.eventsOfTypes({'lab'})),
      hasLength(1),
    );

    // The misread value is marked, with words, until it's edited.
    expect(find.byKey(const ValueKey('lab-unsure-value-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('lab-unsure-value-0')), findsNothing);
    expect(find.text('راجع دي على الورقة'), findsOneWidget);
    await type(tester, 'lab-test-value-1', '10.8');
    expect(find.byKey(const ValueKey('lab-unsure-value-1')), findsNothing);

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

    // One more typed by hand, and a PDF.
    await tapKey(tester, 'lab-add-test');
    await type(tester, 'lab-test-name-3', 'TSH');
    await type(tester, 'lab-test-value-3', '2.1');
    await type(tester, 'lab-test-range-3', '0.27 - 4.2');
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
      'TSH',
    ]);
    expect(report.tests[1].value, 10.8);
    expect(report.tests[1].flag, LabFlag.low);
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
    expect(photos.readSync(files[1].path), [1]);
    // No plain copies left behind.
    expect(picked.first.existsSync(), isFalse);
    expect(cleanups, 1);

    // The record page: each result with its range and flag.
    await tapKey(tester, 'event-${saved.id}');
    expect(find.byKey(const ValueKey('lab-result-3')), findsOneWidget);
    expect(find.text('أقل من معدل المعمل'), findsOneWidget);
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

  testWidgets('nothing is saved without a test and its result', (tester) async {
    final mom = (await tester.runAsync(() => db.addProfile('فاطمة')))!;
    await start(tester, '/family/$mom/add/lab');
    await tapKey(tester, 'record-save');
    expect(find.byKey(const ValueKey('lab-need-test')), findsOneWidget);
    await type(tester, 'lab-test-name-0', 'CBC');
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
}
