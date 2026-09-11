import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/error/app_exception.dart';
import '../../domain/suppliers/supplier.dart';
import '../../domain/suppliers/supplier_draft.dart';
import '../../domain/suppliers/supplier_repository.dart';

/// [SupplierRepository] backed by Supabase + RLS.
class SupabaseSupplierRepository implements SupplierRepository {
  const SupabaseSupplierRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Supplier>> listAll({String? search}) async {
    try {
      var query = _client
          .from('suppliers')
          .select(
            'id, name, phone, notes, deal_type, commission_rate, created_at',
          );

      if (search != null && search.trim().isNotEmpty) {
        final term = search.trim();
        query = query.or('name.ilike.%$term%,phone.ilike.%$term%');
      }

      final rows = await query.order('name');
      return rows.map(Supplier.fromJson).toList();
    } on Object catch (error) {
      throw mapErrorToAppException(error);
    }
  }

  @override
  Future<Supplier?> getById(String id) async {
    try {
      final row = await _client
          .from('suppliers')
          .select(
            'id, name, phone, notes, deal_type, commission_rate, created_at',
          )
          .eq('id', id)
          .maybeSingle();

      if (row == null) return null;
      return Supplier.fromJson(row);
    } on Object catch (error) {
      throw mapErrorToAppException(error);
    }
  }

  @override
  Future<Supplier> create(SupplierDraft draft) async {
    try {
      final rows = await _client
          .from('suppliers')
          .insert(draft.toJson())
          .select(
            'id, name, phone, notes, deal_type, commission_rate, created_at',
          )
          .single();
      return Supplier.fromJson(rows);
    } on Object catch (error) {
      throw mapErrorToAppException(error);
    }
  }

  @override
  Future<void> update({
    required String id,
    required SupplierDraft draft,
  }) async {
    try {
      await _client.from('suppliers').update(draft.toJson()).eq('id', id);
    } on Object catch (error) {
      throw mapErrorToAppException(error);
    }
  }

  @override
  Future<void> delete(String id) async {
    try {
      await _client.from('suppliers').delete().eq('id', id);
    } on Object catch (error) {
      throw mapErrorToAppException(error);
    }
  }
}
