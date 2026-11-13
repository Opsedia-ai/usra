import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usra/core/sync/envelope.dart';
import 'package:usra/core/sync/hlc.dart';
import 'package:usra/core/sync/merge.dart';
import 'package:usra/core/sync/sync_engine.dart';
import 'package:usra/core/sync/sync_scheduler.dart';
import 'package:usra/core/sync/sync_transport.dart';

const kFamily = '0f000000-0000-4000-8000-00000000000f';

/// The server side of push_e2ee_records and sync_pull, in memory.
class FakeServer implements SyncTransport {
  final rows =
      <
        String,
        ({int revision, int keyVersion, Uint8List ct, bool deleted, int txid})
      >{};
  var _txid = 0;
  var enabled = true;
  var pushCalls = 0;
  var pullCalls = 0;
  int pageSize = 500;

  @override
  Future<PullPage> pull(PullRequest r) async {
    pullCalls++;
    if (!enabled) return const PullPage(ok: false, error: 'sync_disabled');
    final after = int.parse(r.afterTxid);
    final sorted = rows.entries.where((e) => e.value.txid > after).toList()
      ..sort((a, b) => a.value.txid.compareTo(b.value.txid));
    final page = sorted.take(pageSize).toList();
    return PullPage(
      ok: true,
      headSeq: 1,
      keyVersion: 1,
      records: [
        for (final e in page)
          (
            record: ServerRecord(
              syncId: e.key,
              revision: e.value.revision,
              keyVersion: e.value.keyVersion,
              ciphertext: e.value.ct,
              deleted: e.value.deleted,
            ),
            txid: '${e.value.txid}',
          ),
      ],
      recordsMore: sorted.length > page.length,
      afterTxid: page.isEmpty ? r.afterTxid : '${page.last.value.txid}',
      afterSync: page.isEmpty ? r.afterSync : page.last.key,
    );
  }

  @override
  Future<PushResponse> push({
    required String familyId,
    required int logSeq,
    required List<OutgoingRecord> records,
  }) async {
    pushCalls++;
    if (!enabled) return const PushResponse(ok: false, error: 'sync_disabled');
    expect(records.length, inInclusiveRange(1, 100));
    expect(
      records.fold<int>(0, (n, r) => n + r.ciphertext.length),
      lessThanOrEqualTo(2 * 1024 * 1024),
    );
    final results = <PushResult>[];
    for (final r in records) {
      final cur = rows[r.syncId];
      final have = cur?.revision ?? 0;
      if (have != r.expectedRevision) {
        results.add(
          PushResult(
            syncId: r.syncId,
            ok: false,
            error: 'revision_conflict',
            current: ServerRecord(
              syncId: r.syncId,
              revision: cur!.revision,
              keyVersion: cur.keyVersion,
              ciphertext: cur.ct,
              deleted: cur.deleted,
            ),
          ),
        );
        continue;
      }
      rows[r.syncId] = (
        revision: have + 1,
        keyVersion: r.keyVersion,
        ct: r.ciphertext,
        deleted: r.deleted,
        txid: ++_txid,
      );
      results.add(PushResult(syncId: r.syncId, ok: true, revision: have + 1));
    }
    return PushResponse(ok: true, headSeq: 1, results: results);
  }
}

/// A family of two parents with one key epoch.
class FakeFamily implements FamilySession {
  FakeFamily(this.deviceId, this.signingKey, this.keys, this.rk);

  @override
  final String deviceId;
  @override
  final SimpleKeyPair signingKey;
  final Map<String, SimplePublicKey> keys;
  final SecretKey rk;
  String? warning;

  @override
  String get familyId => kFamily;
  @override
  int get logSeq => 1;
  @override
  String get logHash => 'aGVhZA';
  @override
  int get keyVersion => 1;
  @override
  bool get canWrite => true;
  @override
  Future<SecretKey?> recordKey(int v) async => v == 1 ? rk : null;
  @override
  Future<SimplePublicKey?> signerKey(String id) async => keys[id];
  @override
  Future<FamilyCheck> absorb(PullPage page) async =>
      warning == null ? const FamilyCheck.ok() : FamilyCheck.stop(warning!);
  @override
  bool mayApply(RecordBody body, int keyVersion) => true;
}

/// One phone's records, in memory.
class MemoryStore implements SyncStore {
  MemoryStore(this.clock);

  final HlcClock clock;
  final records = <String, LocalRecord>{}; // by sync id
  final history = <String>{};
  final conflicts = <MergeConflict>[];
  var _cursor = (afterSeq: 0, afterTxid: '0', afterSync: null as String?);
  final _rnd = Random(7);

  String _v4() {
    String h(int n) =>
        List.generate(n, (_) => _rnd.nextInt(16).toRadixString(16)).join();
    return '${h(8)}-${h(4)}-4${h(3)}-8${h(3)}-${h(12)}';
  }

  LocalRecord? byId(String recordId) =>
      records.values.where((r) => r.recordId == recordId).firstOrNull;

  /// A local edit of [values] (group name to value) on record [recordId].
  void edit(
    String recordId,
    String type,
    Map<String, Object?> values, {
    bool historyRecord = false,
  }) {
    final entry = records.entries
        .where((e) => e.value.recordId == recordId)
        .firstOrNull;
    final syncId = entry?.key ?? _v4();
    final old = entry?.value;
    final groups = {...?old?.groups};
    if (old == null) groups[deletedGroup] = GroupEntry(false, clock.tick());
    for (final v in values.entries) {
      groups[v.key] = GroupEntry(v.value, clock.tick());
    }
    records[syncId] = LocalRecord(
      recordId: recordId,
      type: type,
      revision: old?.revision ?? 0,
      groups: groups,
      changedGroups: {
        ...?old?.changedGroups,
        ...values.keys,
        if (old == null) deletedGroup,
      },
    );
    if (historyRecord) history.add(syncId);
  }

  Map<String, Object?> visible(String recordId) {
    final r = byId(recordId)!;
    if (isDeleted(r.groups)) return {deletedGroup: true};
    return {for (final e in r.groups.entries) e.key: e.value.value};
  }

  @override
  Future<({int afterSeq, String afterTxid, String? afterSync})> cursor(
    String f,
  ) async => _cursor;

  @override
  Future<void> saveCursor(
    String f, {
    required int afterSeq,
    required String afterTxid,
    String? afterSync,
  }) async {
    _cursor = (afterSeq: afterSeq, afterTxid: afterTxid, afterSync: afterSync);
  }

  @override
  Future<LocalRecord?> record(String f, String syncId) async => records[syncId];

  @override
  Future<List<LocalChange>> pending(
    String f, {
    required bool includeHistory,
  }) async => [
    for (final e in records.entries)
      if (e.value.changedGroups.isNotEmpty &&
          (includeHistory || !history.contains(e.key)))
        LocalChange(
          syncId: e.key,
          record: e.value,
          history: history.contains(e.key),
        ),
  ];

  @override
  Future<void> applyMerged(
    String f, {
    required String syncId,
    required String recordId,
    required String type,
    required int revision,
    required Groups groups,
    required Set<String> stillChanged,
    required Groups held,
    required List<MergeConflict> conflicts,
  }) async {
    records[syncId] = LocalRecord(
      recordId: recordId,
      type: type,
      revision: revision,
      groups: groups,
      changedGroups: stillChanged,
    );
    this.conflicts.addAll(conflicts);
  }

  @override
  Future<void> markPushed(String f, LocalChange change, int revision) async {
    final now = records[change.syncId]!;
    records[change.syncId] = LocalRecord(
      recordId: now.recordId,
      type: now.type,
      revision: revision,
      groups: now.groups,
      changedGroups: {
        for (final g in now.changedGroups)
          if (now.groups[g] != change.record.groups[g]) g,
      },
    );
  }
}

class Phone {
  Phone(this.store, this.family, this.engine);
  final MemoryStore store;
  final FakeFamily family;
  final SyncEngine engine;
  Future<SyncOutcome> sync([SyncReason reason = SyncReason.open]) =>
      engine.sync(family, reason);
}

void main() {
  late FakeServer server;
  late Phone mona;
  late Phone ahmed;
  var now = DateTime.utc(2026, 11, 13, 9);

  setUp(() async {
    now = DateTime.utc(2026, 11, 13, 9);
    server = FakeServer();
    final rk = await deriveRecordKey(List.filled(32, 3), kFamily);
    final kMona = await Ed25519().newKeyPairFromSeed(List.filled(32, 1));
    final kAhmed = await Ed25519().newKeyPairFromSeed(List.filled(32, 2));
    final keys = {
      'da000000-0000-4000-8000-0000000000a1': await kMona.extractPublicKey(),
      'db000000-0000-4000-8000-0000000000b1': await kAhmed.extractPublicKey(),
    };
    Phone phone(String device, SimpleKeyPair k, int skewMs) {
      final clock = HlcClock(
        now: () => now.add(Duration(milliseconds: skewMs)),
      );
      final store = MemoryStore(clock);
      return Phone(
        store,
        FakeFamily(device, k, keys, rk),
        SyncEngine(
          transport: server,
          store: store,
          clock: clock,
          isClinical: (type, group) => type == 'medicine' && group == 'dose',
          now: () => now,
        ),
      );
    }

    mona = phone('da000000-0000-4000-8000-0000000000a1', kMona, 0);
    ahmed = phone('db000000-0000-4000-8000-0000000000b1', kAhmed, 3);
  });

  test('a vaccine ticked by one parent reaches the other', () async {
    mona.store.edit('r-vax', 'medical_event', {
      'given': {'on': '2026-11-13', 'dose': 1},
    });
    final out = await mona.sync(SyncReason.edits);
    expect(out.pushed, 1);
    expect(out.pushCalls, 1);
    final pulled = await ahmed.sync();
    expect(pulled.pulled, 1);
    expect(ahmed.store.visible('r-vax')['given'], {
      'on': '2026-11-13',
      'dose': 1,
    });
  });

  test('both parents edit different groups offline; both edits survive on both phones', () async {
    mona.store.edit('r-med', 'medicine', {
      'name': 'Sample syrup',
      'dose': '5 ml',
    });
    await mona.sync();
    await ahmed.sync();
    now = now.add(const Duration(minutes: 1));
    mona.store.edit('r-med', 'medicine', {'name': 'Sample syrup forte'});
    ahmed.store.edit('r-med', 'medicine', {'dose': '7.5 ml'});
    await mona.sync();
    await ahmed.sync(); // conflict on revision, merges, pushes on top
    await mona.sync();
    expect(mona.store.visible('r-med'), ahmed.store.visible('r-med'));
    expect(mona.store.visible('r-med')['name'], 'Sample syrup forte');
    expect(mona.store.visible('r-med')['dose'], '7.5 ml');
    expect(mona.store.conflicts, isEmpty);
    expect(ahmed.store.conflicts, isEmpty);
  });

  test('both change the same dose: the later one wins everywhere and the loser sees both', () async {
    mona.store.edit('r-med', 'medicine', {'dose': '5 ml'});
    await mona.sync();
    await ahmed.sync();
    now = now.add(const Duration(minutes: 1));
    mona.store.edit('r-med', 'medicine', {'dose': '6 ml'});
    now = now.add(const Duration(seconds: 1));
    ahmed.store.edit('r-med', 'medicine', {'dose': '7.5 ml'});
    await ahmed.sync();
    await mona.sync();
    await ahmed.sync();
    expect(mona.store.visible('r-med')['dose'], '7.5 ml');
    expect(ahmed.store.visible('r-med')['dose'], '7.5 ml');
    expect(mona.store.conflicts.single.lost.value, '6 ml');
  });

  test('a delete wins over an older concurrent edit', () async {
    mona.store.edit('r-card', 'insurance_card', {
      'card': {'insurer': 'Sample'},
    });
    await mona.sync();
    await ahmed.sync();
    ahmed.store.edit('r-card', 'insurance_card', {
      'card': {'insurer': 'Sample 2'},
    });
    now = now.add(const Duration(minutes: 1));
    mona.store.edit('r-card', 'insurance_card', {deletedGroup: true});
    await mona.sync();
    await ahmed.sync();
    await mona.sync();
    expect(mona.store.visible('r-card'), {deletedGroup: true});
    expect(ahmed.store.visible('r-card'), {deletedGroup: true});
  });

  test('250 edits go up in three calls of at most 100', () async {
    for (var i = 0; i < 250; i++) {
      mona.store.edit('r-$i', 'doctor', {'name': 'Doctor $i'});
    }
    final out = await mona.sync(SyncReason.edits);
    expect(out.pushed, 250);
    expect(out.pushCalls, 3);
    server.pageSize = 100;
    final pulled = await ahmed.sync();
    expect(pulled.pulled, 250);
  });

  test('an edits run neither pulls nor sends history bundles', () async {
    mona.store.edit('r-doses', 'dose_bundle', {
      '01930000-0000-7000-8000-000000000001': 'taken',
    }, historyRecord: true);
    mona.store.edit('r-doc', 'doctor', {'name': 'Doctor'});
    final out = await mona.sync(SyncReason.edits);
    expect(server.pullCalls, 0);
    expect(out.pushed, 1);
    final later = await mona.sync(SyncReason.history);
    expect(later.pushed, 1);
  });

  test(
    'a record changed on the server is refused and the family stops',
    () async {
      mona.store.edit('r-1', 'doctor', {'name': 'Doctor'});
      await mona.sync();
      final key = server.rows.keys.single;
      final row = server.rows[key]!;
      server.rows[key] = (
        revision: row.revision,
        keyVersion: row.keyVersion,
        ct: Uint8List.fromList(row.ct)..[100] ^= 1,
        deleted: row.deleted,
        txid: row.txid,
      );
      final out = await ahmed.sync();
      expect(out.status, SyncStatus.warning);
      expect(ahmed.store.records, isEmpty);
      expect(
        (await ahmed.store.cursor(kFamily)).afterTxid,
        '0',
        reason: 'the cursor stays before it',
      );
    },
  );

  test('nothing is sent while the server switch is off', () async {
    server.enabled = false;
    mona.store.edit('r-1', 'doctor', {'name': 'Doctor'});
    expect((await mona.sync()).status, SyncStatus.disabled);
    expect((await mona.sync(SyncReason.edits)).status, SyncStatus.disabled);
    expect(server.rows, isEmpty);
  });

  test(
    'a family security warning stops the sync before anything is applied',
    () async {
      mona.store.edit('r-1', 'doctor', {'name': 'Doctor'});
      await mona.sync();
      ahmed.family.warning = 'fork';
      expect((await ahmed.sync()).status, SyncStatus.warning);
      expect(ahmed.store.records, isEmpty);
    },
  );

  group('scheduler', () {
    late List<_FakeTimer> timers;
    late List<SyncReason> runs;
    late SyncScheduler s;

    setUp(() {
      timers = [];
      runs = [];
      s = SyncScheduler(
        run: (r) async => runs.add(r),
        random: Random(1),
        timer: (d, cb) {
          final t = _FakeTimer(d, cb);
          timers.add(t);
          return t;
        },
      );
    });

    Future<void> settle() => Future<void>.delayed(Duration.zero);

    test('opening syncs at once; no timer runs while nothing waits', () async {
      s.appOpened();
      await settle();
      expect(runs, [SyncReason.open]);
      expect(timers, isEmpty);
    });

    test('edits are debounced 20 seconds and restart the wait', () async {
      s.edited();
      s.edited();
      expect(
        timers.where((t) => t.active).single.delay,
        const Duration(seconds: 20),
      );
      timers.last.fire();
      await settle();
      expect(runs, [SyncReason.edits]);
    });

    test(
      'going to the background sends waiting edits and stops every timer',
      () async {
        s.edited();
        s.edited(history: true);
        s.appPaused();
        await settle();
        expect(runs, [SyncReason.edits]);
        expect(timers.every((t) => !t.active), isTrue);
        s.edited(history: true);
        expect(
          timers.where((t) => t.active),
          isEmpty,
          reason: 'no timer in the background',
        );
      },
    );

    test('history waits a random 10 to 40 minutes', () async {
      s.edited(history: true);
      final t = timers.single;
      expect(t.delay.inMinutes, inInclusiveRange(10, 40));
      s.edited(history: true);
      expect(timers.length, 1, reason: 'one wait per batch');
      t.fire();
      await settle();
      expect(runs, [SyncReason.history]);
    });

    test('runs never overlap; triggers during a run queue one more', () async {
      final gate = Completer<void>();
      final order = <SyncReason>[];
      final s2 = SyncScheduler(
        run: (r) async {
          order.add(r);
          if (order.length == 1) await gate.future;
        },
        timer: (d, cb) => _FakeTimer(d, cb),
      );
      s2
        ..appOpened()
        ..refresh()
        ..appOpened();
      await settle();
      expect(order, [SyncReason.open]);
      gate.complete();
      await settle();
      await settle();
      expect(order, [SyncReason.open, SyncReason.manual]);
    });
  });
}

class _FakeTimer implements Timer {
  _FakeTimer(this.delay, this._callback);
  final Duration delay;
  final void Function() _callback;
  bool _active = true;

  void fire() {
    if (!_active) return;
    _active = false;
    _callback();
  }

  @override
  void cancel() => _active = false;

  @override
  bool get isActive => _active;
  bool get active => _active;

  @override
  int get tick => 0;
}
