import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:usra/core/backup/backup_archive.dart';
import 'package:usra/core/backup/backup_crypto.dart';
import 'package:usra/core/backup/backup_service.dart';
import 'package:usra/core/backup/recovery_key.dart';
import 'package:usra/core/database/app_database.dart';
import 'package:usra/core/database/connection.dart';
import 'package:usra/core/files/photo_crypto.dart';
import 'package:usra/features/labs/lab_report.dart';

/// Cheap Argon2id so the tests run fast; real backups use the standard cost.
const _testKdf = BackupKdf(memory: 64, iterations: 1, parallelism: 1);

/// One phone: its private folder, database key and backup service.
class _Phone {
  _Phone(this.dir, {PhotoKeys? photoKeys})
    : key = DatabaseKeyStore.generateKey(),
      photoKeys =
          photoKeys ?? PhotoKeys.ready(PhotoCipher(PhotoCipher.generateKey())),
      root = Directory(p.join(dir.path, 'support'))..createSync(),
      temp = Directory(p.join(dir.path, 'tmp'))..createSync();

  final Directory dir;
  final String key;
  final PhotoKeys photoKeys;
  final keyStore = MemoryPhotoKeyStore();
  final Directory root;

  PhotoCipher get photos => photoKeys.require;
  final Directory temp;

  File get dbFile => File(p.join(root.path, 'usra.sqlite'));

  // One for the phone, as in the app: a restore's stage and commit share it.
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

  AppDatabase open() => AppDatabase(openEncryptedDatabase(dbFile, key));

  File photoFile(String relative) => File(p.join(root.path, relative));

  /// Saves a photo encrypted, as the app does; [plain] for one from before
  /// photos were encrypted.
  void writePhoto(String relative, List<int> bytes, {bool plain = false}) =>
      (photoFile(relative)..createSync(recursive: true)).writeAsBytesSync(
        plain ? bytes : photos.seal(bytes),
      );

  List<int> readPhoto(String relative) =>
      photos.open(photoFile(relative).readAsBytesSync());
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
      final layla = await db.addProfile('ليلى');
      // A prescription with one medicine, its photo in the medicines folder.
      await db.savePrescription(
        profileId: layla,
        prescribedOn: DateTime(2026, 11, 1),
        diagnosis: 'برد',
        photos: const ['medicines/box.front.jpg'],
        items: const [
          PrescriptionItemInput(
            name: 'باراسيتامول',
            dose: '5 مل',
            times: ['08:00'],
            days: 3,
          ),
        ],
      );
      oldPhone.writePhoto('attachments/a1.jpg', photo);
      oldPhone.writePhoto('insurance_cards/c1.png', [1, 2, 3]);
      // Not reached by the start-up migration yet.
      oldPhone.writePhoto('medicines/box.front.jpg', [4], plain: true);
      oldPhone.writePhoto('attachments/.DS_Store', [0]);
      File(p.join(oldPhone.root.path, 'follow_up_dismissals.json'))
          .writeAsStringSync('["x"]');
      return (await oldPhone.service.create(
        db,
        recovery,
        appVersion: '0.1.0+1',
        now: DateTime.utc(2026, 11, 3),
      )).file;
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
    expect(_contains(backup.readAsBytesSync(), photo.sublist(0, 64)), isFalse);
    expect(oldPhone.temp.listSync(), [isA<File>()]);

    // The new phone already has some data of its own; it gets replaced.
    final fresh = newPhone.open();
    await fresh.addProfile('Someone else');
    await fresh.close();
    newPhone.writePhoto('attachments/old.jpg', [9]);

    final staged = await newPhone.service.stage(
      backup,
      recovery,
      currentSchema: 7,
    );
    expect(staged.manifest.schemaVersion, 7);
    expect(staged.manifest.appVersion, '0.1.0+1');
    expect(staged.manifest.createdAt, DateTime.utc(2026, 11, 3));
    expect(staged.manifest.count('people'), 2);
    expect(staged.manifest.count('photos'), 3);
    expect(staged.manifest.count('prescriptions'), 1);
    expect(staged.manifest.count('medicines'), 1);

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
    final layla = (await db.watchProfiles().first).last.id;
    final rx = (await db.watchPrescriptions(layla).first).single;
    expect(rx.diagnosis, 'برد');
    expect(decodeMedicinePhotos(rx.photosJson), ['medicines/box.front.jpg']);
    final course = (await db.watchPrescriptionMedicines(rx.id).first).single;
    expect(course.instructions, '5 مل');
    expect(course.endOn!.toUtc(), DateTime.utc(2026, 11, 3));
    // Encrypted again for the new phone, and only it can open them.
    expect(newPhone.readPhoto('attachments/a1.jpg'), photo);
    expect(newPhone.readPhoto('insurance_cards/c1.png'), [1, 2, 3]);
    expect(newPhone.readPhoto('medicines/box.front.jpg'), [4]);
    final restored = newPhone.photoFile('attachments/a1.jpg').readAsBytesSync();
    expect(_contains(restored, photo.sublist(0, 64)), isFalse);
    expect(
      () => oldPhone.photos.open(restored),
      throwsA(isA<PhotoUnreadableException>()),
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

  test('lab reports restore with their results and PDFs', () async {
    final db = oldPhone.open();
    final mom = await db.addProfile('فاطمة');
    const report = LabReport(
      lab: 'Alfa',
      tests: [
        LabTest(
          name: 'HbA1c',
          value: 7.4,
          unit: '%',
          range: LabRange(low: 4, high: 5.6),
        ),
        LabTest(name: 'TSH', value: 2.1, unit: 'uIU/mL'),
      ],
    );
    final pdf = List<int>.generate(3000, (i) => (i * 13) % 256);
    oldPhone.writePhoto('attachments/report.pdf', pdf);
    await db.addEvent(
      profileId: mom,
      type: 'lab',
      occurredAt: DateTime(2026, 10, 5),
      dataJson: jsonEncode(report.toData()),
      pdfs: ['attachments/report.pdf'],
    );
    final backup = (await oldPhone.service.create(
      db,
      recovery,
      appVersion: '0.1.0+1',
      now: DateTime.utc(2026, 11, 3),
    )).file;
    await db.close();

    await newPhone.service.stage(backup, recovery, currentSchema: 7);
    await newPhone.service.commit();
    final restored = newPhone.open();
    addTearDown(restored.close);
    final event = (await restored.eventsOfTypes({'lab'})).single;
    expect(LabReport.of(event).tests, report.tests);
    expect(LabReport.of(event).lab, 'Alfa');
    final file = (await restored.watchAttachments(event.id).first).single;
    expect(file.kind, 'pdf');
    expect(newPhone.readPhoto(file.path), pdf);
  });

  test('the restored database opens only with the new phone\'s key', () async {
    final backup = await backupOldPhone();
    await newPhone.service.stage(backup, recovery, currentSchema: 7);
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
          currentSchema: 7,
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
        newPhone.service.stage(copy, recovery, currentSchema: 7),
        throwsA(damaged),
        reason: 'cut at $cut of ${bytes.length}',
      );
    }

    // One flipped bit in the middle.
    final flipped = [...bytes];
    flipped[bytes.length ~/ 2] ^= 1;
    copy.writeAsBytesSync(flipped);
    await expectLater(
      newPhone.service.stage(copy, recovery, currentSchema: 7),
      throwsA(damaged),
    );

    // Something appended.
    copy.writeAsBytesSync([...bytes, 0]);
    await expectLater(
      newPhone.service.stage(copy, recovery, currentSchema: 7),
      throwsA(damaged),
    );
    expect(
      Directory(p.join(newPhone.root.path, 'restore-staging')).existsSync(),
      isFalse,
    );
  });

  test('a backup opened but not restored leaves nothing behind', () async {
    final backup = await backupOldPhone();
    await newPhone.service.stage(backup, recovery, currentSchema: 7);
    await newPhone.service.discardStaged();
    expect(newPhone.root.listSync(), isEmpty);
  });

  test('a file that is not a backup is refused', () async {
    final other = File(p.join(dir.path, 'photo.jpg'))..writeAsBytesSync(photo);
    await expectLater(
      newPhone.service.stage(other, recovery, currentSchema: 7),
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
    raw.execute('DROP TABLE prescriptions');
    raw.userVersion = 5;
    raw.close();

    final v5 = _V5Database(
      openEncryptedDatabase(oldPhone.dbFile, oldPhone.key),
    );
    final backup = (await oldPhone.service.create(
      v5,
      recovery,
      appVersion: '0.0.9',
    )).file;
    await v5.close();

    final staged = await newPhone.service.stage(
      backup,
      recovery,
      currentSchema: 7,
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

    await newPhone.service.stage(backup, recovery, currentSchema: 7);
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

  test('a photo that no longer opens is left out, not the backup', () async {
    oldPhone.writePhoto('attachments/good.jpg', photo);
    oldPhone.writePhoto('attachments/bad.jpg', photo);
    final bad = oldPhone.photoFile('attachments/bad.jpg');
    final bytes = bad.readAsBytesSync();
    bytes[bytes.length ~/ 2] ^= 1;
    bad.writeAsBytesSync(bytes);
    final db = oldPhone.open();
    final CreatedBackup created;
    try {
      created = await oldPhone.service.create(db, recovery, appVersion: '1');
    } finally {
      await db.close();
    }
    // Said, not hidden: the backup isn't complete.
    expect(created.skippedPhotos, 1);
    final backup = created.file;

    final staged = await newPhone.service.stage(
      backup,
      recovery,
      currentSchema: 7,
    );
    expect(staged.manifest.count('photos'), 1);
    await newPhone.service.commit();
    expect(newPhone.readPhoto('attachments/good.jpg'), photo);
    expect(newPhone.photoFile('attachments/bad.jpg').existsSync(), isFalse);
  });

  test('restored photos never touch the disk unencrypted', () async {
    final backup = await backupOldPhone();
    await newPhone.service.stage(backup, recovery, currentSchema: 7);
    final staging = Directory(p.join(newPhone.root.path, 'restore-staging'));
    for (final f in staging.listSync(recursive: true).whereType<File>()) {
      if (p.basename(f.path).startsWith('usra.sqlite')) continue;
      if (p.basename(f.path) == 'follow_up_dismissals.json') continue;
      expect(PhotoCipher.isSealed(f.readAsBytesSync()), isTrue, reason: f.path);
    }
    await newPhone.service.discardStaged();
  });

  /// [backup] again, with [extra] entries added to its tar: what Usra never
  /// writes itself (photos already encrypted).
  Future<File> withEntries(File backup, Map<String, List<int>> extra) async {
    final unpacked = Directory(p.join(dir.path, 'unpacked'))..createSync();
    final reader = await BackupFileReader.open(backup, recovery);
    final List<String> names;
    try {
      names = await extractTar(reader, unpacked, accept: (_) => true);
    } finally {
      await reader.close();
    }
    final out = File(p.join(dir.path, 'crafted.usra'));
    final writer = await BackupFileWriter.create(
      out,
      recovery,
      kdf: _testKdf,
      chunkSize: 4096,
    );
    try {
      final tar = TarWriter(writer.add);
      for (final name in names) {
        await tar.addFile(
          name,
          File(p.joinAll([unpacked.path, ...name.split('/')])),
        );
      }
      for (final MapEntry(key: name, value: bytes) in extra.entries) {
        await tar.addBytes(name, bytes);
      }
      await tar.finish();
    } finally {
      await writer.close();
    }
    return out;
  }

  test(
    'a photo already encrypted in a backup is never encrypted again',
    () async {
      final backup = await withEntries(await backupOldPhone(), {
        // Encrypted for the new phone: kept as it is.
        'attachments/mine.jpg': newPhone.photos.seal([8, 8]),
        // Encrypted for some other phone: nothing here opens it.
        'attachments/other.jpg': PhotoCipher(PhotoCipher.generateKey())
            .seal([9]),
      });
      final staged = await newPhone.service.stage(
        backup,
        recovery,
        currentSchema: 7,
      );
      expect(staged.skippedPhotos, 1);
      await newPhone.service.commit();
      expect(newPhone.readPhoto('attachments/mine.jpg'), [8, 8]);
      expect(newPhone.photoFile('attachments/other.jpg').existsSync(), isFalse);
      expect(newPhone.readPhoto('attachments/a1.jpg'), photo);
    },
  );

  test(
    'a backup on a phone without its photo key says what it left out',
    () async {
      final lost = _Phone(
        Directory(p.join(dir.path, 'lost'))..createSync(),
        photoKeys: PhotoKeys.unavailable(PhotoKeyProblem.lost),
      );
      final before = PhotoCipher(PhotoCipher.generateKey());
      for (final name in ['a.jpg', 'b.jpg']) {
        (lost.photoFile(
          'attachments/$name',
        )..createSync(recursive: true)).writeAsBytesSync(before.seal([1]));
      }
      lost.writePhoto('attachments/plain.jpg', [2], plain: true);
      final db = lost.open();
      final CreatedBackup created;
      try {
        created = await lost.service.create(db, recovery, appVersion: '1');
      } finally {
        await db.close();
      }
      expect(created.skippedPhotos, 2);

      final staged = await newPhone.service.stage(
        created.file,
        recovery,
        currentSchema: 7,
      );
      expect(staged.manifest.count('photos'), 1);
    },
  );

  test('restoring onto a phone whose photo key was lost makes a new one, '
      'kept only once the restore goes in', () async {
    final backup = await backupOldPhone();
    final lost = _Phone(
      Directory(p.join(dir.path, 'lost'))..createSync(),
      photoKeys: PhotoKeys.unavailable(PhotoKeyProblem.lost),
    );

    await lost.service.stage(backup, recovery, currentSchema: 7);
    await lost.service.discardStaged();
    // Not restored: no key was saved, the phone still says it has none.
    expect(lost.keyStore.value, isNull);
    expect(lost.photoKeys.problem, PhotoKeyProblem.lost);

    await lost.service.stage(backup, recovery, currentSchema: 7);
    await lost.service.commit();
    expect(lost.keyStore.value, isNotNull);
    expect(lost.photoKeys.cipher, isNotNull);
    expect(lost.readPhoto('attachments/a1.jpg'), photo);
    // The saved key is the one the photos were encrypted with.
    final saved = await lost.keyStore.load(sealedPhotosExist: () async => true);
    expect(
      saved.require.open(
        lost.photoFile('attachments/a1.jpg').readAsBytesSync(),
      ),
      photo,
    );
  });

  test(
    'a phone that can\'t read its key store never restores over it',
    () async {
      final backup = await backupOldPhone();
      final unreadable = _Phone(
        Directory(p.join(dir.path, 'unreadable'))..createSync(),
        photoKeys: PhotoKeys.unavailable(PhotoKeyProblem.unreadable),
      );
      await expectLater(
        unreadable.service.stage(backup, recovery, currentSchema: 7),
        throwsA(isA<PhotoKeyUnavailableException>()),
      );
      expect(unreadable.keyStore.value, isNull);
    },
  );

  group('backup hygiene (S11)', () {
    test('only the encrypted backup is left once it is made: the working '
        'snapshot goes, and the recovery key is written nowhere', () async {
      final backup = await backupOldPhone();
      expect(oldPhone.temp.listSync().map((e) => p.basename(e.path)), [
        p.basename(backup.path),
      ]);
      // Not in the file, its name, or anything else on the phone's disk
      // (only the Keystore / Keychain may hold it).
      final digits = recovery.digits;
      final spaced = recovery.groups.join(' ');
      for (final f
          in oldPhone.dir.listSync(recursive: true).whereType<File>()) {
        expect(p.basename(f.path), isNot(contains(digits)));
        final text = String.fromCharCodes(f.readAsBytesSync());
        expect(text, isNot(contains(digits)), reason: f.path);
        expect(text, isNot(contains(spaced)), reason: f.path);
      }
    });

    test('the working snapshot is never a plain SQLite file', () async {
      // What create() does first: VACUUM INTO keeps the database's cipher.
      final db = oldPhone.open();
      addTearDown(db.close);
      await db.addProfile('فاطمة');
      final snapshot = p.join(oldPhone.temp.path, 'snapshot.sqlite');
      await db.customStatement('VACUUM INTO ?', [snapshot]);
      final head = File(snapshot).readAsBytesSync().sublist(0, 16);
      expect(String.fromCharCodes(head), isNot(startsWith('SQLite format 3')));
      expect(
        _contains(File(snapshot).readAsBytesSync(), utf8.encode('فاطمة')),
        isFalse,
      );
    });

    test('a failed backup leaves nothing behind', () async {
      final db = oldPhone.open();
      await db.addProfile('فاطمة');
      await db.close();
      // A closed database can't be snapshotted: create() fails part way.
      await expectLater(
        oldPhone.service.create(db, recovery, appVersion: '0.1.0+1'),
        throwsA(anything),
      );
      expect(oldPhone.temp.listSync(), isEmpty);
    });

    test('what a backup killed half way left is cleared at the next start, '
        'and only that', () async {
      final work = Directory(p.join(oldPhone.temp.path, 'usra-backup-x1y2'))
        ..createSync();
      File(p.join(work.path, 'snapshot.sqlite')).writeAsBytesSync([1, 2, 3]);
      final shared = File(
        p.join(oldPhone.temp.path, 'usra-backup-2026-11-01.usra'),
      )..writeAsBytesSync([4]);
      final other = File(p.join(oldPhone.temp.path, 'someone-else.txt'))
        ..writeAsStringSync('keep');

      await oldPhone.service.clearLeftovers();

      expect(work.existsSync(), isFalse);
      expect(shared.existsSync(), isFalse);
      expect(other.existsSync(), isTrue);
    });

    test('a shared backup is deleted from the phone', () async {
      final db = oldPhone.open();
      addTearDown(db.close);
      final created = await oldPhone.service.create(
        db,
        recovery,
        appVersion: '0.1.0+1',
      );
      await oldPhone.service.discardCreated(created);
      expect(oldPhone.temp.listSync(), isEmpty);
    });

    test('a restore killed while unpacking leaves no staging at the next '
        'start', () async {
      final backup = await backupOldPhone();
      await newPhone.service.stage(backup, recovery, currentSchema: 7);
      final staging = Directory(p.join(newPhone.root.path, 'restore-staging'));
      expect(staging.existsSync(), isTrue);
      // The app dies here; the next start:
      await newPhone.service.recoverInterrupted();
      expect(staging.existsSync(), isFalse);
    });
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

/// Whether [needle] appears anywhere in [haystack].
bool _contains(List<int> haystack, List<int> needle) {
  outer:
  for (var i = 0; i + needle.length <= haystack.length; i++) {
    for (var j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) continue outer;
    }
    return true;
  }
  return false;
}
