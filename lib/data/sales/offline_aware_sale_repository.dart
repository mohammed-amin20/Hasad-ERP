import '../../domain/sales/sale_invoice_draft.dart';
import '../../domain/sales/sale_repository.dart';
import '../offline/offline_write.dart';

/// Sale write seam that is **local-first**: the invoice is committed to the
/// device in one atomic transaction and the server call becomes a queued replay.
///
/// The earlier server-first shape (`try server → queue only on
/// `NetworkException`) was a data-loss bug, not merely slow. `NetworkException`
/// only covers the deliberate socket-failure path; a `SocketException` raised
/// after the request was already delivered, a proxy returning 5xx, a request
/// that times out, or any non-`NetworkException` mapped to `UnknownException`
/// (`app_exception.dart`) all surfaced as an error to the user while the server
/// may already have accepted the invoice — so a retry created a duplicate.
/// Reads are legitimately cache-first (Slice A.5); **writes are local-first**,
/// because the local commit is the durable record and the queue leg is
/// idempotent server-side via `p_request_id`.
///
/// When the Drift store is unavailable there is nothing to queue into, so
/// `sales_providers.dart` hands back the live Supabase repository instead of
/// constructing this class at all.
class OfflineAwareSaleRepository implements SaleRepository {
  OfflineAwareSaleRepository(this._coordinator);

  final OfflineWriteCoordinator _coordinator;

  @override
  Future<SaleInvoiceResult> create(SaleInvoiceDraft draft) =>
      _coordinator.writeSale(draft);
}
