import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/error/app_exception.dart';
import '../../domain/salaries/salary_repository.dart';

/// [SalaryRepository] backed by the `get_employee_entitlement` /
/// `add_employee_movement` / `pay_salary` RPCs (each a single transaction,
/// idempotent via `p_request_id`).
class SupabaseSalaryRepository implements SalaryRepository {
  const SupabaseSalaryRepository(this._client);

  final SupabaseClient _client;

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
          'p_month':
              '${month.year.toString().padLeft(4, '0')}-${month.month.toString().padLeft(2, '0')}-01',
        },
      );
      return EmployeeEntitlement.fromJson(result as Map<String, dynamic>);
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
      final result = await _client.rpc(
        'pay_salary',
        params: draft.toJson(),
      );
      return SalaryResult.fromJson(result as Map<String, dynamic>);
    } on Object catch (error) {
      throw mapErrorToAppException(error);
    }
  }

  @override
  Future<List<SalaryRecord>> salaryHistory() async {
    try {
      final rows = await _client.from('salaries').select(
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