import '../../core/error/app_exception.dart';
import '../../domain/employees/employee.dart';
import '../../domain/employees/employee_draft.dart';
import '../../domain/employees/employee_repository.dart';
import 'local_database.dart';
import 'local_store.dart';
import 'offline_reads.dart';
import 'offline_write.dart';

/// [EmployeeRepository] that serves the live Supabase repository while online
/// (mirroring every read into the local store) and reads the mirror offline.
///
/// Writes route through [coordinator] when one is wired (local-first: mirror +
/// queued `table_crud` leg, so every write is pending until the flusher drains
/// it) and fall back to the inner repository otherwise.
class OfflineEmployeeRepository implements EmployeeRepository {
  OfflineEmployeeRepository(
    this._inner, {
    required this.store,
    required this.tenantId,
    this.coordinator,
  });

  final EmployeeRepository _inner;
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
  Future<List<Employee>> listAll({String? search}) async {
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
            for (final e in all)
              if (_matches(e.name, term) || _matches(e.phone, term)) e,
          ];
    filtered.sort((a, b) => a.name.compareTo(b.name));
    return filtered;
  }

  @override
  Future<Employee?> getById(String id) => cacheFirst(
        store: store,
        tenantId: tenantId,
        network: () => _inner.getById(id),
        mirror: (Employee? employee) async {
          if (employee == null) return;
          await _mirrorList([employee]);
        },
        local: () async {
          for (final r in await _readAll()) {
            if (r.id == id) return r;
          }
          return null;
        },
      );

  @override
  Future<Employee> create(EmployeeDraft draft) async {
    final c = coordinator;
    if (c != null) return c.writeEmployee(draft);
    final employee = await _inner.create(draft);
    await _upsertLocal(employee);
    return employee;
  }

  @override
  Future<void> update({required String id, required EmployeeDraft draft}) async {
    final c = coordinator;
    if (c != null) return c.updateEmployee(id, draft);
    return _inner.update(id: id, draft: draft);
  }

  @override
  Future<void> delete(String id) async {
    final c = coordinator;
    if (c != null) return c.deleteEmployee(id);
    return _inner.delete(id);
  }

  Future<void> _mirrorList(List<Employee> employees) async {
    final s = store;
    final t = tenantId;
    if (s == null || t == null) return;
    await s.mirrorEmployees(t, [for (final e in employees) _toRow(t, e)]);
  }

  Future<List<Employee>> _readAll() async {
    final s = store;
    final t = tenantId;
    if (s == null || t == null) throw const NetworkException();
    // Pending deletes are hidden from reads: the delete is queued but not on
    // the server yet. When the delete parks `failed` the id drops out and the
    // record becomes visible again.
    final hidden = await s.pendingDeleteIds(t, 'employees');
    return [
      for (final r in await s.employees(t))
        if (!hidden.contains(r.id)) _fromRow(r),
    ];
  }

  Future<void> _upsertLocal(Employee employee) async {
    final s = store;
    final t = tenantId;
    if (s == null || t == null) return;
    try {
      await s.upsertEmployee(_toRow(t, employee));
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

  static LocalEmployeeRow _toRow(String tenantId, Employee e) =>
      LocalEmployeeRow(
        id: e.id,
        tenantId: tenantId,
        name: e.name,
        jobTitle: e.jobTitle,
        phone: e.phone,
        baseSalary: e.baseSalary,
        createdAt: e.createdAt,
        synced: true,
      );

  static Employee _fromRow(LocalEmployeeRow r) => Employee(
        id: r.id,
        name: r.name,
        jobTitle: r.jobTitle,
        phone: r.phone,
        baseSalary: r.baseSalary,
        createdAt: r.createdAt,
      );
}