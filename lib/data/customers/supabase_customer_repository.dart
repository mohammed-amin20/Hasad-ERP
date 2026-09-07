import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/error/app_exception.dart';
import '../../domain/customers/customer.dart';
import '../../domain/customers/customer_draft.dart';
import '../../domain/customers/customer_repository.dart';

/// [CustomerRepository] backed by Supabase + RLS.
class SupabaseCustomerRepository implements CustomerRepository {
  const SupabaseCustomerRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Customer>> listAll({String? search}) async {
    try {
      var query = _client
          .from('customers')
          .select('id, name, phone, notes, created_at');

      if (search != null && search.trim().isNotEmpty) {
        final term = search.trim();
        query = query.or('name.ilike.%$term%,phone.ilike.%$term%');
      }

      final rows = await query.order('name');
      return rows.map(Customer.fromJson).toList();
    } on Object catch (error) {
      throw mapErrorToAppException(error);
    }
  }

  @override
  Future<Customer?> getById(String id) async {
    try {
      final row = await _client
          .from('customers')
          .select('id, name, phone, notes, created_at')
          .eq('id', id)
          .maybeSingle();

      if (row == null) return null;
      return Customer.fromJson(row);
    } on Object catch (error) {
      throw mapErrorToAppException(error);
    }
  }

  @override
  Future<Customer> create(CustomerDraft draft) async {
    try {
      final rows = await _client
          .from('customers')
          .insert(draft.toJson())
          .select('id, name, phone, notes, created_at')
          .single();
      return Customer.fromJson(rows);
    } on Object catch (error) {
      throw mapErrorToAppException(error);
    }
  }

  @override
  Future<void> update({
    required String id,
    required CustomerDraft draft,
  }) async {
    try {
      await _client
          .from('customers')
          .update(draft.toJson())
          .eq('id', id);
    } on Object catch (error) {
      throw mapErrorToAppException(error);
    }
  }

  @override
  Future<void> delete(String id) async {
    try {
      await _client.from('customers').delete().eq('id', id);
    } on Object catch (error) {
      throw mapErrorToAppException(error);
    }
  }
}