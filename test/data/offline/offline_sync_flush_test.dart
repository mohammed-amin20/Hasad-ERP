import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasad_erp/data/offline/local_database.dart';
import 'package:hasad_erp/data/offline/local_store.dart';
import 'package:hasad_erp/data/offline/offline_sync.dart';
import 'package:hasad_erp/data/offline/offline_write.dart';
import 'package:hasad_erp/domain/sales/sale_invoice_draft.dart';

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
    return <String, dynamic>{
      'invoice_id': 'server-${params['p_request_id'] ?? '1'}',
      'no': name == 'create_sale_invoice' ? 'SALE-${params['p_request_id'] ?? '1'}' : 'PUR-${params['p_request_id'] ?? '1'}',
    };
  }

  @override
  Future<Map<String, dynamic>> tableUpsert(
    String entity,
    String id,
    Map<String, dynamic> row,
  ) async {
    calls.add('tableUpsert:$entity:$id');
    return <String, dynamic>{...row, 'id': id};
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

    test('a failing leg stays queued for a bounded retry, then is parked',
        () async {
      final flusher = SyncFlusher(store, tenantId, _ThrowingSyncTarget());

      Future<void> enqueue(String id, String local) => store.enqueue(
            SyncQueueRow(
              id: id,
              tenantId: tenantId,
              rpc: 'create_sale_invoice',
              op: 'rpc',
              params: '{}',
              requestId: 'req-$id',
              entity: 'invoices',
              localId: local,
              status: 'pending',
              attempts: 3, // room for one retry, then parked at kSyncMaxAttempts
              lastError: null,
              createdAt: DateTime.utc(2026, 1, 1),
              updatedAt: DateTime.utc(2026, 1, 1),
            ),
          );

      await enqueue('q-1', 'draft-1');

      // Under the budget: failed leg is re-queued (attempts bumped), not lost.
      final first = await flusher.flush();
      expect(first.replayed, 1);
      expect(first.synced, 0);
      expect(first.failed, 1);
      expect(first.remaining, 1);
      expect(await flusher.pendingCount(), 1);

      // Exhausting the budget parks the leg (dropped from the pending queue).
      final second = await flusher.flush();
      expect(second.replayed, 1);
      expect(second.synced, 0);
      expect(second.failed, 1);
      expect(second.remaining, 0);
      expect(await flusher.pendingCount(), 0);
    });

    test('rpc replay writes back the official number and id mapping',
        () async {
      await store.upsertInvoice(LocalInvoiceRow(
        id: 'draft-1',
        tenantId: tenantId,
        type: 'sale',
        no: 'D-A1B2C3D4',
        partyId: 'c1',
        partyName: 'عميل',
        date: DateTime.utc(2026, 1, 1),
        subtotal: 20000,
        total: 20000,
        paid: 0,
        remaining: 20000,
        status: 'unpaid',
        ownership: 'owned',
        requestId: 'req-1',
        synced: false,
        createdAt: DateTime.utc(2026, 1, 1),
      ));
      await store.enqueue(SyncQueueRow(
        id: 'q-1',
        tenantId: tenantId,
        rpc: 'create_sale_invoice',
        op: 'rpc',
        params: jsonEncode(<String, dynamic>{'p_request_id': 'req-1'}),
        requestId: 'req-1',
        entity: 'invoices',
        localId: 'draft-1',
        status: 'pending',
        attempts: 0,
        lastError: null,
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      ));

      final flusher = SyncFlusher(store, tenantId, _RecordingSyncTarget());
      final summary = await flusher.flush();

      expect(summary.synced, 1);
      expect(await flusher.pendingCount(), 0);

      final invoice = (await store.invoices(tenantId)).single;
      expect(invoice.no, 'SALE-req-1');
      expect(invoice.synced, isTrue);
      expect(await store.serverIdFor('invoices', 'draft-1'), 'server-req-1');
      expect(await store.localIdFor('invoices', 'server-req-1'), 'draft-1');
    });

    test(
        'offline operation series flushes to correct final numbers (E2E)',
        () async {
      await _seedMasterData(store, tenantId);

      final writer = OfflineWriteCoordinator(store, tenantId);
      final sale = await writer.writeSale(SaleInvoiceDraft(
        customerId: 'c1',
        lines: [SaleLineDraft(productId: 'p1', qty: 2, price: 10000)],
        date: DateTime.utc(2026, 9, 9),
        paid: 20000,
        paymentMethod: 'cash',
      ));
      expect(sale.pending, isTrue);
      final saleLocalId = sale.invoiceId;
      final saleRequestId =
          (await store.invoices(tenantId)).single.requestId!;
      expect(
        (await store.pendingSync(tenantId)).single.localId,
        saleLocalId,
      );

      // A second, unpaid sale whose draft must survive replay unchanged.
      await writer.writeSale(SaleInvoiceDraft(
        customerId: 'c1',
        lines: [SaleLineDraft(productId: 'p1', qty: 1, price: 10000)],
        date: DateTime.utc(2026, 9, 9),
        paid: 0,
      ));
      expect(await store.pendingCount(tenantId), 2);

      final target = _OfficialEnvelopeSyncTarget();
      final flusher = SyncFlusher(store, tenantId, target);
      final summary = await flusher.flush();

      expect(summary.replayed, 2);
      expect(summary.synced, 2);
      expect(summary.failed, 0);
      expect(summary.remaining, 0);
      expect(await store.pendingCount(tenantId), 0);

      final synced = await store.invoices(tenantId);
      expect(synced, hasLength(2));
      final byId = {for (final r in synced) r.id: r};
      expect(byId[saleLocalId]!.synced, isTrue);
      expect(byId[saleLocalId]!.no, 'SALE-$saleRequestId');
      expect(byId[saleLocalId]!.total, 20000);
      expect(byId[saleLocalId]!.paid, 20000);
      expect(byId[saleLocalId]!.remaining, 0);
      // id_map remap: server prerolled uuid resolves back to the local one.
      final serverId = await store.serverIdFor('invoices', saleLocalId);
      expect(serverId, isNotNull);
      expect(await store.localIdFor('invoices', serverId!), saleLocalId);

      // Offline double-entry matches the online totals exactly.
      final entries = await store.journalEntries(tenantId);
      expect(entries, hasLength(2));
      final lines = <dynamic>[
        for (final e in entries)
          ...jsonDecode(e.lines) as List<dynamic>,
      ];
      int dr(String code) => lines
          .where((l) => l['account_code'] == code && (l['debit'] as int) > 0)
          .length;
      int cr(String code) => lines
          .where((l) => l['account_code'] == code && (l['credit'] as int) > 0)
          .length;
      expect(dr('1010'), 1); // cash sale
      expect(dr('1020'), 1); // credit sale
      expect(cr('4010'), 2); // revenue on both
    });
  });

  group('AutoSyncRunner', () {
    test('single kick drains until the queue is empty', () async {
      var flushes = 0;
      var pending = 2;
      final runner = AutoSyncRunner(
        flush: () async {
          flushes += 1;
          pending = 0; // each pass fully drains in this fake
          return const SyncFlushSummary(
            replayed: 1, synced: 1, failed: 0, remaining: 0,
          );
        },
        pendingCount: () async => pending,
        isOnline: () => true,
      );
      await runner.kick();
      expect(flushes, 1);
      expect(runner.isRunning, isFalse);
    });

    test('single-flight: a second kick is ignored while draining', () async {
      var flushes = 0;
      final gate = Completer<void>();
      var online = true;
      final runner = AutoSyncRunner(
        flush: () async {
          flushes += 1;
          await gate.future;
          return const SyncFlushSummary(
            replayed: 0, synced: 0, failed: 0, remaining: 0,
          );
        },
        pendingCount: () async => 0,
        isOnline: () => online,
      );
      final first = runner.kick();
      final second = runner.kick();
      expect(flushes, 1);
      gate.complete();
      await first;
      await second;
      expect(flushes, 1);
      expect(runner.isRunning, isFalse);
    });

    test('bails between passes when connectivity drops', () async {
      var flushes = 0;
      var online = true;
      final runner = AutoSyncRunner(
        flush: () {
          flushes += 1;
          // The pass leaves legs pending AND connectivity dies right after.
          online = false;
          return Future.value(const SyncFlushSummary(
            replayed: 1, synced: 0, failed: 1, remaining: 1,
          ));
        },
        pendingCount: () async => 1,
        isOnline: () => online,
      );
      await runner.kick();
      expect(flushes, 1); // no backoff retry after the first pass
      expect(runner.isRunning, isFalse);
    });
  });
}

Future<void> _seedMasterData(DriftLocalStore store, String tenantId) async {
  Future<void> acc(String id, String code, String name, String type) =>
      store.upsertAccount(LocalAccountRow(
        id: id,
        tenantId: tenantId,
        code: code,
        name: name,
        type: type,
        parentCode: null,
      ));
  await acc('a1', '1010', 'نقدية', 'asset');
  await acc('a2', '1020', 'ذمم مدينة', 'asset');
  await acc('a3', '4010', 'إيرادات مبيعات', 'revenue');
  await acc('a4', '1030', 'مخزون', 'asset');

  await store.upsertCustomer(LocalCustomerRow(
    id: 'c1',
    tenantId: tenantId,
    name: 'عميل',
    phone: '0599111222',
    notes: null,
    createdAt: DateTime.utc(2026, 1, 1),
    synced: false,
  ));
  await store.upsertSupplier(LocalSupplierRow(
    id: 's1',
    tenantId: tenantId,
    name: 'مورد',
    phone: null,
    notes: null,
    dealType: 'direct',
    commissionRate: null,
    createdAt: DateTime.utc(2026, 1, 1),
    synced: false,
  ));
  await store.upsertProduct(LocalProductRow(
    id: 'p1',
    tenantId: tenantId,
    name: 'سلعة',
    barcode: null,
    unit: 'قطعة',
    unitType: 'count',
    salePrice: 10000,
    purchasePrice: 6000,
    qty: 100,
    reorderLevel: 10,
    supplierId: 's1',
    commissionRate: null,
    createdAt: DateTime.utc(2026, 1, 1),
    synced: false,
  ));
}

/// Replays RPCs and returns realistic server envelopes: the official invoice
/// number derives from the request id (`no`), and the server-stamped uuid keys
/// the id_map remap.
class _OfficialEnvelopeSyncTarget implements SyncTarget {
  @override
  Future<Map<String, dynamic>> rpc(
    String name,
    Map<String, dynamic> params,
  ) async {
    final requestId = params['p_request_id'] as String? ?? 'x';
    if (name == 'record_payment' || name == 'settle_supplier') {
      return <String, dynamic>{
        'payment_id': 'sv-$requestId',
        'invoice_id': params['p_invoice_id'],
        'no': 'REC-$requestId',
        'paid': params['p_amount'],
        'remaining': 0,
        'status': 'paid',
      };
    }
    return <String, dynamic>{
      'invoice_id': 'sv-$requestId',
      'no': 'SALE-$requestId',
      'total': params['p_paid'] ?? 0,
      'paid': params['p_paid'] ?? 0,
      'remaining': 0,
      'status': 'paid',
    };
  }

  @override
  Future<Map<String, dynamic>> tableUpsert(
    String entity,
    String id,
    Map<String, dynamic> row,
  ) async =>
      <String, dynamic>{...row, 'id': id};

  @override
  Future<void> tableDelete(String entity, String id) async {}
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
