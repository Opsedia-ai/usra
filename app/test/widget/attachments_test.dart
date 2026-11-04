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
import 'package:usra/core/files/photo_store.dart';
import 'package:usra/core/providers.dart';

import '../support/sync_photo_store.dart';

void main() {
  late AppDatabase db;
  late Directory dir;
  late SyncPhotoStore photos;
  final picked = <File>[];
  final shared = <ShareParams>[];
  // What each shared file held while the share sheet was open.
  final sharedBytes = <List<int>>[];
  late SyncSharedPhotoCache shareCache;

  /// A new temporary file, like the picker hands back.
  String pick() {
    final f = File('${dir.path}/picked_${picked.length}.jpg')
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
    dir = Directory.systemTemp.createTempSync('usra_attachments');
    photos = SyncPhotoStore(
      Directory('${dir.path}/support'),
      PhotoStore.attachmentsFolder,
    );
    shareCache = SyncSharedPhotoCache(Directory('${dir.path}/cache'));
    picked.clear();
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
      attachmentStoreProvider.overrideWithValue(photos),
      photoPickerProvider.overrideWithValue((_) async => pick()),
      multiPhotoPickerProvider.overrideWithValue(() async => [pick(), pick()]),
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

  Future<List<Attachment>> live(WidgetTester tester, String eventId) async =>
      (await tester.runAsync(() => db.watchAttachments(eventId).first))!;

  testWidgets('save a visit with photos, view, send and delete them', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 3000);
    tester.view.devicePixelRatio = 1.5;
    addTearDown(tester.view.reset);
    final mom = (await tester.runAsync(() => db.addProfile('فاطمة')))!;
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.byType(Scaffold).first))
        .go('/family/$mom/add/visit');
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('field-doctorName')),
      'د. هاني',
    );
    // One from the camera, two from the gallery, then one taken back out.
    await tapKey(tester, 'record-photo-camera');
    await tapKey(tester, 'record-photo-gallery');
    expect(find.byKey(const ValueKey('record-photo-2')), findsOneWidget);
    await tapKey(tester, 'record-photo-remove-1');
    expect(find.byKey(const ValueKey('record-photo-2')), findsNothing);
    expect(picked[1].existsSync(), isFalse);
    await tapKey(tester, 'record-save');

    final event = (await tester.runAsync(() => db.watchTimeline(mom).first))!
        .single;
    final saved = await live(tester, event.id);
    expect(saved, hasLength(2));
    for (final a in saved) {
      expect(photos.fileOf(a.path).existsSync(), isTrue);
    }
    expect([for (final a in saved) photos.readSync(a.path).single], [0, 2]);
    // Encrypted on disk.
    for (final a in saved) {
      expect(
        PhotoCipher.isSealed(photos.fileOf(a.path).readAsBytesSync()),
        isTrue,
      );
    }
    // The picker's temporary copies are gone once saved.
    expect(picked.where((f) => f.existsSync()), isEmpty);

    // Back on the timeline, the record shows it has photos.
    expect(find.byKey(ValueKey('event-photos-${event.id}')), findsOneWidget);
    await tapKey(tester, 'event-${event.id}');
    expect(find.text('د. هاني'), findsOneWidget);
    expect(find.byKey(const ValueKey('record-thumb-1')), findsOneWidget);

    await tapKey(tester, 'record-share');
    expect(shared.single.text, contains('د. هاني'));
    expect(shared.single.files, hasLength(2));

    // Full screen: send the second photo, then delete it.
    await tapKey(tester, 'record-thumb-1');
    expect(find.text('صورة 2 من 2'), findsOneWidget);
    await tapKey(tester, 'photo-share');
    // Decrypted for the share sheet, and the copy is gone afterwards.
    expect(sharedBytes.last, [2]);
    expect(shareCache.dir.existsSync(), isFalse);
    await tapKey(tester, 'photo-delete');
    await tapKey(tester, 'photo-delete-confirm');
    expect(find.byKey(const ValueKey('record-thumb-1')), findsNothing);
    expect(find.byKey(const ValueKey('record-thumb-0')), findsOneWidget);
    expect((await live(tester, event.id)).single.id, saved[0].id);
    expect(photos.fileOf(saved[1].path).existsSync(), isFalse);

    // Deleting the record takes its photos off the phone.
    await tapKey(tester, 'record-delete');
    await tapKey(tester, 'record-delete-confirm');
    expect(find.byKey(ValueKey('event-${event.id}')), findsNothing);
    expect(photos.fileOf(saved[0].path).existsSync(), isFalse);
  });

  testWidgets('leaving the form without saving discards picked photos', (
    tester,
  ) async {
    final mom = (await tester.runAsync(() => db.addProfile('فاطمة')))!;
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
    router.go('/family/$mom/add/lab');
    await tester.pumpAndSettle();
    await tapKey(tester, 'record-photo-gallery');
    expect(picked.every((f) => f.existsSync()), isTrue);

    router.go('/family/$mom');
    await tester.pumpAndSettle();
    expect(picked.where((f) => f.existsSync()), isEmpty);
    expect(
      await tester.runAsync(() => db.select(db.attachments).get()),
      isEmpty,
    );
  });
}
