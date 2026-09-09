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

String _$connectivityStateHash() => r'606f4595f982843ef56fa02937afd2429fcf389c';

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

/// Convenience provider: true if device has internet connection

@ProviderFor(isOnline)
final isOnlineProvider = IsOnlineProvider._();

/// Convenience provider: true if device has internet connection

final class IsOnlineProvider extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Convenience provider: true if device has internet connection
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

String _$isOnlineHash() => r'bba79b0b7e6e37067967ec0d3121228b68e450b0';
