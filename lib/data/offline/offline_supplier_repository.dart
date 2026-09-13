import '../../core/error/app_exception.dart';
import '../../domain/suppliers/supplier.dart';
import '../../domain/suppliers/supplier_draft.dart';
import '../../domain/suppliers/supplier_repository.dart';
import 'local_database.dart';
import 'local_store.dart';
import 'offline_reads.dart';

/// [SupplierRepository] that serves the live Supabase repository while online
/// (mirroring every read into the local store) and reads the mirror offline.
class OfflineSupplierRepository implements SupplierRepository {
  OfflineSupplierRepository(this._inner, {required this.store, required this.tenantId});

  final SupplierRepository _inner;
  final LocalStore? store;
  final String? tenantId;

  @override
  Future<List<Supplier>> listAll({String? search}) async {
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
            for (final s in all)
              if (_matches(s.name, term) || _matches(s.phone, term)) s,
          ];
    filtered.sort((a, b) => a.name.compareTo(b.name));
    return filtered;
  }

  @override
  Future<Supplier?> getById(String id) => cacheFirst(
        store: store,
        tenantId: tenantId,
        network: () => _inner.getById(id),
        mirror: (Supplier? supplier) async {
          if (supplier == null) return;
          await _mirrorList([supplier]);
        },
        local: () async {
          for (final r in await _readAll()) {
            if (r.id == id) return r;
          }
          return null;
        },
      );

  @override
  Future<Supplier> create(SupplierDraft draft) async {
    final supplier = await _inner.create(draft);
    await _upsertLocal(supplier);
    return supplier;
  }

  @override
  Future<void> update({required String id, required SupplierDraft draft}) =>
      _inner.update(id: id, draft: draft);

  @override
  Future<void> delete(String id) => _inner.delete(id);

  Future<void> _mirrorList(List<Supplier> suppliers) async {
    final s = store;
    final t = tenantId;
    if (s == null || t == null) return;
    await s.mirrorSuppliers(t, [for (final x in suppliers) _toRow(t, x)]);
  }

  Future<List<Supplier>> _readAll() async {
    final s = store;
    final t = tenantId;
    if (s == null || t == null) throw const NetworkException();
    return [for (final r in await s.suppliers(t)) _fromRow(r)];
  }

  Future<void> _upsertLocal(Supplier supplier) async {
    final s = store;
    final t = tenantId;
    if (s == null || t == null) return;
    try {
      await s.upsertSupplier(_toRow(t, supplier));
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

  static LocalSupplierRow _toRow(String tenantId, Supplier s) =>
      LocalSupplierRow(
        id: s.id,
        tenantId: tenantId,
        name: s.name,
        phone: s.phone,
        notes: s.notes,
        dealType: s.dealType.dbValue,
        commissionRate: s.commissionRate,
        createdAt: s.createdAt,
        synced: true,
      );

  static Supplier _fromRow(LocalSupplierRow r) => Supplier(
        id: r.id,
        name: r.name,
        phone: r.phone,
        notes: r.notes,
        dealType: SupplierDealType.fromDb(r.dealType),
        commissionRate: r.commissionRate,
        createdAt: r.createdAt,
      );
}