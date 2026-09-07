import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/invoices/invoice_repository.dart';
import '../../data/sales/supabase_sale_repository.dart';
import '../../data/supabase_client.dart';
import '../../domain/customers/customer.dart';
import '../../domain/invoices/invoice.dart';
import '../../domain/sales/sale_repository.dart';
import 'customers_providers.dart';

part 'sales_providers.g.dart';

@riverpod
SaleRepository saleRepository(Ref ref) =>
    SupabaseSaleRepository(ref.watch(supabaseClientProvider));

@riverpod
InvoiceRepository invoiceRepository(Ref ref) =>
    InvoiceRepository(ref.watch(supabaseClientProvider));

/// All customers for dropdowns, never filtered by the customers screen search.
@riverpod
Future<List<Customer>> allCustomers(Ref ref) {
  final repo = ref.watch(customerRepositoryProvider);
  return repo.listAll();
}

/// Current search term for the sale invoice list (reactive).
@riverpod
class SaleSearch extends _$SaleSearch {
  @override
  String build() => '';

  void update(String term) => state = term;
}

/// Reactive list of sale invoices.
@riverpod
class SaleInvoicesList extends _$SaleInvoicesList {
  @override
  Future<List<Invoice>> build() async {
    final search = ref.watch(saleSearchProvider);
    return ref
        .watch(invoiceRepositoryProvider)
        .list(type: 'sale', search: search.isEmpty ? null : search);
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
  }

  /// Load line items for a single sale invoice.
  Future<List<InvoiceItem>> items(String invoiceId) =>
      ref.read(invoiceRepositoryProvider).items(invoiceId);
}