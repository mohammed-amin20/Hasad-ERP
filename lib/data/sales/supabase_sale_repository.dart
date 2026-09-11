import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/error/app_exception.dart';
import '../../domain/sales/sale_invoice_draft.dart';
import '../../domain/sales/sale_repository.dart';

/// [SaleRepository] backed by the `create_sale_invoice` RPC (balanced entry,
/// stock check/deduction, commission dues — all server-side).
class SupabaseSaleRepository implements SaleRepository {
  const SupabaseSaleRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<SaleInvoiceResult> create(SaleInvoiceDraft draft) async {
    try {
      final result = await _client.rpc(
        'create_sale_invoice',
        params: draft.toJson(),
      );
      return SaleInvoiceResult.fromJson(result as Map<String, dynamic>);
    } on Object catch (error) {
      throw mapErrorToAppException(error);
    }
  }
}
