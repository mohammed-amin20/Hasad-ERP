import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/purchases/supabase_purchase_repository.dart';
import '../../data/supabase_client.dart';
import '../../domain/invoices/invoice.dart';
import '../../domain/purchases/purchase_repository.dart';
import '../../domain/suppliers/supplier.dart';
import 'sales_providers.dart';
import 'suppliers_providers.dart';

part 'purchases_providers.g.dart';

@riverpod
PurchaseRepository purchaseRepository(Ref ref) =>
    SupabasePurchaseRepository(ref.watch(supabaseClientProvider));

/// All suppliers for dropdowns, never filtered by the suppliers screen search.
@riverpod
Future<List<Supplier>> allSuppliers(Ref ref) async {
  final repo = ref.watch(supplierRepositoryProvider);
  return repo.listAll();
}

/// Current search term for the purchase invoice list (reactive).
@riverpod
class PurchaseSearch extends _$PurchaseSearch {
  @override
  String build() => '';

  void update(String term) => state = term;
}

/// Reactive list of purchase invoices.
@riverpod
class PurchaseInvoicesList extends _$PurchaseInvoicesList {
  @override
  Future<List<Invoice>> build() async {
    final search = ref.watch(purchaseSearchProvider);
    return ref.watch(invoiceRepositoryProvider).list(
          type: 'purchase',
          search: search.isEmpty ? null : search,
        );
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
  }
}