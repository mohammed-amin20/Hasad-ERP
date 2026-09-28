import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasad_erp/core/network/connectivity_providers.dart';
import 'package:hasad_erp/data/offline/local_store.dart';
import 'package:hasad_erp/data/offline/offline_sync.dart';
import 'package:hasad_erp/domain/auth/app_role.dart';
import 'package:hasad_erp/domain/auth/app_user.dart';
import 'package:hasad_erp/presentation/app.dart';
import 'package:hasad_erp/presentation/providers/auth_providers.dart';
import 'package:hasad_erp/presentation/providers/dashboard_providers.dart';
import 'package:hasad_erp/presentation/providers/offline_sync_providers.dart';
import 'package:hasad_erp/presentation/screens/auth/login_screen.dart';
import 'package:hasad_erp/presentation/widgets/no_workspace_view.dart';

import '../tool/shell_stubs.dart';

void main() {
  testWidgets('no-workspace user lands on NoWorkspaceView, not the shell',
      (tester) async {
    final user = AppUser(
      id: 'u1',
      email: 'orphan@test.local',
      role: AppRole.unknown,
      tenants: const [],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // M13 Phase 0: `HasadApp` gates its first frame on the local store
          // being open, so a test that does not stub it sits on the splash
          // screen. `path_provider` has no plugin implementation in a test
          // isolate, so the real provider would otherwise open a real file.
          localStoreProvider.overrideWith((ref) async => const NullLocalStore()),
          authStateProvider.overrideWith((ref) => Stream.value(user)),
        ],
        child: const HasadApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NoWorkspaceView), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
    expect(find.text('لا توجد منشأة بعد'), findsOneWidget);
  });

  testWidgets('tenant-bearing user goes straight to the shell',
      (tester) async {
    final user = AppUser(
      id: 'u1',
      email: 'owner@test.local',
      role: AppRole.admin,
      tenantId: 'ef95064e-b867-4b7f-bd98-36748066cc8c',
    );
    // The flusher needs a real store; NullLocalStore is enough because the
    // stubbed sync target never replays anything.
    const store = NullLocalStore();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStoreProvider.overrideWith((ref) async => const NullLocalStore()),
          dashboardRepositoryProvider
              .overrideWithValue(ShellFakeDashboardRepository()),
          syncFlusherProvider.overrideWith(
            (ref) async => SyncFlusher(store, '', ShellNoopSyncTarget()),
          ),
          authStateProvider.overrideWith((ref) => Stream.value(user)),
          isOnlineProvider.overrideWithValue(true),
        ],
        child: const HasadApp(),
      ),
    );
    // The shell's dashboard loads live data here (no repository override), so
    // its shimmer/progress animations never settle — pump fixed frames instead.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(NoWorkspaceView), findsNothing);
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets('signed-out user lands on the login screen', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStoreProvider.overrideWith((ref) async => const NullLocalStore()),
          authStateProvider.overrideWith((ref) => Stream.value(null)),
        ],
        child: const HasadApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(NoWorkspaceView), findsNothing);
  });
}