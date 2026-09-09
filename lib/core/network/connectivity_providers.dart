import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    final stream = ref.watch(connectivityStreamProvider);
    ref.onDispose(() {});
    return <ConnectivityResult>[ConnectivityResult.none];
  }

  /// Call this to update state from the stream listener
  void update(List<ConnectivityResult> result) => state = result;
}

/// Convenience provider: true if device has internet connection
@riverpod
bool isOnline(Ref ref) {
  final state = ref.watch(connectivityStateProvider);
  return state.any((r) => r != ConnectivityResult.none);
}