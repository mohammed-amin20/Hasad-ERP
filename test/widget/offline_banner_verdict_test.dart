import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasad_erp/core/network/connectivity_providers.dart';
import 'package:hasad_erp/core/network/connectivity_service.dart';
import 'package:hasad_erp/core/theme/app_theme.dart';
import 'package:hasad_erp/presentation/widgets/retry_widgets.dart';

/// A probe whose answer the test can flip between calls. Drives the real
/// `ConnectivityService` -> `verifiedOnlineProvider` -> `isOnlineProvider`
/// chain, so no network is touched and `ConnectivityListener` (which needs the
/// platform channel) stays out of the picture.
class _SwitchableProbe {
  bool reachable;

  _SwitchableProbe(this.reachable);

  int calls = 0;

  Future<bool> call(Uri url, Duration timeout) async {
    calls++;
    return reachable;
  }

  ConnectivityProbe get asProbe => call;
}

/// Riverpod 3 does not publicly export the `Override` type, so the override
/// list is built inline where its type is inferred from the parameter.
ConnectivityService _service(_SwitchableProbe probe) =>
    ConnectivityService(Connectivity(), probe: probe.asProbe);

const _home = Scaffold(
  body: Column(children: [OfflineBanner(), Expanded(child: SizedBox())]),
);

void main() {
  testWidgets('a reachable backend shows no banner', (tester) async {
    final probe = _SwitchableProbe(true);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          connectivityServiceProvider.overrideWithValue(_service(probe)),
        ],
        child: MaterialApp(theme: AppTheme.light, home: _home),
      ),
    );
    await tester.pumpAndSettle();

    expect(probe.calls, greaterThan(0), reason: 'the probe should have run');
    expect(find.textContaining('غير متصل'), findsNothing);
  });

  testWidgets('a single failed probe shows no banner (two-strike debounce)',
      (tester) async {
    // The regression this pins: one failed probe used to raise a red
    // "you are offline" bar immediately, even on a healthy connection.
    final probe = _SwitchableProbe(false);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          connectivityServiceProvider.overrideWithValue(_service(probe)),
        ],
        child: MaterialApp(theme: AppTheme.light, home: _home),
      ),
    );
    await tester.pumpAndSettle();

    expect(probe.calls, 1);
    expect(find.textContaining('غير متصل'), findsNothing);
  });

  testWidgets('two consecutive failed probes show the banner, recovery hides it',
      (tester) async {
    final probe = _SwitchableProbe(false);
    final container = ProviderContainer(
      overrides: [
        connectivityServiceProvider.overrideWithValue(_service(probe)),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: AppTheme.light, home: _home),
      ),
    );

    await container.read(verifiedOnlineProvider.future);
    await tester.pumpAndSettle();
    expect(find.textContaining('غير متصل'), findsNothing,
        reason: 'one failure is not enough');

    await container.read(verifiedOnlineProvider.notifier).reverify();
    await tester.pumpAndSettle();
    expect(find.textContaining('غير متصل'), findsOneWidget,
        reason: 'two consecutive failures confirm offline');

    probe.reachable = true;
    await container.read(verifiedOnlineProvider.notifier).reverify();
    await tester.pumpAndSettle();
    expect(find.textContaining('غير متصل'), findsNothing,
        reason: 'recovery back online is instant');
  });
}
