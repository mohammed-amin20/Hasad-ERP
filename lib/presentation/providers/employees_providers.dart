import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/employees/supabase_employee_repository.dart';
import '../../data/supabase_client.dart';
import '../../domain/employees/employee.dart';
import '../../domain/employees/employee_draft.dart';
import '../../domain/employees/employee_repository.dart';

part 'employees_providers.g.dart';

/// Concrete employee repository wired to Supabase.
@riverpod
EmployeeRepository employeeRepository(Ref ref) =>
    SupabaseEmployeeRepository(ref.watch(supabaseClientProvider));

/// Current search term for the employee list (reactive).
@riverpod
class EmployeeSearch extends _$EmployeeSearch {
  @override
  String build() => '';

  void update(String term) => state = term;
}

/// Reactive list of employees, filtered by [EmployeeSearch].
@riverpod
class EmployeesList extends _$EmployeesList {
  @override
  Future<List<Employee>> build() async {
    final search = ref.watch(employeeSearchProvider);
    final repo = ref.watch(employeeRepositoryProvider);
    return repo.listAll(search: search.isEmpty ? null : search);
  }

  /// Create a new employee, then refresh the list.
  Future<Employee> create(EmployeeDraft draft) async {
    final repo = ref.read(employeeRepositoryProvider);
    final employee = await repo.create(draft);
    ref.invalidateSelf();
    return employee;
  }

  /// Update an existing employee, then refresh the list.
  Future<void> updateEmployee({
    required String id,
    required EmployeeDraft draft,
  }) async {
    final repo = ref.read(employeeRepositoryProvider);
    await repo.update(id: id, draft: draft);
    ref.invalidateSelf();
  }

  /// Delete an employee, then refresh the list.
  Future<void> delete(String id) async {
    final repo = ref.read(employeeRepositoryProvider);
    await repo.delete(id);
    ref.invalidateSelf();
  }
}