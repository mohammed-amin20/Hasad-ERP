import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/invoices/invoice_repository.dart';
import '../../data/offline/local_store.dart';
import '../../data/offline/offline_invoice_repository.dart';
import '../../data/offline/offline_write.dart';
import '../../data/sales/offline_aware_sale_repository.dart';
import '../../data/sales/supabase_sale_repository.dart';
import '../../data/supabase_client.dart';
import '../../domain/customers/customer.dart';
import '../../domain/invoices/invoice.dart';
import '../../domain/sales/sale_repository.dart';
import 'accounts_providers.dart';
import 'auth_providers.dart';
import 'customers_providers.dart';

part 'sales_providers.g.dart';

@riverpod
SaleRepository saleRepository(Ref ref) {
  final store = ref.watch(localStoreProvider).value;
  final tenantId = ref.watch(authStateProvider).value?.tenantId;
  // No local store means nothing can be queued, so fall back to the live RPC
  // rather than pretending the write is durable. Writes are local-first
  // otherwise — see OfflineAwareSaleRepository.
  if (store == null || tenantId == null) {
    return SupabaseSaleRepository(ref.watch(supabaseClientProvider));
  }
  return OfflineAwareSaleRepository(
    OfflineWriteCoordinator(
      store,
      tenantId,
      () => ref.read(accountRepositoryProvider).chart(),
    ),
  );
}

@riverpod
InvoiceRepository invoiceRepository(Ref ref) => OfflineInvoiceRepository(
      InvoiceRepository(ref.watch(supabaseClientProvider)),
      store: ref.watch(localStoreProvider).value,
      tenantId: ref.watch(authStateProvider).value?.tenantId,
    );

@riverpod
Future<List<Customer>> allCustomers(Ref ref) =>
    ref.watch(customerRepositoryProvider).listAll();

@riverpod
class SaleSearch extends _$SaleSearch {
  @override
  String build() => '';

  void update(String term) => state = term;
}

@riverpod
class SaleFrom extends _$SaleFrom {
  @override
  String? build() => null;

  void update(String? iso) => state = iso;
}

@riverpod
class SaleTo extends _$SaleTo {
  @override
  String? build() => null;

  void update(String? iso) => state = iso;
}

@riverpod
class SaleInvoicesList extends _$SaleInvoicesList {
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

  void refresh() => ref.invalidateSelf();
}
