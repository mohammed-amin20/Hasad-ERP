import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasad_erp/core/error/app_exception.dart';
import 'package:hasad_erp/data/invoices/invoice_repository.dart';
import 'package:hasad_erp/data/offline/local_database.dart';
import 'package:hasad_erp/data/offline/local_store.dart';
import 'package:hasad_erp/data/offline/offline_customer_repository.dart';
import 'package:hasad_erp/data/offline/offline_dashboard_repository.dart';
import 'package:hasad_erp/data/offline/offline_invoice_repository.dart';
import 'package:hasad_erp/data/offline/offline_report_repository.dart';
import 'package:hasad_erp/domain/accounts/account.dart';
import 'package:hasad_erp/domain/customers/customer.dart';
import 'package:hasad_erp/domain/customers/customer_draft.dart';
import 'package:hasad_erp/domain/customers/customer_repository.dart';
import 'package:hasad_erp/domain/dashboard/dashboard.dart';
import 'package:hasad_erp/domain/invoices/invoice.dart';
import 'package:hasad_erp/domain/products/product.dart';
import 'package:hasad_erp/domain/reports/balance_sheet.dart';
import 'package:hasad_erp/domain/reports/income_statement.dart';
import 'package:hasad_erp/domain/reports/ledger.dart';
import 'package:hasad_erp/domain/reports/report_repository.dart';
import 'package:hasad_erp/domain/reports/trial_balance.dart';

void main() {
  late AppDatabase db;
  late DriftLocalStore store;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = DriftLocalStore(db);
  });

  tearDown(() => db.close());

  const tenant = 'tenant-t';

  group('OfflineCustomerRepository', () {
    test('online reads mirror into the local store then serve', () async {
      final inner = _FakeCustomers([
        Customer(id: 'c1', name: 'أحمد', phone: '0599000001'),
        Customer(id: 'c2', name: 'سارة', phone: null),
      ], false);
      final repo = OfflineCustomerRepository(
        inner,
        store: store,
        tenantId: tenant,
      );

      final online = await repo.listAll();

      expect(online, hasLength(2));
      final mirrored = await store.customers(tenant);
      expect(mirrored, hasLength(2));
    });

    test('offline falls back to the mirrored rows and filters client-side',
        () async {
      await store.mirrorCustomers(tenant, [
        LocalCustomerRow(
          id: 'c1', tenantId: tenant, name: 'أحمد', phone: '0599', notes: null,
          synced: true,
        ),
        LocalCustomerRow(
          id: 'c2', tenantId: tenant, name: 'سارة', phone: '0500', notes: null,
          synced: true,
        ),
      ]);
      final repo = OfflineCustomerRepository(
        _FakeCustomers.offline(),
        store: store,
        tenantId: tenant,
      );

      final all = await repo.listAll();
      expect(all, hasLength(2));

      final search = await repo.listAll(search: 'سارة');
      expect(search.map((c) => c.id), ['c2']);
    });

    test('offline with an empty mirror surfaces an honest error (no silent [])',
        () async {
      final repo = OfflineCustomerRepository(
        _FakeCustomers.offline(),
        store: store,
        tenantId: tenant,
      );
      // A.5 cache-first: an empty mirror + unreachable remote throws honestly
      // instead of silently serving [].
      expect(
        () => repo.listAll(),
        throwsA(isA<NetworkException>()),
      );
    });

    test('create delegates online and mirrors the created row', () async {
      final inner = _FakeCustomers(const [], false);
      final repo = OfflineCustomerRepository(
        inner,
        store: store,
        tenantId: tenant,
      );

      await repo.create(const CustomerDraft(name: 'جديد'));

      expect(inner.created, hasLength(1));
      expect(await store.customers(tenant), hasLength(1));
    });
  });

  group('OfflineInvoiceRepository', () {
    test('online lists are cached under the list key', () async {
      final inner = _FakeInvoices([saleInvoice('I-1')], offline: false);
      final repo = OfflineInvoiceRepository(
        inner,
        store: store,
        tenantId: tenant,
      );

      await repo.list(type: 'sale');

      final cached = await store.report(tenant, 'inv:sale:all:_:_');
      expect(cached, isNotNull);
    });

    test('offline lists rehydrate from the cached envelope', () async {
      await _primeInvoiceList(store, tenant);

      final repo = OfflineInvoiceRepository(
        _FakeInvoices(const [], offline: true),
        store: store,
        tenantId: tenant,
      );

      final invoices = await repo.list(type: 'sale');
      expect(invoices, hasLength(1));
      expect(invoices.single.id, 'I-1');
      expect(invoices.single.partyName, 'أحمد');
    });

    test('offline items rehydrate with a unit type', () async {
      await _primeItemCache(store, tenant);

      final repo = OfflineInvoiceRepository(
        _FakeInvoices(const [], offline: true),
        store: store,
        tenantId: tenant,
      );

      final items = await repo.items('I-1');
      expect(items, hasLength(1));
      expect(items.single.productName, 'سلعة');
      expect(items.single.productUnitType, ProductUnitType.count);
    });

    test('unsynced local drafts merge on top of the offline cached list', () async {
      await _primeInvoiceList(store, tenant);
      await store.upsertInvoice(LocalInvoiceRow(
        id: 'D-draft1', tenantId: tenant, type: 'sale', no: 'D-DRAFT1',
        partyId: 'c2', partyName: 'سارة', date: DateTime(2026, 1, 20),
        subtotal: 50, total: 50, paid: 0, remaining: 50,
        status: 'unpaid', ownership: 'owned', requestId: 'rq', synced: false,
        createdAt: DateTime(2026, 1, 20),
      ));
      await store.upsertInvoice(LocalInvoiceRow(
        id: 'D-other', tenantId: tenant, type: 'purchase', no: 'D-OTHER',
        partyId: 's1', partyName: 'مورد', date: DateTime(2026, 1, 21),
        subtotal: 30, total: 30, paid: 30, remaining: 0,
        status: 'paid', ownership: 'owned', requestId: 'rq2', synced: false,
        createdAt: DateTime(2026, 1, 21),
      ));

      final repo = OfflineInvoiceRepository(
        _FakeInvoices(const [], offline: true),
        store: store,
        tenantId: tenant,
      );

      final invoices = await repo.list(type: 'sale');
      expect(invoices, hasLength(2)); // cached I-1 + draft D-draft1
      expect(invoices.map((i) => i.id).toSet(), {'I-1', 'D-draft1'});
      // Draft sorted newest-first on top of the cached base.
      expect(invoices.first.id, 'D-draft1');
    });

    test('draft items resolve locally when offline without a cache', () async {
      await store.upsertInvoice(LocalInvoiceRow(
        id: 'D-inv', tenantId: tenant, type: 'sale', no: 'D-INV',
        partyId: 'c1', partyName: 'أحمد', date: DateTime(2026, 1, 20),
        subtotal: 60, total: 60, paid: 0, remaining: 60,
        status: 'unpaid', ownership: 'owned', requestId: 'rq', synced: false,
        createdAt: DateTime(2026, 1, 20),
      ));
      await store.upsertInvoiceItems([
        LocalInvoiceItemRow(
          id: 'it1', tenantId: tenant, invoiceId: 'D-inv', productId: 'p1',
          productName: 'سلعة', productUnit: 'قطعة', productUnitType: 'count',
          qty: 3.0, price: 20, total: 60,
        ),
      ]);

      final repo = OfflineInvoiceRepository(
        _FakeInvoices(const [], offline: true),
        store: store,
        tenantId: tenant,
      );

      final items = await repo.items('D-inv');
      expect(items.single.productId, 'p1');
      expect(items.single.productUnitType, ProductUnitType.count);
      expect(items.single.total, 60);
    });
  });

  group('OfflineReportRepository', () {
    test('offline ledger rehydrates the cached statement', () async {
      await store.putReport(
        tenant,
        'ledger:a1:2026-01-01:2026-01-31',
        '''
        {"account_id":"a1","code":"1010","name":"نقدية","type":"asset",
         "from":"2026-01-01","to":"2026-01-31",
         "opening":0,"closing":100,
         "lines":[{"entry_no":1,"date":"2026-01-05","memo":"م","debit":100,"credit":0,"balance":100}]}
        ''',
      );
      final repo = OfflineReportRepository(
        _FakeReports.offline(),
        store: store,
        tenantId: tenant,
      );

      final statement = await repo.ledger(
        accountId: 'a1',
        from: DateTime(2026, 1, 1),
        to: DateTime(2026, 1, 31),
      );

      expect(statement.accountId, 'a1');
      expect(statement.lines.single.debit, 100);
      expect(statement.closing, 100);
      expect(statement.type, AccountType.asset);
    });

    test('online ledger caches under the range key', () async {
      final inner = _FakeReports(false);
      final repo = OfflineReportRepository(
        inner,
        store: store,
        tenantId: tenant,
      );

      await repo.ledger(
        accountId: 'a1',
        from: DateTime(2026, 1, 1),
        to: DateTime(2026, 1, 31),
      );

      final cached = await store.report(tenant, 'ledger:a1:2026-01-01:2026-01-31');
      expect(cached, contains('"closing":100'));
    });

    test('offline with no cache rethrows', () {
      final repo = OfflineReportRepository(
        _FakeReports.offline(),
        store: store,
        tenantId: tenant,
      );
      expect(
        () => repo.ledger(
          accountId: 'a1',
          from: DateTime(2026, 1, 1),
          to: DateTime(2026, 1, 31),
        ),
        throwsA(isA<NetworkException>()),
      );
    });
  });

  group('OfflineDashboardRepository', () {
    test('offline rehydrates the cached KPI envelope', () async {
      await store.putReport(
        tenant,
        'dashboard',
        '''
        {"today_sales":10,"today_purchases":0,"customer_debts":5,
         "supplier_debts":3,"month_expenses":2,"month_salaries":1,
         "net_profit_month":4,
         "last_7_days":[{"date":"2026-01-10","sales":10,"purchases":0}],
         "top_debtors":[{"customer_id":"c1","name":"أحمد","balance":5}],
         "low_stock":[{"product_id":"p1","name":"سلعة","qty":0,"reorder_level":1}]}
        ''',
      );
      final repo = OfflineDashboardRepository(
        _FakeDashboard.offline(),
        store: store,
        tenantId: tenant,
      );

      final summary = await repo.summary();

      expect(summary.todaySales, 10);
      expect(summary.topDebtors.single.balance, 5);
      expect(summary.lowStock.single.outOfStock, isTrue);
      expect(summary.netProfitMonth, 4);
    });

    test('online summary caches under the dashboard key', () async {
      final repo = OfflineDashboardRepository(
        _FakeDashboard.online(),
        store: store,
        tenantId: tenant,
      );

      await repo.summary();

      final cached = await store.report(tenant, 'dashboard');
      expect(cached, contains('"today_sales":10'));
    });
  });
}

/// Helpers ----------------------------------------------------------------

Future<void> _primeInvoiceList(DriftLocalStore store, String tenant) async {
  await store.putReport(
    tenant,
    'inv:sale:all:_:_',
    '['
    '{"id":"I-1","type":"sale","no":"1","party_id":"c1","party_name":"أحمد",'
    '"date":"2026-01-15","subtotal":100,"total":100,"paid":0,"remaining":100,'
    '"status":"unpaid","ownership":"owned"}'
    ']',
  );
}

Future<void> _primeItemCache(DriftLocalStore store, String tenant) async {
  await store.putReport(
    tenant,
    'invItems:I-1',
    '['
    '{"product_id":"p1","product_name":"سلعة","product_unit":"قطعة",'
    '"product_unit_type":"count","qty":2.0,"price":50,"total":100}'
    ']',
  );
}

Invoice saleInvoice(String id) => Invoice(
      id: id,
      type: 'sale',
      no: '1',
      partyId: 'c1',
      partyName: 'أحمد',
      date: DateTime(2026, 1, 15),
      subtotal: 100,
      total: 100,
      paid: 0,
      remaining: 100,
      status: InvoiceStatus.unpaid,
      ownership: InvoiceOwnership.owned,
    );

LedgerStatement sampleLedger() => LedgerStatement(
      accountId: 'a1',
      code: '1010',
      name: 'نقدية',
      type: AccountType.asset,
      from: DateTime(2026, 1, 1),
      to: DateTime(2026, 1, 31),
      opening: 0,
      closing: 100,
      lines: [
        LedgerLine(
          date: DateTime(2026, 1, 5),
          entryNo: 1,
          memo: 'م',
          debit: 100,
          credit: 0,
          balance: 100,
        ),
      ],
    );

/// Fakes ----------------------------------------------------------------

class _FakeCustomers implements CustomerRepository {
  _FakeCustomers(this._list, [this.offline = false]);

  _FakeCustomers.offline() : this(const [], true);

  final List<Customer> _list;
  final bool offline;
  final List<Customer> created = [];

  @override
  Future<List<Customer>> listAll({String? search}) async {
    if (offline) throw const NetworkException();
    return _list;
  }

  @override
  Future<Customer?> getById(String id) async {
    if (offline) throw const NetworkException();
    for (final c in _list) {
      if (c.id == id) return c;
    }
    return null;
  }

  @override
  Future<Customer> create(CustomerDraft draft) async {
    final customer = Customer(id: 'c-new', name: draft.name);
    created.add(customer);
    return customer;
  }

  @override
  Future<void> update({required String id, required CustomerDraft draft}) async {}

  @override
  Future<void> delete(String id) async {}
}

class _FakeInvoices implements InvoiceRepository {
  _FakeInvoices(this._list, {required this.offline});

  final List<Invoice> _list;
  final bool offline;

  @override
  Future<List<Invoice>> list({
    required String type,
    String? search,
    DateTime? from,
    DateTime? to,
  }) async {
    if (offline) throw const NetworkException();
    return _list;
  }

  @override
  Future<List<InvoiceItem>> items(String invoiceId) async {
    if (offline) throw const NetworkException();
    return const [];
  }
}

class _FakeReports implements ReportRepository {
  _FakeReports(this.offline);

  _FakeReports.offline() : this(true);

  final bool offline;

  @override
  Future<LedgerStatement> ledger({
    required String accountId,
    required DateTime from,
    required DateTime to,
  }) async {
    if (offline) throw const NetworkException();
    return sampleLedger();
  }

  @override
  Future<TrialBalanceReport> trialBalance(DateTime asOf) async {
    throw UnimplementedError();
  }

  @override
  Future<IncomeStatement> incomeStatement({
    required DateTime from,
    required DateTime to,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<BalanceSheet> balanceSheet(DateTime asOf) async {
    throw UnimplementedError();
  }
}

class _FakeDashboard implements DashboardRepository {
  _FakeDashboard(this.offline);

  _FakeDashboard.online() : this(false);

  _FakeDashboard.offline() : this(true);

  final bool offline;

  @override
  Future<DashboardSummary> summary() async {
    if (offline) throw const NetworkException();
    return const DashboardSummary(
      todaySales: 10,
      todayPurchases: 0,
      customerDebts: 5,
      supplierDebts: 3,
      monthExpenses: 2,
      monthSalaries: 1,
      netProfitMonth: 4,
      last7Days: [],
      topDebtors: [],
      lowStock: [],
    );
  }
}