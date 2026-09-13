import '../../core/error/app_exception.dart';
import '../../domain/products/product.dart';
import '../../domain/products/product_draft.dart';
import '../../domain/products/product_repository.dart';
import 'local_database.dart';
import 'local_store.dart';
import 'offline_reads.dart';

/// [ProductRepository] that serves the live Supabase repository while online
/// (mirroring every read into the local store) and reads the mirror offline.
class OfflineProductRepository implements ProductRepository {
  OfflineProductRepository(this._inner, {required this.store, required this.tenantId});

  final ProductRepository _inner;
  final LocalStore? store;
  final String? tenantId;

  @override
  Future<List<Product>> listAll({String? search}) async {
    final term = search?.trim();
    final all = await cacheFirst(
      store: store,
      tenantId: tenantId,
      network: () => _inner.listAll(),
      mirror: _mirrorList,
      local: _readAll,
    );
    final filtered = (term == null || term.isEmpty)
        ? all
        : [
            for (final p in all)
              if (_matches(p.name, term) || _matches(p.barcode, term)) p,
          ];
    filtered.sort((a, b) => a.name.compareTo(b.name));
    return filtered;
  }

  @override
  Future<Product?> getById(String id) => cacheFirst(
        store: store,
        tenantId: tenantId,
        network: () => _inner.getById(id),
        mirror: (Product? product) async {
          if (product == null) return;
          await _mirrorList([product]);
        },
        local: () async {
          for (final r in await _readAll()) {
            if (r.id == id) return r;
          }
          return null;
        },
      );

  @override
  Future<Product> create(ProductDraft draft) async {
    final product = await _inner.create(draft);
    await _upsertLocal(product);
    return product;
  }

  @override
  Future<void> update({required String id, required ProductDraft draft}) =>
      _inner.update(id: id, draft: draft);

  @override
  Future<void> delete(String id) => _inner.delete(id);

  Future<void> _mirrorList(List<Product> products) async {
    final s = store;
    final t = tenantId;
    if (s == null || t == null) return;
    await s.mirrorProducts(t, [for (final p in products) _toRow(t, p)]);
  }

  Future<List<Product>> _readAll() async {
    final s = store;
    final t = tenantId;
    if (s == null || t == null) throw const NetworkException();
    return [for (final r in await s.products(t)) _fromRow(r)];
  }

  Future<void> _upsertLocal(Product product) async {
    final s = store;
    final t = tenantId;
    if (s == null || t == null) return;
    try {
      await s.upsertProduct(_toRow(t, product));
    } on Object {
      // best-effort local mirror
    }
  }

  static bool _matches(String? value, String term) {
    if (value == null) return false;
    final v = value.toLowerCase();
    final t = term.toLowerCase();
    return v.contains(t);
  }

  static LocalProductRow _toRow(String tenantId, Product p) => LocalProductRow(
        id: p.id,
        tenantId: tenantId,
        name: p.name,
        barcode: p.barcode,
        unit: p.unit,
        unitType: p.unitType.dbValue,
        salePrice: p.salePrice,
        purchasePrice: p.purchasePrice,
        qty: p.qty,
        reorderLevel: p.reorderLevel,
        supplierId: p.supplierId,
        commissionRate: p.commissionRate,
        createdAt: null,
      );

  static Product _fromRow(LocalProductRow r) => Product(
        id: r.id,
        name: r.name,
        barcode: r.barcode,
        unit: r.unit,
        unitType: ProductUnitType.fromDb(r.unitType),
        salePrice: r.salePrice,
        purchasePrice: r.purchasePrice,
        qty: r.qty,
        reorderLevel: r.reorderLevel,
        supplierId: r.supplierId,
        commissionRate: r.commissionRate,
      );
}