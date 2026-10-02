/// **A listed invoice must have its line detail durable WITHOUT the user ever
/// opening the detail.**
///
/// ## The defect this closed
///
/// `OfflineInvoiceRepository.list()` hydrated **headers only**
/// (`_mirrorHeaders` -> `DriftLocalStore.mirrorInvoices`), and the P1.C header
/// mirror is deliberately header-only: it writes no `local_invoice_items` rows.
/// Line rows reach that table through exactly one route — `_mirrorItems` — which
/// was reachable only from `items(invoiceId)`.
///
/// So an invoice the user had only ever SEEN IN A LIST had a `local_invoices`
/// row and zero `local_invoice_items`. Open its detail offline and `items()`
/// found no `invItems:<id>` cache entry, `cacheLast` rethrew, `_localItems`
/// returned `[]`, and the sheet rendered a complete invoice with an empty body.
///
/// ## What these cases pin
///
/// A list that loads successfully online leaves every invoice it returned with a
/// durable line set, WITHOUT the detail ever having been opened — and does it
/// with a bounded **batch** read, never one `items()` round trip per invoice.
///
/// ## Why the batch assertions record the EXACT id list
///
/// Counting detail calls is not enough: an implementation that loops
/// `itemsForInvoices([id])` makes N calls, none of them over the 100-id bound, and
/// would pass a count-based assertion. `probe.batchCalls` therefore records the
/// id set of every call, so A3 can demand ONE call carrying the whole page.
///
/// `probe.singleInvoiceCalls` is still recorded, for the different job of proving
/// A1/A2 genuinely never opened a detail.
///
/// ## Deliberately not pinned here
///
/// True server line ORDER. `invoice_items.id` is `gen_random_uuid()` with no
/// ordinal column and the production `items()` query carries no `.order()`, so
/// original server line order is unrecoverable — the limitation P1.E already
/// documented. Mirror-row ordering is pinned by
/// `offline_invoice_items_durability_test.dart`.
library;

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
  const tenant = 'tenant-a';

  group('A1/A2. a listed invoice is durable WITHOUT its detail ever being opened', () {
    test(
      'A1 (Sale): online list -> offline restart -> items() has the lines',
      () async {
        final h = await _Harness.boot(tenant);

        // The user is ONLINE and opens the sales list. No detail is opened, so
        // `items()` is never called by the app for these invoices.
        final listed = await h.repo().list(type: 'sale');
        expect(
          listed.map((i) => i.id),
          ['srv-sale-1', 'srv-sale-2', 'srv-sale-3'],
          reason:
              'the list itself must succeed — this is the pre-condition the '
              'failure needs, not part of the defect',
        );

        expect(
          h.probe.singleInvoiceCalls,
          isEmpty,
          reason:
              'the device symptom is precisely that the detail was never '
              'opened, so no single-invoice item read happened',
        );

        // Restart: close the connection completely and reopen the same file.
        await h.restart(offline: true);

        final items = await h.repo().items('srv-sale-1');

        expect(
          items,
          hasLength(1),
          reason:
              'an invoice the user could SEE in a list must show its '
              'products offline; today local_invoice_items was never written '
              'for it because only items() writes that table',
        );
        expect(items.single.productName, 'ورقية A4');
        expect(items.single.qty, 3);
        expect(items.single.productUnit, 'كرتونة');
        expect(items.single.total, 750);
      },
    );

    test('A2 (Purchase): the same sequence for a purchase invoice', () async {
      final h = await _Harness.boot(tenant);

      final listed = await h.repo().list(type: 'purchase');
      expect(listed.map((i) => i.id), ['srv-pur-1']);

      expect(h.probe.singleInvoiceCalls, isEmpty);

      await h.restart(offline: true);

      final items = await h.repo().items('srv-pur-1');

      expect(
        items,
        hasLength(1),
        reason:
            'Purchase shares list()/items() with Sale, so it must be '
            'covered independently — a Sale-only fix would still ship the '
            'same empty body on purchases',
      );
      expect(items.single.productName, 'حبر طابعة B2');
      expect(items.single.qty, 2);
      expect(items.single.productUnit, 'قلم');
      expect(items.single.total, 400);
    });
  });

  group('A3. one list hydrates MANY detail sets without an N+1', () {
    test('A3: three listed invoices each get their own durable detail set, and '
        'no per-invoice items() call is made', () async {
      final h = await _Harness.boot(tenant);

      final listed = await h.repo().list(type: 'sale');
      expect(
        listed,
        hasLength(3),
        reason: 'the list really did return three invoices',
      );

      expect(
        h.probe.singleInvoiceCalls,
        isEmpty,
        reason:
            'hydrating N invoices must NOT be N items() calls — that is '
            'the N+1 this design is required to avoid',
      );

      // The call COUNT alone would pass for an implementation that loops
      // `itemsForInvoices([id])` three times — three batch calls, none of them
      // over the 100-id bound. The requirement is ONE logical read for the page,
      // so the exact id set of each call is what is asserted.
      expect(
        h.probe.batchCalls,
        [
          ['srv-sale-1', 'srv-sale-2', 'srv-sale-3'],
        ],
        reason:
            'one logical batch call carrying every invoice the page listed — '
            'not one call per invoice, and not a call per 100 ids either '
            '(chunking is the transport layer\'s business, inside the '
            'repository, not the caller\'s)',
      );

      await h.restart(offline: true);
      final repo = h.repo();

      final first = await repo.items('srv-sale-1');
      final second = await repo.items('srv-sale-2');
      final third = await repo.items('srv-sale-3');

      expect(first.map((i) => i.productName), ['ورقية A4']);
      expect(
        second.map((i) => i.productName),
        ['حبر B2', 'حبر B2-بلوك'],
        reason:
            'each invoice keeps its OWN lines; a shared/batched write '
            'that leaked one invoice rows into another fails here',
      );
      expect(third.map((i) => i.productName), ['ورق A3']);

      expect(await h.rows(tenant, 'srv-sale-1'), hasLength(1));
      expect(await h.rows(tenant, 'srv-sale-2'), hasLength(2));
      expect(
        await h.rows(tenant, 'srv-sale-3'),
        hasLength(1),
        reason:
            'three distinct invoice ids in the mirror, each with its own '
            'line count — nothing was dropped or merged',
      );
    });
  });

  group('A7. the durable check must resolve the mapped id, or lines are refetched '
      'forever', () {
    test('A7: a replayed invoice listed under its SERVER id is NOT re-requested '
        'when its lines are already durable under its LOCAL id', () async {
      final h = await _Harness.boot(tenant);

      // The state P1.C creates and P1.1 documents: `markReplaySynced` keeps the
      // LOCAL uuid as `local_invoices.id` and records local -> server in id_map,
      // while the list serves the SERVER id. So the rows live under `loc-sale-1`
      // and the list will ask about `srv-sale-1`.
      await h.seedMappedInvoice(
        tenant,
        localId: 'loc-sale-1',
        serverId: 'srv-sale-1',
      );

      final listed = await h.repo().list(type: 'sale');
      expect(listed.map((i) => i.id), [
        'srv-sale-1',
        'srv-sale-2',
        'srv-sale-3',
      ]);

      expect(
        h.probe.batchCalls,
        [
          ['srv-sale-2', 'srv-sale-3'],
        ],
        reason:
            'srv-sale-1 already HAS durable lines (under its local id), so '
            'asking for it again buys nothing and costs a request on every '
            'list refresh forever. Comparing the raw server id against '
            'invoice_id would match no row, which is indistinguishable from '
            '"never fetched" — this assertion is the only thing that '
            'distinguishes the two',
      );

      // And the answer, when it does arrive, must not create a SECOND set of
      // lines beside the mapped one.
      expect(
        await h.rows(tenant, 'srv-sale-1'),
        isEmpty,
        reason:
            'a mirrored answer for the server id would sit beside the local '
            'set as duplicate lines — the same id-space split this file has '
            'already been bitten by twice',
      );
      expect(await h.rows(tenant, 'loc-sale-1'), hasLength(1));
    });

    test(
      'A7b: a second list refresh requests only what is still missing',
      () async {
        final h = await _Harness.boot(tenant);

        // First online list hydrates the whole page.
        await h.repo().list(type: 'sale');
        expect(h.probe.batchCalls, [
          ['srv-sale-1', 'srv-sale-2', 'srv-sale-3'],
        ]);

        h.probe.batchCalls.clear();

        // Every line set is durable now, so a refresh must cost ZERO requests.
        // This is the case the prefetch exists for: an offline-capable device
        // refreshing its list must not issue a detail read per invoice per
        // refresh, and must not fail when it is offline.
        h.probe.goOffline();
        final refreshed = await h.repo().list(type: 'sale');
        expect(refreshed.map((i) => i.id), [
          'srv-sale-1',
          'srv-sale-2',
          'srv-sale-3',
        ]);

        expect(
          h.probe.batchCalls,
          isEmpty,
          reason:
              'durable lines were already mirrored by the first list; a '
              'refresh must issue no detail request at all',
        );
        expect(await h.rows(tenant, 'srv-sale-2'), hasLength(2));
      },
    );
  });

  group('A6. the 100-id transport bound is proven at the boundary', () {
    test('A6: 205 invoice ids become exactly three requests of 100/100/5, and '
        'no request ever exceeds 100', () async {
      final ids = [for (var i = 1; i <= 205; i++) 'inv-$i'];

      // The same helper the production `itemsForInvoices` chunks with, on the
      // same production bound. Testing a parallel copy of the chunking rule
      // would prove nothing about the code that runs.
      expect(
        kInvoiceItemsBatchSize,
        100,
        reason: 'the bound is a PostgREST `in` limit, not a tuning knob',
      );

      final chunks = chunkInvoiceIds(ids);
      expect(chunks.map((c) => c.length), [100, 100, 5]);
      expect(
        [for (final c in chunks) ...c],
        ids,
        reason: 'every id asked for, in order, exactly once',
      );
      expect(
        chunks.every((c) => c.length <= 100),
        isTrue,
        reason: 'no single request may exceed the bound',
      );

      // 200 is the exact-multiple edge: 100 ids must NOT be padded into a
      // second request, which is the shape a `for (i += 100)` loop gets wrong
      // when it reads `i < ids.length - 100`.
      expect(
        chunkInvoiceIds([for (var i = 1; i <= 200; i++) 'inv-$i'])
            .map((c) => c.length),
        [100, 100],
      );
      expect(
        chunkInvoiceIds(const <String>[]),
        isEmpty,
        reason: 'no candidates means no request at all',
      );
    });
  });

  group('A4. a prefetch failure must not break the list or erase lines', () {
    test('A4: list() still succeeds and previously durable lines survive', () async {
      final h = await _Harness.boot(tenant);

      // The list above already mirrors every invoice's lines, so the detail is
      // opened explicitly to give srv-sale-2 a durable set the FAILING read
      // below must leave intact.
      await h.repo().list(type: 'sale');
      expect(
        await h.rows(tenant, 'srv-sale-2'),
        hasLength(2),
        reason: 'pre-condition: srv-sale-2 has durable lines to protect',
      );

      // Now the device-side detail read fails mid-list (dropped connection,
      // bad response). The header list must still be a success.
      h.probe.failDetailReads();
      final listed = await h.repo().list(type: 'sale');

      expect(
        listed.map((i) => i.id),
        ['srv-sale-1', 'srv-sale-2', 'srv-sale-3'],
        reason:
            'an optional item prefetch must never make a header list '
            'fail — the user would lose the entire invoice list',
      );

      final survivors = await h.rows(tenant, 'srv-sale-2');
      expect(
        survivors,
        hasLength(2),
        reason:
            'a failed detail read must not delete durable lines; '
            'mirrorInvoiceItems is replace-all, so a failure must mean '
            '"do not call it", never "call it with an empty list"',
      );
      expect(survivors.map((r) => r.productName), ['حبر B2', 'حبر B2-بلوك']);
    });
  });

  group('A5. a genuinely empty invoice is NOT the same as a failed read', () {
    test('A5: a successful empty answer may mirror empty, while a failed read '
        'must leave the previous rows alone', () async {
      final h = await _Harness.boot(tenant);

      // --- a genuinely empty detail: the server answered with zero rows ------
      final empty = await h.repo().items('srv-empty-1');
      expect(empty, isEmpty);
      expect(
        await h.rows(tenant, 'srv-empty-1'),
        isEmpty,
        reason:
            'a successful empty answer IS authoritative — the server said '
            'this invoice has no lines, so the mirror must follow it',
      );

      // --- an invoice whose lines are durable, then the read FAILS ----------
      await h.repo().items('srv-sale-2');
      expect(await h.rows(tenant, 'srv-sale-2'), hasLength(2));

      // The cache row the successful read above wrote would make this a
      // cache-hit case, not a failure case. P1.E recorded the same trap: to
      // exercise the offline branch, the cache row must be GONE, never seeded
      // with a conflicting `[]`.
      await h.deleteReportCache('invItems:srv-sale-2');
      expect(
        await h.store.report(tenant, 'invItems:srv-sale-2'),
        isNull,
        reason:
            'pre-condition: the cache entry is what `cacheLast` would '
            'fall back to, so it must not be masking the failure',
      );

      h.probe.failDetailReads();
      final afterFailure = await h.repo().items('srv-sale-2');
      expect(
        afterFailure.map((i) => i.productName),
        ['حبر B2', 'حبر B2-بلوك'],
        reason:
            'with no cache and no network the only honest answer is the '
            'mirrored lines — the failure must degrade to local, not to []',
      );
      expect(
        await h.rows(tenant, 'srv-sale-2'),
        hasLength(2),
        reason:
            'these two cases must never collapse: success-with-no-rows is '
            'DATA, failure is the ABSENCE of data, and only the second may '
            'preserve the previous rows',
      );
    });
  });
}

/// One database FILE, opened and closed like a real process run, so these
/// assertions prove cross-process survival rather than in-memory behaviour.
class _Harness {
  _Harness._(this.dir, this.file, this.tenant, this.probe);

  final Directory dir;
  final File file;
  final String tenant;
  final _BatchProbe probe;
  late AppDatabase db;
  late DriftLocalStore store;

  static Future<_Harness> boot(String tenant) async {
    final dir = Directory.systemTemp.createTempSync('hasad_batch_prefetch');
    final h = _Harness._(
      dir,
      File('${dir.path}/hasad_offline.sqlite'),
      tenant,
      _BatchProbe.online(),
    );
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    h._open();
    addTearDown(() => h.db.close());
    return h;
  }

  void _open() {
    db = AppDatabase(NativeDatabase(file));
    store = DriftLocalStore(db);
  }

  /// Closes the connection completely and opens a NEW one over the same file.
  Future<void> restart({required bool offline}) async {
    await db.close();
    _open();
    if (offline) {
      probe.goOffline();
    }
  }

  /// Always built over [probe], the SAME instance for the whole case, so
  /// `probe.singleInvoiceCalls` records what this repository actually called.
  OfflineInvoiceRepository repo() =>
      OfflineInvoiceRepository(probe, store: store, tenantId: tenant);

  /// Removes the report-cache row `items()` writes on a successful read, so the
  /// next call genuinely takes the offline branch instead of a cache hit.
  Future<void> deleteReportCache(String key) => (db.delete(
    db.reportCacheEntries,
  )..where((r) => r.tenantId.equals(tenant) & r.key.equals(key))).go();

  /// Seeds the state a synced replay leaves behind: a SYNCED header under the
  /// LOCAL uuid, lines mirrored under that same local id, and a local -> server
  /// mapping. The list will then serve the server id while every row is keyed by
  /// the local one — the exact id-space split the prefetch has to bridge in BOTH
  /// directions.
  ///
  /// The header is written `synced: true` on purpose: `mirrorInvoiceItems`
  /// refuses to sweep an unsynced header, so an unsynced draft could not hold
  /// durable lines at all and would prove nothing here.
  Future<void> seedMappedInvoice(
    String tenantId, {
    required String localId,
    required String serverId,
  }) async {
    await store.upsertInvoice(
      LocalInvoiceRow(
        id: localId,
        tenantId: tenantId,
        type: 'sale',
        no: 'SALE-2001',
        partyId: 'c1',
        partyName: 'عميل',
        date: DateTime(2026, 3, 3),
        subtotal: 750,
        total: 750,
        paid: 0,
        remaining: 750,
        status: 'unpaid',
        ownership: 'owned',
        synced: true,
      ),
    );
    await store.putMapping(
      tenantId: tenantId,
      entity: 'invoices',
      localId: localId,
      serverId: serverId,
    );
    await store.mirrorInvoiceItems(tenantId, localId, [
      LocalInvoiceItemRow(
        id: '',
        tenantId: tenantId,
        invoiceId: localId,
        productId: 'prod-a4',
        productName: 'ورقية A4',
        qty: 3,
        price: 250,
        total: 750,
      ),
    ]);
  }

  /// Reads durable lines straight off disk, so an assertion cannot be satisfied
  /// by a store filter rather than by a genuinely mirrored row.
  Future<List<LocalInvoiceItemRow>> rows(String tenantId, String invoiceId) =>
      (db.select(db.localInvoiceItems)
            ..where(
              (r) =>
                  r.tenantId.equals(tenantId) & r.invoiceId.equals(invoiceId),
            )
            ..orderBy([(r) => OrderingTerm.asc(r.id)]))
          .get();
}

/// The fake server.
///
/// `singleInvoiceCalls` records every single-invoice detail read. It is the
/// assertion that makes an N+1 implementation fail rather than pass, and it is
/// also how A1/A2 prove the detail was genuinely never opened.
class _BatchProbe implements InvoiceRepository {
  _BatchProbe.online() {
    reachable = true;
    detailReadFails = false;
    linesByInvoice = _lines;
  }

  /// The same instance is kept for the whole case and re-pointed, because
  /// `singleInvoiceCalls` is only meaningful on the probe the repository
  /// actually called. A per-call fresh probe would make every N+1 assertion
  /// pass vacuously.
  void goOnline() {
    reachable = true;
    detailReadFails = false;
    linesByInvoice = _lines;
  }

  void goOffline() {
    reachable = false;
  }

  /// Reachable, but the device-side detail read fails: a dropped connection or
  /// a bad response. The header list is unaffected.
  void failDetailReads() {
    reachable = true;
    detailReadFails = true;
    linesByInvoice = _lines;
  }

  bool reachable = true;
  bool detailReadFails = false;
  Map<String, List<InvoiceItem>> linesByInvoice = const {};

  /// `srv-empty-1` is only ever opened directly by A5, never through a list, so
  /// the list assertions are not polluted by a fourth, line-less header.
  bool get _listIncludesEmptyInvoice => false;

  /// Every single-invoice detail read, in order.
  final List<String> singleInvoiceCalls = <String>[];

  /// Every batch read, recorded as the EXACT id list it was asked for. Counting
  /// the calls alone would let an N+1-shaped implementation that loops over
  /// `itemsForInvoices([id])` pass (three calls, none over 100), so the id set of
  /// each call is the assertion — A3 wants ONE call carrying the whole page.
  final List<List<String>> batchCalls = <List<String>>[];

  @override
  Future<List<Invoice>> list({
    required String type,
    String? search,
    DateTime? from,
    DateTime? to,
  }) async {
    if (!reachable) throw const NetworkException();
    return [
      for (final i in _headers)
        if (i.type == type &&
            (i.id != 'srv-empty-1' || _listIncludesEmptyInvoice))
          i,
    ];
  }

  @override
  Future<List<InvoiceItem>> items(String invoiceId) async {
    singleInvoiceCalls.add(invoiceId);
    if (!reachable || detailReadFails) throw const NetworkException();
    return linesByInvoice[invoiceId] ?? const [];
  }

  @override
  Future<InvoiceItemsBatch> itemsForInvoices(List<String> invoiceIds) async {
    batchCalls.add(List<String>.of(invoiceIds));
    if (!reachable) throw const NetworkException();
    final items = <String, List<InvoiceItem>>{};
    final failed = <String>{};
    for (final id in invoiceIds) {
      if (detailReadFails) {
        failed.add(id);
        continue;
      }
      final list = linesByInvoice[id];
      if (list != null) {
        items[id] = List<InvoiceItem>.from(list);
      } else {
        items[id] = const <InvoiceItem>[];
      }
    }
    return InvoiceItemsBatch(items: items, failed: failed);
  }

  static InvoiceItem _line(
    String productId,
    String name,
    String unit,
    double qty,
    int price,
  ) => InvoiceItem(
    productId: productId,
    productName: name,
    productUnit: unit,
    productUnitType: ProductUnitType.count,
    qty: qty,
    price: price,
    total: (qty * price).round(),
  );

  static final Map<String, List<InvoiceItem>> _lines = {
    'srv-sale-1': [_line('prod-a4', 'ورقية A4', 'كرتونة', 3, 250)],
    'srv-sale-2': [
      _line('prod-b2', 'حبر B2', 'قلم', 2, 200),
      _line('prod-b2', 'حبر B2-بلوك', 'قلم', 1, 150),
    ],
    'srv-sale-3': [_line('prod-a3', 'ورق A3', 'كرتونة', 1, 900)],
    'srv-pur-1': [_line('prod-ink', 'حبر طابعة B2', 'قلم', 2, 200)],
  };

  static final List<Invoice> _headers = [
    Invoice(
      id: 'srv-sale-1',
      type: 'sale',
      no: 'SALE-2001',
      partyId: 'c1',
      partyName: 'عميل',
      date: DateTime(2026, 3, 3),
      subtotal: 750,
      total: 750,
      paid: 0,
      remaining: 750,
      status: InvoiceStatus.unpaid,
      ownership: InvoiceOwnership.owned,
    ),
    Invoice(
      id: 'srv-sale-2',
      type: 'sale',
      no: 'SALE-2002',
      partyId: 'c1',
      partyName: 'عميل',
      date: DateTime(2026, 3, 2),
      subtotal: 400,
      total: 400,
      paid: 0,
      remaining: 400,
      status: InvoiceStatus.unpaid,
      ownership: InvoiceOwnership.owned,
    ),
    Invoice(
      id: 'srv-sale-3',
      type: 'sale',
      no: 'SALE-2003',
      partyId: 'c1',
      partyName: 'عميل',
      date: DateTime(2026, 3, 1),
      subtotal: 900,
      total: 900,
      paid: 0,
      remaining: 900,
      status: InvoiceStatus.unpaid,
      ownership: InvoiceOwnership.owned,
    ),
    Invoice(
      id: 'srv-empty-1',
      type: 'sale',
      no: 'SALE-2004',
      partyId: 'c1',
      partyName: 'عميل',
      date: DateTime(2026, 2, 28),
      subtotal: 0,
      total: 0,
      paid: 0,
      remaining: 0,
      status: InvoiceStatus.unpaid,
      ownership: InvoiceOwnership.owned,
    ),
    Invoice(
      id: 'srv-pur-1',
      type: 'purchase',
      no: 'PUR-2001',
      partyId: 's1',
      partyName: 'مورد',
      date: DateTime(2026, 3, 4),
      subtotal: 400,
      total: 400,
      paid: 0,
      remaining: 400,
      status: InvoiceStatus.unpaid,
      ownership: InvoiceOwnership.owned,
    ),
  ];
}
