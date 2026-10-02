import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasad_erp/core/error/app_exception.dart';
import 'package:hasad_erp/data/invoices/invoice_repository.dart';
import 'package:hasad_erp/data/offline/local_database.dart';
import 'package:hasad_erp/data/offline/local_store.dart';
import 'package:hasad_erp/data/offline/offline_customer_repository.dart';
import 'package:hasad_erp/data/offline/offline_dashboard_repository.dart';
import 'package:hasad_erp/data/offline/offline_invoice_repository.dart';
import 'package:hasad_erp/domain/customers/customer.dart';
import 'package:hasad_erp/domain/customers/customer_draft.dart';
import 'package:hasad_erp/domain/customers/customer_repository.dart';
import 'package:hasad_erp/domain/dashboard/dashboard.dart';
import 'package:hasad_erp/domain/invoices/invoice.dart';
import 'package:path/path.dart' as p;

/// P0 issue 6 — cold-start data blackout: "kill the app while offline, restart
/// it, and the app shows no business data."
///
/// These tests pin the data-layer half of the contract with a real
/// file-backed database:
///
/// 1. Real mirrors + report cache + an unsynced draft + its pending queue leg +
///    the cached auth profile are written to a sqlite file, the connection is
///    closed (a process death), and a SECOND connection opens the SAME file —
///    the exact restart shape `localStoreProvider` takes at app launch.
/// 2. Every offline-first wrapper is rebuilt over the reopened store with a
///    network that throws on every call, and the business data must still be
///    readable: customers, the sales list (cached row + the offline draft
///    merged on top), the draft's own items, the dashboard envelope, the still-
///    pending queue leg, and the cached profile.
///
/// If this suite is green on the shipped code, the repository layer survives a
/// restart and the DEVICE collapse is not "offline reads lost the data" — it is
/// the database failing to open (corrupt file / migration) or the auth stream
/// dying, which is exactly what `store_open_failure_test.dart` and the repair
/// gate cover.
void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('hasad_cold_start'));
  tearDown(() => dir.deleteSync(recursive: true));

  const tenant = 'tenant-t';

  test('business data survives a process restart and is served offline', () async {
    final file = File(p.join(dir.path, 'hasad_offline.sqlite'));

    // ---- first "process run": seed real data, then die (close the db) ----
    final firstDb = AppDatabase(NativeDatabase(file));
    final store = DriftLocalStore(firstDb);

    await store.mirrorCustomers(tenant, [
      const LocalCustomerRow(
        id: 'c1', tenantId: tenant, name: 'أحمد', phone: '0599',
        notes: null, synced: true,
      ),
      const LocalCustomerRow(
        id: 'c2', tenantId: tenant, name: 'سارة', phone: null,
        notes: null, synced: true,
      ),
    ]);
    await store.putReport(
      tenant,
      'inv:sale:all:_:_',
      '['
      '{"id":"I-1","type":"sale","no":"1","party_id":"c1","party_name":"أحمد",'
      '"date":"2026-01-15","subtotal":100,"total":100,"paid":0,"remaining":100,'
      '"status":"unpaid","ownership":"owned"}'
      ']',
    );
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
    await store.upsertInvoice(LocalInvoiceRow(
      id: 'D-1', tenantId: tenant, type: 'sale', no: 'D-DRAFT1',
      partyId: 'c1', partyName: 'أحمد', date: DateTime(2026, 1, 20),
      subtotal: 60, total: 60, paid: 0, remaining: 60,
      status: 'unpaid', ownership: 'owned', requestId: 'rq-1', synced: false,
      createdAt: DateTime(2026, 1, 20),
    ));
    await store.upsertInvoiceItems([
      LocalInvoiceItemRow(
        id: 'it1', tenantId: tenant, invoiceId: 'D-1', productId: 'p1',
        productName: 'سلعة', productUnit: 'قطعة', productUnitType: 'count',
        qty: 3.0, price: 20, total: 60,
      ),
    ]);
    await store.enqueue(SyncQueueRow(
      id: 'leg-1', tenantId: tenant, rpc: 'create_sale_invoice', op: 'rpc',
      params: '{"request_id":"rq-1"}', requestId: 'rq-1',
      entity: 'invoices', localId: 'D-1', status: 'pending', attempts: 0,
      createdAt: DateTime(2026, 1, 20), updatedAt: DateTime(2026, 1, 20),
    ));
    await store.putUserProfile(
      'u-1',
      '{"tenant_id":"tenant-t","roles":["admin"],"display_name":"أحمد"}',
    );

    // process death: drop the object AND the connection, keep only the file
    await firstDb.close();

    // ---- second "process run": reopen the same file, network dead ----
    final secondDb = AppDatabase(NativeDatabase(file));
    final reopened = DriftLocalStore(secondDb);
    addTearDown(() => secondDb.close());

    final customers = OfflineCustomerRepository(
      _ThrowingCustomers(),
      store: reopened,
      tenantId: tenant,
    );
    final invoices = OfflineInvoiceRepository(
      _ThrowingInvoices(),
      store: reopened,
      tenantId: tenant,
    );
    final dashboard = OfflineDashboardRepository(
      _ThrowingDashboard(),
      store: reopened,
      tenantId: tenant,
    );

    // master data serves the mirror
    expect(await customers.listAll(), hasLength(2));
    expect((await customers.listAll(search: 'سارة')).map((c) => c.id), ['c2']);

    // sales list = cached server row + the offline draft merged on top
    final list = await invoices.list(type: 'sale');
    expect(list.map((i) => i.id).toSet(), {'I-1', 'D-1'});
    // draft sorts newest-first on top of the cached base (same rule as online)
    expect(list.first.id, 'D-1');

    // draft items resolve locally
    final items = await invoices.items('D-1');
    expect(items.single.productId, 'p1');

    // dashboard rehydrates the cached envelope
    final summary = await dashboard.summary();
    expect(summary.todaySales, 10);
    expect(summary.topDebtors.single.balance, 5);

    // the queued write is still pending and still attached to the draft
    final legs = await reopened.queueLegsFor(tenant, entity: 'invoices');
    expect(legs.single.status, 'pending');
    expect(legs.single.localId, 'D-1');

    // the cached auth profile survived
    final profile = await reopened.getUserProfile('u-1');
    expect(profile, isNotNull);
    expect(profile!.payload, contains('"tenant_id":"tenant-t"'));
  });
}

/// Network is dead. Every call throws, so the repos must serve the mirror.
class _ThrowingCustomers implements CustomerRepository {
  @override
  Future<List<Customer>> listAll({String? search}) async =>
      throw const NetworkException();

  @override
  Future<Customer?> getById(String id) async => throw const NetworkException();

  @override
  Future<Customer> create(CustomerDraft draft) async =>
      throw const NetworkException();

  @override
  Future<void> update({required String id, required CustomerDraft draft}) async =>
      throw const NetworkException();

  @override
  Future<void> delete(String id) async => throw const NetworkException();
}

class _ThrowingInvoices implements InvoiceRepository {
  @override
  Future<List<Invoice>> list({
    required String type,
    String? search,
    DateTime? from,
    DateTime? to,
  }) async =>
      throw const NetworkException();

  @override
  Future<List<InvoiceItem>> items(String invoiceId) async =>
      throw const NetworkException();

  /// Offline for the whole scenario, so the prefetch is unanswered too. Throwing
  /// (rather than returning `failed`) is the stronger state: it proves the list
  /// read survives a batch that produced no answer at all.
  @override
  Future<InvoiceItemsBatch> itemsForInvoices(List<String> invoiceIds) async =>
      throw const NetworkException();
}

class _ThrowingDashboard implements DashboardRepository {
  @override
  Future<DashboardSummary> summary() async => throw const NetworkException();
}