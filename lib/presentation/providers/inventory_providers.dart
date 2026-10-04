import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/inventory/supabase_inventory_repository.dart';
import '../../data/offline/local_store.dart';
import '../../data/offline/offline_inventory_repository.dart';
import '../../data/offline/offline_write.dart';
import '../../data/supabase_client.dart';
import '../../domain/inventory/inventory.dart';
import '../../domain/inventory/inventory_repository.dart';
import '../../domain/products/product.dart';
import 'auth_providers.dart';
import 'products_providers.dart';

part 'inventory_providers.g.dart';

/// Inventory repository — offline-first. A count routes through an
/// [OfflineWriteCoordinator] when a local store + tenant exist (local-first,
/// queued for replay), else falls back to Supabase.
///
/// The coordinator needs no chart seed here: `adjust_inventory` does not post a
/// journal, so [OfflineWriteCoordinator.adjustInventory] never reads the chart.
@riverpod
InventoryRepository inventoryRepository(Ref ref) {
  final store = ref.watch(localStoreProvider).value;
  final tenantId = ref.watch(authStateProvider).value?.tenantId;
  return OfflineInventoryRepository(
    SupabaseInventoryRepository(ref.watch(supabaseClientProvider)),
    coordinator: (store == null || tenantId == null)
        ? null
        : OfflineWriteCoordinator(store, tenantId),
  );
}

/// True when counts are local-first (a local store + tenant exist, so an
/// adjustment moves the mirror and queues). The UI reads this to show the
/// offline pending message instead of the online confirmation.
@riverpod
bool inventoryWritesLocalFirst(Ref ref) {
  final store = ref.watch(localStoreProvider).value;
  final tenantId = ref.watch(authStateProvider).value?.tenantId;
  return store != null && tenantId != null;
}

/// All products with their live quantities (no search filter), for the
/// inventory screen.
@riverpod
Future<List<Product>> inventoryProducts(Ref ref) async {
  final repo = ref.watch(productRepositoryProvider);
  return repo.listAll();
}

/// The most recent physical-count result, null until a count is submitted.
///
/// **`keepAlive: true` is load-bearing, not an optimisation.** The count sheet
/// reaches this provider with `ref.read`, so nothing ever listens to it; an
/// auto-dispose provider with no listener is disposed as soon as the read
/// returns. The local-first write is a real drift transaction, and the device
/// store runs on a background isolate, so by the time `await repo.adjust`
/// completes the provider has been disposed — and `state = result` then throws
/// `UnmountedRefException`. That is an unmapped `Object`, so a count that had
/// already committed locally and queued its leg reported «حدث خطأ غير متوقع».
/// Same rule as [PaymentActions] / [SalaryActions].
@Riverpod(keepAlive: true)
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
