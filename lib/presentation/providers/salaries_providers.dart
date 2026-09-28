import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/offline/local_store.dart';
import '../../data/offline/offline_salary_repository.dart';
import '../../data/offline/offline_write.dart';
import '../../data/salaries/supabase_salary_repository.dart';
import '../../data/supabase_client.dart';
import '../../domain/salaries/salary_repository.dart';
import 'accounts_providers.dart';
import 'auth_providers.dart';
import 'inventory_providers.dart';

part 'salaries_providers.g.dart';

/// Salary repository — offline reads (live-first with local fallbacks and
/// unsynced-local merges) and, when a local store exists, local-first writes
/// routed through [OfflineWriteCoordinator.addMovement] / [paySalary]. No
/// local store (web/unauthenticated) means nothing can be queued, so writes
/// fall back to the live RPCs — same shape as the sales/journals providers.
@riverpod
SalaryRepository salaryRepository(Ref ref) {
  final store = ref.watch(localStoreProvider).value;
  final tenantId = ref.watch(authStateProvider).value?.tenantId;
  if (store == null || tenantId == null) {
    return SupabaseSalaryRepository(ref.watch(supabaseClientProvider));
  }
  return OfflineSalaryRepository(
    SupabaseSalaryRepository(ref.watch(supabaseClientProvider)),
    store: store,
    tenantId: tenantId,
    coordinator: OfflineWriteCoordinator(
      store,
      tenantId,
      () => ref.read(accountRepositoryProvider).chart(),
    ),
  );
}

/// Entitlement preview for one employee+month, recomputed after any write.
@riverpod
class SalaryRun extends _$SalaryRun {
  @override
  Future<EmployeeEntitlement> build(String employeeId, DateTime month) async {
    final repo = ref.watch(salaryRepositoryProvider);
    return repo.entitlement(
      employeeId: employeeId,
      month: DateTime(month.year, month.month, 1),
    );
  }
}

/// Paid-salary rows for the tenant, refreshed after any salary write.
@riverpod
Future<List<SalaryRecord>> salaryHistory(Ref ref) async =>
    ref.watch(salaryRepositoryProvider).salaryHistory();

/// Per-month salary statement for one employee over a month range.
@riverpod
Future<EmployeeStatement> employeeStatement(
  Ref ref,
  EmployeeStatementRequest request,
) => ref.watch(salaryRepositoryProvider).employeeStatement(request);

/// Executes movement/salary actions, then refreshes the entitlement preview
/// and any inventory-dependent lists (a `product` deduction moves stock).
@riverpod
class SalaryActions extends _$SalaryActions {
  @override
  Object? build() => null;

  Future<MovementResult> movement(MovementDraft draft) async {
    final result = await ref.read(salaryRepositoryProvider).addMovement(draft);
    _refresh(draft.employeeId, draft.month);
    return result;
  }

  Future<SalaryResult> pay(SalaryDraft draft) async {
    final result = await ref.read(salaryRepositoryProvider).pay(draft);
    _refresh(draft.employeeId, draft.month);
    return result;
  }

  void _refresh(String employeeId, DateTime month) {
    ref.invalidate(salaryRunProvider(employeeId, month));
    ref.invalidate(salaryHistoryProvider);
    ref.invalidate(inventoryProductsProvider);
  }
}
