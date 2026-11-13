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
  /// pull page. A [FamilyCheck] that isn't ok stops syncing this family
  /// and shows the security warning.
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
  });

  final String recordId;
  final String type;

  /// The last server revision this phone merged; 0 if never uploaded.
  final int revision;
  final Groups groups;

  /// Groups changed on this phone since its last push.
  final Set<String> changedGroups;
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
  Future<List<LocalChange>> pending(
    String familyId, {
    required bool includeHistory,
  });

  /// Writes the merged groups of a pulled (or conflicting) record and the
  /// server revision it now matches. [stillChanged] are local groups that
  /// won the merge and still need pushing; [held] groups had clocks too far
  /// ahead and are looked at again later; [conflicts] are shown to the
  /// person.
  Future<void> applyMerged(
    String familyId, {
    required String syncId,
    required String recordId,
    required String type,
    required int revision,
    required Groups groups,
    required Set<String> stillChanged,
    required Groups held,
    required List<MergeConflict> conflicts,
  });

  /// The server accepted [change] at [revision]: clear its changed groups,
  /// unless they changed again meanwhile.
  Future<void> markPushed(String familyId, LocalChange change, int revision);
}

enum SyncStatus { done, disabled, warning, offline }

final class SyncOutcome {
  const SyncOutcome(
    this.status, {
    this.pulled = 0,
    this.pushed = 0,
    this.pushCalls = 0,
    this.detail,
  });

  final SyncStatus status;
  final int pulled;
  final int pushed;
  final int pushCalls;
  final String? detail;
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

  Future<SyncOutcome> sync(FamilySession family, SyncReason reason) async {
    var pulled = 0;
    if (reason != SyncReason.edits) {
      final p = await _pull(family);
      if (p.status != SyncStatus.done) return p;
      pulled = p.pulled;
    }
    if (!family.canWrite) {
      return SyncOutcome(SyncStatus.done, pulled: pulled, detail: 'read_only');
    }
    var pushed = 0;
    var calls = 0;
    for (var round = 0; round < maxRounds; round++) {
      final changes = await store.pending(
        family.familyId,
        includeHistory: reason != SyncReason.edits,
      );
      if (changes.isEmpty) break;
      var retry = false;
      for (final batch in await _batches(family, changes)) {
        calls++;
        final response = await transport.push(
          familyId: family.familyId,
          logSeq: family.logSeq,
          records: [for (final b in batch) b.outgoing],
        );
        if (!response.ok) {
          switch (response.error) {
            case 'sync_disabled':
              return SyncOutcome(
                SyncStatus.disabled,
                pulled: pulled,
                pushed: pushed,
                pushCalls: calls,
              );
            case 'stale_log' || 'rotation_pending' || 'no_log':
              // Catch up with the log (and any rotation), then try again.
              final p = await _pull(family);
              if (p.status != SyncStatus.done) return p;
              pulled += p.pulled;
              retry = true;
            default:
              // daily_limit, family_full: nothing more this time.
              return SyncOutcome(
                SyncStatus.done,
                pulled: pulled,
                pushed: pushed,
                pushCalls: calls,
                detail: response.error,
              );
          }
          break;
        }
        final bySync = {for (final b in batch) b.change.syncId: b.change};
        for (final r in response.results) {
          final change = bySync[r.syncId];
          if (change == null) continue;
          if (r.ok) {
            await store.markPushed(family.familyId, change, r.revision!);
            pushed++;
          } else if (r.error == 'revision_conflict' && r.current != null) {
            try {
              await _apply(family, r.current!);
            } on EnvelopeException catch (e) {
              return SyncOutcome(
                SyncStatus.warning,
                pulled: pulled,
                pushed: pushed,
                pushCalls: calls,
                detail: e.reason,
              );
            }
            retry = true;
          } else if (r.error == 'stale_key') {
            final p = await _pull(family);
            if (p.status != SyncStatus.done) return p;
            retry = true;
          }
        }
      }
      if (!retry) break;
    }
    return SyncOutcome(
      SyncStatus.done,
      pulled: pulled,
      pushed: pushed,
      pushCalls: calls,
    );
  }

  Future<SyncOutcome> _pull(FamilySession family) async {
    var pulled = 0;
    while (true) {
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
        return SyncOutcome(
          page.error == 'sync_disabled'
              ? SyncStatus.disabled
              : SyncStatus.warning,
          detail: page.error,
        );
      }
      final check = await family.absorb(page);
      if (!check.ok) {
        return SyncOutcome(SyncStatus.warning, detail: check.warning);
      }
      for (final r in page.records) {
        try {
          await _apply(family, r.record);
        } on EnvelopeException catch (e) {
          // Reader rules 1-6: never applied, and the family stops syncing
          // with the security warning (the cursor stays before it).
          return SyncOutcome(
            SyncStatus.warning,
            pulled: pulled,
            detail: e.reason,
          );
        }
        pulled++;
      }
      await store.saveCursor(
        family.familyId,
        afterSeq: family.logSeq,
        afterTxid: page.afterTxid,
        afterSync: page.afterSync,
      );
      if (!page.recordsMore && !page.logMore) break;
    }
    return SyncOutcome(SyncStatus.done, pulled: pulled);
  }

  /// Opens, checks and merges one server record into the local state.
  Future<void> _apply(FamilySession family, ServerRecord row) async {
    final key = await family.recordKey(row.keyVersion);
    if (key == null) {
      throw const EnvelopeException('unknown key version');
    }
    final header = recordHeader(
      familyId: family.familyId,
      syncId: row.syncId,
      keyVersion: row.keyVersion,
    );
    final body = await openRecord(
      header: header,
      stored: row.ciphertext,
      recordKey: key,
      signerKey: family.signerKey,
    );
    if (!family.mayApply(body, row.keyVersion)) {
      throw const EnvelopeException('writer not allowed');
    }
    final local = await store.record(family.familyId, row.syncId);
    if (local != null &&
        (local.recordId != body.id || local.type != body.type)) {
      throw const EnvelopeException('sync id reused for another record');
    }
    final split = splitFutureGroups(body.groups, _now());
    final changed = local?.changedGroups ?? const <String>{};
    final merged = mergeGroups(
      local?.groups ?? const {},
      split.apply,
      locallyChanged: changed,
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
      held: split.held,
      conflicts: merged.conflicts,
    );
  }

  Future<List<List<({LocalChange change, OutgoingRecord outgoing})>>> _batches(
    FamilySession family,
    List<LocalChange> changes,
  ) async {
    final key = await family.recordKey(family.keyVersion);
    if (key == null) {
      throw const EnvelopeException('no key for the current epoch');
    }
    final batches = <List<({LocalChange change, OutgoingRecord outgoing})>>[];
    var current = <({LocalChange change, OutgoingRecord outgoing})>[];
    var bytes = 0;
    for (final change in changes) {
      final r = change.record;
      final ciphertext = await sealRecord(
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
          groups: r.groups,
        ),
        recordKey: key,
        signingKey: family.signingKey,
      );
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
          ciphertext: Uint8List.fromList(ciphertext),
          deleted: isDeleted(r.groups),
          expectedRevision: r.revision,
        ),
      ));
      bytes += ciphertext.length;
    }
    if (current.isNotEmpty) batches.add(current);
    return batches;
  }
}
