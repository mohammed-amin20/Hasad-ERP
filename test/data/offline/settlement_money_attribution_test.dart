import 'dart:convert';
import 'dart:io';

// Scoped to `Value` on purpose: a bare `package:drift/drift.dart` import
// collides with `package:matcher` on `isNull` in test files.
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasad_erp/data/offline/local_database.dart';
import 'package:hasad_erp/data/offline/local_store.dart';
import 'package:hasad_erp/data/offline/offline_sync.dart';
import 'package:hasad_erp/data/offline/offline_write.dart';
import 'package:hasad_erp/domain/payments/payment_repository.dart';
import 'package:path/path.dart' as p;

/// P1.1 -- invoice-money marker ownership for `settle_supplier` legs.
///
/// The invariant under test:
///
///   a `local_invoices.pendingMoneyLeg` marker may only be dropped once NO
///   money leg that affects that invoice is still active (pending / retrying /
///   parked). While such a leg exists the locally-corrected `paid`, `remaining`
///   and `status` MUST stay authoritative, and the server / cache MUST NOT win.
///
/// The gap this file closes: attribution used to be re-derived from a leg's
/// RPC params via `p_invoice_id`, and `SettlementDraft.toJson` never carries an
/// invoice id (the server chooses what to allocate). So a settlement could not
/// be attributed, and a LATER payment draining first cleared the marker the
/// still-queued settlement owned -- handing the row back to a server figure
/// that knows about neither mutation.
///
/// Note on the sync target used here: `failRpcs` blocks an RPC BY NAME for the
/// whole flush. A "fail the first N calls" counter is NOT enough to pin these
/// states, because `SyncFlusher` rescans after each success and would let the
/// settlement land later in the SAME pass, so the intermediate marker state
/// would never be observable.
void main() {
  late AppDatabase db;
  late DriftLocalStore store;
  late OfflineWriteCoordinator writer;

  const tenant = 't1';

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = DriftLocalStore(db);
    writer = OfflineWriteCoordinator(store, tenant);
  });

  tearDown(() => db.close());

  Future<void> seedChart() async {
    for (final a in const [
      ('a1', '1010', 'cash', 'asset'),
      ('a2', '1015', 'bank', 'asset'),
      ('a5', '2010', 'payable', 'liability'),
    ]) {
      await store.upsertAccount(LocalAccountRow(
        id: a.$1,
        tenantId: tenant,
        code: a.$2,
        name: a.$3,
        type: a.$4,
        parentCode: null,
      ));
    }
    await store.upsertSupplier(LocalSupplierRow(
      id: 's1',
      tenantId: tenant,
      name: 'supplier',
      phone: null,
      notes: null,
      dealType: 'direct',
      commissionRate: null,
      createdAt: DateTime(2026, 1, 1),
      synced: true,
    ));
  }

  /// A purchase invoice that already exists on the server: mirrored, `synced`.
  /// [date] drives the engine's oldest-first settlement allocation, so it must
  /// differ between fixtures whenever a test needs a deterministic order.
  Future<String> seedSyncedPurchase({
    required String id,
    required DateTime date,
    int total = 10000,
    int paid = 0,
    String invoiceTenant = tenant,
    String partyId = 's1',
  }) async {
    final status =
        paid >= total ? 'paid' : (paid > 0 ? 'partial' : 'unpaid');
    await store.upsertInvoice(LocalInvoiceRow(
      id: id,
      tenantId: invoiceTenant,
      type: 'purchase',
      no: 'P-1',
      partyId: partyId,
      partyName: 'supplier',
      date: date,
      subtotal: total,
      total: total,
      paid: paid,
      remaining: total - paid,
      status: status,
      ownership: 'owned',
      requestId: null,
      synced: true,
      createdAt: date,
    ));
    return id;
  }

  Future<LocalInvoiceRow> invoice(String id, {String of = tenant}) async =>
      (await store.invoices(of, type: 'purchase'))
          .firstWhere((r) => r.id == id);

  /// The queue legs of the money pipeline, by rpc name.
  Future<List<SyncQueueRow>> moneyLegs() async {
    final legs = await store.queueLegsFor(tenant, entity: 'payments');
    return legs;
  }

  group('P1.1 - settlement money attribution', () {
    test(
        'a payment draining while its settlement is still queued must NOT '
        'clear the marker the settlement owns', () async {
      await seedChart();
      final invA = await seedSyncedPurchase(
          id: 'inv-a', date: DateTime(2026, 1, 1), total: 10000);

      // An offline settlement that locally allocates to inv-a. Its RPC params
      // name a supplier, never an invoice.
      await writer.settleSupplier(SettlementDraft(
        supplierId: 's1',
        amount: 6000,
        method: 'cash',
        date: DateTime(2026, 3, 1),
      ));
      final settlementLeg = (await moneyLegs())
          .singleWhere((l) => l.rpc == 'settle_supplier');
      expect((await invoice(invA)).pendingMoneyLeg, settlementLeg.id);

      // Before it drains, the user pays the SAME invoice again.
      await writer.recordPayment(PaymentDraft(
        invoiceId: invA,
        amount: 2000,
        method: 'cash',
        date: DateTime(2026, 3, 2),
      ));
      final paymentLeg = (await moneyLegs())
          .singleWhere((l) => l.rpc == 'record_payment');
      expect((await invoice(invA)).pendingMoneyLeg, paymentLeg.id,
          reason: 'the newest money write takes over the marker');
      expect((await invoice(invA)).paid, 8000);
      expect((await invoice(invA)).remaining, 2000);

      // The newer payment reaches the server; the settlement does not.
      final first = await SyncFlusher(
        store,
        tenant,
        _ScriptedSyncTarget(blockedRpcs: const {'settle_supplier'}),
      ).flush();
      expect(first.synced, 1, reason: 'the payment replayed');
      expect(first.failed, 1, reason: 'the settlement was rejected');

      // The settlement is still queued, so inv-a is still locally owned --
      // including by the amounts the settlement applied that the server has
      // never seen. Clearing here is the original issue-3 symptom through a
      // narrower door.
      final after = await invoice(invA);
      expect(after.pendingMoneyLeg, settlementLeg.id,
          reason: 'an active settlement leg must keep its marker alive');
      expect(after.paid, 8000, reason: 'local money figures stay authoritative');
      expect(after.remaining, 2000);
      expect(after.status, 'partial');

      // Now the settlement drains too: nothing money-related is outstanding.
      final second = await SyncFlusher(store, tenant, _ScriptedSyncTarget())
          .flush();
      expect(second.synced, 1);

      final done = await invoice(invA);
      expect(done.pendingMoneyLeg, isNull,
          reason: 'with no active money leg the server regains authority');
      expect(done.paid, 8000);
      expect(done.remaining, 2000);
    });

    test(
        'a settlement spanning two invoices protects BOTH, including the one '
        'that later takes a payment', () async {
      await seedChart();
      final invA = await seedSyncedPurchase(
          id: 'inv-a', date: DateTime(2026, 1, 1), total: 10000);
      final invB = await seedSyncedPurchase(
          id: 'inv-b', date: DateTime(2026, 2, 1), total: 10000);

      // Oldest-first allocation: inv-a takes 10000, inv-b takes the remaining
      // 5000. Both rows are restated locally, so both must be attributed.
      await writer.settleSupplier(SettlementDraft(
        supplierId: 's1',
        amount: 15000,
        method: 'cash',
        date: DateTime(2026, 3, 1),
      ));
      final settlementLeg =
          (await moneyLegs()).singleWhere((l) => l.rpc == 'settle_supplier');
      expect((await invoice(invA)).paid, 10000);
      expect((await invoice(invB)).paid, 5000);

      // Only inv-b gets a later payment; inv-a is untouched by it.
      await writer.recordPayment(PaymentDraft(
        invoiceId: invB,
        amount: 1000,
        method: 'cash',
        date: DateTime(2026, 3, 2),
      ));

      await SyncFlusher(
        store,
        tenant,
        _ScriptedSyncTarget(blockedRpcs: const {'settle_supplier'}),
      ).flush();

      // inv-b is the one that just lost its own marker to the payment leg, so
      // it is the one that proves the settlement was attributed to it.
      for (final id in [invA, invB]) {
        final row = await invoice(id);
        expect(row.pendingMoneyLeg, settlementLeg.id,
            reason: '$id must stay owned by the still-queued settlement');
      }
      expect((await invoice(invB)).paid, 6000);
      expect((await invoice(invB)).remaining, 4000);

      // Draining the settlement clears every invoice it restated.
      await SyncFlusher(store, tenant, _ScriptedSyncTarget()).flush();
      expect((await invoice(invA)).pendingMoneyLeg, isNull);
      expect((await invoice(invB)).pendingMoneyLeg, isNull);
    });

    test('a retrying settlement leg (status pending) keeps its markers',
        () async {
      await seedChart();
      final invA = await seedSyncedPurchase(
          id: 'inv-a', date: DateTime(2026, 1, 1), total: 10000);

      await writer.settleSupplier(SettlementDraft(
        supplierId: 's1',
        amount: 4000,
        method: 'cash',
        date: DateTime(2026, 3, 1),
      ));
      final legId =
          (await moneyLegs()).singleWhere((l) => l.rpc == 'settle_supplier').id;

      final summary = await SyncFlusher(
        store,
        tenant,
        _ScriptedSyncTarget(blockedRpcs: const {'settle_supplier'}),
      ).flush();
      expect(summary.synced, 0);

      // A first transient failure returns the leg to `pending` (attempts 1),
      // NOT `failed` -- only exhausting kSyncMaxAttempts parks it.
      final leg = (await moneyLegs()).singleWhere((l) => l.id == legId);
      expect(leg.status, 'pending');
      expect(leg.attempts, 1);

      expect((await invoice(invA)).pendingMoneyLeg, legId);
      expect((await invoice(invA)).remaining, 6000);
    });

    test('a permanently parked (failed) settlement leg keeps its markers',
        () async {
      // Deliberate liveness trade-off, documented rather than designed away: a
      // leg parked `failed` is still an unsynchronized local financial
      // mutation, so the marker stays. The alternative -- letting the server
      // win -- would show figures that predate the user's own offline
      // settlement. Recovery UX is out of scope for this slice.
      await seedChart();
      final invA = await seedSyncedPurchase(
          id: 'inv-a', date: DateTime(2026, 1, 1), total: 10000);

      await writer.settleSupplier(SettlementDraft(
        supplierId: 's1',
        amount: 4000,
        method: 'cash',
        date: DateTime(2026, 3, 1),
      ));
      final legId =
          (await moneyLegs()).singleWhere((l) => l.rpc == 'settle_supplier').id;

      // Burn the whole attempt budget; the last failure parks the leg.
      for (var i = 0; i < kSyncMaxAttempts; i++) {
        await SyncFlusher(
          store,
          tenant,
          _ScriptedSyncTarget(blockedRpcs: const {'settle_supplier'}),
        ).flush();
      }
      final leg = (await moneyLegs()).singleWhere((l) => l.id == legId);
      expect(leg.status, 'failed');
      // `markFailed` parks the leg WITHOUT bumping attempts (only
      // `requeueRetry` records them), so the last recorded rung is one short
      // of the budget. Pinned because a test that assumed `attempts == 5` here
      // would be asserting a number the queue never stores.
      expect(leg.attempts, kSyncMaxAttempts - 1);

      expect((await invoice(invA)).pendingMoneyLeg, legId,
          reason: 'a failed leg never reached the server, so it still owns it');
      expect((await invoice(invA)).remaining, 6000);
    });

    test('an idempotent duplicate settlement replay still clears the marker',
        () async {
      await seedChart();
      final invA = await seedSyncedPurchase(
          id: 'inv-a', date: DateTime(2026, 1, 1), total: 10000);

      await writer.settleSupplier(SettlementDraft(
        supplierId: 's1',
        amount: 4000,
        method: 'cash',
        date: DateTime(2026, 3, 1),
      ));

      // The server had already committed this request (a lost response) and
      // answers with the duplicate envelope. The money DID land, so the marker
      // must still be released.
      final summary =
          await SyncFlusher(store, tenant, _ScriptedSyncTarget(duplicate: true))
              .flush();
      expect(summary.synced, 1);

      expect((await invoice(invA)).pendingMoneyLeg, isNull);
      expect((await invoice(invA)).remaining, 6000);
    });

    test('draining one tenant leaves another tenant untouched', () async {
      // `local_invoices` and `local_suppliers` are keyed on `{id}` alone
      // (server uuids are globally unique), so two workspaces cannot hold the
      // same invoice id. The real isolation risk is the resolver's SCANS: an
      // unscoped "which money legs are still active" query would let one
      // workspace's leg decide another workspace's marker.
      const other = 't2';
      final bWriter = OfflineWriteCoordinator(store, other);

      for (final entry in const [
        (tenant, 's-a'),
        (other, 's-b'),
      ]) {
        final (t, supplierId) = entry;
        for (final a in const [
          ('a1', '1010', 'cash', 'asset'),
          ('a5', '2010', 'payable', 'liability'),
        ]) {
          await store.upsertAccount(LocalAccountRow(
            id: '${t}_${a.$1}',
            tenantId: t,
            code: a.$2,
            name: a.$3,
            type: a.$4,
            parentCode: null,
          ));
        }
        await store.upsertSupplier(LocalSupplierRow(
          id: supplierId,
          tenantId: t,
          name: 'supplier',
          phone: null,
          notes: null,
          dealType: 'direct',
          commissionRate: null,
          createdAt: DateTime(2026, 1, 1),
          synced: true,
        ));
        await seedSyncedPurchase(
          id: 'inv-${t == tenant ? 'a' : 'b'}',
          date: DateTime(2026, 1, 1),
          invoiceTenant: t,
          partyId: supplierId,
        );
      }

      // Both workspaces run the same overlapping scenario offline.
      await writer.settleSupplier(SettlementDraft(
        supplierId: 's-a',
        amount: 4000,
        method: 'cash',
        date: DateTime(2026, 3, 1),
      ));
      await writer.recordPayment(PaymentDraft(
        invoiceId: 'inv-a',
        amount: 1000,
        method: 'cash',
        date: DateTime(2026, 3, 2),
      ));

      await bWriter.settleSupplier(SettlementDraft(
        supplierId: 's-b',
        amount: 9000,
        method: 'cash',
        date: DateTime(2026, 3, 1),
      ));
      final bSettlementLeg =
          (await store.queueLegsFor(other, entity: 'payments'))
              .singleWhere((l) => l.rpc == 'settle_supplier');

      // Drain ONLY tenant A, completely.
      await SyncFlusher(store, tenant, _ScriptedSyncTarget()).flush();

      // A is finished...
      expect((await invoice('inv-a')).pendingMoneyLeg, isNull);
      expect((await invoice('inv-a')).paid, 5000);
      expect((await invoice('inv-a')).remaining, 5000);

      // ...and B is exactly as it was: its own marker, its own figures, its
      // own leg still queued.
      final bRow = await invoice('inv-b', of: other);
      expect(bRow.pendingMoneyLeg, bSettlementLeg.id);
      expect(bRow.paid, 9000);
      expect(bRow.remaining, 1000);
      expect(
        (await store.queueLegsFor(other, entity: 'payments'))
            .single
            .status,
        'pending',
        reason: "another tenant's flush must not mark this leg synced",
      );
    });

    test(
        'another tenant\'s leg attributing THIS tenant\'s invoice must not '
        're-stamp this tenant\'s marker', () async {
      // The sharpest isolation case, and the one the tenant filter on the
      // outstanding-leg scan exists for. Attribution is local metadata read
      // back out of the queue, so it is untrusted input: if the scan were not
      // tenant-scoped, a foreign leg naming our invoice would be treated as
      // still owning it and our marker would be re-stamped to a leg id from
      // another workspace -- a marker no local write could ever clear.
      await seedChart();
      final invA = await seedSyncedPurchase(
          id: 'inv-a', date: DateTime(2026, 1, 1), total: 10000);

      await writer.settleSupplier(SettlementDraft(
        supplierId: 's1',
        amount: 6000,
        method: 'cash',
        date: DateTime(2026, 3, 1),
      ));
      final settlementLeg =
          (await moneyLegs()).singleWhere((l) => l.rpc == 'settle_supplier');
      await writer.recordPayment(PaymentDraft(
        invoiceId: invA,
        amount: 1000,
        method: 'cash',
        date: DateTime(2026, 3, 2),
      ));

      // A foreign-tenant leg claiming our invoice, OLDER than our settlement so
      // that an unscoped scan would pick it first and win.
      await store.enqueue(SyncQueueRow(
        id: 'foreign-leg',
        tenantId: 't2',
        rpc: 'settle_supplier',
        op: 'rpc',
        params: jsonEncode({'p_supplier_id': 'other-supplier'}),
        entity: 'payments',
        status: 'pending',
        attempts: 0,
        affectsInvoiceIds: jsonEncode([invA]),
        createdAt: DateTime(2020),
        updatedAt: DateTime(2020),
      ));

      // Drain the payment only; the settlement stays queued.
      await SyncFlusher(
        store,
        tenant,
        _ScriptedSyncTarget(blockedRpcs: const {'settle_supplier'}),
      ).flush();

      expect((await invoice(invA)).pendingMoneyLeg, settlementLeg.id,
          reason: "the marker must name OUR still-queued leg, never a foreign "
              "tenant's");
    });

    test('the recorded attribution matches exactly the rows it stamped',
        () async {
      // Guards the one place the two could silently diverge: attribution is
      // derived from `allocations` before the stamping loop walks the same
      // list, so a future change to either could drift apart and the marker
      // would then be owned by a set that does not match the figures.
      await seedChart();
      final invA = await seedSyncedPurchase(
          id: 'inv-a', date: DateTime(2026, 1, 1), total: 10000);
      final invB = await seedSyncedPurchase(
          id: 'inv-b', date: DateTime(2026, 2, 1), total: 10000);
      final untouched = await seedSyncedPurchase(
          id: 'inv-c', date: DateTime(2026, 3, 1), total: 10000);

      await writer.settleSupplier(SettlementDraft(
        supplierId: 's1',
        amount: 15000,
        method: 'cash',
        date: DateTime(2026, 4, 1),
      ));

      final leg = (await moneyLegs())
          .singleWhere((l) => l.rpc == 'settle_supplier');
      final recorded =
          LocalStore.parseInvoiceAttribution(leg.affectsInvoiceIds).toSet();

      // A settlement names no invoice in its RPC body: the attribution column
      // is the only place this set exists.
      expect(jsonDecode(leg.params), isNot(contains('p_invoice_id')));
      expect(recorded, {invA, invB});
      expect(recorded, isNot(contains(untouched)),
          reason: 'a row the settlement did not restate must not be claimed');

      // And it agrees with the markers the same transaction wrote.
      final stamped = {
        for (final r in await store.invoices(tenant, type: 'purchase'))
          if (r.pendingMoneyLeg == leg.id) r.id
      };
      expect(stamped, recorded);
    });

    test('a record_payment leg records its single invoice as its attribution',
        () async {
      await seedChart();
      final invA = await seedSyncedPurchase(
          id: 'inv-a', date: DateTime(2026, 1, 1), total: 10000);

      await writer.recordPayment(PaymentDraft(
        invoiceId: invA,
        amount: 1000,
        method: 'cash',
        date: DateTime(2026, 3, 2),
      ));

      final leg =
          (await moneyLegs()).singleWhere((l) => l.rpc == 'record_payment');
      expect(LocalStore.parseInvoiceAttribution(leg.affectsInvoiceIds), [invA]);
    });

    test('malformed attribution degrades instead of throwing', () async {
      // A corrupt column must not be able to crash a flush, and must not
      // silently claim the leg affects nothing either: it falls back to the
      // pre-v7 params, which is exact for a payment and empty for a
      // settlement.
      expect(LocalStore.parseInvoiceAttribution(null), isEmpty);
      expect(LocalStore.parseInvoiceAttribution('not json'), isEmpty);
      expect(LocalStore.parseInvoiceAttribution('{"a":1}'), isEmpty);
      expect(LocalStore.parseInvoiceAttribution('[1,null,"inv-a",""]'),
          ['inv-a']);
      expect(LocalStore.parseDependencies('not json'), isEmpty);

      await seedChart();
      final invA = await seedSyncedPurchase(
          id: 'inv-a', date: DateTime(2026, 1, 1), total: 10000);

      // A settlement leg with unreadable attribution is attributed to nothing,
      // which is the honest reading: an unreadable set is not evidence of one.
      await store.enqueue(SyncQueueRow(
        id: 'corrupt-settlement',
        tenantId: tenant,
        rpc: 'settle_supplier',
        op: 'rpc',
        params: jsonEncode({'p_supplier_id': 's1', 'p_amount': 1000}),
        entity: 'payments',
        status: 'pending',
        attempts: 0,
        affectsInvoiceIds: 'not json',
        createdAt: DateTime(2026, 3, 1),
        updatedAt: DateTime(2026, 3, 1),
      ));
      await db.update(db.localInvoices).write(
        const LocalInvoicesCompanion(pendingMoneyLeg: Value('syncing-leg')),
      );
      await store.enqueue(SyncQueueRow(
        id: 'syncing-leg',
        tenantId: tenant,
        rpc: 'record_payment',
        op: 'rpc',
        params: jsonEncode({'p_invoice_id': invA}),
        entity: 'payments',
        status: 'synced',
        attempts: 0,
        createdAt: DateTime(2026, 3, 2),
        updatedAt: DateTime(2026, 3, 2),
      ));

      await store.resolveInvoiceMoneyMarker(tenant, 'syncing-leg');
      expect((await invoice(invA)).pendingMoneyLeg, isNull,
          reason: 'neither the corrupt leg nor the excluded one may hold it');
    });

    test('outstanding legs are ordered by (createdAt, id), deterministically',
        () async {
      // Two outstanding legs for ONE invoice sharing a timestamp -- exactly the
      // same-millisecond case that makes `createdAt` alone a non-total order.
      // The tie-break is what keeps marker resolution reproducible, so the legs
      // are inserted in DESCENDING id order: an implementation that ordered by
      // `createdAt` alone would keep query order and pick 'leg-zzz'.
      await seedChart();
      final invA = await seedSyncedPurchase(
          id: 'inv-a', date: DateTime(2026, 1, 1), total: 10000);

      final at = DateTime(2026, 3, 1);
      for (final id in const ['leg-zzz', 'leg-mmm', 'leg-aaa']) {
        await store.enqueue(SyncQueueRow(
          id: id,
          tenantId: tenant,
          rpc: 'settle_supplier',
          op: 'rpc',
          params: jsonEncode({'p_supplier_id': 's1'}),
          entity: 'payments',
          status: 'pending',
          attempts: 0,
          affectsInvoiceIds: jsonEncode([invA]),
          createdAt: at,
          updatedAt: at,
        ));
      }
      await store.enqueue(SyncQueueRow(
        id: 'leg-done',
        tenantId: tenant,
        rpc: 'record_payment',
        op: 'rpc',
        params: jsonEncode({'p_invoice_id': invA}),
        entity: 'payments',
        status: 'synced',
        attempts: 0,
        createdAt: at,
        updatedAt: at,
      ));
      await db.update(db.localInvoices).write(
        const LocalInvoicesCompanion(pendingMoneyLeg: Value('leg-done')),
      );

      await store.resolveInvoiceMoneyMarker(tenant, 'leg-done');
      expect((await invoice(invA)).pendingMoneyLeg, 'leg-aaa',
          reason: 'equal timestamps must resolve by id, not by row order');
    });

    test('resolution depends on the queue, not on which leg held the marker',
        () async {
      // The self-healing property, and the only thing that distinguishes the
      // approved union (stamped set ∪ attribution) from using the stamped set
      // alone. Every other test here passes with either variant, because a
      // stamp-only resolver and a union resolver both leave the marker naming
      // *some* outstanding leg. This one does not.
      //
      // What it pins: the resolved marker is a function of the QUEUE, so an
      // invoice whose marker was set by an out-of-order write still lands on the
      // same answer. Re-stamping the oldest outstanding leg is otherwise
      // arbitrary-but-valid, which is precisely why it needs a test to not drift
      // into depending on marker history.
      await seedChart();
      final invA = await seedSyncedPurchase(
          id: 'inv-a', date: DateTime(2026, 1, 1), total: 10000);

      // Two outstanding legs for inv-a; the marker currently names the NEWER one.
      final early = DateTime(2026, 3, 1);
      final late = DateTime(2026, 3, 5);
      for (final leg in [
        (id: 'leg-old', at: early),
        (id: 'leg-new', at: late),
      ]) {
        await store.enqueue(SyncQueueRow(
          id: leg.id,
          tenantId: tenant,
          rpc: 'settle_supplier',
          op: 'rpc',
          params: jsonEncode({'p_supplier_id': 's1'}),
          entity: 'payments',
          status: 'pending',
          attempts: 0,
          affectsInvoiceIds: jsonEncode([invA]),
          createdAt: leg.at,
          updatedAt: leg.at,
        ));
      }
      // A leg that has already drained but DID restate inv-a.
      await store.enqueue(SyncQueueRow(
        id: 'leg-drained',
        tenantId: tenant,
        rpc: 'record_payment',
        op: 'rpc',
        params: jsonEncode({'p_invoice_id': invA}),
        entity: 'payments',
        status: 'synced',
        attempts: 0,
        affectsInvoiceIds: jsonEncode([invA]),
        createdAt: early,
        updatedAt: early,
      ));
      await db.update(db.localInvoices).write(
        const LocalInvoicesCompanion(pendingMoneyLeg: Value('leg-new')),
      );

      await store.resolveInvoiceMoneyMarker(tenant, 'leg-drained');

      expect((await invoice(invA)).pendingMoneyLeg, 'leg-old',
          reason: 'the marker must be re-decided from the queue, not left on '
              'whichever leg last stamped it');
    });

    test('resolving a leg that is not this tenant\'s own is a no-op', () async {
      // Reachable shape: an invoice whose marker names one leg, resolved by a
      // leg id that is unknown or owned by another workspace. Neither the
      // marker set nor the attribution set contains anything, so nothing moves.
      //
      // Note what is deliberately NOT asserted: that resolving a foreign leg id
      // cannot clear a marker that happens to name it. That state is
      // unreachable -- a row's marker is only ever written by its own tenant's
      // coordinator with a leg id that coordinator minted -- so pinning it would
      // test a fiction, and guarding it would be dead code.
      await seedChart();
      final invA = await seedSyncedPurchase(
          id: 'inv-a', date: DateTime(2026, 1, 1), total: 10000);

      await writer.settleSupplier(SettlementDraft(
        supplierId: 's1',
        amount: 4000,
        method: 'cash',
        date: DateTime(2026, 3, 1),
      ));
      final own = (await moneyLegs())
          .singleWhere((l) => l.rpc == 'settle_supplier')
          .id;
      expect((await invoice(invA)).pendingMoneyLeg, own);

      await store.resolveInvoiceMoneyMarker(tenant, 'leg-that-does-not-exist');
      expect((await invoice(invA)).pendingMoneyLeg, own,
          reason: 'an unknown leg owns nothing and must clear nothing');

      // A leg that exists, but in another workspace.
      await store.enqueue(SyncQueueRow(
        id: 't2-leg',
        tenantId: 't2',
        rpc: 'settle_supplier',
        op: 'rpc',
        params: jsonEncode({'p_supplier_id': 's-other'}),
        entity: 'payments',
        status: 'pending',
        attempts: 0,
        affectsInvoiceIds: jsonEncode(['inv-other']),
        createdAt: DateTime(2020),
        updatedAt: DateTime(2020),
      ));
      await store.resolveInvoiceMoneyMarker(tenant, 't2-leg');
      expect((await invoice(invA)).pendingMoneyLeg, own,
          reason: "another tenant's leg must not decide this marker");
    });
  });

  test('leg attribution survives a process restart', () async {
    // File-backed on purpose: `NativeDatabase.memory()` cannot prove the column
    // is durable, and durability is the whole point -- the marker decision
    // happens in a later process against a leg written in an earlier one.
    final dir = Directory.systemTemp.createTempSync('hasad_attribution');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File(p.join(dir.path, 'hasad_offline.sqlite'));

    late DriftLocalStore first;
    {
      final db0 = AppDatabase(NativeDatabase(file));
      first = DriftLocalStore(db0);
      final w0 = OfflineWriteCoordinator(first, tenant);
      for (final a in const [
        ('a1', '1010', 'cash', 'asset'),
        ('a5', '2010', 'payable', 'liability'),
      ]) {
        await first.upsertAccount(LocalAccountRow(
          id: a.$1,
          tenantId: tenant,
          code: a.$2,
          name: a.$3,
          type: a.$4,
          parentCode: null,
        ));
      }
      await first.upsertSupplier(LocalSupplierRow(
        id: 's1',
        tenantId: tenant,
        name: 'supplier',
        phone: null,
        notes: null,
        dealType: 'direct',
        commissionRate: null,
        createdAt: DateTime(2026, 1, 1),
        synced: true,
      ));
      for (final e in [
        ('inv-a', DateTime(2026, 1, 1)),
        ('inv-b', DateTime(2026, 2, 1)),
      ]) {
        await first.upsertInvoice(LocalInvoiceRow(
          id: e.$1,
          tenantId: tenant,
          type: 'purchase',
          no: 'P-1',
          partyId: 's1',
          partyName: 'supplier',
          date: e.$2,
          subtotal: 10000,
          total: 10000,
          paid: 0,
          remaining: 10000,
          status: 'unpaid',
          ownership: 'owned',
          requestId: null,
          synced: true,
          createdAt: e.$2,
        ));
      }

      await w0.settleSupplier(SettlementDraft(
        supplierId: 's1',
        amount: 15000,
        method: 'cash',
        date: DateTime(2026, 3, 1),
      ));
      await w0.recordPayment(PaymentDraft(
        invoiceId: 'inv-b',
        amount: 1000,
        method: 'cash',
        date: DateTime(2026, 3, 2),
      ));
      await db0.close();
    }

    // A brand-new process over the same file.
    final db1 = AppDatabase(NativeDatabase(file));
    addTearDown(db1.close);
    final store1 = DriftLocalStore(db1);

    final settlementLeg = (await store1.queueLegsFor(tenant, entity: 'payments'))
        .singleWhere((l) => l.rpc == 'settle_supplier');
    expect(
        LocalStore.parseInvoiceAttribution(settlementLeg.affectsInvoiceIds),
        ['inv-a', 'inv-b'],
        reason: 'attribution is durable local metadata, not in-memory state');

    // The restart-time decision: the payment drains, the settlement does not,
    // and the marker survives because the SET survived.
    await SyncFlusher(
      store1,
      tenant,
      _ScriptedSyncTarget(blockedRpcs: const {'settle_supplier'}),
    ).flush();
    final rows = {for (final r in await store1.invoices(tenant, type: 'purchase')) r.id: r};
    expect(rows['inv-b']!.pendingMoneyLeg, settlementLeg.id);
    expect(rows['inv-a']!.pendingMoneyLeg, settlementLeg.id);
    expect(rows['inv-b']!.paid, 6000);
    expect(rows['inv-b']!.remaining, 4000);
  });
}

/// Blocks RPCs by name for the whole flush, so a test can keep one leg queued
/// across as many passes as it needs while the others drain.
class _ScriptedSyncTarget implements SyncTarget {
  _ScriptedSyncTarget({
    this.blockedRpcs = const {},
    this.duplicate = false,
  });

  final Set<String> blockedRpcs;
  final bool duplicate;

  @override
  Future<Map<String, dynamic>> rpc(
    String name,
    Map<String, dynamic> params,
  ) async {
    if (blockedRpcs.contains(name)) throw StateError('rejected $name');
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
