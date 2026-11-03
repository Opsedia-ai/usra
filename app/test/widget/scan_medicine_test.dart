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
import 'package:usra/core/providers.dart';
import 'package:usra/features/scan/scan_medicine_screen.dart';

import '../support/fake_ocr_service.dart';

void main() {
  late AppDatabase db;
  late Directory dir;
  late File picked;
  late FakeOcrService ocr;
  late MedicineNameExtractor extractor;

  setUpAll(() {
    extractor = MedicineNameExtractor.fromList(
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
    dir = Directory.systemTemp.createTempSync('usra_scan');
    picked = File('${dir.path}/box.jpg')..writeAsBytesSync([0, 1, 2]);
    ocr = FakeOcrService(OcrResult.empty);
  });
  tearDown(() async {
    await db.close();
    dir.deleteSync(recursive: true);
  });

  Widget app() => ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      photoPickerProvider.overrideWithValue((_) async => picked.path),
      ocrServiceProvider.overrideWithValue(ocr),
      medicineNameExtractorProvider.overrideWith((ref) async => extractor),
    ],
    child: const UsraApp(),
  );

  /// Opens the scan screen the way a feature would, returning its result.
  Future<Future<MedicineSuggestion?>> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 3000);
    tester.view.devicePixelRatio = 1.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
    final result = router.push<MedicineSuggestion>(ScanMedicineScreen.path);
    await tester.pumpAndSettle();
    return result;
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    await tester.ensureVisible(find.byKey(ValueKey(key)));
    await tester.tap(find.byKey(ValueKey(key)));
    await tester.pumpAndSettle();
  }

  String field(WidgetTester tester, String key) =>
      tester.widget<TextField>(find.byKey(ValueKey(key))).controller!.text;

  testWidgets('scan a box, pick a suggestion, edit it and return it', (
    tester,
  ) async {
    ocr.result = ocrOf(
      [
        'Panadol Extra',
        'Paracetamol 500mg Caffeine 65mg',
        'Take 2 tablets every 6 hours',
        '24 Tablets',
      ],
      heights: [60, 20, 14, 14],
    );
    final result = await open(tester);
    expect(find.text('صوّر علبة الدوا'), findsOneWidget);
    // Says up front what the phone can't read.
    expect(find.textContaining('خط الإيد'), findsOneWidget);

    await tapKey(tester, 'scan-camera');
    expect(ocr.read, [picked.path]);
    expect(find.text('Panadol Extra 500mg'), findsOneWidget);
    expect(find.text('Paracetamol 500mg'), findsOneWidget);
    // The first suggestion is filled in, ready to check.
    expect(field(tester, 'scan-name'), 'Panadol Extra');
    expect(field(tester, 'scan-strength'), '500mg');
    // Nothing from the instructions.
    expect(find.textContaining('every'), findsNothing);

    await tapKey(tester, 'scan-suggestion-1');
    expect(field(tester, 'scan-name'), 'Paracetamol');

    await tester.enterText(
      find.byKey(const ValueKey('scan-name')),
      'Panadol Advance',
    );
    await tapKey(tester, 'scan-use');

    final value = await result;
    expect(value?.name, 'Panadol Advance');
    expect(value?.strength, '500mg');
    expect(find.byType(ScanMedicineScreen), findsNothing);
    // The photo isn't kept.
    expect(picked.existsSync(), isFalse);
  });

  testWidgets('a new photo replaces an unedited suggestion, not typing', (
    tester,
  ) async {
    ocr.result = ocrOf(['Concor 5 mg']);
    final result = await open(tester);
    await tapKey(tester, 'scan-camera');
    expect(field(tester, 'scan-name'), 'Concor');

    // Wrong box: a new photo fills in the new name.
    ocr.result = ocrOf(['Augmentin 1g']);
    await tapKey(tester, 'scan-camera');
    expect(field(tester, 'scan-name'), 'Augmentin');
    expect(field(tester, 'scan-strength'), '1g');

    // Once the person types, another photo leaves the fields alone.
    await tester.enterText(find.byKey(const ValueKey('scan-name')), 'Hibiotic');
    ocr.result = ocrOf(['Concor 5 mg']);
    await tapKey(tester, 'scan-gallery');
    expect(field(tester, 'scan-name'), 'Hibiotic');

    await tapKey(tester, 'scan-use');
    expect((await result)?.name, 'Hibiotic');
  });

  testWidgets('nothing read: type the name in', (tester) async {
    final result = await open(tester);
    await tapKey(tester, 'scan-gallery');
    expect(find.byKey(const ValueKey('scan-none')), findsOneWidget);

    await tapKey(tester, 'scan-use');
    expect(find.text('مطلوب'), findsOneWidget);
    expect(find.byType(ScanMedicineScreen), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('scan-name')), 'Cetal');
    await tapKey(tester, 'scan-use');
    final value = await result;
    expect(value?.name, 'Cetal');
    expect(value?.strength, isNull);
  });

  testWidgets('a photo that can\'t be read says so', (tester) async {
    ocr.error = Exception('ML Kit failed');
    await open(tester);
    await tapKey(tester, 'scan-camera');
    expect(find.byKey(const ValueKey('scan-failed')), findsOneWidget);
    expect(find.byKey(const ValueKey('scan-use')), findsOneWidget);
  });
}
