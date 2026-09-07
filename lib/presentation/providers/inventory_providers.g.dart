// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'inventory_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(inventoryRepository)
final inventoryRepositoryProvider = InventoryRepositoryProvider._();

final class InventoryRepositoryProvider
    extends
        $FunctionalProvider<
          InventoryRepository,
          InventoryRepository,
          InventoryRepository
        >
    with $Provider<InventoryRepository> {
  InventoryRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'inventoryRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$inventoryRepositoryHash();

  @$internal
  @override
  $ProviderElement<InventoryRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  InventoryRepository create(Ref ref) {
    return inventoryRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(InventoryRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<InventoryRepository>(value),
    );
  }
}

String _$inventoryRepositoryHash() =>
    r'b8564fb7166a9e14fbfd189fa163ba905897bcd5';

/// All products with their live quantities (no search filter), for the
/// inventory screen.

@ProviderFor(inventoryProducts)
final inventoryProductsProvider = InventoryProductsProvider._();

/// All products with their live quantities (no search filter), for the
/// inventory screen.

final class InventoryProductsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Product>>,
          List<Product>,
          FutureOr<List<Product>>
        >
    with $FutureModifier<List<Product>>, $FutureProvider<List<Product>> {
  /// All products with their live quantities (no search filter), for the
  /// inventory screen.
  InventoryProductsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'inventoryProductsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$inventoryProductsHash();

  @$internal
  @override
  $FutureProviderElement<List<Product>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Product>> create(Ref ref) {
    return inventoryProducts(ref);
  }
}

String _$inventoryProductsHash() => r'2c242cd6773316ed27917d4a873b638aab3c9a63';

/// The most recent physical-count result, null until a count is submitted.

@ProviderFor(LastAdjust)
final lastAdjustProvider = LastAdjustProvider._();

/// The most recent physical-count result, null until a count is submitted.
final class LastAdjustProvider
    extends $NotifierProvider<LastAdjust, StockAdjustResult?> {
  /// The most recent physical-count result, null until a count is submitted.
  LastAdjustProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'lastAdjustProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$lastAdjustHash();

  @$internal
  @override
  LastAdjust create() => LastAdjust();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(StockAdjustResult? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<StockAdjustResult?>(value),
    );
  }
}

String _$lastAdjustHash() => r'e4b11a6897566d6e6efcd394fb7b8287e6b7a377';

/// The most recent physical-count result, null until a count is submitted.

abstract class _$LastAdjust extends $Notifier<StockAdjustResult?> {
  StockAdjustResult? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<StockAdjustResult?, StockAdjustResult?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<StockAdjustResult?, StockAdjustResult?>,
              StockAdjustResult?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
