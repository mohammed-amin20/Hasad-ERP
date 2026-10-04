import '../../domain/inventory/inventory.dart';
import '../../domain/inventory/inventory_repository.dart';
import 'offline_write.dart';

/// [InventoryRepository] that routes a physical-count adjustment through the
/// [OfflineWriteCoordinator] when a local store + tenant exist (local-first:
/// the product quantity moves in the mirror and the RPC is queued for replay),
/// else falls back to the Supabase repository.
class OfflineInventoryRepository implements InventoryRepository {
  const OfflineInventoryRepository(this._inner, {this.coordinator});

  final InventoryRepository _inner;
  final OfflineWriteCoordinator? coordinator;

  /// True when a count is mirrored + queued locally rather than sent now.
  bool get writesAreLocalFirst => coordinator != null;

  @override
  Future<StockAdjustResult> adjust(StockAdjustDraft draft) {
    final c = coordinator;
    if (c != null) return c.adjustInventory(draft);
    return _inner.adjust(draft);
  }
}
