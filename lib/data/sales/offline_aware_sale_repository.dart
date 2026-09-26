import '../../core/error/app_exception.dart';
import '../../domain/sales/sale_invoice_draft.dart';
import '../../domain/sales/sale_repository.dart';
import '../offline/offline_write.dart';

/// Sale write seam that always attempts the server first and only reroutes
/// `create` through the offline coordinator when the attempt actually failed
/// with a network error.
///
/// The connectivity verdict is deliberately NOT consulted here. It is a hint
/// from a probe, and a wrong hint must never be able to divert a write into the
/// local queue — when that happened the queue's own `isOnline` gate also read
/// the same wrong hint, so the invoice could sit unflushed indefinitely while
/// the UI reported success. Reads follow the same rule (Slice A.5): trust the
/// server, fall back to the cache only on a real `NetworkException`.
class OfflineAwareSaleRepository implements SaleRepository {
  OfflineAwareSaleRepository(this._supabase, this._coordinator);

  final SaleRepository _supabase;
  final OfflineWriteCoordinator _coordinator;

  @override
  Future<SaleInvoiceResult> create(SaleInvoiceDraft draft) async {
    try {
      return await _supabase.create(draft);
    } on NetworkException {
      return _coordinator.writeSale(draft);
    }
  }
}
