import 'package:supabase_flutter/supabase_flutter.dart';

import 'offline_sync.dart';

/// Production [SyncTarget] backed by the live Supabase client passed from the
/// composition root (`supabaseClientProvider` in `data/supabase_client.dart`).
///
/// All operations are the replay-safe "on-line" half of the queue protocol:
///  - `rpc` legs pass client params through verbatim â€” the RPC contracts accept
///    a client `request_id` so a replay is idempotent server-side;
///  - `tableUpsert` upserts by the client-supplied primary key (`id`) with
///    `onConflict: 'id'`, making a replay a no-op-diff;
///  - `tableDelete` deletes by primary key and treats a missing row as success
///    (idempotent by design).
class SupabaseSyncTarget implements SyncTarget {
  SupabaseSyncTarget(this._client);

  final SupabaseClient _client;

  @override
  Future<Map<String, dynamic>> rpc(
    String name,
    Map<String, dynamic> params,
  ) async {
    final result = await _client.rpc(name, params: params);
    if (result is Map<String, dynamic>) {
      return result;
    }
    if (result is List && result.isNotEmpty && result.first is Map) {
      return (result.first as Map).cast<String, dynamic>();
    }
    return <String, dynamic>{};
  }

  @override
  Future<Map<String, dynamic>> tableUpsert(
    String entity,
    String id,
    Map<String, dynamic> row,
  ) async {
    final rows = await _client
        .from(entity)
        .upsert(<String, dynamic>{...row, 'id': id}, onConflict: 'id')
        .select();
    if (rows.isNotEmpty) {
      return (rows.first as Map).cast<String, dynamic>();
    }
    return <String, dynamic>{};
  }

  @override
  Future<void> tableDelete(String entity, String id) async {
    try {
      await _client.from(entity).delete().eq('id', id);
    } on PostgrestException catch (e) {
      if (e.code != 'PGRST116') rethrow;
    }
  }
}

