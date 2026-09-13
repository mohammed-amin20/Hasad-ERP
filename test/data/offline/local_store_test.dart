import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasad_erp/data/offline/local_database.dart';
import 'package:hasad_erp/data/offline/local_store.dart';

void main() {
  late AppDatabase db;
  late DriftLocalStore store;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = DriftLocalStore(db);
  });

  tearDown(() => db.close());

  const tenantA = 'tenant-a';
  const tenantB = 'tenant-b';

  LocalCustomerRow customer(String id, String tenant) => LocalCustomerRow(
        id: id,
        tenantId: tenant,
        name: 'عميل $id',
        phone: '0599$id',
        notes: null,
        createdAt: DateTime(2026, 1, 1),
        synced: false,
      );

  test('store reports availability and exposes the database', () {
    expect(store.isAvailable, isTrue);
    expect(store.db, same(db));
  });

  test('master mirror replaces a tenant row set but leaves others intact', () async {
    await store.upsertCustomer(customer('c1', tenantA));
    await store.upsertCustomer(customer('c-other', tenantB));

    await store.mirrorCustomers(tenantA, [customer('c1', tenantA), customer('c2', tenantA)]);

    final list = await store.customers(tenantA);
    expect(list.map((r) => r.id), containsAll(['c1', 'c2']));
    expect(await store.customers(tenantB), hasLength(1));
  });

  test('master data upserts and reads for each entity', () async {
    await store.upsertSupplier(LocalSupplierRow(
      id: 's1', tenantId: tenantA, name: 'مورد1', phone: null, notes: null,
      dealType: 'commission', commissionRate: 20, createdAt: DateTime(2026, 1, 1),
      synced: false,
    ));
    await store.upsertProduct(LocalProductRow(
      id: 'p1', tenantId: tenantA, name: 'سلعة1', barcode: null, unit: 'قطعة',
      unitType: 'count', salePrice: 10000, purchasePrice: 6000, qty: 10,
      reorderLevel: 1, supplierId: 's1', commissionRate: 20, createdAt: null,
      synced: false,
    ));
    await store.upsertEmployee(LocalEmployeeRow(
      id: 'e1', tenantId: tenantA, name: 'موظف1', jobTitle: null, phone: null,
      baseSalary: 500_00, createdAt: DateTime(2026, 1, 1),
      synced: false,
    ));
    await store.upsertAccount(LocalAccountRow(
      id: 'a1', tenantId: tenantA, code: '1010', name: 'نقدية',
      type: 'asset', parentCode: null,
    ));

    expect((await store.suppliers(tenantA)).single.dealType, 'commission');
    expect((await store.products(tenantA)).single.qty, 10);
    expect((await store.employees(tenantA)).single.baseSalary, 500_00);
    expect((await store.accounts(tenantA)).single.code, '1010');

    await store.mirrorSuppliers(tenantA, [
      LocalSupplierRow(
        id: 's2', tenantId: tenantA, name: 'مورد2', phone: null, notes: null,
        dealType: 'direct', commissionRate: null, createdAt: null, synced: true,
      ),
    ]);
    expect((await store.suppliers(tenantA)).single.id, 's2');
  });

  test('invoices with items round-trip and delete cascades', () async {
    await store.upsertInvoice(LocalInvoiceRow(
      id: 'i1', tenantId: tenantA, type: 'sale', no: 'D-0001',
      partyId: 'c1', partyName: 'العميل', date: DateTime(2026, 1, 5),
      subtotal: 1000, total: 1000, paid: 0, remaining: 1000,
      status: 'unpaid', ownership: 'owned', requestId: 'req-1',
      synced: false, createdAt: null,
    ));
    await store.upsertInvoiceItems([
      LocalInvoiceItemRow(
        id: 'it1', tenantId: tenantA, invoiceId: 'i1', productId: 'p1',
        productName: 'سلعة', productUnit: 'قطعة', productUnitType: 'count',
        qty: 2, price: 500, total: 1000,
      ),
    ]);

    expect((await store.invoices(tenantA, type: 'sale')).single.no, 'D-0001');
    expect((await store.invoices(tenantA, type: 'purchase')), isEmpty);
    expect((await store.invoiceItems('i1')).single.qty, 2);

    await store.deleteInvoice('i1');
    expect(await store.invoices(tenantA), isEmpty);
    expect(await store.invoiceItems('i1'), isEmpty);
  });

  test('journal entries, payments, commissions, movements and salaries persist', () async {
    await store.insertJournalEntry(LocalJournalEntryRow(
      id: 'j1', tenantId: tenantA, date: DateTime(2026, 1, 5), memo: 'قيد',
      lines: '[{"account_code":"1010","debit":100,"credit":0}]',
      sourceType: 'sale', sourceId: 'i1', requestId: 'req-1', synced: false,
      createdAt: null,
    ));
    await store.upsertPayment(LocalPaymentRow(
      id: 'pay1', tenantId: tenantA, invoiceId: 'i1', partyId: 'c1',
      partyName: null, amount: 500, method: 'cash', date: DateTime(2026, 1, 6),
      note: null, requestId: 'req-2', synced: false, createdAt: null,
    ));
    await store.upsertCommissionDue(LocalCommissionDueRow(
      id: 'cd1', tenantId: tenantA, invoiceId: 'i1', productId: 'p1',
      supplierId: 's1', dueAmount: 200, status: 'pending', createdAt: null,
    ));
    await store.upsertEmployeeMovement(LocalEmployeeMovementRow(
      id: 'm1', tenantId: tenantA, employeeId: 'e1', month: '2026-01',
      direction: 'deduct', category: 'advance', amount: 100, date: DateTime(2026, 1, 7),
      note: null, requestId: 'req-3', synced: false, createdAt: null,
    ));
    await store.upsertSalary(LocalSalaryRow(
      id: 'sal1', tenantId: tenantA, employeeId: 'e1', month: '2026-01',
      paid: 400_00, netDue: 500_00, requestId: 'req-4', synced: false,
      createdAt: null,
    ));

    expect((await store.journalEntries(tenantA)).single.memo, 'قيد');
    expect((await store.payments(tenantA)).single.amount, 500);
    expect((await store.commissionDues(tenantA, supplierId: 's1')).single.dueAmount, 200);
    expect((await store.employeeMovements(tenantA, employeeId: 'e1')).single.category, 'advance');
    expect((await store.salaries(tenantA, employeeId: 'e1')).single.paid, 400_00);
  });

  test('sync queue is ordered, counted and transitions status', () async {
    Future<void> enqueue(String id, DateTime at) => store.enqueue(SyncQueueRow(
          id: id, tenantId: tenantA, rpc: 'create_sale_invoice', params: '{}',
          requestId: 'req-$id', entity: 'invoices', localId: 'i-$id',
          status: 'pending', attempts: 0, lastError: null,
          createdAt: at, updatedAt: at,
        ));

    await enqueue('a', DateTime(2026, 1, 1));
    await enqueue('b', DateTime(2026, 1, 2));
    await enqueue('c', DateTime(2026, 1, 3));

    await store.markSynced('a');
    await store.markFailed('c', 'network');

    expect(await store.pendingCount(tenantA), 1);
    final pending = await store.pendingSync(tenantA);
    expect(pending.single.id, 'b');

    final all = await db.select(db.syncQueueItems).get();
    expect(all.firstWhere((r) => r.id == 'c').status, 'failed');
  });

  test('id map resolves both directions and survives repeat put', () async {
    await store.putMapping(entity: 'customers', localId: 'l1', serverId: 'sv1');
    await store.putMapping(entity: 'customers', localId: 'l1', serverId: 'sv2');

    expect(await store.serverIdFor('customers', 'l1'), 'sv2');
    expect(await store.localIdFor('customers', 'sv2'), 'l1');
    expect(await store.serverIdFor('products', 'l1'), isNull);
  });

  test('report cache and settings round-trip and fall back to null', () async {
    expect(await store.report(tenantA, 'dashboard'), isNull);
    await store.putReport(tenantA, 'dashboard', '{"kpi":1}');
    expect(await store.report(tenantA, 'dashboard'), '{"kpi":1}');
    expect(await store.report(tenantB, 'dashboard'), isNull);

    await store.putSetting(tenantA, 'threshold', '7');
    expect(await store.getSetting(tenantA, 'threshold'), '7');
    await store.putSetting(tenantA, 'threshold', null);
    expect(await store.getSetting(tenantA, 'threshold'), isNull);
  });

  test('clearTenant wipes only the requested tenant', () async {
    await store.upsertCustomer(customer('c1', tenantA));
    await store.upsertCustomer(customer('c2', tenantB));
    await store.putReport(tenantA, 'dashboard', 'x');

    await store.clearTenant(tenantA);

    expect(await store.customers(tenantA), isEmpty);
    expect(await store.report(tenantA, 'dashboard'), isNull);
    expect((await store.customers(tenantB)).single.id, 'c2');
  });

  test('NullLocalStore degrades gracefully', () async {
    const none = NullLocalStore();
    expect(none.isAvailable, isFalse);
    expect(await none.customers(tenantA), isEmpty);
    await none.enqueue(SyncQueueRow(
      id: 'q', tenantId: tenantA, rpc: 'x', params: '{}', requestId: null,
      entity: null, localId: null, status: 'pending', attempts: 0,
      lastError: null, createdAt: DateTime(2026), updatedAt: DateTime(2026),
    ));
    expect(await none.pendingCount(tenantA), 0);
    expect(await none.serverIdFor('customers', 'l1'), 'l1');
  });
}