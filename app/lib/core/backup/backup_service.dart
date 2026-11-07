import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import '../database/app_database.dart';
import '../database/connection.dart';
import '../files/photo_crypto.dart';
import 'auto_backup.dart' show backupMissingPhotosCount;
import 'backup_archive.dart';
import 'backup_crypto.dart';
import 'recovery_key.dart';

/// What a backup holds, saved inside it as `manifest.json`.
class BackupManifest {
  const BackupManifest({
    required this.appVersion,
    required this.schemaVersion,
    required this.createdAt,
    required this.counts,
  });

  /// Bumped when the inside of the backup changes in a way older apps
  /// can't read.
  static const format = 1;

  final String appVersion;
  final int schemaVersion;
  final DateTime createdAt;

  /// Live (not deleted) rows per table, and `photos`.
  final Map<String, int> counts;

  int count(String name) => counts[name] ?? 0;

  static BackupManifest fromJson(Map<String, dynamic> json) => BackupManifest(
    appVersion: json['appVersion'] as String,
    schemaVersion: json['schemaVersion'] as int,
    createdAt: DateTime.parse(json['createdAt'] as String),
    counts: (json['counts'] as Map<String, dynamic>).map(
      (k, v) => MapEntry(k, v as int),
    ),
  );
}

/// A backup decrypted and checked, waiting in the staging folder to replace
/// what's on the phone.
class StagedRestore {
  const StagedRestore(this.manifest, {this.skippedPhotos = 0});

  final BackupManifest manifest;

  /// Photos in the backup that were left out: already encrypted for
  /// another phone, so nothing here can open them.
  final int skippedPhotos;
}

/// A backup file made by [BackupService.create].
class CreatedBackup {
  const CreatedBackup(
    this.file, {
    this.skippedPhotos = 0,
    this.counts = const {},
  });

  final File file;

  /// What's in it, as in [BackupManifest.counts], plus the photos with a row
  /// in the database but no file (`backupMissingPhotosCount`).
  final Map<String, int> counts;

  /// Photos left out because they can't be opened on this phone (damaged,
  /// or the photo key is gone); the backup isn't complete without saying so.
  final int skippedPhotos;
}

/// Makes encrypted backups of the database and photos, and puts them back.
///
/// Backups are never encrypted with the phone's database key (that never
/// leaves the phone), but with a key derived from the family's
/// [RecoveryKey]. The database inside is a `VACUUM INTO` snapshot re-keyed
/// with a one-off key written in the manifest, so it is never on disk
/// unencrypted, here or on the new phone.
///
/// Photos are the same: the phone's photo key never leaves it either. They
/// go into the backup decrypted, inside the backup's encryption, and a
/// restore encrypts them for the phone it runs on as they come out, so
/// they never touch the disk unencrypted. That also keeps the inside of a
/// backup the same as before photos were encrypted, so old and new
/// backups restore both ways.
class BackupService {
  BackupService({
    required this.root,
    required this.databaseName,
    required this.deviceKey,
    required this.photoKeys,
    this.photoKeyStore,
    required this.temporary,
    required this.folders,
    this.files = const [],
    this.kdf = BackupKdf.standard,
    this.chunkSize = BackupFileFormat.defaultChunkSize,
    this.excludeFromBackup,
  });

  /// The app's private folder, holding the database, [folders] and [files].
  final Directory root;
  final String databaseName;

  /// The phone's database key, only used to read and re-key snapshots.
  final String deviceKey;

  /// The phone's photo key (see [PhotoCipher]), only used to decrypt photos
  /// into a backup and encrypt restored ones.
  final PhotoKeys photoKeys;

  /// Where a new photo key is saved when a restore brings photos back to a
  /// phone whose key was lost (or never made).
  final PhotoKeyStore? photoKeyStore;

  /// The key a staged restore encrypted its photos with, if it had to make
  /// one; saved by [commit].
  PhotoCipher? _stagedKey;

  /// Where new backup files are written before sharing.
  final Directory temporary;

  /// Photo folders inside [root].
  final List<String> folders;

  /// Other small files inside [root] worth keeping (dismissed follow-ups).
  final List<String> files;
  final BackupKdf kdf;
  final int chunkSize;

  /// Keeps a folder out of iCloud backup (its photo key stays on this
  /// phone, so a copy elsewhere is no use).
  final Future<void> Function(Directory dir)? excludeFromBackup;

  static const _backupPrefix = 'usra-backup-';
  static const _manifestName = 'manifest.json';
  static const _databaseEntry = 'database.sqlite';
  static const _stagingName = 'restore-staging';
  static const _asideName = 'restore-aside';
  static const _markerName = 'restore-in-progress.json';

  Directory get _staging => Directory(p.join(root.path, _stagingName));
  Directory get _aside => Directory(p.join(root.path, _asideName));
  File get _marker => File(p.join(root.path, _markerName));

  /// Writes an encrypted backup of [db] and the photos to a new file in
  /// [temporary] and returns it. The caller shares it, then deletes it.
  Future<CreatedBackup> create(
    AppDatabase db,
    RecoveryKey key, {
    required String appVersion,
    DateTime? now,
  }) async {
    final createdAt = (now ?? DateTime.now()).toUtc();
    await clearLeftovers();
    final work = await temporary.createTemp(_backupPrefix);
    final snapshot = p.join(work.path, 'snapshot.sqlite');
    final stamp = createdAt.toIso8601String().substring(0, 10);
    final out = File(p.join(temporary.path, '$_backupPrefix$stamp.usra'));
    try {
      // Consistent even while the app keeps writing.
      await db.customStatement('VACUUM INTO ?', [snapshot]);
      final (rootPath, folders, files, deviceKey, photoKey, kdf, chunk) = (
        root.path,
        this.folders,
        this.files,
        this.deviceKey,
        photoKeys.cipher?.keyBytes,
        this.kdf,
        chunkSize,
      );
      final (skipped, counts) = await Isolate.run(
        () => _pack(
          snapshot: snapshot,
          out: out.path,
          root: rootPath,
          folders: folders,
          files: files,
          deviceKey: deviceKey,
          photoKey: photoKey,
          key: key,
          kdf: kdf,
          chunkSize: chunk,
          appVersion: appVersion,
          createdAt: createdAt,
        ),
      );
      return CreatedBackup(out, skippedPhotos: skipped, counts: counts);
    } catch (_) {
      if (await out.exists()) await out.delete();
      rethrow;
    } finally {
      await work.delete(recursive: true);
    }
  }

  /// Deletes what earlier backups left in [temporary] (S11): backup files
  /// already shared (encrypted, but no use kept here) and the work folder
  /// of one the app was killed while making, with its database snapshot
  /// (encrypted too, with this phone's key). Run at start-up and before
  /// each backup. The recovery key is never written to any of them.
  Future<void> clearLeftovers() async {
    if (!await temporary.exists()) return;
    await for (final entity in temporary.list(followLinks: false)) {
      if (p.basename(entity.path).startsWith(_backupPrefix)) {
        await entity.delete(recursive: true);
      }
    }
  }

  /// Deletes a backup file once it was shared or saved: the copy that
  /// matters is wherever the family put it.
  Future<void> discardCreated(CreatedBackup backup) async {
    if (await backup.file.exists()) await backup.file.delete();
  }

  /// Decrypts [backup] with [key] into a staging folder and checks it,
  /// without touching what's on the phone yet. Throws [BackupException].
  Future<StagedRestore> stage(
    File backup,
    RecoveryKey key, {
    required int currentSchema,
  }) async {
    await _clearStaging();
    await _staging.create(recursive: true);
    await excludeFromBackup?.call(_staging);
    // No key, because it was lost or is corrupt: the restore replaces every
    // photo, so a new one is safe, and is saved only if the restore goes in.
    // A key store that couldn't be read may still hold the real key: stop.
    _stagedKey = null;
    var cipher = photoKeys.cipher;
    if (cipher == null) {
      if (photoKeys.problem == PhotoKeyProblem.unreadable ||
          photoKeyStore == null) {
        throw PhotoKeyUnavailableException(photoKeys.problem!);
      }
      cipher = _stagedKey = PhotoCipher(PhotoCipher.generateKey());
    }
    final (staging, databaseName, folders, files, deviceKey, photoKey) = (
      _staging.path,
      this.databaseName,
      this.folders,
      this.files,
      this.deviceKey,
      cipher.keyBytes,
    );
    try {
      final json = await Isolate.run(
        () => _unpack(
          backup: backup.path,
          staging: staging,
          databaseName: databaseName,
          folders: folders,
          files: files,
          deviceKey: deviceKey,
          photoKey: photoKey,
          key: key,
          currentSchema: currentSchema,
        ),
      );
      final skipped = json.remove('skippedPhotos') as int;
      return StagedRestore(
        BackupManifest.fromJson(json),
        skippedPhotos: skipped,
      );
    } catch (_) {
      await _clearStaging();
      rethrow;
    }
  }

  /// Swaps the staged backup in for the database and photos. The database
  /// must be closed. What was there is kept in a side folder until
  /// [discardAside]; if anything fails it is put back and this rethrows.
  Future<void> commit() async {
    if (!await File(p.join(_staging.path, databaseName)).exists()) {
      throw StateError('Nothing staged to restore');
    }
    if (_stagedKey case final key?) {
      // Before anything moves: photos encrypted with a key that isn't kept
      // would be lost.
      await photoKeyStore!.save(key);
      photoKeys.replace(key);
      _stagedKey = null;
    }
    if (await _aside.exists()) await _aside.delete(recursive: true);
    await _aside.create();
    // Its presence is what matters: rollback works from [_targets].
    await _marker.create();
    try {
      for (final name in _targets) {
        await _move(p.join(root.path, name), p.join(_aside.path, name));
      }
      for (final name in [databaseName, ...folders, ...files]) {
        await _move(p.join(_staging.path, name), p.join(root.path, name));
      }
    } catch (_) {
      await _rollBack();
      await _clearStaging();
      rethrow;
    }
    await _marker.delete();
    await _clearStaging();
    for (final folder in folders) {
      final dir = Directory(p.join(root.path, folder));
      if (await dir.exists()) await excludeFromBackup?.call(dir);
    }
  }

  /// Drops a staged backup that won't be restored after all.
  Future<void> discardStaged() => _clearStaging();

  /// Deletes what a successful restore replaced.
  /// A restore that went in but won't open: puts the old data back, while
  /// it's still aside. If this is stopped part way, the next start finishes it.
  Future<void> undoCommit() async {
    await _marker.create();
    await recoverInterrupted();
  }

  Future<void> discardAside() async {
    if (await _aside.exists()) await _aside.delete(recursive: true);
  }

  /// At start-up, before opening the database: finishes off a restore the
  /// app was killed in the middle of, putting the old data back, and clears
  /// leftovers.
  Future<void> recoverInterrupted() async {
    if (await _marker.exists()) {
      await _rollBack();
    } else {
      await discardAside();
    }
    await _clearStaging();
  }

  /// Everything a restore replaces, relative to [root]. The journal files
  /// only ever move aside: a closed database has nothing in them that
  /// matters, and a stray one must not be paired with the new database.
  List<String> get _targets => [
    databaseName,
    for (final suffix in ['-journal', '-wal', '-shm']) '$databaseName$suffix',
    ...folders,
    ...files,
  ];

  Future<void> _rollBack() async {
    for (final name in _targets) {
      final live = p.join(root.path, name);
      final old = p.join(_aside.path, name);
      final staged = p.join(_staging.path, name);
      if (await _exists(old)) {
        await _delete(live);
        await _move(old, live);
      } else if (!await _exists(staged)) {
        // Moved in from the backup with nothing before it.
        await _delete(live);
      }
    }
    if (await _marker.exists()) await _marker.delete();
    await discardAside();
  }

  Future<void> _clearStaging() async {
    if (await _staging.exists()) await _staging.delete(recursive: true);
  }

  static Future<bool> _exists(String path) async =>
      await FileSystemEntity.type(path) != FileSystemEntityType.notFound;

  static Future<void> _delete(String path) async {
    switch (await FileSystemEntity.type(path)) {
      case FileSystemEntityType.directory:
        await Directory(path).delete(recursive: true);
      case FileSystemEntityType.notFound:
        break;
      default:
        await File(path).delete();
    }
  }

  static Future<void> _move(String from, String to) async {
    switch (await FileSystemEntity.type(from)) {
      case FileSystemEntityType.directory:
        await Directory(from).rename(to);
      case FileSystemEntityType.notFound:
        break;
      default:
        await File(from).rename(to);
    }
  }
}

/// Tables counted in the manifest, by the name the UI uses.
const _countedTables = {
  'people': 'profiles',
  'records': 'medical_events',
  'medicines': 'medicines',
  'prescriptions': 'prescriptions',
  'sickDays': 'sick_episodes',
  'doctors': 'doctors',
  'insuranceCards': 'insurance_cards',
  'attachments': 'attachments',
};

/// Every photo the live rows point at, whichever table holds the path. Add
/// any new photo column here, or its photos can go missing unnoticed.
Set<String> _photoPathsInDatabase(Database db, Set<String> tables) {
  final paths = <String>{};
  void addColumn(String table, String column) {
    if (!tables.contains(table)) return;
    for (final row in db.select(
      'SELECT $column AS path FROM $table WHERE deleted_at IS NULL',
    )) {
      if (row['path'] case final String path when path.isNotEmpty) {
        paths.add(path);
      }
    }
  }

  void addJsonColumn(String table, String column) {
    if (!tables.contains(table)) return;
    for (final row in db.select(
      'SELECT $column AS paths FROM $table WHERE deleted_at IS NULL',
    )) {
      try {
        final list = jsonDecode(row['paths'] as String) as List<dynamic>;
        for (final path in list) {
          if (path case final String path when path.isNotEmpty) {
            paths.add(path);
          }
        }
      } on Object {
        // A damaged list can't name anything to look for; the row is kept.
      }
    }
  }

  addColumn('attachments', 'path');
  addColumn('insurance_cards', 'front_photo');
  addColumn('insurance_cards', 'back_photo');
  addJsonColumn('medicines', 'photos_json');
  addJsonColumn('prescriptions', 'photos_json');
  return paths;
}

/// Returns how many photos were left out, and what's in it.
Future<(int, Map<String, int>)> _pack({
  required String snapshot,
  required String out,
  required String root,
  required List<String> folders,
  required List<String> files,
  required String deviceKey,
  required List<int>? photoKey,
  required RecoveryKey key,
  required BackupKdf kdf,
  required int chunkSize,
  required String appVersion,
  required DateTime createdAt,
}) async {
  // Re-key the snapshot with a one-off key, so the phone's key never
  // leaves it and the new phone can open the database.
  final snapshotKey = DatabaseKeyStore.generateKey();
  final counts = <String, int>{};
  final int schemaVersion;
  final Set<String> expectedPhotos;
  final db = sqlite3.open(snapshot);
  try {
    unlockDatabase(db, deviceKey);
    schemaVersion = db.userVersion;
    final tables = {
      for (final row in db.select(
        "SELECT name FROM sqlite_master WHERE type = 'table'",
      ))
        row['name'] as String,
    };
    for (final MapEntry(key: name, value: table) in _countedTables.entries) {
      if (!tables.contains(table)) continue;
      counts[name] =
          db
                  .select(
                    'SELECT count(*) AS n FROM $table WHERE deleted_at IS NULL',
                  )
                  .first['n']
              as int;
    }
    expectedPhotos = _photoPathsInDatabase(db, tables);
    db.execute("PRAGMA rekey = '$snapshotKey';");
  } finally {
    db.close();
  }

  final photos = <(String, File)>[];
  for (final folder in folders) {
    final dir = Directory(p.join(root, folder));
    if (!await dir.exists()) continue;
    await for (final entity in dir.list()) {
      final name = '$folder/${p.basename(entity.path)}';
      if (entity is! File) continue;
      // Hidden system files (.DS_Store) aren't photos. Anything else must
      // go in, so a name the tar can't hold fails the backup, loudly.
      if (p.basename(entity.path).startsWith('.')) continue;
      photos.add((name, entity));
    }
  }

  // In the database but not on disk: its folder is gone, or it never landed.
  // Nothing in the file can show this, so it's reported here.
  final found = {for (final (name, _) in photos) name};
  final missing = expectedPhotos.where((path) => !found.contains(path)).length;

  var skipped = 0;
  final writer = await BackupFileWriter.create(
    File(out),
    key,
    kdf: kdf,
    chunkSize: chunkSize,
  );
  try {
    final tar = TarWriter(writer.add);
    await tar.addFile(BackupService._databaseEntry, File(snapshot));
    final cipher = photoKey == null ? null : PhotoCipher(photoKey);
    var photoCount = 0;
    for (final (name, file) in photos) {
      final bytes = await file.readAsBytes();
      final Uint8List photo;
      if (!PhotoCipher.isSealed(bytes)) {
        // Not reached yet by the start-up migration: still plain.
        photo = bytes;
      } else if (cipher == null) {
        // No key on this phone: nothing to open it with.
        skipped++;
        continue;
      } else {
        try {
          photo = cipher.open(bytes);
        } on PhotoUnreadableException {
          // Damaged on this phone and shown as a broken image already; it
          // mustn't stop the rest from being backed up, but is reported.
          skipped++;
          continue;
        }
      }
      await tar.addBytes(name, photo);
      photoCount++;
    }
    counts['photos'] = photoCount;
    for (final name in files) {
      final file = File(p.join(root, name));
      if (await file.exists()) await tar.addFile(name, file);
    }
    // Last, so it can count the photos; a restore reads it once everything
    // is unpacked, wherever it is.
    await tar.addBytes(
      BackupService._manifestName,
      utf8.encode(
        jsonEncode({
          'format': BackupManifest.format,
          'appVersion': appVersion,
          'schemaVersion': schemaVersion,
          'createdAt': createdAt.toIso8601String(),
          'counts': counts,
          'snapshotKey': snapshotKey,
        }),
      ),
    );
    await tar.finish();
  } finally {
    await writer.close();
  }
  return (skipped, {...counts, backupMissingPhotosCount: missing});
}

Future<Map<String, dynamic>> _unpack({
  required String backup,
  required String staging,
  required String databaseName,
  required List<String> folders,
  required List<String> files,
  required String deviceKey,
  required List<int> photoKey,
  required RecoveryKey key,
  required int currentSchema,
}) async {
  final cipher = PhotoCipher(photoKey);
  var skipped = 0;
  // Backups hold photos decrypted. One already encrypted (a backup not
  // made by Usra, or from a future format) is kept only if this phone can
  // open it; encrypting it again would make it a photo nothing can show.
  List<int>? sealForThisPhone(Uint8List photo) {
    if (!PhotoCipher.isSealed(photo)) return cipher.seal(photo);
    try {
      cipher.open(photo);
      return photo;
    } on PhotoUnreadableException {
      skipped++;
      return null;
    }
  }

  bool isPhoto(String name) {
    final parts = name.split('/');
    return parts.length == 2 && folders.contains(parts.first);
  }

  final reader = await BackupFileReader.open(File(backup), key);
  try {
    await extractTar(
      reader,
      Directory(staging),
      accept: (name) {
        if (name == BackupService._manifestName ||
            name == BackupService._databaseEntry ||
            files.contains(name)) {
          return true;
        }
        return isPhoto(name);
      },
      transform: (name) => isPhoto(name) ? sealForThisPhone : null,
    );
  } finally {
    await reader.close();
  }

  final manifestFile = File(p.join(staging, BackupService._manifestName));
  final databaseFile = File(p.join(staging, BackupService._databaseEntry));
  if (!await manifestFile.exists() || !await databaseFile.exists()) {
    throw const BackupException(BackupFailure.damaged, 'missing parts');
  }
  final Map<String, dynamic> manifest;
  final String snapshotKey;
  try {
    manifest =
        jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>;
    snapshotKey = manifest['snapshotKey'] as String;
    BackupManifest.fromJson(manifest);
  } catch (_) {
    throw const BackupException(BackupFailure.damaged, 'manifest');
  } finally {
    await manifestFile.delete();
  }
  if ((manifest['format'] as int? ?? 0) > BackupManifest.format ||
      (manifest['schemaVersion'] as int) > currentSchema) {
    throw const BackupException(BackupFailure.tooNew);
  }

  // Opened with the one-off key, checked, then re-keyed for this phone.
  final db = sqlite3.open(databaseFile.path);
  try {
    unlockDatabase(db, snapshotKey);
    final check = db.select('PRAGMA quick_check;');
    if (check.length != 1 || check.first.values.first != 'ok') {
      throw const BackupException(BackupFailure.damaged, 'database check');
    }
    if (db.userVersion != manifest['schemaVersion']) {
      throw const BackupException(BackupFailure.damaged, 'schema version');
    }
    db.execute("PRAGMA rekey = '$deviceKey';");
  } on SqliteException {
    throw const BackupException(BackupFailure.damaged, 'database');
  } on ArgumentError {
    throw const BackupException(BackupFailure.damaged, 'database key');
  } finally {
    db.close();
  }
  await databaseFile.rename(p.join(staging, databaseName));
  manifest.remove('snapshotKey');
  return manifest..['skippedPhotos'] = skipped;
}
