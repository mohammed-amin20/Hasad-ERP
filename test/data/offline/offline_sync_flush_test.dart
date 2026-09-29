import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasad_erp/data/offline/local_database.dart';
import 'package:hasad_erp/data/offline/local_store.dart';
import 'package:hasad_erp/data/offline/offline_customer_repository.dart';
import 'package:hasad_erp/data/offline/offline_sync.dart';
import 'package:hasad_erp/data/offline/offline_write.dart';
import 'package:hasad_erp/domain/customers/customer.dart';
import 'package:hasad_erp/domain/customers/customer_draft.dart';
import 'package:hasad_erp/domain/customers/customer_repository.dart';
import 'package:hasad_erp/domain/journal/manual_journal_draft.dart';
import 'package:hasad_erp/domain/purchases/purchase_invoice_draft.dart';
import 'package:hasad_erp/domain/salaries/salary_repository.dart';
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

/// Fails the RPCs named in [failFor] and succeeds for every other one, so a
/// test can park one leg while proving the rest of the pass still runs.
class _SelectiveSyncTarget implements SyncTarget {
  _SelectiveSyncTarget({required this.failFor});

  final Set<String> failFor;
  final List<String> calls = <String>[];

  @override
  Future<Map<String, dynamic>> rpc(
    String name,
    Map<String, dynamic> params,
  ) async {
    calls.add('rpc:$name');
    if (failFor.contains(name)) throw StateError('rejected $name');
    return <String, dynamic>{'id': 'server-$name'};
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
      expect(await store.serverIdFor(tenantId, 'invoices', 'draft-1'),
          'server-req-1');
      expect(await store.localIdFor(tenantId, 'invoices', 'server-req-1'),
          'draft-1');
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
      final serverId = await store.serverIdFor(tenantId, 'invoices', saleLocalId);
      expect(serverId, isNotNull);
      expect(await store.localIdFor(tenantId, 'invoices', serverId!), saleLocalId);

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

  group('offline sync flush (dependsOn ordering)', () {
    late AppDatabase db;
    late DriftLocalStore store;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      store = DriftLocalStore(db);
    });

    tearDown(() => db.close());

    /// Enqueues a leg, optionally declaring the legs it must follow.
    Future<void> enqueue(
      String id, {
      List<String> dependsOn = const [],
      String status = 'pending',
      int attempts = 0,
      int minute = 0,
    }) =>
        store.enqueue(SyncQueueRow(
          id: id,
          tenantId: tenantId,
          rpc: 'rpc_$id',
          op: 'rpc',
          params: '{}',
          requestId: 'req-$id',
          entity: null,
          localId: null,
          status: status,
          attempts: attempts,
          lastError: null,
          createdAt: DateTime.utc(2026, 1, 1, 0, minute),
          updatedAt: DateTime.utc(2026, 1, 1, 0, minute),
          dependsOn: dependsOn.isEmpty
              ? null
              : jsonEncode(dependsOn),
        ));

    test('a dependent leg waits until its prerequisite is synced', () async {
      // Deliberately enqueued CHILD-FIRST: the child's created_at sorts before
      // its parent's, so pure FIFO would replay it too early.
      await enqueue('child', dependsOn: ['parent'], minute: 0);
      await enqueue('parent', minute: 1);

      final target = _RecordingSyncTarget();
      final summary = await SyncFlusher(store, tenantId, target).flush();

      // The parent syncs, which unblocks the child later in the SAME pass.
      expect(summary.synced, 2);
      expect(summary.blocked, 0);
      expect(summary.remaining, 0);
      expect(target.calls, <String>['rpc:rpc_parent', 'rpc:rpc_child']);
    });

    test('a dependent leg is skipped (not failed) when its parent is still queued',
        () async {
      // The parent is a leg that will fail transiently this pass, so it stays
      // pending; the child must be left alone, not counted as a failure.
      await enqueue('parent', attempts: 0, minute: 0);
      await enqueue('child', dependsOn: ['parent'], minute: 1);

      // A target that fails only the parent, succeeds on the child.
      final flusher = SyncFlusher(
        store,
        tenantId,
        _SelectiveSyncTarget(failFor: {'rpc_parent'}),
      );
      final summary = await flusher.flush();

      expect(summary.synced, 0);
      expect(summary.failed, 1); // the parent
      expect(summary.blocked, 1); // the child, held back
      // Both are still pending: the parent is retrying and the child is waiting
      // on it, so the queue is not done.
      expect(summary.remaining, 2);
      expect(summary.done, isFalse);
    });

    test('a dependent leg is parked when its prerequisite is failed', () async {
      await enqueue('parent', status: 'failed', minute: 0);
      await enqueue('child', dependsOn: ['parent'], minute: 1);

      final target = _RecordingSyncTarget();
      final summary = await SyncFlusher(store, tenantId, target).flush();

      // The child can never succeed, so it is parked instead of burning retries.
      expect(summary.blocked, 0);
      expect(summary.failed, 1);
      expect(target.calls, isEmpty); // never even attempted
      expect(summary.remaining, 0);
      expect(await store.pendingCount(tenantId), 0);
    });

    test('a dependent leg is parked when its prerequisite is missing', () async {
      // The parent id is not in the queue at all (e.g. a forced tenant clear).
      await enqueue('child', dependsOn: ['vanished'], minute: 0);

      final target = _RecordingSyncTarget();
      final summary = await SyncFlusher(store, tenantId, target).flush();

      expect(summary.failed, 1);
      expect(target.calls, isEmpty);
      expect(summary.remaining, 0);
    });

    test('a self-referencing leg is parked as a circular dependency', () async {
      await enqueue('self', dependsOn: ['self']);

      final target = _RecordingSyncTarget();
      final summary = await SyncFlusher(store, tenantId, target).flush();

      expect(summary.failed, 1);
      expect(target.calls, isEmpty);
    });

    test('multiple prerequisites must ALL be synced before the leg runs',
        () async {
      await enqueue('a', minute: 0);
      await enqueue('b', minute: 1);
      await enqueue('c', dependsOn: ['a', 'b'], minute: 2);

      final flusher = SyncFlusher(
        store,
        tenantId,
        _SelectiveSyncTarget(failFor: {'rpc_b'}),
      );
      final summary = await flusher.flush();

      // 'b' failed, so 'c' is held regardless of 'a' having succeeded.
      expect(summary.synced, 1);
      expect(summary.failed, 1);
      expect(summary.blocked, 1);
    });

    test('an offline payment replays only after its pending invoice leg',
        () async {
      // The exact graph the Phase 1B coordinator emits: a `record_payment` leg
      // names the `create_sale_invoice` leg it was paid against. Enqueued
      // payment-first to prove the flusher re-scans rather than relying on
      // FIFO.
      await store.enqueue(SyncQueueRow(
        id: 'q-pay', tenantId: tenantId, rpc: 'record_payment', op: 'rpc',
        params: '{"p_invoice_id":"inv-1"}', requestId: 'req-pay',
        entity: 'payments', localId: 'pay-1', status: 'pending', attempts: 0,
        lastError: null, createdAt: DateTime.utc(2026, 1, 1, 0, 0),
        updatedAt: DateTime.utc(2026, 1, 1, 0, 0),
        dependsOn: jsonEncode(['q-inv']),
      ));
      await store.enqueue(SyncQueueRow(
        id: 'q-inv', tenantId: tenantId, rpc: 'create_sale_invoice', op: 'rpc',
        params: '{"p_customer_id":"c1"}', requestId: 'req-inv',
        entity: 'invoices', localId: 'inv-1', status: 'pending', attempts: 0,
        lastError: null, createdAt: DateTime.utc(2026, 1, 1, 0, 1),
        updatedAt: DateTime.utc(2026, 1, 1, 0, 1),
      ));

      final target = _RecordingSyncTarget();
      final summary = await SyncFlusher(store, tenantId, target).flush();

      expect(summary.synced, 2);
      expect(summary.blocked, 0);
      expect(summary.failed, 0);
      expect(summary.remaining, 0);
      // The invoice must reach the server before the payment against it; paying
      // an invoice the server has never seen would reject the RPC.
      expect(target.calls, <String>[
        'rpc:create_sale_invoice',
        'rpc:record_payment',
      ]);
    });

    test('dependencies are tenant-scoped: another tenant\'s pending leg does not block',
        () async {
      await store.enqueue(SyncQueueRow(
        id: 'other-tenant-parent',
        tenantId: 'tenant-B',
        rpc: 'rpc_other',
        op: 'rpc',
        params: '{}',
        requestId: 'req-other',
        entity: null,
        localId: null,
        status: 'pending',
        attempts: 0,
        lastError: null,
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      ));
      await enqueue('child', dependsOn: ['other-tenant-parent']);

      final target = _RecordingSyncTarget();
      final summary = await SyncFlusher(store, tenantId, target).flush();

      // The foreign parent is invisible to this tenant's queue, so the leg is
      // parked rather than silently "found" via the other tenant's data.
      expect(summary.failed, 1);
      expect(summary.remaining, 0);
    });

    test('a malformed dependsOn column degrades to "no dependencies"',
        () async {
      await store.enqueue(SyncQueueRow(
        id: 'corrupt',
        tenantId: tenantId,
        rpc: 'rpc_corrupt',
        op: 'rpc',
        params: '{}',
        requestId: 'req-corrupt',
        entity: null,
        localId: null,
        status: 'pending',
        attempts: 0,
        lastError: null,
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
        dependsOn: 'not json at all',
      ));

      final target = _RecordingSyncTarget();
      final summary = await SyncFlusher(store, tenantId, target).flush();

      // A corrupt column must not wedge the queue shut.
      expect(summary.synced, 1);
      expect(summary.remaining, 0);
    });
  });

  group('offline purchase flush', () {
    late AppDatabase db;
    late DriftLocalStore store;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      store = DriftLocalStore(db);
    });

    tearDown(() => db.close());

    test('an inline new product syncs before the purchase in one pass',
        () async {
      await _seedMasterData(store, tenantId);
      final writer = OfflineWriteCoordinator(store, tenantId);

      final purchase = await writer.writePurchase(PurchaseInvoiceDraft(
        supplierId: 's1',
        lines: [
          PurchaseLineDraft(
            newProduct: NewProductDraft(
              name: 'سلعة جديدة',
              unit: 'قطعة',
              salePrice: 12000,
            ),
            qty: 5,
            price: 7000,
          ),
        ],
        paid: 35000, // fully paid -> Cr 1010 cash, so no 2010 is needed
        paymentMethod: 'cash',
      ));
      expect(purchase.pending, isTrue);
      expect(await store.pendingCount(tenantId), 2);
      final purchaseRequestId =
          (await store.invoices(tenantId, type: 'purchase')).single.requestId!;

      final target = _RecordingSyncTarget();
      final summary = await SyncFlusher(store, tenantId, target).flush();

      expect(summary.synced, 2);
      expect(summary.blocked, 0);
      expect(summary.failed, 0);
      expect(summary.remaining, 0);
      expect(await store.pendingCount(tenantId), 0);

      final product = (await store.products(tenantId))
          .firstWhere((r) => r.name == 'سلعة جديدة');
      // tableUpsert echoed the client uuid (`onConflict: 'id'`), so the synced
      // product keeps the id the invoice item references.
      expect(product.synced, isTrue);
      expect(product.qty, 5);
      // The product leg replayed FIRST (it is a dependsOn of the purchase), and
      // the purchase then adopted the official number + server id.
      expect(target.calls, <String>[
        'tableUpsert:products:${product.id}',
        'rpc:create_purchase_invoice',
      ]);
      final invoice = (await store.invoices(tenantId, type: 'purchase')).single;
      expect(invoice.synced, isTrue);
      expect(invoice.no, 'PUR-$purchaseRequestId');
      expect(await store.serverIdFor(tenantId, 'invoices', purchase.invoiceId),
          'server-$purchaseRequestId');
    });

    test('a purchase replays after its pending supplier and product legs',
        () async {
      await _seedMasterData(store, tenantId);
      await store.enqueue(SyncQueueRow(
        id: 'q-s1', tenantId: tenantId, rpc: 'table:suppliers',
        op: 'table_crud', params: '{}', requestId: 'req-s1',
        entity: 'suppliers', localId: 's1', status: 'pending', attempts: 0,
        lastError: null, createdAt: DateTime.utc(2026, 1, 1, 0, 0),
        updatedAt: DateTime.utc(2026, 1, 1, 0, 0),
      ));
      await store.enqueue(SyncQueueRow(
        id: 'q-p1', tenantId: tenantId, rpc: 'table:products',
        op: 'table_crud', params: '{}', requestId: 'req-p1',
        entity: 'products', localId: 'p1', status: 'pending', attempts: 0,
        lastError: null, createdAt: DateTime.utc(2026, 1, 1, 0, 1),
        updatedAt: DateTime.utc(2026, 1, 1, 0, 1),
      ));

      final writer = OfflineWriteCoordinator(store, tenantId);
      final purchase = await writer.writePurchase(PurchaseInvoiceDraft(
        supplierId: 's1',
        lines: [PurchaseLineDraft(productId: 'p1', qty: 1, price: 6000)],
        paid: 6000, // full payment -> Cr 1010 cash
        paymentMethod: 'cash',
      ));
      expect(await store.pendingCount(tenantId), 3);

      final target = _RecordingSyncTarget();
      final summary = await SyncFlusher(store, tenantId, target).flush();

      expect(summary.synced, 3);
      expect(summary.blocked, 0);
      expect(summary.failed, 0);
      expect(summary.remaining, 0);

      // The two master legs replay first (in either order), the purchase last.
      expect(
        target.calls.indexOf('rpc:create_purchase_invoice'),
        target.calls.length - 1,
      );
      expect(
        target.calls,
        containsAll(
            ['tableUpsert:suppliers:s1', 'tableUpsert:products:p1']),
      );
      final requestId =
          (await store.invoices(tenantId, type: 'purchase')).single.requestId;
      expect(
        await store.serverIdFor(tenantId, 'invoices', purchase.invoiceId),
        'server-$requestId',
      );
    });

    test(
        'a duplicate purchase replay adopts the official number from the'
        ' nested envelope', () async {
      const c = _EnvelopeCase(
        entity: 'invoices',
        rpc: 'create_purchase_invoice',
        serverId: 'sv-77',
        officialNo: 'PUR-000077',
        flat: <String, dynamic>{},
        nested: <String, dynamic>{},
      );
      await _seedMirrorRow(store, tenantId, c, 'local-1');
      await _enqueueLeg(store, tenantId, c, 'local-1');

      final flusher = SyncFlusher(
        store,
        tenantId,
        _ShapedEnvelopeSyncTarget(envelopes: {
          c.rpc: <String, dynamic>{
            'duplicate': true,
            'invoice': <String, dynamic>{
              'id': 'sv-77',
              'no': 'PUR-000077',
              'total': 60000,
            },
          },
        }),
      );
      expect((await flusher.flush()).synced, 1);

      final invoice = (await store.invoices(tenantId)).single;
      expect(invoice.no, 'PUR-000077');
      expect(invoice.synced, isTrue);
      expect(await store.serverIdFor(tenantId, 'invoices', 'local-1'), 'sv-77');
    });
  });

  group('offline salaries & movements flush', () {
    late AppDatabase db;
    late DriftLocalStore store;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      store = DriftLocalStore(db);
      await _seedMasterData(store, tenantId);
    });

    tearDown(() => db.close());

    Future<void> seedEmployeeAndSalaryAccounts() async {
      await store.upsertAccount(LocalAccountRow(
        id: 'a6', tenantId: tenantId, code: '2030', name: 'ذمم دائنة للرواتب',
        type: 'liability', parentCode: null,
      ));
      await store.upsertAccount(LocalAccountRow(
        id: 'a8', tenantId: tenantId, code: '5030', name: 'أجور',
        type: 'expense', parentCode: null,
      ));
      await store.upsertEmployee(LocalEmployeeRow(
        id: 'e1', tenantId: tenantId, name: 'موظف', jobTitle: 'sales',
        phone: null, baseSalary: 500000, createdAt: DateTime.utc(2026, 1, 1),
        synced: false,
      ));
    }

    test('a movement and a salary drain after a pending employee leg',
        () async {
      await seedEmployeeAndSalaryAccounts();
      await store.enqueue(SyncQueueRow(
        id: 'q-empl', tenantId: tenantId, rpc: 'table:employees',
        op: 'table_crud', params: '{}', requestId: 'req-e',
        entity: 'employees', localId: 'e1', status: 'pending', attempts: 0,
        lastError: null, createdAt: DateTime.utc(2026, 1, 1, 0, 0),
        updatedAt: DateTime.utc(2026, 1, 1, 0, 0),
      ));

      final writer = OfflineWriteCoordinator(store, tenantId);
      await writer.addMovement(MovementDraft(
        employeeId: 'e1',
        month: DateTime(2026, 9, 1),
        direction: 'out',
        category: 'advance',
        amount: 100000,
      ));
      await writer.paySalary(SalaryDraft(
        employeeId: 'e1',
        month: DateTime(2026, 9, 1),
        paid: 400000,
        method: 'cash',
      ));
      expect(await store.pendingCount(tenantId), 3);

      final target = _RecordingSyncTarget();
      final summary = await SyncFlusher(store, tenantId, target).flush();

      expect(summary.synced, 3);
      expect(summary.blocked, 0);
      expect(summary.failed, 0);
      expect(summary.remaining, 0);
      expect(await store.pendingCount(tenantId), 0);

      // The employee (a dependsOn of both legs) replays before the salary RPCs.
      final employeeAt = target.calls.indexOf('tableUpsert:employees:e1');
      expect(employeeAt, isNot(-1));
      for (final rpc in ['rpc:add_employee_movement', 'rpc:pay_salary']) {
        final at = target.calls.indexOf(rpc);
        expect(at, greaterThan(employeeAt), reason: '$rpc must replay after the employee');
      }
      expect(await store.employeeMovements(tenantId), hasLength(1));
      expect(await store.salaries(tenantId), hasLength(1));
    });

    test('a nested duplicate replay maps id and never duplicates mirror rows',
        () async {
      await seedEmployeeAndSalaryAccounts();
      final writer = OfflineWriteCoordinator(store, tenantId);
      final movement = await writer.addMovement(MovementDraft(
        employeeId: 'e1',
        month: DateTime(2026, 9, 1),
        direction: 'out',
        category: 'advance',
        amount: 100000,
      ));
      final salary = await writer.paySalary(SalaryDraft(
        employeeId: 'e1',
        month: DateTime(2026, 9, 1),
        paid: 400000,
        method: 'cash',
      ));
      expect(await store.employeeMovements(tenantId), hasLength(1));
      expect(await store.salaries(tenantId), hasLength(1));

      // The server already committed both requests (timed-out originals), so it
      // answers the nested duplicate envelopes with its stamped ids.
      final flusher = SyncFlusher(
        store,
        tenantId,
        _ShapedEnvelopeSyncTarget(envelopes: {
          'add_employee_movement': <String, dynamic>{
            'duplicate': true,
            'movement': <String, dynamic>{'id': 'sv-mov', 'amount': 100000},
          },
          'pay_salary': <String, dynamic>{
            'duplicate': true,
            'salary': <String, dynamic>{'id': 'sv-sal'},
          },
        }),
      );
      expect((await flusher.flush()).synced, 2);
      expect(await store.employeeMovements(tenantId), hasLength(1),
          reason: 'a retried push must never create a second local movement');
      expect(await store.salaries(tenantId), hasLength(1),
          reason: 'a retried push must never create a second local salary');
      expect(await store.pendingCount(tenantId), 0);
      expect(
        await store.serverIdFor(tenantId, 'employee_movements',
            movement.movementId!),
        'sv-mov',
      );
      expect(
        await store.serverIdFor(tenantId, 'salaries', salary.salaryId!),
        'sv-sal',
      );

      // Retry after success is a no-op.
      expect((await flusher.flush()).synced, 0);
      expect(await store.pendingCount(tenantId), 0);
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

  group('replayed identity resolves from BOTH response families', () {
    late AppDatabase db;
    late DriftLocalStore store;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      store = DriftLocalStore(db);
    });

    tearDown(() => db.close());

    for (final c in _envelopeCases) {
      test('${c.entity}: a FLAT success envelope writes the id mapping',
          () async {
        await _seedMirrorRow(store, tenantId, c, 'local-1');
        await _enqueueLeg(store, tenantId, c, 'local-1');

        final flusher = SyncFlusher(
          store,
          tenantId,
          _ShapedEnvelopeSyncTarget(envelopes: {c.rpc: c.flat}),
        );
        final summary = await flusher.flush();

        expect(summary.synced, 1);
        expect(await flusher.pendingCount(), 0);
        expect(await store.serverIdFor(tenantId, c.entity, 'local-1'),
            c.serverId);
        expect(await store.localIdFor(tenantId, c.entity, c.serverId), 'local-1');
        expect(await _syncedFlag(store, tenantId, c.entity, 'local-1'), isTrue);
        if (c.officialNo != null) {
          expect((await store.invoices(tenantId)).single.no, c.officialNo);
        }
      });

      test('${c.entity}: a NESTED duplicate/replay envelope writes the id mapping',
          () async {
        await _seedMirrorRow(store, tenantId, c, 'local-1');
        await _enqueueLeg(store, tenantId, c, 'local-1');

        final flusher = SyncFlusher(
          store,
          tenantId,
          _ShapedEnvelopeSyncTarget(envelopes: {c.rpc: c.nested}),
        );
        final summary = await flusher.flush();

        expect(summary.synced, 1);
        expect(await flusher.pendingCount(), 0);
        // Without the nested fallback this is null, no mapping is written, and
        // the row is still marked synced -- a silent wrong identity.
        expect(await store.serverIdFor(tenantId, c.entity, 'local-1'),
            c.serverId);
        expect(await store.localIdFor(tenantId, c.entity, c.serverId), 'local-1');
        expect(await _syncedFlag(store, tenantId, c.entity, 'local-1'), isTrue);
        if (c.officialNo != null) {
          expect((await store.invoices(tenantId)).single.no, c.officialNo);
        }
      });
    }

    test('a real create_journal_entry leg drains and maps the official entry_id',
        () async {
      await _seedMasterData(store, tenantId);
      final entry = await OfflineWriteCoordinator(store, tenantId)
          .createJournal(ManualJournalDraft(
            date: DateTime.utc(2026, 1, 15),
            memo: 'قيد يدوي',
            lines: [
              ManualJournalLineDraft(accountId: 'a1', debit: 3000),
              ManualJournalLineDraft(accountId: 'a3', credit: 3000),
            ],
          ));

      final flusher = SyncFlusher(
        store,
        tenantId,
        _ShapedEnvelopeSyncTarget(envelopes: {
          'create_journal_entry': <String, dynamic>{
            'entry_id': 'sv-je-1',
            'entry_no': 77,
            'total': 3000,
          },
        }),
      );
      final summary = await flusher.flush();

      expect(summary.synced, 1);
      expect(await flusher.pendingCount(), 0);
      final mirror = (await store.journalEntries(tenantId)).single;
      expect(mirror.synced, isTrue);
      expect(await store.serverIdFor(tenantId, 'journal_entries', entry.entryId),
          'sv-je-1');
      expect(await store.localIdFor(tenantId, 'journal_entries', 'sv-je-1'),
          entry.entryId);
    });

    test('a duplicate journal replay maps entry_id without a second mirror row',
        () async {
      await _seedMasterData(store, tenantId);
      final entry = await OfflineWriteCoordinator(store, tenantId)
          .createJournal(ManualJournalDraft(
            date: DateTime.utc(2026, 1, 15),
            memo: 'قيد يدوي',
            lines: [
              ManualJournalLineDraft(accountId: 'a1', debit: 3000),
              ManualJournalLineDraft(accountId: 'a3', credit: 3000),
            ],
          ));
      expect(await store.journalEntries(tenantId), hasLength(1));

      // First push: the server already committed this request, so it answers
      // the nested duplicate envelope with the real entry_id (a timed-out
      // original response looks exactly like this).
      final flusher = SyncFlusher(
        store,
        tenantId,
        _ShapedEnvelopeSyncTarget(envelopes: {
          'create_journal_entry': <String, dynamic>{
            'duplicate': true,
            'entry': <String, dynamic>{'entry_id': 'sv-je-9', 'entry_no': 9},
          },
        }),
      );
      expect((await flusher.flush()).synced, 1);
      expect(await store.journalEntries(tenantId), hasLength(1),
          reason: 'a retried push must never create a second local entry');
      expect(await store.serverIdFor(tenantId, 'journal_entries', entry.entryId),
          'sv-je-9');

      // Retry after success is a no-op: nothing left to replay, no duplicates.
      expect((await flusher.flush()).synced, 0);
      expect(await flusher.pendingCount(), 0);
    });

    test('invoices: the official number is adopted from the NESTED shape',
        () async {
      const c = _EnvelopeCase(
        entity: 'invoices',
        rpc: 'create_sale_invoice',
        serverId: 'sv-77',
        officialNo: 'SALE-000077',
        flat: <String, dynamic>{},
        nested: <String, dynamic>{},
      );
      await _seedMirrorRow(store, tenantId, c, 'local-1');
      await _enqueueLeg(store, tenantId, c, 'local-1');

      final flusher = SyncFlusher(
        store,
        tenantId,
        _ShapedEnvelopeSyncTarget(envelopes: {
          c.rpc: <String, dynamic>{
            'duplicate': true,
            'invoice': <String, dynamic>{
              'id': 'sv-77',
              'no': 'SALE-000077',
              'total': 20000,
            },
          },
        }),
      );
      expect((await flusher.flush()).synced, 1);

      final invoice = (await store.invoices(tenantId)).single;
      expect(invoice.no, 'SALE-000077');
      expect(invoice.synced, isTrue);
      expect(await store.serverIdFor(tenantId, 'invoices', 'local-1'), 'sv-77');
    });

    test('journal_entries: the inner key is entry_id, not id', () async {
      const c = _EnvelopeCase(
        entity: 'journal_entries',
        rpc: 'create_journal_entry',
        serverId: 'sv-je',
        flat: <String, dynamic>{},
        nested: <String, dynamic>{},
      );

      // The replay payload carries entry_id and NO id key, so a resolver that
      // only looked for the table column name would come back empty.
      expect(
        resolveServerId('journal_entries', <String, dynamic>{
          'duplicate': true,
          'entry': <String, dynamic>{'entry_id': 'sv-je', 'entry_no': 12},
        }),
        'sv-je',
      );
      expect(
        resolveServerId('journal_entries', <String, dynamic>{'entry_id': 'sv-je'}),
        'sv-je',
      );

      await _seedMirrorRow(store, tenantId, c, 'local-1');
      await _enqueueLeg(store, tenantId, c, 'local-1');
      final flusher = SyncFlusher(
        store,
        tenantId,
        _ShapedEnvelopeSyncTarget(envelopes: {
          c.rpc: <String, dynamic>{
            'duplicate': true,
            'entry': <String, dynamic>{'entry_id': 'sv-je', 'entry_no': 12},
          },
        }),
      );
      expect((await flusher.flush()).synced, 1);
      expect(await store.serverIdFor(tenantId, 'journal_entries', 'local-1'),
          'sv-je');
    });

    test('a loosely-typed nested map is still unwrapped', () async {
      // Defensive re-key: `is Map<String, dynamic>` would reject this and
      // silently resolve to null, reinstating the exact bug being fixed.
      final loose = <String, dynamic>{
        'duplicate': true,
        'entry': <dynamic, dynamic>{'entry_id': 'sv-loose'},
      };
      expect(resolveServerId('journal_entries', loose), 'sv-loose');
    });

    test('an unknown entity falls back to a bare id key', () async {
      expect(
        resolveServerId('widgets', <String, dynamic>{'id': 'sv-w'}),
        'sv-w',
      );
      expect(nestedReplayRow('widgets', <String, dynamic>{'id': 'sv-w'}),
          isNull);
      expect(resolveServerId('invoices', <String, dynamic>{}), isNull);
    });
  });

  group('customers table_crud lifecycle', () {
    late AppDatabase db;
    late DriftLocalStore store;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      store = DriftLocalStore(db);
      await _seedMasterData(store, tenantId);
    });

    tearDown(() => db.close());

    test('a customer create replays before the sale that references it',
        () async {
      final writer = OfflineWriteCoordinator(store, tenantId);
      final customer = await writer.writeCustomer(
        const CustomerDraft(name: 'عميل', phone: '0599111222'),
      );
      final sale = await writer.writeSale(SaleInvoiceDraft(
        customerId: customer.id,
        lines: [SaleLineDraft(productId: 'p1', qty: 2, price: 10000)],
        date: DateTime.utc(2026, 9, 9),
        paid: 20000,
        paymentMethod: 'cash',
      ));
      expect(sale.pending, isTrue);
      expect(await store.pendingCount(tenantId), 2);

      final customerLeg =
          (await store.queueLegsFor(tenantId, entity: 'customers')).single;
      expect(customerLeg.localId, customer.id);
      final saleLegs = await store.queueLegsFor(tenantId, entity: 'invoices');
      expect(jsonDecode(saleLegs.single.dependsOn!), [customerLeg.id],
          reason: 'the sale must depend on the customer leg, not its id');

      final target = _RecordingSyncTarget();
      final summary = await SyncFlusher(store, tenantId, target).flush();

      expect(summary.synced, 2);
      expect(summary.failed, 0);
      expect(summary.remaining, 0);
      expect(await store.pendingCount(tenantId), 0);

      final customerAt =
          target.calls.indexOf('tableUpsert:customers:${customer.id}');
      expect(customerAt, isNot(-1));
      final saleAt = target.calls.indexOf('rpc:create_sale_invoice');
      expect(saleAt, greaterThan(customerAt),
          reason: 'the sale must replay only after its customer leg drained');
    });

    test('a create-update-delete series drains in order and deletes the mirror',
        () async {
      final writer = OfflineWriteCoordinator(store, tenantId);
      final customer = await writer.writeCustomer(
        const CustomerDraft(name: 'عميل', phone: '0599111222'),
      );
      await writer.updateCustomer(customer.id, const CustomerDraft(name: 'محدث'));
      await writer.deleteCustomer(customer.id);
      expect(await store.pendingCount(tenantId), 3);

      final target = _RecordingSyncTarget();
      final summary = await SyncFlusher(store, tenantId, target).flush();

      expect(summary.synced, 3);
      expect(summary.failed, 0);
      expect(summary.remaining, 0);
      expect(await store.pendingCount(tenantId), 0);

      // The server lost the row: the flush drops the mirror, clears the
      // pending-delete filter, and local reads no longer see the customer.
      expect(
        target.calls,
        contains('tableDelete:customers:${customer.id}'),
      );
      final remaining = await store.customers(tenantId);
      expect(remaining.map((r) => r.id), ['c1'],
          reason: 'only the seeded c1 survives after the replayed delete');
      expect(await store.pendingDeleteIds(tenantId, 'customers'), isEmpty);
    });

    test('a failed delete keeps the row locally and un-suppresses it',
        () async {
      final writer = OfflineWriteCoordinator(store, tenantId);
      final customer = await writer.writeCustomer(
        const CustomerDraft(name: 'عميل', phone: '0599111222'),
      );
      await writer.deleteCustomer(customer.id);
      expect(await store.pendingDeleteIds(tenantId, 'customers'), {customer.id});

      // Park the delete on its next failure so a single flush both replays the
      // create and parks the delete as failed. kSyncMaxAttempts is 5, so a leg
      // at attempts 4 that fails once crosses the budget and is parked.
      final delLeg = (await store.pendingSync(tenantId)).last;
      await store.requeueRetry(delLeg.id, 'x', 4);

      final summary =
          await SyncFlusher(store, tenantId, _ThrowingDeleteSyncTarget()).flush();
      expect(summary.failed, 1);

      // The delete is FAILED, not pending: the mirror keeps the row and reads
      // show the customer again (requirement #9).
      expect(await store.pendingDeleteIds(tenantId, 'customers'), isEmpty,
          reason: 'a FAILED delete must not suppress the row');
      expect(
        (await store.customers(tenantId)).map((r) => r.id),
        containsAll(['c1', customer.id]),
        reason: 'the mirror keeps the row after a failed delete',
      );

      final repo = OfflineCustomerRepository(
        _NoCustomersRepository(),
        store: store,
        tenantId: tenantId,
      );
      final visible = await repo.listAll();
      expect(visible.map((c) => c.id), containsAll(['c1', customer.id]),
          reason: 'the customer is locally visible again');
    });

    test('a refresh never resurrects a row whose delete is still pending',
        () async {
      final writer = OfflineWriteCoordinator(store, tenantId);
      final customer = await writer.writeCustomer(
        const CustomerDraft(name: 'عميل', phone: '0599111222'),
      );
      await writer.deleteCustomer(customer.id);

      // A refresh delivers the same customer (the server still has it): it
      // must not undo the pending delete.
      await store.mirrorCustomers(tenantId, [
        LocalCustomerRow(
          id: customer.id,
          tenantId: tenantId,
          name: 'عميل',
          phone: '0599111222',
          notes: null,
          createdAt: DateTime.utc(2026, 1, 1),
          synced: true,
        ),
      ]);

      expect(await store.pendingDeleteIds(tenantId, 'customers'), {customer.id},
          reason: 'the delete leg survives the refresh');
      final rows = await store.customers(tenantId);
      expect(rows.map((r) => r.id), containsAll(['c1', customer.id]),
          reason: 'the refresh must not undo the pending delete');
    });

    test('a refresh does not revert a pending edit', () async {
      final writer = OfflineWriteCoordinator(store, tenantId);
      final customer = await writer.writeCustomer(
        const CustomerDraft(name: 'عميل', phone: '0599111222'),
      );
      await writer.updateCustomer(customer.id, const CustomerDraft(name: 'محدث'));

      await store.mirrorCustomers(tenantId, [
        LocalCustomerRow(
          id: customer.id,
          tenantId: tenantId,
          name: 'الاسم القديم من الخادم',
          phone: '0599111222',
          notes: null,
          createdAt: DateTime.utc(2026, 1, 1),
          synced: true,
        ),
      ]);

      final rows = await store.customers(tenantId);
      final mine = rows.singleWhere((r) => r.id == customer.id);
      expect(mine.name, 'محدث',
          reason: 'a stale server copy must not revert the pending edit');
    });

    test('replayed table_crud legs are idempotent on the mirror', () async {
      final writer = OfflineWriteCoordinator(store, tenantId);
      final customer = await writer.writeCustomer(
        const CustomerDraft(name: 'عميل', phone: '0599111222'),
      );
      final target = _RecordingSyncTarget();
      final flusher = SyncFlusher(store, tenantId, target);
      expect((await flusher.flush()).synced, 1);
      expect(
        (await store.customers(tenantId)).where((r) => r.id == customer.id),
        hasLength(1),
        reason: 'the create leg keeps exactly one mirror row',
      );

      // A retried push (e.g. a lost response) upserts the same row again: no
      // second mirror row, no duplicate mapping.
      await store.enqueue(SyncQueueRow(
        id: 'again',
        tenantId: tenantId,
        rpc: 'table:customers',
        op: 'table_crud',
        params: jsonEncode({'name': customer.name, 'phone': customer.phone}),
        requestId: 'req-again',
        entity: 'customers',
        localId: customer.id,
        status: 'pending',
        attempts: 0,
        lastError: null,
        createdAt: DateTime.utc(2026, 1, 2),
        updatedAt: DateTime.utc(2026, 1, 2),
      ));
      expect((await flusher.flush()).synced, 1);
      expect(
        (await store.customers(tenantId)).where((r) => r.id == customer.id),
        hasLength(1),
        reason: 'a replayed upsert must not duplicate the mirror row',
      );

      // Same for the delete: replaying it twice is a harmless no-op — the
      // first replay removed the mirror, the second removes nothing.
      await writer.deleteCustomer(customer.id);
      expect((await flusher.flush()).synced, 1);
      expect(
        (await store.customers(tenantId)).where((r) => r.id == customer.id),
        isEmpty,
        reason: 'the replayed delete removes the mirror row',
      );

      await store.enqueue(SyncQueueRow(
        id: 'del-again',
        tenantId: tenantId,
        rpc: 'table:customers',
        op: 'table_crud',
        params: jsonEncode({'id': customer.id}),
        requestId: 'req-del-again',
        entity: 'customers',
        localId: customer.id,
        status: 'pending',
        attempts: 0,
        lastError: null,
        createdAt: DateTime.utc(2026, 1, 3),
        updatedAt: DateTime.utc(2026, 1, 3),
      ));
      expect((await flusher.flush()).synced, 1);
      expect(
        (await store.customers(tenantId)).where((r) => r.id == customer.id),
        isEmpty,
        reason: 'a replayed delete is still a no-op on the mirror',
      );
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

/// One entity's two response families, exactly as the migrations return them.
///
/// FLAT is a fresh write; NESTED is an idempotent replay
/// (`{'duplicate': true, '<entity>': {...}}`). Payloads are transcribed from
/// the migrations so a future contract change breaks these tests loudly:
///
///  * `create_sale_invoice` / `create_purchase_invoice` — 0007:281 / 0018:68
///  * `record_payment` — 0009:173 / 0009:96
///  * `add_employee_movement` — 0010:202 / 0010:148
///  * `pay_salary` — 0010:370 / 0010:273
///  * `create_journal_entry` — 0019:456 / 0019:383 (inner key is `entry_id`)
class _EnvelopeCase {
  const _EnvelopeCase({
    required this.entity,
    required this.rpc,
    required this.serverId,
    required this.flat,
    required this.nested,
    this.officialNo,
  });

  final String entity;
  final String rpc;
  final String serverId;
  final Map<String, dynamic> flat;
  final Map<String, dynamic> nested;
  final String? officialNo;
}

const _envelopeCases = <_EnvelopeCase>[
  _EnvelopeCase(
    entity: 'invoices',
    rpc: 'create_sale_invoice',
    serverId: 'sv-inv',
    officialNo: 'SALE-0001',
    flat: <String, dynamic>{'invoice_id': 'sv-inv', 'no': 'SALE-0001'},
    nested: <String, dynamic>{
      'duplicate': true,
      'invoice': <String, dynamic>{
        'id': 'sv-inv',
        'no': 'SALE-0001',
        'total': 20000,
      },
    },
  ),
  _EnvelopeCase(
    entity: 'payments',
    rpc: 'record_payment',
    serverId: 'sv-pay',
    flat: <String, dynamic>{'payment_id': 'sv-pay', 'remaining': 0},
    nested: <String, dynamic>{
      'duplicate': true,
      'payment': <String, dynamic>{'id': 'sv-pay', 'remaining': 0},
    },
  ),
  _EnvelopeCase(
    entity: 'employee_movements',
    rpc: 'add_employee_movement',
    serverId: 'sv-mov',
    flat: <String, dynamic>{'movement_id': 'sv-mov', 'amount': 5000},
    nested: <String, dynamic>{
      'duplicate': true,
      'movement': <String, dynamic>{'id': 'sv-mov', 'amount': 5000},
    },
  ),
  _EnvelopeCase(
    entity: 'salaries',
    rpc: 'pay_salary',
    serverId: 'sv-sal',
    flat: <String, dynamic>{'salary_id': 'sv-sal'},
    nested: <String, dynamic>{
      'duplicate': true,
      'salary': <String, dynamic>{'id': 'sv-sal'},
    },
  ),
  _EnvelopeCase(
    entity: 'journal_entries',
    rpc: 'create_journal_entry',
    serverId: 'sv-je',
    flat: <String, dynamic>{'entry_id': 'sv-je', 'entry_no': 12},
    nested: <String, dynamic>{
      'duplicate': true,
      'entry': <String, dynamic>{'entry_id': 'sv-je', 'entry_no': 12},
    },
  ),
];

/// Replays each RPC with a caller-supplied envelope, so one harness drives
/// every entity x response-family combination.
class _ShapedEnvelopeSyncTarget implements SyncTarget {
  _ShapedEnvelopeSyncTarget({required this.envelopes});

  final Map<String, Map<String, dynamic>> envelopes;

  @override
  Future<Map<String, dynamic>> rpc(
    String name,
    Map<String, dynamic> params,
  ) async =>
      envelopes[name] ?? <String, dynamic>{};

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

Future<void> _enqueueLeg(
  DriftLocalStore store,
  String tenantId,
  _EnvelopeCase c,
  String localId,
) =>
    store.enqueue(SyncQueueRow(
      id: 'q-1',
      tenantId: tenantId,
      rpc: c.rpc,
      op: 'rpc',
      params: jsonEncode(<String, dynamic>{'p_request_id': 'req-1'}),
      requestId: 'req-1',
      entity: c.entity,
      localId: localId,
      status: 'pending',
      attempts: 0,
      lastError: null,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    ));

Future<void> _seedMirrorRow(
  DriftLocalStore store,
  String tenantId,
  _EnvelopeCase c,
  String localId,
) async {
  final when = DateTime.utc(2026, 1, 1);
  switch (c.entity) {
    case 'invoices':
      await store.upsertInvoice(LocalInvoiceRow(
        id: localId,
        tenantId: tenantId,
        type: 'sale',
        no: 'D-A1B2C3D4',
        partyId: 'c1',
        partyName: 'عميل',
        date: when,
        subtotal: 20000,
        total: 20000,
        paid: 0,
        remaining: 20000,
        status: 'unpaid',
        ownership: 'owned',
        requestId: 'req-1',
        synced: false,
        createdAt: when,
      ));
    case 'payments':
      await store.upsertPayment(LocalPaymentRow(
        id: localId,
        tenantId: tenantId,
        invoiceId: 'c1',
        partyId: 'c1',
        partyName: 'عميل',
        amount: 20000,
        method: 'cash',
        date: when,
        note: null,
        requestId: 'req-1',
        synced: false,
        createdAt: when,
      ));
    case 'employee_movements':
      await store.upsertEmployeeMovement(LocalEmployeeMovementRow(
        id: localId,
        tenantId: tenantId,
        employeeId: 'e1',
        month: '2026-01',
        direction: 'debit',
        category: 'bonus',
        amount: 5000,
        date: when,
        note: null,
        requestId: 'req-1',
        synced: false,
        createdAt: when,
      ));
    case 'salaries':
      await store.upsertSalary(LocalSalaryRow(
        id: localId,
        tenantId: tenantId,
        employeeId: 'e1',
        month: '2026-01',
        paid: 500000,
        netDue: 500000,
        requestId: 'req-1',
        synced: false,
        createdAt: when,
      ));
    case 'journal_entries':
      await store.insertJournalEntry(LocalJournalEntryRow(
        id: localId,
        tenantId: tenantId,
        date: when,
        memo: 'قيد اختبار',
        lines: jsonEncode(const <Map<String, dynamic>>[
          <String, dynamic>{'account_code': '1010', 'debit': 100, 'credit': 0},
          <String, dynamic>{'account_code': '4010', 'debit': 0, 'credit': 100},
        ]),
        sourceType: 'auto',
        sourceId: null,
        requestId: 'req-1',
        synced: false,
        createdAt: when,
      ));
    default:
      fail('unhandled entity ${c.entity}');
  }
}

Future<bool> _syncedFlag(
  DriftLocalStore store,
  String tenantId,
  String entity,
  String localId,
) async {
  switch (entity) {
    case 'invoices':
      return (await store.invoices(tenantId)).single.synced;
    case 'payments':
      return (await store.payments(tenantId)).single.synced;
    case 'employee_movements':
      return (await store.employeeMovements(tenantId)).single.synced;
    case 'salaries':
      return (await store.salaries(tenantId)).single.synced;
    case 'journal_entries':
      return (await store.journalEntries(tenantId)).single.synced;
    default:
      fail('unhandled entity $entity');
  }
}

/// Rejects every table delete, so a customer delete leg parks `failed` and the
/// mirror row must survive (requirement #9: a failed sync keeps local data).
class _ThrowingDeleteSyncTarget extends _RecordingSyncTarget {
  @override
  Future<void> tableDelete(String entity, String id) async {
    calls.add('tableDelete:$entity:$id');
    throw StateError('server refused the delete');
  }
}

/// An online repository that serves nothing: used as the background-refresh
/// source for a mirror read that must resolve purely from the local store.
class _NoCustomersRepository implements CustomerRepository {
  @override
  Future<List<Customer>> listAll({String? search}) async => const [];

  @override
  Future<Customer?> getById(String id) async => null;

  @override
  Future<Customer> create(CustomerDraft draft) async => Customer(
        id: 'unused',
        name: draft.name,
        phone: draft.phone,
        notes: draft.notes,
      );

  @override
  Future<void> update({
    required String id,
    required CustomerDraft draft,
  }) async {}

  @override
  Future<void> delete(String id) async {}
}
