import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/payments/supabase_payment_repository.dart';
import '../../data/supabase_client.dart';
import '../../domain/payments/payment_repository.dart';
import 'purchases_providers.dart';
import 'sales_providers.dart';

part 'payments_providers.g.dart';

@riverpod
PaymentRepository paymentRepository(Ref ref) =>
    SupabasePaymentRepository(ref.watch(supabaseClientProvider));

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