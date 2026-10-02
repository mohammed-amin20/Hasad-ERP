/// Issue 3, device follow-up — **an upgraded device that only ever reads its
/// durable report cache can never use an invoice for an offline money write**.
///
/// ## Why the device differs from the passing A1 tests
///
/// `OfflineInvoiceRepository.list()` cache-lasts its response and hands
/// `_mirrorHeaders` to `cacheLast` as the `mirror:` callback. `cacheLast` invokes
/// that callback **only after a successful network read**
/// (`offline_reads.dart:116-123`); its `on NetworkException` branch returns the
/// deserialized payload with `return fromCached(cached);`
/// (`offline_reads.dart:107`) and never reaches the mirror.
///
/// Every A1 case drives the *online* path, so the cache branch had **zero**
/// coverage — the fake's `offline` flag existed but no test used it. On a real
/// upgraded device the picture is the mirror image of the A1 harness:
///
/// ```
///   report_cache   HAS the invoice payload   (written by the OLD build)
///   local_invoices has NOTHING               (mirrorInvoices did not exist)
/// ```
///
/// The UI deserializes and paints the cached invoice (so the user *sees* it),
/// but `OfflineWriteCoordinator._invoice()` resolves its target by scanning
/// `local_invoices` and throws `الفاتورة غير موجودة محلياً`.
///
/// ## The invariant these cases pin
///
/// If `list()` returns invoice X to application code — from a fresh network
/// response **or** from durable `report_cache` — the corresponding local invoice
/// identity must be resolvable by the mutation layer before `list()` returns
/// control. The cases are deliberately split so a future failure can say *which*
/// link in the chain is broken, instead of one early failure hiding the rest.
/// All three links are now green:
///
///   A. the cached invoice renders
///   B. `local_invoices` is hydrated on whichever key the read used
///   C. the money mutation then succeeds
library;

import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasad_erp/core/error/app_exception.dart';
import 'package:hasad_erp/data/invoices/invoice_repository.dart';
import 'package:hasad_erp/data/offline/local_database.dart';
import 'package:hasad_erp/data/offline/local_store.dart';
import 'package:hasad_erp/data/offline/offline_invoice_repository.dart';
import 'package:hasad_erp/data/offline/offline_write.dart';
import 'package:hasad_erp/data/offline/report_keys.dart';
import 'package:hasad_erp/domain/invoices/invoice.dart';
import 'package:hasad_erp/domain/payments/payment_repository.dart';

void main() {
  const tenantA = 'tenant-a';
  const tenantB = 'tenant-b';

  late AppDatabase db;
  late DriftLocalStore store;
  late OfflineWriteCoordinator writer;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = DriftLocalStore(db);
    writer = OfflineWriteCoordinator(store, tenantA);
  });

  tearDown(() => db.close());

  /// 1010 backs a cash payment/settlement, 1015 the bank side, 1020 AR, 1030
  /// inventory, 2010 the purchase credit, 4010 revenue. Identical to the A1 seed
  /// so these cases stay comparable with that suite.
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
      name: 'مورد',
      phone: null,
      notes: null,
      dealType: 'direct',
      commissionRate: null,
      createdAt: DateTime(2026, 1, 1),
      synced: true,
    ));
  }

  /// The **exact** production report-cache payload shape, copied from
  /// `OfflineInvoiceRepository.list()`'s `toPayload`. A test that seeds a
  /// different shape would fail for the wrong reason — the deserializer only
  /// reads these keys, and `ownership`/`status` use `.name` / `.dbValue`.
  Map<String, dynamic> legacyHeader({
    String id = 'inv-server-1',
    String type = 'sale',
    String no = 'SALE-1001',
    String partyId = 'c1',
    String partyName = 'عميل',
    int total = 10000,
    int paid = 0,
    String status = 'unpaid',
    String ownership = 'owned',
  }) =>
      {
        'id': id,
        'type': type,
        'no': no,
        'party_id': partyId,
        'party_name': partyName,
        'date': '2026-03-01',
        'subtotal': total,
        'total': total,
        'paid': paid,
        'remaining': total - paid,
        'status': status,
        'ownership': ownership,
      };

  /// Models an upgraded device: the durable cache holds the invoice, the mirror
  /// does not. `invoiceListKey` is the same key the production `list()` computes
  /// for an unfiltered read of that type.
  ///
  /// A single-header cache is the overwhelmingly common shape; the multi-header
  /// variant exists for the cross-tenant partition, which is only observable
  /// when one row collides and the others do not.
  Future<void> seedLegacyCacheMany(
    String tenant,
    List<Map<String, dynamic>> headers, {
    required String type,
    String? search,
  }) async {
    final key = invoiceListKey(
      type: type,
      search: search,
      from: null,
      to: null,
    );
    await store.putReport(tenant, key, jsonEncode(headers));
  }

  /// The one-invoice case of [seedLegacyCacheMany].
  Future<void> seedLegacyCache(
    String tenant,
    Map<String, dynamic> header, {
    required String type,
    String? search,
  }) =>
      seedLegacyCacheMany(tenant, [header], type: type, search: search);

  /// The real repository over a server that is **unreachable** — the state an
  /// offline upgraded device is actually in.
  OfflineInvoiceRepository offlineRepo(String tenant) => OfflineInvoiceRepository(
        _UnreachableInvoices(),
        store: store,
        tenantId: tenant,
      );

  /// Exactly what `_invoice()` scans. If this is empty the mutation layer cannot
  /// resolve the identity, whatever the UI is showing.
  Future<bool> identityResolvable(String tenant, String invoiceId) async =>
      (await store.invoices(tenant)).any((r) => r.id == invoiceId);

  group('A. the cached invoice is still visible to the user', () {
    test('A1. an offline read of a legacy sale cache paints the invoice', () async {
      await seedChart(tenantA);
      await seedLegacyCache(tenantA, legacyHeader(), type: 'sale');

      // Precondition: this is the upgraded-device state. A legacy cache exists
      // and the mirror has never heard of the invoice.
      expect(await store.report(
        tenantA,
        invoiceListKey(type: 'sale', search: null, from: null, to: null),
      ), isNotNull);
      expect(await store.invoices(tenantA), isEmpty);

      final listed = await offlineRepo(tenantA).list(type: 'sale');

      expect(listed, hasLength(1),
          reason: 'the durable cache is rehydrated, so the row must render — '
              'this is the part that already works on the device');
      expect(listed.single.id, 'inv-server-1');
      expect(listed.single.no, 'SALE-1001');
      expect(listed.single.total, 10000);
    });

    test('A2. an offline read of a legacy purchase cache paints the invoice',
        () async {
      await seedChart(tenantA);
      await seedLegacyCache(
        tenantA,
        legacyHeader(
          id: 'inv-purchase-1',
          type: 'purchase',
          no: 'PUR-77',
          partyId: 's1',
          partyName: 'مورد',
        ),
        type: 'purchase',
      );

      final listed = await offlineRepo(tenantA).list(type: 'purchase');

      expect(listed, hasLength(1));
      expect(listed.single.id, 'inv-purchase-1');
    });
  });

  group('B. the mirror is hydrated from the durable cache too', () {
    test('B1. a cached sale read hydrates local_invoices', () async {
      await seedChart(tenantA);
      await seedLegacyCache(tenantA, legacyHeader(), type: 'sale');

      await offlineRepo(tenantA).list(type: 'sale');

      expect(await store.invoices(tenantA), hasLength(1),
          reason: 'a value handed to application code must be resolvable by the '
              'mutation layer, so the header must be mirrored on the cache path '
              'exactly as it is on the network path');
    });

    test('B2. a cached purchase read hydrates local_invoices', () async {
      await seedChart(tenantA);
      await seedLegacyCache(
        tenantA,
        legacyHeader(
          id: 'inv-purchase-1',
          type: 'purchase',
          no: 'PUR-77',
          partyId: 's1',
          partyName: 'مورد',
        ),
        type: 'purchase',
      );

      await offlineRepo(tenantA).list(type: 'purchase');

      expect(await store.invoices(tenantA), hasLength(1));
    });

    test('B3. the identity the UI was shown is resolvable immediately after the '
        'read returns', () async {
      await seedChart(tenantA);
      await seedLegacyCache(tenantA, legacyHeader(), type: 'sale');

      final listed = await offlineRepo(tenantA).list(type: 'sale');
      final shown = listed.single;

      expect(await identityResolvable(tenantA, shown.id), isTrue,
          reason: 'this is the exact lookup `OfflineWriteCoordinator._invoice()` '
              'performs; the invariant is that the list and the mutation layer '
              'never disagree about which invoice exists');
    });

    test('B4. a cache stored under a search-term key hydrates too', () async {
      // `invoiceListKey` embeds the search string, so an upgraded device's cache
      // is fragmented per query. Hydration must not assume one key.
      await seedChart(tenantA);
      await seedLegacyCache(tenantA, legacyHeader(no: 'SALE-1001'),
          type: 'sale', search: '1001');

      final listed = await offlineRepo(tenantA)
          .list(type: 'sale', search: '1001');

      expect(listed, hasLength(1));
      expect(await store.invoices(tenantA), hasLength(1),
          reason: 'a cache-only device hydrates on whichever key it reads');
    });
  });

  group('C. the money writes then succeed against the visible invoice', () {
    test('C1. an offline payment against the visible cached invoice records '
        'locally', () async {
      await seedChart(tenantA);
      await seedLegacyCache(tenantA, legacyHeader(), type: 'sale');
      final listed = await offlineRepo(tenantA).list(type: 'sale');

      final result = await writer.recordPayment(PaymentDraft(
        invoiceId: listed.single.id,
        amount: 4000,
        method: 'cash',
        date: DateTime(2026, 3, 2),
      ));

      expect(result.paid, 4000);
      expect(result.remaining, 6000);
      expect(result.pending, isTrue);

      final row = (await store.invoices(tenantA)).single;
      expect(row.paid, 4000);
      expect(row.remaining, 6000);
      expect(row.pendingMoneyLeg, isNotNull);
    });

    test('C1b. a payment against a MAPPED invoice resolves through the mapping',
        () async {
      // The second half of the defect, and the one C1 cannot reach.
      //
      // C1 pays the id it just read, and that id is the server id — so the
      // exact-local-id branch of the resolver always hits and `_invoice`'s
      // mapping fallback is never exercised. The state that actually breaks in
      // the field is the one D3 sets up: the row is keyed by the **local** uuid
      // (`markReplaySynced` keeps it so the badge join still matches) while the
      // invoice the list now serves arrives under the **server** id. Two id
      // spaces, one invoice, and a by-id money write that has to cross between
      // them or the payment is refused with `الفاتورة غير موجودة محلياً` on an
      // invoice the user is looking at.
      //
      // This case drives the write with the **server** id on purpose, so the
      // fallback is the only thing that can resolve it.
      await seedChart(tenantA);
      const localUuid = 'local-uuid-mapped';
      await store.upsertInvoice(LocalInvoiceRow(
        id: localUuid,
        tenantId: tenantA,
        type: 'sale',
        no: 'SALE-1001',
        partyId: 'c1',
        partyName: 'عميل',
        date: DateTime(2026, 3, 1),
        subtotal: 10000,
        total: 10000,
        paid: 0,
        remaining: 10000,
        status: 'unpaid',
        ownership: 'owned',
        requestId: null,
        synced: true,
        createdAt: null,
      ));
      await store.putMapping(
        tenantId: tenantA,
        entity: 'invoices',
        localId: localUuid,
        serverId: 'inv-server-1',
      );

      final result = await writer.recordPayment(PaymentDraft(
        invoiceId: 'inv-server-1',
        amount: 4000,
        method: 'cash',
        date: DateTime(2026, 3, 2),
      ));

      expect(result.paid, 4000);
      expect(result.remaining, 6000);
      expect(result.pending, isTrue);

      final row = (await store.invoices(tenantA)).single;
      expect(row.id, localUuid,
          reason: 'the write targets the mapped row in place; it must not '
              're-key it to the server id');
      expect(row.paid, 4000, reason: 'the money figures the user will see');
      expect(row.pendingMoneyLeg, isNotNull);
    });

    test('C1c. a payment for an unmapped, unknown id still fails honestly',
        () async {
      // The flip side. "Resolve through the mapping" must not degrade into
      // "resolve anything": an id that is neither local nor mapped has no
      // invoice behind it, and the honest Arabic refusal is the correct
      // outcome. A fallback that invented a row here would be worse than the
      // bug it replaces.
      await seedChart(tenantA);
      await seedLegacyCache(tenantA, legacyHeader(), type: 'sale');
      await offlineRepo(tenantA).list(type: 'sale');

      await expectLater(
        writer.recordPayment(PaymentDraft(
          invoiceId: 'inv-never-seen',
          amount: 1000,
          method: 'cash',
          date: DateTime(2026, 3, 2),
        )),
        throwsA(isA<ValidationException>()),
      );
      expect((await store.invoices(tenantA)).single.paid, 0,
          reason: 'the refused payment must not have written anything');
    });

    test('C2. an offline settlement against the visible cached purchase invoice '
        'allocates to it', () async {
      await seedChart(tenantA);
      await seedLegacyCache(
        tenantA,
        legacyHeader(
          id: 'inv-purchase-1',
          type: 'purchase',
          no: 'PUR-77',
          partyId: 's1',
          partyName: 'مورد',
        ),
        type: 'purchase',
      );
      final listed = await offlineRepo(tenantA).list(type: 'purchase');

      final result = await writer.settleSupplier(SettlementDraft(
        supplierId: 's1',
        amount: 6000,
        method: 'cash',
        date: DateTime(2026, 3, 5),
      ));

      expect(result.allocations.map((a) => a.invoiceId), contains(listed.single.id),
          reason: 'the settlement must allocate against the invoice the user can '
              'see, not against an empty candidate set');
      expect(result.invoicesCount, 1,
          reason: 'a silent 0 here is the reported under-allocation');
      expect(result.total, 6000);
    });

    test('C3. a settlement on a cache-only device must still reach its '
        'invoices', () async {
      // The settlement path enumerates `_ownedInvoiceRows` rather than resolving
      // one id, so with an empty mirror there are no candidates — and the debt
      // pre-flight (`offline_write.dart:1508`) then rejects the amount against
      // a computed debt of zero with `المبلغ المطلوب تسويته أكبر من ديون المورد`.
      //
      // Worth stating plainly, because it was my first assumption and it was
      // wrong: this is **not** a silent 0-allocation. There is a guard. The
      // guard's own error is what the user sees, and it is wrong in a way that
      // sends them looking for a missing invoice rather than a paid one.
      await seedChart(tenantA);
      await seedLegacyCache(
        tenantA,
        legacyHeader(
          id: 'inv-purchase-1',
          type: 'purchase',
          no: 'PUR-77',
          partyId: 's1',
          partyName: 'مورد',
        ),
        type: 'purchase',
      );
      await offlineRepo(tenantA).list(type: 'purchase');

      final result = await writer.settleSupplier(SettlementDraft(
        supplierId: 's1',
        amount: 6000,
        method: 'cash',
        date: DateTime(2026, 3, 5),
      ));

      expect(result.invoicesCount, greaterThan(0),
          reason: 'with a visible unpaid purchase the settlement has a real '
              'candidate; today the empty mirror leaves it nothing to allocate '
              'against and the debt pre-flight rejects the amount instead');
      expect(result.total, 6000);
    });
  });

  group('D. authority preservation on the hydration path', () {
    test('D1. hydrating a cache must not touch an unsynced local draft '
        '(synced == false)', () async {
      await seedChart(tenantA);
      await store.upsertInvoice(LocalInvoiceRow(
        id: 'inv-server-1',
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
        requestId: 'req-local',
        synced: false,
        createdAt: DateTime(2026, 3, 1),
      ));
      await seedLegacyCache(tenantA, legacyHeader(no: 'SALE-1001'),
          type: 'sale');

      await offlineRepo(tenantA).list(type: 'sale');

      final rows = await store.invoices(tenantA);
      expect(rows, hasLength(1), reason: 'the draft must not be replaced or '
          'duplicated by a read that predates it');
      expect(rows.single.synced, isFalse);
      expect(rows.single.requestId, 'req-local');
      expect(rows.single.no, 'D-0001');
      expect(rows.single.total, 5000);
    });

    test('D2. hydrating a cache must not clear a live pendingMoneyLeg', () async {
      await seedChart(tenantA);
      await store.upsertInvoice(LocalInvoiceRow(
        id: 'inv-server-1',
        tenantId: tenantA,
        type: 'sale',
        no: 'SALE-1001',
        partyId: 'c1',
        partyName: 'عميل',
        date: DateTime(2026, 3, 1),
        subtotal: 10000,
        total: 10000,
        paid: 4000,
        remaining: 6000,
        status: 'partial',
        ownership: 'owned',
        requestId: null,
        synced: true,
        createdAt: null,
        pendingMoneyLeg: 'leg-1',
      ));
      // The server still reports the PRE-payment figures; the leg has not
      // replayed so it cannot know about them.
      await seedLegacyCache(
        tenantA,
        legacyHeader(no: 'SALE-1001', paid: 0, status: 'unpaid'),
        type: 'sale',
      );

      await offlineRepo(tenantA).list(type: 'sale');

      final after = (await store.invoices(tenantA)).single;
      expect(after.paid, 4000, reason: 'pending local money is authoritative');
      expect(after.remaining, 6000);
      expect(after.status, 'partial');
      expect(after.pendingMoneyLeg, 'leg-1',
          reason: 'a read must never retire a live marker');
    });

    test('D3. a mapped local id is refreshed in place, never re-keyed and never '
        'duplicated', () async {
      await seedChart(tenantA);
      // The post-replay shape: the row keeps the LOCAL uuid (the sync badge joins
      // on the leg's localId) and id_map records local -> server.
      final localId = 'local-uuid-1';
      await store.upsertInvoice(LocalInvoiceRow(
        id: localId,
        tenantId: tenantA,
        type: 'sale',
        no: 'SALE-1001',
        partyId: 'c1',
        partyName: 'عميل',
        date: DateTime(2026, 3, 1),
        subtotal: 10000,
        total: 10000,
        paid: 0,
        remaining: 10000,
        status: 'unpaid',
        ownership: 'owned',
        requestId: null,
        synced: true,
        createdAt: null,
      ));
      await store.putMapping(
        tenantId: tenantA,
        entity: 'invoices',
        localId: localId,
        serverId: 'inv-server-1',
      );
      await seedLegacyCache(tenantA, legacyHeader(), type: 'sale');

      final listed = await offlineRepo(tenantA).list(type: 'sale');
      expect(listed, hasLength(1));

      final rows = await store.invoices(tenantA);
      expect(rows, hasLength(1),
          reason: 'the same invoice under two keys is one invoice, not two');
      expect(rows.single.id, localId,
          reason: 're-keying to the server id would break the badge join');
    });

    test('D4a. hydrating a cache must not overwrite another tenant\'s row with '
        'the same id', () async {
      await seedChart(tenantA);
      await store.upsertInvoice(LocalInvoiceRow(
        id: 'inv-server-1',
        tenantId: tenantB,
        type: 'sale',
        no: 'OTHER-9',
        partyId: 'c9',
        partyName: 'طرف آخر',
        date: DateTime(2026, 3, 1),
        subtotal: 777,
        total: 777,
        paid: 0,
        remaining: 777,
        status: 'unpaid',
        ownership: 'owned',
        requestId: null,
        synced: true,
        createdAt: null,
      ));
      await seedLegacyCache(tenantA, legacyHeader(), type: 'sale');

      await offlineRepo(tenantA).list(type: 'sale');

      final other = (await store.invoices(tenantB)).single;
      expect(other.no, 'OTHER-9',
          reason: 'the id-only primary key means an unguarded write would have '
              'destroyed another workspace\'s invoice');
      expect(other.total, 777);
    });

    test('D4b. the colliding row is skipped and its safe siblings still '
        'hydrate', () async {
      // The point of the partition. `local_invoices` is keyed `{id}` alone, so
      // an incoming id that belongs to another tenant is a structural
      // collision, not a stale row to overwrite. Skipping **only** that id —
      // rather than aborting the whole batch — is what keeps one neighbour's
      // uuid from costing this workspace every other invoice on the screen.
      // A batch-wide bail would still pass D4a, so D4a alone proves nothing
      // about the siblings; this case is the one with teeth.
      await seedChart(tenantA);
      await store.upsertInvoice(LocalInvoiceRow(
        id: 'inv-server-1',
        tenantId: tenantB,
        type: 'sale',
        no: 'OTHER-9',
        partyId: 'c9',
        partyName: 'طرف آخر',
        date: DateTime(2026, 3, 1),
        subtotal: 777,
        total: 777,
        paid: 0,
        remaining: 777,
        status: 'unpaid',
        ownership: 'owned',
        requestId: null,
        synced: true,
        createdAt: null,
      ));
      await seedLegacyCacheMany(tenantA, [
        legacyHeader(), // collides with tenant B's row
        legacyHeader(id: 'inv-server-2', no: 'SALE-1002', total: 20000),
        legacyHeader(id: 'inv-server-3', no: 'SALE-1003', total: 30000),
      ], type: 'sale');

      await offlineRepo(tenantA).list(type: 'sale');

      final other = (await store.invoices(tenantB)).single;
      expect(other.no, 'OTHER-9',
          reason: 'the foreign row is never replaced');
      expect(other.total, 777);

      final mine = await store.invoices(tenantA);
      expect(
        mine.map((r) => r.no).toList()..sort(),
        ['SALE-1002', 'SALE-1003'],
        reason: 'the colliding id is skipped, and both siblings still land — '
            'the filter is per-row, not per-batch',
      );
    });

    test('D4c. reading a cache containing a collision still returns the list',
        () async {
      // The read must not throw. The colliding invoice is absent from the local
      // mirror, so resolving it fails later and honestly (C1/D5), but the list
      // itself is still served: a neighbouring uuid must not blank the screen.
      await seedChart(tenantA);
      await store.upsertInvoice(LocalInvoiceRow(
        id: 'inv-server-1',
        tenantId: tenantB,
        type: 'sale',
        no: 'OTHER-9',
        partyId: 'c9',
        partyName: 'طرف آخر',
        date: DateTime(2026, 3, 1),
        subtotal: 777,
        total: 777,
        paid: 0,
        remaining: 777,
        status: 'unpaid',
        ownership: 'owned',
        requestId: null,
        synced: true,
        createdAt: null,
      ));
      await seedLegacyCacheMany(tenantA, [
        legacyHeader(),
        legacyHeader(id: 'inv-server-2', no: 'SALE-1002', total: 20000),
      ], type: 'sale');

      final listed = await offlineRepo(tenantA).list(type: 'sale');

      expect(listed, hasLength(2),
          reason: 'the cache is served verbatim; hydration never filters the '
              'returned list');
      expect(listed.map((i) => i.no), containsAll(['SALE-1001', 'SALE-1002']));
    });
  });

  group('E. restart durability of the hydration', () {
    test('E1. a legacy cache hydrates after an app restart, and the payment then '
        'succeeds offline', () async {
      final dir = Directory.systemTemp.createTempSync('hasad_legacy_cache');
      addTearDown(() {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      });
      final file = File('${dir.path}/legacy.db');

      final db1 = AppDatabase(NativeDatabase(file));
      final store1 = DriftLocalStore(db1);
      await seedChartFor(store1, tenantA);
      await store1.putReport(
        tenantA,
        invoiceListKey(type: 'sale', search: null, from: null, to: null),
        jsonEncode([legacyHeader()]),
      );
      expect(await store1.invoices(tenantA), isEmpty,
          reason: 'precondition: the legacy cache was never mirrored');
      await db1.close();

      // The app restarts, still offline, on the upgraded build.
      final db2 = AppDatabase(NativeDatabase(file));
      final store2 = DriftLocalStore(db2);
      addTearDown(db2.close);
      final repo = OfflineInvoiceRepository(
        _UnreachableInvoices(),
        store: store2,
        tenantId: tenantA,
      );

      final listed = await repo.list(type: 'sale');
      expect(listed, hasLength(1));

      final rows = await store2.invoices(tenantA);
      expect(rows, hasLength(1),
          reason: 'an upgraded installation must self-heal its historical cache '
              'on the first invoice read');
      expect(rows.single.id, 'inv-server-1');

      final result = await OfflineWriteCoordinator(store2, tenantA).recordPayment(
        PaymentDraft(
          invoiceId: 'inv-server-1',
          amount: 4000,
          method: 'cash',
          date: DateTime(2026, 3, 2),
        ),
      );
      expect(result.paid, 4000);
      expect(result.pending, isTrue);
    });
  });
}

/// Chart/supplier seed that also takes a store, so the file-backed case can seed
/// through the first connection.
Future<void> seedChartFor(DriftLocalStore store, String tenant) async {
  for (final a in const [
    ('a1', '1010', 'نقدية', 'asset'),
    ('a2', '1015', 'بنك', 'asset'),
    ('a3', '1020', 'ذمم مدينة', 'asset'),
    ('a4', '1030', 'مخزون', 'asset'),
    ('a5', '2010', 'ذمم دائنة', 'liability'),
    ('a7', '4010', 'إيرادات مبيعات', 'revenue'),
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
    name: 'مورد',
    phone: null,
    notes: null,
    dealType: 'direct',
    commissionRate: null,
    createdAt: DateTime(2026, 1, 1),
    synced: true,
  ));
}

/// A server that is simply not there — every call throws [NetworkException], the
/// state an offline device is in. Deliberately carries no invoice data, so a case
/// cannot accidentally pass by reading the "network" instead of the cache.
class _UnreachableInvoices implements InvoiceRepository {
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

  /// The legacy-cache scenario has no reachable server, so the batch read fails
  /// the same way the single read does. That is the point: a legacy invoice must
  /// still be served from its cached payload with every line unanswered.
  @override
  Future<InvoiceItemsBatch> itemsForInvoices(List<String> invoiceIds) async =>
      throw const NetworkException();
}
