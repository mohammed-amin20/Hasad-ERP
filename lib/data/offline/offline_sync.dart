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
    this.blocked = 0,
  });

  final int replayed;
  final int synced;
  final int failed;
  final int remaining;

  /// Legs skipped because an `dependsOn` prerequisite was not ready yet. They
  /// stay `pending` and are retried on the next pass, so they still count in
  /// [remaining].
  final int blocked;

  bool get done => remaining == 0;
}

/// Outcome of resolving a leg's `dependsOn` prerequisites: nothing waiting, a
/// prerequisite still queued ([pending], retry next pass), or a prerequisite that
/// can never succeed ([permanently] with a [reason] for the parked leg).
class _UnmetDependencies {
  const _UnmetDependencies({
    this.pending = false,
    this.permanently = false,
    this.reason,
  });

  final bool pending;
  final bool permanently;
  final String? reason;
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
      // Status of EVERY leg for this tenant, `failed` ones included, so a
      // `dependsOn` prerequisite can be resolved without a query per leg.
      final statuses = await store.queueStatuses(tenantId);
      final legs = await store.pendingSync(tenantId);
      final handled = <String>{};

      // FIFO order alone is not enough: a leg that needs a parent the server
      // has not seen yet must wait, or the server rejects it on a missing
      // foreign key and the leg burns a retry (or is parked as `failed`) for a
      // purely local ordering reason. The outer loop re-scans until a full
      // round adds no progress, so a child enqueued BEFORE its parent still
      // replays in this same pass once the parent is acknowledged — a chain
      // must not cost a backoff rung per link.
      var progress = true;
      while (progress) {
        progress = false;
        for (final leg in legs) {
          if (handled.contains(leg.id)) continue;

          final unmet = _unmetDependencies(leg, statuses);
          if (unmet.permanently) {
            // A prerequisite is parked `failed` or is gone from the queue, and
            // nothing will ever replay it, so this leg can never succeed. Park
            // it too instead of retrying a doomed call on every backoff rung.
            handled.add(leg.id);
            progress = true;
            failed += 1;
            await store.markFailed(leg.id, unmet.reason!);
            statuses[leg.id] = 'failed';
            continue;
          }
          if (unmet.pending) {
            // A prerequisite is still queued: hold this leg for a later round
            // in this pass (and, if it never clears, the next pass). It stays
            // `pending`, so `remaining` still counts it.
            continue;
          }

          handled.add(leg.id);
          progress = true;
          replayed += 1;
          final ok = await _replayOne(leg);
          if (ok) {
            synced += 1;
            await store.markSynced(leg.id);
            // Marking a prerequisite synced is what unblocks its dependents
            // in the next round.
            statuses[leg.id] = 'synced';
          } else {
            failed += 1;
            // Transient failure: keep the leg queued (bounded by
            // [kSyncMaxAttempts]) so the next flush pass retries it; once the
            // attempt budget is exhausted the leg is parked for manual reset.
            final nextAttempts = leg.attempts + 1;
            if (nextAttempts >= kSyncMaxAttempts) {
              await store.markFailed(leg.id, _lastError);
              statuses[leg.id] = 'failed';
            } else {
              await store.requeueRetry(leg.id, _lastError, nextAttempts);
              statuses[leg.id] = 'pending';
            }
          }
        }
      }

      // Legs that never cleared their dependency gate are still pending.
      final blocked = legs.where((l) => !handled.contains(l.id)).length;
      _currentPass = SyncFlushSummary(
        replayed: replayed,
        synced: synced,
        failed: failed,
        blocked: blocked,
        remaining: await store.pendingCount(tenantId),
      );
      return _currentPass!;
    } finally {
      _flushing = false;
    }
  }

  /// Resolves [SyncQueueItem.dependsOn] against the tenant's leg [statuses].
  ///
  /// Returns whether a prerequisite is merely *pending* (wait for the next
  /// pass) or is *permanently* stuck (a `failed` leg, or a prerequisite id that
  /// no longer exists in the queue because it was cleared) — in which case
  /// [reason] explains why the dependent can never run.
  _UnmetDependencies _unmetDependencies(
    SyncQueueRow leg,
    Map<String, String> statuses,
  ) {
    final deps = LocalStore.parseDependencies(leg.dependsOn);
    if (deps.isEmpty) return const _UnmetDependencies();

    var waiting = false;
    for (final dep in deps) {
      if (dep == leg.id) {
        return _UnmetDependencies(
          permanently: true,
          reason: 'تبعية دائرية: لا يمكن أن تعتمد العملية على نفسها',
        );
      }
      final status = statuses[dep];
      if (status == null) {
        // The prerequisite is gone from the queue entirely (e.g. a forced
        // tenant clear). Replaying now would fail server-side anyway.
        return _UnmetDependencies(
          permanently: true,
          reason: 'المُعدّ السابق $dep غير موجود في قائمة المزامنة',
        );
      }
      if (status == 'failed') {
        return _UnmetDependencies(
          permanently: true,
          reason: 'فشل المُعدّ السابق $dep ولا يمكن تنفيذ هذه العملية',
        );
      }
      if (status != 'synced') waiting = true;
    }
    return _UnmetDependencies(pending: waiting);
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
            final id = params['id'] as String;
            await target.tableDelete(entity, id);
            // The server no longer has the row (or never will — deletes are
            // idempotent). Drop it from the mirror so local reads stop showing
            // a record the server already dropped. The delete leg itself is
            // marked synced by the caller's markSynced.
            await store.removeMirrorRows(row.tenantId, entity, [id]);
          } else {
            final rowParams = params['row'] as Map<String, dynamic>? ?? params;
            final saved = await target.tableUpsert(entity, row.localId!, rowParams);
            // Upsert-by-pk keeps the client uuid as the server id; prefer the
            // echoed id when the target returns it, else fall back to localId.
            await store.markReplaySynced(
              tenantId: row.tenantId,
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

    final serverId = resolveServerId(entity, envelope);
    final officialNo = entity == 'invoices'
        ? (envelope['no']?.toString() ?? nestedReplayRow('invoices', envelope)?['no']?.toString())
        : null;

    await store.markReplaySynced(
      tenantId: row.tenantId,
      entity: entity,
      localId: localId,
      serverId: serverId,
      officialNo: officialNo,
    );
  }
}

/// Unwraps the row nested inside an idempotent replay envelope.
///
/// A retried write answers `{'duplicate': true, '<entity>': {...}}`, so the
/// identity sits one level down instead of at the top level. Unknown entities
/// have no documented nesting key and yield null.
///
/// `is Map` then re-key, NOT `is Map<String, dynamic>`: a looser decoded map
/// would fail that test and silently return null all over again.
Map<String, dynamic>? nestedReplayRow(String entity, Map<String, dynamic> envelope) {
  final key = switch (entity) {
    'invoices' => 'invoice',
    'payments' => 'payment',
    'employee_movements' => 'movement',
    'salaries' => 'salary',
    'journal_entries' => 'entry',
    _ => null,
  };
  if (key == null) return null;
  final row = envelope[key];
  return row is Map ? row.map((k, v) => MapEntry(k.toString(), v)) : null;
}

/// Resolves the server-assigned id from EITHER response family a write RPC can
/// answer with, flat first:
///
///  * a fresh write returns a FLAT envelope keyed by an entity-specific id
///    (`invoice_id`, `payment_id`, `movement_id`, `salary_id`, `entry_id`);
///  * an idempotent replay returns `{'duplicate': true, '<entity>': {...}}`,
///    nesting the row one level down where the id sits under the TABLE column
///    name -- `id` for invoices/payments/movements/salaries, but `entry_id` for
///    journal entries.
///
/// Resolving flat-first then nested matters because a miss is silent: the
/// server id comes back null, `markReplaySynced` falls back to the local uuid,
/// the `serverId != localId` guard skips `putMapping`, and the row is still
/// marked synced -- so the mirror keeps a client uuid the server never issued
/// and nothing reports an error.
///
/// `settle_supplier` is deliberately absent: it enqueues with a null `localId`,
/// so its `result` nesting never reaches here.
String? resolveServerId(String entity, Map<String, dynamic> envelope) {
  final flatKey = switch (entity) {
    'invoices' => 'invoice_id',
    'payments' => 'payment_id',
    'employee_movements' => 'movement_id',
    'salaries' => 'salary_id',
    'journal_entries' => 'entry_id',
    _ => 'id',
  };
  final nested = nestedReplayRow(entity, envelope);
  final raw = envelope[flatKey] ??
      nested?[flatKey] ??
      nested?['id'] ??
      envelope['id'];
  return raw?.toString();
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
