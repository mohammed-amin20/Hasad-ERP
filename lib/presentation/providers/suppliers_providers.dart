import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/supabase_client.dart';
import '../../data/suppliers/supabase_supplier_repository.dart';
import '../../domain/suppliers/supplier.dart';
import '../../domain/suppliers/supplier_draft.dart';
import '../../domain/suppliers/supplier_repository.dart';

part 'suppliers_providers.g.dart';

/// Concrete supplier repository wired to Supabase.
@riverpod
SupplierRepository supplierRepository(Ref ref) =>
    SupabaseSupplierRepository(ref.watch(supabaseClientProvider));

/// Current search term for the supplier list (reactive).
@riverpod
class SupplierSearch extends _$SupplierSearch {
  @override
  String build() => '';

  void update(String term) => state = term;
}

/// Reactive list of suppliers, filtered by [SupplierSearch].
@riverpod
class SuppliersList extends _$SuppliersList {
  @override
  Future<List<Supplier>> build() async {
    final search = ref.watch(supplierSearchProvider);
    final repo = ref.watch(supplierRepositoryProvider);
    return repo.listAll(search: search.isEmpty ? null : search);
  }

  /// Create a new supplier, then refresh the list.
  Future<Supplier> create(SupplierDraft draft) async {
    final repo = ref.read(supplierRepositoryProvider);
    final supplier = await repo.create(draft);
    ref.invalidateSelf();
    return supplier;
  }

  /// Update an existing supplier, then refresh the list.
  Future<void> updateSupplier({
    required String id,
    required SupplierDraft draft,
  }) async {
    final repo = ref.read(supplierRepositoryProvider);
    await repo.update(id: id, draft: draft);
    ref.invalidateSelf();
  }

  /// Delete a supplier, then refresh the list.
  Future<void> delete(String id) async {
    final repo = ref.read(supplierRepositoryProvider);
    await repo.delete(id);
    ref.invalidateSelf();
  }
}