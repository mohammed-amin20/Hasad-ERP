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
}