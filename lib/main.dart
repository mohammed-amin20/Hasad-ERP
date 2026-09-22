import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/supabase_client.dart';
import 'presentation/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HasadSupabase.initialize();

  if (kDebugMode) {
    // Debug-only global error surface so a null-check / any uncaught exception
    // shows the real stack trace instead of a silent red box. This is how we
    // pinpointed the "العملاء" null-check crash without guessing.
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      // Also log to the console so `flutter run` (or `-d chrome`) shows it.
      debugPrint('$details');
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      debugPrint(
        'Uncaught platform error:\n$error\n${stack.toString()}',
      );
      return true;
    };
    ErrorWidget.builder = (details) => _DebugErrorSurface(details);
  }

  runZonedGuarded(
    () => runApp(const ProviderScope(child: HasadApp())),
    (error, stack) {
      if (kDebugMode) {
        debugPrint(
          'Zoned uncaught error:\n$error\n${stack.toString()}',
        );
      } else {
        // Production: send to whatever the current error-tracking hooks use.
        debugPrint('Uncaught async error: $error');
      }
    },
  );
}

/// Debug-only replacement for the default grey/red ErrorWidget — renders the
/// exception *and* the first meaningful stack frame so the offending line is
/// visible directly on screen.
class _DebugErrorSurface extends StatelessWidget {
  const _DebugErrorSurface(this.details);

  final FlutterErrorDetails details;

  @override
  Widget build(BuildContext context) {
    final summary = details.exceptionAsString();
    final stack = details.stack?.toString() ?? '';
    // Take the first few frames that point into lib/ — that's where the bug is.
    final traceLines = stack
        .split('\n')
        .where((l) => l.contains('package:hasad_erp'))
        .take(12)
        .join('\n');

    return Material(
      color: const Color(0xFFB71C1C),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'حدث خطأ — تفاصيل (وضع التطوير فقط)',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  summary,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  traceLines.isEmpty ? stack : traceLines,
                  style: const TextStyle(
                    color: Color(0xFFFFD54F),
                    fontSize: 12,
                    fontFamily: 'monospace',
                    height: 1.4,
                  ),
                  textDirection: TextDirection.ltr,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
