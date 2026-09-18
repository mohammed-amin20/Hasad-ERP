import 'package:flutter_test/flutter_test.dart';

import 'package:drift/native.dart';
import 'package:hasad_erp/data/offline/local_database.dart';
import 'package:hasad_erp/data/offline/local_store.dart';
import 'package:hasad_erp/data/offline/offline_sync.dart';

/// Records every replay leg the flusher sends, so a test can assert the queue
/// is drained exactly once (replay-safe by construction).
class _RecordingSyncTarget implements SyncTarget {
  final List<String> calls = <String>[];

  @override
  Future<Map<String, dynamic>> rpc(
    String name,
    Map<String, dynamic> params,
  ) async {
    calls.add('rpc:$name');
    return <String, dynamic>{'ok': true};
  }

  @override
  Future<Map<String, dynamic>> tableUpsert(
    String entity,
    String id,
    Map<String, dynamic> row,
  ) async {
    calls.add('tableUpsert:$entity:$id');
    return row;
  }

  @override
  Future<void> tableDelete(String entity, String id) async {
    calls.add('tableDelete:$entity:$id');
  }
}

void main() {
  const tenantId = 'tenant-A';

  group('offline sync flush (regression)', () {
    late AppDatabase db;
    late DriftLocalStore store;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      store = DriftLocalStore(db);
    });

    tearDown(() => db.close());

    test('drains each pending leg exactly once in FIFO order', () async {
      final target = _RecordingSyncTarget();
      final flusher = SyncFlusher(store, tenantId, target);
      final at = DateTime.utc(2026, 1, 1);

      Future<void> enqueue(String id, String op, String entity, String local) =>
          store.enqueue(SyncQueueRow(
            id: id,
            tenantId: tenantId,
            rpc: 'create_sale_invoice',
            op: op,
            params: '{}',
            requestId: 'req-$id',
            entity: entity,
            localId: local,
            status: 'pending',
            attempts: 0,
            lastError: null,
            createdAt: at,
            updatedAt: at,
          ));

      await enqueue('1', 'rpc', 'invoices', 'i-1');
      await enqueue('2', 'rpc', 'invoices', 'i-2');

      expect(await flusher.pendingCount(), 2);

      final summary = await flusher.flush();

      expect(summary.replayed, 2);
      expect(summary.synced, 2);
      expect(summary.failed, 0);
      expect(summary.remaining, 0);
      expect(target.calls, <String>[
        'rpc:create_sale_invoice',
        'rpc:create_sale_invoice',
      ]);
      expect(await flusher.pendingCount(), 0);
    });

    test('a failing leg is parked, not replayed, and reported as failed',
        () async {
      final flusher = SyncFlusher(store, tenantId, _ThrowingSyncTarget());
      await store.enqueue(SyncQueueRow(
        id: 'req-9',
        tenantId: tenantId,
        rpc: 'create_sale_invoice',
        op: 'rpc',
        params: '{}',
        requestId: 'req-9',
        entity: 'invoices',
        localId: 'i-9',
        status: 'pending',
        attempts: 0,
        lastError: null,
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      ));

      final summary = await flusher.flush();

      expect(summary.replayed, 1);
      expect(summary.synced, 0);
      expect(summary.failed, 1);
      expect(summary.remaining, 0);
      expect(await flusher.pendingCount(), 0);
    });
  });
}

class _ThrowingSyncTarget implements SyncTarget {
  @override
  Future<Map<String, dynamic>> rpc(
    String name,
    Map<String, dynamic> params,
  ) =>
      throw StateError('offline');

  @override
  Future<Map<String, dynamic>> tableUpsert(
    String entity,
    String id,
    Map<String, dynamic> row,
  ) =>
      throw StateError('offline');

  @override
  Future<void> tableDelete(String entity, String id) =>
      throw StateError('offline');
}
