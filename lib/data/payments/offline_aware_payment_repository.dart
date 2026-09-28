import '../../domain/payments/payment_repository.dart';
import '../offline/offline_write.dart';

/// Payment write seam that is **local-first**: the payment (or settlement) is
/// committed to the device in one atomic transaction and the server call
/// becomes a queued replay.
///
/// Mirrors [OfflineAwareSaleRepository] for the same reason: the local commit
/// is the durable record, and both RPCs are idempotent server-side via
/// `p_request_id` (`record_payment` dedupes on `payments.request_id`,
/// `settle_supplier` on `processed_requests`), so a replay is safe.
///
/// When the Drift store is unavailable there is nothing to queue into, so
/// `payments_providers.dart` hands back the live Supabase repository instead of
/// constructing this class at all.
class OfflineAwarePaymentRepository implements PaymentRepository {
  OfflineAwarePaymentRepository(this._coordinator);

  final OfflineWriteCoordinator _coordinator;

  @override
  Future<PaymentResult> record(PaymentDraft draft) =>
      _coordinator.recordPayment(draft);

  @override
  Future<SettlementResult> settle(SettlementDraft draft) =>
      _coordinator.settleSupplier(draft);
}