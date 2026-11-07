import 'dart:io';

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:usra/app.dart';
import 'package:usra/core/database/app_database.dart';
import 'package:usra/core/providers.dart';
import 'package:usra/core/files/photo_store.dart';

import '../support/sync_photo_store.dart';

void main() {
  late AppDatabase db;
  late Directory dir;
  late File picked;
  late SyncPhotoStore photos;
  final shared = <ShareParams>[];
  final sharedBytes = <List<int>>[];
  late SyncSharedPhotoCache shareCache;

  setUp(() {
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    dir = Directory.systemTemp.createTempSync('usra_cards');
    picked = File('${dir.path}/picked.jpg')..writeAsBytesSync([0, 1, 2]);
    photos = SyncPhotoStore(
      Directory('${dir.path}/support'),
      PhotoStore.cardsFolder,
    );
    shareCache = SyncSharedPhotoCache(Directory('${dir.path}/cache'));
    shared.clear();
    sharedBytes.clear();
  });
  tearDown(() async {
    await db.close();
    dir.deleteSync(recursive: true);
  });

  Widget app() => ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      cardPhotoStoreProvider.overrideWithValue(photos),
      photoPickerProvider.overrideWithValue((_) async => picked.path),
      sharedPhotoCacheProvider.overrideWithValue(shareCache),
      shareProvider.overrideWithValue((p) async {
        shared.add(p);
        for (final f in p.files ?? <XFile>[]) {
          sharedBytes.add(File(f.path).readAsBytesSync());
        }
      }),
    ],
    child: const UsraApp(),
  );

  Future<void> tapKey(WidgetTester tester, String key) async {
    await tester.ensureVisible(find.byKey(ValueKey(key)));
    await tester.tap(find.byKey(ValueKey(key)));
    await tester.pumpAndSettle();
  }

  testWidgets('add a card with a photo, send it, then delete it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 3000);
    tester.view.devicePixelRatio = 1.5;
    addTearDown(tester.view.reset);
    // Database calls outside the widgets run on real time, not fake time.
    final mom = (await tester.runAsync(() => db.addProfile('فاطمة')))!;
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
    router.go('/family/$mom');
    await tester.pumpAndSettle();
    await tapKey(tester, 'member-insurance');
    expect(find.text('كروت التأمين'), findsOneWidget);

    await tapKey(tester, 'insurance-add');
    // The card needs a name.
    await tapKey(tester, 'insurance-save');
    expect(find.text('مطلوب'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('insurance-label')),
      'نقابة',
    );
    await tester.enterText(
      find.byKey(const ValueKey('insurance-insurer')),
      'مصر للتأمين',
    );
    await tester.enterText(
      find.byKey(const ValueKey('insurance-member')),
      '998877',
    );
    await tapKey(tester, 'insurance-front-camera');
    expect(
      find.byKey(const ValueKey('insurance-front-preview')),
      findsOneWidget,
    );
    await tapKey(tester, 'insurance-save');

    // On the card's page, with the photo copied into the app.
    final card = (await tester.runAsync(
      () => db.watchInsuranceCards(mom).first,
    ))!.single;
    expect(card.frontPhoto, isNotNull);
    expect(photos.fileOf(card.frontPhoto!).existsSync(), isTrue);
    // The picker's temporary copy is gone once saved.
    expect(picked.existsSync(), isFalse);
    expect(find.text('998877'), findsOneWidget);

    // First a warning that it leaves the app's protection (S7).
    await tapKey(tester, 'insurance-share');
    expect(find.byKey(const ValueKey('share-warning')), findsOneWidget);
    await tapKey(tester, 'share-warning-cancel');
    expect(shared, isEmpty);
    expect(shareCache.dir.existsSync(), isFalse);
    await tapKey(tester, 'insurance-share');
    await tapKey(tester, 'share-warning-go');
    final sent = shared.single;
    expect(sent.text, contains('كارت التأمين بتاع فاطمة'));
    expect(sent.text, contains('رقم العضوية: 998877'));
    expect(sent.files, hasLength(1));
    expect(sharedBytes.single, [0, 1, 2]);
    expect(shareCache.dir.existsSync(), isFalse);

    await tapKey(tester, 'insurance-delete');
    await tapKey(tester, 'insurance-delete-confirm');
    expect(find.text('نقابة'), findsNothing);
    expect(find.text('التأمين'), findsOneWidget);
    // The photo left the phone with its card.
    expect(photos.fileOf(card.frontPhoto!).existsSync(), isFalse);
  });

  testWidgets('cards near or past expiry are flagged in the person\'s list', (
    tester,
  ) async {
    final today = DateTime.now();
    final kid = (await tester.runAsync(() async {
      final id = await db.addProfile('عمر');
      await db.saveInsuranceCard(
        profileId: id,
        label: 'شغل 1',
        expiresOn: today.add(const Duration(days: 10)),
      );
      await db.saveInsuranceCard(
        profileId: id,
        label: 'شغل 2',
        expiresOn: today.subtract(const Duration(days: 3)),
      );
      return id;
    }))!;
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.byType(Scaffold).first))
        .go('/family/$kid/insurance');
    await tester.pumpAndSettle();

    expect(find.text('شغل 1'), findsOneWidget);
    expect(find.text('شغل 2'), findsOneWidget);
    expect(find.textContaining('بينتهي'), findsOneWidget);
    expect(find.textContaining('انتهى'), findsOneWidget);
  });
}
