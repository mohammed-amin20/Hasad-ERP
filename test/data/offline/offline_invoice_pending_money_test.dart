import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasad_erp/core/error/app_exception.dart';
import 'package:hasad_erp/data/invoices/invoice_repository.dart';
import 'package:hasad_erp/data/offline/local_database.dart';
import 'package:hasad_erp/data/offline/local_store.dart';
import 'package:hasad_erp/data/offline/offline_invoice_repository.dart';
import 'package:hasad_erp/data/offline/offline_sync.dart';
import 'package:hasad_erp/data/offline/offline_write.dart';
import 'package:hasad_erp/domain/invoices/invoice.dart';
import 'package:hasad_erp/domain/payments/payment_repository.dart';

/// Issue 3 — an invoice list must show the money an offline payment just
/// recorded, and must NOT let a stale mirror row overwrite a fresher server row.
///
/// The rule under test ([OfflineInvoiceRepository._localOverrides]):
///   * `synced == false`                        -> the local draft is the invoice
///   * `synced == true`, `pendingMoneyLeg != null` -> server identity + local money
///   * otherwise                                -> the server/cache row wins
///
/// The last case is the one that used to be unsafe: a mirror copy of a server
/// row is not evidence of anything, so allowing it into the merge would both
/// restate stale figures and keep showing a row the server had dropped.
void main() {
  late AppDatabase db;
  late DriftLocalStore store;
  late OfflineWriteCoordinator writer;

  const tenant = 'tenant-a';

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = DriftLocalStore(db);
    writer = OfflineWriteCoordinator(store, tenant);
  });

  tearDown(() => db.close());

  Future<void> seedChart() async {
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
    await store.upsertProduct(LocalProductRow(
      id: 'p1', tenantId: tenant, name: 'سلعة', barcode: null, unit: 'قطعة',
      unitType: 'count', salePrice: 10000, purchasePrice: 6000, qty: 100,
      reorderLevel: 10, supplierId: 's1', commissionRate: null,
      createdAt: DateTime(2026, 1, 1), synced: true,
    ));
  }

  /// A purchase invoice that already exists on the server, mirrored and synced.
  Future<String> seedSyncedPurchaseInvoice({
    int total = 10000,
    int paid = 0,
    String id = 'inv-server-1',
  }) async {
    final status = paid >= total
        ? 'paid'
        : paid > 0
            ? 'partial'
            : 'unpaid';
    await store.upsertInvoice(LocalInvoiceRow(
      id: id,
      tenantId: tenant,
      type: 'purchase',
      no: 'P-1',
      partyId: 's1',
      partyName: 'مورد',
      date: DateTime(2026, 3, 1),
      subtotal: total,
      total: total,
      paid: paid,
      remaining: total - paid,
      status: status,
      ownership: 'owned',
      requestId: null,
      synced: true,
      createdAt: DateTime(2026, 3, 1),
    ));
    return id;
  }

  /// What the list should show for [id] after the merge.
  Future<Invoice> listed(String id, {required bool offline}) async {
    final repo = OfflineInvoiceRepository(
      _FakeInvoices(
        [
          _serverInvoice(paid: 0, remaining: 10000, status: 'unpaid'),
        ],
        offline: offline,
      ),
      store: store,
      tenantId: tenant,
    );
    final rows = await repo.list(type: 'purchase');
    return rows.firstWhere((i) => i.id == id);
  }

  group('issue 3 — pending local money is authoritative', () {
    test(
        'A. an offline payment on a synced invoice shows its new '
        'paid/remaining/status before the drain', () async {
      await seedChart();
      final id = await seedSyncedPurchaseInvoice();

      // Reproduce the reported flow: no network, payment recorded locally.
      await writer.recordPayment(PaymentDraft(
        invoiceId: id,
        amount: 4000,
        method: 'cash',
        date: DateTime(2026, 3, 2),
      ));

      final row = (await store.invoices(tenant, type: 'purchase')).single;
      expect(row.pendingMoneyLeg, isNotNull,
          reason: 'the write must mark the row it restated');
      expect(row.synced, isTrue,
          reason: 'an offline payment does not make the invoice a draft');

      final invoice = await listed(id, offline: true);
      expect(invoice.paid, 4000);
      expect(invoice.remaining, 6000);
      expect(invoice.status, InvoiceStatus.partial);
    });

    test(
        'B. with no pending mutation the server value wins over a stale mirror '
        'row (no marker -> mirror is not evidence)', () async {
      await seedChart();
      final id = await seedSyncedPurchaseInvoice(total: 10000, paid: 0);

      // The mirror row drifts away from the server: an older snapshot that
      // claims the invoice was already settled. With nothing pending there is
      // no reason to believe it.
      await store.upsertInvoice(LocalInvoiceRow(
        id: id,
        tenantId: tenant,
        type: 'purchase',
        no: 'P-1',
        partyId: 's1',
        partyName: 'مورد',
        date: DateTime(2026, 3, 1),
        subtotal: 10000,
        total: 10000,
        paid: 10000,
        remaining: 0,
        status: 'paid',
        ownership: 'owned',
        requestId: null,
        synced: true,
        createdAt: DateTime(2026, 3, 1),
      ));
      final row = (await store.invoices(tenant, type: 'purchase')).single;
      expect(row.pendingMoneyLeg, isNull);

      // Online here: the server row is reachable, so the merge has both
      // representations to choose from and the unmarked mirror must lose.
      final invoice = await listed(id, offline: false);
      expect(invoice.paid, 0, reason: 'stale mirror must not win');
      expect(invoice.remaining, 10000);
      expect(invoice.status, InvoiceStatus.unpaid);
    });

    test(
        'B2. an unmarked mirror is not resurrected offline: no local '
        'authority means an honest NetworkException, not a stale row', () async {
      await seedChart();
      await seedSyncedPurchaseInvoice(total: 10000, paid: 10000);

      // The same unmarked, stale row, but the server is unreachable. There is
      // no pending local work to serve, so rethrowing is the honest answer —
      // the merge must not invent a representation out of the mirror.
      final repo = OfflineInvoiceRepository(
        _FakeInvoices(const [], offline: true),
        store: store,
        tenantId: tenant,
      );
      await expectLater(
        repo.list(type: 'purchase'),
        throwsA(isA<NetworkException>()),
      );
    });

    test(
        'C. a marked row keeps the server identity and only overrides the '
        'money fields', () async {
      await seedChart();
      final id = await seedSyncedPurchaseInvoice();

      await writer.recordPayment(PaymentDraft(
        invoiceId: id,
        amount: 4000,
        method: 'cash',
        date: DateTime(2026, 3, 2),
      ));

      // The server has meanwhile issued the official number and corrected the
      // party name. Those are identity facts the local row never touched, so
      // the merge must keep them and take only paid/remaining/status locally.
      final repo = OfflineInvoiceRepository(
        _FakeInvoices(
          [
            _serverInvoice(
              paid: 0,
              remaining: 10000,
              status: 'unpaid',
              no: 'P-77',
              partyName: 'مورد محدّث',
            ),
          ],
          offline: false,
        ),
        store: store,
        tenantId: tenant,
      );
      final rows = await repo.list(type: 'purchase');
      final invoice = rows.firstWhere((i) => i.id == id);
      expect(invoice.no, 'P-77');
      expect(invoice.partyName, 'مورد محدّث');
      expect(invoice.paid, 4000);
      expect(invoice.remaining, 6000);
      expect(invoice.status, InvoiceStatus.partial);
    });

    test(
        'D. a settlement marks ONLY the invoices it allocated, never the '
        "supplier's other open invoices", () async {
      await seedChart();
      // Two open invoices from the same supplier, oldest first.
      for (final row in [
        ['inv-old', 'P-1', DateTime(2026, 1, 5)],
        ['inv-new', 'P-2', DateTime(2026, 2, 5)],
      ]) {
        await store.upsertInvoice(LocalInvoiceRow(
          id: row[0] as String,
          tenantId: tenant,
          type: 'purchase',
          no: row[1] as String,
          partyId: 's1',
          partyName: 'مورد',
          date: row[2] as DateTime,
          subtotal: 10000,
          total: 10000,
          paid: 0,
          remaining: 10000,
          status: 'unpaid',
          ownership: 'owned',
          requestId: null,
          synced: true,
          createdAt: row[2] as DateTime,
        ));
      }

      // Settle 10000: the engine allocates it oldest-first, so only inv-old is
      // touched and inv-new must be left to the server's authority.
      await writer.settleSupplier(SettlementDraft(
        supplierId: 's1',
        amount: 10000,
        method: 'cash',
        date: DateTime(2026, 3, 3),
      ));

      final rows = {for (final r in await store.invoices(tenant, type: 'purchase')) r.id: r};
      expect(rows['inv-old']!.remaining, 0);
      expect(rows['inv-old']!.pendingMoneyLeg, isNotNull,
          reason: 'an allocated invoice is locally authoritative');
      expect(rows['inv-new']!.pendingMoneyLeg, isNull,
          reason: 'an untouched invoice must not be restated locally');
    });
  });

  group('issue 3 — overlapping money legs', () {
    test(
        'replaying leg A must not clear the marker leg B wrote, so the row '
        'stays authoritative until B drains too', () async {
      await seedChart();
      final id = await seedSyncedPurchaseInvoice(total: 10000, paid: 0);

      await writer.recordPayment(PaymentDraft(
        invoiceId: id, amount: 4000, method: 'cash', date: DateTime(2026, 3, 2),
      ));
      final legA =
          (await store.invoices(tenant, type: 'purchase')).single.pendingMoneyLeg!;
      expect(legA, isNotNull);

      // A second payment lands before the first has drained and takes over the
      // marker — the row now reflects BOTH payments.
      await writer.recordPayment(PaymentDraft(
        invoiceId: id, amount: 3000, method: 'cash', date: DateTime(2026, 3, 3),
      ));
      final marked = (await store.invoices(tenant, type: 'purchase')).single;
      final legB = marked.pendingMoneyLeg!;
      expect(legB, isNot(legA), reason: 'B overwrites the marker');
      expect(marked.paid, 7000);
      expect(marked.remaining, 3000);

      // Leg A reaches the server. Only A's marker may be cleared.
      await store.clearInvoiceMoneyMarker(tenant, legA);
      final afterA = (await store.invoices(tenant, type: 'purchase')).single;
      expect(afterA.pendingMoneyLeg, legB,
          reason: 'B is still pending and must keep the row authoritative');
      expect(afterA.remaining, 3000);

      // Leg B reaches the server too: now the server is authoritative.
      await store.clearInvoiceMoneyMarker(tenant, legB);
      final afterB = (await store.invoices(tenant, type: 'purchase')).single;
      expect(afterB.pendingMoneyLeg, isNull);
    });

    test('a retry reuses the same leg and does not invent a second marker',
        () async {
      await seedChart();
      final id = await seedSyncedPurchaseInvoice();

      await writer.recordPayment(PaymentDraft(
        invoiceId: id, amount: 4000, method: 'cash', date: DateTime(2026, 3, 2),
      ));
      final leg = (await store.invoices(tenant, type: 'purchase')).single
          .pendingMoneyLeg!;

      // The flusher requeues the same leg on a transient failure. A retry
      // touches only the queue, so the marker must be untouched too.
      await store.requeueRetry(leg, 'boom', 1);
      await store.requeueRetry(leg, 'boom', 2);

      final rows = await store.invoices(tenant, type: 'purchase');
      expect(rows.single.pendingMoneyLeg, leg);
      final legs = await store.queueLegsFor(tenant, entity: 'payments');
      expect(legs, hasLength(1), reason: 'a retry is not a second write');
      expect(legs.single.id, leg);
    });

    test('a parked leg keeps the marker, so the local figures stay visible',
        () async {
      await seedChart();
      final id = await seedSyncedPurchaseInvoice();

      await writer.recordPayment(PaymentDraft(
        invoiceId: id, amount: 4000, method: 'cash', date: DateTime(2026, 3, 2),
      ));
      final leg = (await store.invoices(tenant, type: 'purchase')).single
          .pendingMoneyLeg!;
      await store.markFailed(leg, 'server said no');

      final row = (await store.invoices(tenant, type: 'purchase')).single;
      expect(row.pendingMoneyLeg, leg,
          reason: 'a failed leg never returns the row to the server');
      final invoice = await listed(id, offline: true);
      expect(invoice.remaining, 6000);
    });

    test('clearing a leg id that no row references is a no-op', () async {
      await seedChart();
      await seedSyncedPurchaseInvoice();
      await writer.recordPayment(PaymentDraft(
        invoiceId: 'inv-server-1', amount: 4000, method: 'cash',
        date: DateTime(2026, 3, 2),
      ));
      final before = (await store.invoices(tenant, type: 'purchase')).single;

      await store.clearInvoiceMoneyMarker(tenant, 'leg-that-never-existed');

      final after = (await store.invoices(tenant, type: 'purchase')).single;
      expect(after.pendingMoneyLeg, before.pendingMoneyLeg);
    });
  });

  group('issue 3 — the flusher clears the marker, and only on success', () {
    test('a successful drain hands the row back to the server', () async {
      await seedChart();
      final id = await seedSyncedPurchaseInvoice();

      await writer.recordPayment(PaymentDraft(
        invoiceId: id, amount: 4000, method: 'cash', date: DateTime(2026, 3, 2),
      ));
      expect((await store.invoices(tenant, type: 'purchase')).single
          .pendingMoneyLeg, isNotNull);

      final target = _OkSyncTarget();
      final summary =
          await SyncFlusher(store, tenant, target).flush();
      expect(summary.synced, 1);

      final after = (await store.invoices(tenant, type: 'purchase')).single;
      expect(after.pendingMoneyLeg, isNull,
          reason: 'the payment reached the server, so it is now authoritative');
    });

    test('a failed replay keeps the marker, so the row stays local-first',
        () async {
      await seedChart();
      final id = await seedSyncedPurchaseInvoice();

      await writer.recordPayment(PaymentDraft(
        invoiceId: id, amount: 4000, method: 'cash', date: DateTime(2026, 3, 2),
      ));
      final legId = (await store.invoices(tenant, type: 'purchase'))
          .single
          .pendingMoneyLeg!;

      final summary = await SyncFlusher(
        store,
        tenant,
        _OkSyncTarget(failRpcs: {'record_payment'}),
      ).flush();
      expect(summary.synced, 0);

      final after = (await store.invoices(tenant, type: 'purchase')).single;
      expect(after.pendingMoneyLeg, legId,
          reason: 'a payment that never landed must stay authoritative locally');
      expect(after.paid, 4000);
      expect(after.remaining, 6000);
    });

    test('whichever overlapping leg fails keeps the marker', () async {
      // The half of the overlap invariant that a "both legs drain, then look at
      // the final state" test cannot observe. Fails exactly ONE of the two
      // replays and asserts the surviving marker names the leg that has NOT
      // landed. If the flusher cleared by invoice rather than by leg id, the
      // succeeding leg would wipe the marker and the still-queued correction
      // would be silently dropped — the case a boolean flag cannot represent.
      //
      // Deliberately order-independent: both legs are enqueued with
      // `DateTime.now()` in the same millisecond, so which one the flusher
      // attempts first is not something to assume. The invariant is symmetric,
      // so the assertion is too.
      await seedChart();
      final id = await seedSyncedPurchaseInvoice(total: 10000, paid: 0);

      await writer.recordPayment(PaymentDraft(
        invoiceId: id, amount: 4000, method: 'cash', date: DateTime(2026, 3, 2),
      ));
      final legA = (await store.invoices(tenant, type: 'purchase'))
          .single
          .pendingMoneyLeg!;

      await writer.recordPayment(PaymentDraft(
        invoiceId: id, amount: 3000, method: 'cash', date: DateTime(2026, 3, 3),
      ));
      final legB = (await store.invoices(tenant, type: 'purchase'))
          .single
          .pendingMoneyLeg!;
      expect(legB, isNot(legA));

      final summary =
          await SyncFlusher(store, tenant, _OkSyncTarget(failFirstRpcCalls: 1))
              .flush();
      expect(summary.synced, 1, reason: 'one replay was rejected, one landed');
      expect(summary.failed, 1);

      // The leg that did NOT reach `synced` is the one whose claim must
      // survive. Its status is `pending`, not `failed`: a fresh leg is at
      // attempts 0, and 1 < kSyncMaxAttempts sends it back through
      // `requeueRetry` for another pass.
      final legs = await store.queueLegsFor(tenant, entity: 'payments');
      final stillQueued = legs.singleWhere((l) => l.status != 'synced');

      final after = (await store.invoices(tenant, type: 'purchase')).single;
      expect(after.pendingMoneyLeg, stillQueued.id,
          reason: 'the marker must name the leg that has not landed, not '
              'whichever replay happened to run');
      expect(after.remaining, 3000,
          reason: 'both payments are still reflected locally');
    });

    test('both overlapping legs draining in one pass ends fully cleared',
        () async {
      await seedChart();
      final id = await seedSyncedPurchaseInvoice(total: 10000, paid: 0);

      await writer.recordPayment(PaymentDraft(
        invoiceId: id, amount: 4000, method: 'cash', date: DateTime(2026, 3, 2),
      ));
      final legA = (await store.invoices(tenant, type: 'purchase'))
          .single
          .pendingMoneyLeg!;

      await writer.recordPayment(PaymentDraft(
        invoiceId: id, amount: 3000, method: 'cash', date: DateTime(2026, 3, 3),
      ));
      final legB = (await store.invoices(tenant, type: 'purchase'))
          .single
          .pendingMoneyLeg!;
      expect(legB, isNot(legA));

      // Both legs drain in this one pass: the flusher rescans until the graph
      // is empty, and the two payments have no dependency between them.
      final target = _OkSyncTarget();
      final first = await SyncFlusher(store, tenant, target).flush();
      expect(first.synced, 2);

      // The order still matters for correctness. A drains first (it is the
      // older leg) and must leave B's marker in place; B drains second and
      // clears it. The final state can only be reached if neither replay
      // cleared the other's claim.
      final after = (await store.invoices(tenant, type: 'purchase')).single;
      expect(after.pendingMoneyLeg, isNull,
          reason: 'both payments landed, so the server is authoritative');
      expect(after.remaining, 3000);
    });

    test('an idempotent duplicate replay still clears the marker', () async {
      await seedChart();
      final id = await seedSyncedPurchaseInvoice();

      await writer.recordPayment(PaymentDraft(
        invoiceId: id, amount: 4000, method: 'cash', date: DateTime(2026, 3, 2),
      ));

      // The server had already committed this request (a lost response), so it
      // answers with the duplicate envelope instead of a fresh id. The local
      // money write DID land, so the marker must still be cleared.
      final summary = await SyncFlusher(
        store,
        tenant,
        _OkSyncTarget(duplicate: true),
      ).flush();
      expect(summary.synced, 1);

      final after = (await store.invoices(tenant, type: 'purchase')).single;
      expect(after.pendingMoneyLeg, isNull,
          reason: 'a duplicate envelope means the payment committed server-side');
    });
  });
}

/// The server's view of the invoice, as `cacheLast` would serve it.
Invoice _serverInvoice({
  required int paid,
  required int remaining,
  required String status,
  String no = 'P-1',
  String partyName = 'مورد',
}) =>
    Invoice(
      id: 'inv-server-1',
      type: 'purchase',
      no: no,
      partyId: 's1',
      partyName: partyName,
      date: DateTime(2026, 3, 1),
      subtotal: 10000,
      total: 10000,
      paid: paid,
      remaining: remaining,
      status: InvoiceStatus.fromDb(status),
      ownership: InvoiceOwnership.owned,
    );

/// A sync target that accepts every RPC, optionally failing or duplicating
/// them, so the flusher's own success/failure branches run for real.
class _OkSyncTarget implements SyncTarget {
  _OkSyncTarget({
    this.failRpcs = const {},
    this.duplicate = false,
    this.failFirstRpcCalls = 0,
  });

  final Set<String> failRpcs;
  final bool duplicate;

  /// Fails only the first N rpc calls, then succeeds. Lets a test fail ONE leg
  /// of several and observe what the others did to the shared marker.
  final int failFirstRpcCalls;
  int _rpcCalls = 0;

  @override
  Future<Map<String, dynamic>> rpc(
    String name,
    Map<String, dynamic> params,
  ) async {
    _rpcCalls++;
    if (failRpcs.contains(name)) throw StateError('rejected $name');
    if (_rpcCalls <= failFirstRpcCalls) {
      throw StateError('the first $name was rejected');
    }
    if (duplicate) {
      return <String, dynamic>{
        'duplicate': true,
        'payment': <String, dynamic>{'id': 'server-payment'},
      };
    }
    return <String, dynamic>{'payment_id': 'server-payment'};
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

  /// The batch path shares this fake's reachability so an offline list prefetch
  /// fails exactly the way a single read would — the money-marker assertions
  /// must never be able to pass on an invoice whose lines were hydrated.
  @override
  Future<InvoiceItemsBatch> itemsForInvoices(List<String> invoiceIds) async {
    if (offline) throw const NetworkException();
    return InvoiceItemsBatch(
      items: {for (final id in invoiceIds) id: const <InvoiceItem>[]},
      failed: const {},
    );
  }
}
