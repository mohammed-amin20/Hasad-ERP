import 'product.dart';
import 'product_draft.dart';

/// Abstract interface for product persistence.
///
/// Concrete implementations live in `data/` — the UI never imports
/// the Supabase client directly.
abstract interface class ProductRepository {
  Future<List<Product>> listAll({String? search});
  Future<Product?> getById(String id);
  Future<Product> create(ProductDraft draft);
  Future<void> update({required String id, required ProductDraft draft});
  Future<void> delete(String id);
}
