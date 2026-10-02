/// **B4 — what the LOCAL CATALOG can answer with no network, and what it must
/// refuse to invent.** (The data half of FAILURE B; the widget half lives in
/// `test/widget/product_picker_offline_search_test.dart`.)
///
/// This file needs a real `DriftLocalStore` over a real sqlite FILE. B1's
/// widget test proves the picker's search box is inert; it cannot answer what
/// the local mirror actually contains after a cold start, because its fake
/// repository answers whatever it is told to.
///
/// ## What is asserted
///
///  * **B4.1 / B4.2 — a mirrored `local_products` row IS searchable offline**,
///    by name and by barcode, and survives a process restart. This is the
///    honest half of the answer: for any product the device has seen, offline
///    selection is genuinely available, so "no products offline" is never the
///    correct diagnosis.
///
///  * **B4.3 — an `InvoiceItem`-only reference is NOT a selectable product.**
///    A line mirrored from a server invoice names a product that this device
///    may never have had a `products` row for. `InvoiceItem` carries no
///    barcode, no separate purchase price, no `reorderLevel`, no `supplierId`,
///    no `commissionRate`, and its `qty` is the TRANSACTION quantity, not
///    stock. Rebuilding a `Product` from those fields would invent a purchase
///    price and would silently drop consignment attribution — so the mirror
///    must not do it, and `writeSale` must refuse the unknown id with an
///    honest error instead of queueing a line the server cannot resolve.
///
///  * **B4.4 — the empty mirror is an honest error, never a silent `[]`.**
///    `cacheFirst` rethrows `NetworkException` when the mirror has nothing;
///    the picker must therefore surface "cannot load products" rather than
///    showing an empty sheet the user reads as "this shop has no products".
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasad_erp/core/error/app_exception.dart';
import 'package:hasad_erp/data/offline/local_database.dart';
import 'package:hasad_erp/data/offline/local_store.dart';
import 'package:hasad_erp/data/offline/offline_product_repository.dart';
import 'package:hasad_erp/data/offline/offline_write.dart';
import 'package:hasad_erp/domain/products/product.dart';
import 'package:hasad_erp/domain/products/product_draft.dart';
import 'package:hasad_erp/domain/products/product_repository.dart';
import 'package:hasad_erp/domain/sales/sale_invoice_draft.dart';

const _tenant = 'tenant-a';

void main() {
  group('B4.1/B4.2. a MIRRORED product is searchable offline', () {
    test('a local_products row is findable by name and by barcode, with no '
        'network, after a cold start', () async {
      final h = await _Harness.boot();
      await h.seedCatalog();

      await h.restart();

      final repo = h.repo();

      final byName = await repo.listAll(search: 'تفاح');
      expect(
        byName.map((p) => p.id),
        ['p-apple'],
        reason:
            'a product this device HAS mirrored must be searchable '
            'offline by name — the failure being reported is that search '
            'ignores the term, not that the term can never match',
      );

      final byBarcode = await repo.listAll(search: '6281000000017');
      expect(
        byBarcode.map((p) => p.id),
        ['p-banana'],
        reason:
            'barcode lookup is the other half of the filter '
            '(`_matches(p.barcode, term)`); a name-only filter would fail '
            'here while B4.1\'s case still passed',
      );

      // The mirrored row must carry real prices, not zeros — the picker's
      // pre-fill reads salePrice straight off this row.
      expect(byName.single.salePrice, 25000);
      expect(
        byName.single.purchasePrice,
        18000,
        reason:
            'a mirror that dropped or collapsed the purchase price would '
            'pass B4.1 while breaking every Purchase line built from it',
      );
    });

    test('a mirrored product is resolvable by id, and writeSale can use it '
        'with no network', () async {
      final h = await _Harness.boot();
      await h.seedCatalog();
      await h.restart();

      await h.seedChart();
      final byId = await h.repo().getById('p-apple');
      expect(
        byId,
        isNotNull,
        reason:
            'the picker resolves the tapped row by id, so an offline '
            'catalog that lists a product but cannot return it by id would '
            'fail on tap with no product chosen',
      );
      expect(byId!.name, 'تفاح أحمر');

      final result = await h.writer.writeSale(_saleDraft('p-apple'));
      expect(
        result.pending,
        isTrue,
        reason: 'the write must queue rather than need the network',
      );
      expect(
        (await h.store.invoices(_tenant, type: 'sale')).single.id,
        result.invoiceId,
      );
    });
  });

  group('B4.3. an InvoiceItem-only reference must NOT become a product', () {
    test('a mirrored invoice line whose product was never in the catalog '
        'stays unselectable, and writeSale refuses it honestly', () async {
      final h = await _Harness.boot();

      // The invoice header mirrors fine (that path is P1.D/P1.E's), and so do
      // its lines — but ONLY `local_invoice_items` exists for this product id.
      // There is no `local_products` row, which is the real shape of "the
      // invoice was created on the server, this device never saw the product".
      await h.seedCatalog();
      await h.seedChart();
      await h.store.upsertInvoice(_mirroredInvoice());
      await h.store.upsertInvoiceItems([
        _mirroredLine(invoiceId: 'srv-1', productId: 'p-ghost'),
      ]);
      await h.restart();

      // The picker reads the CATALOG, and the catalog mirror is well populated
      // here — so `listAll` succeeds and the question is only whether the
      // historical line reference shows up in it.
      final catalog = await h.repo().listAll();
      expect(
        catalog.where((p) => p.id == 'p-ghost'),
        isEmpty,
        reason:
            'InvoiceItem has no barcode, no purchase price, no '
            'reorderLevel, no supplierId and no commissionRate, and its qty is '
            'the transaction quantity. Synthesising a Product from it would '
            'invent a purchase price and could silently drop consignment '
            'attribution — so a historical line reference must NOT appear in '
            'the selectable catalog.',
      );

      // And the write path must refuse it rather than queue an unresolvable
      // line. This is the reachable failure the picker guards against.
      expect(
        () => h.writer.writeSale(_saleDraft('p-ghost')),
        throwsA(isA<ValidationException>()),
        reason:
            'the honest Arabic refusal must be what the caller sees. It was '
            'UNREACHABLE: the price was resolved in the same list comprehension '
            'that built the lines, one line BEFORE the guard ran, so '
            '`products[l.productId]!.salePrice` threw a raw `_TypeError` first '
            'and `_guard` (which maps `StateError` and `ArgumentError`, not '
            '`TypeError`) passed it straight through — the UI showed the generic '
            'unknown-error message and the real refusal existed only as dead '
            'code. The guard now runs over `draft.lines`, before any priced '
            'line exists.',
      );
      expect(
        await h.store.pendingCount(_tenant),
        0,
        reason:
            'the refusal must enqueue nothing: an aborted draft that left '
            'a queue leg behind would be a second, subtler data-loss path. '
            '(`pendingCount`, not an invoice count, because this case '
            'deliberately mirrored a header so it cannot assert an empty '
            'invoice list.)',
      );
      expect(
        await h.store.invoices(_tenant, type: 'sale'),
        hasLength(1),
        reason:
            'the only sale invoice is the one mirrored at the top; the '
            'refused draft must not have added a second',
      );
    });

    test('with an explicit price, the same unknown product IS refused with the '
        'honest Arabic error', () async {
      // The reachable half of the case above: give the caller-supplied price so
      // the dead guard at :77 is the thing that fires. This documents that the
      // refusal is already implemented — only its ORDER is wrong.
      final h = await _Harness.boot();
      await h.seedCatalog();
      await h.seedChart();
      await h.restart();

      await expectLater(
        h.writer.writeSale(
          const SaleInvoiceDraft(
            customerId: 'c1',
            lines: [SaleLineDraft(productId: 'p-ghost', qty: 1, price: 100)],
            date: null,
          ),
        ),
        throwsA(isA<ValidationException>()),
      );
      expect(await h.store.pendingCount(_tenant), 0);
    });

    test('but the same product IS selectable once a real catalog row exists — '
        'the historical line is not a permanent bar', () async {
      final h = await _Harness.boot();
      await h.seedCatalog();
      await h.seedChart();
      await h.restart();

      final catalog = await h.repo().listAll();
      expect(catalog.map((p) => p.id), containsAll(['p-apple', 'p-banana']));

      final result = await h.writer.writeSale(_saleDraft('p-banana'));
      expect(result.pending, isTrue);
    });
  });

  group('B4.4. an empty mirror is an honest error, not an empty catalog', () {
    test('with no mirrored rows and no network, listAll rethrows rather than '
        'serving []', () async {
      final h = await _Harness.boot();
      await h.restart();

      expect(
        () => h.repo().listAll(),
        throwsA(isA<NetworkException>()),
        reason:
            '`cacheFirst` over an empty mirror rethrows (M11 Slice A.5). '
            'A silent `[]` here would render as an empty picker sheet, which '
            'the user reads as "this shop sells nothing" — a different and '
            'much more alarming claim than "products could not be loaded"',
      );
    });
  });
}

class _Harness {
  _Harness._(this.dir, this.file, this.db, this.store);

  final Directory dir;
  final File file;
  AppDatabase db;
  DriftLocalStore store;

  OfflineWriteCoordinator get writer => OfflineWriteCoordinator(store, _tenant);

  /// Reads the local mirror only; the network side is dead, which is the point.
  OfflineProductRepository repo() => OfflineProductRepository(
    _NoNetworkProducts(),
    store: store,
    tenantId: _tenant,
  );

  static Future<_Harness> boot() async {
    final dir = Directory.systemTemp.createTempSync('hasad_product_catalog');
    final file = File('${dir.path}/hasad_offline.sqlite');
    final db = AppDatabase(NativeDatabase(file));
    final h = _Harness._(dir, file, db, DriftLocalStore(db));
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    // A closure, not a tear-off: `restart()` replaces `db`, and on Windows a
    // still-open connection blocks deleting the temp directory.
    addTearDown(() => h.db.close());
    return h;
  }

  Future<void> restart() async {
    await db.close();
    db = AppDatabase(NativeDatabase(file));
    store = DriftLocalStore(db);
  }

  /// Two real products, mirrored as `synced: true` rows — the shape left by a
  /// successful online `listAll()`.
  Future<void> seedCatalog() async {
    await store.upsertProduct(
      LocalProductRow(
        id: 'p-apple',
        tenantId: _tenant,
        name: 'تفاح أحمر',
        barcode: '6281000000010',
        unit: 'كرتونة',
        unitType: 'count',
        salePrice: 25000,
        purchasePrice: 18000,
        qty: 40,
        reorderLevel: 5,
        supplierId: null,
        commissionRate: null,
        createdAt: DateTime(2026, 1, 1),
        synced: true,
      ),
    );
    await store.upsertProduct(
      LocalProductRow(
        id: 'p-banana',
        tenantId: _tenant,
        name: 'موز',
        barcode: '6281000000017',
        unit: 'كرتونة',
        unitType: 'count',
        salePrice: 30000,
        purchasePrice: 22000,
        qty: 25,
        reorderLevel: 5,
        supplierId: null,
        commissionRate: null,
        createdAt: DateTime(2026, 1, 1),
        synced: true,
      ),
    );
  }

  /// The minimum `writeSale` accepts: the customer it bills, the accounts the
  /// sale posts to, and the inventory account it credits.
  Future<void> seedChart() async {
    await store.upsertCustomer(
      LocalCustomerRow(
        id: 'c1',
        tenantId: _tenant,
        name: 'عميل',
        phone: null,
        notes: null,
        createdAt: DateTime(2026, 1, 1),
        synced: true,
      ),
    );
    for (final a in const [
      ('a1', '1010', 'نقدية', 'asset'),
      ('a2', '1020', 'ذمم مدينة', 'asset'),
      ('a4', '1030', 'مخزون', 'asset'),
      ('a7', '4010', 'إيرادات مبيعات', 'revenue'),
    ]) {
      await store.upsertAccount(
        LocalAccountRow(
          id: a.$1,
          tenantId: _tenant,
          code: a.$2,
          name: a.$3,
          type: a.$4,
          parentCode: null,
        ),
      );
    }
  }
}

/// One offline sale line naming [productId]. The price is left null on purpose
/// so `writeSale` has to derive it from the local product row — which is also
/// what makes the `p-ghost` refusal reachable rather than bypassed by a
/// caller-supplied price.
SaleInvoiceDraft _saleDraft(String productId) => SaleInvoiceDraft(
  customerId: 'c1',
  lines: [SaleLineDraft(productId: productId, qty: 1)],
  date: DateTime(2026, 3, 5),
);

/// A server-side sale invoice, mirrored header-only (P1.C's shape).
LocalInvoiceRow _mirroredInvoice() => LocalInvoiceRow(
  id: 'srv-1',
  tenantId: _tenant,
  type: 'sale',
  no: 'SALE-2001',
  partyId: 'c1',
  partyName: 'عميل',
  date: DateTime(2026, 3, 1),
  subtotal: 900,
  total: 900,
  paid: 0,
  remaining: 900,
  status: 'unpaid',
  ownership: 'owned',
  requestId: null,
  synced: true,
  createdAt: null,
);

/// The one durable row a historical line leaves behind for a product this device
/// never had a `products` row for.
LocalInvoiceItemRow _mirroredLine({
  required String invoiceId,
  required String productId,
}) => LocalInvoiceItemRow(
  id: '$invoiceId:0000',
  tenantId: _tenant,
  invoiceId: invoiceId,
  productId: productId,
  productName: 'ورقية A4',
  productUnit: 'كرتونة',
  productUnitType: 'count',
  qty: 3,
  price: 300,
  total: 900,
);

/// A server that is never reachable — every read throws `NetworkException`, so
/// anything `listAll` returns came out of the local mirror.
class _NoNetworkProducts implements ProductRepository {
  @override
  Future<List<Product>> listAll({String? search}) async =>
      throw const NetworkException();

  @override
  Future<Product?> getById(String id) async => throw const NetworkException();

  @override
  Future<Product> create(ProductDraft draft) async =>
      throw const NetworkException();

  @override
  Future<void> update({
    required String id,
    required ProductDraft draft,
  }) async => throw const NetworkException();

  @override
  Future<void> delete(String id) async => throw const NetworkException();
}
