import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/offline/local_store.dart';
import '../../data/offline/offline_write.dart';
import '../../data/payments/offline_aware_payment_repository.dart';
import '../../data/payments/supabase_payment_repository.dart';
import '../../data/supabase_client.dart';
import '../../domain/payments/payment_repository.dart';
import 'accounts_providers.dart';
import 'auth_providers.dart';
import 'purchases_providers.dart';
import 'sales_providers.dart';

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
@riverpod
class PaymentActions extends _$PaymentActions {
  @override
  Object? build() => null;

  Future<PaymentResult> record(PaymentDraft draft) async {
    final result = await ref.read(paymentRepositoryProvider).record(draft);
    _refresh();
    return result;
  }

  Future<SettlementResult> settle(SettlementDraft draft) async {
    final result = await ref.read(paymentRepositoryProvider).settle(draft);
    _refresh();
    return result;
  }

  void _refresh() {
    ref.invalidate(saleInvoicesListProvider);
    ref.invalidate(purchaseInvoicesListProvider);
  }
}
