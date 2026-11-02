import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:usra/core/database/app_database.dart';
import 'package:usra/features/family/family_screen.dart';

void main() {
  group('ageInYears', () {
    final now = DateTime(2026, 11, 2);
    test('counts whole years, before and after the birthday', () {
      expect(ageInYears(DateTime(1954, 11, 2), now), 72);
      expect(ageInYears(DateTime(1954, 11, 3), now), 71);
      expect(ageInYears(DateTime(2024, 10, 1), now), 2);
    });
    test('unknown or future birth dates give no age', () {
      expect(ageInYears(null, now), isNull);
      expect(ageInYears(DateTime(2027, 1, 1), now), isNull);
    });
  });

  test(
    'profile details can be added and edited, blanks become empty',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      final id = await db.addProfile(
        'Fatma',
        sex: 'female',
        bloodType: 'O+',
        allergies: 'Penicillin',
      );
      var p = (await db.watchProfile(id).first)!;
      expect(
        [p.sex, p.bloodType, p.allergies, p.conditions],
        ['female', 'O+', 'Penicillin', null],
      );

      await db.updateProfile(
        id,
        displayName: ' Fatma Hassan ',
        bloodType: 'O+',
        allergies: '  ',
        conditions: 'Diabetes',
      );
      p = (await db.watchProfile(id).first)!;
      expect(p.displayName, 'Fatma Hassan');
      expect(p.allergies, isNull);
      expect(p.conditions, 'Diabetes');
    },
  );

  test('a deleted event leaves the timeline and is queued for sync', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final id = await db.addProfile('Karim');
    final eventId = await db.addEvent(
      profileId: id,
      type: 'lab',
      occurredAt: DateTime.utc(2026, 10, 20),
    );
    await db.softDeleteEvent(eventId);
    expect(await db.watchTimeline(id).first, isEmpty);
    final ops = await (db.select(
      db.outboxEntries,
    )..where((o) => o.entityId.equals(eventId))).get();
    expect(ops.map((o) => o.operation), ['upsert', 'delete']);
  });

  test('a version 1 database upgrades and keeps its people', () async {
    // The schema as shipped in M0 (version 1).
    final raw = sqlite3.openInMemory();
    raw.execute('''
      CREATE TABLE profiles (id TEXT NOT NULL PRIMARY KEY, display_name TEXT NOT NULL,
        birth_date INTEGER NULL, sex TEXT NULL,
        simple_mode INTEGER NOT NULL DEFAULT 0 CHECK (simple_mode IN (0, 1)),
        updated_at INTEGER NOT NULL, deleted_at INTEGER NULL);
      CREATE TABLE medical_events (id TEXT NOT NULL PRIMARY KEY,
        profile_id TEXT NOT NULL REFERENCES profiles (id), type TEXT NOT NULL,
        occurred_at INTEGER NOT NULL, doctor_id TEXT NULL, cost_minor INTEGER NULL,
        currency TEXT NULL, data_json TEXT NOT NULL DEFAULT '{}',
        updated_at INTEGER NOT NULL, deleted_at INTEGER NULL);
      CREATE TABLE outbox_entries (id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        entity TEXT NOT NULL, entity_id TEXT NOT NULL, operation TEXT NOT NULL,
        created_at INTEGER NOT NULL);
      INSERT INTO profiles (id, display_name, updated_at) VALUES ('p1', 'Yassin', 0);
      PRAGMA user_version = 1;
    ''');
    final db = AppDatabase(NativeDatabase.opened(raw));
    addTearDown(db.close);

    final people = await db.watchProfiles().first;
    expect(people.single.displayName, 'Yassin');
    expect(people.single.bloodType, isNull);
    await db.updateProfile('p1', displayName: 'Yassin', bloodType: 'A+');
    expect((await db.watchProfile('p1').first)!.bloodType, 'A+');
  });
}
