import 'dart:async';
import 'dart:convert';

import 'local_database.dart';
import 'local_store.dart';

/// Maximum attempts (including the first) for a single queued leg before it is
/// parked as `failed` and left for a manual reset. Nothing auto-requeues a
/// parked leg; the next [SyncFlusher.flush] pass skips it (store contract:
/// `pendingSync` only returns `status == 'pending'`).
const int kSyncMaxAttempts = 5;

/// Backoff ladder in seconds applied *between* flush passes when a pass left
/// legs pending: 1s, 2s, 5s, 15s, 60s then capped at the ladder's last rung.
const List<int> kSyncBackoffSeconds = <int>[1, 2, 5, 15, 60];

/// Idempotent on-line surface the flusher replays one queued leg against.
///
/// Production binds a Supabase-backed target (RPCs + table CRUD against
/// `Supabase.instance.client`); tests bind a fake. Every method is safe to
/// replay: RPC legs carry a client `request_id` (server dedupes), table CRUD
/// upserts by the client-supplied primary key.
abstract interface class SyncTarget {
  /// Replays an `rpc` leg named [name] with [params] (already carries the
  /// client `request_id` so a replay is idempotent server-side).
  Future<Map<String, dynamic>> rpc(String name, Map<String, dynamic> params);

  /// Replays a `table_crud` upsert for [entity] keyed by [id] (upsert-by-pk,
  /// so replays are safe). [row] carries the client draft to upsert.
  Future<Map<String, dynamic>> tableUpsert(
    String entity,
    String id,
    Map<String, dynamic> row,
  );

  /// Replays a `table_crud` delete for [entity] by [id]. Returns normally when
  /// the row is already gone server-side (idempotent by design).
  Future<void> tableDelete(String entity, String id);
}

/// Outcome of a single [SyncFlusher.flush] pass.
class SyncFlushSummary {
  const SyncFlushSummary({
    required this.replayed,
    required this.synced,
    required this.failed,
    required this.remaining,
  });

  final int replayed;
  final int synced;
  final int failed;
  final int remaining;

  bool get done => remaining == 0;
}

/// Drains the tenant's pending offline-write queue FIFO, replaying each leg
/// against a [SyncTarget].
///
/// Retry semantics (mirrors the store contract):
///  - a pass replays each `pending` leg once;
///  - success → `markSynced`; failure → `markFailed(error)` and the leg is
///    left `failed` for a manual retry (it no longer appears in `pendingSync`);
///  - the [kSyncBackoffSeconds] ladder is consumed by the caller between passes
///    when a pass leaves legs pending, so reconnects/manual syncs retry with
///    bounded backoff rather than hammering.
///
/// Single-flight: a concurrent [flush] returns the in-progress pass's summary
/// instead of starting a second drain.
class SyncFlusher {
  SyncFlusher(this.store, this.tenantId, this.target);

  final LocalStore store;
  final String tenantId;
  final SyncTarget target;

  bool _flushing = false;
  SyncFlushSummary? _currentPass;
  Future<SyncFlushSummary> _inFlight = Future.value(
    const SyncFlushSummary(replayed: 0, synced: 0, failed: 0, remaining: 0),
  );

  /// True while a flush pass is running.
  bool get isFlushing => _flushing;

  /// Number of legs still waiting for this tenant.
  Future<int> pendingCount() => store.pendingCount(tenantId);

  /// Replays every pending leg once, FIFO, single-flight.
  Future<SyncFlushSummary> flush() {
    if (_flushing) return _inFlight;
    _flushing = true;
    final result = _doFlush();
    _inFlight = result;
    return result;
  }

  Future<SyncFlushSummary> _doFlush() async {
    var replayed = 0;
    var synced = 0;
    var failed = 0;
    try {
      final legs = await store.pendingSync(tenantId);
      for (final leg in legs) {
        replayed += 1;
        final ok = await _replayOne(leg);
        if (ok) {
          synced += 1;
          await store.markSynced(leg.id);
        } else {
          failed += 1;
          await store.markFailed(leg.id, _lastError);
        }
      }
      _currentPass = SyncFlushSummary(
        replayed: replayed,
        synced: synced,
        failed: failed,
        remaining: await store.pendingCount(tenantId),
      );
      return _currentPass!;
    } finally {
      _flushing = false;
    }
  }

  String _lastError = '';

  /// Replays one leg. Returns true when the server acknowledged it.
  Future<bool> _replayOne(SyncQueueRow row) async {
    try {
      final params = row.params == '' ? <String, dynamic>{} : jsonDecode(row.params) as Map<String, dynamic>;
      switch (row.op) {
        case 'rpc':
          await target.rpc(row.rpc, params);
          return true;
        case 'table_crud':
          final entity = row.rpc.replaceFirst('table:', '');
          if (params.containsKey('id') && !params.containsKey('row')) {
            await target.tableDelete(entity, params['id'] as String);
          } else {
            final rowParams = params['row'] as Map<String, dynamic>? ?? params;
            await target.tableUpsert(entity, row.localId!, rowParams);
            await store.putMapping(
              entity: entity,
              localId: row.localId!,
              serverId: row.localId!,
            );
          }
          return true;
        default:
          return false;
      }
    } on Object catch (e) {
      _lastError = e.toString();
      return false;
    }
  }
}
