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
import 'package:usra/core/providers.dart';
import 'package:usra/features/medicines/medicines_providers.dart';

import '../support/fake_reminder_scheduler.dart';
import '../support/sync_photo_store.dart';

/// Fails the moment a prune would delete a photo it has just imported: that
/// is what a form that pruned before saving its row would do.
class _GuardedStore extends SyncPhotoStore {
  _GuardedStore(super.root, super.folder);

  final imported = <String>[];
  final prunedTooEarly = <String>[];
  var prunes = 0;

  @override
  Future<String> import(String sourcePath) async {
    final path = await super.import(sourcePath);
    imported.add(path);
    return path;
  }

  @override
  Future<void> prune(Set<String> keep) async {
    prunes++;
    prunedTooEarly.addAll(imported.where((path) => !keep.contains(path)));
    await super.prune(keep);
  }
}

/// Forms copy a picked photo into the app before they save its row, and prune
/// the folder after. In the other order the prune deletes the new photo: see
/// the last test in `test/core/photo_safety_test.dart`.
void main() {
  late AppDatabase db;
  late Directory dir;
  late _GuardedStore cards;
  late _GuardedStore medicines;
  late _GuardedStore attachments;
  late File picked;

  setUp(() {
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    dir = Directory.systemTemp.createTempSync('usra_photo_forms');
    final root = Directory('${dir.path}/support');
    cards = _GuardedStore(root, PhotoStore.cardsFolder);
    medicines = _GuardedStore(root, PhotoStore.medicinesFolder);
    attachments = _GuardedStore(root, PhotoStore.attachmentsFolder);
    picked = File('${dir.path}/picked.jpg');
  });
  tearDown(() async {
    await db.close();
    dir.deleteSync(recursive: true);
  });

  Future<String> open(
    WidgetTester tester,
    String Function(String id) path,
  ) async {
    tester.view.physicalSize = const Size(1170, 3600);
    tester.view.devicePixelRatio = 1.5;
    addTearDown(tester.view.reset);
    final sara = (await tester.runAsync(() => db.addProfile('سارة')))!;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          cardPhotoStoreProvider.overrideWithValue(cards),
          medicinePhotoStoreProvider.overrideWithValue(medicines),
          attachmentStoreProvider.overrideWithValue(attachments),
          reminderSchedulerProvider.overrideWithValue(FakeReminderScheduler()),
          photoPickerProvider.overrideWithValue((_) async {
            picked.writeAsBytesSync([1, 2, 3]);
            return picked.path;
          }),
        ],
        child: const UsraApp(),
      ),
    );
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.byType(Scaffold).first)).go(path(sara));
    await tester.pumpAndSettle();
    return sara;
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    await tester.ensureVisible(find.byKey(ValueKey(key)));
    await tester.tap(find.byKey(ValueKey(key)));
    await tester.pumpAndSettle();
  }

  Future<void> type(WidgetTester tester, String key, String text) =>
      tester.enterText(find.byKey(ValueKey(key)), text);

  void expectKept(_GuardedStore store, {required bool pruned}) {
    expect(store.imported, hasLength(1));
    expect(store.prunedTooEarly, isEmpty);
    expect(store.prunes, pruned ? greaterThan(0) : 0);
    expect(store.fileOf(store.imported.single).existsSync(), isTrue);
  }

  testWidgets('the insurance form saves the card before it prunes', (
    tester,
  ) async {
    final sara = await open(tester, (id) => '/family/$id/insurance/new');
    await type(tester, 'insurance-label', 'نقابة');
    await tapKey(tester, 'insurance-front-camera');
    await tapKey(tester, 'insurance-save');

    expectKept(cards, pruned: true);
    final card = (await tester.runAsync(
      () => db.watchInsuranceCards(sara).first,
    ))!.single;
    expect(card.frontPhoto, cards.imported.single);
  });

  testWidgets('the medicine form saves the medicine before it prunes', (
    tester,
  ) async {
    final sara = await open(tester, (id) => '/family/$id/medicines/new');
    await type(tester, 'medicine-name', 'دواء');
    await tapKey(tester, 'medicine-photo-camera');
    await tapKey(tester, 'medicine-save');

    expectKept(medicines, pruned: true);
    final m = (await tester.runAsync(() => db.watchMedicines(sara).first))!
        .single;
    expect(decodeMedicinePhotos(m.photosJson), medicines.imported);
  });

  testWidgets('the prescription form saves it before it prunes', (
    tester,
  ) async {
    final sara = await open(tester, (id) => '/family/$id/prescriptions/new');
    await type(tester, 'rx-item-0-name', 'دواء');
    await type(tester, 'rx-item-0-days', '3');
    await tapKey(tester, 'rx-photo-camera');
    await tapKey(tester, 'rx-save');

    expectKept(medicines, pruned: true);
    final rx = (await tester.runAsync(() => db.watchPrescriptions(sara).first))!
        .single;
    expect(decodeMedicinePhotos(rx.photosJson), medicines.imported);
  });

  testWidgets('a record form that saves prunes nothing', (tester) async {
    final sara = await open(tester, (id) => '/family/$id/add/visit');
    await type(tester, 'field-doctorName', 'د. هاني');
    await tapKey(tester, 'record-photo-camera');
    await tapKey(tester, 'record-save');

    expectKept(attachments, pruned: false);
    final event = (await tester.runAsync(() => db.watchTimeline(sara).first))!
        .single;
    final saved = (await tester.runAsync(
      () => db.watchAttachments(event.id).first,
    ))!;
    expect([for (final a in saved) a.path], attachments.imported);
  });

  // go_router keeps a screen's State when only the path's values change, and
  // the Add sheet can open the same form for another person.
  for (final (name, path, pickKey, preview) in [
    (
      'insurance',
      'insurance/new',
      'insurance-front-camera',
      'insurance-front-preview',
    ),
    (
      'medicine',
      'medicines/new',
      'medicine-photo-camera',
      'medicine-photo-preview-0',
    ),
    (
      'prescription',
      'prescriptions/new',
      'rx-photo-camera',
      'rx-photo-preview-0',
    ),
    ('record', 'add/visit', 'record-photo-camera', 'record-photo-0'),
  ]) {
    testWidgets('the $name form opened for someone else drops the photo', (
      tester,
    ) async {
      await open(tester, (id) => '/family/$id/$path');
      final omar = (await tester.runAsync(() => db.addProfile('عمر')))!;
      await tapKey(tester, pickKey);
      expect(find.byKey(ValueKey(preview)), findsOneWidget);

      GoRouter.of(tester.element(find.byType(Scaffold).first))
          .go('/family/$omar/$path');
      await tester.pumpAndSettle();

      expect(find.byKey(ValueKey(preview)), findsNothing);
    });
  }
}
