import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:usra/core/database/app_database.dart';
import 'package:usra/core/util/localized_numbers.dart';
import 'package:usra/features/doctors/contact_links.dart';

void main() {
  group('phone links', () {
    test('Egyptian local numbers get the country code for WhatsApp', () {
      expect(
        whatsappUri('010 1234 5678').toString(),
        'https://wa.me/201012345678',
      );
      expect(
        whatsappUri('+20 101 234 5678').toString(),
        'https://wa.me/201012345678',
      );
      expect(
        whatsappUri('00971501234567').toString(),
        'https://wa.me/971501234567',
      );
    });

    test('Arabic-Indic digits work and junk gives no link', () {
      expect(callUri('٠١٠١٢٣٤٥٦٧٨').toString(), 'tel:01012345678');
      expect(callUri('  '), isNull);
      expect(whatsappUri('123'), isNull);
    });
  });

  test('money input round-trips', () {
    expect(parseMoneyMinor('٣٥٠'), 35000);
    expect(parseMoneyMinor('350٫5'), 35050);
    expect(parseMoneyMinor('-1'), isNull);
    expect(formatMoneyInput(35000), '350');
    expect(formatMoneyInput(35050), '350.5');
    expect(formatMoneyInput(35005), '350.05');
  });

  test('doctors can be added, edited and removed; visits stay', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final id = await db.saveDoctor(
      name: ' Dr. Hany ',
      specialty: 'Pediatrics',
      phone: '01012345678',
      feeMinor: 40000,
      clinic: '  ',
    );
    var d = (await db.watchDoctor(id).first)!;
    expect([d.name, d.clinic, d.feeMinor], ['Dr. Hany', null, 40000]);

    await db.saveDoctor(id: id, name: 'Dr. Hany Adel', feeMinor: 45000);
    d = (await db.watchDoctor(id).first)!;
    expect([d.name, d.specialty, d.feeMinor], ['Dr. Hany Adel', null, 45000]);

    final kid = await db.addProfile('Omar');
    await db.addEvent(
      profileId: kid,
      type: 'visit',
      occurredAt: DateTime.utc(2026, 10, 1),
      doctorId: id,
      costMinor: 45000,
    );
    expect(
      (await db.watchDoctorVisits(id).first).single.person.displayName,
      'Omar',
    );

    await db.softDeleteDoctor(id);
    expect(await db.watchDoctors().first, isEmpty);
    expect(await db.watchDoctor(id).first, isNull);
    // The visit itself is untouched.
    expect((await db.watchTimeline(kid).first).single.doctorId, id);
  });

  test('a blank doctor name is refused', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    expect(() => db.saveDoctor(name: '  '), throwsArgumentError);
  });

  test('a v2 database gains the doctors table on upgrade', () async {
    final dir = await Directory.systemTemp.createTemp('usra_v2');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/v2.db');

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
      CREATE TABLE outbox_entries (id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        entity TEXT NOT NULL, entity_id TEXT NOT NULL, operation TEXT NOT NULL,
        created_at INTEGER NOT NULL);
      PRAGMA user_version = 2;
    ''');
    raw.close();

    final db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);
    final id = await db.saveDoctor(name: 'Dr. Mona');
    expect((await db.watchDoctors().first).single.id, id);
  });
}
