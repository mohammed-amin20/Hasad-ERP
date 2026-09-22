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
          // Transient failure: keep the leg queued (bounded by
          // [kSyncMaxAttempts]) so the next flush pass retries it; once the
          // attempt budget is exhausted the leg is parked for manual reset.
          final nextAttempts = leg.attempts + 1;
          if (nextAttempts >= kSyncMaxAttempts) {
            await store.markFailed(leg.id, _lastError);
          } else {
            await store.requeueRetry(leg.id, _lastError, nextAttempts);
          }
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
          final response = await target.rpc(row.rpc, params);
          await _writeBackReplay(row, response);
          return true;
        case 'table_crud':
          final entity = row.rpc.replaceFirst('table:', '');
          if (params.containsKey('id') && !params.containsKey('row')) {
            await target.tableDelete(entity, params['id'] as String);
          } else {
            final rowParams = params['row'] as Map<String, dynamic>? ?? params;
            final saved = await target.tableUpsert(entity, row.localId!, rowParams);
            // Upsert-by-pk keeps the client uuid as the server id; prefer the
            // echoed id when the target returns it, else fall back to localId.
            await store.markReplaySynced(
              entity: entity,
              localId: row.localId!,
              serverId: (saved['id'] as String?) ?? row.localId!,
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

  /// Adopts the official identity returned by a replayed RPC:
  ///  - `invoices` legs write the server envelope's `no` (official invoice
  ///    number) onto the local mirror row and store the `id_map` remap;
  ///  - mirrored rows for every leg are flipped to `synced:true`.
  Future<void> _writeBackReplay(SyncQueueRow row, Map<String, dynamic> envelope) async {
    final localId = row.localId;
    final entity = row.entity;
    if (localId == null || entity == null) return;

    final serverId = entity == 'invoices'
        ? (envelope['invoice_id'] ?? envelope['id'])?.toString()
        : (envelope['payment_id'] ?? envelope['id'])?.toString();
    final officialNo = entity == 'invoices' ? envelope['no']?.toString() : null;

    await store.markReplaySynced(
      entity: entity,
      localId: localId,
      serverId: serverId,
      officialNo: officialNo,
    );
  }
}

/// Automatic sync-on-reconnect runner: once kicked, it flushes the tenant's
/// queue and, while legs remain pending and the app stays online, retries with
/// the [kSyncBackoffSeconds] ladder between passes. Single-flight: a kick while
/// a pass is queued is ignored; the loop stops as soon as the queue drains,
/// connectivity drops, or the attempt budget is exhausted (legs parked by the
/// flusher no longer count as pending).
///
/// Triggered from the offline→online edge by the presenting layer, so there is
/// no self-polling timer and widget tests stay settleable as long as nothing
/// kicks a runner (online is verified false in tests).
class AutoSyncRunner {
  AutoSyncRunner({
    required this.flush,
    required this.pendingCount,
    required this.isOnline,
  });

  /// Runs one flush pass (e.g. [SyncFlusher.flush]).
  final Future<SyncFlushSummary> Function() flush;

  /// Returns the number of legs still pending after [flush].
  final Future<int> Function() pendingCount;

  /// Whether the app is currently verified online.
  final bool Function() isOnline;

  bool _running = false;

  bool get isRunning => _running;

  /// Starts the drain loop (single-flight).
  Future<void> kick() async {
    if (_running) return;
    _running = true;
    try {
      var rung = 0;
      while (true) {
        if (!isOnline()) return;
        await flush();
        if (await pendingCount() == 0) return;
        if (!isOnline()) return;
        rung = rung.clamp(0, kSyncBackoffSeconds.length - 1);
        await Future<void>.delayed(
          Duration(seconds: kSyncBackoffSeconds[rung]),
        );
        rung += 1;
      }
    } finally {
      _running = false;
    }
  }
}
