import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/customers/supabase_customer_repository.dart';
import '../../data/supabase_client.dart';
import '../../domain/customers/customer.dart';
import '../../domain/customers/customer_draft.dart';
import '../../domain/customers/customer_repository.dart';

part 'customers_providers.g.dart';

/// Concrete customer repository wired to Supabase.
@riverpod
CustomerRepository customerRepository(Ref ref) =>
    SupabaseCustomerRepository(ref.watch(supabaseClientProvider));

/// Current search term for the customer list (reactive).
@riverpod
class CustomerSearch extends _$CustomerSearch {
  @override
  String build() => '';

  void update(String term) => state = term;
}

/// Reactive list of customers, filtered by [CustomerSearch].
@riverpod
class CustomersList extends _$CustomersList {
  @override
  Future<List<Customer>> build() async {
    final search = ref.watch(customerSearchProvider);
    final repo = ref.watch(customerRepositoryProvider);
    return repo.listAll(search: search.isEmpty ? null : search);
  }

  /// Create a new customer, then refresh the list.
  Future<Customer> create(CustomerDraft draft) async {
    final repo = ref.read(customerRepositoryProvider);
    final customer = await repo.create(draft);
    ref.invalidateSelf();
    return customer;
  }

  /// Update an existing customer, then refresh the list.
  Future<void> updateCustomer({
    required String id,
    required CustomerDraft draft,
  }) async {
    final repo = ref.read(customerRepositoryProvider);
    await repo.update(id: id, draft: draft);
    ref.invalidateSelf();
  }

  /// Delete a customer, then refresh the list.
  Future<void> delete(String id) async {
    final repo = ref.read(customerRepositoryProvider);
    await repo.delete(id);
    ref.invalidateSelf();
  }
}
