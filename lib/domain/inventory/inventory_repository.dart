import 'inventory.dart';

/// Records a physical count adjustment into the inventory.
abstract interface class InventoryRepository {
  Future<StockAdjustResult> adjust(StockAdjustDraft draft);
}