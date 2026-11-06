import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:usra/core/database/connection.dart';

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
    expect(prepareDatabaseFile(file, keyA), DatabaseOpenOutcome.ready);
    expect(file.existsSync(), isTrue);
  });

  test('a lost key moves the old file aside instead of crashing', () {
    writeRow(file, keyA);
    expect(
      prepareDatabaseFile(file, keyB),
      DatabaseOpenOutcome.recoveredFromUnreadableFile,
    );
    expect(file.existsSync(), isFalse);
    final kept = dir.listSync().whereType<File>().map(
      (f) => p.basename(f.path),
    );
    expect(kept.single, startsWith('usra.sqlite.unreadable-'));
  });

  group('only SQLITE_NOTADB moves the file aside', () {
    void expectFileKept(File file) {
      expect(file.existsSync(), isTrue);
      expect(
        dir.listSync().map((f) => p.basename(f.path)),
        isNot(contains(startsWith('usra.sqlite.unreadable-'))),
      );
    }

    test('wrong key reports NOTADB (rollback journal and WAL files)', () {
      writeRow(file, keyA);
      final other = File(p.join(dir.path, 'wal.sqlite'));
      final wal = sqlite3.open(other.path);
      unlockDatabase(wal, keyA);
      wal.execute('PRAGMA journal_mode = WAL;');
      wal.execute('CREATE TABLE t (v TEXT)');
      wal.close();
      for (final f in [file, other]) {
        final db = sqlite3.open(f.path);
        addTearDown(db.close);
        expect(
          () => unlockDatabase(db, keyB),
          throwsA(
            isA<SqliteException>().having(
              (e) => e.resultCode,
              'resultCode',
              sqliteNotADatabase,
            ),
          ),
        );
      }
    });

    test('a file that is not a database still moves aside', () {
      file.writeAsBytesSync(List.filled(4096, 7));
      expect(
        prepareDatabaseFile(file, keyA),
        DatabaseOpenOutcome.recoveredFromUnreadableFile,
      );
      expect(file.existsSync(), isFalse);
    });

    test('a real SQLITE_BUSY keeps the file and reports the code', () {
      writeRow(file, keyA);
      final holder = sqlite3.open(file.path);
      addTearDown(holder.close);
      unlockDatabase(holder, keyA);
      holder.execute('BEGIN EXCLUSIVE;');
      expect(
        () => prepareDatabaseFile(file, keyA),
        throwsA(isA<DatabaseOpenException>().having((e) => e.code, 'code', 5)),
      );
      expectFileKept(file);
      holder.execute('COMMIT;');
      expect(prepareDatabaseFile(file, keyA), DatabaseOpenOutcome.ready);
    });

    test('a file SQLite cannot open keeps the file', () {
      writeRow(file, keyA);
      Process.runSync('chmod', ['000', file.path]);
      addTearDown(() => Process.runSync('chmod', ['600', file.path]));
      expect(
        () => prepareDatabaseFile(file, keyA),
        throwsA(isA<DatabaseOpenException>()),
      );
      expectFileKept(file);
    }, skip: Platform.isWindows);

    // Disk errors can't be caused on demand in a test, so these inject them.
    for (final (name, code) in [
      ('FULL', 13),
      ('IOERR', 10),
      ('IOERR_READ', 266),
      ('CORRUPT', 11),
      ('CANTOPEN', 14),
    ]) {
      test('$name keeps the file', () {
        writeRow(file, keyA);
        expect(
          () => prepareDatabaseFile(
            file,
            keyA,
            unlock: (_, _) => throw SqliteException(
              extendedResultCode: code,
              message: 'injected',
            ),
          ),
          throwsA(
            isA<DatabaseOpenException>().having((e) => e.code, 'code', code),
          ),
        );
        expectFileKept(file);
      });
    }

    test('an extended NOTADB code still moves the file aside', () {
      writeRow(file, keyA);
      expect(
        prepareDatabaseFile(
          file,
          keyA,
          unlock: (_, _) => throw SqliteException(
            extendedResultCode: 26 | 256,
            message: 'injected',
          ),
        ),
        DatabaseOpenOutcome.recoveredFromUnreadableFile,
      );
    });

    test('a failed rename is reported, not a crash', () {
      file.writeAsBytesSync(List.filled(4096, 7));
      Process.runSync('chmod', ['500', dir.path]);
      addTearDown(() => Process.runSync('chmod', ['700', dir.path]));
      expect(
        () => prepareDatabaseFile(file, keyA),
        throwsA(isA<DatabaseOpenException>()),
      );
      expect(file.existsSync(), isTrue);
    }, skip: Platform.isWindows);

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
      expect(
        () => prepareDatabaseFile(
          file,
          keyA,
          unlock: (_, _) => throw EncryptionUnavailableError(),
        ),
        throwsA(isA<EncryptionUnavailableError>()),
      );
      expectFileKept(file);
    });
  });

  test('no file yet means ready', () {
    expect(prepareDatabaseFile(file, keyA), DatabaseOpenOutcome.ready);
  });

  test('a malformed key is refused before opening', () {
    expect(
      () => openEncryptedDatabase(file, "abc'; DROP TABLE x; --"),
      throwsArgumentError,
    );
    expect(() => prepareDatabaseFile(file, 'short'), throwsArgumentError);
  });
}
