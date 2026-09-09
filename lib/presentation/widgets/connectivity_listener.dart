import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../../core/network/connectivity_providers.dart';

/// A widget that listens to connectivity changes and updates the [ConnectivityState] provider.
/// Place this at the root of your widget tree (e.g., inside AppShell or MaterialApp).
class ConnectivityListener extends ConsumerStatefulWidget {
  const ConnectivityListener({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<ConnectivityListener> createState() => _ConnectivityListenerState();
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
      }
    });
    // Initialize with current connectivity (fire-and-forget)
    service.initialize().then((_) {
      if (mounted) {
        ref.read(connectivityStateProvider.notifier).update(service.lastResult);
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
  Widget build(BuildContext context) => widget.child;
}