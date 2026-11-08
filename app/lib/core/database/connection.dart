import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../security/secure_storage_options.dart';

/// Keeps the database key in Android Keystore / iOS Keychain.
class DatabaseKeyStore {
  DatabaseKeyStore([FlutterSecureStorage? storage])
    : _storage =
          storage ??
          const FlutterSecureStorage(
            // Never migrate the key to another device through a backup.
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
            aOptions: secureStorageAndroidOptions,
          );

  static const _keyName = 'usra.db.key.v1';
  final FlutterSecureStorage _storage;

  /// The stored key, or a new one if none is stored.
  ///
  /// [beforeCreating] runs first when there is none: it's the only moment we
  /// know for certain that the key can't open a file already there. If it
  /// throws, no key is written, so the next start still knows.
  Future<String> readOrCreate({required void Function() beforeCreating}) async {
    final existing = await _storage.read(key: _keyName);
    if (existing != null) {
      // Not replaced, whatever it holds. The caller says it can't be read.
      _checkKey(existing);
      return existing;
    }
    beforeCreating();
    final key = generateKey();
    await _storage.write(key: _keyName, value: key);
    return key;
  }

  /// Saves [hexKey] over whatever is stored, readable or not. This gives up
  /// the old key for good, so it's only for a restore the person chose, once
  /// the restored file has been shown to open with [hexKey]. Everywhere else,
  /// a key that can't be read is left alone: it may come back.
  ///
  /// Reads it back, so a store that takes the key but won't return it fails
  /// here, while the restore can still be undone.
  Future<void> replace(String hexKey) async {
    _checkKey(hexKey);
    await _storage.write(key: _keyName, value: hexKey);
    if (await _storage.read(key: _keyName) != hexKey) {
      throw StateError('The database key was not saved');
    }
  }

  /// 256 random bits as hex (only 0-9a-f, so safe inside the PRAGMA).
  static String generateKey([Random? random]) {
    final rng = random ?? Random.secure();
    final bytes = List<int>.generate(32, (_) => rng.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}

/// The SQLite build has no encryption, so data would be written in plain
/// text. The app must refuse to start rather than store health data openly.
class EncryptionUnavailableError extends StateError {
  EncryptionUnavailableError()
    : super(
        'SQLite was built without encryption (expected SQLite3 Multiple '
        'Ciphers). Check hooks.user_defines.sqlite3.source in pubspec.yaml.',
      );
}

/// The database file couldn't be opened with the stored key, or couldn't be
/// moved: a full disk, a read error, a lock, damage. The records stay where
/// they are, so trying again later may work.
///
/// Carries only the SQLite code. A [SqliteException]'s text can quote the
/// `PRAGMA key` statement.
class DatabaseOpenException implements Exception {
  const DatabaseOpenException([this.code]);

  /// SQLite extended result code. Null if the file system refused instead.
  final int? code;

  @override
  String toString() => 'DatabaseOpenException($code)';
}

/// How the database file was found at start.
enum DatabaseOpenOutcome {
  /// New or readable database.
  ready,

  /// The key was gone, so the old file can't be opened. It was moved aside,
  /// never deleted, and a new one starts.
  recoveredFromUnreadableFile,
}

/// Applies [hexKey] and checks that encryption is really active.
///
/// Must be the first thing done on a connection. Throws
/// [EncryptionUnavailableError] if the cipher build is missing, and a
/// [SqliteException] if the key does not open the file.
void unlockDatabase(Database db, String hexKey) {
  _checkKey(hexKey);
  db.execute("PRAGMA key = '$hexKey';");
  // Plain SQLite ignores unknown pragmas and returns no rows.
  if (db.select('PRAGMA cipher;').isEmpty) throw EncryptionUnavailableError();
  db.select('SELECT count(*) FROM sqlite_master;');
}

/// Makes sure [file] can be opened with [hexKey] before the app uses it.
///
/// Never moves the file. Any SQLite failure throws [DatabaseOpenException],
/// including SQLITE_NOTADB: a damaged first page or a
/// cut-short file reports exactly what a wrong key reports, so that code can't
/// prove the key is wrong. The only proof is an empty key store, see
/// [setAsideAfterLostKey].
void prepareDatabaseFile(
  File file,
  String hexKey, {
  @visibleForTesting void Function(Database, String) unlock = unlockDatabase,
}) {
  _checkKey(hexKey);
  if (!file.existsSync()) return;

  try {
    final db = sqlite3.open(file.path);
    try {
      unlock(db, hexKey);
    } finally {
      db.close();
    }
  } on SqliteException catch (e) {
    throw DatabaseOpenException(e.extendedResultCode);
  }
}

/// The key store has no key, so nothing can open [file] any more: moves it
/// aside, with its journal files, so a new database can start. Never deletes.
/// Only for [DatabaseKeyStore.readOrCreate]'s `beforeCreating`.
DatabaseOpenOutcome setAsideAfterLostKey(File file) {
  final stamp = DateTime.now().toUtc().millisecondsSinceEpoch;
  // Also true if an earlier start moved it and was stopped before saving the
  // new key, so the notice still shows. A stray journal file alone isn't.
  final name = '${p.basename(file.path)}.unreadable-';
  final recovered =
      file.existsSync() ||
      (file.parent.existsSync() &&
          file.parent.listSync().any(
            (e) => p.basename(e.path).startsWith(name),
          ));
  try {
    for (final suffix in ['', '-journal', '-wal', '-shm']) {
      final part = File('${file.path}$suffix');
      if (!part.existsSync()) continue;
      part.renameSync('${file.path}$suffix.unreadable-$stamp');
    }
  } on FileSystemException {
    throw const DatabaseOpenException();
  }
  return recovered
      ? DatabaseOpenOutcome.recoveredFromUnreadableFile
      : DatabaseOpenOutcome.ready;
}

Future<File> defaultDatabaseFile() async {
  final dir = await getApplicationSupportDirectory();
  return File(p.join(dir.path, 'usra.sqlite'));
}

/// Keeps [file], its -wal / -shm files and the rest of its folder out of
/// iCloud backup by excluding the folder (see `PhotoStore.excludeFromBackup`).
/// The copy couldn't be opened anyway (the key is this-device-only), but
/// health data must not be in iCloud at all (Apple 5.1.3).
Future<void> excludeDatabaseFromBackup(
  File file,
  Future<void> Function(Directory dir) exclude,
) => exclude(file.parent);

/// Opens [file], encrypted with SQLite3 Multiple Ciphers.
QueryExecutor openEncryptedDatabase(File file, String hexKey) {
  _checkKey(hexKey);
  return NativeDatabase.createInBackground(
    file,
    setup: (db) => unlockDatabase(db, hexKey),
  );
}

void _checkKey(String hexKey) {
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(hexKey)) {
    throw ArgumentError('Database key must be 64 lowercase hex characters');
  }
}
