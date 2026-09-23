import '../../domain/sales/sale_invoice_draft.dart';
import '../../domain/sales/sale_repository.dart';
import '../offline/offline_write.dart';

/// Sale write seam that reroutes `create` through the offline coordinator
/// when the connectivity verdict says offline, keeping the RPC path in all
/// other cases.
class OfflineAwareSaleRepository implements SaleRepository {
  OfflineAwareSaleRepository(
    this._supabase,
    this._coordinator,
    this._verdict,
  );

  final SaleRepository _supabase;
  final OfflineWriteCoordinator _coordinator;
  final bool Function() _verdict;

  @override
  Future<SaleInvoiceResult> create(SaleInvoiceDraft draft) {
    final online = _verdict();
    if (online) {
      return _supabase.create(draft);
    }
    return _coordinator.writeSale(draft);
  }
}
