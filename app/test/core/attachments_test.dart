import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:usra/core/database/app_database.dart';

void main() {
  late AppDatabase db;
  late String mom;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    mom = await db.addProfile('Fatma');
  });
  tearDown(() => db.close());

  Future<String> visit({List<String> photos = const []}) => db.addEvent(
    profileId: mom,
    type: 'visit',
    occurredAt: DateTime.utc(2026, 10, 1),
    photos: photos,
  );

  Future<List<String>> outboxOf(String entity) async {
    final rows = await (db.select(
      db.outboxEntries,
    )..where((o) => o.entity.equals(entity))).get();
    return [for (final r in rows) '${r.operation} ${r.entityId}'];
  }

  group('attachments', () {
    test('a record saves its photos in order and queues them', () async {
      final id = await visit(
        photos: ['attachments/a.jpg', 'attachments/b.jpg'],
      );
      final photos = await db.watchAttachments(id).first;
      expect(photos.map((a) => a.path), [
        'attachments/a.jpg',
        'attachments/b.jpg',
      ]);
      expect(photos.every((a) => a.kind == 'photo'), isTrue);
      expect(photos.first.caption, isNull);
      expect(await outboxOf('attachment'), [
        for (final a in photos) 'upsert ${a.id}',
      ]);
      expect(await db.liveAttachmentPaths(), {
        'attachments/a.jpg',
        'attachments/b.jpg',
      });
    });

    test('photos can be added to a record and deleted one by one', () async {
      final id = await visit();
      expect(await db.watchAttachments(id).first, isEmpty);

      final [first, second] = await db.addAttachments(id, [
        'attachments/1.jpg',
        'attachments/2.jpg',
      ]);
      await db.softDeleteAttachment(first);

      final live = await db.watchAttachments(id).first;
      expect(live.single.id, second);
      expect(await db.liveAttachmentPaths(), {'attachments/2.jpg'});
      // Kept as a tombstone for sync.
      expect(await db.select(db.attachments).get(), hasLength(2));
      expect(await outboxOf('attachment'), [
        'upsert $first',
        'upsert $second',
        'delete $first',
      ]);
    });

    test('photos can\'t be added to a deleted or missing record', () async {
      final id = await visit();
      await db.softDeleteEvent(id);
      expect(
        () => db.addAttachments(id, ['attachments/x.jpg']),
        throwsStateError,
      );
      expect(
        () => db.addAttachments('nope', ['attachments/x.jpg']),
        throwsStateError,
      );
      expect(await db.select(db.attachments).get(), isEmpty);
    });

    test('deleting a record deletes its photos, not others', () async {
      final gone = await visit(photos: ['attachments/gone.jpg']);
      final kept = await visit(photos: ['attachments/kept.jpg']);

      await db.softDeleteEvent(gone);
      expect(await db.watchEvent(gone).first, isNull);
      expect(await db.watchAttachments(gone).first, isEmpty);
      expect(await db.watchAttachments(kept).first, hasLength(1));
      expect(await db.liveAttachmentPaths(), {'attachments/kept.jpg'});
      final goneId = (await db.select(db.attachments).get())
          .firstWhere((a) => a.eventId == gone)
          .id;
      expect(await outboxOf('attachment'), contains('delete $goneId'));
    });

    test('deleting a person deletes their records\' photos', () async {
      final kid = await db.addProfile('Omar');
      await visit(photos: ['attachments/mom.jpg']);
      await db.addEvent(
        profileId: kid,
        type: 'lab',
        occurredAt: DateTime.utc(2026, 10, 2),
        photos: ['attachments/kid.jpg'],
      );

      await db.softDeleteProfile(mom);
      expect(await db.liveAttachmentPaths(), {'attachments/kid.jpg'});
      final deleted = await (db.select(
        db.attachments,
      )..where((a) => a.deletedAt.isNotNull())).get();
      expect(deleted.single.path, 'attachments/mom.jpg');
      expect(deleted.single.updatedAt, deleted.single.deletedAt);
    });

    test('the timeline counts each record\'s live photos', () async {
      final two = await visit(
        photos: ['attachments/1.jpg', 'attachments/2.jpg'],
      );
      final one = await visit(photos: ['attachments/3.jpg']);
      await visit();
      final other = await db.addProfile('Omar');
      await db.addEvent(
        profileId: other,
        type: 'lab',
        occurredAt: DateTime.utc(2026),
        photos: ['attachments/4.jpg'],
      );
      final [first, _] = await db.watchAttachments(two).first;
      await db.softDeleteAttachment(first.id);

      expect(await db.watchAttachmentCounts(mom).first, {two: 1, one: 1});
    });

    test('an attachment must belong to a record', () {
      expect(
        () => db
            .into(db.attachments)
            .insert(
              AttachmentsCompanion.insert(
                id: 'a1',
                eventId: 'missing',
                path: 'attachments/x.jpg',
                createdAt: DateTime.utc(2026),
                updatedAt: DateTime.utc(2026),
              ),
            ),
        throwsA(isA<SqliteException>()),
      );
    });
  });

  test('a v4 database gains the attachments table on upgrade', () async {
    final dir = await Directory.systemTemp.createTemp('usra_v4');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/v4.db');

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
      CREATE TABLE insurance_cards (id TEXT NOT NULL PRIMARY KEY,
        profile_id TEXT NOT NULL REFERENCES profiles (id), label TEXT NOT NULL,
        insurer TEXT, member_number TEXT, expires_on INTEGER, notes TEXT,
        front_photo TEXT, back_photo TEXT,
        updated_at INTEGER NOT NULL, deleted_at INTEGER);
      CREATE TABLE outbox_entries (id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        entity TEXT NOT NULL, entity_id TEXT NOT NULL, operation TEXT NOT NULL,
        created_at INTEGER NOT NULL);
      INSERT INTO profiles (id, display_name, updated_at) VALUES ('p1', 'Mona', 0);
      INSERT INTO medical_events (id, profile_id, type, occurred_at, updated_at)
        VALUES ('e1', 'p1', 'lab', 0, 0);
      INSERT INTO insurance_cards (id, profile_id, label, updated_at)
        VALUES ('c1', 'p1', 'شغل', 0);
      PRAGMA user_version = 4;
    ''');
    raw.close();

    final upgraded = AppDatabase(NativeDatabase(file));
    addTearDown(upgraded.close);
    await upgraded.addAttachments('e1', ['attachments/lab.jpg']);
    expect(
      (await upgraded.watchAttachments('e1').first).single.path,
      'attachments/lab.jpg',
    );
    // Earlier data is untouched.
    expect((await upgraded.watchTimeline('p1').first).single.id, 'e1');
    expect(
      (await upgraded.watchInsuranceCards('p1').first).single.label,
      'شغل',
    );
  });
}
