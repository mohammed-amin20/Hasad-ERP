import 'supplier.dart';
import 'supplier_draft.dart';

/// Abstract interface for supplier persistence.
///
/// Concrete implementations live in `data/` — the UI never imports
/// the Supabase client directly.
abstract interface class SupplierRepository {
  Future<List<Supplier>> listAll({String? search});
  Future<Supplier?> getById(String id);
  Future<Supplier> create(SupplierDraft draft);
  Future<void> update({required String id, required SupplierDraft draft});
  Future<void> delete(String id);
}
