import '../../core/error/app_exception.dart';
import '../../domain/customers/customer.dart';
import '../../domain/customers/customer_draft.dart';
import '../../domain/customers/customer_repository.dart';
import 'local_database.dart';
import 'local_store.dart';
import 'offline_reads.dart';
import 'offline_write.dart';

/// [CustomerRepository] that serves the live Supabase repository while online
/// (mirroring every read into the local store) and reads the mirror offline.
///
/// Writes route through [coordinator] when one is wired (local-first:
/// mirror + queue, so every write is pending until the flusher drains it) and
/// fall back to the inner repository otherwise.
class OfflineCustomerRepository implements CustomerRepository {
  OfflineCustomerRepository(
    this._inner, {
    required this.store,
    required this.tenantId,
    this.coordinator,
  });

  final CustomerRepository _inner;
  final LocalStore? store;
  final String? tenantId;

  /// When present, create/update/delete are local-first ([OfflineWriteCoordinator]);
  /// when null they go to Supabase.
  final OfflineWriteCoordinator? coordinator;

  /// True when writes are local-first: a coordinator is wired, so every write
  /// is mirrored + queued — and therefore pending until [SyncFlusher] drains
  /// it. The UI reads this to show offline pending messages instead of online
  /// confirmations.
  bool get writesAreLocalFirst => coordinator != null;

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
    final c = coordinator;
    if (c != null) return c.writeCustomer(draft);
    final customer = await _inner.create(draft);
    await _upsertLocal(customer);
    return customer;
  }

  @override
  Future<void> update({required String id, required CustomerDraft draft}) async {
    final c = coordinator;
    if (c != null) return c.updateCustomer(id, draft);
    return _inner.update(id: id, draft: draft);
  }

  @override
  Future<void> delete(String id) async {
    final c = coordinator;
    if (c != null) return c.deleteCustomer(id);
    return _inner.delete(id);
  }

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
    // Pending deletes are hidden from reads: the delete is queued but not on
    // the server yet. When the delete parks `failed` the id drops out and the
    // record becomes visible again.
    final hidden = await s.pendingDeleteIds(t, 'customers');
    return [
      for (final r in await s.customers(t))
        if (!hidden.contains(r.id)) _fromRow(r),
    ];
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