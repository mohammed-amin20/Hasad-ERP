import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/error/app_exception.dart';
import '../../domain/salaries/salary_computation.dart';
import '../../domain/salaries/salary_repository.dart';

/// [SalaryRepository] backed by the `get_employee_entitlement` /
/// `add_employee_movement` / `pay_salary` RPCs (each a single transaction,
/// idempotent via `p_request_id`).
class SupabaseSalaryRepository implements SalaryRepository {
  const SupabaseSalaryRepository(this._client);

  final SupabaseClient _client;

  /// The COMPLETE read model for one employee-month: the RPC's gross figures
  /// plus whether the month has actually been paid.
  ///
  /// The paid state is part of this contract rather than a second method because
  /// a caller that wants "what is this employee owed" and does not also get
  /// "have they had it" will render a pay button for a salary already paid — the
  /// exact defect the split would invite. Composing it here also means the
  /// offline wrapper has exactly one contract to combine with its local row.
  @override
  Future<EmployeeEntitlement> entitlement({
    required String employeeId,
    required DateTime month,
  }) async {
    try {
      final result = await _client.rpc(
        'get_employee_entitlement',
        params: {
          'p_employee_id': employeeId,
          'p_month': salaryMonthDate(month),
        },
      );
      final gross = EmployeeEntitlement.fromJson(result as Map<String, dynamic>);
      // `get_employee_entitlement` is arithmetic only, so it cannot say whether
      // the month was paid. This asks the existing RLS-covered `salaries` table
      // the narrowest question that answers it: is there a row for THIS employee
      // and THIS month? No new RPC, no migration.
      //
      // Narrow existence rather than `salaryHistory()`, which fetches every
      // salary row in the tenant — this runs on every entitlement read (the
      // salary screen, and again after every movement and payment) to answer a
      // one-row question.
      final paid = await _client
          .from('salaries')
          .select('id')
          .eq('employee_id', employeeId)
          .eq('month', salaryMonthDate(month))
          .limit(1);
      return gross.copyWith(isPaidForMonth: paid.isNotEmpty);
    } on Object catch (error) {
      throw mapErrorToAppException(error);
    }
  }

  @override
  Future<MovementResult> addMovement(MovementDraft draft) async {
    try {
      final result = await _client.rpc(
        'add_employee_movement',
        params: draft.toJson(),
      );
      return MovementResult.fromJson(result as Map<String, dynamic>);
    } on Object catch (error) {
      throw mapErrorToAppException(error);
    }
  }

  @override
  Future<SalaryResult> pay(SalaryDraft draft) async {
    try {
      final result = await _client.rpc('pay_salary', params: draft.toJson());
      return SalaryResult.fromJson(result as Map<String, dynamic>);
    } on Object catch (error) {
      throw mapErrorToAppException(error);
    }
  }

  @override
  Future<List<SalaryRecord>> salaryHistory() async {
    try {
      final rows = await _client
          .from('salaries')
          .select(
            'id, employee_id, month, base_salary, paid, date, created_at',
          );
      return [for (final r in rows) SalaryRecord.fromJson(r)];
    } on Object catch (error) {
      throw mapErrorToAppException(error);
    }
  }

  @override
  Future<EmployeeStatement> employeeStatement(
    EmployeeStatementRequest request,
  ) async {
    try {
      final employee = await _client
          .from('employees')
          .select('base_salary')
          .eq('id', request.employeeId)
          .single();
      final employeeBase = (employee['base_salary'] as num?)?.toInt() ?? 0;

      final salaryRows = await _client
          .from('salaries')
          .select('month, base_salary, paid')
          .eq('employee_id', request.employeeId)
          .order('month');

      final movementRows = await _client
          .from('employee_movements')
          .select('month, direction, amount')
          .eq('employee_id', request.employeeId)
          .order('month');

      return buildEmployeeStatement(
        employeeId: request.employeeId,
        employeeBase: employeeBase,
        from: request.from,
        to: request.to,
        salaryRows: [
          for (final r in salaryRows)
            EmployeeSalaryRow(
              month: DateTime.parse(r['month'] as String),
              base: (r['base_salary'] as num?)?.toInt() ?? 0,
              paid: (r['paid'] as num?)?.toInt() ?? 0,
            ),
        ],
        movementRows: [
          for (final r in movementRows)
            EmployeeMovementRow(
              month: DateTime.parse(r['month'] as String),
              isIn: r['direction'] == 'in',
              amount: (r['amount'] as num?)?.toInt() ?? 0,
            ),
        ],
      );
    } on Object catch (error) {
      throw mapErrorToAppException(error);
    }
  }
}
