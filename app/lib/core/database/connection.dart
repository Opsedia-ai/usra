import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

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
          );

  static const _keyName = 'usra.db.key.v1';
  final FlutterSecureStorage _storage;

  Future<String> readOrCreate() async {
    final existing = await _storage.read(key: _keyName);
    if (existing != null) return existing;
    final key = generateKey();
    await _storage.write(key: _keyName, value: key);
    return key;
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

/// What [prepareDatabaseFile] found.
enum DatabaseOpenOutcome {
  /// New or readable database.
  ready,

  /// The old file could not be opened with this key (for example the key
  /// was reset). It was moved aside, never deleted, and a new one starts.
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
DatabaseOpenOutcome prepareDatabaseFile(File file, String hexKey) {
  _checkKey(hexKey);
  if (!file.existsSync()) return DatabaseOpenOutcome.ready;

  var readable = true;
  final db = sqlite3.open(file.path);
  try {
    unlockDatabase(db, hexKey);
  } on SqliteException {
    readable = false;
  } finally {
    db.close();
  }
  if (readable) return DatabaseOpenOutcome.ready;

  final stamp = DateTime.now().toUtc().millisecondsSinceEpoch;
  file.renameSync('${file.path}.unreadable-$stamp');
  return DatabaseOpenOutcome.recoveredFromUnreadableFile;
}

Future<File> defaultDatabaseFile() async {
  final dir = await getApplicationSupportDirectory();
  return File(p.join(dir.path, 'usra.sqlite'));
}

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
