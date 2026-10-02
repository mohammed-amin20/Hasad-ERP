import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasad_erp/core/error/app_exception.dart';
import 'package:hasad_erp/data/offline/local_database.dart';
import 'package:hasad_erp/data/offline/local_store.dart';
import 'package:hasad_erp/data/offline/offline_statement_repository.dart';
import 'package:hasad_erp/domain/invoices/invoice.dart';
import 'package:hasad_erp/domain/statements/debts_repository.dart';

/// Issue 3, debt side: the balances are an aggregate over the server's
/// invoices, so a payment recorded on the device is invisible to them until the
/// queue drains. The screen would then show money the user has already handed
/// over as still owed — the same "my payment didn't register" complaint, on a
/// different screen than the invoice list.
class _FakeDebts implements DebtsRepository {
  _FakeDebts({
    this.customers = const [],
    this.suppliers = const [],
    this.offline = false,
  });

  final List<PartyBalance> customers;
  final List<PartyBalance> suppliers;
  final bool offline;

  @override
  Future<List<PartyBalance>> customerBalances() async {
    if (offline) throw const NetworkException();
    return customers;
  }

  @override
  Future<List<PartyBalance>> supplierBalances() async {
    if (offline) throw const NetworkException();
    return suppliers;
  }

  @override
  Future<int> supplierInvoiceDebt(String supplierId) async => 0;

  @override
  Future<int> supplierCommissionDebt(String supplierId) async => 0;

  @override
  Future<List<Invoice>> partyInvoices({
    required String type,
    required String partyId,
  }) async =>
      const [];
}

void main() {
  late AppDatabase db;
  late DriftLocalStore store;

  const tenant = 'tenant-a';

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = DriftLocalStore(db);
  });

  tearDown(() => db.close());

  Future<void> addInvoice({
    required String id,
    required String partyId,
    bool synced = false,
  }) async {
    await store.upsertInvoice(LocalInvoiceRow(
      id: id,
      tenantId: tenant,
      type: 'sale',
      no: 'D-1',
      partyId: partyId,
      partyName: 'عميل',
      date: DateTime(2026, 3, 1),
      subtotal: 10000,
      total: 10000,
      paid: 0,
      remaining: 10000,
      status: 'unpaid',
      ownership: 'owned',
      requestId: null,
      synced: synced,
      createdAt: DateTime(2026, 3, 1),
    ));
  }

  Future<void> addPayment({
    required String id,
    required String partyId,
    required int amount,
    bool synced = false,
    String invoiceId = 'inv-1',
  }) async {
    await store.upsertPayment(LocalPaymentRow(
      id: id,
      tenantId: tenant,
      invoiceId: invoiceId,
      partyId: partyId,
      partyName: 'طرف',
      amount: amount,
      method: 'cash',
      date: DateTime(2026, 3, 2),
      note: null,
      requestId: null,
      synced: synced,
      createdAt: DateTime(2026, 3, 2),
    ));
  }

  test('an unsynced payment reduces the customer balance it was paid to',
      () async {
    await addPayment(id: 'pay-1', partyId: 'c1', amount: 4000);

    final repo = OfflineDebtsRepository(
      _FakeDebts(
        customers: const [
          PartyBalance(id: 'c1', name: 'عميل', amount: 10000),
          PartyBalance(id: 'c2', name: 'آخر', amount: 2500),
        ],
      ),
      store: store,
      tenantId: tenant,
    );

    final rows = await repo.customerBalances();
    expect(rows.firstWhere((b) => b.id == 'c1').amount, 6000,
        reason: 'the server still counts 10000, so the local 4000 is subtracted');
    expect(rows.firstWhere((b) => b.id == 'c2').amount, 2500,
        reason: 'a party with no pending payment is untouched');
  });

  test('an unsynced settlement reduces the supplier balance', () async {
    await addPayment(id: 'pay-1', partyId: 's1', amount: 7000);

    final repo = OfflineDebtsRepository(
      _FakeDebts(
        suppliers: const [PartyBalance(id: 's1', name: 'مورد', amount: 9000)],
      ),
      store: store,
      tenantId: tenant,
    );

    final rows = await repo.supplierBalances();
    expect(rows.single.amount, 2000);
  });

  test('a payment that settles the debt in full removes the row, rather than '
      'leaving a negative balance', () async {
    await addPayment(id: 'pay-1', partyId: 'c1', amount: 10000);

    final repo = OfflineDebtsRepository(
      _FakeDebts(
        customers: const [
          PartyBalance(id: 'c1', name: 'عميل', amount: 10000),
          PartyBalance(id: 'c2', name: 'آخر', amount: 2500),
        ],
      ),
      store: store,
      tenantId: tenant,
    );

    final rows = await repo.customerBalances();
    expect(rows.map((b) => b.id), isNot(contains('c1')));
    expect(rows.single.id, 'c2');
  });

  test('several pending payments for one party add up', () async {
    await addPayment(id: 'pay-1', partyId: 'c1', amount: 2000);
    await addPayment(id: 'pay-2', partyId: 'c1', amount: 3000);
    await addPayment(id: 'pay-3', partyId: 'c2', amount: 500);

    final repo = OfflineDebtsRepository(
      _FakeDebts(
        customers: const [
          PartyBalance(id: 'c1', name: 'عميل', amount: 10000),
          PartyBalance(id: 'c2', name: 'آخر', amount: 2500),
        ],
      ),
      store: store,
      tenantId: tenant,
    );

    final rows = await repo.customerBalances();
    expect(rows.firstWhere((b) => b.id == 'c1').amount, 5000);
    expect(rows.firstWhere((b) => b.id == 'c2').amount, 2000);
  });

  test('a replayed payment is NOT subtracted again', () async {
    // The server's aggregate already includes it, so the balance is served
    // unchanged — this is the case that keeps the overlay from double-counting
    // every payment the moment its leg drains.
    await addPayment(id: 'pay-1', partyId: 'c1', amount: 4000, synced: true);

    final repo = OfflineDebtsRepository(
      _FakeDebts(
        customers: const [PartyBalance(id: 'c1', name: 'عميل', amount: 10000)],
      ),
      store: store,
      tenantId: tenant,
    );

    final rows = await repo.customerBalances();
    expect(rows.single.amount, 10000);
  });

  test('a payment with no party is ignored rather than crashing the screen',
      () async {
    await store.upsertPayment(LocalPaymentRow(
      id: 'pay-orphan',
      tenantId: tenant,
      invoiceId: null,
      partyId: null,
      partyName: null,
      amount: 1000,
      method: 'cash',
      date: DateTime(2026, 3, 2),
      note: null,
      requestId: null,
      synced: false,
      createdAt: DateTime(2026, 3, 2),
    ));

    final repo = OfflineDebtsRepository(
      _FakeDebts(
        customers: const [PartyBalance(id: 'c1', name: 'عميل', amount: 10000)],
      ),
      store: store,
      tenantId: tenant,
    );

    final rows = await repo.customerBalances();
    expect(rows.single.amount, 10000);
  });

  test('another tenant’s pending payment never touches this tenant’s balance',
      () async {
    await store.upsertPayment(LocalPaymentRow(
      id: 'pay-foreign',
      tenantId: 'other-tenant',
      invoiceId: 'inv-1',
      partyId: 'c1',
      partyName: 'طرف',
      amount: 4000,
      method: 'cash',
      date: DateTime(2026, 3, 2),
      note: null,
      requestId: null,
      synced: false,
      createdAt: DateTime(2026, 3, 2),
    ));

    final repo = OfflineDebtsRepository(
      _FakeDebts(
        customers: const [PartyBalance(id: 'c1', name: 'عميل', amount: 10000)],
      ),
      store: store,
      tenantId: tenant,
    );

    final rows = await repo.customerBalances();
    expect(rows.single.amount, 10000,
        reason: 'tenant isolation is part of the store contract, not decoration');
  });

  test('the overlay also applies to the CACHED figures, not just a live read',
      () async {
    await addPayment(id: 'pay-1', partyId: 'c1', amount: 4000);

    // First pass populates the cache while online...
    final online = OfflineDebtsRepository(
      _FakeDebts(
        customers: const [PartyBalance(id: 'c1', name: 'عميل', amount: 10000)],
      ),
      store: store,
      tenantId: tenant,
    );
    expect((await online.customerBalances()).single.amount, 6000);

    // ...then the network drops. The cached payload holds the server's 10000,
    // so without the overlay on the cache path the debt would jump back up.
    final offline = OfflineDebtsRepository(
      _FakeDebts(offline: true),
      store: store,
      tenantId: tenant,
    );
    expect((await offline.customerBalances()).single.amount, 6000,
        reason: 'the offline path is the whole point of the issue');
  });

  test('a payment against an unsynced LOCAL DRAFT is not subtracted, because '
      'the server aggregate never contained that invoice', () async {
    // The customer creates a 5000 invoice offline and pays it offline. The
    // server's balance knows nothing about either the invoice or the payment,
    // so the debt it reports (10000 on its own invoices) is already correct.
    // Subtracting 5000 here would understate the real debt by half.
    await addInvoice(id: 'inv-draft', partyId: 'c1');
    await addPayment(id: 'pay-1', partyId: 'c1', amount: 5000,
        invoiceId: 'inv-draft');

    final repo = OfflineDebtsRepository(
      _FakeDebts(
        customers: const [PartyBalance(id: 'c1', name: 'عميل', amount: 10000)],
      ),
      store: store,
      tenantId: tenant,
    );

    final rows = await repo.customerBalances();
    expect(rows.single.amount, 10000,
        reason: 'paying a local draft reduces that draft, not the server debt');
  });

  test('a payment against a SYNCED invoice is still subtracted, so the filter '
      'keys on sync state and not merely on the invoice existing', () async {
    // The counterpart to the case above: the very same shape, but the invoice
    // IS in the server's aggregate, so the payment must reduce the balance.
    // Without this, a filter written as "invoice row present" would pass the
    // previous test and break this one.
    await addInvoice(id: 'inv-1', partyId: 'c1', synced: true);
    await addPayment(id: 'pay-1', partyId: 'c1', amount: 4000,
        invoiceId: 'inv-1');

    final repo = OfflineDebtsRepository(
      _FakeDebts(
        customers: const [PartyBalance(id: 'c1', name: 'عميل', amount: 10000)],
      ),
      store: store,
      tenantId: tenant,
    );

    final rows = await repo.customerBalances();
    expect(rows.single.amount, 6000);
  });
}
