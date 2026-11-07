import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:usra/core/database/connection.dart';

import '../support/spy_secure_storage.dart';

void main() {
  final keyA = DatabaseKeyStore.generateKey();
  final keyB = DatabaseKeyStore.generateKey();
  late Directory dir;
  late File file;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('usra_db_test');
    file = File(p.join(dir.path, 'usra.sqlite'));
  });
  tearDown(() => dir.deleteSync(recursive: true));

  void writeRow(File file, String key) {
    final db = sqlite3.open(file.path);
    try {
      unlockDatabase(db, key);
      db.execute('CREATE TABLE IF NOT EXISTS t (v TEXT)');
      db.execute("INSERT INTO t VALUES ('secret medical note')");
    } finally {
      db.close();
    }
  }

  test('the database folder is kept out of iCloud backup', () async {
    final excluded = <String>[];
    await excludeDatabaseFromBackup(
      file,
      (dir) async => excluded.add(dir.path),
    );
    // The folder, so usra.sqlite-wal and -shm are covered too.
    expect(excluded, [file.parent.path]);
  });

  test('the bundled SQLite supports encryption', () {
    // The cipher build refuses keys on in-memory databases, so use a file.
    final db = sqlite3.open(file.path);
    addTearDown(db.close);
    expect(() => unlockDatabase(db, keyA), returnsNormally);
  });

  test('the database file on disk is encrypted', () {
    writeRow(file, keyA);
    final bytes = file.readAsBytesSync();
    final header = latin1.decode(bytes.sublist(0, 15));
    expect(header, isNot('SQLite format 3'));
    expect(latin1.decode(bytes), isNot(contains('secret medical note')));
  });

  test('the database cannot be read without its key', () {
    writeRow(file, keyA);
    final db = sqlite3.open(file.path);
    addTearDown(db.close);
    expect(
      () => db.select('SELECT count(*) FROM sqlite_master;'),
      throwsA(isA<SqliteException>()),
    );
  });

  test('the right key keeps the existing file', () {
    writeRow(file, keyA);
    expect(() => prepareDatabaseFile(file, keyA), returnsNormally);
    expect(file.existsSync(), isTrue);
  });

  group('an open error never moves the file', () {
    void expectFileKept(File file, List<int> bytes) {
      expect(file.readAsBytesSync(), bytes);
      expect(
        dir.listSync().map((f) => p.basename(f.path)),
        isNot(contains(startsWith('usra.sqlite.unreadable-'))),
      );
    }

    final throwsOpenError = throwsA(isA<DatabaseOpenException>());
    Matcher throwsCode(int code) => throwsA(
      isA<DatabaseOpenException>().having((e) => e.code, 'code', code),
    );

    test('a key that does not open the file (NOTADB, 26)', () {
      writeRow(file, keyA);
      final bytes = file.readAsBytesSync();
      expect(() => prepareDatabaseFile(file, keyB), throwsCode(26));
      expectFileKept(file, bytes);
      // Nothing about the records changed: the right key still opens them.
      expect(() => prepareDatabaseFile(file, keyA), returnsNormally);
    });

    test('a damaged first page with the right key (NOTADB, 26)', () {
      writeRow(file, keyA);
      final bytes = file.readAsBytesSync();
      for (var i = 100; i < 200; i++) {
        bytes[i] ^= 0xff;
      }
      file.writeAsBytesSync(bytes);
      expect(() => prepareDatabaseFile(file, keyA), throwsCode(26));
      expectFileKept(file, bytes);
    });

    test('a file cut short with the right key', () {
      writeRow(file, keyA);
      final bytes = file.readAsBytesSync().sublist(0, 2000);
      file.writeAsBytesSync(bytes);
      expect(() => prepareDatabaseFile(file, keyA), throwsOpenError);
      expectFileKept(file, bytes);
    });

    test('a file that is not a database', () {
      final bytes = List.filled(4096, 7);
      file.writeAsBytesSync(bytes);
      expect(() => prepareDatabaseFile(file, keyA), throwsCode(26));
      expectFileKept(file, bytes);
    });

    test('a real SQLITE_BUSY reports the code', () {
      writeRow(file, keyA);
      final holder = sqlite3.open(file.path);
      addTearDown(holder.close);
      unlockDatabase(holder, keyA);
      holder.execute('BEGIN EXCLUSIVE;');
      final bytes = file.readAsBytesSync();
      expect(() => prepareDatabaseFile(file, keyA), throwsCode(5));
      expectFileKept(file, bytes);
      holder.execute('COMMIT;');
      expect(() => prepareDatabaseFile(file, keyA), returnsNormally);
    });

    test('a file SQLite cannot open', () {
      writeRow(file, keyA);
      final bytes = file.readAsBytesSync();
      Process.runSync('chmod', ['000', file.path]);
      addTearDown(() => Process.runSync('chmod', ['600', file.path]));
      expect(() => prepareDatabaseFile(file, keyA), throwsOpenError);
      Process.runSync('chmod', ['600', file.path]);
      expectFileKept(file, bytes);
    }, skip: Platform.isWindows);

    // Disk errors can't be caused on demand in a test, so these inject them.
    for (final (name, code) in [
      ('FULL', 13),
      ('IOERR', 10),
      ('IOERR_READ', 266),
      ('CORRUPT', 11),
      ('CANTOPEN', 14),
    ]) {
      test(name, () {
        writeRow(file, keyA);
        final bytes = file.readAsBytesSync();
        expect(
          () => prepareDatabaseFile(
            file,
            keyA,
            unlock: (_, _) => throw SqliteException(
              extendedResultCode: code,
              message: 'injected',
            ),
          ),
          throwsCode(code),
        );
        expectFileKept(file, bytes);
      });
    }

    test('the error text never carries the key', () {
      writeRow(file, keyA);
      try {
        prepareDatabaseFile(
          file,
          keyA,
          unlock: (_, key) => throw SqliteException(
            extendedResultCode: 13,
            message: 'injected',
            causingStatement: "PRAGMA key = '$key';",
          ),
        );
        fail('should throw');
      } on DatabaseOpenException catch (e) {
        expect(e.toString(), isNot(contains(keyA)));
      }
    });

    test('a missing cipher build is not treated as an open failure', () {
      writeRow(file, keyA);
      final bytes = file.readAsBytesSync();
      expect(
        () => prepareDatabaseFile(
          file,
          keyA,
          unlock: (_, _) => throw EncryptionUnavailableError(),
        ),
        throwsA(isA<EncryptionUnavailableError>()),
      );
      expectFileKept(file, bytes);
    });
  });

  group('only an empty key store sets the file aside', () {
    test('a stored key: nothing moves, whatever the file holds', () async {
      writeRow(file, keyB);
      final store = DatabaseKeyStore(
        SpySecureStorage(values: {'usra.db.key.v1': keyA}),
      );
      final key = await store.readOrCreate(
        beforeCreating: () => fail('the key is not gone'),
      );
      expect(key, keyA);
      expect(file.existsSync(), isTrue);
    });

    test('no key: the file moves before the new key is saved', () async {
      writeRow(file, keyA);
      File(p.join(dir.path, 'usra.sqlite-journal')).writeAsStringSync('j');
      final storage = SpySecureStorage();
      DatabaseOpenOutcome? outcome;
      final key = await DatabaseKeyStore(storage).readOrCreate(
        beforeCreating: () {
          expect(storage.values, isEmpty);
          outcome = setAsideAfterLostKey(file);
        },
      );
      expect(outcome, DatabaseOpenOutcome.recoveredFromUnreadableFile);
      expect(storage.values.values, [key]);
      final names = dir.listSync().map((f) => p.basename(f.path)).toList();
      expect(names, hasLength(2));
      expect(names, contains(startsWith('usra.sqlite.unreadable-')));
      expect(names, contains(startsWith('usra.sqlite-journal.unreadable-')));
      // The new database starts on its own, and the old file is kept whole.
      expect(() => prepareDatabaseFile(file, key), returnsNormally);
      final kept = dir.listSync().whereType<File>().firstWhere(
        (f) => p.basename(f.path).startsWith('usra.sqlite.unreadable-'),
      );
      expect(() => prepareDatabaseFile(kept, keyA), returnsNormally);
    });

    test('no key and no file: a plain first start', () {
      expect(setAsideAfterLostKey(file), DatabaseOpenOutcome.ready);
      expect(dir.listSync(), isEmpty);
    });

    test('a failed move saves no key, so the next start still knows', () async {
      file.writeAsBytesSync(List.filled(4096, 7));
      Process.runSync('chmod', ['500', dir.path]);
      addTearDown(() => Process.runSync('chmod', ['700', dir.path]));
      final storage = SpySecureStorage();
      await expectLater(
        DatabaseKeyStore(storage)
            .readOrCreate(beforeCreating: () => setAsideAfterLostKey(file)),
        throwsA(isA<DatabaseOpenException>()),
      );
      expect(storage.values, isEmpty);
      expect(file.existsSync(), isTrue);
    }, skip: Platform.isWindows);
  });

  test('no file yet means ready', () {
    expect(() => prepareDatabaseFile(file, keyA), returnsNormally);
  });

  test('a malformed key is refused before opening', () {
    expect(
      () => openEncryptedDatabase(file, "abc'; DROP TABLE x; --"),
      throwsArgumentError,
    );
    expect(() => prepareDatabaseFile(file, 'short'), throwsArgumentError);
  });
}
