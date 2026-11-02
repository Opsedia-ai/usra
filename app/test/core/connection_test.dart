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
