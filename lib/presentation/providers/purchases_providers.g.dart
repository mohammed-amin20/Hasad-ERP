// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'purchases_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(purchaseRepository)
final purchaseRepositoryProvider = PurchaseRepositoryProvider._();

final class PurchaseRepositoryProvider
    extends
        $FunctionalProvider<
          PurchaseRepository,
          PurchaseRepository,
          PurchaseRepository
        >
    with $Provider<PurchaseRepository> {
  PurchaseRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'purchaseRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$purchaseRepositoryHash();

  @$internal
  @override
  $ProviderElement<PurchaseRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PurchaseRepository create(Ref ref) {
    return purchaseRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PurchaseRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PurchaseRepository>(value),
    );
  }
}

String _$purchaseRepositoryHash() =>
    r'2f73e56a5ac6bf88e6cfd77ffc426bc9bef931b5';

/// All suppliers for dropdowns, never filtered by the suppliers screen search.

@ProviderFor(allSuppliers)
final allSuppliersProvider = AllSuppliersProvider._();

/// All suppliers for dropdowns, never filtered by the suppliers screen search.

final class AllSuppliersProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Supplier>>,
          List<Supplier>,
          FutureOr<List<Supplier>>
        >
    with $FutureModifier<List<Supplier>>, $FutureProvider<List<Supplier>> {
  /// All suppliers for dropdowns, never filtered by the suppliers screen search.
  AllSuppliersProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'allSuppliersProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$allSuppliersHash();

  @$internal
  @override
  $FutureProviderElement<List<Supplier>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Supplier>> create(Ref ref) {
    return allSuppliers(ref);
  }
}

String _$allSuppliersHash() => r'bdd5ea03638ac308876b9262ed5de06d9bb9c3d4';

/// Current search term for the purchase invoice list (reactive).

@ProviderFor(PurchaseSearch)
final purchaseSearchProvider = PurchaseSearchProvider._();

/// Current search term for the purchase invoice list (reactive).
final class PurchaseSearchProvider
    extends $NotifierProvider<PurchaseSearch, String> {
  /// Current search term for the purchase invoice list (reactive).
  PurchaseSearchProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'purchaseSearchProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$purchaseSearchHash();

  @$internal
  @override
  PurchaseSearch create() => PurchaseSearch();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$purchaseSearchHash() => r'3540a91f839b37de1b09c3e2be8d7153dcf1bf74';

/// Current search term for the purchase invoice list (reactive).

abstract class _$PurchaseSearch extends $Notifier<String> {
  String build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<String, String>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String, String>,
              String,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Reactive list of purchase invoices.

@ProviderFor(PurchaseInvoicesList)
final purchaseInvoicesListProvider = PurchaseInvoicesListProvider._();

/// Reactive list of purchase invoices.
final class PurchaseInvoicesListProvider
    extends $AsyncNotifierProvider<PurchaseInvoicesList, List<Invoice>> {
  /// Reactive list of purchase invoices.
  PurchaseInvoicesListProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'purchaseInvoicesListProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$purchaseInvoicesListHash();

  @$internal
  @override
  PurchaseInvoicesList create() => PurchaseInvoicesList();
}

String _$purchaseInvoicesListHash() =>
    r'5db06ab5290f8e267362a089b4236e9950d68ec9';

/// Reactive list of purchase invoices.

abstract class _$PurchaseInvoicesList extends $AsyncNotifier<List<Invoice>> {
  FutureOr<List<Invoice>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<Invoice>>, List<Invoice>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<Invoice>>, List<Invoice>>,
              AsyncValue<List<Invoice>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
