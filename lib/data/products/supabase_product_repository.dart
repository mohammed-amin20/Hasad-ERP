import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/error/app_exception.dart';
import '../../domain/products/product.dart';
import '../../domain/products/product_draft.dart';
import '../../domain/products/product_repository.dart';

const _productColumns =
    'id, name, barcode, unit, unit_type, sale_price, purchase_price, '
    'qty, reorder_level, supplier_id, commission_rate';

/// [ProductRepository] backed by Supabase + RLS.
class SupabaseProductRepository implements ProductRepository {
  const SupabaseProductRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Product>> listAll({String? search}) async {
    try {
      var query = _client.from('products').select(_productColumns);

      if (search != null && search.trim().isNotEmpty) {
        final term = search.trim();
        query = query.or('name.ilike.%$term%,barcode.ilike.%$term%');
      }

      final rows = await query.order('name');
      return rows.map(Product.fromJson).toList();
    } on Object catch (error) {
      throw mapErrorToAppException(error);
    }
  }

  @override
  Future<Product?> getById(String id) async {
    try {
      final row = await _client
          .from('products')
          .select(_productColumns)
          .eq('id', id)
          .maybeSingle();

      if (row == null) return null;
      return Product.fromJson(row);
    } on Object catch (error) {
      throw mapErrorToAppException(error);
    }
  }

  @override
  Future<Product> create(ProductDraft draft) async {
    try {
      final rows = await _client
          .from('products')
          .insert(draft.toJson())
          .select(_productColumns)
          .single();
      return Product.fromJson(rows);
    } on Object catch (error) {
      throw mapErrorToAppException(error);
    }
  }

  @override
  Future<void> update({
    required String id,
    required ProductDraft draft,
  }) async {
    try {
      await _client.from('products').update(draft.toJson()).eq('id', id);
    } on Object catch (error) {
      throw mapErrorToAppException(error);
    }
  }

  @override
  Future<void> delete(String id) async {
    try {
      await _client.from('products').delete().eq('id', id);
    } on Object catch (error) {
      throw mapErrorToAppException(error);
    }
  }
}