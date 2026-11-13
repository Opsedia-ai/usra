import 'dart:convert';
import 'dart:typed_data';

/// What the sync engine sends to and gets from the server.
///
/// The engine only talks to this interface (docs/sync-design.md section 23),
/// so a plain HTTPS API can replace the Supabase client without touching it.
/// Binary values are base64 on the wire (section 22, rule 12).
abstract interface class SyncTransport {
  /// One app-open round trip: a page of records plus the family log after
  /// [PullRequest.afterSeq], epochs, this phone's wraps and head beacons.
  Future<PullPage> pull(PullRequest request);

  /// Writes up to 100 records (2 MiB) of one family in one call.
  Future<PushResponse> push({
    required String familyId,
    required int logSeq,
    required List<OutgoingRecord> records,
  });
}

final class PullRequest {
  const PullRequest({
    required this.familyId,
    this.afterSeq = 0,
    this.afterTxid = '0',
    this.afterSync,
    this.limit = 500,
  });

  final String familyId;
  final int afterSeq;
  final String afterTxid;
  final String? afterSync;
  final int limit;
}

/// A record row as the server holds it.
final class ServerRecord {
  const ServerRecord({
    required this.syncId,
    required this.revision,
    required this.keyVersion,
    required this.ciphertext,
    required this.deleted,
  });

  final String syncId;
  final int revision;
  final int keyVersion;
  final Uint8List ciphertext;
  final bool deleted;
}

final class PullPage {
  const PullPage({
    required this.ok,
    this.error,
    this.headSeq = 0,
    this.keyVersion = 0,
    this.rotationPending = false,
    this.log = const [],
    this.logMore = false,
    this.epochs = const [],
    this.wraps = const [],
    this.heads = const [],
    this.records = const [],
    this.recordsMore = false,
    this.afterTxid = '0',
    this.afterSync,
  });

  /// Parses the JSON `sync_pull` answers.
  factory PullPage.fromJson(Map<String, Object?> json) {
    if (json['ok'] != true) {
      return PullPage(ok: false, error: json['error'] as String? ?? 'unknown');
    }
    List<Map<String, Object?>> list(String key) => [
      for (final e in (json[key] as List? ?? const []))
        (e as Map).cast<String, Object?>(),
    ];
    return PullPage(
      ok: true,
      headSeq: (json['head_seq'] as int?) ?? 0,
      keyVersion: (json['key_version'] as int?) ?? 0,
      rotationPending: json['rotation_pending'] == true,
      log: list('log'),
      logMore: json['log_more'] == true,
      epochs: list('epochs'),
      wraps: list('wraps'),
      heads: list('heads'),
      records: [
        for (final r in list('records'))
          (
            record: ServerRecord(
              syncId: r['sync_id']! as String,
              revision: r['revision']! as int,
              keyVersion: r['key_version']! as int,
              ciphertext: base64Decode(r['ciphertext']! as String),
              deleted: r['deleted'] == true,
            ),
            txid: r['txid']! as String,
          ),
      ],
      recordsMore: json['records_more'] == true,
      afterTxid: json['after_txid'] as String? ?? '0',
      afterSync: json['after_sync'] as String?,
    );
  }

  final bool ok;

  /// `sync_disabled` when the server's kill switch is off.
  final String? error;
  final int headSeq;
  final int keyVersion;
  final bool rotationPending;

  /// Family log entries `{seq, entry, sig}` (base64), epochs, wraps and
  /// beacons, for the family layer to verify.
  final List<Map<String, Object?>> log;
  final bool logMore;
  final List<Map<String, Object?>> epochs;
  final List<Map<String, Object?>> wraps;
  final List<Map<String, Object?>> heads;
  final List<({ServerRecord record, String txid})> records;
  final bool recordsMore;
  final String afterTxid;
  final String? afterSync;
}

final class OutgoingRecord {
  const OutgoingRecord({
    required this.syncId,
    required this.keyVersion,
    required this.ciphertext,
    required this.deleted,
    required this.expectedRevision,
  });

  final String syncId;
  final int keyVersion;
  final Uint8List ciphertext;

  /// A plain hint for the server's tombstone cleanup; readers trust only
  /// the signed `_deleted` group.
  final bool deleted;

  /// The server revision this phone merged; 0 for a new record.
  final int expectedRevision;

  Map<String, Object?> toJson() => {
    'sync_id': syncId,
    'key_version': keyVersion,
    'ciphertext': base64Encode(ciphertext),
    'deleted': deleted,
    'expected_revision': expectedRevision,
  };
}

final class PushResult {
  const PushResult({
    required this.syncId,
    required this.ok,
    this.revision,
    this.error,
    this.current,
  });

  final String syncId;
  final bool ok;
  final int? revision;

  /// `stale_key` or `revision_conflict`.
  final String? error;

  /// For `revision_conflict`: the version this phone has to merge first.
  final ServerRecord? current;
}

final class PushResponse {
  const PushResponse({
    required this.ok,
    this.error,
    this.headSeq = 0,
    this.results = const [],
  });

  factory PushResponse.fromJson(Map<String, Object?> json) {
    if (json['ok'] != true) {
      return PushResponse(
        ok: false,
        error: json['error'] as String? ?? 'unknown',
        headSeq: (json['head_seq'] as int?) ?? 0,
      );
    }
    return PushResponse(
      ok: true,
      headSeq: (json['head_seq'] as int?) ?? 0,
      results: [
        for (final raw in json['results']! as List)
          () {
            final r = (raw as Map).cast<String, Object?>();
            final cur = (r['current'] as Map?)?.cast<String, Object?>();
            return PushResult(
              syncId: r['sync_id']! as String,
              ok: r['ok'] == true,
              revision: r['revision'] as int?,
              error: r['error'] as String?,
              current: cur == null
                  ? null
                  : ServerRecord(
                      syncId: r['sync_id']! as String,
                      revision: cur['revision']! as int,
                      keyVersion: cur['key_version']! as int,
                      ciphertext: base64Decode(cur['ciphertext']! as String),
                      deleted: cur['deleted'] == true,
                    ),
            );
          }(),
      ],
    );
  }

  final bool ok;

  /// Whole-batch refusals: `sync_disabled`, `no_log`, `stale_log`,
  /// `rotation_pending`, `daily_limit`, `family_full`.
  final String? error;
  final int headSeq;
  final List<PushResult> results;
}
