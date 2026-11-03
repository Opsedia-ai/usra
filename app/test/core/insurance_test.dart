import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:usra/core/database/app_database.dart';
import 'package:usra/core/design/tokens.dart';
import 'package:usra/core/files/photo_store.dart';
import 'package:usra/features/insurance/insurance_info.dart';

void main() {
  group('cards', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('a person can have several cards; edit and delete them', () async {
      final mom = await db.addProfile('Fatma');
      final union = await db.saveInsuranceCard(
        profileId: mom,
        label: ' نقابة ',
        insurer: 'AXA',
        memberNumber: '12345',
        expiresOn: DateTime(2027, 3, 31, 18, 30),
        notes: '  ',
        frontPhoto: 'insurance_cards/a.jpg',
      );
      final work = await db.saveInsuranceCard(profileId: mom, label: 'شغل 1');

      var cards = await db.watchInsuranceCards(mom).first;
      expect(cards.map((c) => c.label), ['نقابة', 'شغل 1']);
      final c = cards.first;
      expect([c.insurer, c.memberNumber, c.notes], ['AXA', '12345', null]);
      // Only the day is kept.
      expect(expiryDay(c.expiresOn), DateTime(2027, 3, 31));

      await db.saveInsuranceCard(
        id: union,
        profileId: mom,
        label: 'نقابة المهندسين',
        backPhoto: 'insurance_cards/b.jpg',
      );
      final edited = (await db.watchInsuranceCard(union).first)!;
      expect(edited.label, 'نقابة المهندسين');
      expect(
        [edited.insurer, edited.frontPhoto, edited.expiresOn],
        [null, null, null],
      );
      expect(await db.liveInsurancePhotos(), {'insurance_cards/b.jpg'});

      await db.softDeleteInsuranceCard(work);
      cards = await db.watchInsuranceCards(mom).first;
      expect(cards.single.id, union);
      expect(await db.watchInsuranceCard(work).first, isNull);
      // Kept as a tombstone for sync.
      expect(await db.select(db.insuranceCards).get(), hasLength(2));

      final outbox = await (db.select(
        db.outboxEntries,
      )..where((o) => o.entity.equals('insurance_card'))).get();
      expect(outbox.map((o) => o.operation), [
        'upsert',
        'upsert',
        'upsert',
        'delete',
      ]);
    });

    test('a deleted card cannot be saved again', () async {
      final id = await db.addProfile('Omar');
      final card = await db.saveInsuranceCard(profileId: id, label: 'شغل');
      await db.softDeleteInsuranceCard(card);
      await expectLater(
        db.saveInsuranceCard(id: card, profileId: id, label: 'شغل 2'),
        throwsStateError,
      );
      expect(await db.watchInsuranceCard(card).first, isNull);
    });

    test('a blank card name is refused', () async {
      final id = await db.addProfile('Omar');
      expect(
        () => db.saveInsuranceCard(profileId: id, label: ' '),
        throwsArgumentError,
      );
    });

    test(
      'deleting a person deletes their cards and frees the photos',
      () async {
        final dad = await db.addProfile('Ahmed');
        final kid = await db.addProfile('Omar');
        await db.saveInsuranceCard(
          profileId: dad,
          label: 'شغل',
          frontPhoto: 'insurance_cards/dad.jpg',
        );
        await db.saveInsuranceCard(
          profileId: kid,
          label: 'مدرسة',
          frontPhoto: 'insurance_cards/kid.jpg',
        );

        await db.softDeleteProfile(dad);
        expect(await db.watchInsuranceCards(dad).first, isEmpty);
        expect(await db.watchInsuranceCards(kid).first, hasLength(1));
        expect(await db.liveInsurancePhotos(), {'insurance_cards/kid.jpg'});
      },
    );
  });

  test('expiry: within 30 days is a heads-up, past is urgent', () {
    final today = DateTime(2026, 11, 3, 15);
    DateTime stored(int y, int m, int d) => DateTime.utc(y, m, d);
    expect(expirySeverity(null, today), isNull);
    expect(expirySeverity(stored(2026, 11, 2), today), Severity.urgent);
    // The last valid day is still valid.
    expect(expirySeverity(stored(2026, 11, 3), today), Severity.headsUp);
    expect(expirySeverity(stored(2026, 12, 3), today), Severity.headsUp);
    expect(expirySeverity(stored(2026, 12, 4), today), Severity.info);
  });

  test('the share text is short Arabic with name, insurer and number', () {
    final card = InsuranceCard(
      id: '1',
      profileId: 'p',
      label: 'نقابة',
      insurer: 'مصر للتأمين',
      memberNumber: '998877',
      updatedAt: DateTime.utc(2026),
    );
    expect(
      insuranceShareText('فاطمة', card),
      'كارت التأمين بتاع فاطمة\n'
      'الكارت: نقابة\n'
      'شركة التأمين: مصر للتأمين\n'
      'رقم العضوية: 998877',
    );
  });

  test('photos are copied in privately and pruned when unused', () async {
    final dir = await Directory.systemTemp.createTemp('usra_photos');
    addTearDown(() => dir.delete(recursive: true));
    final picked = File('${dir.path}/picked.JPG')..writeAsBytesSync([1, 2]);
    final store = PhotoStore(
      Directory('${dir.path}/support'),
      PhotoStore.cardsFolder,
    );

    final a = await store.import(picked.path);
    final b = await store.import(picked.path);
    expect(a, startsWith('insurance_cards/'));
    expect(a, endsWith('.jpg'));
    expect(a, isNot(b));
    expect(store.fileOf(a).readAsBytesSync(), [1, 2]);

    await store.prune({b});
    expect(store.fileOf(a).existsSync(), isFalse);
    expect(store.fileOf(b).existsSync(), isTrue);
    // The picked original is left alone.
    expect(picked.existsSync(), isTrue);
  });

  test('a v3 database gains the insurance cards table on upgrade', () async {
    final dir = await Directory.systemTemp.createTemp('usra_v3');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/v3.db');

    final raw = sqlite3.open(file.path);
    raw.execute('''
      CREATE TABLE profiles (id TEXT NOT NULL PRIMARY KEY, display_name TEXT NOT NULL,
        birth_date INTEGER, sex TEXT, simple_mode INTEGER NOT NULL DEFAULT 0,
        blood_type TEXT, allergies TEXT, conditions TEXT,
        updated_at INTEGER NOT NULL, deleted_at INTEGER);
      CREATE TABLE medical_events (id TEXT NOT NULL PRIMARY KEY,
        profile_id TEXT NOT NULL REFERENCES profiles (id), type TEXT NOT NULL,
        occurred_at INTEGER NOT NULL, doctor_id TEXT, cost_minor INTEGER,
        currency TEXT, data_json TEXT NOT NULL DEFAULT '{}',
        updated_at INTEGER NOT NULL, deleted_at INTEGER);
      CREATE TABLE doctors (id TEXT NOT NULL PRIMARY KEY, name TEXT NOT NULL,
        specialty TEXT, phone TEXT, clinic TEXT, address TEXT,
        fee_minor INTEGER, notes TEXT,
        updated_at INTEGER NOT NULL, deleted_at INTEGER);
      CREATE TABLE outbox_entries (id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        entity TEXT NOT NULL, entity_id TEXT NOT NULL, operation TEXT NOT NULL,
        created_at INTEGER NOT NULL);
      INSERT INTO profiles (id, display_name, updated_at) VALUES ('p1', 'Mona', 0);
      INSERT INTO doctors (id, name, updated_at) VALUES ('d1', 'Dr. Hany', 0);
      PRAGMA user_version = 3;
    ''');
    raw.close();

    final upgraded = AppDatabase(NativeDatabase(file));
    addTearDown(upgraded.close);
    final id = await upgraded.saveInsuranceCard(profileId: 'p1', label: 'شغل');
    expect((await upgraded.watchInsuranceCards('p1').first).single.id, id);
    // Earlier data is untouched.
    expect((await upgraded.watchDoctors().first).single.name, 'Dr. Hany');
    expect((await upgraded.watchProfile('p1').first)!.displayName, 'Mona');
  });
}
