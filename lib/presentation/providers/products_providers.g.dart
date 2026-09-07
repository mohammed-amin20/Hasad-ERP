// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'products_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Concrete product repository wired to Supabase.

@ProviderFor(productRepository)
final productRepositoryProvider = ProductRepositoryProvider._();

/// Concrete product repository wired to Supabase.

final class ProductRepositoryProvider
    extends
        $FunctionalProvider<
          ProductRepository,
          ProductRepository,
          ProductRepository
        >
    with $Provider<ProductRepository> {
  /// Concrete product repository wired to Supabase.
  ProductRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'productRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$productRepositoryHash();

  @$internal
  @override
  $ProviderElement<ProductRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ProductRepository create(Ref ref) {
    return productRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ProductRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ProductRepository>(value),
    );
  }
}

String _$productRepositoryHash() => r'3555e387cb81ed7f33aa6801a8fb0419df0d5902';

/// Current search term for the product list (reactive).

@ProviderFor(ProductSearch)
final productSearchProvider = ProductSearchProvider._();

/// Current search term for the product list (reactive).
final class ProductSearchProvider
    extends $NotifierProvider<ProductSearch, String> {
  /// Current search term for the product list (reactive).
  ProductSearchProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'productSearchProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$productSearchHash();

  @$internal
  @override
  ProductSearch create() => ProductSearch();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$productSearchHash() => r'85bb46f9886df4ee143182595510a51755d8bdde';

/// Current search term for the product list (reactive).

abstract class _$ProductSearch extends $Notifier<String> {
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

/// Reactive list of products, filtered by [ProductSearch].

@ProviderFor(ProductsList)
final productsListProvider = ProductsListProvider._();

/// Reactive list of products, filtered by [ProductSearch].
final class ProductsListProvider
    extends $AsyncNotifierProvider<ProductsList, List<Product>> {
  /// Reactive list of products, filtered by [ProductSearch].
  ProductsListProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'productsListProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$productsListHash();

  @$internal
  @override
  ProductsList create() => ProductsList();
}

String _$productsListHash() => r'3bed769a5bdf547df1214a50641df8d6c69a04a1';

/// Reactive list of products, filtered by [ProductSearch].

abstract class _$ProductsList extends $AsyncNotifier<List<Product>> {
  FutureOr<List<Product>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<Product>>, List<Product>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<Product>>, List<Product>>,
              AsyncValue<List<Product>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
