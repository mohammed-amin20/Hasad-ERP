import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/error/app_exception.dart';
import '../../domain/purchases/purchase_invoice_draft.dart';
import '../../domain/purchases/purchase_repository.dart';

/// [PurchaseRepository] backed by the `create_purchase_invoice` RPC (stock
/// receipt, inline product creation, direct/consignment journal logic).
class SupabasePurchaseRepository implements PurchaseRepository {
  const SupabasePurchaseRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<PurchaseInvoiceResult> create(PurchaseInvoiceDraft draft) async {
    try {
      final result = await _client.rpc(
        'create_purchase_invoice',
        params: draft.toJson(),
      );
      return PurchaseInvoiceResult.fromJson(result as Map<String, dynamic>);
    } on Object catch (error) {
      throw mapErrorToAppException(error);
    }
  }
}
