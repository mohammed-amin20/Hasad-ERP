import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/invoices/invoice_repository.dart';
import '../../data/offline/local_store.dart';
import '../../data/offline/offline_invoice_repository.dart';
import '../../data/sales/supabase_sale_repository.dart';
import '../../data/supabase_client.dart';
import '../../domain/customers/customer.dart';
import '../../domain/invoices/invoice.dart';
import '../../domain/sales/sale_repository.dart';
import 'auth_providers.dart';
import 'customers_providers.dart';

part 'sales_providers.g.dart';

@riverpod
SaleRepository saleRepository(Ref ref) =>
    SupabaseSaleRepository(ref.watch(supabaseClientProvider));

@riverpod
InvoiceRepository invoiceRepository(Ref ref) => OfflineInvoiceRepository(
      InvoiceRepository(ref.watch(supabaseClientProvider)),
      store: ref.watch(localStoreProvider).value,
      tenantId: ref.watch(authStateProvider).value?.tenantId,
    );

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

/// From-date bound (ISO yyyy-MM-dd) for the sale invoice list; null = none.
@riverpod
class SaleFrom extends _$SaleFrom {
  @override
  String? build() => null;

  void update(String? iso) => state = iso;
}

/// To-date bound (ISO yyyy-MM-dd) for the sale invoice list; null = none.
@riverpod
class SaleTo extends _$SaleTo {
  @override
  String? build() => null;

  void update(String? iso) => state = iso;
}

/// Reactive list of sale invoices.
@riverpod
class SaleInvoicesList extends _$SaleInvoicesList {
  @override
    @override
  Future<List<Invoice>> build() async {
    final search = ref.watch(saleSearchProvider);
    final from = ref.watch(saleFromProvider);
    final to = ref.watch(saleToProvider);
    return ref.watch(invoiceRepositoryProvider).list(
          type: 'sale',
          search: search.isEmpty ? null : search,
          from: from == null ? null : DateTime.parse(from),
          to: to == null ? null : DateTime.parse(to),
        );
  }
Future<void> refresh() async {
    ref.invalidateSelf();
  }

  /// Load line items for a single sale invoice.
  Future<List<InvoiceItem>> items(String invoiceId) =>
      ref.read(invoiceRepositoryProvider).items(invoiceId);
}
