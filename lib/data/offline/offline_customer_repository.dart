import '../../core/error/app_exception.dart';
import '../../domain/customers/customer.dart';
import '../../domain/customers/customer_draft.dart';
import '../../domain/customers/customer_repository.dart';
import 'local_database.dart';
import 'local_store.dart';
import 'offline_reads.dart';

/// [CustomerRepository] that serves the live Supabase repository while online
/// (mirroring every read into the local store) and reads the mirror offline.
///
/// Writes always go to Supabase; offline-driven writes are Slice C.
class OfflineCustomerRepository implements CustomerRepository {
  OfflineCustomerRepository(this._inner, {required this.store, required this.tenantId});

  final CustomerRepository _inner;
  final LocalStore? store;
  final String? tenantId;

  @override
  Future<List<Customer>> listAll({String? search}) async {
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
            for (final c in all)
              if (_matches(c.name, term) || _matches(c.phone, term)) c,
          ];
    filtered.sort((a, b) => a.name.compareTo(b.name));
    return filtered;
  }

  @override
  Future<Customer?> getById(String id) => cacheFirst(
        store: store,
        tenantId: tenantId,
        network: () => _inner.getById(id),
        mirror: (Customer? customer) async {
          if (customer == null) return;
          await _mirrorList([customer]);
        },
        local: () async {
          for (final r in await _readAll()) {
            if (r.id == id) return r;
          }
          return null;
        },
      );

  @override
  Future<Customer> create(CustomerDraft draft) async {
    final customer = await _inner.create(draft);
    await _upsertLocal(customer);
    return customer;
  }

  @override
  Future<void> update({required String id, required CustomerDraft draft}) =>
      _inner.update(id: id, draft: draft);

  @override
  Future<void> delete(String id) => _inner.delete(id);

  Future<void> _mirrorList(List<Customer> customers) async {
    final s = store;
    final t = tenantId;
    if (s == null || t == null) return;
    await s.mirrorCustomers(t, [for (final c in customers) _toRow(t, c)]);
  }

  Future<List<Customer>> _readAll() async {
    final s = store;
    final t = tenantId;
    if (s == null || t == null) throw const NetworkException();
    return [for (final r in await s.customers(t)) _fromRow(r)];
  }

  Future<void> _upsertLocal(Customer customer) async {
    final s = store;
    final t = tenantId;
    if (s == null || t == null) return;
    try {
      await s.upsertCustomer(_toRow(t, customer));
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

  static LocalCustomerRow _toRow(String tenantId, Customer c) =>
      LocalCustomerRow(
        id: c.id,
        tenantId: tenantId,
        name: c.name,
        phone: c.phone,
        notes: c.notes,
        createdAt: c.createdAt,
        synced: true,
      );

  static Customer _fromRow(LocalCustomerRow r) => Customer(
        id: r.id,
        name: r.name,
        phone: r.phone,
        notes: r.notes,
        createdAt: r.createdAt,
      );
}