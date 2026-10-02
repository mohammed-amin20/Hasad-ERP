import '../../core/error/app_exception.dart';
import '../../domain/salaries/salary_computation.dart';
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
    if (c == null) {
      // No local store (web / unauthenticated): the live RPC, because nothing
      // can be queued for a later replay.
      return _inner.addMovement(draft);
    }
    return c.addMovement(draft);
  }

  @override
  Future<SalaryResult> pay(SalaryDraft draft) async {
    final c = coordinator;
    if (c != null) return c.paySalary(draft);
    return _inner.pay(draft);
  }

  /// The live entitlement, with this device's own salary rows layered on top.
  ///
  /// `_inner.entitlement` already answers "has the SERVER paid this month" —
  /// it checks the `salaries` table — so the composition is a single `||`
  /// against the local row. Both halves are needed, and they cover disjoint
  /// windows: before the drain the server has not seen the payment and only the
  /// local row knows; after it, only the server does on a device whose mirror
  /// was cleared or never written.
  @override
  Future<EmployeeEntitlement> entitlement({
    required String employeeId,
    required DateTime month,
  }) async {
    final target = salaryMonthOf(month);
    try {
      final live = await _inner.entitlement(
        employeeId: employeeId,
        month: target,
      );
      // Checked even though the server answered: a queued payment has not
      // reached the server yet, so both the RPC's arithmetic and the server's
      // salaries table still describe the month as UNPAID. Without this the
      // screen re-enables the pay button in exactly the window between the
      // offline write and the drain.
      final localPaid = await _hasLocalSalary(employeeId, target);
      return live.copyWith(
        isPaidForMonth: live.isPaidForMonth || localPaid,
      );
    } on NetworkException {
      // Offline: the mirror is the only source, and `_localEntitlement` already
      // reads the salary rows the figures are computed from — so the paid state
      // costs no extra query and cannot come from a different snapshot than the
      // numbers shown beside it.
      return _localEntitlement(employeeId, target);
    }
  }

  /// True when this tenant's mirror holds a salary row for [employeeId] +
  /// [month].
  ///
  /// ANY row counts, synced or not. A drained row stays in the mirror — the
  /// replay marks it synced rather than deleting it — and a synced row is still
  /// the only evidence that a month was paid on a device that has been offline
  /// since. Reading `synced == false` only would make a paid month read as
  /// unpaid again the moment the device lost connectivity, which is the same
  /// defect in a smaller window.
  ///
  /// The key is [salaryMonthKey] — the same function the write guard's duplicate
  /// check uses — so the read and the write cannot disagree about which month a
  /// row belongs to.
  Future<bool> _hasLocalSalary(String employeeId, DateTime month) async {
    final s = store;
    final t = tenantId;
    if (s == null || t == null) return false;
    final key = salaryMonthKey(month);
    for (final row in await s.salaries(t, employeeId: employeeId)) {
      if (row.month == key) return true;
    }
    return false;
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
    final target = salaryMonthOf(month);
    final salaryRows = await s.salaries(t, employeeId: employeeId);
    final targetKey = salaryMonthKey(target);

    // Shared with `paySalary` on purpose: the preview shown before a payment
    // and the payment that gets queued must not disagree.
    final computation = computeSalaryComputation(
      month: target,
      baseSalary: employee.baseSalary,
      salaryRows: [
        for (final row in salaryRows)
          SalaryPeriodRow(month: _parseMonth(row.month), paid: row.paid),
      ],
      movements: [
        for (final mv in await s.employeeMovements(t, employeeId: employeeId))
          if (mv.month != null)
            SalaryMovementInput(
              month: _parseMonth(mv.month!),
              direction: mv.direction,
              amount: mv.amount,
            ),
      ],
    );
    return EmployeeEntitlement(
      employeeId: employeeId,
      month: target,
      baseSalary: computation.baseSalary,
      arrears: computation.arrears,
      entitlements: computation.entitlements,
      deductions: computation.deductions,
      netDue: computation.netDue,
      // From the SAME rows the figures above came from. A second lookup could
      // read a different snapshot and render "paid, 0 payable" next to figures
      // that were computed before the payment landed.
      isPaidForMonth: salaryRows.any((row) => row.month == targetKey),
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