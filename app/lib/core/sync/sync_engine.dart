import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'envelope.dart';
import 'hlc.dart';
import 'merge.dart';
import 'sync_scheduler.dart';
import 'sync_transport.dart';

/// What the engine needs from the family layer: the verified family log,
/// keys and the reader rules that depend on them (docs/sync-design.md
/// sections 6, 7 and 12). Built in a later PR; tests use a fake.
abstract interface class FamilySession {
  String get familyId;

  /// This phone's device id and Ed25519 signing key.
  String get deviceId;
  SimpleKeyPair get signingKey;

  /// The verified log head this phone writes at.
  int get logSeq;
  String get logHash;

  /// The current key epoch, the one every write uses.
  int get keyVersion;

  /// `RK_v`, or null when this phone doesn't hold epoch [keyVersion] yet.
  Future<SecretKey?> recordKey(int keyVersion);

  /// The Ed25519 key of a device in the verified log, or null.
  Future<SimplePublicKey?> signerKey(String deviceId);

  /// Verifies and applies the log suffix, epochs, wraps and beacons of a
  /// pull page. Must be idempotent: a page can be absorbed again. A
  /// [FamilyCheck] that isn't ok stops syncing this family and shows the
  /// security warning.
  Future<FamilyCheck> absorb(PullPage page);

  /// Reader rules 3, 5 and 6: the writer's role at its log head, revoked or
  /// removed writers' clocks, and clocks under an old epoch.
  bool mayApply(RecordBody body, int keyVersion);

  /// False while writes must stop: a pending rotation, a stale beacon from
  /// every phone of another member (section 7), or a recovered phone that
  /// is still read-only.
  bool get canWrite;
}

final class FamilyCheck {
  const FamilyCheck.ok() : warning = null;
  const FamilyCheck.stop(String this.warning);

  final String? warning;
  bool get ok => warning == null;
}

/// A record as this phone holds it, by its server sync id.
final class LocalRecord {
  const LocalRecord({
    required this.recordId,
    required this.type,
    required this.revision,
    required this.groups,
    this.changedGroups = const {},
    this.baseClocks = const {},
  });

  final String recordId;
  final String type;

  /// The last server revision this phone merged; 0 if never uploaded.
  final int revision;
  final Groups groups;

  /// Groups changed on this phone since its last push.
  final Set<String> changedGroups;

  /// Each group's clock in the last server version this phone merged or
  /// pushed. A group whose local and remote clocks both differ from it was
  /// changed on two phones (the conflict flag).
  final Map<String, Hlc> baseClocks;
}

/// A local change waiting to be pushed.
final class LocalChange {
  const LocalChange({
    required this.syncId,
    required this.record,
    this.history = false,
  });

  /// The server's random v4 id (chosen by the store when first uploaded).
  final String syncId;
  final LocalRecord record;

  /// A dose-log, temperature or given-medicine bundle (jittered upload).
  final bool history;
}

/// The phone's side: local tables, sync ids, cursors and clocks. The drift
/// implementation (with the record codecs for each table) comes with the
/// family layer; tests use an in-memory one.
abstract interface class SyncStore {
  Future<({int afterSeq, String afterTxid, String? afterSync})> cursor(
    String familyId,
  );
  Future<void> saveCursor(
    String familyId, {
    required int afterSeq,
    required String afterTxid,
    String? afterSync,
  });

  Future<LocalRecord?> record(String familyId, String syncId);

  /// Changes waiting to be pushed; history bundles only when [includeHistory].
  /// Changes the store has set aside with [rejected] are left out.
  Future<List<LocalChange>> pending(
    String familyId, {
    required bool includeHistory,
  });

  /// Writes the merged groups of a pulled (or conflicting) record and the
  /// server revision it now matches.
  ///
  /// [stillChanged] are local groups that won the merge and still need
  /// pushing. [baseClocks] are the clocks of the server version just
  /// merged. [held] groups had clocks too far ahead (reader rule 7): the
  /// store keeps them and offers them again as a remote version on a later
  /// sync. [conflicts] are shown to the person.
  Future<void> applyMerged(
    String familyId, {
    required String syncId,
    required String recordId,
    required String type,
    required int revision,
    required Groups groups,
    required Set<String> stillChanged,
    required Map<String, Hlc> baseClocks,
    required Groups held,
    required List<MergeConflict> conflicts,
  });

  /// The server accepted [change] at [revision]: clear its changed groups
  /// (unless they changed again meanwhile) and take its clocks as the base.
  Future<void> markPushed(String familyId, LocalChange change, int revision);

  /// The server or the envelope refused [change] for [reason] (too big, its
  /// server row is gone): keep it out of [pending] and tell the person,
  /// until a full resync settles it.
  Future<void> rejected(String familyId, LocalChange change, String reason);
}

enum SyncStatus {
  done,

  /// The server's kill switch is off.
  disabled,

  /// The family security warning: syncing this family stops.
  warning,

  /// No network, the server's rate limit, or another transport failure: try
  /// again on the next trigger.
  offline,

  /// This phone doesn't hold the current key epoch yet (a wrap is missing).
  waiting,
}

final class SyncOutcome {
  const SyncOutcome(
    this.status, {
    this.pulled = 0,
    this.pushed = 0,
    this.pushCalls = 0,
    this.rejected = 0,
    this.detail,
  });

  final SyncStatus status;
  final int pulled;
  final int pushed;
  final int pushCalls;

  /// Local changes set aside with [SyncStore.rejected].
  final int rejected;
  final String? detail;

  SyncOutcome add({
    int pulled = 0,
    int pushed = 0,
    int pushCalls = 0,
    int rejected = 0,
  }) => SyncOutcome(
    status,
    pulled: this.pulled + pulled,
    pushed: this.pushed + pushed,
    pushCalls: this.pushCalls + pushCalls,
    rejected: this.rejected + rejected,
    detail: detail,
  );
}

final class _Stop implements Exception {
  const _Stop(this.outcome);
  final SyncOutcome outcome;
}

/// Pulls and pushes one family's encrypted records (section 12): pull first
/// (log, then records, merged group by group), then push the waiting
/// changes in batches of at most 100 records and 2 MiB (section 22, rule 2),
/// with compare-and-set on the server revision.
class SyncEngine {
  SyncEngine({
    required this.transport,
    required this.store,
    required this.clock,
    required this.isClinical,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final SyncTransport transport;
  final SyncStore store;
  final HlcClock clock;

  /// Whether a group of a record type is clinical (a concurrent change sets
  /// the conflict flag instead of merging silently).
  final bool Function(String type, String group) isClinical;
  final DateTime Function() _now;

  static const maxBatchRecords = 100;
  static const maxBatchBytes = 2 * 1024 * 1024;
  static const maxRounds = 5;
  static const maxPages = 1000;

  /// Never throws: every failure becomes a [SyncOutcome].
  Future<SyncOutcome> sync(FamilySession family, SyncReason reason) async {
    var totals = const SyncOutcome(SyncStatus.done);
    try {
      if (reason != SyncReason.edits) {
        totals = totals.add(pulled: await _pull(family));
      }
      if (!family.canWrite) {
        return SyncOutcome(
          SyncStatus.done,
          pulled: totals.pulled,
          detail: 'read_only',
        );
      }
      for (var round = 0; round < maxRounds; round++) {
        final changes = await store.pending(
          family.familyId,
          includeHistory: reason != SyncReason.edits,
        );
        if (changes.isEmpty) break;
        final r = await _pushRound(family, changes);
        totals = totals.add(
          pushed: r.pushed,
          pushCalls: r.calls,
          rejected: r.rejected,
        );
        if (r.pullFirst) {
          totals = totals.add(pulled: await _pull(family));
        }
        if (!r.retry) break;
      }
      return totals;
    } on _Stop catch (s) {
      return SyncOutcome(
        s.outcome.status,
        pulled: totals.pulled,
        pushed: totals.pushed,
        pushCalls: totals.pushCalls,
        rejected: totals.rejected,
        detail: s.outcome.detail,
      );
    } on Exception catch (e) {
      // Network errors, HTTP 429 (rate limit) and other transport failures.
      return SyncOutcome(
        SyncStatus.offline,
        pulled: totals.pulled,
        pushed: totals.pushed,
        pushCalls: totals.pushCalls,
        rejected: totals.rejected,
        detail: e.runtimeType.toString(),
      );
    }
  }

  /// One round: seal every pending change, push in batches, handle results.
  Future<({int pushed, int calls, int rejected, bool retry, bool pullFirst})>
  _pushRound(FamilySession family, List<LocalChange> changes) async {
    var pushed = 0;
    var calls = 0;
    var rejected = 0;
    var retry = false;
    var pullFirst = false;
    final sealed = await _batches(family, changes);
    rejected += sealed.rejected;
    for (final batch in sealed.batches) {
      calls++;
      final response = await transport.push(
        familyId: family.familyId,
        logSeq: family.logSeq,
        records: [for (final b in batch) b.outgoing],
      );
      if (!response.ok) {
        switch (response.error) {
          case 'sync_disabled':
            throw const _Stop(SyncOutcome(SyncStatus.disabled));
          case 'stale_log' || 'rotation_pending' || 'no_log':
            // Catch up with the log (and any rotation), then reseal.
            return (
              pushed: pushed,
              calls: calls,
              rejected: rejected,
              retry: true,
              pullFirst: true,
            );
          default:
            // daily_limit, family_full: nothing more this time.
            throw _Stop(SyncOutcome(SyncStatus.done, detail: response.error));
        }
      }
      final bySync = {for (final b in batch) b.change.syncId: b.change};
      for (final r in response.results) {
        final change = bySync[r.syncId];
        if (change == null) continue;
        if (r.ok && r.revision != null) {
          await store.markPushed(family.familyId, change, r.revision!);
          pushed++;
        } else if (r.error == 'revision_conflict' && r.current != null) {
          await _apply(family, r.current!);
          retry = true;
        } else if (r.error == 'stale_key') {
          // One pull for the whole round, then reseal under the new epoch.
          pullFirst = true;
          retry = true;
        } else {
          // A conflict with a row the server no longer has (a tombstone
          // purged after a year), or an error this version doesn't know.
          await store.rejected(family.familyId, change, r.error ?? 'unknown');
          rejected++;
        }
      }
      if (pullFirst) break;
    }
    return (
      pushed: pushed,
      calls: calls,
      rejected: rejected,
      retry: retry,
      pullFirst: pullFirst,
    );
  }

  /// Pulls until the server has nothing more. Returns the records applied.
  Future<int> _pull(FamilySession family) async {
    var pulled = 0;
    for (var pages = 0; ; pages++) {
      if (pages == maxPages) {
        throw const _Stop(
          SyncOutcome(SyncStatus.warning, detail: 'no_progress'),
        );
      }
      final cursor = await store.cursor(family.familyId);
      final page = await transport.pull(
        PullRequest(
          familyId: family.familyId,
          afterSeq: cursor.afterSeq,
          afterTxid: cursor.afterTxid,
          afterSync: cursor.afterSync,
        ),
      );
      if (!page.ok) {
        throw _Stop(
          SyncOutcome(
            page.error == 'sync_disabled'
                ? SyncStatus.disabled
                : SyncStatus.warning,
            detail: page.error,
          ),
        );
      }
      final check = await family.absorb(page);
      if (!check.ok) {
        throw _Stop(SyncOutcome(SyncStatus.warning, detail: check.warning));
      }
      if (page.logMore) {
        // Records may need devices or epochs from later log pages: take
        // the whole log first, then this page's records again.
        if (family.logSeq <= cursor.afterSeq) {
          throw const _Stop(
            SyncOutcome(SyncStatus.warning, detail: 'no_progress'),
          );
        }
        await store.saveCursor(
          family.familyId,
          afterSeq: family.logSeq,
          afterTxid: cursor.afterTxid,
          afterSync: cursor.afterSync,
        );
        continue;
      }
      for (final r in page.records) {
        await _apply(family, r.record);
        pulled++;
      }
      if (page.recordsMore &&
          page.afterTxid == cursor.afterTxid &&
          page.afterSync == cursor.afterSync) {
        throw const _Stop(
          SyncOutcome(SyncStatus.warning, detail: 'no_progress'),
        );
      }
      await store.saveCursor(
        family.familyId,
        afterSeq: family.logSeq,
        afterTxid: page.afterTxid,
        afterSync: page.afterSync,
      );
      if (!page.recordsMore) break;
    }
    return pulled;
  }

  /// Opens, checks and merges one server record into the local state. A
  /// record failing reader rules 1-6 is never applied and stops the family
  /// with the security warning; the cursor stays before it.
  Future<void> _apply(FamilySession family, ServerRecord row) async {
    final key = await family.recordKey(row.keyVersion);
    if (key == null) {
      throw const _Stop(SyncOutcome(SyncStatus.waiting, detail: 'missing_key'));
    }
    final RecordBody body;
    try {
      body = await openRecord(
        header: recordHeader(
          familyId: family.familyId,
          syncId: row.syncId,
          keyVersion: row.keyVersion,
        ),
        stored: row.ciphertext,
        recordKey: key,
        signerKey: family.signerKey,
      );
    } on EnvelopeException catch (e) {
      throw _Stop(SyncOutcome(SyncStatus.warning, detail: e.reason));
    }
    if (!family.mayApply(body, row.keyVersion)) {
      throw const _Stop(
        SyncOutcome(SyncStatus.warning, detail: 'writer_not_allowed'),
      );
    }
    final local = await store.record(family.familyId, row.syncId);
    if (local != null &&
        (local.recordId != body.id || local.type != body.type)) {
      throw const _Stop(
        SyncOutcome(SyncStatus.warning, detail: 'sync_id_reused'),
      );
    }
    final split = splitFutureGroups(body.groups, _now());
    final changed = local?.changedGroups ?? const <String>{};
    final merged = mergeGroups(
      local?.groups ?? const {},
      split.apply,
      baseClocks: local?.baseClocks ?? const {},
      isClinical: (g) => isClinical(body.type, g),
    );
    for (final g in split.apply.values) {
      clock.observe(g.clock);
    }
    // Local groups that won (or that the remote didn't have) still go up.
    final stillChanged = {
      for (final g in changed)
        if (merged.groups[g] != null && merged.groups[g] == local!.groups[g]) g,
    };
    await store.applyMerged(
      family.familyId,
      syncId: row.syncId,
      recordId: body.id,
      type: body.type,
      revision: row.revision,
      groups: merged.groups,
      stillChanged: stillChanged,
      baseClocks: {for (final e in split.apply.entries) e.key: e.value.clock},
      held: split.held,
      conflicts: merged.conflicts,
    );
  }

  Future<
    ({
      List<List<({LocalChange change, OutgoingRecord outgoing})>> batches,
      int rejected,
    })
  >
  _batches(FamilySession family, List<LocalChange> changes) async {
    final key = await family.recordKey(family.keyVersion);
    if (key == null) {
      throw const _Stop(SyncOutcome(SyncStatus.waiting, detail: 'missing_key'));
    }
    final batches = <List<({LocalChange change, OutgoingRecord outgoing})>>[];
    var current = <({LocalChange change, OutgoingRecord outgoing})>[];
    var bytes = 0;
    var rejected = 0;
    for (final change in changes) {
      final r = change.record;
      final deleted = isDeleted(r.groups);
      final Uint8List ciphertext;
      try {
        ciphertext = await sealRecord(
          header: recordHeader(
            familyId: family.familyId,
            syncId: change.syncId,
            keyVersion: family.keyVersion,
          ),
          body: RecordBody(
            id: r.recordId,
            type: r.type,
            by: family.deviceId,
            logSeq: family.logSeq,
            logHash: family.logHash,
            // A deleted record goes up as a tombstone, without its values.
            groups: deleted ? tombstone(r.groups) : r.groups,
          ),
          recordKey: key,
          signingKey: family.signingKey,
        );
      } on EnvelopeException catch (e) {
        // Too big for one record: set aside, the rest still go up.
        await store.rejected(family.familyId, change, e.reason);
        rejected++;
        continue;
      }
      if (current.length == maxBatchRecords ||
          bytes + ciphertext.length > maxBatchBytes) {
        batches.add(current);
        current = [];
        bytes = 0;
      }
      current.add((
        change: change,
        outgoing: OutgoingRecord(
          syncId: change.syncId,
          keyVersion: family.keyVersion,
          ciphertext: ciphertext,
          deleted: deleted,
          expectedRevision: r.revision,
        ),
      ));
      bytes += ciphertext.length;
    }
    if (current.isNotEmpty) batches.add(current);
    return (batches: batches, rejected: rejected);
  }
}
