import '../../domain/purchases/purchase_invoice_draft.dart';
import '../../domain/purchases/purchase_repository.dart';
import '../offline/offline_write.dart';

/// Purchase write seam that is **local-first**, mirroring
/// [OfflineAwareSaleRepository]: the invoice is committed to the device in one
/// atomic transaction and the server call becomes a queued replay. A
/// `NetworkException`-gated server-first shape would be a data-loss bug for the
/// same reasons documented on the sale wrapper — the local commit (invoice +
/// items + stock + journal + queue legs) is the durable record, and the queue
/// leg is idempotent server-side via `p_request_id`.
///
/// Inline new products are mapped through `product_id` (see
/// [OfflineWriteCoordinator.writePurchase]): each one enqueues its own
/// `table:products` leg with the client uuid so the server creates that product
/// under the same id, and the purchase RPC leg references it instead of
/// `new_product`. No duplicate products, no phantom local rows.
///
/// When the Drift store is unavailable there is nothing to queue into, so
/// `purchases_providers.dart` hands back the live Supabase repository instead
/// of constructing this class at all.
class OfflineAwarePurchaseRepository implements PurchaseRepository {
  OfflineAwarePurchaseRepository(this._coordinator);

  final OfflineWriteCoordinator _coordinator;

  @override
  Future<PurchaseInvoiceResult> create(PurchaseInvoiceDraft draft) =>
      _coordinator.writePurchase(draft);
}