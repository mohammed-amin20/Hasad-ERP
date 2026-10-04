import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasad_erp/core/error/app_exception.dart';
import 'package:hasad_erp/data/offline/local_database.dart';
import 'package:hasad_erp/data/offline/local_store.dart';
import 'package:hasad_erp/data/offline/offline_write.dart';
import 'package:hasad_erp/domain/inventory/inventory.dart';
import 'package:hasad_erp/domain/products/product.dart';
import 'package:hasad_erp/domain/products/product_draft.dart';
import 'package:hasad_erp/domain/purchases/purchase_invoice_draft.dart';
import 'package:hasad_erp/domain/salaries/salary_repository.dart';
import 'package:hasad_erp/domain/sales/sale_invoice_draft.dart';

/// Standalone Inventory Adjustment, offline-first.
///
/// A physical count is `adjust_inventory` — it writes a `stock_moves` row and
/// sets `products.qty`; it posts NO journal. Offline it moves the local mirror
/// quantity and queues the RPC, and until that leg replays the product's
/// quantity is owned by the leg (not by any server refresh). These tests pin:
///
///  * the queued leg's shape (`rpc`, `entity: null`, `localId`, attribution,
///    `p_request_id`) and the no-op / rejected paths;
///  * the dependency rule (a count replays after every earlier pending stock
///    mutation of the same product, and only of the same product);
///  * the mirror quantity-authority rule (a pending stock leg freezes exactly
///    its product's quantity, never an unrelated one or another tenant's);
///  * Product EDIT never restates quantity (DECISION 2);
///  * stock and delete are mutually exclusive.
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

  LocalProductRow productRow(
    String id, {
    double qty = 100,
    String name = 'سلعة',
    bool synced = true,
    DateTime? createdAt,
  }) =>
      LocalProductRow(
        id: id,
        tenantId: tenant,
        name: name,
        barcode: null,
        unit: 'قطعة',
        unitType: 'count',
        salePrice: 10000,
        purchasePrice: 6000,
        qty: qty,
        reorderLevel: 10,
        supplierId: null,
        commissionRate: null,
        createdAt: createdAt ?? DateTime(2026, 1, 1),
        synced: synced,
      );

  Future<void> seed() async {
    Future<void> acct(String id, String code, String name, String type) =>
        store.upsertAccount(LocalAccountRow(
          id: id,
          tenantId: tenant,
          code: code,
          name: name,
          type: type,
          parentCode: null,
        ));

    await acct('a1', '1010', 'نقدية', 'asset');
    await acct('a3', '1020', 'ذمم مدينة', 'asset');
    await acct('a4', '1030', 'مخزون', 'asset');
    await acct('a5', '2010', 'ذمم دائنة', 'liability');
    await acct('a7', '4010', 'إيرادات', 'revenue');

    await store.upsertSupplier(LocalSupplierRow(
      id: 's1',
      tenantId: tenant,
      name: 'مورد',
      phone: null,
      notes: null,
      dealType: 'direct',
      commissionRate: null,
      createdAt: DateTime(2026, 1, 1),
      synced: false,
    ));

    await store.upsertCustomer(LocalCustomerRow(
      id: 'c1',
      tenantId: tenant,
      name: 'عميل',
      phone: '0599',
      notes: null,
      createdAt: DateTime(2026, 1, 1),
      synced: false,
    ));

    await store.upsertProduct(productRow('p1', qty: 100));
    await store.upsertProduct(productRow('p2', qty: 50, name: 'سلعة2'));
  }

  Future<LocalProductRow> p(String id) async =>
      (await store.products(tenant)).firstWhere((r) => r.id == id);

  Future<List<SyncQueueRow>> pending() => store.pendingSync(tenant);

  SyncQueueRow leg({
    required String id,
    required String rpc,
    String op = 'rpc',
    String params = '{}',
    String? status = 'pending',
    String? localId,
    String? affectsProductIds,
    DateTime? createdAt,
  }) =>
      SyncQueueRow(
        id: id,
        tenantId: tenant,
        rpc: rpc,
        op: op,
        params: params,
        requestId: null,
        entity: null,
        localId: localId,
        status: status ?? 'pending',
        attempts: 0,
        lastError: null,
        dependsOn: null,
        affectsInvoiceIds: null,
        affectsProductIds: affectsProductIds,
        createdAt: createdAt ?? DateTime(2026, 1, 2),
        updatedAt: createdAt ?? DateTime(2026, 1, 2),
      );

  group('adjustInventory', () {
    test('moves local qty and queues an attributed adjust_inventory leg',
        () async {
      await seed();

      final result = await writer.adjustInventory(
        const StockAdjustDraft(productId: 'p1', countedQty: 80, reason: 'جرد'),
      );

      expect(result.changed, isTrue);
      expect(result.oldQty, 100);
      expect(result.newQty, 80);
      expect(result.delta, -20);
      expect(result.productName, 'سلعة');

      expect((await p('p1')).qty, 80);
      // adjust_inventory posts no journal (0014), so neither may the mirror.
      expect(await store.journalEntries(tenant), isEmpty);

      final queued = await pending();
      expect(queued, hasLength(1));
      final queuedLeg = queued.single;
      expect(queuedLeg.rpc, 'adjust_inventory');
      expect(queuedLeg.op, 'rpc');
      expect(queuedLeg.entity, isNull);
      expect(queuedLeg.localId, 'p1');
      expect(queuedLeg.requestId, isNotNull);
      expect(LocalStore.parseProductAttribution(queuedLeg.affectsProductIds),
          ['p1']);
      expect(queuedLeg.dependsOn, isNull);

      final params = jsonDecode(queuedLeg.params) as Map<String, dynamic>;
      expect(params['p_product_id'], 'p1');
      expect(params['p_counted_qty'], 80);
      expect(params['p_reason'], 'جرد');
      expect(params['p_request_id'], queuedLeg.requestId);
    });

    test('a count equal to the current local qty is a no-op', () async {
      await seed();

      final result = await writer.adjustInventory(
        const StockAdjustDraft(productId: 'p1', countedQty: 100),
      );

      expect(result.changed, isFalse);
      expect(result.delta, 0);
      expect((await p('p1')).qty, 100);
      expect(await pending(), isEmpty);
    });

    test('a negative count is rejected and queues nothing', () async {
      await seed();

      await expectLater(
        writer.adjustInventory(
          const StockAdjustDraft(productId: 'p1', countedQty: -1),
        ),
        throwsA(isA<ValidationException>()),
      );
      expect((await p('p1')).qty, 100);
      expect(await pending(), isEmpty);
    });

    test('an unknown product surfaces a validation error', () async {
      await seed();

      await expectLater(
        writer.adjustInventory(
          const StockAdjustDraft(productId: 'nope', countedQty: 5),
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('a product queued for deletion cannot be counted', () async {
      await seed();
      await writer.deleteProduct('p2');

      await expectLater(
        writer.adjustInventory(
          const StockAdjustDraft(productId: 'p2', countedQty: 40),
        ),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.message,
            'message',
            contains('قيد الحذف'),
          ),
        ),
      );
    });

    test('a count on another product records no dependency', () async {
      await seed();
      await writer.adjustInventory(
        const StockAdjustDraft(productId: 'p1', countedQty: 90),
      );
      await writer.adjustInventory(
        const StockAdjustDraft(productId: 'p2', countedQty: 40),
      );

      final onP2 = (await pending()).firstWhere((l) => l.localId == 'p2');
      expect(onP2.dependsOn, isNull);
    });

    test('a later count depends on the earlier pending stock leg', () async {
      await seed();
      await writer.adjustInventory(
        const StockAdjustDraft(productId: 'p1', countedQty: 90),
      );
      final first = (await pending()).single;

      await writer.adjustInventory(
        const StockAdjustDraft(productId: 'p1', countedQty: 85),
      );

      final second =
          (await pending()).firstWhere((l) => l.id != first.id);
      expect(LocalStore.parseDependencies(second.dependsOn),
          contains(first.id));
    });

    test('a terminal failed stock leg does not block a new count', () async {
      await seed();
      await store.enqueue(leg(
        id: 'leg-failed',
        rpc: 'adjust_inventory',
        status: 'failed',
        localId: 'p1',
        affectsProductIds: jsonEncode(['p1']),
      ));

      final result = await writer.adjustInventory(
        const StockAdjustDraft(productId: 'p1', countedQty: 80),
      );

      expect(result.changed, isTrue);
      // pendingSync returns pending legs only; the new leg must not depend on
      // the parked diagnostic one.
      expect((await pending()).single.dependsOn, isNull);
    });

    test('retrying a queued count replays the same request id', () async {
      await seed();
      await writer.adjustInventory(
        const StockAdjustDraft(productId: 'p1', countedQty: 80),
      );
      final before = (await pending()).single;
      final rid = before.requestId;
      expect(rid, isNotNull);

      await store.requeueRetry(before.id, 'transient', 1);

      final after = (await pending()).single;
      expect(after.requestId, rid);
      expect(jsonDecode(after.params)['p_request_id'], rid);
    });
  });

  group('mirrorProducts quantity authority', () {
    test('a pending stock leg preserves qty but accepts server master fields',
        () async {
      await seed();
      await writer.adjustInventory(
        const StockAdjustDraft(productId: 'p1', countedQty: 80),
      );

      await store.mirrorProducts(tenant, [
        productRow('p1', qty: 100, name: 'اسم من الخادم'),
        productRow('p2', qty: 50, name: 'سلعة2'),
      ]);

      final p1 = await p('p1');
      expect(p1.qty, 80, reason: 'the pending stock leg owns the quantity');
      expect(p1.name, 'اسم من الخادم',
          reason: 'master fields still come from the server');
      // An unrelated product is never frozen by a pending leg on another.
      expect((await p('p2')).qty, 50);
    });

    test('a terminal failed stock leg does not freeze qty', () async {
      await seed();
      await store.enqueue(leg(
        id: 'leg-failed',
        rpc: 'adjust_inventory',
        status: 'failed',
        localId: 'p1',
        affectsProductIds: jsonEncode(['p1']),
      ));

      await store.mirrorProducts(tenant, [productRow('p1', qty: 40)]);

      expect((await p('p1')).qty, 40);
    });

    test('a pending leg in another tenant does not freeze our qty', () async {
      await seed();
      await store.upsertProduct(productRow('p1', qty: 80));
      await store.enqueue(SyncQueueRow(
        id: 'leg-b',
        tenantId: 'tenant-b',
        rpc: 'adjust_inventory',
        op: 'rpc',
        params: '{}',
        requestId: null,
        entity: null,
        localId: 'p1',
        status: 'pending',
        attempts: 0,
        lastError: null,
        dependsOn: null,
        affectsInvoiceIds: null,
        affectsProductIds: jsonEncode(['p1']),
        createdAt: DateTime(2026, 1, 2),
        updatedAt: DateTime(2026, 1, 2),
      ));

      await store.mirrorProducts(tenant, [productRow('p1', qty: 100)]);

      expect((await p('p1')).qty, 100);
    });

    test('a pre-v9 leg with a NULL column still protects qty via p_items',
        () async {
      await seed();
      await store.upsertProduct(productRow('p1', qty: 80));
      await store.enqueue(leg(
        id: 'leg-sale',
        rpc: 'create_sale_invoice',
        params: jsonEncode({
          'p_items': [
            {'product_id': 'p1', 'qty': 2},
          ],
        }),
        affectsProductIds: null,
      ));

      await store.mirrorProducts(tenant, [productRow('p1', qty: 100)]);

      expect((await p('p1')).qty, 80);
    });
  });

  group('LocalStore product attribution', () {
    test('parseProductAttribution tolerates null/empty/malformed', () {
      expect(LocalStore.parseProductAttribution(null), isEmpty);
      expect(LocalStore.parseProductAttribution(''), isEmpty);
      expect(LocalStore.parseProductAttribution('not json'), isEmpty);
      expect(LocalStore.parseProductAttribution('{"a":1}'), isEmpty);
      expect(LocalStore.parseProductAttribution('[1,"p1",null,""]'), ['p1']);
    });

    test('affectedProductIdsOf prefers the durable column over params', () {
      final row = leg(
        id: 'l1',
        rpc: 'adjust_inventory',
        params: jsonEncode({'p_product_id': 'other'}),
        affectsProductIds: jsonEncode(['p9']),
      );
      expect(LocalStore.affectedProductIdsOf(row), {'p9'});
    });

    test('affectedProductIdsOf derives a legacy sale/purchase item set', () {
      final row = leg(
        id: 'l2',
        rpc: 'create_sale_invoice',
        params: jsonEncode({
          'p_items': [
            {'product_id': 'a'},
            {'product_id': 'b'},
          ],
        }),
      );
      expect(LocalStore.affectedProductIdsOf(row), {'a', 'b'});
    });

    test('affectedProductIdsOf derives a legacy movement product', () {
      final row = leg(
        id: 'l3',
        rpc: 'add_employee_movement',
        params: jsonEncode({'p_product_id': 'p1'}),
      );
      expect(LocalStore.affectedProductIdsOf(row), {'p1'});
    });

    test('affectedProductIdsOf treats a product create with qty as a stock leg',
        () {
      final row = leg(
        id: 'l4',
        rpc: 'table:products',
        op: 'table_crud',
        params: jsonEncode({'id': 'p1', 'name': 'x', 'qty': 5}),
      );
      expect(LocalStore.affectedProductIdsOf(row), {'p1'});
    });

    test('affectedProductIdsOf treats a product edit without qty as non-stock',
        () {
      final row = leg(
        id: 'l5',
        rpc: 'table:products',
        op: 'table_crud',
        params: jsonEncode({'id': 'p1', 'row': {'name': 'x'}}),
      );
      expect(LocalStore.affectedProductIdsOf(row), isEmpty);
    });
  });

  group('stock-leg stamping', () {
    test('writeSale stamps every line product on its leg', () async {
      await seed();

      await writer.writeSale(SaleInvoiceDraft(
        customerId: 'c1',
        lines: [
          SaleLineDraft(productId: 'p1', qty: 2, price: 10000),
          SaleLineDraft(productId: 'p2', qty: 1, price: 15000),
        ],
        date: DateTime(2026, 9, 9),
        paid: 0,
      ));

      final saleLeg = (await pending())
          .firstWhere((l) => l.rpc == 'create_sale_invoice');
      expect(LocalStore.parseProductAttribution(saleLeg.affectsProductIds),
          unorderedEquals(['p1', 'p2']));
    });

    test('writePurchase stamps the stocked product on its leg', () async {
      await seed();

      await writer.writePurchase(PurchaseInvoiceDraft(
        supplierId: 's1',
        lines: [PurchaseLineDraft(productId: 'p1', qty: 10, price: 6000)],
        date: DateTime(2026, 9, 9),
      ));

      final purchaseLeg = (await pending())
          .firstWhere((l) => l.rpc == 'create_purchase_invoice');
      expect(LocalStore.parseProductAttribution(purchaseLeg.affectsProductIds),
          ['p1']);
    });

    test('addMovement stamps the deducted product on its leg', () async {
      await seed();
      await store.upsertEmployee(LocalEmployeeRow(
        id: 'e1',
        tenantId: tenant,
        name: 'موظف',
        jobTitle: null,
        phone: null,
        baseSalary: 100,
        createdAt: DateTime(2026, 1, 1),
        synced: false,
      ));

      await writer.addMovement(MovementDraft(
        employeeId: 'e1',
        month: DateTime(2026, 9, 1),
        direction: 'out',
        category: 'product',
        productId: 'p1',
        qty: 2,
      ));

      final movementLeg = (await pending())
          .firstWhere((l) => l.rpc == 'add_employee_movement');
      expect(LocalStore.parseProductAttribution(movementLeg.affectsProductIds),
          ['p1']);
    });
  });

  group('Product EDIT keeps stock authority separate', () {
    test('updateProduct preserves live qty and strips qty from replay',
        () async {
      await seed();
      await writer.writeSale(SaleInvoiceDraft(
        customerId: 'c1',
        lines: [SaleLineDraft(productId: 'p1', qty: 2, price: 10000)],
        date: DateTime(2026, 9, 9),
        paid: 0,
      ));
      expect((await p('p1')).qty, 98);

      await writer.updateProduct(
        'p1',
        const ProductDraft(
          name: 'اسم جديد',
          unit: 'قطعة',
          unitType: ProductUnitType.count,
          salePrice: 11000,
          purchasePrice: 6500,
          qty: 999,
          reorderLevel: 12,
        ),
      );

      final p1 = await p('p1');
      expect(p1.qty, 98, reason: 'an edit never restates the quantity');
      expect(p1.name, 'اسم جديد');

      final updateLeg =
          (await store.queueLegsFor(tenant, entity: 'products')).singleWhere(
        (l) => jsonDecode(l.params) is Map && (jsonDecode(l.params) as Map).containsKey('row'),
      );
      final params = jsonDecode(updateLeg.params) as Map<String, dynamic>;
      expect((params['row'] as Map).containsKey('qty'), isFalse);
      expect(LocalStore.parseProductAttribution(updateLeg.affectsProductIds),
          isEmpty);
    });
  });

  group('stock and delete are mutually exclusive', () {
    test('deleteProduct refuses while a stock leg is pending', () async {
      await seed();
      await writer.adjustInventory(
        const StockAdjustDraft(productId: 'p1', countedQty: 80),
      );

      await expectLater(
        writer.deleteProduct('p1'),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.message,
            'message',
            contains('مخزون'),
          ),
        ),
      );
    });
  });

  // Reverse stock ordering: an Adjustment still queued, then a LATER
  // sale/purchase/product-movement on its product. The adjustment's approved
  // contract sets `localId = productId`, and the generic localId-keyed
  // master resolver (`_pendingMasterLegIds` / `_pendingLegIdsFor`) matches on
  // that alone — so in the real flow the dependency ALSO arrives through the
  // master path, which is why the original M5 survived. The
  // `... through attribution` cases below give the stock leg a non-product
  // sentinel `localId`, so the only possible source of the UUID is the
  // persisted product attribution (`affects_product_ids`); those are the
  // assertions that fail if the new contribution is removed.
  group('reverse stock dependency (Adjustment -> later legs)', () {
    const adjSentinel = 'adj:local-id-not-a-product';

    LocalEmployeeRow employeeRow() => LocalEmployeeRow(
          id: 'e1',
          tenantId: tenant,
          name: 'موظف',
          jobTitle: null,
          phone: null,
          baseSalary: 100,
          createdAt: DateTime(2026, 1, 1),
          synced: false,
        );

    Future<SyncQueueRow> saleLegAfter(SaleInvoiceDraft draft) async {
      await writer.writeSale(draft);
      return (await pending())
          .singleWhere((l) => l.rpc == 'create_sale_invoice');
    }

    test('J2: a sale after a pending adjustment depends on it', () async {
      await seed();
      await writer.adjustInventory(
        const StockAdjustDraft(productId: 'p1', countedQty: 90),
      );
      final adjustment =
          (await pending()).singleWhere((l) => l.rpc == 'adjust_inventory');
      expect(LocalStore.affectedProductIdsOf(adjustment), contains('p1'));

      final sale = await saleLegAfter(SaleInvoiceDraft(
        customerId: 'c1',
        lines: [SaleLineDraft(productId: 'p1', qty: 2, price: 10000)],
        date: DateTime(2026, 9, 9),
        paid: 0,
      ));

      expect(LocalStore.parseDependencies(sale.dependsOn),
          contains(adjustment.id));
      expect(LocalStore.parseProductAttribution(sale.affectsProductIds),
          contains('p1'));
    });

    test('J4: a purchase after a pending adjustment depends on it', () async {
      await seed();
      await writer.adjustInventory(
        const StockAdjustDraft(productId: 'p1', countedQty: 90),
      );
      final adjustment =
          (await pending()).singleWhere((l) => l.rpc == 'adjust_inventory');

      await writer.writePurchase(PurchaseInvoiceDraft(
        supplierId: 's1',
        lines: [PurchaseLineDraft(productId: 'p1', qty: 10, price: 6000)],
        date: DateTime(2026, 9, 9),
      ));

      final purchase = (await pending())
          .singleWhere((l) => l.rpc == 'create_purchase_invoice');
      expect(LocalStore.parseDependencies(purchase.dependsOn),
          contains(adjustment.id));
      expect(LocalStore.parseProductAttribution(purchase.affectsProductIds),
          contains('p1'));
    });

    test('J6: a product movement after a pending adjustment depends on it',
        () async {
      await seed();
      await store.upsertEmployee(employeeRow());
      await writer.adjustInventory(
        const StockAdjustDraft(productId: 'p1', countedQty: 90),
      );
      final adjustment =
          (await pending()).singleWhere((l) => l.rpc == 'adjust_inventory');

      await writer.addMovement(MovementDraft(
        employeeId: 'e1',
        month: DateTime(2026, 9, 1),
        direction: 'out',
        category: 'product',
        productId: 'p1',
        qty: 2,
      ));

      final movement = (await pending())
          .singleWhere((l) => l.rpc == 'add_employee_movement');
      expect(LocalStore.parseDependencies(movement.dependsOn),
          contains(adjustment.id));
      expect(LocalStore.parseProductAttribution(movement.affectsProductIds),
          contains('p1'));
    });

    test('J2 through attribution: the stock path, not localId, links the sale',
        () async {
      await seed();
      await store.enqueue(leg(
        id: 'adj-attr-only',
        rpc: 'adjust_inventory',
        localId: adjSentinel,
        params: jsonEncode({'p_product_id': 'p1', 'p_counted_qty': 90}),
        affectsProductIds: jsonEncode(['p1']),
      ));

      final sale = await saleLegAfter(SaleInvoiceDraft(
        customerId: 'c1',
        lines: [SaleLineDraft(productId: 'p1', qty: 2, price: 10000)],
        date: DateTime(2026, 9, 9),
        paid: 0,
      ));

      expect(LocalStore.parseDependencies(sale.dependsOn),
          contains('adj-attr-only'));
      expect(LocalStore.parseProductAttribution(sale.affectsProductIds),
          contains('p1'));
    });

    test('J4 through attribution: the stock path links the purchase', () async {
      await seed();
      await store.enqueue(leg(
        id: 'adj-attr-only',
        rpc: 'adjust_inventory',
        localId: adjSentinel,
        params: jsonEncode({'p_product_id': 'p1', 'p_counted_qty': 90}),
        affectsProductIds: jsonEncode(['p1']),
      ));

      await writer.writePurchase(PurchaseInvoiceDraft(
        supplierId: 's1',
        lines: [PurchaseLineDraft(productId: 'p1', qty: 10, price: 6000)],
        date: DateTime(2026, 9, 9),
      ));

      final purchase = (await pending())
          .singleWhere((l) => l.rpc == 'create_purchase_invoice');
      expect(LocalStore.parseDependencies(purchase.dependsOn),
          contains('adj-attr-only'));
    });

    test('J6 through attribution: the stock path links the movement', () async {
      await seed();
      await store.upsertEmployee(employeeRow());
      await store.enqueue(leg(
        id: 'adj-attr-only',
        rpc: 'adjust_inventory',
        localId: adjSentinel,
        params: jsonEncode({'p_product_id': 'p1', 'p_counted_qty': 90}),
        affectsProductIds: jsonEncode(['p1']),
      ));

      await writer.addMovement(MovementDraft(
        employeeId: 'e1',
        month: DateTime(2026, 9, 1),
        direction: 'out',
        category: 'product',
        productId: 'p1',
        qty: 2,
      ));

      final movement = (await pending())
          .singleWhere((l) => l.rpc == 'add_employee_movement');
      expect(LocalStore.parseDependencies(movement.dependsOn),
          contains('adj-attr-only'));
    });

    test('resolver: an adjustment on an unrelated product does not link',
        () async {
      await seed();
      await store.enqueue(leg(
        id: 'adj-on-p2',
        rpc: 'adjust_inventory',
        localId: adjSentinel,
        params: jsonEncode({'p_product_id': 'p2', 'p_counted_qty': 40}),
        affectsProductIds: jsonEncode(['p2']),
      ));

      final sale = await saleLegAfter(SaleInvoiceDraft(
        customerId: 'c1',
        lines: [SaleLineDraft(productId: 'p1', qty: 2, price: 10000)],
        date: DateTime(2026, 9, 9),
        paid: 0,
      ));

      expect(sale.dependsOn, isNull);
    });

    test('resolver: a terminal failed adjustment does not link', () async {
      await seed();
      await store.enqueue(leg(
        id: 'adj-failed',
        rpc: 'adjust_inventory',
        status: 'failed',
        localId: adjSentinel,
        params: jsonEncode({'p_product_id': 'p1', 'p_counted_qty': 90}),
        affectsProductIds: jsonEncode(['p1']),
      ));

      final sale = await saleLegAfter(SaleInvoiceDraft(
        customerId: 'c1',
        lines: [SaleLineDraft(productId: 'p1', qty: 2, price: 10000)],
        date: DateTime(2026, 9, 9),
        paid: 0,
      ));

      expect(sale.dependsOn, isNull);
    });
  });
}
