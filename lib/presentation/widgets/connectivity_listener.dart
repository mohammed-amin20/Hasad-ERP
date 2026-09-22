import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../../core/network/connectivity_providers.dart';
import '../providers/offline_sync_providers.dart';

/// A widget that listens to connectivity changes and updates the [ConnectivityState] provider.
/// Place this at the root of your widget tree (e.g., inside AppShell or MaterialApp).
class ConnectivityListener extends ConsumerStatefulWidget {
  const ConnectivityListener({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<ConnectivityListener> createState() =>
      _ConnectivityListenerState();
}

class _ConnectivityListenerState extends ConsumerState<ConnectivityListener> {
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  @override
  void initState() {
    super.initState();
    // Listen to the stream directly from the service
    final service = ref.read(connectivityServiceProvider);
    _subscription = service.onConnectivityChanged.listen((result) {
      if (mounted) {
        ref.read(connectivityStateProvider.notifier).update(result);
        // Trigger verification on ANY change (including full offline) — the
        // browser's instant navigator.onLine fast-path inside
        // verifyInternetConnectivity flips the mood offline immediately
        // instead of waiting for the next 30s periodic probe.
        ref.read(verifiedOnlineProvider.notifier).reverify();
      }
    });
    // Initialize with current connectivity (fire-and-forget)
    service.initialize().then((_) {
      if (mounted) {
        ref.read(connectivityStateProvider.notifier).update(service.lastResult);
        if (service.hasInterface) {
          ref.read(verifiedOnlineProvider.notifier).reverify();
        }
      }
    });
    // ignore: unawaited_futures
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<bool>>(verifiedOnlineProvider, (previous, next) {
      final wasOnline = previous?.value ?? false;
      final isOnline = next.value ?? false;
      if (isOnline && !wasOnline) {
        // Edge back online: drain the tenant's pending queue (with backoff)
        // without waiting for a manual tap.
        unawaited(ref.read(autoSyncRunnerProvider).kick());
      }
    });
    return widget.child;
  }
}
