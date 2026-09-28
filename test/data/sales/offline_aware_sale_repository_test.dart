import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasad_erp/core/error/app_exception.dart';
import 'package:hasad_erp/data/offline/local_database.dart';
import 'package:hasad_erp/data/offline/local_store.dart';
import 'package:hasad_erp/data/offline/offline_write.dart';
import 'package:hasad_erp/data/sales/offline_aware_sale_repository.dart';
import 'package:hasad_erp/domain/sales/sale_invoice_draft.dart';

import '../offline/delegating_local_store.dart';

void main() {
  late AppDatabase db;
  late DriftLocalStore store;
  late OfflineWriteCoordinator coordinator;

  const tenant = 'tenant-a';

  SaleInvoiceDraft draft({String customerId = 'c1'}) => SaleInvoiceDraft(
        customerId: customerId,
        lines: [SaleLineDraft(productId: 'p1', qty: 2, price: 10000)],
        date: DateTime.utc(2026, 9, 9),
        paid: 20000,
        paymentMethod: 'cash',
      );

  /// Mirrors just enough data for the coordinator to journal a sale offline.
  Future<void> seed(DriftLocalStore target) async {
    for (final a in [
      ['a1', '1010', 'asset'],
      ['a3', '1020', 'asset'],
      ['a4', '1030', 'asset'],
      ['a7', '4010', 'revenue'],
    ]) {
      await target.upsertAccount(LocalAccountRow(
        id: a[0],
        tenantId: tenant,
        code: a[1],
        name: a[0],
        type: a[2],
        parentCode: null,
      ));
    }
    await target.upsertCustomer(LocalCustomerRow(
      id: 'c1',
      tenantId: tenant,
      name: 'عميل',
      phone: null,
      notes: null,
      createdAt: DateTime.utc(2026, 1, 1),
      synced: false,
    ));
    await target.upsertProduct(LocalProductRow(
      id: 'p1',
      tenantId: tenant,
      name: 'منتج',
      barcode: null,
      unit: 'قطعة',
      unitType: 'count',
      salePrice: 10000,
      purchasePrice: 6000,
      qty: 100,
      reorderLevel: 10,
      supplierId: null,
      commissionRate: null,
      createdAt: DateTime.utc(2026, 1, 1),
      synced: false,
    ));
  }

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    store = DriftLocalStore(db);
    coordinator = OfflineWriteCoordinator(store, tenant);
    await seed(store);
  });

  tearDown(() => db.close());

  group('OfflineAwareSaleRepository is local-first', () {
    test('a successful sale is committed locally and queued for replay',
        () async {
      final repo = OfflineAwareSaleRepository(coordinator);

      final result = await repo.create(draft());

      expect(result.pending, isTrue);
      expect(result.total, 20000);
      expect(result.paid, 20000);
      expect(result.remaining, 0);

      // The invoice is on the device immediately, and there is a replay leg.
      final invoices = await store.invoices(tenant, type: 'sale');
      expect(invoices, hasLength(1));
      expect(invoices.single.total, 20000);
      expect(invoices.single.synced, isFalse);
      expect(invoices.single.id, result.invoiceId);

      final queued = await store.pendingSync(tenant);
      expect(queued, hasLength(1));
      expect(queued.single.rpc, 'create_sale_invoice');
      expect(queued.single.localId, result.invoiceId);
      expect(queued.single.dependsOn, isNull,
          reason: 'no master data is pending, so there is no prerequisite');
    });

    test('every effect of the sale lands together (transactional write path)',
        () async {
      final repo = OfflineAwareSaleRepository(coordinator);

      final result = await repo.create(draft());

      // All five effects exist: invoice, its line, the journal, the stock
      // move, and the replay leg. These are separate tables, so a shared
      // transaction is the only thing that makes them all-or-nothing.
      expect(await store.invoices(tenant, type: 'sale'), hasLength(1));
      expect(await store.invoiceItems(result.invoiceId), hasLength(1));
      expect(await store.journalEntries(tenant), hasLength(1));
      expect((await store.products(tenant)).single.qty, 98,
          reason: 'stock moved by the 2 units sold');
      expect(await store.pendingSync(tenant), hasLength(1));
    });

    test('an invalid sale surfaces the error and commits nothing', () async {
      final repo = OfflineAwareSaleRepository(coordinator);

      await expectLater(
        repo.create(draft(customerId: 'missing-customer')),
        throwsA(isA<ValidationException>()),
      );

      // Atomic AND validated: a rejected draft leaves the device untouched.
      expect(await store.invoices(tenant, type: 'sale'), isEmpty);
      expect(await store.journalEntries(tenant), isEmpty);
      expect(await store.pendingSync(tenant), isEmpty);
      expect((await store.products(tenant)).single.qty, 100,
          reason: 'stock must be untouched by a rejected sale');
    });

    test('a sale with no usable local chart is refused without a partial write',
        () async {
      // A chart whose codes are all junk, so the engine's "required account not
      // found" validation fires even though account rows exist. The write must
      // fail cleanly rather than leave an invoice nothing will ever replay.
      final repo = OfflineAwareSaleRepository(
        OfflineWriteCoordinator(_JunkChartStore(store), tenant),
      );

      await expectLater(repo.create(draft()), throwsA(isA<AppException>()));

      expect(await store.invoices(tenant, type: 'sale'), isEmpty);
      expect(await store.journalEntries(tenant), isEmpty);
      expect(await store.pendingSync(tenant), isEmpty);
      expect((await store.products(tenant)).single.qty, 100,
          reason: 'stock must be untouched by a refused sale');
    });

    test('the transaction rolls back when the last step of the write throws',
        () async {
      // Proves the atomicity contract directly: the coordinator's FINAL step is
      // the queue `enqueue`, so a store that throws there has already staged
      // the invoice, its line, the journal and the stock move. If the write were
      // a sequence of independent commits, all four would survive as a
      // half-written sale with no replay leg — the exact corruption the
      // transaction exists to prevent.
      final repo = OfflineAwareSaleRepository(coordinator);
      final poisoning = OfflineWriteCoordinator(
        _ThrowOnEnqueueStore(store),
        tenant,
      );

      await expectLater(
        poisoning.writeSale(draft()),
        throwsA(isA<AppException>()),
        reason: 'the coordinator maps the raw failure to an AppException',
      );

      // Every effect of the aborted write is gone.
      expect(await store.invoices(tenant, type: 'sale'), isEmpty);
      expect(await store.journalEntries(tenant), isEmpty);
      expect((await store.products(tenant)).single.qty, 100);
      expect(await store.pendingSync(tenant), isEmpty);

      // The real coordinator is unaffected; a normal write still works.
      final result = await repo.create(draft());
      expect(result.pending, isTrue);
      expect(await store.invoices(tenant, type: 'sale'), hasLength(1));
    });
  });
}

/// Throws on the coordinator's final `enqueue` inside a sale, after every other
/// write in the transaction has already been staged.
class _ThrowOnEnqueueStore extends DelegatingLocalStore {
  _ThrowOnEnqueueStore(super.inner);

  @override
  Future<void> enqueue(SyncQueueRow row) =>
      throw StateError('queue write failed after the invoice was staged');
}

/// Reports a chart whose codes cannot balance anything, so the engine's
/// "required account not found" validation fires.
class _JunkChartStore extends DelegatingLocalStore {
  _JunkChartStore(super.inner);

  @override
  Future<List<LocalAccountRow>> accounts(String tenantId) async => [
        for (final a in await inner.accounts(tenantId))
          a.copyWith(code: 'junk-${a.code}'),
      ];
}
