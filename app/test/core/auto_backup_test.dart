import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:usra/core/backup/auto_backup.dart';
import 'package:usra/core/backup/auto_backup_runner.dart';
import 'package:usra/core/backup/backup_crypto.dart';
import 'package:usra/core/backup/backup_folder.dart';
import 'package:usra/core/backup/backup_service.dart';
import 'package:usra/core/backup/recovery_key.dart';
import 'package:usra/core/database/app_database.dart';
import 'package:usra/core/database/connection.dart';
import 'package:usra/core/files/photo_crypto.dart';
import 'package:usra/core/log.dart';

const _tag = 'abcd1234';
const _testKdf = BackupKdf(memory: 64, iterations: 1, parallelism: 1);

/// A folder on disk, behaving as the platform channels do, with ways to
/// fail: what a phone can't do in a test.
class _Folder implements BackupFolderAccess {
  _Folder(this.dir);

  final Directory dir;
  BackupFolderProblem? inspectProblem;
  BackupFolderProblem? writeProblem;
  BackupFolderProblem? renameProblem;
  BackupFolderProblem? listProblem;
  BackupFolderProblem? deleteProblem;

  /// Writes this many bytes, then stops: a killed app or a full disk.
  int? writeOnly;
  bool ubiquitous = false;
  String? path;
  String? renewedId;
  bool protectedData = true;
  PickedFolder? picked;
  final writes = <String>[];
  final deleted = <String>[];

  void _throw(BackupFolderProblem? problem) {
    if (problem != null) throw BackupFolderException(problem);
  }

  List<String> get names =>
      [for (final entity in dir.listSync()) p.basename(entity.path)]..sort();

  @override
  Future<PickedFolder?> pick() async => picked;

  @override
  Future<FolderStatus> inspect(String id) async {
    _throw(inspectProblem);
    return FolderStatus(
      path: path ?? dir.path,
      isUbiquitous: ubiquitous,
      renewedId: renewedId,
    );
  }

  @override
  Future<int> write(String id, String sourcePath, String name) async {
    writes.add(name);
    final target = File(p.join(dir.path, name));
    final bytes = await File(sourcePath).readAsBytes();
    if (writeOnly case final only?) {
      await target.writeAsBytes(bytes.sublist(0, only));
      _throw(writeProblem);
      return only;
    }
    _throw(writeProblem);
    await target.writeAsBytes(bytes);
    return bytes.length;
  }

  @override
  Future<void> rename(String id, String from, String to) async {
    _throw(renameProblem);
    await File(p.join(dir.path, from)).rename(p.join(dir.path, to));
  }

  @override
  Future<void> delete(String id, String name) async {
    _throw(deleteProblem);
    deleted.add(name);
    final file = File(p.join(dir.path, name));
    if (await file.exists()) await file.delete();
  }

  @override
  Future<List<FolderEntry>> list(String id) async {
    _throw(listProblem);
    return [for (final name in names) FolderEntry(name, null)];
  }

  @override
  Future<void> release(String id) async {}

  @override
  Future<bool> protectedDataAvailable() async => protectedData;
}

AutoBackupSettings _on({
  DateTime? lastAt,
  DateTime? lastAttemptAt,
  BackupFrequency frequency = BackupFrequency.weekly,
  AutoBackupFailure? failure,
}) => AutoBackupSettings(
  enabled: true,
  frequency: frequency,
  folder: const BackupFolder(id: 'folder', name: 'Backups', onThisPhone: true),
  tag: _tag,
  lastAt: lastAt,
  lastAttemptAt: lastAttemptAt,
  failure: failure,
);

void main() {
  group('when a backup is due', () {
    final now = DateTime(2026, 11, 6, 9);

    test('the first one is due at once, and weekly is the default', () {
      expect(const AutoBackupSettings().frequency, BackupFrequency.weekly);
      expect(isBackupDue(_on(), now), isTrue);
    });

    test('counts calendar days, so an earlier hour isn\'t skipped', () {
      // Made at 10:00; opened at 09:00 seven days later.
      final last = DateTime(2026, 10, 30, 10);
      expect(isBackupDue(_on(lastAt: last), now), isTrue);
      expect(isBackupDue(_on(lastAt: DateTime(2026, 10, 31, 8)), now), isFalse);
    });

    test('each frequency', () {
      for (final (frequency, days, due) in [
        (BackupFrequency.daily, 0, false),
        (BackupFrequency.daily, 1, true),
        (BackupFrequency.weekly, 6, false),
        (BackupFrequency.weekly, 7, true),
        (BackupFrequency.monthly, 29, false),
        (BackupFrequency.monthly, 30, true),
      ]) {
        final last = DateTime(2026, 11, 6 - days, 9);
        expect(
          isBackupDue(_on(lastAt: last, frequency: frequency), now),
          due,
          reason: '$frequency after $days days',
        );
      }
    });

    test('a clock moved back doesn\'t stop backups', () {
      expect(isBackupDue(_on(lastAt: DateTime(2027, 1, 1)), now), isTrue);
    });

    test('off, or with no folder, never starts', () {
      expect(
        shouldStartAutoBackup(_on().copyWith(enabled: false), now),
        isFalse,
      );
      expect(shouldStartAutoBackup(_on().copyWith(folder: null), now), isFalse);
      expect(shouldStartAutoBackup(_on(), now), isTrue);
    });

    test('a failed try waits before the next open tries again', () {
      final soon = now.subtract(const Duration(hours: 1));
      final later = now.subtract(autoBackupCooldown);
      expect(
        shouldStartAutoBackup(
          _on(lastAttemptAt: soon, failure: AutoBackupFailure.failed),
          now,
        ),
        isFalse,
      );
      expect(
        shouldStartAutoBackup(
          _on(lastAttemptAt: later, failure: AutoBackupFailure.failed),
          now,
        ),
        isTrue,
      );
    });

    test('a locked phone tries again as soon as it\'s opened', () {
      expect(
        shouldStartAutoBackup(
          _on(
            lastAttemptAt: now.subtract(const Duration(minutes: 1)),
            failure: AutoBackupFailure.phoneLocked,
          ),
          now,
        ),
        isTrue,
      );
    });
  });

  group('file names and retention', () {
    String named(int day, {bool complete = true, String tag = _tag}) =>
        AutoBackupFileName.make(
          tag,
          DateTime.utc(2026, 11, day, 10, 30, 5),
          complete: complete,
        );

    test('names say nothing about the family, and read back', () {
      final name = named(6);
      expect(name, 'usra-auto-abcd1234-20261106-103005.usra');
      final parsed = AutoBackupFileName.parse(name)!;
      expect(parsed.tag, _tag);
      expect(parsed.isComplete, isTrue);
      expect(
        AutoBackupFileName.parse(named(6, complete: false))!.isComplete,
        isFalse,
      );
    });

    test('keeps the newest 3', () {
      final names = [named(1), named(2), named(3), named(4), named(5)];
      expect(backupsToDelete(names, _tag), [named(2), named(1)]);
      expect(backupsToDelete(names.take(3), _tag), isEmpty);
    });

    test('never deletes what this phone didn\'t write', () {
      final names = [
        // The family's own, a manual backup, another phone's, near misses.
        'usra-backup-2026-01-01.usra',
        'notes.pdf',
        'usra-auto-abcd1234.usra',
        'usra-auto-ABCD1234-20260101-000000.usra',
        'usra-auto-abcd1234-20260101-000000.usra.bak',
        named(1, tag: 'ffffffff'),
        // This phone's.
        named(1), named(2), named(3), named(4),
      ];
      expect(backupsToDelete(names, _tag), [named(1)]);
    });

    test('backups missing photos can\'t push out the last whole one', () {
      final names = [
        named(1),
        named(2),
        named(3, complete: false),
        named(4, complete: false),
        named(5, complete: false),
      ];
      expect(backupsToDelete(names, _tag), [named(1)]);
      expect(backupsToDelete([...names, named(6, complete: false)], _tag), [
        named(3, complete: false),
        named(1),
      ]);
    });

    test('a clock corrected from a wrong date can\'t delete the new one', () {
      final wrong = [
        for (final year in [2030, 2031, 2032])
          AutoBackupFileName.make(_tag, DateTime.utc(year)),
      ];
      final landed = named(6);
      final doomed = backupsToDelete(
        [...wrong, landed],
        _tag,
        justLanded: landed,
      );
      expect(doomed, isNot(contains(landed)));
      expect(doomed, [wrong.first]);
    });

    test('only this phone\'s half-written files are leftovers', () {
      final mine = AutoBackupFileName.partialOf(named(1));
      final other = AutoBackupFileName.partialOf(named(1, tag: 'ffffffff'));
      expect(mine, 'usra-auto-abcd1234-20261101-103005.partial');
      expect(partialsToDelete([mine, other, 'x.partial', named(2)], _tag), [
        mine,
      ]);
    });

    test('a new tag is 8 hex characters', () {
      expect(newBackupTag(Random(1)), matches(RegExp(r'^[0-9a-f]{8}$')));
    });
  });

  group('iCloud', () {
    test('finds iCloud Drive paths', () {
      for (final path in [
        '/private/var/mobile/Library/Mobile Documents/com~apple~CloudDocs/Backups',
        '/var/mobile/Library/Mobile Documents/iCloud~com~example~app/Documents',
        '/private/var/mobile/Library/Mobile Documents',
      ]) {
        expect(isICloudPath(path), isTrue, reason: path);
      }
    });

    test('leaves other places alone', () {
      for (final path in [
        '/private/var/mobile/Containers/Shared/AppGroup/1234/File Provider Storage/Backups',
        '/private/var/mobile/Library/LiveFiles/com.apple.filesystems.userfsd/USB/Backups',
        '/storage/emulated/0/Documents/iCloud notes',
      ]) {
        expect(isICloudPath(path), isFalse, reason: path);
      }
    });

    test('iOS saying it\'s ubiquitous is enough, whatever the path', () {
      expect(isInICloud(path: '/somewhere/else', isUbiquitous: true), isTrue);
      expect(isInICloud(path: null, isUbiquitous: false), isFalse);
    });
  });

  group('settings', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('usra_auto_store'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('survive a restart, and leave no temporary file', () async {
      final store = await AutoBackupStore.open(dir);
      expect(store.current.enabled, isFalse);
      final at = DateTime.fromMillisecondsSinceEpoch(1762426800000);
      await store.save(
        _on(lastAt: at, failure: AutoBackupFailure.noSpace).copyWith(
          lastSize: 1234,
          lastSkippedPhotos: 2,
          frequency: BackupFrequency.monthly,
        ),
      );
      final reopened = (await AutoBackupStore.open(dir)).current;
      expect(reopened.enabled, isTrue);
      expect(reopened.frequency, BackupFrequency.monthly);
      expect(reopened.folder!.id, 'folder');
      expect(reopened.folder!.onThisPhone, isTrue);
      expect(reopened.tag, _tag);
      expect(reopened.lastAt, at);
      expect(reopened.lastSize, 1234);
      expect(reopened.lastSkippedPhotos, 2);
      expect(reopened.failure, AutoBackupFailure.noSpace);
      expect(dir.listSync().map((e) => p.basename(e.path)), [
        AutoBackupStore.fileName,
      ]);
    });

    test('a damaged file means off, not a crash', () async {
      File(p.join(dir.path, AutoBackupStore.fileName)).writeAsStringSync('{{');
      final store = await AutoBackupStore.open(dir);
      expect(store.current.enabled, isFalse);
    });
  });

  group('the gate', () {
    test('one at a time, and close waits for the running one', () async {
      final gate = BackupGate();
      var finished = false;
      final first = gate.tryRun(() async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        finished = true;
        return 1;
      });
      expect(gate.busy, isTrue);
      expect(await gate.tryRun(() async => 2), isNull);
      await gate.close();
      expect(finished, isTrue);
      expect(await first, 1);
      expect(await gate.tryRun(() async => 3), isNull);
      gate.open();
      expect(await gate.tryRun(() async => 4), 4);
      expect(gate.busy, isFalse);
    });

    test('a stuck backup can\'t hold up a wipe for ever', () async {
      final gate = BackupGate();
      final stuck = Completer<int>();
      unawaited(gate.tryRun(() => stuck.future));
      await gate.close(timeout: const Duration(milliseconds: 10));
      expect(await gate.tryRun(() async => 1), isNull);
      stuck.complete(1);
    });

    test('a job that throws frees it', () async {
      final gate = BackupGate();
      await expectLater(
        gate.tryRun<int>(() async => throw StateError('no')),
        throwsStateError,
      );
      expect(await gate.tryRun(() async => 1), 1);
    });
  });

  group('running a backup', () {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    late Directory dir;
    late Directory folderDir;
    late Directory temp;
    late Directory root;
    late _Folder folder;
    late AutoBackupStore store;
    late MemoryRecoveryKeyStore keys;
    late RecoveryKey key;
    late String dbKey;
    late AppDatabase db;
    late BackupService service;
    late PhotoKeys photoKeys;
    var now = DateTime.utc(2026, 11, 6, 10);

    setUp(() async {
      dir = Directory.systemTemp.createTempSync('usra_auto_run');
      folderDir = Directory(p.join(dir.path, 'chosen'))..createSync();
      temp = Directory(p.join(dir.path, 'tmp'))..createSync();
      root = Directory(p.join(dir.path, 'support'))..createSync();
      folder = _Folder(folderDir);
      key = RecoveryKey.generate();
      keys = MemoryRecoveryKeyStore(key);
      store = AutoBackupStore.memory(_on());
      dbKey = DatabaseKeyStore.generateKey();
      photoKeys = PhotoKeys.ready(PhotoCipher(PhotoCipher.generateKey()));
      db = AppDatabase(
        openEncryptedDatabase(File(p.join(root.path, 'usra.sqlite')), dbKey),
      );
      await db.customStatement('SELECT 1');
      service = BackupService(
        root: root,
        databaseName: 'usra.sqlite',
        deviceKey: dbKey,
        photoKeys: photoKeys,
        temporary: temp,
        folders: const ['attachments'],
        kdf: _testKdf,
        chunkSize: 4096,
      );
      now = DateTime.utc(2026, 11, 6, 10);
    });
    tearDown(() async {
      await db.close();
      dir.deleteSync(recursive: true);
    });

    AutoBackupRunner runner() => AutoBackupRunner(
      folders: folder,
      keys: keys,
      store: store,
      make: (key, at) =>
          service.create(db, key, appVersion: '1.0.0+1', now: at),
      discard: service.discardCreated,
      clock: () => now,
    );

    Iterable<String> whole() => folder.names.where((n) => n.endsWith('.usra'));

    test('lands one whole file, then says when and how big', () async {
      final result = await runner().run();
      expect(result.landed, isTrue);
      expect(result.settings.failure, isNull);
      final name = whole().single;
      expect(name, startsWith('usra-auto-$_tag-20261106-'));
      expect(folder.names, [name]);
      // Written under a temporary name, and renamed only once whole.
      expect(folder.writes.single, endsWith('.partial'));
      final size = File(p.join(folderDir.path, name)).lengthSync();
      expect(result.settings.lastSize, size);
      expect(result.settings.lastAt, now);
      expect(store.current.lastAt, now);
      // Nothing left on the phone (S11).
      expect(temp.listSync(), isEmpty);
    });

    test('the file restores with the recovery key', () async {
      final photo = File(p.join(root.path, 'attachments', 'a.jpg'))
        ..createSync(recursive: true)
        ..writeAsBytesSync(photoKeys.require.seal([1, 2, 3]));
      await runner().run();
      photo.deleteSync();
      final staged = await service.stage(
        File(p.join(folderDir.path, whole().single)),
        key,
        currentSchema: db.schemaVersion,
      );
      expect(staged.manifest.schemaVersion, db.schemaVersion);
      expect(staged.manifest.count('photos'), 1);
      await service.discardStaged();
    });

    test('the recovery key is never written next to the backup', () async {
      await runner().run();
      for (final entity in folderDir.listSync()) {
        expect(p.basename(entity.path), isNot(contains(key.digits)));
        final bytes = (entity as File).readAsBytesSync();
        final text = String.fromCharCodes(bytes);
        expect(text, isNot(contains(key.digits)));
        expect(text, isNot(contains(key.groups.first)));
      }
      expect(store.current.toJson().toString(), isNot(contains(key.digits)));
    });

    test('keeps the last 3 and leaves other files alone', () async {
      File(p.join(folderDir.path, 'usra-backup-2026-01-01.usra'))
          .writeAsStringSync('mine');
      File(p.join(folderDir.path, 'notes.txt')).writeAsStringSync('mine');
      for (var day = 1; day <= 5; day++) {
        now = DateTime.utc(2026, 11, day, 10);
        final result = await runner().run();
        expect(result.landed, isTrue);
      }
      final own = folder.names
          .where((n) => n.startsWith('usra-auto-'))
          .toList();
      expect(own, hasLength(3));
      expect(own.first, contains('20261103'));
      expect(folder.names, contains('usra-backup-2026-01-01.usra'));
      expect(folder.names, contains('notes.txt'));
    });

    group('atomic write', () {
      test('a copy cut short leaves only what was there before', () async {
        await runner().run();
        final before = folder.names;
        now = now.add(const Duration(days: 7));
        folder
          ..writeOnly = 10
          ..writeProblem = BackupFolderProblem.noSpace;
        final result = await runner().run();
        expect(result.landed, isFalse);
        expect(result.settings.failure, AutoBackupFailure.noSpace);
        expect(folder.names, before);
        expect(result.settings.lastAt, isNot(now));
      });

      test('a short write isn\'t taken for a whole file', () async {
        folder.writeOnly = 10;
        final result = await runner().run();
        expect(result.landed, isFalse);
        expect(result.settings.failure, AutoBackupFailure.failed);
        expect(whole(), isEmpty);
        expect(folder.names, isEmpty);
      });

      test('a rename that fails leaves no half file', () async {
        folder.renameProblem = BackupFolderProblem.failed;
        final result = await runner().run();
        expect(result.landed, isFalse);
        expect(folder.names, isEmpty);
      });

      test('killed mid-write: says so, and the next run cleans up', () async {
        await runner().run();
        final good = whole().single;
        // As the app would leave it: a half file and the "interrupted" mark
        // saved before it started. Nothing gets a chance to clean up.
        final partial = File(
          p.join(folderDir.path, 'usra-auto-$_tag-20261113-100000.partial'),
        )..writeAsStringSync('half');
        await store.save(
          store.current.copyWith(
            lastAttemptAt: now,
            failure: AutoBackupFailure.interrupted,
          ),
        );
        expect(whole(), [good]);

        now = now.add(const Duration(days: 7));
        final result = await runner().run();
        expect(result.landed, isTrue);
        expect(result.settings.failure, isNull);
        expect(partial.existsSync(), isFalse);
        expect(whole(), hasLength(2));
      });

      test('a leftover that won\'t delete doesn\'t stop backups', () async {
        File(p.join(folderDir.path, 'usra-auto-$_tag-20261001-100000.partial'))
            .writeAsStringSync('half');
        folder.deleteProblem = BackupFolderProblem.failed;
        final result = await runner().run();
        expect(result.landed, isTrue);
        expect(result.settings.failure, isNull);
      });

      test('a new backup survives a clock that was set ahead', () async {
        for (final year in [2030, 2031, 2032]) {
          now = DateTime.utc(year);
          await runner().run();
        }
        now = DateTime.utc(2026, 11, 6, 10);
        final result = await runner().run();
        expect(result.landed, isTrue);
        final names = whole().toList();
        expect(names, hasLength(3));
        expect(names.any((n) => n.contains('20261106')), isTrue);
      });

      test('another phone\'s half file is left alone', () async {
        final other = File(
          p.join(folderDir.path, 'usra-auto-ffffffff-20261113-100000.partial'),
        )..writeAsStringSync('half');
        await runner().run();
        expect(other.existsSync(), isTrue);
      });

      test('older backups only go once the new one is in', () async {
        for (var day = 1; day <= 3; day++) {
          now = DateTime.utc(2026, 11, day, 10);
          await runner().run();
        }
        expect(whole(), hasLength(3));
        now = DateTime.utc(2026, 11, 4, 10);
        folder.writeProblem = BackupFolderProblem.failed;
        await runner().run();
        expect(whole(), hasLength(3));
        expect(whole().first, contains('20261101'));
      });

      test('failing to delete old ones doesn\'t fail the backup', () async {
        for (var day = 1; day <= 3; day++) {
          now = DateTime.utc(2026, 11, day, 10);
          await runner().run();
        }
        now = DateTime.utc(2026, 11, 4, 10);
        folder.deleteProblem = BackupFolderProblem.failed;
        final result = await runner().run();
        expect(result.landed, isTrue);
        expect(result.settings.failure, isNull);
        expect(whole(), hasLength(4));
      });
    });

    group('what can go wrong', () {
      test('folder gone', () async {
        folder.inspectProblem = BackupFolderProblem.missing;
        final result = await runner().run();
        expect(result.landed, isFalse);
        expect(result.settings.failure, AutoBackupFailure.folderMissing);
        expect(store.current.failure, AutoBackupFailure.folderMissing);
        // Not even made: nothing was wasted, nothing left behind.
        expect(temp.listSync(), isEmpty);
      });

      test('folder gone part way', () async {
        folder.writeProblem = BackupFolderProblem.missing;
        final result = await runner().run();
        expect(result.settings.failure, AutoBackupFailure.folderMissing);
        expect(temp.listSync(), isEmpty);
      });

      test('no folder saved', () async {
        await store.save(store.current.copyWith(folder: null));
        final result = await runner().run();
        expect(result.settings.failure, AutoBackupFailure.folderMissing);
      });

      test('folder moved into iCloud: refused, nothing written', () async {
        folder.path = '/private/var/mobile/Library/Mobile Documents/com~apple~CloudDocs/B';
        final result = await runner().run();
        expect(result.landed, isFalse);
        expect(result.settings.failure, AutoBackupFailure.iCloudFolder);
        expect(folder.writes, isEmpty);
        expect(folder.names, isEmpty);
      });

      test('iOS says the folder is ubiquitous: refused too', () async {
        folder.ubiquitous = true;
        final result = await runner().run();
        expect(result.settings.failure, AutoBackupFailure.iCloudFolder);
        expect(folder.writes, isEmpty);
      });

      test('a stale bookmark is renewed and saved', () async {
        folder.renewedId = 'fresh';
        final result = await runner().run();
        expect(result.landed, isTrue);
        expect(result.settings.folder!.id, 'fresh');
        expect(result.settings.folder!.name, 'Backups');
      });

      test('no recovery key: nothing is made', () async {
        keys = MemoryRecoveryKeyStore();
        final result = await runner().run();
        expect(result.settings.failure, AutoBackupFailure.noRecoveryKey);
        expect(folder.writes, isEmpty);
      });

      test('phone locked before starting', () async {
        folder.protectedData = false;
        final result = await runner().run();
        expect(result.settings.failure, AutoBackupFailure.phoneLocked);
        expect(folder.writes, isEmpty);
      });

      test('phone locked part way: a photo can\'t be read', () async {
        final locked = AutoBackupRunner(
          folders: folder,
          keys: keys,
          store: store,
          make: (key, at) async {
            folder.protectedData = false;
            throw const FileSystemException(
              'open',
              'x',
              OSError('Operation not permitted', 1),
            );
          },
          discard: service.discardCreated,
          clock: () => now,
        );
        final result = await locked.run();
        expect(result.settings.failure, AutoBackupFailure.phoneLocked);
      });

      test('disk full while making the file', () async {
        final full = AutoBackupRunner(
          folders: folder,
          keys: keys,
          store: store,
          make: (key, at) async => throw const FileSystemException(
            'write',
            'x',
            OSError('No space left on device', 28),
          ),
          discard: service.discardCreated,
          clock: () => now,
        );
        final result = await full.run();
        expect(result.settings.failure, AutoBackupFailure.noSpace);
        expect(folder.names, isEmpty);
      });

      test('recognises each way of running out of space', () {
        expect(
          isOutOfSpace(const FileSystemException('w', 'x', OSError('', 28))),
          isTrue,
        );
        expect(
          isOutOfSpace(Exception('SqliteException(13): SQLITE_FULL')),
          isTrue,
        );
        expect(isOutOfSpace(Exception('database or disk is full')), isTrue);
        expect(isOutOfSpace(Exception('something else')), isFalse);
      });

      test('a backup missing photos is marked in its name', () async {
        final partial = AutoBackupRunner(
          folders: folder,
          keys: keys,
          store: store,
          make: (key, at) async {
            final made = await service.create(
              db,
              key,
              appVersion: '1.0.0+1',
              now: at,
            );
            return CreatedBackup(made.file, skippedPhotos: 2);
          },
          discard: service.discardCreated,
          clock: () => now,
        );
        final result = await partial.run();
        expect(result.settings.lastSkippedPhotos, 2);
        expect(whole().single, endsWith('-p.usra'));
      });

      test('errors are logged by type only, with no path or name', () async {
        final lines = <String>[];
        final output = Log.output;
        final release = Log.release;
        Log.output = lines.add;
        Log.release = false;
        addTearDown(() {
          Log.output = output;
          Log.release = release;
        });
        await store.save(
          store.current.copyWith(
            folder: const BackupFolder(
              id: 'content://secret-folder',
              name: 'Secret folder',
              onThisPhone: true,
            ),
          ),
        );
        folder.writeProblem = BackupFolderProblem.failed;
        await runner().run();
        expect(lines, isNotEmpty);
        for (final line in lines) {
          expect(line, isNot(contains('secret')));
          expect(line, isNot(contains('Secret')));
          expect(line, isNot(contains('.usra')));
          expect(line, isNot(contains(dir.path)));
        }
      });
    });
  });
}
