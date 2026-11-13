import 'package:supabase_flutter/supabase_flutter.dart';

import 'sync_transport.dart';

/// [SyncTransport] over PostgREST database functions (no Edge Function call,
/// section 22, rule 8). Always POST: the functions write a call counter, so a
/// read-only GET would fail.
final class SupabaseSyncTransport implements SyncTransport {
  SupabaseSyncTransport(this._client);

  final SupabaseClient _client;

  @override
  Future<PullPage> pull(PullRequest request) async {
    final json = await _client.rpc<Map<String, dynamic>>(
      'sync_pull',
      params: {
        'p_family': request.familyId,
        'p_after_seq': request.afterSeq,
        'p_after_txid': request.afterTxid,
        'p_after_sync': request.afterSync,
        'p_limit': request.limit,
      },
    );
    return PullPage.fromJson(json);
  }

  @override
  Future<PushResponse> push({
    required String familyId,
    required int logSeq,
    required List<OutgoingRecord> records,
  }) async {
    final json = await _client.rpc<Map<String, dynamic>>(
      'push_e2ee_records',
      params: {
        'p_family': familyId,
        'p_log_seq': logSeq,
        'p_records': [for (final r in records) r.toJson()],
      },
    );
    return PushResponse.fromJson(json);
  }
}
