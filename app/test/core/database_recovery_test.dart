import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:usra/core/backup/backup_crypto.dart';
import 'package:usra/core/backup/backup_service.dart';
import 'package:usra/core/backup/recovery_key.dart';
import 'package:usra/core/database/app_database.dart';
import 'package:usra/core/database/connection.dart';
import 'package:usra/core/files/photo_crypto.dart';
import 'package:usra/features/settings/database_recovery.dart';

const _testKdf = BackupKdf(memory: 64, iterations: 1, parallelism: 1);

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late Directory dir;
  late Directory root;
  late File dbFile;
  late File photo;
  final recovery = RecoveryKey.generate();
  final oldKey = DatabaseKeyStore.generateKey();
  final newKey = DatabaseKeyStore.generateKey();

  BackupService serviceFor(
    String deviceKey, {
    PhotoKeys? photoKeys,
    PhotoKeyStore? store,
    bool replaceUnreadablePhotoKey = false,
  }) => BackupService(
    root: root,
    databaseName: 'usra.sqlite',
    deviceKey: deviceKey,
    photoKeys:
        photoKeys ?? PhotoKeys.ready(PhotoCipher(PhotoCipher.generateKey())),
    photoKeyStore: store ?? MemoryPhotoKeyStore(),
    temporary: dir,
    folders: const ['medicines'],
    kdf: _testKdf,
    chunkSize: 4096,
    replaceUnreadablePhotoKey: replaceUnreadablePhotoKey,
  );

  /// A backup holding one person, made on another phone.
  Future<File> makeBackup() async {
    final other = Directory(p.join(dir.path, 'other'))..createSync();
    final otherKey = DatabaseKeyStore.generateKey();
    final db = AppDatabase(
      openEncryptedDatabase(File(p.join(other.path, 'usra.sqlite')), otherKey),
    );
    await db.addProfile('فاطمة');
    final created = await BackupService(
      root: other,
      databaseName: 'usra.sqlite',
      deviceKey: otherKey,
      photoKeys: PhotoKeys.ready(PhotoCipher(PhotoCipher.generateKey())),
      temporary: dir,
      folders: const ['medicines'],
      kdf: _testKdf,
      chunkSize: 4096,
    ).create(db, recovery, appVersion: '1');
    await db.close();
    return created.file;
  }

  Future<List<String>> people(String key) async {
    final db = AppDatabase(openEncryptedDatabase(dbFile, key));
    try {
      return [for (final x in await db.watchProfiles().first) x.displayName];
    } finally {
      await db.close();
    }
  }

  setUp(() {
    dir = Directory.systemTemp.createTempSync('usra_recovery');
    root = Directory(p.join(dir.path, 'root'))..createSync();
    dbFile = File(p.join(root.path, 'usra.sqlite'));
    photo = File(p.join(root.path, 'medicines', 'old.jpg'));
    // Damaged: not a database at all.
    dbFile.writeAsStringSync('not a database');
    photo
      ..createSync(recursive: true)
      ..writeAsStringSync('old photo');
  });
  tearDown(() => dir.deleteSync(recursive: true));

  void expectOldDataBack() {
    expect(dbFile.readAsStringSync(), 'not a database');
    expect(photo.readAsStringSync(), 'old photo');
  }

  test('with a readable key, the backup replaces a damaged database', () async {
    final backup = await makeBackup();
    final service = serviceFor(oldKey);
    await service.stage(
      backup,
      recovery,
      currentSchema: AppDatabase.currentSchema,
    );
    var remembered = false;
    await replaceDamagedData(
      backup: service,
      file: dbFile,
      deviceKey: oldKey,
      remember: () async => remembered = true,
    );
    expect(remembered, isTrue);
    expect(await people(oldKey), ['فاطمة']);
    expect(photo.existsSync(), isFalse);
    // Nothing is left to roll back to on the next start.
    await service.recoverInterrupted();
    expect(await people(oldKey), ['فاطمة']);
    expect(Directory(p.join(root.path, 'restore-aside')).existsSync(), isFalse);
  });

  test('with no readable key, it opens with the new one, saved only after it '
      'has been shown to open', () async {
    final backup = await makeBackup();
    final service = serviceFor(newKey);
    await service.stage(
      backup,
      recovery,
      currentSchema: AppDatabase.currentSchema,
    );
    String? saved;
    var openedBeforeSave = false;
    await replaceDamagedData(
      backup: service,
      file: dbFile,
      deviceKey: newKey,
      checkOpens: (file, key) {
        prepareDatabaseFile(file, key);
        openedBeforeSave = saved == null;
      },
      saveDeviceKey: () async => saved = newKey,
    );
    expect(openedBeforeSave, isTrue);
    expect(saved, newKey);
    expect(await people(newKey), ['فاطمة']);
  });

  test('if the new key can\'t be saved, the old data comes back', () async {
    final backup = await makeBackup();
    final service = serviceFor(newKey);
    await service.stage(
      backup,
      recovery,
      currentSchema: AppDatabase.currentSchema,
    );
    await expectLater(
      replaceDamagedData(
        backup: service,
        file: dbFile,
        deviceKey: newKey,
        saveDeviceKey: () async => throw StateError('keystore'),
      ),
      throwsStateError,
    );
    expectOldDataBack();
  });

  test('if the new database won\'t open, the old data comes back and the key '
      'is never saved', () async {
    final backup = await makeBackup();
    final service = serviceFor(newKey);
    await service.stage(
      backup,
      recovery,
      currentSchema: AppDatabase.currentSchema,
    );
    var saved = false;
    await expectLater(
      replaceDamagedData(
        backup: service,
        file: dbFile,
        deviceKey: newKey,
        checkOpens: (_, _) => throw const DatabaseOpenException(),
        saveDeviceKey: () async => saved = true,
      ),
      throwsA(isA<DatabaseOpenException>()),
    );
    expect(saved, isFalse);
    expectOldDataBack();
  });

  test('killed after the backup went in but before the key was saved: the '
      'next start puts the old data back', () async {
    final backup = await makeBackup();
    final service = serviceFor(newKey);
    await service.stage(
      backup,
      recovery,
      currentSchema: AppDatabase.currentSchema,
    );
    // What replaceDamagedData does first; then the app is killed.
    await service.commit(hold: true);
    expect(dbFile.lengthSync(), isNot('not a database'.length));

    await serviceFor(oldKey).recoverInterrupted();
    expectOldDataBack();
  });

  test(
    'killed after the new key was saved: the next start keeps the restore',
    () async {
      final backup = await makeBackup();
      final service = serviceFor(newKey);
      await service.stage(
        backup,
        recovery,
        currentSchema: AppDatabase.currentSchema,
      );
      await service.commit(hold: true);
      // The key is saved and the app is killed. The next start reads that key.
      await serviceFor(newKey).recoverInterrupted();
      expect(await people(newKey), ['فاطمة']);
      expect(photo.existsSync(), isFalse);
      expect(
        Directory(p.join(root.path, 'restore-aside')).existsSync(),
        isFalse,
      );
    },
  );

  test('a failed tidy-up after the key is saved isn\'t a failed restore, and '
      'never undoes it', () async {
    final backup = await makeBackup();
    final service = serviceFor(oldKey);
    await service.stage(
      backup,
      recovery,
      currentSchema: AppDatabase.currentSchema,
    );
    final reported = <Object>[];
    final before = FlutterError.onError;
    FlutterError.onError = (d) => reported.add(d.exception);
    addTearDown(() => FlutterError.onError = before);
    await replaceDamagedData(
      backup: service,
      file: dbFile,
      deviceKey: oldKey,
      remember: () async => throw StateError('prefs'),
    );
    expect(reported.single, isStateError);
    expect(await people(oldKey), ['فاطمة']);
  });

  test('a restore stopped and not undone is never overwritten', () async {
    final backup = await makeBackup();
    final service = serviceFor(newKey);
    await service.stage(
      backup,
      recovery,
      currentSchema: AppDatabase.currentSchema,
    );
    await service.commit(hold: true);
    final again = serviceFor(newKey);
    await again.stage(
      backup,
      recovery,
      currentSchema: AppDatabase.currentSchema,
    );
    await expectLater(again.commit(hold: true), throwsStateError);
    // The old data is still aside, and comes back.
    await again.undoCommit();
    expectOldDataBack();
  });

  test(
    'a photo key made for the restore isn\'t saved until it has opened',
    () async {
      final backup = await makeBackup();
      final store = MemoryPhotoKeyStore();
      final service = serviceFor(
        newKey,
        photoKeys: PhotoKeys.unavailable(PhotoKeyProblem.unreadable),
        store: store,
        replaceUnreadablePhotoKey: true,
      );
      await service.stage(
        backup,
        recovery,
        currentSchema: AppDatabase.currentSchema,
      );
      await expectLater(
        replaceDamagedData(
          backup: service,
          file: dbFile,
          deviceKey: newKey,
          checkOpens: (_, _) => throw const DatabaseOpenException(),
        ),
        throwsA(isA<DatabaseOpenException>()),
      );
      expect(await store.readRaw(), isNull);
      expectOldDataBack();
    },
  );

  group('a photo key that can\'t be read', () {
    PhotoKeys unreadable() => PhotoKeys.unavailable(PhotoKeyProblem.unreadable);

    test('still stops a normal restore', () async {
      final backup = await makeBackup();
      await expectLater(
        serviceFor(
          oldKey,
          photoKeys: unreadable(),
        ).stage(backup, recovery, currentSchema: AppDatabase.currentSchema),
        throwsA(isA<PhotoKeyUnavailableException>()),
      );
    });

    test('doesn\'t stop one chosen on the recovery screen, and a new key is '
        'saved when it goes in', () async {
      final backup = await makeBackup();
      final store = MemoryPhotoKeyStore();
      final service = serviceFor(
        oldKey,
        photoKeys: unreadable(),
        store: store,
        replaceUnreadablePhotoKey: true,
      );
      await service.stage(
        backup,
        recovery,
        currentSchema: AppDatabase.currentSchema,
      );
      expect(await store.readRaw(), isNull);
      await replaceDamagedData(
        backup: service,
        file: dbFile,
        deviceKey: oldKey,
      );
      expect(await store.readRaw(), isNotNull);
    });
  });
}
