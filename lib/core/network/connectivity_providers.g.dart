// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'connectivity_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider for the ConnectivityService instance

@ProviderFor(connectivityService)
final connectivityServiceProvider = ConnectivityServiceProvider._();

/// Provider for the ConnectivityService instance

final class ConnectivityServiceProvider
    extends
        $FunctionalProvider<
          ConnectivityService,
          ConnectivityService,
          ConnectivityService
        >
    with $Provider<ConnectivityService> {
  /// Provider for the ConnectivityService instance
  ConnectivityServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'connectivityServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$connectivityServiceHash();

  @$internal
  @override
  $ProviderElement<ConnectivityService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ConnectivityService create(Ref ref) {
    return connectivityService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ConnectivityService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ConnectivityService>(value),
    );
  }
}

String _$connectivityServiceHash() =>
    r'77a78669645b8e8c63aa2e9f923f142251e3da52';

/// Stream provider that emits connectivity changes

@ProviderFor(connectivityStream)
final connectivityStreamProvider = ConnectivityStreamProvider._();

/// Stream provider that emits connectivity changes

final class ConnectivityStreamProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ConnectivityResult>>,
          List<ConnectivityResult>,
          Stream<List<ConnectivityResult>>
        >
    with
        $FutureModifier<List<ConnectivityResult>>,
        $StreamProvider<List<ConnectivityResult>> {
  /// Stream provider that emits connectivity changes
  ConnectivityStreamProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'connectivityStreamProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$connectivityStreamHash();

  @$internal
  @override
  $StreamProviderElement<List<ConnectivityResult>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<ConnectivityResult>> create(Ref ref) {
    return connectivityStream(ref);
  }
}

String _$connectivityStreamHash() =>
    r'dd89676411a3811cd03b3c4dcb12115d5219d289';

/// Provider that holds the current connectivity state (rebuilds on change)

@ProviderFor(ConnectivityState)
final connectivityStateProvider = ConnectivityStateProvider._();

/// Provider that holds the current connectivity state (rebuilds on change)
final class ConnectivityStateProvider
    extends $NotifierProvider<ConnectivityState, List<ConnectivityResult>> {
  /// Provider that holds the current connectivity state (rebuilds on change)
  ConnectivityStateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'connectivityStateProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$connectivityStateHash();

  @$internal
  @override
  ConnectivityState create() => ConnectivityState();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<ConnectivityResult> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<ConnectivityResult>>(value),
    );
  }
}

String _$connectivityStateHash() => r'88321c8ff5f294882888d475efbdc45c49ec0feb';

/// Provider that holds the current connectivity state (rebuilds on change)

abstract class _$ConnectivityState extends $Notifier<List<ConnectivityResult>> {
  List<ConnectivityResult> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<List<ConnectivityResult>, List<ConnectivityResult>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<List<ConnectivityResult>, List<ConnectivityResult>>,
              List<ConnectivityResult>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Convenience provider: true if device has a network interface (instant, may be false positive)

@ProviderFor(hasInterface)
final hasInterfaceProvider = HasInterfaceProvider._();

/// Convenience provider: true if device has a network interface (instant, may be false positive)

final class HasInterfaceProvider extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Convenience provider: true if device has a network interface (instant, may be false positive)
  HasInterfaceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'hasInterfaceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$hasInterfaceHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return hasInterface(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$hasInterfaceHash() => r'd43f433ef2afd2eb68ae56df8443a7c914c3a832';

/// Provider that emits verified online status (interface + HTTP check)

@ProviderFor(VerifiedOnline)
final verifiedOnlineProvider = VerifiedOnlineProvider._();

/// Provider that emits verified online status (interface + HTTP check)
final class VerifiedOnlineProvider
    extends $AsyncNotifierProvider<VerifiedOnline, bool> {
  /// Provider that emits verified online status (interface + HTTP check)
  VerifiedOnlineProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'verifiedOnlineProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$verifiedOnlineHash();

  @$internal
  @override
  VerifiedOnline create() => VerifiedOnline();
}

String _$verifiedOnlineHash() => r'65f6673494fa30565b190f035bdaf9c3008a7e40';

/// Provider that emits verified online status (interface + HTTP check)

abstract class _$VerifiedOnline extends $AsyncNotifier<bool> {
  FutureOr<bool> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<bool>, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<bool>, bool>,
              AsyncValue<bool>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Convenience provider: true if verified online (interface + HTTP check)

@ProviderFor(isOnline)
final isOnlineProvider = IsOnlineProvider._();

/// Convenience provider: true if verified online (interface + HTTP check)

final class IsOnlineProvider extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Convenience provider: true if verified online (interface + HTTP check)
  IsOnlineProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'isOnlineProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$isOnlineHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return isOnline(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$isOnlineHash() => r'045ed046340508dcae28922a4a33d72658604e90';
