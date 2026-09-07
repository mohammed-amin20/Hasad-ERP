// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sales_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(saleRepository)
final saleRepositoryProvider = SaleRepositoryProvider._();

final class SaleRepositoryProvider
    extends $FunctionalProvider<SaleRepository, SaleRepository, SaleRepository>
    with $Provider<SaleRepository> {
  SaleRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'saleRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$saleRepositoryHash();

  @$internal
  @override
  $ProviderElement<SaleRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SaleRepository create(Ref ref) {
    return saleRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SaleRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SaleRepository>(value),
    );
  }
}

String _$saleRepositoryHash() => r'2d56d75f04d03a124bc0d043befd68fa7ccb4899';

@ProviderFor(invoiceRepository)
final invoiceRepositoryProvider = InvoiceRepositoryProvider._();

final class InvoiceRepositoryProvider
    extends
        $FunctionalProvider<
          InvoiceRepository,
          InvoiceRepository,
          InvoiceRepository
        >
    with $Provider<InvoiceRepository> {
  InvoiceRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'invoiceRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$invoiceRepositoryHash();

  @$internal
  @override
  $ProviderElement<InvoiceRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  InvoiceRepository create(Ref ref) {
    return invoiceRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(InvoiceRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<InvoiceRepository>(value),
    );
  }
}

String _$invoiceRepositoryHash() => r'fe0ff4c62f9b1097222a9f741dfaaf3e3cfd1097';

/// All customers for dropdowns, never filtered by the customers screen search.

@ProviderFor(allCustomers)
final allCustomersProvider = AllCustomersProvider._();

/// All customers for dropdowns, never filtered by the customers screen search.

final class AllCustomersProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Customer>>,
          List<Customer>,
          FutureOr<List<Customer>>
        >
    with $FutureModifier<List<Customer>>, $FutureProvider<List<Customer>> {
  /// All customers for dropdowns, never filtered by the customers screen search.
  AllCustomersProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'allCustomersProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$allCustomersHash();

  @$internal
  @override
  $FutureProviderElement<List<Customer>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Customer>> create(Ref ref) {
    return allCustomers(ref);
  }
}

String _$allCustomersHash() => r'6278163e05b67746d636d44600cfed0c2d07e32f';

/// Current search term for the sale invoice list (reactive).

@ProviderFor(SaleSearch)
final saleSearchProvider = SaleSearchProvider._();

/// Current search term for the sale invoice list (reactive).
final class SaleSearchProvider extends $NotifierProvider<SaleSearch, String> {
  /// Current search term for the sale invoice list (reactive).
  SaleSearchProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'saleSearchProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$saleSearchHash();

  @$internal
  @override
  SaleSearch create() => SaleSearch();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$saleSearchHash() => r'33f8e441e731438659d3896aa202e112c6c5831e';

/// Current search term for the sale invoice list (reactive).

abstract class _$SaleSearch extends $Notifier<String> {
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

/// Reactive list of sale invoices.

@ProviderFor(SaleInvoicesList)
final saleInvoicesListProvider = SaleInvoicesListProvider._();

/// Reactive list of sale invoices.
final class SaleInvoicesListProvider
    extends $AsyncNotifierProvider<SaleInvoicesList, List<Invoice>> {
  /// Reactive list of sale invoices.
  SaleInvoicesListProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'saleInvoicesListProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$saleInvoicesListHash();

  @$internal
  @override
  SaleInvoicesList create() => SaleInvoicesList();
}

String _$saleInvoicesListHash() => r'eed8c9b3c82b42587ac430575a7a8f18a747b568';

/// Reactive list of sale invoices.

abstract class _$SaleInvoicesList extends $AsyncNotifier<List<Invoice>> {
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
