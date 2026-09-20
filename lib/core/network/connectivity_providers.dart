import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'connectivity_service.dart';

/// Provides the singleton [ConnectivityService]; tares the underlying stream
/// controller and heartbeat on teardown.
final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  final service = ConnectivityService(Connectivity());
  ref.onDispose(() => service.dispose());
  return service;
});

/// Stream provider that emits connectivity changes.
final connectivityStreamProvider =
    StreamProvider<List<ConnectivityResult>>((ref) {
  final service = ref.watch(connectivityServiceProvider);
  return service.onConnectivityChanged;
});

/// Notifier holding the latest raw interface result list; consumers call
/// `.notifier.update(...)` from the stream listener.
class ConnectivityState extends Notifier<List<ConnectivityResult>> {
  @override
  List<ConnectivityResult> build() {
    ref.watch(connectivityStreamProvider);
    return const <ConnectivityResult>[ConnectivityResult.none];
  }

  void update(List<ConnectivityResult> result) => state = result;
}

final connectivityStateProvider =
    NotifierProvider<ConnectivityState, List<ConnectivityResult>>(
  ConnectivityState.new,
);

/// True when any network interface is present (instant; false positives possible).
final hasInterfaceProvider = Provider<bool>((ref) {
  final state = ref.watch(connectivityStateProvider);
  return state.any((r) => r != ConnectivityResult.none);
});

/// Verified online status: interface + HTTP check with hysteresis. Optimistic
/// default (true) so the app starts "online" and only flips offline after
/// consecutive failed probes; [reverify] re-runs the check on demand.
class VerifiedOnline extends AsyncNotifier<bool> {
  @override
  Future<bool> build() {
    final service = ref.watch(connectivityServiceProvider);
    return service.verifyInternetConnectivity();
  }

  Future<void> reverify() async {
    state = const AsyncLoading();
    final service = ref.read(connectivityServiceProvider);
    final result = await service.verifyInternetConnectivity();
    state = AsyncData<bool>(result);
  }
}

final verifiedOnlineProvider =
    AsyncNotifierProvider<VerifiedOnline, bool>(VerifiedOnline.new);

/// Online banner gate: optimistic default `true` so the offline banner is
/// hidden until the heartbeat proves we are offline.
final isOnlineProvider = Provider<bool>((ref) {
  final verified = ref.watch(verifiedOnlineProvider);
  return verified.value ?? true;
});
