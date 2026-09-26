import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasad_erp/core/network/connectivity_providers.dart';
import 'package:hasad_erp/domain/auth/app_role.dart';
import 'package:hasad_erp/domain/auth/app_user.dart';
import 'package:hasad_erp/presentation/app.dart';
import 'package:hasad_erp/presentation/providers/auth_providers.dart';
import 'package:hasad_erp/presentation/screens/auth/login_screen.dart';
import 'package:hasad_erp/presentation/widgets/no_workspace_view.dart';

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

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
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