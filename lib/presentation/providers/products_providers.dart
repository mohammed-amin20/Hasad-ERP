import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/products/supabase_product_repository.dart';
import '../../data/supabase_client.dart';
import '../../domain/products/product.dart';
import '../../domain/products/product_draft.dart';
import '../../domain/products/product_repository.dart';

part 'products_providers.g.dart';

/// Concrete product repository wired to Supabase.
@riverpod
ProductRepository productRepository(Ref ref) =>
    SupabaseProductRepository(ref.watch(supabaseClientProvider));

/// Current search term for the product list (reactive).
@riverpod
class ProductSearch extends _$ProductSearch {
  @override
  String build() => '';

  void update(String term) => state = term;
}

/// Reactive list of products, filtered by [ProductSearch].
@riverpod
class ProductsList extends _$ProductsList {
  @override
  Future<List<Product>> build() async {
    final search = ref.watch(productSearchProvider);
    final repo = ref.watch(productRepositoryProvider);
    return repo.listAll(search: search.isEmpty ? null : search);
  }

  /// Create a new product, then refresh the list.
  Future<Product> create(ProductDraft draft) async {
    final repo = ref.read(productRepositoryProvider);
    final product = await repo.create(draft);
    ref.invalidateSelf();
    return product;
  }

  /// Update an existing product, then refresh the list.
  Future<void> updateProduct({
    required String id,
    required ProductDraft draft,
  }) async {
    final repo = ref.read(productRepositoryProvider);
    await repo.update(id: id, draft: draft);
    ref.invalidateSelf();
  }

  /// Delete a product, then refresh the list.
  Future<void> delete(String id) async {
    final repo = ref.read(productRepositoryProvider);
    await repo.delete(id);
    ref.invalidateSelf();
  }
}