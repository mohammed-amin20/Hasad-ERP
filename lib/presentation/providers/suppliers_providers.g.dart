// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'suppliers_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Concrete supplier repository wired to Supabase.

@ProviderFor(supplierRepository)
final supplierRepositoryProvider = SupplierRepositoryProvider._();

/// Concrete supplier repository wired to Supabase.

final class SupplierRepositoryProvider
    extends
        $FunctionalProvider<
          SupplierRepository,
          SupplierRepository,
          SupplierRepository
        >
    with $Provider<SupplierRepository> {
  /// Concrete supplier repository wired to Supabase.
  SupplierRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'supplierRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$supplierRepositoryHash();

  @$internal
  @override
  $ProviderElement<SupplierRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SupplierRepository create(Ref ref) {
    return supplierRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SupplierRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SupplierRepository>(value),
    );
  }
}

String _$supplierRepositoryHash() =>
    r'0f886d11c58b122dcc414d3b0c8f8f4dcda8aacf';

/// Current search term for the supplier list (reactive).

@ProviderFor(SupplierSearch)
final supplierSearchProvider = SupplierSearchProvider._();

/// Current search term for the supplier list (reactive).
final class SupplierSearchProvider
    extends $NotifierProvider<SupplierSearch, String> {
  /// Current search term for the supplier list (reactive).
  SupplierSearchProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'supplierSearchProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$supplierSearchHash();

  @$internal
  @override
  SupplierSearch create() => SupplierSearch();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$supplierSearchHash() => r'7e1a9e5b0f852fcd067e45d264273f96c7091991';

/// Current search term for the supplier list (reactive).

abstract class _$SupplierSearch extends $Notifier<String> {
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

/// Reactive list of suppliers, filtered by [SupplierSearch].

@ProviderFor(SuppliersList)
final suppliersListProvider = SuppliersListProvider._();

/// Reactive list of suppliers, filtered by [SupplierSearch].
final class SuppliersListProvider
    extends $AsyncNotifierProvider<SuppliersList, List<Supplier>> {
  /// Reactive list of suppliers, filtered by [SupplierSearch].
  SuppliersListProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'suppliersListProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$suppliersListHash();

  @$internal
  @override
  SuppliersList create() => SuppliersList();
}

String _$suppliersListHash() => r'484b66021f47384877fb473224b51584521fdeed';

/// Reactive list of suppliers, filtered by [SupplierSearch].

abstract class _$SuppliersList extends $AsyncNotifier<List<Supplier>> {
  FutureOr<List<Supplier>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<Supplier>>, List<Supplier>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<Supplier>>, List<Supplier>>,
              AsyncValue<List<Supplier>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
