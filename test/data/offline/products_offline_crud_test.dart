import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasad_erp/core/error/app_exception.dart';
import 'package:hasad_erp/data/offline/local_database.dart';
import 'package:hasad_erp/data/offline/local_store.dart';
import 'package:hasad_erp/data/offline/offline_write.dart';
import 'package:hasad_erp/domain/products/product.dart';
import 'package:hasad_erp/domain/products/product_draft.dart';

import 'delegating_local_store.dart';

const tenant = 'tenant-a';

const _draft = ProductDraft(
  name: 'منتج',
  barcode: 'BAR-1',
  unit: 'قطعة',
  unitType: ProductUnitType.count,
  salePrice: 10000,
  purchasePrice: 6000,
  qty: 10,
  reorderLevel: 2,
);

void main() {
  late AppDatabase db;
  late DriftLocalStore store;
  late OfflineWriteCoordinator writer;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = DriftLocalStore(db);
    writer = OfflineWriteCoordinator(store, tenant);
  });

  tearDown(() => db.close());

  Future<void> seedProduct() async {
    await store.upsertProduct(LocalProductRow(
      id: 'p1',
      tenantId: tenant,
      name: 'سلعة مباشرة',
      barcode: null,
      unit: 'قطعة',
      unitType: 'count',
      salePrice: 10000,
      purchasePrice: 6000,
      qty: 100,
      reorderLevel: 10,
      supplierId: 's1',
      commissionRate: null,
      createdAt: DateTime(2026, 1, 1),
      synced: true,
    ));
  }

  group('writeProduct', () {
    test('mirrors synced:false and enqueues a table_crud upsert', () async {
      final product = await writer.writeProduct(_draft);

      final row = (await store.products(tenant)).single;
      expect(row.id, product.id);
      expect(row.synced, isFalse);
      expect(row.name, 'منتج');
      expect(row.barcode, 'BAR-1');
      expect(row.qty, 10);
      expect(row.unitType, 'count');

      final queued = (await store.pendingSync(tenant)).single;
      expect(queued.rpc, 'table:products');
      expect(queued.op, 'table_crud');
      expect(queued.entity, 'products');
      expect(queued.localId, product.id);
      final params = jsonDecode(queued.params) as Map<String, dynamic>;
      expect(params['name'], 'منتج');
      expect(params['unit_type'], 'count');
      expect(params.containsKey('id'), isFalse,
          reason: 'the local id becomes the server id via the leg');
    });

    test('rolls back the mirror when the enqueue throws', () async {
      final poisoned = OfflineWriteCoordinator(
        _ThrowOnEnqueueStore(store),
        tenant,
      );
      await expectLater(
        poisoned.writeProduct(_draft),
        throwsA(isA<ValidationException>()),
      );
      expect(await store.products(tenant), isEmpty);
      expect(await store.pendingSync(tenant), isEmpty);
    });
  });

  group('updateProduct', () {
    test('preserves createdAt and enqueues a table_crud update', () async {
      await seedProduct();

      await writer.updateProduct(
        'p1',
        const ProductDraft(
          name: 'سلعة محدثة',
          unit: 'قطعة',
          unitType: ProductUnitType.count,
          salePrice: 22000,
          purchasePrice: 12000,
          qty: 5,
          reorderLevel: 2,
        ),
      );

      final row = (await store.products(tenant)).firstWhere((r) => r.id == 'p1');
      expect(row.synced, isFalse);
      expect(row.name, 'سلعة محدثة');
      expect(row.salePrice, 22000);
      expect(row.createdAt, DateTime(2026, 1, 1),
          reason: 'an update must never stamp a new creation date');

      final queued = (await store.pendingSync(tenant)).single;
      expect(queued.rpc, 'table:products');
      expect(queued.op, 'table_crud');
      expect(queued.localId, 'p1');
      expect(queued.dependsOn, isNull,
          reason: 'nothing pending on p1 when it is already on the server');
      final params = jsonDecode(queued.params) as Map<String, dynamic>;
      expect(params['id'], 'p1');
      expect((params['row'] as Map<String, dynamic>)['name'], 'سلعة محدثة');
    });

    test('dependsOn the pending create leg for the same product', () async {
      final created = await writer.writeProduct(_draft);
      await writer.updateProduct(
        created.id,
        const ProductDraft(
          name: 'منتج محدث',
          unit: 'قطعة',
          unitType: ProductUnitType.count,
          salePrice: 200,
          purchasePrice: 100,
          qty: 3,
          reorderLevel: 1,
        ),
      );

      final legs = await store.pendingSync(tenant);
      expect(legs, hasLength(2));
      final create = legs.firstWhere((l) => jsonDecode(l.params)['row'] == null);
      final update = legs.firstWhere((l) => jsonDecode(l.params)['row'] != null);
      expect(jsonDecode(update.dependsOn!), [create.id],
          reason: 'the update replays only after the create');
    });

    test('rolls back the mirror when the enqueue throws', () async {
      await seedProduct();

      final poisoned = OfflineWriteCoordinator(
        _ThrowOnEnqueueStore(store),
        tenant,
      );
      await expectLater(
        poisoned.updateProduct(
          'p1',
          const ProductDraft(
            name: 'لن ينجح',
            unit: 'قطعة',
            unitType: ProductUnitType.count,
            salePrice: 1,
            purchasePrice: 1,
            qty: 1,
            reorderLevel: 0,
          ),
        ),
        throwsA(isA<ValidationException>()),
      );
      final row = (await store.products(tenant)).single;
      expect(row.name, 'سلعة مباشرة');
      expect(row.synced, isTrue);
      expect(await store.pendingSync(tenant), isEmpty);
    });
  });

  group('deleteProduct', () {
    test('a missing product surfaces ValidationException', () async {
      await expectLater(
        writer.deleteProduct('ghost'),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.message,
            'message',
            'المنتج غير موجود محلياً',
          ),
        ),
      );
    });

    test('flips the kept row synced:false and enqueues a delete shape',
        () async {
      await seedProduct();
      await writer.deleteProduct('p1');

      final row = (await store.products(tenant)).single;
      expect(row.id, 'p1');
      expect(row.synced, isFalse,
          reason: 'the kept row can never be resurrected by a refresh');

      final queued = (await store.pendingSync(tenant)).single;
      expect(queued.rpc, 'table:products');
      expect(queued.op, 'table_crud');
      expect(queued.localId, 'p1');
      expect(queued.dependsOn, isNull);
      expect(jsonDecode(queued.params), {'id': 'p1'});
      expect(await store.pendingDeleteIds(tenant, 'products'), {'p1'});
    });

    test('is refused when a mirrored invoice line references the product',
        () async {
      await seedProduct();
      await store.upsertInvoiceItems([
        LocalInvoiceItemRow(
          id: 'inv-1:0000',
          tenantId: tenant,
          invoiceId: 'inv-1',
          productId: 'p1',
          productName: 'سلعة مباشرة',
          productUnit: 'قطعة',
          productUnitType: 'count',
          qty: 1,
          price: 100,
          total: 100,
        ),
      ]);

      await expectLater(
        writer.deleteProduct('p1'),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.message,
            'message',
            'لا يمكن حذف المنتج لأنه مرتبط بفواتير أو عمولات موجودة',
          ),
        ),
      );
      expect((await store.products(tenant)).single.synced, isTrue);
      expect(await store.pendingSync(tenant), isEmpty);
    });

    test('is refused when a mirrored commission due references the product',
        () async {
      await seedProduct();
      await store.upsertCommissionDue(
        LocalCommissionDueRow(
          id: 'due-1',
          tenantId: tenant,
          invoiceId: 'inv-1',
          productId: 'p1',
          supplierId: 's1',
          dueAmount: 500,
          status: 'pending',
        ),
      );

      await expectLater(
        writer.deleteProduct('p1'),
        throwsA(isA<ValidationException>()),
      );
      expect(await store.pendingSync(tenant), isEmpty);
    });

    test('allows the delete when the only reference is another tenant',
        () async {
      await seedProduct();
      await store.upsertInvoiceItems([
        LocalInvoiceItemRow(
          id: 'inv-9:0000',
          tenantId: 'tenant-b',
          invoiceId: 'inv-9',
          productId: 'p1',
          productName: null,
          productUnit: null,
          productUnitType: null,
          qty: 1,
          price: 1,
          total: 1,
        ),
      ]);

      await writer.deleteProduct('p1');
      expect(await store.pendingDeleteIds(tenant, 'products'), {'p1'});
    });

    test('dependsOn pending create/update legs for the same product', () async {
      final created = await writer.writeProduct(_draft);
      await writer.deleteProduct(created.id);

      final legs = await store.pendingSync(tenant);
      expect(legs, hasLength(2));
      final create = legs.firstWhere(
        (l) => !(jsonDecode(l.params) as Map).containsKey('id'),
      );
      final del = legs.firstWhere(
        (l) => (jsonDecode(l.params) as Map).containsKey('id'),
      );
      expect(jsonDecode(del.dependsOn!), [create.id]);
      expect(await store.pendingDeleteIds(tenant, 'products'), {created.id});
    });

    test('rolls back the mirror flip when the enqueue throws', () async {
      await seedProduct();

      final poisoned = OfflineWriteCoordinator(
        _ThrowOnEnqueueStore(store),
        tenant,
      );
      await expectLater(
        poisoned.deleteProduct('p1'),
        throwsA(isA<ValidationException>()),
      );
      expect((await store.products(tenant)).single.synced, isTrue,
          reason: 'the synced flip is rolled back with the failed leg');
      expect(await store.pendingSync(tenant), isEmpty);
    });
  });

  group('invoiceItemsReferenceProduct', () {
    test('is tenant-scoped and false when nothing references the product',
        () async {
      expect(await store.invoiceItemsReferenceProduct(tenant, 'p1'), isFalse);

      await store.upsertInvoiceItems([
        LocalInvoiceItemRow(
          id: 'inv-1:0000',
          tenantId: tenant,
          invoiceId: 'inv-1',
          productId: 'p1',
          productName: null,
          productUnit: null,
          productUnitType: null,
          qty: 1,
          price: 1,
          total: 1,
        ),
      ]);
      expect(await store.invoiceItemsReferenceProduct(tenant, 'p1'), isTrue);
      expect(await store.invoiceItemsReferenceProduct('tenant-b', 'p1'), isFalse);
    });
  });

}

/// Throws on the coordinator's final `enqueue` inside the write, after every
/// other statement in the transaction has already been staged.
class _ThrowOnEnqueueStore extends DelegatingLocalStore {
  _ThrowOnEnqueueStore(super.inner);

  @override
  Future<void> enqueue(SyncQueueRow row) =>
      throw StateError('queue write failed after the write was staged');
}
