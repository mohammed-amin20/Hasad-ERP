// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'navigation_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Index of the currently selected destination in the app shell.

@ProviderFor(CurrentDestination)
final currentDestinationProvider = CurrentDestinationProvider._();

/// Index of the currently selected destination in the app shell.
final class CurrentDestinationProvider
    extends $NotifierProvider<CurrentDestination, int> {
  /// Index of the currently selected destination in the app shell.
  CurrentDestinationProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentDestinationProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentDestinationHash();

  @$internal
  @override
  CurrentDestination create() => CurrentDestination();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$currentDestinationHash() =>
    r'b6f916a87e52f3c3ec82292494cc9b7db73a93d2';

/// Index of the currently selected destination in the app shell.

abstract class _$CurrentDestination extends $Notifier<int> {
  int build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<int, int>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<int, int>,
              int,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
