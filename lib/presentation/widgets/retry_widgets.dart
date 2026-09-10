import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/connectivity_providers.dart';

/// Banner shown when device is offline
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider);
    
    if (isOnline) return const SizedBox.shrink();
    
    return Material(
      color: const Color(0xFFDC2626), // danger red
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 36,
          width: double.infinity,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi_off, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Text(
                  'أنت غير متصل بالإنترنت — سيتم مزامنة البيانات عند عودة الاتصال',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Inline retry button for failed async operations
class RetryButton extends StatelessWidget {
  const RetryButton({
    required this.onRetry,
    this.label = 'إعادة المحاولة',
    this.icon = Icons.refresh,
    super.key,
  });

  final VoidCallback onRetry;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onRetry,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF2563EB), // primary
        side: const BorderSide(color: Color(0xFF2563EB)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

/// Wrapper for async operations that shows loading/error/retry states
class AsyncOperationWrapper<T> extends ConsumerWidget {
  const AsyncOperationWrapper({
    required this.operation,
    required this.onSuccess,
    this.onError,
    this.loadingWidget,
    this.errorWidget,
    super.key,
  });

  final Future<T> Function() operation;
  final void Function(T result) onSuccess;
  final void Function(Object error)? onError;
  final Widget? loadingWidget;
  final Widget? errorWidget;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<T>(
      future: operation(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return loadingWidget ?? const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          final error = snapshot.error!;
          if (onError != null) {
            onError!(error);
          }
          return errorWidget ?? _defaultErrorWidget(context, error);
        }
        
        if (snapshot.hasData) {
          final data = snapshot.data;
          // Use post-frame callback to avoid build-phase side effects
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (data != null) onSuccess(data);
          });
          return const SizedBox.shrink();
        }
        
        return const SizedBox.shrink();
      },
    );
  }

  Widget _defaultErrorWidget(BuildContext context, Object error) {
    final isNetwork = error.toString().contains('SocketException') || 
                      error.toString().contains('TimeoutException') ||
                      error.toString().contains('NetworkException');
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isNetwork ? Icons.wifi_off : Icons.error_outline,
              size: 48,
              color: isNetwork ? const Color(0xFFF59E0B) : const Color(0xFFDC2626),
            ),
            const SizedBox(height: 16),
            Text(
              isNetwork 
                  ? 'تعذر الاتصال بالخادم'
                  : 'حدث خطأ غير متوقع',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF64748B),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            RetryButton(
              onRetry: () {
                // Trigger rebuild by using a key change or state update
                // In practice, parent should manage this via a key or state
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Mixin for providers that want automatic retry on network errors
/// Usage: mixin on your AutoDisposeAsyncNotifier class
mixin RetryableProviderMixin<T> {
  static const int maxRetries = 3;
  static const Duration baseDelay = Duration(seconds: 1);
  
  Future<T> executeWithRetry(Future<T> Function() operation, {int attempt = 1}) async {
    try {
      return await operation();
    } catch (e) {
      if (attempt >= maxRetries) rethrow;
      
      final isNetworkError = e.toString().contains('SocketException') ||
                             e.toString().contains('TimeoutException') ||
                             e.toString().contains('NetworkException');
      
      if (!isNetworkError) rethrow;
      
      // Exponential backoff
      final delay = baseDelay * (1 << (attempt - 1));
      await Future.delayed(delay);
      
      return executeWithRetry(operation, attempt: attempt + 1);
    }
  }
}