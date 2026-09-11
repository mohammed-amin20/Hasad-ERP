import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'connectivity_service.dart';

part 'connectivity_providers.g.dart';

/// Provider for the ConnectivityService instance
@riverpod
ConnectivityService connectivityService(Ref ref) {
  final service = ConnectivityService(Connectivity());
  ref.onDispose(() => service.dispose());
  return service;
}

/// Stream provider that emits connectivity changes
@riverpod
Stream<List<ConnectivityResult>> connectivityStream(Ref ref) {
  final service = ref.watch(connectivityServiceProvider);
  return service.onConnectivityChanged;
}

/// Provider that holds the current connectivity state (rebuilds on change)
@riverpod
class ConnectivityState extends _$ConnectivityState {
  @override
  List<ConnectivityResult> build() {
    ref.watch(connectivityStreamProvider);
    ref.onDispose(() {});
    return <ConnectivityResult>[ConnectivityResult.none];
  }

  /// Call this to update state from the stream listener
  void update(List<ConnectivityResult> result) => state = result;
}

/// Convenience provider: true if device has a network interface (instant, may be false positive)
@riverpod
bool hasInterface(Ref ref) {
  final state = ref.watch(connectivityStateProvider);
  return state.any((r) => r != ConnectivityResult.none);
}

/// Provider that emits verified online status (interface + HTTP check)
@riverpod
class VerifiedOnline extends _$VerifiedOnline {
  @override
  Future<bool> build() async {
    final service = ref.watch(connectivityServiceProvider);
    // Trigger initial verification
    return service.verifyInternetConnectivity();
  }

  /// Call to manually re-verify
  Future<void> reverify() async {
    final service = ref.read(connectivityServiceProvider);
    state = const AsyncLoading();
    final result = await service.verifyInternetConnectivity();
    state = AsyncData(result);
  }
}

/// Convenience provider: true if verified online (interface + HTTP check)
@riverpod
bool isOnline(Ref ref) {
  final async = ref.watch(verifiedOnlineProvider);
  return async.value ?? false;
}
