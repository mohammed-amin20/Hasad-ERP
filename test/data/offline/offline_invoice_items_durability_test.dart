/// Phase P1.E — **the invoice detail body is not durable, so an invoice the user
/// can see offline opens with no products and no quantities.**
///
/// ## The defect
///
/// `OfflineInvoiceRepository.items()` cache-lasts its response under
/// `invItems:<invoiceId>` and passes **no `mirror:` callback**, so nothing is
/// ever written to `local_invoice_items` for a server-created invoice. The table
/// has exactly two writers, both in `offline_write.dart` — the offline *create*
/// paths. A server invoice's only durable record of its lines is therefore the
/// JSON blob in `report_cache`, which is written as a `cacheLast` side effect:
///
/// ```
///   online, detail opened once  -> report_cache HAS the payload, lines render
///   offline, that cache entry   -> report_cache serves it,     lines render
///   offline, no cache entry     -> cacheLast rethrows,
///                                  _localItems finds nothing, lines EMPTY
/// ```
///
/// The header survives all three (P1.D hydrated it into `local_invoices`), so
/// the sheet shows a complete invoice and an empty body. `_mirrorHeaders`' own
/// comment records the scope decision that produced this: "Line items are NOT
/// mirrored".
///
/// ## Two further breaks found while tracing, both pinned here
///
/// **(a) An id-space mismatch, the same one P1.D fixed for the money path.**
/// `markReplaySynced` deliberately keeps the **local uuid** as
/// `local_invoices.id` (the sync badge joins the queue on `localId`) and records
/// local→server in `id_map`. The *list* then serves the **server** row for a
/// synced, unmarked invoice (`_withLocalMoney` keeps `server.id`), so the sheet
/// is opened with `invoice.id == serverUuid` while the lines live under
/// `invoiceId == localUuid`. `_localItems` finds nothing — on or off the
/// network.
///
/// **(b) A cached empty payload masks good local lines.** `cacheLast` calls
/// `putReport` unconditionally, including for `[]`. Open a *pending* invoice
/// while online (the server has never seen it, so it answers `[]`), then go
/// offline: `fromCached` returns `[]` and the `on NetworkException` branch is
/// never reached, so the rows `writeSale` durably wrote are never consulted.
///
/// ## The invariant these cases pin
///
/// If the app has loaded an invoice's detail at least once, those lines stay
/// available offline across a restart — for server invoices (by mirroring the
/// read) *and* for pending local drafts (already durable, and now reachable
/// through the right precedence). One sheet, one repository method, both types.
///
/// ## Why the durability assertions read the TABLE, not the store
///
/// `LocalStore.invoiceItems` is being re-signed to take a tenant id in this same
/// slice. If these cases called it, a wrong assertion could be satisfied by a
/// store filter rather than by a genuinely mirrored row, and the whole file
/// would not compile until the signature landed. They therefore read
/// `local_invoice_items` through drift directly, with the tenant and invoice
/// filters spelled out here, so what is asserted is "these rows are on disk for
/// this tenant" — independent of any store method.
library;

import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasad_erp/core/error/app_exception.dart';
import 'package:hasad_erp/data/invoices/invoice_repository.dart';
import 'package:hasad_erp/data/offline/local_database.dart';
import 'package:hasad_erp/data/offline/local_store.dart';
import 'package:hasad_erp/data/offline/offline_invoice_repository.dart';
import 'package:hasad_erp/domain/invoices/invoice.dart';
import 'package:hasad_erp/domain/products/product.dart';

void main() {
  const tenantA = 'tenant-a';
  const tenantB = 'tenant-b';

  late AppDatabase db;
  late DriftLocalStore store;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = DriftLocalStore(db);
  });

  tearDown(() => db.close());

  /// The durable truth, read straight from the table with both filters written
  /// out here. This is deliberately NOT `LocalStore.invoiceItems` — see the
  /// library header.
  Future<List<LocalInvoiceItemRow>> lines(
    String tenantId,
    String invoiceId,
  ) =>
      (db.select(db.localInvoiceItems)
            ..where((r) =>
                r.tenantId.equals(tenantId) & r.invoiceId.equals(invoiceId))
            ..orderBy([(r) => OrderingTerm.asc(r.id)]))
          .get();

  /// The exact production report-cache payload shape, copied from
  /// `OfflineInvoiceRepository.items()`'s `toPayload` — a test that seeds a
  /// different shape fails for the wrong reason, because `_itemFromJson`
  /// reads exactly these keys.
  Map<String, dynamic> cachedLine({
    String productId = 'p1',
    String? productName = 'سلعة',
    String? productUnit = 'قطعة',
    String? productUnitType = 'count',
    double qty = 2,
    int price = 50,
    int total = 100,
  }) =>
      {
        'product_id': productId,
        'product_name': productName,
        'product_unit': productUnit,
        'product_unit_type': productUnitType,
        'qty': qty,
        'price': price,
        'total': total,
      };

  /// Models a device that opened this invoice's detail while online, then went
  /// offline: the durable cache holds the payload and `local_invoice_items` does
  /// not. This is the shape a real upgraded device is in.
  Future<void> seedCacheOnly(
    String tenant,
    String invoiceId,
    List<Map<String, dynamic>> payload,
  ) =>
      store.putReport(tenant, 'invItems:$invoiceId', jsonEncode(payload));

  OfflineInvoiceRepository repo(
    String tenant, {
    List<InvoiceItem> serverItems = const [],
    bool reachable = false,
  }) =>
      OfflineInvoiceRepository(
        _FakeInvoices(serverItems: serverItems, reachable: reachable),
        store: store,
        tenantId: tenant,
      );

  InvoiceItem item({
    String productId = 'p1',
    String? productName = 'سلعة',
    String? productUnit = 'قطعة',
    ProductUnitType? productUnitType = ProductUnitType.count,
    double qty = 2,
    int price = 50,
    int total = 100,
  }) =>
      InvoiceItem(
        productId: productId,
        productName: productName,
        productUnit: productUnit,
        productUnitType: productUnitType,
        qty: qty,
        price: price,
        total: total,
      );

  /// A server-owned header, so `items()` takes the cacheLast path rather than
  /// the pending-draft path.
  Future<void> seedServerHeader(
    String tenant,
    String id, {
    String type = 'sale',
    String no = 'SALE-1001',
  }) =>
      store.upsertInvoice(LocalInvoiceRow(
        id: id,
        tenantId: tenant,
        type: type,
        no: no,
        partyId: 'c1',
        partyName: 'عميل',
        date: DateTime(2026, 3, 1),
        subtotal: 100,
        total: 100,
        paid: 0,
        remaining: 100,
        status: 'unpaid',
        ownership: 'owned',
        requestId: null,
        synced: true,
        createdAt: null,
      ));

  /// A pending local draft. `synced == false` is what makes its local lines the
  /// only truth — the server has never seen this invoice.
  Future<void> seedDraft(
    String tenant,
    String id, {
    String type = 'sale',
    String partyId = 'c1',
  }) =>
      store.upsertInvoice(LocalInvoiceRow(
        id: id,
        tenantId: tenant,
        type: type,
        no: 'D-$id',
        partyId: partyId,
        partyName: 'عميل',
        date: DateTime(2026, 3, 1),
        subtotal: 100,
        total: 100,
        paid: 0,
        remaining: 100,
        status: 'unpaid',
        ownership: 'owned',
        requestId: 'rq-$id',
        synced: false,
        createdAt: DateTime(2026, 3, 1),
      ));

  /// One durable line row, seeded the way `writeSale` does (so the `synced ==
  /// false` and cached-`[]` cases model a real offline create).
  Future<void> seedLine(
    String tenant,
    String invoiceId, {
    String id = 'line-0',
    String productId = 'p1',
    String? productName = 'سلعة محلية',
    String? productUnit = 'قطعة',
    String? productUnitType = 'count',
    double qty = 5,
    int price = 20,
    int total = 100,
  }) =>
      store.upsertInvoiceItems([
        LocalInvoiceItemRow(
          id: id,
          tenantId: tenant,
          invoiceId: invoiceId,
          productId: productId,
          productName: productName,
          productUnit: productUnit,
          productUnitType: productUnitType,
          qty: qty,
          price: price,
          total: total,
        ),
      ]);

  group('A. a successful detail read must become durable', () {
    test('A1. an online Sale read writes local_invoice_items, and the lines '
        'survive going offline', () async {
      await seedServerHeader(tenantA, 'inv-1');

      final read =
          await repo(tenantA, serverItems: [item()], reachable: true)
              .items('inv-1');
      expect(read, hasLength(1), reason: 'precondition: the online read works');

      expect(await lines(tenantA, 'inv-1'), hasLength(1),
          reason: 'a detail the user was shown must be durable; today the only '
              'durable record is the report_cache JSON blob, so nothing reaches '
              'the table the detail and write layers read');

      final offline = await repo(tenantA).items('inv-1');
      expect(offline, hasLength(1));
      expect(offline.single.productName, 'سلعة');
      expect(offline.single.qty, 2);
      expect(offline.single.productUnit, 'قطعة');
      expect(offline.single.total, 100);
    });

    test('A2. the same for a Purchase invoice — one sheet serves both types',
        () async {
      await seedServerHeader(tenantA, 'inv-p', type: 'purchase', no: 'PUR-1');

      await repo(tenantA,
              serverItems: [item(productName: 'مواد')], reachable: true)
          .items('inv-p');

      expect(await lines(tenantA, 'inv-p'), hasLength(1));
      final offline = await repo(tenantA).items('inv-p');
      expect(offline.single.productName, 'مواد');
    });

    test('A3. the mirror keeps null product fields null rather than inventing '
        'placeholders', () async {
      await seedServerHeader(tenantA, 'inv-1');

      await repo(tenantA, serverItems: [
        item(
          productName: null,
          productUnit: null,
          productUnitType: null,
          qty: 1.5,
          price: 7,
          total: 11,
        )
      ], reachable: true).items('inv-1');

      final row = (await lines(tenantA, 'inv-1')).single;
      expect(row.productName, isNull);
      expect(row.productUnit, isNull);
      expect(row.productUnitType, isNull);
      expect(row.qty, 1.5);
      expect(row.price, 7);
      expect(row.total, 11);
    });
  });

  group('B. a device holding only the legacy report cache self-heals', () {
    test('B1. a cache-only detail opens offline AND hydrates the table', () async {
      await seedServerHeader(tenantA, 'inv-1');
      await seedCacheOnly(tenantA, 'inv-1', [cachedLine(qty: 3, total: 150)]);
      expect(await lines(tenantA, 'inv-1'), isEmpty,
          reason: 'precondition: the cache was never mirrored');

      final items = await repo(tenantA).items('inv-1');
      expect(items, hasLength(1));
      expect(items.single.qty, 3);

      expect(await lines(tenantA, 'inv-1'), hasLength(1),
          reason: 'an upgraded device must self-heal from the cache it already '
              'holds, exactly as P1.D hydrates legacy headers — no Clear Data');

      // Durability, not cache-dependence: DELETE the cache row and the rows
      // must still serve the read on their own. This is what separates
      // "hydrated" from "served from the cache".
      //
      // The cache row is removed through drift rather than overwritten, and the
      // distinction is load-bearing. The mirror runs on the FINAL value, so a
      // cache entry of `[]` is a legitimate answer for a synced invoice (the
      // server says it has no lines) and mirroring it faithfully replaces the
      // set. Overwriting with `[]` would therefore be asserting that a
      // conflicting cache value is ignored — which is the opposite of the
      // contract, and would have "passed" only because the pre-fix code had no
      // mirror to disagree with.
      await (db.delete(db.reportCacheEntries)
            ..where((r) => r.tenantId.equals(tenantA) & r.key.equals('invItems:inv-1')))
          .go();
      expect(await store.report(tenantA, 'invItems:inv-1'), isNull,
          reason: 'precondition: the cache entry is gone');

      final afterCacheLoss = await repo(tenantA).items('inv-1');
      expect(afterCacheLoss.single.qty, 3,
          reason: 'the rows must serve the read on their own once written');
      expect(afterCacheLoss.single.productName, 'سلعة');
    });

    test('B2. a malformed cached payload fails the read honestly instead of '
        'rendering a partial line set', () async {
      await seedServerHeader(tenantA, 'inv-1');
      await seedCacheOnly(tenantA, 'inv-1', [
        cachedLine(),
        {'product_id': 'p2'},
      ]);

      await expectLater(
        repo(tenantA).items('inv-1'),
        throwsA(anything),
        reason: 'a truncated payload must not silently become a half-rendered '
            'invoice; an honest failure beats a partial lie',
      );
    });
  });

  group('C. durability across a real restart', () {
    test('C1. lines written online are still there after the process restarts '
        'offline', () async {
      final dir = Directory.systemTemp.createTempSync('hasad_items');
      addTearDown(() {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      });
      final file = File('${dir.path}/items.db');

      final db1 = AppDatabase(NativeDatabase(file));
      final store1 = DriftLocalStore(db1);
      await store1.upsertInvoice(LocalInvoiceRow(
        id: 'inv-1',
        tenantId: tenantA,
        type: 'sale',
        no: 'SALE-1001',
        partyId: 'c1',
        partyName: 'عميل',
        date: DateTime(2026, 3, 1),
        subtotal: 200,
        total: 200,
        paid: 0,
        remaining: 200,
        status: 'unpaid',
        ownership: 'owned',
        requestId: null,
        synced: true,
        createdAt: null,
      ));
      await OfflineInvoiceRepository(
        _FakeInvoices(
          serverItems: [item(qty: 4, total: 200)],
          reachable: true,
        ),
        store: store1,
        tenantId: tenantA,
      ).items('inv-1');
      expect(
        await (db1.select(db1.localInvoiceItems)
              ..where((r) => r.invoiceId.equals('inv-1')))
            .get(),
        hasLength(1),
      );
      await db1.close();

      // The app restarts, still offline, and opens the same invoice.
      final db2 = AppDatabase(NativeDatabase(file));
      addTearDown(db2.close);
      final items = await OfflineInvoiceRepository(
        _FakeInvoices(serverItems: const [], reachable: false),
        store: DriftLocalStore(db2),
        tenantId: tenantA,
      ).items('inv-1');

      expect(items, hasLength(1),
          reason: 'a detail loaded before the restart must survive it — '
              'NativeDatabase.memory() cannot prove this, hence the file');
      expect(items.single.qty, 4);
      expect(items.single.total, 200);
    });
  });

  group('D/E. pending local drafts keep their own lines', () {
    test('D. a pending draft serves its local lines', () async {
      await seedDraft(tenantA, 'D-1');
      await seedLine(tenantA, 'D-1');

      final items = await repo(tenantA).items('D-1');
      expect(items, hasLength(1));
      expect(items.single.productName, 'سلعة محلية');
      expect(items.single.qty, 5);
    });

    test('E. a pending Purchase draft resolves the same way', () async {
      await seedDraft(tenantA, 'D-2', type: 'purchase', partyId: 's1');
      await seedLine(
        tenantA,
        'D-2',
        productId: 'p9',
        productName: 'مواد أولية',
        productUnit: 'كيلو',
        productUnitType: 'weight',
        qty: 2.5,
        price: 24,
        total: 60,
      );

      final items = await repo(tenantA).items('D-2');
      expect(items, hasLength(1));
      expect(items.single.productUnitType, ProductUnitType.weight);
      expect(items.single.qty, 2.5);
      expect(items.single.total, 60);
    });

    test('E2. a draft with no lines yields an empty body rather than falling '
        'through to the network', () async {
      await seedDraft(tenantA, 'D-empty');
      await expectLater(repo(tenantA).items('D-empty'), completion(isEmpty));
    });
  });

  group('F. several lines keep their identity and their order', () {
    test('F1. twelve lines come back in order, and a refresh neither '
        'duplicates nor reorders them', () async {
      await seedServerHeader(tenantA, 'inv-many');
      final twelve = [
        for (var i = 0; i < 12; i++)
          item(
            productId: 'p$i',
            productName: 'منتج $i',
            qty: (i + 1).toDouble(),
            total: (i + 1) * 10,
          ),
      ];

      await repo(tenantA, serverItems: twelve, reachable: true).items('inv-many');

      final offline = repo(tenantA);
      final first = await offline.items('inv-many');
      expect(first, hasLength(12));
      expect(
        first.map((i) => i.productName).toList(),
        [for (var i = 0; i < 12; i++) 'منتج $i'],
        reason: 'the sheet iterates the list in order, so the mirror must '
            'preserve the server sequence — and 12 lines is past the point '
            'where an unpadded ordinal sorts 10 before 2',
      );

      // An identical second refresh must not append.
      await repo(tenantA, serverItems: twelve, reachable: true).items('inv-many');
      expect(await lines(tenantA, 'inv-many'), hasLength(12));
      final again = await offline.items('inv-many');
      expect(
        again.map((i) => i.productName).toList(),
        first.map((i) => i.productName).toList(),
      );
    });

    test('F2. a refresh to FEWER lines drops the stale ones', () async {
      await seedServerHeader(tenantA, 'inv-shrink');
      await repo(tenantA, serverItems: [
        item(productName: 'أ'),
        item(productName: 'ب'),
        item(productName: 'ج'),
      ], reachable: true).items('inv-shrink');
      expect(await lines(tenantA, 'inv-shrink'), hasLength(3));

      await repo(tenantA, serverItems: [item(productName: 'أ')],
          reachable: true).items('inv-shrink');

      final rows = await lines(tenantA, 'inv-shrink');
      expect(rows, hasLength(1),
          reason: 'a positional id scheme leaves an orphan row past the new '
              'length unless the mirror replaces the set wholesale');
      expect(rows.single.productName, 'أ');
    });

    test('F3. the same product twice on one invoice stays two lines', () async {
      await seedServerHeader(tenantA, 'inv-repeat');
      await repo(tenantA, serverItems: [
        item(productId: 'p1', productName: 'سلعة', qty: 1, total: 100),
        item(productId: 'p1', productName: 'سلعة', qty: 3, total: 300),
      ], reachable: true).items('inv-repeat');

      final rows = await lines(tenantA, 'inv-repeat');
      expect(rows, hasLength(2),
          reason: 'a product-keyed line id would collapse these into one row; '
              'an invoice may legitimately carry the same product twice');
      expect(rows.map((r) => r.qty), [1, 3]);
    });
  });

  group('G. tenant isolation', () {
    test('G1. one workspace never receives another workspace\'s mirrored lines',
        () async {
      await seedServerHeader(tenantA, 'inv-1');
      await repo(tenantA, serverItems: [item(productName: 'سرية')],
          reachable: true).items('inv-1');
      expect(await lines(tenantA, 'inv-1'), hasLength(1));

      final forB = await repo(tenantB).items('inv-1');
      expect(forB, isEmpty,
          reason: 'the local read must be scoped by tenant, not by invoice id '
              'alone — with one id, the other workspace\'s rows are all it '
              'could find');
    });

    test('G2. mirroring the same invoice id in another workspace replaces '
        'nothing', () async {
      await seedServerHeader(tenantA, 'inv-1');
      await repo(tenantA, serverItems: [item(productName: 'أصلي')],
          reachable: true).items('inv-1');

      await seedServerHeader(tenantB, 'inv-1');
      await repo(tenantB, serverItems: [item(productName: 'مستبدل')],
          reachable: true).items('inv-1');

      final a = await lines(tenantA, 'inv-1');
      final b = await lines(tenantB, 'inv-1');
      expect(a, hasLength(1),
          reason: 'the other workspace\'s mirror must not replace this one — '
              'a primary key that is not tenant-qualified makes this a silent '
              'clobber, and "no duplicate row" would NOT catch it');
      expect(a.single.productName, 'أصلي');
      expect(b.single.productName, 'مستبدل');
    });
  });

  group('H. mapped identity', () {
    test('H1. after a replay the server id resolves the local lines, and a '
        'refresh does not create a second set', () async {
      // The state `markReplaySynced` leaves behind: `local_invoices.id` is STILL
      // the local uuid (the sync badge joins the queue on the leg's localId),
      // and `id_map` records local to server.
      await seedDraft(tenantA, 'D-1');
      await seedLine(tenantA, 'D-1', id: 'D-1:0000', qty: 2, total: 100);
      await store.upsertInvoice(
        (await store.invoices(tenantA)).single.copyWith(synced: true),
      );
      await store.putMapping(
        tenantId: tenantA,
        entity: 'invoices',
        localId: 'D-1',
        serverId: 'srv-1',
      );

      // The list serves the SERVER id, so that is the id the sheet is given.
      final items = await repo(tenantA).items('srv-1');
      expect(items, hasLength(1),
          reason: 'the lines are stored under the local uuid, so the read must '
              'resolve the mapping first — the same lookup `_invoice` does for '
              'money, and the same defect P1.D fixed for headers');
      expect(items.single.productName, 'سلعة محلية');

      // A later server refresh must land on those same rows.
      await repo(tenantA, serverItems: [item(qty: 7, total: 350)],
          reachable: true).items('srv-1');
      final rows = await lines(tenantA, 'D-1');
      expect(rows, hasLength(1), reason: 'no duplicate set under the server id');
      expect(rows.single.qty, 7);
      expect(rows.single.total, 350);
      expect(await lines(tenantA, 'srv-1'), isEmpty);
    });
  });

  group('I. reconnect', () {
    test('I1. a repeated server refresh leaves the lines intact', () async {
      await seedServerHeader(tenantA, 'inv-1');
      await repo(tenantA, serverItems: [item()], reachable: true).items('inv-1');
      await repo(tenantA, serverItems: [item()], reachable: true).items('inv-1');

      final rows = await lines(tenantA, 'inv-1');
      expect(rows, hasLength(1));
      expect(rows.single.qty, 2);
      expect(rows.single.total, 100);
    });

    test('I2. a draft drained to synced hands its lines to the server copy',
        () async {
      await seedDraft(tenantA, 'D-1');
      await seedLine(tenantA, 'D-1', id: 'D-1:0000', qty: 2, total: 100);
      await store.upsertInvoice(
        (await store.invoices(tenantA)).single.copyWith(synced: true),
      );
      await store.putMapping(
        tenantId: tenantA,
        entity: 'invoices',
        localId: 'D-1',
        serverId: 'srv-1',
      );

      // Online again, so the server's copy of the same invoice is authoritative.
      await repo(tenantA, serverItems: [item(qty: 9, total: 900)],
          reachable: true).items('srv-1');

      final rows = await lines(tenantA, 'D-1');
      expect(rows, hasLength(1));
      expect(rows.single.qty, 9,
          reason: 'once synced, the server owns the lines; the read must not '
              'stay pinned to the draft copy it wrote offline');
    });
  });

  group('J. a cached empty payload must not mask local lines', () {
    test('J1. a pending draft whose items were cached as [] offline still '
        'shows its own lines', () async {
      await seedDraft(tenantA, 'D-1');
      await seedLine(tenantA, 'D-1');
      // Opened once while online: the server has never seen the draft, answers
      // [], and cacheLast writes that empty payload unconditionally.
      await seedCacheOnly(tenantA, 'D-1', const []);

      final items = await repo(tenantA).items('D-1');
      expect(items, hasLength(1),
          reason: 'an unsynced draft has exactly one source of truth, so the '
              'cacheLast path must be skipped for it entirely');
      expect(items.single.productName, 'سلعة محلية');
    });

    test('J2. the durable copy wins even when the cache holds a stale '
        'NON-empty payload for the same draft', () async {
      await seedDraft(tenantA, 'D-1');
      await seedLine(tenantA, 'D-1', productName: 'النسخة المحلية', qty: 5);
      await seedCacheOnly(tenantA, 'D-1', [
        cachedLine(productName: 'نسخة قديمة', qty: 1, total: 100),
      ]);

      final items = await repo(tenantA).items('D-1');
      expect(items.single.productName, 'النسخة المحلية',
          reason: 'the server never had this invoice, so any cached payload '
              'under its id is stale by construction');
    });
  });

  group('L. legacy rows written before any positional id scheme', () {
    test('L1. bare-uuid line rows are still returned in full, in id order',
        () async {
      await seedDraft(tenantA, 'D-1');
      await store.upsertInvoiceItems([
        for (final n in ['zzz-uuid', 'aaa-uuid', 'mmm-uuid'])
          LocalInvoiceItemRow(
            id: n,
            tenantId: tenantA,
            invoiceId: 'D-1',
            productId: 'p-$n',
            productName: 'سلعة',
            productUnit: 'قطعة',
            productUnitType: 'count',
            qty: 1,
            price: 10,
            total: 10,
          ),
      ]);

      final items = await repo(tenantA).items('D-1');
      expect(items, hasLength(3),
          reason: 'the id scheme is an internal detail, so every row must come '
              'back; their ORIGINAL order is not recoverable from a bare uuid, '
              'which is documented rather than pretended');
      expect(
        items.map((i) => i.productId).toList(),
        ['p-aaa-uuid', 'p-mmm-uuid', 'p-zzz-uuid'],
      );
    });
  });
}

/// The online/offline half of the contract. `reachable: false` throws
/// [NetworkException] from every call, which is the state an offline device is
/// in; no case may pass by reading "the network" instead of the cache.
class _FakeInvoices implements InvoiceRepository {
  _FakeInvoices({required this.serverItems, required this.reachable});

  /// Named `serverItems`, not `items`: `InvoiceRepository` already declares an
  /// `items(String)` member, so a field of that name cannot be declared at all.
  final List<InvoiceItem> serverItems;
  final bool reachable;

  @override
  Future<List<Invoice>> list({
    required String type,
    String? search,
    DateTime? from,
    DateTime? to,
  }) async {
    if (!reachable) throw const NetworkException();
    return const [];
  }

  @override
  Future<List<InvoiceItem>> items(String invoiceId) async {
    if (!reachable) throw const NetworkException();
    return serverItems;
  }

  /// `serverItems` is a FLAT list with no per-invoice attribution — this fake
  /// existed to prove one invoice's durability, so fanning the same lines out
  /// across every requested id would invent an id-to-lines mapping the test
  /// never declared. `list()` returns `[]` here, so no prefetch ever asks;
  /// the empty answer keeps the member honest instead of guessing.
  @override
  Future<InvoiceItemsBatch> itemsForInvoices(List<String> invoiceIds) async {
    if (!reachable) throw const NetworkException();
    return InvoiceItemsBatch(
      items: {for (final id in invoiceIds) id: const <InvoiceItem>[]},
      failed: const {},
    );
  }
}
