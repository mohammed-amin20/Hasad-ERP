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

/// Records every call and plays the "remote down" NetworkException the offline
/// wrapper uses to decide when to read the mirror.
class _FakeInnerRepository implements ProductRepository {
  final List<String> calls = <String>[];
  bool offline = false;
  List<Product> products = <Product>[];
  int _next = 0;

  @override
  Future<List<Product>> listAll({String? search}) async {
    calls.add('listAll');
    if (offline) throw const NetworkException();
    return products;
  }

  @override
  Future<Product?> getById(String id) async {
    calls.add('getById:$id');
    if (offline) throw const NetworkException();
    for (final p in products) {
      if (p.id == id) return p;
    }
    return null;
  }

  @override
  Future<Product> create(ProductDraft draft) async {
    calls.add('create');
    if (offline) throw const NetworkException();
    _next += 1;
    final product = Product(
      id: 'server-$_next',
      name: draft.name,
      barcode: draft.barcode,
      unit: draft.unit,
      unitType: draft.unitType,
      salePrice: draft.salePrice,
      purchasePrice: draft.purchasePrice,
      qty: draft.qty,
      reorderLevel: draft.reorderLevel,
      supplierId: draft.supplierId,
      commissionRate: draft.commissionRate,
    );
    products.add(product);
    return product;
  }

  @override
  Future<void> update({required String id, required ProductDraft draft}) async {
    calls.add('update:$id');
    if (offline) throw const NetworkException();
  }

  @override
  Future<void> delete(String id) async {
    calls.add('delete:$id');
    if (offline) throw const NetworkException();
  }
}

const _draft = ProductDraft(
  name: 'منتج',
  barcode: '123',
  unit: 'قطعة',
  unitType: ProductUnitType.count,
  salePrice: 150,
  purchasePrice: 100,
  qty: 10,
  reorderLevel: 2,
);

void main() {
  const tenant = 'tenant-a';
  late AppDatabase db;
  late DriftLocalStore store;
  late _FakeInnerRepository inner;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = DriftLocalStore(db);
    inner = _FakeInnerRepository();
  });

  tearDown(() => db.close());

  test('writes fall back to the inner repo when no coordinator is wired',
      () async {
    final repo = OfflineProductRepository(
      inner,
      store: store,
      tenantId: tenant,
    );
    expect(repo.writesAreLocalFirst, isFalse);

    final created = await repo.create(_draft);
    expect(created.id, 'server-1');
    await repo.update(id: 'server-1', draft: _draft);
    await repo.delete('server-1');

    expect(inner.calls, ['create', 'update:server-1', 'delete:server-1']);
    expect(await store.pendingCount(tenant), 0);
  });

  test('with a coordinator, writes are local-first: mirrored and queued',
      () async {
    final coordinator = OfflineWriteCoordinator(store, tenant);
    final repo = OfflineProductRepository(
      inner,
      store: store,
      tenantId: tenant,
      coordinator: coordinator,
    );
    expect(repo.writesAreLocalFirst, isTrue);

    final created = await repo.create(_draft);
    expect(inner.calls, isEmpty,
        reason: 'the coordinator owns the write, not the inner repo');
    expect(created.id, isNotEmpty);
    expect(created.name, 'منتج');

    final row = (await store.products(tenant)).single;
    expect(row.id, created.id);
    expect(row.synced, isFalse);
    expect(row.qty, 10);
    expect(row.unitType, 'count');
    expect((await store.pendingSync(tenant)).single.localId, created.id);

    await repo.update(id: created.id, draft: _draft);
    expect(await store.pendingCount(tenant), 2);

    await repo.delete(created.id);
    expect(await store.pendingDeleteIds(tenant, 'products'), {created.id});
    expect(await store.pendingCount(tenant), 3);
  });

  test('listAll serves the mirror offline and hides pending deletes', () async {
    final repo = OfflineProductRepository(
      inner,
      store: store,
      tenantId: tenant,
      coordinator: OfflineWriteCoordinator(store, tenant),
    );
    inner.offline = true;

    final kept = await repo.create(_draft);
    final deleted =
        await repo.create(const ProductDraft(
        name: 'منتج ب',
        unit: 'قطعة',
        unitType: ProductUnitType.count,
        salePrice: 50,
        purchasePrice: 40,
        qty: 1,
        reorderLevel: 0,
      ));

    await repo.delete(deleted.id);
    final hidden = await repo.listAll();
    expect(hidden, hasLength(1));
    expect(hidden.single.id, kept.id);

    // A FAILED delete relaxes the filter: the product reappears locally even
    // though the server copy still exists.
    final legs = await store.pendingSync(tenant);
    await store.markFailed(legs.last.id, 'server refused the delete');
    expect(await store.pendingDeleteIds(tenant, 'products'), isEmpty);
    final visible = await repo.listAll();
    expect(visible.map((p) => p.id), containsAll([kept.id, deleted.id]));
  });

  test('delete is refused when a mirrored invoice line references the product',
      () async {
    final repo = OfflineProductRepository(
      inner,
      store: store,
      tenantId: tenant,
      coordinator: OfflineWriteCoordinator(store, tenant),
    );
    final product = await repo.create(_draft);
    await store.upsertInvoiceItems([
      LocalInvoiceItemRow(
        id: '${product.id}:0000',
        tenantId: tenant,
        invoiceId: 'inv-1',
        productId: product.id,
        productName: product.name,
        productUnit: product.unit,
        productUnitType: 'count',
        qty: 1,
        price: 100,
        total: 100,
      ),
    ]);

    await expectLater(
      repo.delete(product.id),
      throwsA(
        isA<ValidationException>().having(
          (e) => e.message,
          'message',
          contains('مرتبط بفواتير أو عمولات'),
        ),
      ),
    );
    expect(await store.pendingDeleteIds(tenant, 'products'), isEmpty,
        reason: 'a blocked delete enqueues nothing');
  });

  test('delete is refused when a mirrored commission due references the product',
      () async {
    final repo = OfflineProductRepository(
      inner,
      store: store,
      tenantId: tenant,
      coordinator: OfflineWriteCoordinator(store, tenant),
    );
    final product = await repo.create(_draft);
    await store.upsertCommissionDue(
      LocalCommissionDueRow(
        id: 'due-1',
        tenantId: tenant,
        invoiceId: 'inv-1',
        productId: product.id,
        supplierId: 'sup-1',
        dueAmount: 500,
        status: 'pending',
      ),
    );

    await expectLater(
      repo.delete(product.id),
      throwsA(isA<ValidationException>()),
    );
    expect(await store.pendingDeleteIds(tenant, 'products'), isEmpty);
  });

  test('listAll mirrors the server list when online', () async {
    inner.products = [
      const Product(
        id: 'p1',
        name: 'منتج خادم',
        unit: 'قطعة',
        unitType: ProductUnitType.count,
        salePrice: 10,
        purchasePrice: 5,
        qty: 3,
        reorderLevel: 1,
      ),
    ];
    final repo = OfflineProductRepository(
      inner,
      store: store,
      tenantId: tenant,
    );

    final all = await repo.listAll();
    expect(all, hasLength(1));
    expect((await store.products(tenant)).single.synced, isTrue);
  });

  test('an empty mirror with the remote down rethrows, never silent []',
      () async {
    inner.offline = true;
    final repo = OfflineProductRepository(
      inner,
      store: store,
      tenantId: tenant,
    );
    await expectLater(repo.listAll(), throwsA(isA<NetworkException>()));
  });

  test('an offline-managed product survives a process restart', () async {
    final dir = await Directory.systemTemp.createTemp('product_repo_offline');
    final file = File('${dir.path}/test.db');

    final db1 = AppDatabase(NativeDatabase(file));
    final s1 = DriftLocalStore(db1);
    final repo1 = OfflineProductRepository(
      _FakeInnerRepository(),
      store: s1,
      tenantId: tenant,
      coordinator: OfflineWriteCoordinator(s1, tenant),
    );
    final created = await repo1.create(_draft);
    await db1.close();

    final db2 = AppDatabase(NativeDatabase(file));
    final s2 = DriftLocalStore(db2);
    try {
      final repo2 = OfflineProductRepository(
        _FakeInnerRepository(),
        store: s2,
        tenantId: tenant,
        coordinator: OfflineWriteCoordinator(s2, tenant),
      );
      final all = await repo2.listAll();
      expect(all, hasLength(1));
      expect(all.single.id, created.id);
      expect(all.single.name, 'منتج');
    } finally {
      await db2.close();
    }
  });
}
