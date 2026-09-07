import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/inventory/supabase_inventory_repository.dart';
import '../../data/supabase_client.dart';
import '../../domain/inventory/inventory.dart';
import '../../domain/inventory/inventory_repository.dart';
import '../../domain/products/product.dart';
import 'products_providers.dart';

part 'inventory_providers.g.dart';

@riverpod
InventoryRepository inventoryRepository(Ref ref) =>
    SupabaseInventoryRepository(ref.watch(supabaseClientProvider));

/// All products with their live quantities (no search filter), for the
/// inventory screen.
@riverpod
Future<List<Product>> inventoryProducts(Ref ref) async {
  final repo = ref.watch(productRepositoryProvider);
  return repo.listAll();
}

/// The most recent physical-count result, null until a count is submitted.
@riverpod
class LastAdjust extends _$LastAdjust {
  @override
  StockAdjustResult? build() => null;

  Future<StockAdjustResult> adjust(StockAdjustDraft draft) async {
    final repo = ref.read(inventoryRepositoryProvider);
    final result = await repo.adjust(draft);
    state = result;
    ref.invalidate(inventoryProductsProvider);
    return result;
  }
}