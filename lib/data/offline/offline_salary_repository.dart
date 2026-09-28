import '../../core/error/app_exception.dart';
import '../../domain/salaries/salary_repository.dart';
import 'local_database.dart';
import 'local_store.dart';
import 'offline_write.dart';

/// [SalaryRepository] with a local-first write path and offline read
/// fallbacks, mirroring the journal/payments slices.
///
/// * Writes ([addMovement]/[pay]) route through
///   [OfflineWriteCoordinator.addMovement]/[OfflineWriteCoordinator.paySalary]:
///   validate locally, persist the mirror + queue leg in one transaction, and
///   return a `pending` result immediately.
/// * Reads stay live-first and fall back to the local mirrors **only** on
///   [NetworkException]. Unsynced local salary/movement rows are merged into
///   the served lists (and survive restarts, because they live in drift), so
///   an offline-created movement or salary shows up before it drains.
///
/// When the Drift store is unavailable there is nothing to read or queue
/// from, so `salaries_providers.dart` hands back the live Supabase repository
/// instead of constructing this class at all.
class OfflineSalaryRepository implements SalaryRepository {
  OfflineSalaryRepository(
    this._inner, {
    required this.store,
    required this.tenantId,
    this.coordinator,
  });

  final SalaryRepository _inner;
  final LocalStore? store;
  final String? tenantId;

  /// Local-first write path; when null (no local store — web/unauthenticated)
  /// [addMovement]/[pay] fall through to [_inner]'s live RPCs.
  final OfflineWriteCoordinator? coordinator;

  @override
  Future<MovementResult> addMovement(MovementDraft draft) async {
    final c = coordinator;
    if (c != null) return c.addMovement(draft);
    return _inner.addMovement(draft);
  }

  @override
  Future<SalaryResult> pay(SalaryDraft draft) async {
    final c = coordinator;
    if (c != null) return c.paySalary(draft);
    return _inner.pay(draft);
  }

  @override
  Future<EmployeeEntitlement> entitlement({
    required String employeeId,
    required DateTime month,
  }) async {
    try {
      return await _inner.entitlement(employeeId: employeeId, month: month);
    } on NetworkException {
      return _localEntitlement(employeeId, month);
    }
  }

  @override
  Future<List<SalaryRecord>> salaryHistory() async {
    final List<SalaryRecord> base;
    try {
      base = await _inner.salaryHistory();
    } on NetworkException {
      final local = await _localSalaryRecords();
      if (local.isNotEmpty) return local;
      rethrow;
    }
    final local = await _localSalaryRecords();
    if (local.isEmpty) return base;
    final result = [...base, ...local];
    result.sort((a, b) => b.month.compareTo(a.month));
    return result;
  }

  @override
  Future<EmployeeStatement> employeeStatement(
    EmployeeStatementRequest request,
  ) async {
    try {
      return await _inner.employeeStatement(request);
    } on NetworkException {
      return _localStatement(request);
    }
  }

  // ---------------------------------------------------------------------------
  // local fallbacks (mirror `get_employee_entitlement` + `buildEmployeeStatement
  // against the local mirrors so an offline user still sees their data).
  // ---------------------------------------------------------------------------

  Future<EmployeeEntitlement> _localEntitlement(
    String employeeId,
    DateTime month,
  ) async {
    final employee = await _employeeRow(employeeId);
    final s = store;
    final t = tenantId;
    if (s == null || t == null) throw const NetworkException();
    final target = firstOfMonth(month);

    var arrears = 0;
    var entitlements = 0;
    var deductions = 0;
    for (final row in await s.salaries(t, employeeId: employeeId)) {
      final m = _parseMonth(row.month);
      final diff = employee.baseSalary - row.paid;
      if (m.isBefore(target) && diff > 0) arrears += diff;
    }
    for (final mv in await s.employeeMovements(t, employeeId: employeeId)) {
      final m = mv.month == null ? null : _parseMonth(mv.month!);
      if (m != target) continue;
      if (mv.direction == 'in') {
        entitlements += mv.amount;
      } else {
        deductions += mv.amount;
      }
    }
    return EmployeeEntitlement(
      employeeId: employeeId,
      month: target,
      baseSalary: employee.baseSalary,
      arrears: arrears,
      entitlements: entitlements,
      deductions: deductions,
      netDue: employee.baseSalary + arrears + entitlements - deductions,
    );
  }

  Future<EmployeeStatement> _localStatement(
    EmployeeStatementRequest request,
  ) async {
    final employee = await _employeeRow(request.employeeId);
    final s = store;
    final t = tenantId;
    if (s == null || t == null) throw const NetworkException();
    return buildEmployeeStatement(
      employeeId: request.employeeId,
      employeeBase: employee.baseSalary,
      from: request.from,
      to: request.to,
      salaryRows: [
        for (final row in await s.salaries(t, employeeId: request.employeeId))
          EmployeeSalaryRow(
            month: _parseMonth(row.month),
            base: employee.baseSalary,
            paid: row.paid,
          ),
      ],
      movementRows: [
        for (final mv
            in await s.employeeMovements(t, employeeId: request.employeeId))
          if (mv.month != null)
            EmployeeMovementRow(
              month: _parseMonth(mv.month!),
              isIn: mv.direction == 'in',
              amount: mv.amount,
            ),
      ],
    );
  }

  /// Unsynced locally-created salary rows as server-shaped [SalaryRecord]s
  /// (base salary from the employee mirror, date from the local row's
  /// createdAt — the mirror has no base_salary/date columns).
  Future<List<SalaryRecord>> _localSalaryRecords() async {
    final s = store;
    final t = tenantId;
    if (s == null || t == null) return const [];
    final employees = await s.employees(t);
    final baseOf = {for (final e in employees) e.id: e.baseSalary};
    final rows = await s.salaries(t);
    return [
      for (final row in rows)
        if (!row.synced)
          SalaryRecord(
            employeeId: row.employeeId,
            month: _parseMonth(row.month),
            baseSalary: baseOf[row.employeeId] ?? 0,
            paid: row.paid,
            date: row.createdAt,
          ),
    ];
  }

  Future<LocalEmployeeRow> _employeeRow(String id) async {
    final s = store;
    final t = tenantId;
    if (s == null || t == null) throw const NetworkException();
    for (final r in await s.employees(t)) {
      if (r.id == id) return r;
    }
    throw ValidationException('الموظف غير موجود محلياً');
  }

  static DateTime _parseMonth(String yyyyMm) {
    final parts = yyyyMm.split('-');
    return DateTime(int.parse(parts[0]), int.parse(parts[1]), 1);
  }
}