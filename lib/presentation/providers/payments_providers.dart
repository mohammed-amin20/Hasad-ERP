import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/offline/local_store.dart';
import '../../data/offline/offline_write.dart';
import '../../data/payments/offline_aware_payment_repository.dart';
import '../../data/payments/supabase_payment_repository.dart';
import '../../data/supabase_client.dart';
import '../../domain/payments/payment_repository.dart';
import 'accounts_providers.dart';
import 'auth_providers.dart';
import 'offline_sync_providers.dart';
import 'purchases_providers.dart';
import 'sales_providers.dart';
import 'statements_providers.dart';

part 'payments_providers.g.dart';

@riverpod
PaymentRepository paymentRepository(Ref ref) {
  final store = ref.watch(localStoreProvider).value;
  final tenantId = ref.watch(authStateProvider).value?.tenantId;
  // No local store means nothing can be queued, so fall back to the live RPC
  // rather than pretending the write is durable. Writes are local-first
  // otherwise — see OfflineAwarePaymentRepository.
  if (store == null || tenantId == null) {
    return SupabasePaymentRepository(ref.watch(supabaseClientProvider));
  }
  return OfflineAwarePaymentRepository(
    OfflineWriteCoordinator(
      store,
      tenantId,
      () => ref.read(accountRepositoryProvider).chart(),
    ),
  );
}

/// Executes payment actions and then refreshes both invoice lists so the
/// new status/remaining reach the UI immediately.
///
/// **`keepAlive: true` is load-bearing, not an optimisation.** The sheets reach
/// this notifier with `ref.read(paymentActionsProvider.notifier)` and then hold
/// it across `await record(...)`, so the notifier's own `ref` is used again in
/// `_refresh()` *after* the await. An auto-dispose provider that nothing
/// `watch`es is disposed at the end of the first frame that follows the read,
/// and the post-await `ref.invalidate` then throws
/// `UnmountedRefException: Cannot use the Ref of paymentActionsProvider after
/// it has been disposed` — which the sheet's own `catch` renders as the generic
/// `حدث خطأ غير متوقع` banner while the write itself has already landed. The user
/// retries, and the second attempt is the one that double-pays.
///
/// The signature of this defect is that it is **invisible to a state
/// assertion**: the banner is the only observable, and `tester.takeException()`
/// is null either way. Proven both ways in `offline_payment_sheet_test.dart` and
/// `offline_settlement_sheet_test.dart` — reverting this annotation fails all
/// three cases. It holds no state (`build() => null`), so nothing leaks.
///
/// Any other provider whose notifier is only ever `read` from a sheet and used
/// across an `await` has the same defect — see `SalaryActions`.
@Riverpod(keepAlive: true)
class PaymentActions extends _$PaymentActions {
  @override
  Object? build() => null;

  Future<PaymentResult> record(PaymentDraft draft) async {
    final result = await ref.read(paymentRepositoryProvider).record(draft);
    _refresh(pending: result.pending);
    return result;
  }

  Future<SettlementResult> settle(SettlementDraft draft) async {
    final result = await ref.read(paymentRepositoryProvider).settle(draft);
    _refresh(pending: result.pending);
    return result;
  }

  /// Targeted: exactly the reads a payment can change.
  ///
  /// Debts are included because a payment is the thing that moves a party's
  /// balance — invalidating only the invoice lists left the debts screen
  /// showing a figure the same action had already invalidated the source of.
  /// The invoice *sync badge* is deliberately NOT touched: it is keyed on
  /// `'invoices'` queue legs, and a payment leg does not change whether an
  /// invoice is synced.
  ///
  /// [pending] adds the app-wide pending count, and only when the write was
  /// actually enqueued. That is the same defect Phase 2 P2 fixed for invoices:
  /// `pendingSyncCountProvider` is a one-shot `FutureProvider` over the queue
  /// with no self-polling, so without an invalidation the count stayed at its
  /// pre-write value (0) until a drain corrected it — the app claimed
  /// "everything is synced" while the user's own payment sat unsent. Gated on
  /// `result.pending` because a write that reached the server enqueues nothing
  /// and must not churn the provider.
  void _refresh({required bool pending}) {
    ref.invalidate(saleInvoicesListProvider);
    ref.invalidate(purchaseInvoicesListProvider);
    ref.invalidate(customerDebtsProvider);
    ref.invalidate(supplierDebtsProvider);
    if (pending) ref.invalidate(pendingSyncCountProvider);
  }
}
