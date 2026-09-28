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

  LocalCustomerRow customer(String id, String tenant, {bool synced = false}) =>
      LocalCustomerRow(
        id: id,
        tenantId: tenant,
        name: 'عميل $id',
        phone: '0599$id',
        notes: null,
        createdAt: DateTime(2026, 1, 1),
        synced: synced,
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

  group('background refresh never destroys pending local work', () {
    // A mirror is a server snapshot applied with delete+insert. When a write is
    // still queued, that is a data-loss bug: the user's offline record vanishes
    // and the replay then references a row that no longer exists locally.
    // Pending local rows are authoritative until the server acknowledges them.

    test('an offline-created customer survives a server refresh', () async {
      await store.upsertCustomer(customer('local-new', tenantA)); // synced:false
      await store.mirrorCustomers(tenantA, [customer('srv-1', tenantA, synced: true)]);

      final ids = (await store.customers(tenantA)).map((r) => r.id).toList();
      expect(ids, contains('local-new'),
          reason: 'the pending offline row must not be deleted by a refresh');
      expect(ids, contains('srv-1'), reason: 'the server row is applied');
    });

    test('a synced customer the server dropped is removed by the refresh',
        () async {
      await store.upsertCustomer(customer('gone', tenantA, synced: true));
      await store.mirrorCustomers(tenantA, [customer('kept', tenantA, synced: true)]);

      final ids = (await store.customers(tenantA)).map((r) => r.id).toList();
      expect(ids, isNot(contains('gone')),
          reason: 'the server is the truth for rows it has acknowledged');
      expect(ids, contains('kept'));
    });

    test('an offline EDIT is not reverted by a stale server copy', () async {
      // The user renamed the customer offline; the server snapshot still has
      // the old name because the edit has not replayed yet.
      await store.upsertCustomer(customer('c1', tenantA));
      await store.mirrorCustomers(tenantA, [
        customer('c1', tenantA, synced: true).copyWith(name: 'الاسم القديم'),
      ]);

      final row = (await store.customers(tenantA)).singleWhere((r) => r.id == 'c1');
      expect(row.name, 'عميل c1', reason: 'the local edit wins until it syncs');
      expect(row.synced, isFalse);
    });

    test('once the row is synced the server copy becomes authoritative',
        () async {
      await store.upsertCustomer(customer('c1', tenantA, synced: true));
      await store.mirrorCustomers(tenantA, [
        customer('c1', tenantA, synced: true).copyWith(name: 'من الخادم'),
      ]);

      final row = (await store.customers(tenantA)).single;
      expect(row.name, 'من الخادم');
    });

    test('the same protection applies to suppliers, products and employees',
        () async {
      await store.upsertSupplier(LocalSupplierRow(
        id: 's-local', tenantId: tenantA, name: 'مورد محلي', phone: null,
        notes: null, dealType: 'commission', commissionRate: 20,
        createdAt: DateTime(2026), synced: false,
      ));
      await store.upsertProduct(LocalProductRow(
        id: 'p-local', tenantId: tenantA, name: 'سلعة محلية', barcode: null,
        unit: 'قطعة', unitType: 'count', salePrice: 1, purchasePrice: 1, qty: 5,
        reorderLevel: 0, supplierId: null, commissionRate: null,
        createdAt: null, synced: false,
      ));
      await store.upsertEmployee(LocalEmployeeRow(
        id: 'e-local', tenantId: tenantA, name: 'موظف محلي', jobTitle: null,
        phone: null, baseSalary: 100, createdAt: DateTime(2026), synced: false,
      ));

      // Each refresh carries only a server row; the pending local rows must
      // still be there afterwards.
      await store.mirrorSuppliers(tenantA, [
        LocalSupplierRow(
          id: 's-srv', tenantId: tenantA, name: 'مورد خادمي', phone: null,
          notes: null, dealType: 'commission', commissionRate: 10,
          createdAt: DateTime(2026), synced: true,
        ),
      ]);
      await store.mirrorProducts(tenantA, [
        LocalProductRow(
          id: 'p-srv', tenantId: tenantA, name: 'سلعة خادمية', barcode: null,
          unit: 'قطعة', unitType: 'count', salePrice: 2, purchasePrice: 2,
          qty: 9, reorderLevel: 0, supplierId: null, commissionRate: null,
          createdAt: null, synced: true,
        ),
      ]);
      await store.mirrorEmployees(tenantA, [
        LocalEmployeeRow(
          id: 'e-srv', tenantId: tenantA, name: 'موظف خادمي', jobTitle: null,
          phone: null, baseSalary: 200, createdAt: DateTime(2026), synced: true,
        ),
      ]);

      expect((await store.suppliers(tenantA)).map((r) => r.id),
          containsAll(['s-local', 's-srv']));
      expect((await store.products(tenantA)).map((r) => r.id),
          containsAll(['p-local', 'p-srv']));
      expect((await store.employees(tenantA)).map((r) => r.id),
          containsAll(['e-local', 'e-srv']));
    });

    test('a refresh for one tenant never resurrects or drops another', () async {
      await store.upsertCustomer(customer('a-pending', tenantA));
      await store.upsertCustomer(customer('b-pending', tenantB));

      await store.mirrorCustomers(tenantA, [customer('a-srv', tenantA, synced: true)]);

      expect((await store.customers(tenantA)).map((r) => r.id),
          containsAll(['a-pending', 'a-srv']));
      expect((await store.customers(tenantB)).map((r) => r.id), ['b-pending'],
          reason: "another tenant's pending row is untouched");
    });
  });

  group('chart of accounts baseline', () {
    test('provisions the 14 defaults on a device that has never synced', () async {
      expect(await store.accounts(tenantA), isEmpty);

      final chart = await store.ensureBaselineChart(tenantA);

      expect(chart, hasLength(14));
      expect(
        chart.map((a) => a.code).toSet(),
        {
          '1010', '1015', '1020', '1030', '1040',
          '2010', '2030', '3010', '3020',
          '4010', '4020', '5010', '5020', '5030',
        },
      );
    });

    test('is a no-op when the tenant already has a real chart', () async {
      await store.upsertAccount(LocalAccountRow(
        id: 'a1', tenantId: tenantA, code: '1010', name: 'نقدية',
        type: 'asset', parentCode: null,
      ));

      final chart = await store.ensureBaselineChart(tenantA);

      expect(chart.map((a) => a.code), ['1010'],
          reason: 'defaults must never be layered over real accounts');
    });

    test('is per-tenant: one tenant\'s baseline does not leak into another',
        () async {
      await store.ensureBaselineChart(tenantA);
      await store.ensureBaselineChart(tenantB);

      final a = await store.accounts(tenantA);
      final b = await store.accounts(tenantB);

      expect(a, hasLength(14));
      expect(b, hasLength(14));
      expect(a.map((r) => r.code).toSet(), b.map((r) => r.code).toSet(),
          reason: 'both tenants get the same 14 codes');

      // The regression this pins: a fixed id like `baseline:1010` is the same
      // primary key in both tenants, so the second tenant's baseline either
      // collides with or overwrites the first tenant's rows.
      final shared = a.map((r) => r.id).toSet().intersection(b.map((r) => r.id).toSet());
      expect(shared, isEmpty, reason: 'baseline account ids must not be shared across tenants');
      expect(a.every((r) => r.tenantId == tenantA), isTrue);
      expect(b.every((r) => r.tenantId == tenantB), isTrue);
    });

    test('is idempotent: a second call does not duplicate or re-id rows',
        () async {
      final first = await store.ensureBaselineChart(tenantA);
      final second = await store.ensureBaselineChart(tenantA);

      expect(second.map((r) => r.id).toSet(), first.map((r) => r.id).toSet());
      expect(second, hasLength(14));
    });
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
    expect((await store.suppliers(tenantA)).map((r) => r.id), containsAll(['s1', 's2']),
        reason: 's1 is still queued, so the refresh must not delete it');
    expect((await store.suppliers(tenantA))
        .firstWhere((r) => r.id == 's2')
        .dealType, 'direct');
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
          id: id, tenantId: tenantA, rpc: 'create_sale_invoice', op: 'rpc',
          params: '{}',
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
    await store.putMapping(
        tenantId: tenantA, entity: 'customers', localId: 'l1', serverId: 'sv1');
    await store.putMapping(
        tenantId: tenantA, entity: 'customers', localId: 'l1', serverId: 'sv2');

    expect(await store.serverIdFor(tenantA, 'customers', 'l1'), 'sv2');
    expect(await store.localIdFor(tenantA, 'customers', 'sv2'), 'l1');
    expect(await store.serverIdFor(tenantA, 'products', 'l1'), isNull);
  });

  test('id map is tenant-scoped: the same localId in two tenants is distinct',
      () async {
    await store.putMapping(
        tenantId: tenantA, entity: 'customers', localId: 'l1', serverId: 'sv-a');
    await store.putMapping(
        tenantId: tenantB, entity: 'customers', localId: 'l1', serverId: 'sv-b');

    expect(await store.serverIdFor(tenantA, 'customers', 'l1'), 'sv-a');
    expect(await store.serverIdFor(tenantB, 'customers', 'l1'), 'sv-b');
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
    // Synced rows only: nothing local is at risk, so the clear proceeds.
    await store.upsertCustomer(customer('c1', tenantA, synced: true));
    await store.upsertCustomer(customer('c2', tenantB, synced: true));
    await store.putReport(tenantA, 'dashboard', 'x');

    final report = await store.clearTenant(tenantA);
    expect(report.cleared, isTrue);

    expect(await store.customers(tenantA), isEmpty);
    expect(await store.report(tenantA, 'dashboard'), isNull);
    expect((await store.customers(tenantB)).single.id, 'c2');
  });

  group('clearTenant refuses to destroy unsynced work', () {
    Future<void> enqueuePending() => store.enqueue(SyncQueueRow(
          id: 'q1',
          tenantId: tenantA,
          rpc: 'create_sale_invoice',
          op: 'rpc',
          params: '{}',
          requestId: 'r1',
          entity: 'invoices',
          localId: 'i1',
          status: 'pending',
          attempts: 0,
          lastError: null,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ));

    test('a pending queue item blocks the clear and reports the count',
        () async {
      await store.upsertCustomer(customer('c1', tenantA));
      await enqueuePending();

      final report = await store.clearTenant(tenantA);

      // Refused, and the caller is told exactly what is at stake.
      expect(report.cleared, isFalse);
      expect(report.pendingQueueItems, 1);
      expect(report.unsyncedMirrorRows, greaterThanOrEqualTo(0));
      expect(report.atRisk, greaterThan(0));

      // Nothing was destroyed.
      expect((await store.customers(tenantA)).single.id, 'c1');
      expect(await store.pendingCount(tenantA), 1);
    });

    test('a synced-only mirror does not block the clear', () async {
      await store.upsertCustomer(customer('c1', tenantA, synced: true));
      await store.enqueue(SyncQueueRow(
        id: 'q1',
        tenantId: tenantA,
        rpc: 'x',
        op: 'rpc',
        params: '{}',
        requestId: null,
        entity: null,
        localId: null,
        status: 'synced',
        attempts: 1,
        lastError: null,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ));

      final report = await store.clearTenant(tenantA);

      // Already-synced data is safe to drop: nothing local is at risk.
      expect(report.cleared, isTrue);
      expect(report.atRisk, 0);
      expect(await store.customers(tenantA), isEmpty);
    });

    test('force: true discards pending work and still reports what was lost',
        () async {
      await store.upsertCustomer(customer('c1', tenantA));
      await enqueuePending();

      final report = await store.clearTenant(tenantA, force: true);

      expect(report.cleared, isTrue);
      // The report still records the loss, so the UI can log/confirm it.
      expect(report.pendingQueueItems, 1);
      expect(await store.customers(tenantA), isEmpty);
      expect(await store.pendingCount(tenantA), 0);
    });

    test('a clear of one tenant never touches another tenant queue', () async {
      await enqueuePending();
      await store.enqueue(SyncQueueRow(
        id: 'q2',
        tenantId: tenantB,
        rpc: 'create_sale_invoice',
        op: 'rpc',
        params: '{}',
        requestId: 'r2',
        entity: 'invoices',
        localId: 'i2',
        status: 'pending',
        attempts: 0,
        lastError: null,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ));

      await store.clearTenant(tenantA, force: true);

      expect(await store.pendingCount(tenantA), 0);
      expect(await store.pendingCount(tenantB), 1);
    });
  });

  group('sign-out wipe (clearTenant force:true)', () {
    // Signing out must leave nothing of that workspace on a shared device:
    // not the mirrors, not the queue, and not the local->server id mappings.
    // The mappings are the easy one to forget -- they had no tenant column
    // until schema 5, so a sign-out silently left every resolved id behind.

    SyncQueueRow leg(String id, String tenant) => SyncQueueRow(
          id: id,
          tenantId: tenant,
          rpc: 'create_sale_invoice',
          op: 'rpc',
          params: '{}',
          requestId: 'req-$id',
          entity: 'invoices',
          localId: 'inv-$id',
          status: 'pending',
          attempts: 0,
          lastError: null,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        );

    test('with nothing pending it clears and reports zero losses', () async {
      await store.upsertCustomer(customer('c1', tenantA, synced: true));
      await store.putMapping(
          tenantId: tenantA, entity: 'customers', localId: 'l1', serverId: 'sv1');

      final report = await store.clearTenant(tenantA, force: true);

      expect(report.cleared, isTrue);
      expect(report.pendingQueueItems, 0);
      expect(report.unsyncedMirrorRows, 0);
      expect(await store.customers(tenantA), isEmpty);
      expect(await store.serverIdFor(tenantA, 'customers', 'l1'), isNull);
    });

    test('with pending work it reports the exact loss counts', () async {
      await store.enqueue(leg('q1', tenantA));
      await store.enqueue(leg('q2', tenantA));
      // synced:false so it counts as unsynced mirror data too
      await store.upsertCustomer(customer('c1', tenantA));

      final report = await store.clearTenant(tenantA, force: true);

      expect(report.cleared, isTrue);
      expect(report.pendingQueueItems, 2);
      expect(report.unsyncedMirrorRows, 1);
      expect(report.atRisk, 3, reason: '2 queued legs + 1 unsynced mirror row');
    });

    test('the queue is cleared, not marked synced', () async {
      await store.enqueue(leg('q1', tenantA));
      await store.clearTenant(tenantA, force: true);

      // A 'synced' leftover would be worse than nothing: the flusher would
      // believe the write reached the server.
      expect(await db.select(db.syncQueueItems).get(), isEmpty);
      expect(await store.pendingCount(tenantA), 0);
    });

    test('id mappings are cleared -- a stale one would resolve to a dead row',
        () async {
      await store.putMapping(
          tenantId: tenantA, entity: 'invoices', localId: 'l1', serverId: 'sv-a');
      await store.clearTenant(tenantA, force: true);

      expect(await store.serverIdFor(tenantA, 'invoices', 'l1'), isNull,
          reason: 'signing out must not leave a localId -> serverId remap behind');
    });

    test('a sign-out cannot touch another tenant\'s mirrors, queue or mappings',
        () async {
      await store.upsertCustomer(customer('a', tenantA));
      await store.upsertCustomer(customer('b', tenantB));
      await store.enqueue(leg('qa', tenantA));
      await store.enqueue(leg('qb', tenantB));
      await store.putMapping(
          tenantId: tenantA, entity: 'customers', localId: 'l1', serverId: 'sv-a');
      await store.putMapping(
          tenantId: tenantB, entity: 'customers', localId: 'l1', serverId: 'sv-b');

      await store.clearTenant(tenantA, force: true);

      expect(await store.customers(tenantA), isEmpty);
      expect((await store.customers(tenantB)).single.id, 'b');
      expect(await store.pendingCount(tenantA), 0);
      expect(await store.pendingCount(tenantB), 1);
      expect(await store.serverIdFor(tenantA, 'customers', 'l1'), isNull);
      expect(await store.serverIdFor(tenantB, 'customers', 'l1'), 'sv-b',
          reason: 'the same localId in another tenant must survive');
    });

    test('an orphaned pre-schema-5 mapping is not swept up by any tenant',
        () async {
      // The migration parks unattributable rows under a sentinel tenant. No
      // real sign-out may delete them (a wrong guess would delete another
      // workspace's mappings) and no lookup may return them.
      await store.putMapping(
          tenantId: '__unknown_tenant__',
          entity: 'customers',
          localId: 'l1',
          serverId: 'sv-old');

      await store.clearTenant(tenantA, force: true);

      expect(await store.serverIdFor(tenantA, 'customers', 'l1'), isNull);
      final remaining = await db.select(db.idMappings).get();
      expect(remaining, hasLength(1));
      expect(remaining.single.serverId, 'sv-old');
    });

    test('a second sign-out on the same tenant is a harmless no-op', () async {
      await store.upsertCustomer(customer('c1', tenantA));

      final first = await store.clearTenant(tenantA, force: true);
      final second = await store.clearTenant(tenantA, force: true);

      expect(first.cleared, isTrue);
      expect(second.cleared, isTrue);
      expect(second.pendingQueueItems, 0);
    });
  });

  test('NullLocalStore degrades gracefully', () async {
    const none = NullLocalStore();
    expect(none.isAvailable, isFalse);
    expect(await none.customers(tenantA), isEmpty);
    await none.enqueue(SyncQueueRow(
      id: 'q', tenantId: tenantA, rpc: 'x', op: 'rpc', params: '{}',
      requestId: null,
      entity: null, localId: null, status: 'pending', attempts: 0,
      lastError: null, createdAt: DateTime(2026), updatedAt: DateTime(2026),
    ));
    expect(await none.pendingCount(tenantA), 0);
    expect(await none.serverIdFor(tenantA, 'customers', 'l1'), 'l1');
  });
}