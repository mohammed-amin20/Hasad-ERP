import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/error/app_exception.dart';
import '../../domain/employees/employee.dart';
import '../../domain/employees/employee_draft.dart';
import '../../domain/employees/employee_repository.dart';

/// [EmployeeRepository] backed by Supabase + RLS (migration `0016`).
class SupabaseEmployeeRepository implements EmployeeRepository {
  const SupabaseEmployeeRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Employee>> listAll({String? search}) async {
    try {
      var query = _client
          .from('employees')
          .select('id, name, job_title, phone, base_salary, created_at');

      if (search != null && search.trim().isNotEmpty) {
        final term = search.trim();
        query = query.or('name.ilike.%$term%,phone.ilike.%$term%');
      }

      final rows = await query.order('name');
      return rows.map(Employee.fromJson).toList();
    } on Object catch (error) {
      throw mapErrorToAppException(error);
    }
  }

  @override
  Future<Employee?> getById(String id) async {
    try {
      final row = await _client
          .from('employees')
          .select('id, name, job_title, phone, base_salary, created_at')
          .eq('id', id)
          .maybeSingle();

      if (row == null) return null;
      return Employee.fromJson(row);
    } on Object catch (error) {
      throw mapErrorToAppException(error);
    }
  }

  @override
  Future<Employee> create(EmployeeDraft draft) async {
    try {
      final rows = await _client
          .from('employees')
          .insert(draft.toJson())
          .select('id, name, job_title, phone, base_salary, created_at')
          .single();
      return Employee.fromJson(rows);
    } on Object catch (error) {
      throw mapErrorToAppException(error);
    }
  }

  @override
  Future<void> update({
    required String id,
    required EmployeeDraft draft,
  }) async {
    try {
      await _client.from('employees').update(draft.toJson()).eq('id', id);
    } on Object catch (error) {
      throw mapErrorToAppException(error);
    }
  }

  @override
  Future<void> delete(String id) async {
    try {
      await _client.from('employees').delete().eq('id', id);
    } on Object catch (error) {
      throw mapErrorToAppException(error);
    }
  }
}
