// Backup and restore of the founder's family of 12 Nov 2026: everything
// recorded for جميلة (two today) comes back identical on a new phone.

import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:usra/core/backup/backup_crypto.dart';
import 'package:usra/core/backup/backup_service.dart';
import 'package:usra/core/backup/recovery_key.dart';
import 'package:usra/core/database/app_database.dart';
import 'package:usra/core/database/connection.dart';
import 'package:usra/core/files/photo_crypto.dart';

/// Cheap Argon2id so the test runs fast; real backups use the standard cost.
const _testKdf = BackupKdf(memory: 64, iterations: 1, parallelism: 1);

class _Phone {
  _Phone(this.dir)
    : key = DatabaseKeyStore.generateKey(),
      photoKeys = PhotoKeys.ready(PhotoCipher(PhotoCipher.generateKey())),
      root = Directory(p.join(dir.path, 'support'))..createSync(),
      temp = Directory(p.join(dir.path, 'tmp'))..createSync();

  final Directory dir;
  final String key;
  final PhotoKeys photoKeys;
  final keyStore = MemoryPhotoKeyStore();
  final Directory root;
  final Directory temp;

  late final service = BackupService(
    root: root,
    databaseName: 'usra.sqlite',
    deviceKey: key,
    photoKeys: photoKeys,
    photoKeyStore: keyStore,
    temporary: temp,
    folders: const ['insurance_cards', 'attachments', 'medicines'],
    files: const ['follow_up_dismissals.json'],
    kdf: _testKdf,
    chunkSize: 4096,
  );

  AppDatabase open() => AppDatabase(
    openEncryptedDatabase(File(p.join(root.path, 'usra.sqlite')), key),
  );
}

/// Every row of every table, as plain values, ordered, so two databases can
/// be compared whole.
Future<Map<String, List<Map<String, Object?>>>> dump(AppDatabase db) async {
  final out = <String, List<Map<String, Object?>>>{};
  for (final t in db.allTables) {
    final rows = await db
        .customSelect('SELECT * FROM "${t.actualTableName}" ORDER BY 1')
        .get();
    out[t.actualTableName] = [for (final r in rows) r.data];
  }
  return out;
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late Directory dir;
  final recovery = RecoveryKey.generate();

  setUp(() => dir = Directory.systemTemp.createTempSync('usra_two_year_old'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('her records restore identical on a new phone', () async {
    final oldPhone = _Phone(Directory(p.join(dir.path, 'old'))..createSync());
    final newPhone = _Phone(Directory(p.join(dir.path, 'new'))..createSync());

    final db = oldPhone.open();
    late Map<String, List<Map<String, Object?>>> before;
    late String gamila;
    late File backup;
    try {
      final me = await db.addProfile(
        'أنا',
        sex: 'female',
        birthDate: DateTime(1990),
      );
      gamila = await db.addProfile(
        'جميلة',
        sex: 'female',
        birthDate: DateTime(2024, 11, 12),
        relationship: 'daughter',
        bloodType: 'A+',
        allergies: 'بنسلين',
      );
      await db.addEvent(
        profileId: gamila,
        type: 'growth',
        occurredAt: DateTime(2026, 11, 12),
        dataJson: jsonEncode({
          'weightKg': 12.0,
          'heightCm': 86.0,
          'headCm': 47.0,
        }),
      );
      await db.addEvent(
        profileId: gamila,
        type: 'vaccine',
        occurredAt: DateTime(2026, 11, 12),
        dataJson: jsonEncode({'vaccine': 'MMR', 'dose': '1'}),
      );
      await db.addEvent(
        profileId: gamila,
        type: 'visit',
        occurredAt: DateTime(2026, 11, 12),
        dataJson: jsonEncode({'doctorName': 'د. منى'}),
        costMinor: 30000,
        currency: 'EGP',
      );
      await db.addEvent(
        profileId: me,
        type: 'visit',
        occurredAt: DateTime(2026, 10, 20),
        costMinor: 20000,
        currency: 'EGP',
        dataJson: jsonEncode({'doctorName': 'د. سامي'}),
      );
      final episode = await db.saveEpisode(
        profileId: gamila,
        startedAt: DateTime(2026, 11, 12, 8),
      );
      for (final (h, v) in [(8, 38.5), (12, 39.1), (18, 37.8)]) {
        await db.saveReading(
          episodeId: episode,
          takenAt: DateTime(2026, 11, 12, h),
          value: v,
          unit: 'c',
        );
      }
      final med = await db.saveMedicine(
        profileId: gamila,
        name: 'باراسيتامول شراب',
        instructions: '5 مل',
        startOn: DateTime(2026, 11, 12),
        endOn: DateTime(2026, 11, 16),
        schedule: const DoseScheduleInput(times: ['08:00', '20:00']),
      );
      await db.logDose(med, DateTime(2026, 11, 12, 8).toUtc(), 'taken');
      await db.saveInsuranceCard(
        profileId: gamila,
        label: 'شغل ماما',
        expiresOn: DateTime.utc(2027, 6, 30),
      );
      before = await dump(db);
      backup = (await oldPhone.service.create(
        db,
        recovery,
        appVersion: '0.1.0+1',
        now: DateTime.utc(2026, 11, 12, 10),
      )).file;
    } finally {
      await db.close();
    }

    // A fresh phone, with data of its own that the restore replaces.
    final fresh = newPhone.open();
    await fresh.addProfile('Someone else');
    await fresh.close();
    final staged = await newPhone.service.stage(
      backup,
      recovery,
      currentSchema: AppDatabase.currentSchema,
    );
    expect(staged.manifest.count('people'), 2);
    await newPhone.service.commit();
    await newPhone.service.discardAside();

    final restored = newPhone.open();
    addTearDown(restored.close);
    final after = await dump(restored);
    expect(after.keys, before.keys);
    for (final table in before.keys) {
      expect(after[table], before[table], reason: table);
    }
    final her = (await restored.watchProfile(gamila).first)!;
    expect(her.displayName, 'جميلة');
    expect(her.birthDate, DateTime(2024, 11, 12));
    expect((await restored.watchTimeline(gamila).first).length, 3);
  });
}
