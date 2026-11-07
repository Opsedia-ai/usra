import 'dart:io';

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:usra/core/backup/backup_crypto.dart';
import 'package:usra/core/backup/backup_service.dart';
import 'package:usra/core/backup/recovery_key.dart';
import 'package:usra/core/database/app_database.dart';
import 'package:usra/core/database/connection.dart';
import 'package:usra/core/files/photo_crypto.dart';

import '../generated_migrations/schema.dart';

const _testKdf = BackupKdf(memory: 64, iterations: 1, parallelism: 1);

/// A database as a v8 build left it.
class _V8Database extends AppDatabase {
  _V8Database(super.executor);

  @override
  int get schemaVersion => 8;
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('saving', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('a new person keeps them, blanks saved as nothing', () async {
      final id = await db.addProfile(
        'ليلى',
        relationship: 'daughter',
        emergencyPhone: ' 010 1234 5678 ',
        emergencyContactName: '   ',
      );
      final p = (await db.watchProfile(id).first)!;
      expect(p.relationship, 'daughter');
      expect(p.emergencyPhone, '010 1234 5678');
      expect(p.emergencyContactName, isNull);
    });

    test('a save that leaves them out doesn\'t wipe them', () async {
      final id = await db.addProfile(
        'ليلى',
        relationship: 'daughter',
        emergencyPhone: '0101234',
        emergencyContactName: 'آية',
      );
      // What About you does: it doesn't know about these.
      await db.updateProfile(id, displayName: 'ليلى أحمد');
      final p = (await db.watchProfile(id).first)!;
      expect(p.displayName, 'ليلى أحمد');
      expect(p.relationship, 'daughter');
      expect(p.emergencyPhone, '0101234');
      expect(p.emergencyContactName, 'آية');
    });

    test('the person form can clear them', () async {
      final id = await db.addProfile(
        'ليلى',
        relationship: 'daughter',
        emergencyPhone: '0101234',
        emergencyContactName: 'آية',
      );
      await db.updateProfile(
        id,
        displayName: 'ليلى',
        relationship: const Value(null),
        emergencyPhone: const Value(''),
        emergencyContactName: const Value('  '),
      );
      final p = (await db.watchProfile(id).first)!;
      expect(p.relationship, isNull);
      expect(p.emergencyPhone, isNull);
      expect(p.emergencyContactName, isNull);
    });
  });

  group('migration from v8 (drift_schemas snapshot)', () {
    late SchemaVerifier verifier;
    setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

    test('the upgraded schema matches a fresh v9 one', () async {
      final schema = await verifier.schemaAt(8);
      final upgraded = AppDatabase(schema.newConnection());
      addTearDown(upgraded.close);
      await verifier.migrateAndValidate(upgraded, 9);
    });

    test('a v8 database keeps its people, with the new fields empty', () async {
      final schema = await verifier.schemaAt(8);
      schema.rawDatabase.execute('''
        INSERT INTO profiles (id, display_name, blood_type, updated_at)
          VALUES ('p1', 'Mona', 'O+', 0);
      ''');
      final upgraded = AppDatabase(schema.newConnection());
      addTearDown(upgraded.close);
      final p = (await upgraded.watchProfile('p1').first)!;
      expect(p.displayName, 'Mona');
      expect(p.bloodType, 'O+');
      expect(p.relationship, isNull);
      expect(p.emergencyPhone, isNull);
      expect(p.emergencyContactName, isNull);
    });

    test(
      'running it twice is safe: an older build opened it in between',
      () async {
        final schema = await verifier.schemaAt(9);
        schema.rawDatabase.execute('''
        INSERT INTO profiles (id, display_name, emergency_phone, updated_at)
          VALUES ('p1', 'Mona', '0101234', 0);
        PRAGMA user_version = 8;
      ''');
        final upgraded = AppDatabase(schema.newConnection());
        addTearDown(upgraded.close);
        final p = (await upgraded.watchProfile('p1').first)!;
        expect(p.emergencyPhone, '0101234');
      },
    );
  });

  group('backups', () {
    late Directory dir;
    final recovery = RecoveryKey.generate();

    setUp(() => dir = Directory.systemTemp.createTempSync('usra_contact'));
    tearDown(() => dir.deleteSync(recursive: true));

    ({Directory root, String key, BackupService service}) phone(String name) {
      final root = Directory(p.join(dir.path, name))
        ..createSync(recursive: true);
      final key = DatabaseKeyStore.generateKey();
      return (
        root: root,
        key: key,
        service: BackupService(
          root: root,
          databaseName: 'usra.sqlite',
          deviceKey: key,
          photoKeys: PhotoKeys.ready(PhotoCipher(PhotoCipher.generateKey())),
          photoKeyStore: MemoryPhotoKeyStore(),
          temporary: dir,
          folders: const ['medicines'],
          kdf: _testKdf,
          chunkSize: 4096,
        ),
      );
    }

    File dbFile(Directory root) => File(p.join(root.path, 'usra.sqlite'));

    test('they travel in a backup and come back on a restore', () async {
      final from = phone('from');
      final to = phone('to');
      final db = AppDatabase(
        openEncryptedDatabase(dbFile(from.root), from.key),
      );
      final id = await db.addProfile(
        'ليلى',
        relationship: 'daughter',
        emergencyPhone: '010 1234 5678',
        emergencyContactName: 'آية، مامتها',
      );
      final backup = (await from.service.create(
        db,
        recovery,
        appVersion: '1',
      )).file;
      await db.close();

      await to.service.stage(
        backup,
        recovery,
        currentSchema: AppDatabase.currentSchema,
      );
      await to.service.commit();
      final restored = AppDatabase(
        openEncryptedDatabase(dbFile(to.root), to.key),
      );
      addTearDown(restored.close);
      final p = (await restored.watchProfile(id).first)!;
      expect(p.relationship, 'daughter');
      expect(p.emergencyPhone, '010 1234 5678');
      expect(p.emergencyContactName, 'آية، مامتها');
    });

    test('a backup from before them still restores, with them empty', () async {
      final from = phone('old');
      final to = phone('new');
      // Everything a v8 build has, and no more.
      final current = AppDatabase(
        openEncryptedDatabase(dbFile(from.root), from.key),
      );
      final id = await current.addProfile('سارة', bloodType: 'A+');
      await current.close();
      final raw = sqlite3.open(dbFile(from.root).path);
      unlockDatabase(raw, from.key);
      raw.execute('ALTER TABLE profiles DROP COLUMN relationship');
      raw.execute('ALTER TABLE profiles DROP COLUMN emergency_phone');
      raw.execute('ALTER TABLE profiles DROP COLUMN emergency_contact_name');
      raw.userVersion = 8;
      raw.close();

      final v8 = _V8Database(
        openEncryptedDatabase(dbFile(from.root), from.key),
      );
      final backup = (await from.service.create(
        v8,
        recovery,
        appVersion: '0.9',
      )).file;
      await v8.close();

      final staged = await to.service.stage(
        backup,
        recovery,
        currentSchema: AppDatabase.currentSchema,
      );
      expect(staged.manifest.schemaVersion, 8);
      await to.service.commit();
      final restored = AppDatabase(
        openEncryptedDatabase(dbFile(to.root), to.key),
      );
      addTearDown(restored.close);
      final p = (await restored.watchProfile(id).first)!;
      expect(p.displayName, 'سارة');
      expect(p.bloodType, 'A+');
      expect(p.relationship, isNull);
      expect(p.emergencyPhone, isNull);
    });

    test(
      'a backup from a newer app than this is refused, not half read',
      () async {
        final from = phone('newer');
        final to = phone('older');
        final db = AppDatabase(
          openEncryptedDatabase(dbFile(from.root), from.key),
        );
        await db.addProfile('سارة');
        final backup = (await from.service.create(
          db,
          recovery,
          appVersion: '2',
        )).file;
        await db.close();
        await expectLater(
          to.service.stage(backup, recovery, currentSchema: 8),
          throwsA(
            isA<BackupException>().having(
              (e) => e.failure,
              'failure',
              BackupFailure.tooNew,
            ),
          ),
        );
      },
    );
  });
}
