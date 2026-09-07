import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/error/app_exception.dart';
import '../../domain/inventory/inventory.dart';
import '../../domain/inventory/inventory_repository.dart';

/// [InventoryRepository] backed by the `adjust_inventory` RPC (records a
/// stock_moves row + updates products.qty to the counted value).
class SupabaseInventoryRepository implements InventoryRepository {
  const SupabaseInventoryRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<StockAdjustResult> adjust(StockAdjustDraft draft) async {
    try {
      final result = await _client.rpc(
        'adjust_inventory',
        params: draft.toJson(),
      );
      return StockAdjustResult.fromJson(result as Map<String, dynamic>);
    } on Object catch (error) {
      throw mapErrorToAppException(error);
    }
  }
}