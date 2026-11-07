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

void main() {
  late AppDatabase db;
  late Directory dir;
  late SyncPhotoStore photos;
  late String sara;
  late String omar;
  late String medicine;

  setUp(() {
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    dir = Directory.systemTemp.createTempSync('usra_move_ui');
    photos = SyncPhotoStore(
      Directory('${dir.path}/support'),
      PhotoStore.medicinesFolder,
    );
  });
  tearDown(() async {
    await db.close();
    dir.deleteSync(recursive: true);
  });

  Finder key(String k) => find.byKey(ValueKey(k));

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> start(
    WidgetTester tester, {
    bool twoPeople = true,
    String? prescribed,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 1400);
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      sara = await db.addProfile('سارة');
      if (twoPeople) omar = await db.addProfile('عمر');
      if (prescribed != null) {
        await db.savePrescription(
          profileId: sara,
          prescribedOn: DateTime(2026, 11, 1),
          items: [
            PrescriptionItemInput(name: prescribed, times: ['08:00']),
          ],
        );
        medicine = (await db.watchMedicines(sara).first).single.id;
      } else {
        medicine = await db.saveMedicine(
          profileId: sara,
          name: 'جلوكوفاج',
          startOn: DateTime(2026, 11, 1),
          schedule: const DoseScheduleInput(times: ['08:00']),
        );
      }
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          medicinePhotoStoreProvider.overrideWithValue(photos),
          reminderSchedulerProvider.overrideWithValue(FakeReminderScheduler()),
        ],
        child: const UsraApp(),
      ),
    );
    await settle(tester);
    GoRouter.of(tester.element(find.byType(Scaffold).first))
        .go('/family/$sara/medicines/$medicine');
    await settle(tester);
  }

  testWidgets('it isn\'t offered with nobody to move it to', (tester) async {
    await start(tester, twoPeople: false);
    expect(key('medicine-edit'), findsOneWidget);
    expect(key('medicine-move'), findsNothing);
  });

  testWidgets('nothing moves until a person is chosen and it\'s confirmed, and '
      'the screen names both', (tester) async {
    await start(tester);
    await tester.tap(key('medicine-move'));
    await settle(tester);
    expect(find.text('دلوقتي عند سارة'), findsOneWidget);
    // Not the person who already has it.
    expect(key('move-to-$sara'), findsNothing);
    expect(tester.widget<FilledButton>(key('move-confirm')).onPressed, isNull);
    expect(find.text('يفضل عند سارة'), findsOneWidget);
    expect(key('move-warning'), findsNothing);

    await tester.tap(key('move-to-$omar'));
    await tester.pump();
    expect(find.text('نقل لعمر'), findsOneWidget);
    expect(
      find.text('بعد النقل التذكير هيبقى لعمر، مش لسارة.'),
      findsOneWidget,
    );
    final m = (await tester.runAsync(() => db.watchMedicine(medicine).first))!;
    expect(m.profileId, sara);

    await tester.tap(key('move-confirm'));
    await settle(tester);
    final moved = (await tester.runAsync(
      () => db.watchMedicine(medicine).first,
    ))!;
    expect(moved.profileId, omar);
    expect(find.text('الدوا اتنقل لعمر.'), findsOneWidget);
    expect(
      GoRouter.of(tester.element(find.byType(Scaffold).first)).state.uri.path,
      '/family/$omar/medicines/$medicine',
    );
  });

  testWidgets('going back changes nothing', (tester) async {
    await start(tester);
    await tester.tap(key('medicine-move'));
    await settle(tester);
    await tester.tap(key('move-to-$omar'));
    await tester.pump();
    await tester.tap(key('move-cancel'));
    await settle(tester);
    final m = (await tester.runAsync(() => db.watchMedicine(medicine).first))!;
    expect(m.profileId, sara);
    expect(key('medicine-move'), findsOneWidget);
  });

  testWidgets('it says what stays when it\'s on a prescription', (
    tester,
  ) async {
    await start(tester, prescribed: 'بنادول');
    await tester.tap(key('medicine-move'));
    await settle(tester);
    expect(find.text('هيفضل عند سارة'), findsOneWidget);
    expect(find.textContaining('الروشتة'), findsOneWidget);
    await tester.tap(key('move-to-$omar'));
    await tester.pump();
    await tester.tap(key('move-confirm'));
    await settle(tester);
    final moved = (await tester.runAsync(
      () => db.watchMedicine(medicine).first,
    ))!;
    expect(moved.prescriptionId, isNull);
  });
}
