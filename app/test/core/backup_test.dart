import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:usra/core/backup/backup_crypto.dart';
import 'package:usra/core/backup/backup_service.dart';
import 'package:usra/core/backup/recovery_key.dart';
import 'package:usra/core/database/app_database.dart';
import 'package:usra/core/database/connection.dart';

/// Cheap Argon2id so the tests run fast; real backups use the standard cost.
const _testKdf = BackupKdf(memory: 64, iterations: 1, parallelism: 1);

/// One phone: its private folder, database key and backup service.
class _Phone {
  _Phone(this.dir)
    : key = DatabaseKeyStore.generateKey(),
      root = Directory(p.join(dir.path, 'support'))..createSync(),
      temp = Directory(p.join(dir.path, 'tmp'))..createSync();

  final Directory dir;
  final String key;
  final Directory root;
  final Directory temp;

  File get dbFile => File(p.join(root.path, 'usra.sqlite'));

  BackupService get service => BackupService(
    root: root,
    databaseName: 'usra.sqlite',
    deviceKey: key,
    temporary: temp,
    folders: const ['insurance_cards', 'attachments', 'medicines'],
    files: const ['follow_up_dismissals.json'],
    kdf: _testKdf,
    chunkSize: 4096,
  );

  AppDatabase open() => AppDatabase(openEncryptedDatabase(dbFile, key));

  void writePhoto(String relative, List<int> bytes) => (File(
    p.join(root.path, relative),
  )..createSync(recursive: true)).writeAsBytesSync(bytes);
}

/// A database still at schema 5 (before medicines), as an older app left it.
class _V5Database extends AppDatabase {
  _V5Database(super.executor);

  @override
  int get schemaVersion => 5;
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late Directory dir;
  late _Phone oldPhone;
  late _Phone newPhone;
  final recovery = RecoveryKey.generate();
  final photo = List<int>.generate(10000, (i) => (i * 7) % 256);

  setUp(() {
    dir = Directory.systemTemp.createTempSync('usra_backup_test');
    oldPhone = _Phone(Directory(p.join(dir.path, 'old'))..createSync());
    newPhone = _Phone(Directory(p.join(dir.path, 'new'))..createSync());
  });
  tearDown(() => dir.deleteSync(recursive: true));

  Future<File> backupOldPhone() async {
    final db = oldPhone.open();
    try {
      final id = await db.addProfile('فاطمة', bloodType: 'O+');
      await db.addProfile('أحمد');
      await db.softDeleteProfile(id);
      await db.addProfile('ليلى');
      oldPhone.writePhoto('attachments/a1.jpg', photo);
      oldPhone.writePhoto('insurance_cards/c1.png', [1, 2, 3]);
      oldPhone.writePhoto('medicines/box.front.jpg', [4]);
      oldPhone.writePhoto('attachments/.DS_Store', [0]);
      File(p.join(oldPhone.root.path, 'follow_up_dismissals.json'))
          .writeAsStringSync('["x"]');
      return await oldPhone.service.create(
        db,
        recovery,
        appVersion: '0.1.0+1',
        now: DateTime.utc(2026, 11, 3),
      );
    } finally {
      await db.close();
    }
  }

  test('a backup restores on a new phone, photos and all', () async {
    final backup = await backupOldPhone();
    expect(p.basename(backup.path), 'usra-backup-2026-11-03.usra');
    // Nothing readable inside: not the names, not the photo bytes.
    final raw = String.fromCharCodes(backup.readAsBytesSync());
    expect(raw, isNot(contains('manifest')));
    expect(raw, isNot(contains('attachments/')));
    expect(oldPhone.temp.listSync(), [isA<File>()]);

    // The new phone already has some data of its own; it gets replaced.
    final fresh = newPhone.open();
    await fresh.addProfile('Someone else');
    await fresh.close();
    newPhone.writePhoto('attachments/old.jpg', [9]);

    final staged = await newPhone.service.stage(
      backup,
      recovery,
      currentSchema: 6,
    );
    expect(staged.manifest.schemaVersion, 6);
    expect(staged.manifest.appVersion, '0.1.0+1');
    expect(staged.manifest.createdAt, DateTime.utc(2026, 11, 3));
    expect(staged.manifest.count('people'), 2);
    expect(staged.manifest.count('photos'), 3);

    await newPhone.service.commit();
    await newPhone.service.discardAside();
    expect(
      File(p.join(newPhone.root.path, 'medicines/box.front.jpg')).existsSync(),
      isTrue,
    );

    final db = newPhone.open();
    addTearDown(db.close);
    final names = (await db.watchProfiles().first).map((p) => p.displayName);
    expect(names, ['أحمد', 'ليلى']);
    expect(
      File(p.join(newPhone.root.path, 'attachments/a1.jpg')).readAsBytesSync(),
      photo,
    );
    expect(
      File(p.join(newPhone.root.path, 'attachments/old.jpg')).existsSync(),
      isFalse,
    );
    expect(
      File(p.join(newPhone.root.path, 'follow_up_dismissals.json'))
          .readAsStringSync(),
      '["x"]',
    );
    // Only the database, the restored photos and files are left.
    expect(newPhone.root.listSync().map((e) => p.basename(e.path)).toSet(), {
      'usra.sqlite',
      'attachments',
      'insurance_cards',
      'medicines',
      'follow_up_dismissals.json',
    });
  });

  test('the restored database opens only with the new phone\'s key', () async {
    final backup = await backupOldPhone();
    await newPhone.service.stage(backup, recovery, currentSchema: 6);
    await newPhone.service.commit();
    final db = sqlite3.open(newPhone.dbFile.path);
    addTearDown(db.close);
    expect(
      () => unlockDatabase(db, oldPhone.key),
      throwsA(isA<SqliteException>()),
    );
  });

  test(
    'a wrong recovery key fails cleanly, leaving the phone as it was',
    () async {
      final backup = await backupOldPhone();
      final fresh = newPhone.open();
      await fresh.addProfile('Mine');
      await fresh.close();

      await expectLater(
        newPhone.service.stage(
          backup,
          RecoveryKey.generate(),
          currentSchema: 6,
        ),
        throwsA(
          isA<BackupException>().having(
            (e) => e.failure,
            'failure',
            BackupFailure.wrongKey,
          ),
        ),
      );
      expect(newPhone.root.listSync().map((e) => p.basename(e.path)), [
        'usra.sqlite',
      ]);
      final db = newPhone.open();
      addTearDown(db.close);
      expect((await db.watchProfiles().first).single.displayName, 'Mine');
    },
  );

  test('a truncated or altered file fails cleanly as damaged', () async {
    final backup = await backupOldPhone();
    final bytes = backup.readAsBytesSync();
    final damaged = isA<BackupException>().having(
      (e) => e.failure,
      'failure',
      BackupFailure.damaged,
    );
    final copy = File(p.join(dir.path, 'copy.usra'));

    // Cut anywhere in the payload, including exactly at a chunk boundary.
    for (final cut in [
      bytes.length - 1,
      bytes.length - 4096 - 16,
      bytes.length ~/ 2,
      500,
    ]) {
      copy.writeAsBytesSync(bytes.sublist(0, cut));
      await expectLater(
        newPhone.service.stage(copy, recovery, currentSchema: 6),
        throwsA(damaged),
        reason: 'cut at $cut of ${bytes.length}',
      );
    }

    // One flipped bit in the middle.
    final flipped = [...bytes];
    flipped[bytes.length ~/ 2] ^= 1;
    copy.writeAsBytesSync(flipped);
    await expectLater(
      newPhone.service.stage(copy, recovery, currentSchema: 6),
      throwsA(damaged),
    );

    // Something appended.
    copy.writeAsBytesSync([...bytes, 0]);
    await expectLater(
      newPhone.service.stage(copy, recovery, currentSchema: 6),
      throwsA(damaged),
    );
    expect(
      Directory(p.join(newPhone.root.path, 'restore-staging')).existsSync(),
      isFalse,
    );
  });

  test('a backup opened but not restored leaves nothing behind', () async {
    final backup = await backupOldPhone();
    await newPhone.service.stage(backup, recovery, currentSchema: 6);
    await newPhone.service.discardStaged();
    expect(newPhone.root.listSync(), isEmpty);
  });

  test('a file that is not a backup is refused', () async {
    final other = File(p.join(dir.path, 'photo.jpg'))..writeAsBytesSync(photo);
    await expectLater(
      newPhone.service.stage(other, recovery, currentSchema: 6),
      throwsA(
        isA<BackupException>().having(
          (e) => e.failure,
          'failure',
          BackupFailure.notABackup,
        ),
      ),
    );
  });

  test('a backup from a newer app is refused', () async {
    final backup = await backupOldPhone();
    await expectLater(
      newPhone.service.stage(backup, recovery, currentSchema: 5),
      throwsA(
        isA<BackupException>().having(
          (e) => e.failure,
          'failure',
          BackupFailure.tooNew,
        ),
      ),
    );
  });

  test('a backup from an older schema restores through migrations', () async {
    // Build a schema-5 database: everything, minus what 6 added.
    final current = oldPhone.open();
    await current.addProfile('سارة');
    await current.close();
    final raw = sqlite3.open(oldPhone.dbFile.path);
    unlockDatabase(raw, oldPhone.key);
    raw.execute('DROP TABLE dose_logs');
    raw.execute('DROP TABLE dose_schedules');
    raw.execute('DROP TABLE medicines');
    raw.userVersion = 5;
    raw.close();

    final v5 = _V5Database(
      openEncryptedDatabase(oldPhone.dbFile, oldPhone.key),
    );
    final backup = await oldPhone.service.create(
      v5,
      recovery,
      appVersion: '0.0.9',
    );
    await v5.close();

    final staged = await newPhone.service.stage(
      backup,
      recovery,
      currentSchema: 6,
    );
    expect(staged.manifest.schemaVersion, 5);
    await newPhone.service.commit();

    final db = newPhone.open();
    addTearDown(db.close);
    final people = await db.watchProfiles().first;
    expect(people.single.displayName, 'سارة');
    // Migrated: the medicines tables exist again.
    expect(await db.select(db.medicines).get(), isEmpty);
  });

  test('a restore killed half-way is undone at the next start', () async {
    final backup = await backupOldPhone();
    final fresh = newPhone.open();
    await fresh.addProfile('Mine');
    await fresh.close();
    newPhone.writePhoto('medicines/m.jpg', [5]);

    await newPhone.service.stage(backup, recovery, currentSchema: 6);
    await newPhone.service.commit();
    // Pretend the app died right after the swap, before it was confirmed:
    // put the marker back as it was mid-swap.
    File(p.join(newPhone.root.path, 'restore-in-progress.json'))
        .writeAsStringSync('{}');
    await newPhone.service.recoverInterrupted();

    final db = newPhone.open();
    addTearDown(db.close);
    expect((await db.watchProfiles().first).single.displayName, 'Mine');
    expect(
      File(p.join(newPhone.root.path, 'medicines/m.jpg')).existsSync(),
      isTrue,
    );
    expect(
      Directory(p.join(newPhone.root.path, 'attachments')).existsSync(),
      isFalse,
    );
  });

  test('the file format refuses a hostile Argon2 cost', () {
    expect(
      const BackupKdf(
        memory: 1 << 30,
        iterations: 1,
        parallelism: 1,
      ).isReasonable,
      isFalse,
    );
    expect(BackupKdf.standard.isReasonable, isTrue);
  });

  group('recovery key', () {
    test('is 6 groups of 6 digits that check', () {
      for (var seed = 0; seed < 50; seed++) {
        final key = RecoveryKey.generate(Random(seed));
        expect(key.groups, hasLength(6));
        expect(key.groups.every((g) => RegExp(r'^\d{6}$').hasMatch(g)), isTrue);
        expect(RecoveryKey.tryParse(key.groups.join(' ')), key);
        expect(RecoveryKey.wrongGroups(key.digits), isEmpty);
      }
    });

    test('reads Arabic digits, spaces and dashes', () {
      final key = RecoveryKey.generate(Random(1));
      const arabic = '٠١٢٣٤٥٦٧٨٩';
      final typed = key.groups
          .map((g) => g.split('').map((d) => arabic[int.parse(d)]).join())
          .join(' - ');
      expect(RecoveryKey.tryParse(typed), key);
    });

    test('catches a wrong digit, swapped digits and swapped groups', () {
      final key = RecoveryKey.generate(Random(2));
      final digits = key.digits.split('');
      for (var i = 0; i < digits.length; i++) {
        final wrong = [...digits];
        wrong[i] = '${(int.parse(wrong[i]) + 3) % 10}';
        expect(RecoveryKey.tryParse(wrong.join()), isNull);
        expect(RecoveryKey.wrongGroups(wrong.join()), [i ~/ 6]);
      }
      for (var i = 0; i < digits.length - 1; i++) {
        if (i % 6 == 5 || digits[i] == digits[i + 1]) continue;
        final swapped = [...digits];
        swapped[i] = digits[i + 1];
        swapped[i + 1] = digits[i];
        expect(RecoveryKey.tryParse(swapped.join()), isNull);
      }
      final groups = key.groups;
      expect(
        RecoveryKey.wrongGroups(
          [groups[1], groups[0], ...groups.skip(2)].join(),
        ),
        isNotEmpty,
      );
    });

    test('a missing group is reported', () {
      final key = RecoveryKey.generate(Random(3));
      expect(RecoveryKey.wrongGroups(key.groups.take(5).join()), [5]);
    });

    test('is never printed', () {
      expect('${RecoveryKey.generate()}', isNot(contains(RegExp(r'\d'))));
    });
  });
}
