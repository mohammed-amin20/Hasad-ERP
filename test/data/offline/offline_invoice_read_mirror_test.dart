import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasad_erp/core/error/app_exception.dart';
import 'package:hasad_erp/data/invoices/invoice_repository.dart';
import 'package:hasad_erp/data/offline/local_database.dart';
import 'package:hasad_erp/data/offline/local_store.dart';
import 'package:hasad_erp/data/offline/offline_invoice_repository.dart';
import 'package:hasad_erp/data/offline/offline_write.dart';
import 'package:hasad_erp/domain/invoices/invoice.dart';
import 'package:hasad_erp/domain/payments/payment_repository.dart';
import 'package:hasad_erp/domain/sales/sale_invoice_draft.dart';

/// Issue 3 (device) — an invoice the user can SEE in the list must be usable by
/// the local money writes.
///
/// ## The defect this pins
///
/// `OfflineInvoiceRepository.list()` cache-lasted its response into
/// `report_cache` and never wrote a `local_invoices` row. The only writers of
/// that table were the four offline-write sites, so it held **nothing but
/// invoices this device created offline**. The local financial mutations resolve
/// their target invoice by scanning it:
///
///  * `OfflineWriteCoordinator._invoice()` (recordPayment) -> threw
///    `الفاتورة غير موجودة محلياً` for an invoice the list was showing;
///  * `settleSupplier()` enumerated it to build its allocation set -> silently
///    allocated against nothing.
///
/// So the row had no owner. `LocalStore` exposes `mirrorCustomers` /
/// `mirrorSuppliers` / `mirrorProducts` / `mirrorEmployees` and had **no**
/// `mirrorInvoices` / `mirrorSalaries`; the same omission makes a server salary
/// row invisible to the duplicate-month guard (that is a separate report, and
/// its consequence there is benign — a missing guard, not a wrong number).
///
/// ## What the mirror must NOT do
///
/// The row it writes is marked `synced: true` / `pendingMoneyLeg: null`, which
/// is exactly the state `_localOverrides` EXCLUDES from the merge. That is
/// deliberate, not incidental: the read merge must keep preferring the server
/// row for a plain mirror copy, or a stale mirror would overwrite fresher server
/// data. The mirror exists purely so the WRITE path can find the header. Two
/// cases below prove a read cannot clobber a row the local side owns.
void main() {
  late AppDatabase db;
  late DriftLocalStore store;
  late OfflineWriteCoordinator writer;

  const tenantA = 'tenant-a';
  const tenantB = 'tenant-b';

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = DriftLocalStore(db);
    writer = OfflineWriteCoordinator(store, tenantA);
  });

  tearDown(() => db.close());

  /// 1010/1015 back a payment and a settlement, 1020 the AR side, 2010 the
  /// purchase credit, 4010 revenue. The same shape the P1.1 suite seeds.
  Future<void> seedChart(String tenant) async {
    for (final a in const [
      ('a1', '1010', 'نقدية', 'asset'),
      ('a2', '1015', 'بنك', 'asset'),
      ('a3', '1020', 'ذمم مدينة', 'asset'),
      ('a4', '1030', 'مخزون', 'asset'),
      ('a5', '2010', 'ذمم دائنة', 'liability'),
      ('a7', '4010', 'إيرادات مبيعات', 'revenue'),
    ]) {
      await store.upsertAccount(LocalAccountRow(
        id: a.$1, tenantId: tenant, code: a.$2, name: a.$3, type: a.$4,
        parentCode: null,
      ));
    }
    await store.upsertSupplier(LocalSupplierRow(
      id: 's1', tenantId: tenant, name: 'مورد', phone: null, notes: null,
      dealType: 'direct', commissionRate: null, createdAt: DateTime(2026, 1, 1),
      synced: true,
    ));
  }

  /// The real repository over a fake "server", for one tenant.
  OfflineInvoiceRepository repoFor(
    String tenant, {
    required List<Invoice> server,
    bool offline = false,
  }) =>
      OfflineInvoiceRepository(
        _FakeInvoices(server, offline: offline),
        store: store,
        tenantId: tenant,
      );

  Invoice serverSale({
    String id = 'inv-server-1',
    String type = 'sale',
    String partyId = 'c1',
    String partyName = 'عميل',
    String no = 'SALE-1001',
    int total = 10000,
    int paid = 0,
    String status = 'unpaid',
    DateTime? date,
  }) =>
      Invoice(
        id: id,
        type: type,
        no: no,
        partyId: partyId,
        partyName: partyName,
        date: date ?? DateTime(2026, 3, 1),
        subtotal: total,
        total: total,
        paid: paid,
        remaining: total - paid,
        status: InvoiceStatus.fromDb(status),
        ownership: InvoiceOwnership.owned,
      );

  group('issue 3 - an invoice read online is mirrored for the local write path', () {
    test(
        'A. an online list read leaves a synced, unmarked header row the '
        'coordinator can resolve', () async {
      await seedChart(tenantA);

      final rows = await repoFor(tenantA, server: [serverSale()])
          .list(type: 'sale');

      // The list the user sees is unaffected by the mirror (proved in the P1
      // suite); this is about the row the WRITE path needs.
      expect(rows.single.id, 'inv-server-1');

      final mirrored = (await store.invoices(tenantA)).single;
      expect(mirrored.id, 'inv-server-1');
      expect(mirrored.synced, isTrue,
          reason: 'a server row is not a local draft');
      expect(mirrored.pendingMoneyLeg, isNull,
          reason: 'no local money mutation is outstanding yet');
    });

    test(
        'B. the mirrored header carries the server identity verbatim and '
        'synthesizes no local metadata', () async {
      await seedChart(tenantA);
      final server = serverSale(
        total: 12345,
        paid: 2345,
        status: 'partial',
        partyName: 'مؤسسة النخيل للتجارة',
      );

      await repoFor(tenantA, server: [server]).list(type: 'sale');

      final m = (await store.invoices(tenantA)).single;
      expect(m.id, server.id);
      expect(m.type, server.type);
      expect(m.no, server.no, reason: 'the OFFICIAL number, not a D-… placeholder');
      expect(m.partyId, server.partyId);
      expect(m.partyName, server.partyName);
      expect(m.date, server.date);
      expect(m.subtotal, server.subtotal);
      expect(m.total, server.total);
      expect(m.paid, server.paid);
      expect(m.remaining, server.remaining);
      expect(m.status, server.status.dbValue);
      expect(m.ownership, server.ownership.name);

      // The `Invoice` read model carries neither field, and both mirror columns
      // are nullable — so the faithful row leaves them null rather than
      // inventing a timestamp or a request id the server never sent.
      expect(m.requestId, isNull);
      expect(m.createdAt, isNull,
          reason: 'synthesizing a createdAt would be a local fiction');
    });

    test(
        'C. a payment against a mirrored server invoice records locally '
        'instead of throwing "invoice not local"', () async {
      await seedChart(tenantA);
      await repoFor(tenantA, server: [serverSale()]).list(type: 'sale');

      final result = await writer.recordPayment(PaymentDraft(
        invoiceId: 'inv-server-1',
        amount: 4000,
        method: 'cash',
        date: DateTime(2026, 3, 2),
      ));

      expect(result.duplicate, isFalse);
      expect(result.paid, 4000);
      expect(result.remaining, 6000);
      expect(result.status, 'partial');
      expect(result.pending, isTrue);

      final row = (await store.invoices(tenantA)).single;
      expect(row.paid, 4000);
      expect(row.remaining, 6000);
      expect(row.pendingMoneyLeg, isNotNull);
    });

    test(
        'D. a later read with OLDER figures must not overwrite a pending local '
        'money mutation', () async {
      await seedChart(tenantA);
      final fake = _FakeInvoices([serverSale()]);

      // 1. online read -> the header is mirrored as a plain synced row.
      final repo = OfflineInvoiceRepository(fake, store: store, tenantId: tenantA);
      await repo.list(type: 'sale');
      expect((await store.invoices(tenantA)).single.pendingMoneyLeg, isNull);

      // 2. an offline payment restates the money fields and stamps the marker.
      await writer.recordPayment(PaymentDraft(
        invoiceId: 'inv-server-1',
        amount: 4000,
        method: 'cash',
        date: DateTime(2026, 3, 2),
      ));
      final marked = (await store.invoices(tenantA)).single;
      expect(marked.paid, 4000);
      expect(marked.pendingMoneyLeg, isNotNull);

      // 3. the server read happens again and still reports the PRE-payment
      //    figures (the leg has not replayed, so it cannot know about them).
      fake.invoices = [serverSale(paid: 0, status: 'unpaid')];
      await repo.list(type: 'sale');

      // 4. the read must leave the local authority completely alone.
      final after = (await store.invoices(tenantA)).single;
      expect(after.paid, 4000, reason: 'pending local money is authoritative');
      expect(after.remaining, 6000);
      expect(after.status, 'partial');
      expect(after.pendingMoneyLeg, marked.pendingMoneyLeg,
          reason: 'a read must never clear a live marker');

      // And the user still sees the corrected figures, not the server's.
      final listed = await repo.list(type: 'sale');
      expect(listed.single.paid, 4000);
      expect(listed.single.remaining, 6000);
    });

    test(
        'E. a read must not overwrite an unsynced local draft that the server '
        'now also reports', () async {
      await seedChart(tenantA);
      // A local draft the server has never issued an id for; the read below
      // returns a server row under that same id, which is the shape a
      // post-replay refresh has.
      await store.upsertInvoice(LocalInvoiceRow(
        id: 'inv-draft-1',
        tenantId: tenantA,
        type: 'sale',
        no: 'D-0001',
        partyId: 'c1',
        partyName: 'عميل',
        date: DateTime(2026, 3, 1),
        subtotal: 5000,
        total: 5000,
        paid: 0,
        remaining: 5000,
        status: 'unpaid',
        ownership: 'owned',
        requestId: 'req-draft',
        synced: false,
        createdAt: DateTime(2026, 3, 1),
      ));

      await repoFor(tenantA, server: [serverSale(id: 'inv-draft-1', no: 'SALE-1001')])
          .list(type: 'sale');

      final rows = await store.invoices(tenantA);
      expect(rows, hasLength(1), reason: 'the incoming row must be SKIPPED, '
          'not replace the draft — two rows would mean the draft was replaced '
          'and re-inserted under a different key');
      expect(rows.single.synced, isFalse);
      expect(rows.single.no, 'D-0001',
          reason: 'the local draft number is not the server authority yet');
      expect(rows.single.total, 5000);
    });

    test(
        'I. a replayed invoice keeps its LOCAL id in the mirror, so a later '
        'read of the server copy must refresh that row in place via id_map '
        'rather than land a second one beside it', () async {
      await seedChart(tenantA);
      await store.upsertCustomer(LocalCustomerRow(
        id: 'c1',
        tenantId: tenantA,
        name: 'عميل',
        phone: null,
        notes: null,
        synced: true,
      ));
      await store.upsertProduct(LocalProductRow(
        id: 'p1',
        tenantId: tenantA,
        name: 'بضاعة',
        barcode: null,
        unit: 'قطعة',
        unitType: 'unit',
        salePrice: 5000,
        purchasePrice: 5000,
        qty: 10,
        reorderLevel: 0,
        supplierId: null,
        commissionRate: null,
        createdAt: DateTime(2026, 1, 1),
        synced: true,
      ));

      // The local write, exactly as a real offline sale leaves it: stored under
      // a client-minted uuid, still unsynced.
      await writer.writeSale(SaleInvoiceDraft(
        customerId: 'c1',
        date: DateTime(2026, 3, 1),
        lines: const [SaleLineDraft(productId: 'p1', qty: 1, price: 5000)],
        paid: 0,
        paymentMethod: 'cash',
      ));
      final localRow = (await store.invoices(tenantA)).single;
      expect(localRow.synced, isFalse);
      expect(localRow.id, isNot('inv-server-1'));

      // The replay: `markReplaySynced` updates `no`/`synced` IN PLACE and records
      // local→server. The row deliberately keeps the LOCAL id, because the
      // sync badge joins the queue on the leg's `localId`.
      await store.markReplaySynced(
        tenantId: tenantA,
        entity: 'invoices',
        localId: localRow.id,
        serverId: 'inv-server-1',
        officialNo: 'SALE-1001',
      );
      expect((await store.invoices(tenantA)).single.id, localRow.id,
          reason: 'precondition: the mirror row still carries the local id');
      expect(
          await store.localIdFor(tenantA, 'invoices', 'inv-server-1'),
          localRow.id);

      // Now the read the user performs: the server now reports the invoice
      // under ITS id. Without the id_map lookup this is a different primary key
      // and gets inserted, so the invoice appears twice and the badge's join
      // stops matching.
      await repoFor(tenantA, server: [
        serverSale(id: 'inv-server-1', no: 'SALE-1001', total: 5000),
      ]).list(type: 'sale');

      final rows = await store.invoices(tenantA);
      expect(rows, hasLength(1),
          reason: 'the same invoice under two keys — the local uuid and the '
              'server id — is one invoice, not two');
      expect(rows.single.id, localRow.id,
          reason: 're-keying it to the server id would break the badge join, '
              'which keys on the queue leg localId');
      expect(rows.single.no, 'SALE-1001');
      expect(rows.single.synced, isTrue);
      expect(rows.single.pendingMoneyLeg, isNull);
    });
  });

  group('issue 3 - settleSupplier against a server-created purchase invoice', () {
    test(
        'F. a purchase invoice read online becomes allocatable, instead of the '
        'settlement silently allocating against nothing', () async {
      await seedChart(tenantA);

      // The production online read path for purchases.
      await repoFor(tenantA, server: [
        serverSale(
          type: 'purchase',
          id: 'inv-purchase-1',
          no: 'PUR-77',
          partyId: 's1',
          partyName: 'مورد',
          total: 10000,
        ),
      ]).list(type: 'purchase');

      final result = await writer.settleSupplier(SettlementDraft(
        supplierId: 's1',
        amount: 6000,
        method: 'cash',
        date: DateTime(2026, 3, 5),
      ));

      expect(result.allocations.map((a) => a.invoiceId), contains('inv-purchase-1'),
          reason: 'the server invoice must be one of the candidates');
      expect(result.invoicesCount, 1,
          reason: 'a silent 0 here is the reported under-allocation');
      expect(result.total, 6000);
      expect(result.pending, isTrue);

      final row = (await store.invoices(tenantA, type: 'purchase')).single;
      expect(row.paid, 6000);
      expect(row.remaining, 4000);
    });

    test(
        'G. a settlement read back with older figures keeps the local '
        'allocation', () async {
      await seedChart(tenantA);
      final fake = _FakeInvoices([
        serverSale(
            type: 'purchase',
            id: 'inv-purchase-1',
            no: 'PUR-77',
            partyId: 's1',
            partyName: 'مورد',
            total: 10000),
      ]);
      final repo = OfflineInvoiceRepository(fake, store: store, tenantId: tenantA);
      await repo.list(type: 'purchase');

      await writer.settleSupplier(SettlementDraft(
        supplierId: 's1',
        amount: 6000,
        method: 'cash',
        date: DateTime(2026, 3, 5),
      ));
      final marked = (await store.invoices(tenantA, type: 'purchase')).single;
      expect(marked.paid, 6000);

      fake.invoices = [
        serverSale(
            type: 'purchase',
            id: 'inv-purchase-1',
            no: 'PUR-77',
            partyId: 's1',
            partyName: 'مورد',
            total: 10000),
      ];
      await repo.list(type: 'purchase');

      final after = (await store.invoices(tenantA, type: 'purchase')).single;
      expect(after.paid, 6000);
      expect(after.remaining, 4000);
      expect(after.pendingMoneyLeg, marked.pendingMoneyLeg);
    });
  });

  group('tenant isolation - the id-only primary key is a documented limit', () {
    test(
        'H. another tenant mirroring the same invoice id cannot overwrite, '
        'delete, or touch this tenant\'s locally-owned row', () async {
      await seedChart(tenantA);
      await seedChart(tenantB);

      // Tenant A owns this row: synced, but carrying a live money marker, so it
      // is the row a naive clear-and-replace mirror would destroy.
      await store.upsertInvoice(LocalInvoiceRow(
        id: 'collide-1',
        tenantId: tenantA,
        type: 'purchase',
        no: 'PUR-1',
        partyId: 's1',
        partyName: 'مورد',
        date: DateTime(2026, 3, 1),
        subtotal: 10000,
        total: 10000,
        paid: 4000,
        remaining: 6000,
        status: 'partial',
        ownership: 'owned',
        requestId: null,
        synced: true,
        createdAt: DateTime(2026, 3, 1),
        pendingMoneyLeg: 'leg-alive',
      ));
      final before = (await store.invoices(tenantA)).single;

      // Tenant B's server happens to report an invoice under the same id.
      // `LocalInvoices.primaryKey` is `{id}` alone, so the two cannot coexist.
      // The delete is tenant-scoped and the insert is NOT an upsert, so the
      // insert must fail rather than replace tenant A's work.
      await repoFor(tenantB, server: [
        serverSale(
            type: 'purchase',
            id: 'collide-1',
            no: 'PUR-9999',
            partyId: 's1',
            partyName: 'مورد آخر',
            total: 777777,
            paid: 0),
      ]).list(type: 'purchase');

      // Tenant A's row is byte-for-byte what it was.
      final after = await store.invoices(tenantA);
      expect(after, hasLength(1), reason: 'the foreign row was neither '
          'deleted nor replaced in place');
      expect(after.single.id, before.id);
      expect(after.single.tenantId, tenantA);
      expect(after.single.no, 'PUR-1', reason: 'tenant A keeps its own number');
      expect(after.single.total, 10000, reason: 'no cross-tenant mutation');
      expect(after.single.paid, 4000);
      expect(after.single.remaining, 6000);
      expect(after.single.status, 'partial');
      expect(after.single.pendingMoneyLeg, 'leg-alive',
          reason: 'a live marker is never dropped, not even by a failed mirror');

      // And tenant B did not end up believing it owns that id.
      expect(await store.invoices(tenantB), isEmpty,
          reason: 'the collision is skipped, not resolved by overwriting');
    });
  });
}

class _FakeInvoices implements InvoiceRepository {
  _FakeInvoices(this.invoices, {this.offline = false});

  List<Invoice> invoices;
  final bool offline;

  @override
  Future<List<Invoice>> list({
    required String type,
    String? search,
    DateTime? from,
    DateTime? to,
  }) async {
    if (offline) throw const NetworkException();
    return [
      for (final i in invoices)
        if (i.type == type) i,
    ];
  }

  @override
  Future<List<InvoiceItem>> items(String invoiceId) async => const [];

  /// The "answered with nothing" branch on purpose: this suite is about header
  /// hydration, and an empty answer is what keeps it there. A `failed` id would
  /// silently skip the mirror and stop testing the header path.
  @override
  Future<InvoiceItemsBatch> itemsForInvoices(List<String> invoiceIds) async =>
      InvoiceItemsBatch(
        items: {for (final id in invoiceIds) id: const <InvoiceItem>[]},
        failed: const {},
      );
}
