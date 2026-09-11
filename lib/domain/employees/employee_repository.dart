import 'employee.dart';
import 'employee_draft.dart';

/// Abstract interface for employee persistence.
///
/// Concrete implementations live in `data/` — the UI never imports
/// the Supabase client directly.
abstract interface class EmployeeRepository {
  Future<List<Employee>> listAll({String? search});
  Future<Employee?> getById(String id);
  Future<Employee> create(EmployeeDraft draft);
  Future<void> update({required String id, required EmployeeDraft draft});
  Future<void> delete(String id);
}
