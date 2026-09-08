import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/error/app_exception.dart';
import '../../domain/payments/payment_repository.dart';

/// [PaymentRepository] backed by the `record_payment` / `settle_supplier`
/// RPCs (single balanced transaction each, idempotent via `p_request_id`).
class SupabasePaymentRepository implements PaymentRepository {
  const SupabasePaymentRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<PaymentResult> record(PaymentDraft draft) async {
    try {
      final result = await _client.rpc(
        'record_payment',
        params: draft.toJson(),
      );
      return PaymentResult.fromJson(result as Map<String, dynamic>);
    } on Object catch (error) {
      throw mapErrorToAppException(error);
    }
  }

  @override
  Future<SettlementResult> settle(SettlementDraft draft) async {
    try {
      final result = await _client.rpc(
        'settle_supplier',
        params: draft.toJson(),
      );
      return SettlementResult.fromJson(result as Map<String, dynamic>);
    } on Object catch (error) {
      throw mapErrorToAppException(error);
    }
  }
}