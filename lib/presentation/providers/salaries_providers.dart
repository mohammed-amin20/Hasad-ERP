import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/error/app_exception.dart';
import '../../data/offline/local_store.dart';
import '../../data/offline/offline_salary_repository.dart';
import '../../data/offline/offline_write.dart';
import '../../data/salaries/supabase_salary_repository.dart';
import '../../data/supabase_client.dart';
import '../../domain/salaries/salary_repository.dart';
import 'accounts_providers.dart';
import 'auth_providers.dart';
import 'inventory_providers.dart';
import 'offline_sync_providers.dart';

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
///
/// **`keepAlive: true` is load-bearing, not an optimisation.** The salary sheets
/// reach this notifier with `ref.read(salaryActionsProvider.notifier)` and hold
/// it across `await movement(...)` / `await pay(...)`, so the notifier's own
/// `ref` is used again in `_refresh()` *after* the await. An auto-dispose
/// provider nothing `watch`es is disposed at the end of the first frame after
/// the read, and the post-await `ref.invalidate` then throws
/// `UnmountedRefException`, which `mapErrorToAppException` degrades to the
/// generic `حدث خطأ غير متوقع` banner while the write itself may well have
/// landed — the movement sheet failing for no visible reason. This is the same
/// defect `PaymentActions` had; it was found through the payment path first.
/// Holds no state (`build() => null`), so nothing leaks.
@Riverpod(keepAlive: true)
class SalaryActions extends _$SalaryActions {
  @override
  Object? build() => null;

  Future<MovementResult> movement(MovementDraft draft) async {
    final result = await ref.read(salaryRepositoryProvider).addMovement(draft);
    _refresh(draft.employeeId, draft.month, pending: result.pending);
    return result;
  }

  Future<SalaryResult> pay(SalaryDraft draft) async {
    final repo = ref.read(salaryRepositoryProvider);
    // The sheet previews an entitlement captured when it OPENED. Between then
    // and the tap the month can be paid — another window, another device, or a
    // drain that landed in between — so the sheet's own button state is a
    // snapshot of a value that is already stale.
    //
    // The coordinator's duplicate guard cannot be the backstop: it is
    // device-local and inspects only `local_salaries`, so on a device whose
    // mirror was cleared, or one that has been offline, it would happily queue a
    // second payout for a month the server already holds. Re-reading the live
    // read model closes the window, and it answers with the Arabic duplicate
    // message the user already knows instead of a server validation error.
    final current = await repo.entitlement(
      employeeId: draft.employeeId,
      month: draft.month,
    );
    if (current.isPaidForMonth) {
      throw const ValidationException('تم صرف راتب هذا الشهر مسبقاً');
    }
    final result = await repo.pay(draft);
    _refresh(draft.employeeId, draft.month, pending: result.pending);
    return result;
  }

  /// Targeted: the salary run, its history, inventory (a product deduction
  /// moves stock) and the employee statement.
  ///
  /// The statement was missing: it is derived from the same salary/movement
  /// rows, so after recording a movement the statement screen kept showing the
  /// pre-movement balance while the run card above it had already updated.
  ///
  /// [pending] adds the app-wide pending count, and only when the write was
  /// actually enqueued — the same one-shot-`FutureProvider` gap Phase 2 P2
  /// fixed for invoices. A write that reached the server enqueues nothing, so
  /// invalidating then would churn the provider for no reason.
  void _refresh(String employeeId, DateTime month, {required bool pending}) {
    ref.invalidate(salaryRunProvider(employeeId, month));
    ref.invalidate(salaryHistoryProvider);
    ref.invalidate(inventoryProductsProvider);
    ref.invalidate(employeeStatementProvider);
    if (pending) ref.invalidate(pendingSyncCountProvider);
  }
}
