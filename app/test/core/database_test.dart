import 'package:drift/drift.dart' show Value;

import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usra/core/database/app_database.dart';
import 'package:usra/core/database/connection.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('adding a profile also queues it for sync', () async {
    final id = await db.addProfile('Fatma');
    final profiles = await db.watchProfiles().first;
    expect(profiles.single.displayName, 'Fatma');

    final outbox = await db.select(db.outboxEntries).get();
    expect(outbox.single.entityId, id);
    expect(outbox.single.operation, 'upsert');
  });

  test('soft-deleted profiles are hidden but kept for sync', () async {
    final id = await db.addProfile('Karim');
    await db.softDeleteProfile(id);
    expect(await db.watchProfiles().first, isEmpty);
    expect(await db.select(db.profiles).get(), hasLength(1));
  });

  test('timeline lists a profile\'s events newest first', () async {
    final id = await db.addProfile('Yassin');
    await db.addEvent(
      profileId: id,
      type: 'vaccine',
      occurredAt: DateTime.utc(2026, 1, 1),
    );
    await db.addEvent(
      profileId: id,
      type: 'visit',
      occurredAt: DateTime.utc(2026, 10, 1),
    );
    final timeline = await db.watchTimeline(id).first;
    expect(timeline.map((e) => e.type), ['visit', 'vaccine']);
  });

  test('events must belong to an existing profile', () async {
    expect(
      () => db.addEvent(
        profileId: 'missing',
        type: 'visit',
        occurredAt: DateTime.utc(2026),
      ),
      throwsA(isA<Exception>()),
    );
  });

  test('generated database keys are 256-bit hex', () {
    final key = DatabaseKeyStore.generateKey(Random(1));
    expect(key, matches(RegExp(r'^[0-9a-f]{64}$')));
    expect(
      DatabaseKeyStore.generateKey(),
      isNot(DatabaseKeyStore.generateKey()),
    );
  });

  test('blank names are refused', () async {
    expect(() => db.addProfile('   '), throwsArgumentError);
  });

  test('profiles keep the order they were added, even after edits', () async {
    final first = await db.addProfile('Fatma');
    await db.addProfile('Karim');
    await (db.update(db.profiles)..where((p) => p.id.equals(first))).write(
      ProfilesCompanion(updatedAt: Value(DateTime.utc(2030))),
    );
    final names = (await db.watchProfiles().first).map((p) => p.displayName);
    expect(names, ['Fatma', 'Karim']);
  });

  test('deleting a profile also deletes and queues its records', () async {
    final id = await db.addProfile('Karim');
    final eventId = await db.addEvent(
      profileId: id,
      type: 'visit',
      occurredAt: DateTime.utc(2026),
    );
    await db.softDeleteProfile(id);

    expect(await db.watchTimeline(id).first, isEmpty);
    final queued = await (db.select(
      db.outboxEntries,
    )..where((o) => o.entityId.equals(eventId))).get();
    expect(queued.map((o) => o.operation), ['upsert', 'delete']);
  });
}
