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

  /// Writes the whole file with this byte changed: a provider's fault.
  int? corruptAt;
  bool ubiquitous = false;
  Future<void> Function()? onInspect;
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
    await onInspect?.call();
    return FolderStatus(
      path: path ?? dir.path,
      isUbiquitous: ubiquitous,
      renewedId: renewedId,
    );
  }

  @override
  Future<void> write(String id, String sourcePath, String name) async {
    writes.add(name);
    final target = File(p.join(dir.path, name));
    final bytes = await File(sourcePath).readAsBytes();
    if (writeOnly case final only?) {
      await target.writeAsBytes(bytes.sublist(0, only));
      _throw(writeProblem);
      return;
    }
    _throw(writeProblem);
    if (corruptAt case final at?) bytes[at] ^= 0xff;
    await target.writeAsBytes(bytes);
  }

  @override
  Future<int> verify(String id, String sourcePath, String name) async {
    final landed = await File(p.join(dir.path, name)).readAsBytes();
    final original = await File(sourcePath).readAsBytes();
    if (landed.length != original.length) {
      throw const BackupFolderException(BackupFolderProblem.failed);
    }
    for (var i = 0; i < landed.length; i++) {
      if (landed[i] != original[i]) {
        throw const BackupFolderException(BackupFolderProblem.failed);
      }
    }
    return landed.length;
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

/// Retires the store once the copy is done, as a wipe overtaking a slow run
/// would.
class _RetiringFolder extends _Folder {
  _RetiringFolder(super.dir, this.onWritten);

  final void Function() onWritten;

  @override
  Future<int> verify(String id, String sourcePath, String name) async {
    final size = await super.verify(id, sourcePath, name);
    onWritten();
    return size;
  }
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
      expect(backupsToDelete(names, _tag, now: DateTime.utc(2026, 12)), [
        named(2),
        named(1),
      ]);
      expect(
        backupsToDelete(names.take(3), _tag, now: DateTime.utc(2026, 12)),
        isEmpty,
      );
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
      expect(backupsToDelete(names, _tag, now: DateTime.utc(2026, 12)), [
        named(1),
      ]);
    });

    test('backups missing photos can\'t push out the last whole one', () {
      final names = [
        named(1),
        named(2),
        named(3, complete: false),
        named(4, complete: false),
        named(5, complete: false),
      ];
      expect(backupsToDelete(names, _tag, now: DateTime.utc(2026, 12)), [
        named(1),
      ]);
      expect(
        backupsToDelete(
          [...names, named(6, complete: false)],
          _tag,
          now: DateTime.utc(2026, 12),
        ),
        [named(3, complete: false), named(1)],
      );
    });

    test('files dated ahead of the clock go before real ones', () {
      final future = [
        for (final year in [2030, 2031, 2032])
          AutoBackupFileName.make(_tag, DateTime.utc(year)),
      ];
      final clock = DateTime.utc(2026, 11, 6, 10, 30, 5);
      // The new one stays, and the oldest of the wrong ones goes.
      expect(backupsToDelete([...future, named(6)], _tag, now: clock), [
        future.first,
      ]);
      // Real ones build up, and the wrong ones don't outrank them.
      expect(
        backupsToDelete(
          [...future, named(1), named(2), named(3)],
          _tag,
          now: clock,
        ),
        unorderedEquals(future),
      );
    });

    test('held backups aren\'t touched or counted', () {
      final names = [for (var d = 1; d <= 7; d++) named(d)];
      final held = names.take(3).toList();
      expect(
        backupsToDelete(names, _tag, now: DateTime.utc(2026, 12), held: held),
        [named(4)],
      );
    });

    test('only this phone\'s half-written files are leftovers', () {
      final mine = AutoBackupFileName.partialOf(named(1));
      final other = AutoBackupFileName.partialOf(named(1, tag: 'ffffffff'));
      expect(mine, 'usra-auto-abcd1234-20261101-103005.partial');
      const renamed = 'usra-auto-abcd1234-20261101-103005 (1).partial';
      expect(
        partialsToDelete([mine, other, renamed, 'x.partial', named(2)], _tag),
        [mine, renamed],
      );
    });

    test('a new tag is 8 hex characters', () {
      expect(newBackupTag(Random(1)), matches(RegExp(r'^[0-9a-f]{8}$')));
    });
  });

  group('what counts as a drop in content', () {
    const before = {
      'people': 4,
      'records': 100,
      'photos': 50,
      backupMissingPhotosCount: 0,
    };

    test('nothing to compare yet, or the same or more, isn\'t one', () {
      expect(hasContentDropped(null, before), isFalse);
      expect(hasContentDropped(before, const {}), isFalse);
      expect(hasContentDropped(before, before), isFalse);
      expect(hasContentDropped(before, {...before, 'records': 200}), isFalse);
    });

    test('any person gone is', () {
      expect(hasContentDropped(before, {...before, 'people': 3}), isTrue);
    });

    test('tidying up a few records or photos isn\'t', () {
      expect(hasContentDropped(before, {...before, 'records': 98}), isFalse);
      expect(hasContentDropped(before, {...before, 'photos': 48}), isFalse);
      // 3 gone but under 10%.
      expect(hasContentDropped(before, {...before, 'records': 97}), isFalse);
      // 10% gone but under 3.
      expect(
        hasContentDropped({...before, 'photos': 10}, {...before, 'photos': 8}),
        isFalse,
      );
    });

    test('3 or more and at least 10% is', () {
      expect(hasContentDropped(before, {...before, 'records': 90}), isTrue);
      expect(hasContentDropped(before, {...before, 'photos': 45}), isTrue);
      expect(
        hasContentDropped(
          {...before, 'records': 10},
          {...before, 'records': 7},
        ),
        isTrue,
      );
    });

    test('a photo row with no file is, until accepted', () {
      final missing = {...before, backupMissingPhotosCount: 1};
      expect(hasContentDropped(before, missing), isTrue);
      expect(hasContentDropped(missing, missing), isFalse);
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

    test('a restore clears the drop notice and keeps what\'s expected', () {
      final at = DateTime.utc(2026, 11, 6);
      final after = _on(failure: AutoBackupFailure.noSpace)
          .copyWith(
            baselineCounts: const {'people': 4},
            latestCounts: const {'people': 1},
            contentDropped: true,
            heldBackups: const ['a.usra'],
          )
          .afterRestore(at);
      expect(after.contentDropped, isFalse);
      expect(after.heldBackups, isEmpty);
      expect(after.baselineCounts, {'people': 4});
      // Only a pause turns anything back on; other failures stay as they are.
      expect(after.failure, AutoBackupFailure.noSpace);
      expect(after.enabledAt, isNull);
    });

    test('a restore ends a pause', () {
      final at = DateTime.utc(2026, 11, 6);
      final after = _on(failure: AutoBackupFailure.pausedForRecovery)
          .copyWith(enabled: false)
          .afterRestore(at);
      expect(after.enabled, isTrue);
      expect(after.enabledAt, at);
      expect(after.failure, isNull);
    });

    test('a damaged file means off, and says so, not a crash', () async {
      File(p.join(dir.path, AutoBackupStore.fileName)).writeAsStringSync('{{');
      final store = await AutoBackupStore.open(dir);
      expect(store.current.enabled, isFalse);
      expect(store.unreadable, isTrue);
    });

    test('nothing to read isn\'t unreadable', () async {
      expect((await AutoBackupStore.open(dir)).unreadable, isFalse);
    });

    test('a retired store writes nothing back', () async {
      final store = await AutoBackupStore.open(dir);
      await store.save(_on());
      File(p.join(dir.path, AutoBackupStore.fileName)).deleteSync();
      store.retire();
      await store.save(_on(failure: AutoBackupFailure.failed));
      expect(dir.listSync(), isEmpty);
      expect(store.current.failure, isNull);
    });

    test('content counts and held backups survive a restart', () async {
      final store = await AutoBackupStore.open(dir);
      await store.save(
        _on().copyWith(
          baselineCounts: const {'people': 3},
          latestCounts: const {'people': 2},
          contentDropped: true,
          heldBackups: const ['a.usra'],
        ),
      );
      final reopened = (await AutoBackupStore.open(dir)).current;
      expect(reopened.baselineCounts, {'people': 3});
      expect(reopened.latestCounts, {'people': 2});
      expect(reopened.contentDropped, isTrue);
      expect(reopened.heldBackups, ['a.usra']);
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
        folders: const ['attachments', 'insurance_cards', 'medicines'],
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

      test(
        'a file changed on the way in fails, and pushes nothing out',
        () async {
          for (var day = 1; day <= 3; day++) {
            now = DateTime.utc(2026, 11, day, 10);
            await runner().run();
          }
          final good = whole().toList();
          now = DateTime.utc(2026, 11, 4, 10);
          folder.corruptAt = 100;
          final result = await runner().run();
          expect(result.landed, isFalse);
          expect(result.settings.failure, AutoBackupFailure.failed);
          expect(result.settings.lastAt, DateTime.utc(2026, 11, 3, 10));
          expect(folder.names, good);
        },
      );

      test('reports the size that landed', () async {
        final result = await runner().run();
        final file = File(p.join(folderDir.path, whole().single));
        expect(result.settings.lastSize, file.lengthSync());
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

    group('when the content drops', () {
      /// A run whose backup holds [counts], as the real one reports them.
      Future<AutoBackupResult> runWith(Map<String, int> counts, {int day = 1}) {
        now = DateTime.utc(2026, 11, day, 10);
        return AutoBackupRunner(
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
            return CreatedBackup(made.file, counts: counts);
          },
          discard: service.discardCreated,
          clock: () => now,
        ).run();
      }

      const full = {'people': 4, 'records': 100, 'photos': 50};
      const shrunk = {'people': 1, 'records': 2, 'photos': 0};

      Future<List<String>> threeGood() async {
        for (var day = 1; day <= 3; day++) {
          await runWith(full, day: day);
        }
        return whole().toList();
      }

      test('it lands, older ones stay, and it says so', () async {
        final good = await threeGood();
        final result = await runWith(shrunk, day: 4);
        expect(result.landed, isTrue);
        expect(result.settings.failure, isNull);
        expect(result.settings.contentDropped, isTrue);
        expect(result.settings.heldBackups, good);
        expect(whole(), hasLength(4));
        // What's expected doesn't move down.
        expect(result.settings.baselineCounts, full);
        expect(result.settings.latestCounts, shrunk);
      });

      test(
        'run after run can\'t push out the good ones, and stays bounded',
        () async {
          final good = await threeGood();
          for (var day = 4; day <= 12; day++) {
            final result = await runWith(shrunk, day: day);
            expect(result.settings.contentDropped, isTrue);
            expect(result.settings.heldBackups, good);
          }
          final names = whole().toList();
          expect(names, containsAll(good));
          expect(names, hasLength(good.length + autoBackupKeep));
        },
      );

      test('restoring an older backup: the next due run holds', () async {
        final good = await threeGood();
        // As after `restoreAndRestart`, with far fewer records than expected.
        final result = await runWith(const {
          'people': 4,
          'records': 40,
          'photos': 50,
        }, day: 10);
        expect(result.settings.contentDropped, isTrue);
        expect(whole(), containsAll(good));
      });

      test('a missing database: a new one with one person holds', () async {
        // `prepareDatabaseFile` calls a missing file "ready", so nothing
        // pauses this. The family's first new person is what starts a run.
        final good = await threeGood();
        final result = await runWith(const {
          'people': 1,
          'records': 0,
          'photos': 0,
        }, day: 10);
        expect(result.settings.contentDropped, isTrue);
        expect(whole(), containsAll(good));
      });

      test(
        'a whole photo folder gone is found, and named incomplete',
        () async {
          await db.addProfile('a');
          final person = await db.addProfile('b');
          final event = await db.addEvent(
            profileId: person,
            type: 'visit',
            occurredAt: DateTime.utc(2026),
          );
          await db.addAttachments(event, const ['attachments/a.jpg']);
          final photo = File(p.join(root.path, 'attachments', 'a.jpg'))
            ..createSync(recursive: true)
            ..writeAsBytesSync(photoKeys.require.seal([1, 2, 3]));
          final first = await runner().run();
          expect(first.settings.latestCounts!['photos'], 1);
          expect(first.settings.latestCounts![backupMissingPhotosCount], 0);
          expect(whole().single, isNot(endsWith('-p.usra')));

          photo.parent.deleteSync(recursive: true);
          now = now.add(const Duration(days: 7));
          final second = await runner().run();
          expect(second.landed, isTrue);
          expect(second.settings.latestCounts![backupMissingPhotosCount], 1);
          expect(second.settings.contentDropped, isTrue);
          expect(whole().where((n) => n.endsWith('-p.usra')), hasLength(1));
          expect(whole(), hasLength(2));
        },
      );

      test('an attachment row with no file is found too', () async {
        final person = await db.addProfile('a');
        final event = await db.addEvent(
          profileId: person,
          type: 'visit',
          occurredAt: DateTime.utc(2026),
        );
        await db.addAttachments(event, const ['attachments/never.jpg']);
        final result = await runner().run();
        expect(result.settings.latestCounts![backupMissingPhotosCount], 1);
        expect(whole().single, endsWith('-p.usra'));
      });

      group('photos other tables point at', () {
        void photoFile(String path) =>
            (File(p.join(root.path, path))..createSync(recursive: true))
                .writeAsBytesSync(photoKeys.require.seal([1, 2, 3]));

        Future<String> person() => db.addProfile('a');

        test('the cards folder gone: 3 of 43 is under the share, and still '
            'found', () async {
          final who = await person();
          final event = await db.addEvent(
            profileId: who,
            type: 'visit',
            occurredAt: DateTime.utc(2026),
          );
          final attached = [for (var i = 0; i < 40; i++) 'attachments/$i.jpg'];
          await db.addAttachments(event, attached);
          attached.forEach(photoFile);
          for (final path in [
            'insurance_cards/f.jpg',
            'insurance_cards/b.jpg',
            'insurance_cards/c.jpg',
          ]) {
            photoFile(path);
          }
          await db.saveInsuranceCard(
            profileId: who,
            label: 'one',
            frontPhoto: 'insurance_cards/f.jpg',
            backPhoto: 'insurance_cards/b.jpg',
          );
          await db.saveInsuranceCard(
            profileId: who,
            label: 'two',
            frontPhoto: 'insurance_cards/c.jpg',
          );
          final first = await runner().run();
          expect(first.settings.latestCounts!['photos'], 43);
          final good = whole().single;
          expect(good, isNot(endsWith('-p.usra')));

          Directory(p.join(root.path, 'insurance_cards'))
              .deleteSync(recursive: true);
          now = now.add(const Duration(days: 7));
          final second = await runner().run();
          expect(second.settings.latestCounts!['photos'], 40);
          expect(second.settings.latestCounts![backupMissingPhotosCount], 3);
          expect(second.settings.contentDropped, isTrue);
          expect(second.settings.heldBackups, [good]);
          expect(whole().where((n) => n.endsWith('-p.usra')), hasLength(1));
        });

        test('medicine and prescription photos are in JSON lists', () async {
          final who = await person();
          await db.saveMedicine(
            profileId: who,
            name: 'x',
            startOn: DateTime.utc(2026),
            photos: const ['medicines/m.jpg', 'medicines/n.jpg'],
          );
          await db.savePrescription(
            profileId: who,
            prescribedOn: DateTime.utc(2026),
            photos: const ['medicines/r.jpg'],
            items: const [PrescriptionItemInput(name: 'x')],
          );
          photoFile('medicines/n.jpg');
          final result = await runner().run();
          expect(result.settings.latestCounts![backupMissingPhotosCount], 2);
          expect(whole().single, endsWith('-p.usra'));
        });

        test('all there: nothing missing, and named complete', () async {
          final who = await person();
          await db.saveMedicine(
            profileId: who,
            name: 'x',
            startOn: DateTime.utc(2026),
            photos: const ['medicines/m.jpg'],
          );
          photoFile('medicines/m.jpg');
          final result = await runner().run();
          expect(result.settings.latestCounts![backupMissingPhotosCount], 0);
          expect(whole().single, isNot(endsWith('-p.usra')));
        });

        test('deleted rows and a damaged list don\'t count', () async {
          final who = await person();
          final medicine = await db.saveMedicine(
            profileId: who,
            name: 'x',
            startOn: DateTime.utc(2026),
            photos: const ['medicines/gone.jpg'],
          );
          await db.customStatement(
            'UPDATE medicines SET deleted_at = 1 WHERE id = ?',
            [medicine],
          );
          await db.saveMedicine(
            profileId: who,
            name: 'y',
            startOn: DateTime.utc(2026),
          );
          await db.customStatement(
            "UPDATE medicines SET photos_json = 'not json' WHERE name = 'y'",
          );
          final result = await runner().run();
          expect(result.landed, isTrue);
          expect(result.settings.latestCounts![backupMissingPhotosCount], 0);
        });
      });

      test('back to normal: the hold clears by itself', () async {
        await threeGood();
        await runWith(shrunk, day: 4);
        final result = await runWith(full, day: 5);
        expect(result.settings.contentDropped, isFalse);
        expect(result.settings.heldBackups, isEmpty);
        expect(whole(), hasLength(autoBackupKeep));
      });

      test(
        'once accepted, the new normal applies and old ones can go',
        () async {
          await threeGood();
          await runWith(shrunk, day: 4);
          // What "I deleted them on purpose" does.
          await store.save(
            store.current.copyWith(
              baselineCounts: store.current.latestCounts,
              contentDropped: false,
              heldBackups: const [],
            ),
          );
          final result = await runWith(shrunk, day: 5);
          expect(result.settings.contentDropped, isFalse);
          expect(whole(), hasLength(autoBackupKeep));
        },
      );

      test(
        'restoring something smaller is flagged again at the next run',
        () async {
          final good = await threeGood();
          await runWith(shrunk, day: 4);
          await store.save(store.current.afterRestore(now));
          expect(store.current.contentDropped, isFalse);
          final result = await runWith(shrunk, day: 5);
          expect(result.settings.contentDropped, isTrue);
          expect(whole(), containsAll(good));
        },
      );

      test('the first backup has nothing to compare with', () async {
        final result = await runWith(shrunk);
        expect(result.settings.contentDropped, isFalse);
        expect(result.settings.baselineCounts, shrunk);
      });
    });

    group('a run outlived by a restore or wipe', () {
      late Completer<void> hold;

      AutoBackupRunner slow() => AutoBackupRunner(
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
          await hold.future;
          return made;
        },
        discard: service.discardCreated,
        clock: () => now,
      );

      setUp(() => hold = Completer<void>());

      test('stops: nothing lands, and no settings come back', () async {
        final file = Directory(p.join(dir.path, 'settings'))..createSync();
        store = await AutoBackupStore.open(file);
        await store.save(_on());
        final running = slow().run();
        await Future<void>.delayed(const Duration(milliseconds: 50));

        store.retire();
        for (final entity in file.listSync()) {
          entity.deleteSync();
        }
        hold.complete();
        final result = await running;

        expect(result.landed, isFalse);
        expect(folder.writes, isEmpty);
        expect(file.listSync(), isEmpty);
        expect(temp.listSync(), isEmpty);
      });

      test(
        'retired during the copy: the file goes, and nothing is pruned',
        () async {
          await runner().run();
          final retiring = _RetiringFolder(folderDir, () => store.retire());
          now = now.add(const Duration(days: 7));
          final result = await AutoBackupRunner(
            folders: retiring,
            keys: keys,
            store: store,
            make: (key, at) =>
                service.create(db, key, appVersion: '1.0.0+1', now: at),
            discard: service.discardCreated,
            clock: () => now,
          ).run();
          expect(result.landed, isFalse);
          expect(whole(), hasLength(1));
          expect(folder.names.where((n) => n.endsWith('.partial')), isEmpty);
        },
      );
    });

    group('settings changed during a run', () {
      AutoBackupRunner changing(
        AutoBackupSettings Function(AutoBackupSettings) c,
      ) => AutoBackupRunner(
        folders: folder,
        keys: keys,
        store: store,
        make: (key, at) async {
          await store.save(c(store.current));
          return service.create(db, key, appVersion: '1.0.0+1', now: at);
        },
        discard: service.discardCreated,
        clock: () => now,
      );

      test('a new frequency isn\'t overwritten', () async {
        final result = await changing(
          (s) => s.copyWith(frequency: BackupFrequency.daily),
        ).run();
        expect(result.landed, isTrue);
        expect(store.current.frequency, BackupFrequency.daily);
      });

      test('a new folder isn\'t overwritten', () async {
        const other = BackupFolder(id: 'other', name: 'O', onThisPhone: true);
        await changing((s) => s.copyWith(folder: other)).run();
        expect(store.current.folder!.id, 'other');
        expect(store.current.lastAt, now);
      });

      test(
        'a renewed bookmark doesn\'t replace a folder chosen since',
        () async {
          const other = BackupFolder(id: 'other', name: 'O', onThisPhone: true);
          folder
            ..renewedId = 'fresh'
            ..onInspect = () =>
                store.save(store.current.copyWith(folder: other));
          await runner().run();
          expect(store.current.folder!.id, 'other');
        },
      );

      test('turned off during a run stays off', () async {
        await changing((s) => s.copyWith(enabled: false)).run();
        expect(store.current.enabled, isFalse);
      });
    });

    group('what can go wrong', () {
      test(
        'the folder moves into iCloud while the file is being made',
        () async {
          folder.writeProblem = BackupFolderProblem.iCloud;
          final result = await runner().run();
          expect(result.landed, isFalse);
          expect(result.settings.failure, AutoBackupFailure.iCloudFolder);
          expect(folder.names, isEmpty);
        },
      );

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
