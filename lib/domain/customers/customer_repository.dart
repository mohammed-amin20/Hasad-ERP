import 'customer.dart';
import 'customer_draft.dart';

/// Abstract interface for customer persistence.
///
/// Concrete implementations live in `data/` — the UI never imports
/// the Supabase client directly.
abstract interface class CustomerRepository {
  Future<List<Customer>> listAll({String? search});
  Future<Customer?> getById(String id);
  Future<Customer> create(CustomerDraft draft);
  Future<void> update({required String id, required CustomerDraft draft});
  Future<void> delete(String id);
}
