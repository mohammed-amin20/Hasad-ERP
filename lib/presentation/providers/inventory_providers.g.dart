// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'inventory_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Inventory repository — offline-first. A count routes through an
/// [OfflineWriteCoordinator] when a local store + tenant exist (local-first,
/// queued for replay), else falls back to Supabase.
///
/// The coordinator needs no chart seed here: `adjust_inventory` does not post a
/// journal, so [OfflineWriteCoordinator.adjustInventory] never reads the chart.

@ProviderFor(inventoryRepository)
final inventoryRepositoryProvider = InventoryRepositoryProvider._();

/// Inventory repository — offline-first. A count routes through an
/// [OfflineWriteCoordinator] when a local store + tenant exist (local-first,
/// queued for replay), else falls back to Supabase.
///
/// The coordinator needs no chart seed here: `adjust_inventory` does not post a
/// journal, so [OfflineWriteCoordinator.adjustInventory] never reads the chart.

final class InventoryRepositoryProvider
    extends
        $FunctionalProvider<
          InventoryRepository,
          InventoryRepository,
          InventoryRepository
        >
    with $Provider<InventoryRepository> {
  /// Inventory repository — offline-first. A count routes through an
  /// [OfflineWriteCoordinator] when a local store + tenant exist (local-first,
  /// queued for replay), else falls back to Supabase.
  ///
  /// The coordinator needs no chart seed here: `adjust_inventory` does not post a
  /// journal, so [OfflineWriteCoordinator.adjustInventory] never reads the chart.
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
    r'36bac17e4cb91e0321d6f393ce09a6b522e4e42f';

/// True when counts are local-first (a local store + tenant exist, so an
/// adjustment moves the mirror and queues). The UI reads this to show the
/// offline pending message instead of the online confirmation.

@ProviderFor(inventoryWritesLocalFirst)
final inventoryWritesLocalFirstProvider = InventoryWritesLocalFirstProvider._();

/// True when counts are local-first (a local store + tenant exist, so an
/// adjustment moves the mirror and queues). The UI reads this to show the
/// offline pending message instead of the online confirmation.

final class InventoryWritesLocalFirstProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// True when counts are local-first (a local store + tenant exist, so an
  /// adjustment moves the mirror and queues). The UI reads this to show the
  /// offline pending message instead of the online confirmation.
  InventoryWritesLocalFirstProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'inventoryWritesLocalFirstProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$inventoryWritesLocalFirstHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return inventoryWritesLocalFirst(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$inventoryWritesLocalFirstHash() =>
    r'9ba695918464456d11cc4171ce47eae2336c9c85';

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
///
/// **`keepAlive: true` is load-bearing, not an optimisation.** The count sheet
/// reaches this provider with `ref.read`, so nothing ever listens to it; an
/// auto-dispose provider with no listener is disposed as soon as the read
/// returns. The local-first write is a real drift transaction, and the device
/// store runs on a background isolate, so by the time `await repo.adjust`
/// completes the provider has been disposed — and `state = result` then throws
/// `UnmountedRefException`. That is an unmapped `Object`, so a count that had
/// already committed locally and queued its leg reported «حدث خطأ غير متوقع».
/// Same rule as [PaymentActions] / [SalaryActions].

@ProviderFor(LastAdjust)
final lastAdjustProvider = LastAdjustProvider._();

/// The most recent physical-count result, null until a count is submitted.
///
/// **`keepAlive: true` is load-bearing, not an optimisation.** The count sheet
/// reaches this provider with `ref.read`, so nothing ever listens to it; an
/// auto-dispose provider with no listener is disposed as soon as the read
/// returns. The local-first write is a real drift transaction, and the device
/// store runs on a background isolate, so by the time `await repo.adjust`
/// completes the provider has been disposed — and `state = result` then throws
/// `UnmountedRefException`. That is an unmapped `Object`, so a count that had
/// already committed locally and queued its leg reported «حدث خطأ غير متوقع».
/// Same rule as [PaymentActions] / [SalaryActions].
final class LastAdjustProvider
    extends $NotifierProvider<LastAdjust, StockAdjustResult?> {
  /// The most recent physical-count result, null until a count is submitted.
  ///
  /// **`keepAlive: true` is load-bearing, not an optimisation.** The count sheet
  /// reaches this provider with `ref.read`, so nothing ever listens to it; an
  /// auto-dispose provider with no listener is disposed as soon as the read
  /// returns. The local-first write is a real drift transaction, and the device
  /// store runs on a background isolate, so by the time `await repo.adjust`
  /// completes the provider has been disposed — and `state = result` then throws
  /// `UnmountedRefException`. That is an unmapped `Object`, so a count that had
  /// already committed locally and queued its leg reported «حدث خطأ غير متوقع».
  /// Same rule as [PaymentActions] / [SalaryActions].
  LastAdjustProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'lastAdjustProvider',
        isAutoDispose: false,
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

String _$lastAdjustHash() => r'c3b9d13fb24a3436b8c5a1e201a81b7984bb06a5';

/// The most recent physical-count result, null until a count is submitted.
///
/// **`keepAlive: true` is load-bearing, not an optimisation.** The count sheet
/// reaches this provider with `ref.read`, so nothing ever listens to it; an
/// auto-dispose provider with no listener is disposed as soon as the read
/// returns. The local-first write is a real drift transaction, and the device
/// store runs on a background isolate, so by the time `await repo.adjust`
/// completes the provider has been disposed — and `state = result` then throws
/// `UnmountedRefException`. That is an unmapped `Object`, so a count that had
/// already committed locally and queued its leg reported «حدث خطأ غير متوقع».
/// Same rule as [PaymentActions] / [SalaryActions].

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
