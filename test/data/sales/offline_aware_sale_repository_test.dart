import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasad_erp/core/error/app_exception.dart';
import 'package:hasad_erp/data/offline/local_database.dart';
import 'package:hasad_erp/data/offline/local_store.dart';
import 'package:hasad_erp/data/offline/offline_write.dart';
import 'package:hasad_erp/data/sales/offline_aware_sale_repository.dart';
import 'package:hasad_erp/domain/invoices/invoice.dart';
import 'package:hasad_erp/domain/sales/sale_invoice_draft.dart';
import 'package:hasad_erp/domain/sales/sale_repository.dart';

/// Stands in for the live `create_sale_invoice` RPC repository.
class _FakeRpcSaleRepository implements SaleRepository {
  _FakeRpcSaleRepository({this.error});

  /// Thrown by `create` when set.
  final Object? error;

  int createCalls = 0;

  @override
  Future<SaleInvoiceResult> create(SaleInvoiceDraft draft) async {
    createCalls++;
    final err = error;
    if (err != null) throw err;
    return const SaleInvoiceResult(
      invoiceId: 'server-1',
      no: 'S-1',
      total: 20000,
      paid: 20000,
      remaining: 0,
      status: InvoiceStatus.paid,
      entryNo: 7,
    );
  }
}

void main() {
  late AppDatabase db;
  late DriftLocalStore store;
  late OfflineWriteCoordinator coordinator;

  const tenant = 'tenant-a';

  SaleInvoiceDraft draft() => SaleInvoiceDraft(
    customerId: 'c1',
    lines: [SaleLineDraft(productId: 'p1', qty: 2, price: 10000)],
    date: DateTime(2026, 9, 9),
    paid: 20000,
    paymentMethod: 'cash',
  );

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    store = DriftLocalStore(db);
    coordinator = OfflineWriteCoordinator(store, tenant);

    // Minimal mirror so the coordinator can journal the queued sale offline.
    for (final a in [
      ['a1', '1010', 'asset'],
      ['a3', '1020', 'asset'],
      ['a4', '1030', 'asset'],
      ['a7', '4010', 'revenue'],
    ]) {
      await store.upsertAccount(LocalAccountRow(
        id: a[0],
        tenantId: tenant,
        code: a[1],
        name: a[0],
        type: a[2],
        parentCode: null,
      ));
    }
    await store.upsertCustomer(LocalCustomerRow(
      id: 'c1',
      tenantId: tenant,
      name: 'عميل',
      phone: null,
      notes: null,
      createdAt: DateTime(2026, 1, 1),
      synced: false,
    ));
    await store.upsertProduct(LocalProductRow(
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
      createdAt: DateTime(2026, 1, 1),
      synced: false,
    ));
  });

  tearDown(() => db.close());

  group('OfflineAwareSaleRepository', () {
    test('happy path calls the RPC and never touches the queue', () async {
      final rpc = _FakeRpcSaleRepository();
      final repo = OfflineAwareSaleRepository(rpc, coordinator);

      final result = await repo.create(draft());

      expect(rpc.createCalls, 1);
      expect(result.invoiceId, 'server-1');
      expect(result.pending, isFalse);
      expect(await store.pendingSync(tenant), isEmpty);
      expect(await store.invoices(tenant, type: 'sale'), isEmpty);
    });

    test('a NetworkException falls back to the offline queue', () async {
      final rpc = _FakeRpcSaleRepository(error: const NetworkException());
      final repo = OfflineAwareSaleRepository(rpc, coordinator);

      final result = await repo.create(draft());

      expect(rpc.createCalls, 1, reason: 'the server must be tried first');
      expect(result.pending, isTrue, reason: 'the write was queued offline');
      final queued = await store.pendingSync(tenant);
      expect(queued, hasLength(1));
      expect(queued.single.rpc, 'create_sale_invoice');
    });

    test('a server-side ValidationException surfaces instead of queueing',
        () async {
      // A rejected invoice must NOT be silently retried offline forever; the
      // user has to see the real error.
      final rpc = _FakeRpcSaleRepository(
        error: const ValidationException('رصيد غير كافٍ'),
      );
      final repo = OfflineAwareSaleRepository(rpc, coordinator);

      await expectLater(
        repo.create(draft()),
        throwsA(isA<ValidationException>()),
      );
      expect(await store.pendingSync(tenant), isEmpty);
      expect(await store.invoices(tenant, type: 'sale'), isEmpty);
    });

    test('an UnknownException surfaces instead of queueing', () async {
      final rpc = _FakeRpcSaleRepository(error: const UnknownException());
      final repo = OfflineAwareSaleRepository(rpc, coordinator);

      await expectLater(repo.create(draft()), throwsA(isA<UnknownException>()));
      expect(await store.pendingSync(tenant), isEmpty);
    });

    test('the connectivity verdict can no longer force a write into the queue',
        () async {
      // This is the regression that shipped the false "offline" banner: the
      // repository used to take a `bool Function()` hint and route straight to
      // the coordinator when it said offline. The hint came from a probe that
      // could not succeed in a browser, so every sale was queued instead of
      // created - and the queue's own isOnline gate read the same broken hint,
      // so the invoice never reached the server. The constructor no longer
      // accepts a verdict at all; this test pins the server-first behavior.
      final rpc = _FakeRpcSaleRepository();
      final repo = OfflineAwareSaleRepository(rpc, coordinator);

      final result = await repo.create(draft());

      expect(rpc.createCalls, 1);
      expect(result.pending, isFalse);
      expect(result.invoiceId, 'server-1');
      expect(await store.pendingSync(tenant), isEmpty);
    });
  });
}
