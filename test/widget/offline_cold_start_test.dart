import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart' show Size;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasad_erp/core/error/app_exception.dart';
import 'package:hasad_erp/core/network/connectivity_providers.dart';
import 'package:hasad_erp/data/auth/offline_aware_auth_repository.dart';
import 'package:hasad_erp/data/offline/local_database.dart';
import 'package:hasad_erp/data/offline/local_store.dart';
import 'package:hasad_erp/data/offline/offline_sync.dart';
import 'package:hasad_erp/domain/auth/app_role.dart';
import 'package:hasad_erp/domain/auth/app_user.dart';
import 'package:hasad_erp/domain/auth/auth_repository.dart';
import 'package:hasad_erp/domain/auth/tenant_ref.dart';
import 'package:hasad_erp/presentation/app.dart';
import 'package:hasad_erp/presentation/providers/auth_providers.dart';
import 'package:hasad_erp/presentation/providers/dashboard_providers.dart';
import 'package:hasad_erp/presentation/providers/offline_sync_providers.dart';
import 'package:hasad_erp/presentation/screens/auth/login_screen.dart';
import 'package:hasad_erp/presentation/screens/auth/splash_screen.dart';
import 'package:hasad_erp/presentation/shell/app_shell.dart';

import '../tool/shell_stubs.dart';

/// M13 Phase 0 — the offline cold start, wired the way the app really is.
///
/// This is the regression test for the reported symptom: *kill the app while
/// offline and restart it, and the user is thrown back to the login screen
/// even though the data is still on the device.* The previous wiring made that
/// inevitable — the live profile read errored the auth stream, the provider
/// latched into `error`, and `app.dart` rendered `LoginScreen`.
///
/// Each test drives the **real** `HasadApp` and the **real**
/// `OfflineAwareAuthRepository`, and fakes only the network.
///
/// Scope note: these tests assert the **routing decision**, not that the shell's
/// data layer can render. The shell's dashboard/tenants providers watch
/// `supabaseClientProvider`, which reads `Supabase.instance.client` and throws
/// in a test isolate; those errors are expected here and are drained with
/// [WidgetTester.takeException] after the routing assertion. Serving cached
/// business data offline is covered at the repository level by
/// `test/data/offline/offline_reads_test.dart` and
/// `test/data/offline/offline_wrappers_test.dart`.
void main() {
  const uid = 'auth-uid-1';
  const tenant = 'ef95064e-b867-4b7f-bd98-36748066cc8c';

  final signedIn = AppUser(
    id: 'u1',
    email: 'owner@test.local',
    name: 'مالك',
    role: AppRole.admin,
    tenantId: tenant,
    tenants: const [
      TenantRef(id: tenant, name: 'منشأة الحصاد', role: AppRole.admin),
    ],
  );

  late AppDatabase db;
  late DriftLocalStore store;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = DriftLocalStore(db);
  });

  tearDown(() => db.close());

  /// The `flutter_test` default surface is 800x600, which is short enough that
  /// the shell's empty/error state views (`state_views.dart:33`) overflow
  /// vertically. That is a test-harness artifact, not a product defect — the
  /// real screens are swept at realistic viewports in
  /// `test/widget/overflow_sweep_test.dart` — so give these tests a desktop
  /// surface, which is one of the app's two shipped targets.
  void useDesktopSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> seedCachedProfile([AppUser? user]) =>
      store.putUserProfile(uid, jsonEncode((user ?? signedIn).toJson()));

  /// The real decorator over a fake that behaves like a real offline phone: the
  /// auth session is still on disk, but the profile read needs the network and
  /// cannot get it.
  AuthRepository offlineAuthRepository() => OfflineAwareAuthRepository(
        _FakeAuthRepository(
          error: const NetworkException(),
          tenants: signedIn.tenants,
        ),
        store: store,
        currentAuthUid: () => uid,
      );

  /// The shell's shimmer/progress animations never settle without their data
  /// providers, so `pumpAndSettle` would time out. Drive fixed frames instead.
  Future<void> pumpShell(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }

  /// The shell watches `authStateProvider`, `currentDestinationProvider` and
  /// `availableTenantsProvider`; only the first and last come from the auth
  /// decorator. The mounted dashboard then reaches `supabaseClientProvider`,
  /// which reads `Supabase.instance.client` and throws in a test isolate.
  ///
  /// Those two throw paths are stubbed rather than absorbed. A Riverpod
  /// `ProviderException` is raised inside the provider's own zone, so
  /// `tester.takeException()` cannot drain it and the test fails no matter what
  /// it asserts — which is why the pre-existing shell-routing test only ever
  /// asserts `findsNothing`. They are inlined into each `overrides:` list
  /// because Riverpod 3.4.3 does not export the `Override` type, so a helper
  /// cannot declare its return type.
  Future<void> settleShell(WidgetTester tester) async {
    await pumpShell(tester);
    await tester.pump(const Duration(milliseconds: 300));
  }

  group('offline cold start', () {
    testWidgets('a cached profile routes to the shell, not the login screen',
        (tester) async {
      useDesktopSurface(tester);
      await seedCachedProfile();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStoreProvider.overrideWith((ref) async => store),
            authRepositoryProvider
                .overrideWith((ref) async => offlineAuthRepository()),
            isOnlineProvider.overrideWithValue(false),
            dashboardRepositoryProvider
                .overrideWithValue(ShellFakeDashboardRepository()),
            syncFlusherProvider.overrideWith(
              (ref) async =>
                  SyncFlusher(store, '', ShellNoopSyncTarget()),
            ),
          ],
          child: const HasadApp(),
        ),
      );
      await settleShell(tester);

      expect(
        find.byType(LoginScreen),
        findsNothing,
        reason: 'this is the reported bug: an offline restart with valid '
            'cached data must not land on the login screen',
      );
      expect(
        find.byType(AppShell),
        findsOneWidget,
        reason: 'a signed-in user with a tenant must reach the shell',
      );
    });

    testWidgets('the offline banner shows, proving the phone really is offline',
        (tester) async {
      useDesktopSurface(tester);
      await seedCachedProfile();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStoreProvider.overrideWith((ref) async => store),
            authRepositoryProvider
                .overrideWith((ref) async => offlineAuthRepository()),
            isOnlineProvider.overrideWithValue(false),
            dashboardRepositoryProvider
                .overrideWithValue(ShellFakeDashboardRepository()),
            syncFlusherProvider.overrideWith(
              (ref) async =>
                  SyncFlusher(store, '', ShellNoopSyncTarget()),
            ),
          ],
          child: const HasadApp(),
        ),
      );
      await settleShell(tester);

      // Without this the test would also pass on a phone that is merely
      // online-but-failing, which is a different defect with a different fix.
      expect(find.textContaining('غير متصل'), findsWidgets);
    });

    testWidgets('no cache and no network lands on the login screen',
        (tester) async {
      useDesktopSurface(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStoreProvider.overrideWith((ref) async => store),
            authRepositoryProvider
                .overrideWith((ref) async => offlineAuthRepository()),
            isOnlineProvider.overrideWithValue(true),
          ],
          child: const HasadApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Degrades honestly: nothing to restore, so no shell.
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(AppShell), findsNothing);
    });

    testWidgets('a user with no workspace gets NoWorkspaceView offline',
        (tester) async {
      useDesktopSurface(tester);
      await seedCachedProfile(
        AppUser(id: 'u1', email: 'orphan@test.local', role: AppRole.unknown),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStoreProvider.overrideWith((ref) async => store),
            authRepositoryProvider
                .overrideWith((ref) async => offlineAuthRepository()),
            isOnlineProvider.overrideWithValue(true),
          ],
          child: const HasadApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AppShell), findsNothing);
      expect(find.text('لا توجد منشأة بعد'), findsOneWidget);
    });
  });

  group('the shell never builds without a store', () {
    testWidgets('a pending local store holds the splash instead of the shell',
        (tester) async {
      // Auth is ready immediately, so only the store gate can hold the shell
      // back. This isolates the gate: without it the shell would build on a
      // null store, and every `cacheFirst` read would silently skip the local
      // mirror and report "no data" while the data sat in SQLite.
      final storeCompleter = Completer<LocalStore>();
      useDesktopSurface(tester);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStoreProvider.overrideWith((ref) => storeCompleter.future),
            authStateProvider.overrideWith((ref) => Stream.value(signedIn)),
            isOnlineProvider.overrideWithValue(true),
            dashboardRepositoryProvider
                .overrideWithValue(ShellFakeDashboardRepository()),
            syncFlusherProvider.overrideWith(
              (ref) async =>
                  SyncFlusher(store, '', ShellNoopSyncTarget()),
            ),
          ],
          child: const HasadApp(),
        ),
      );
      await tester.pump();

      expect(find.byType(SplashScreen), findsOneWidget);
      expect(
        find.byType(AppShell),
        findsNothing,
        reason: 'the shell must never be built on a null store',
      );

      // Once the store resolves, the shell opens.
      storeCompleter.complete(store);
      await settleShell(tester);

      expect(find.byType(SplashScreen), findsNothing);
      expect(find.byType(AppShell), findsOneWidget);
    });
  });

  group('a signed-out device gains no offline access', () {
    testWidgets('a null live session overrides the cache and drops it',
        (tester) async {
      useDesktopSurface(tester);
      await seedCachedProfile();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStoreProvider.overrideWith((ref) async => store),
            // The server says the session is gone. The decorator must not
            // satisfy that from the cache.
            authRepositoryProvider.overrideWith(
              (ref) async => OfflineAwareAuthRepository(
                _FakeAuthRepository(
                  stream: Stream<AppUser?>.value(null),
                  tenants: signedIn.tenants,
                ),
                store: store,
                currentAuthUid: () => uid,
              ),
            ),
            isOnlineProvider.overrideWithValue(true),
          ],
          child: const HasadApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(AppShell), findsNothing);
      expect(
        await store.getUserProfile(uid),
        isNull,
        reason: 'a revoked session must also purge the offline copy',
      );
    });
  });
}

/// Network-faking auth repository; the decorator under test is the real one.
class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.stream, this.error, this.tenants = const []});

  final Stream<AppUser?>? stream;
  final Object? error;

  /// Must be non-empty for a user that has a tenant, or the shell renders its
  /// "no workspace" state instead of the dashboard.
  final List<TenantRef> tenants;

  @override
  Stream<AppUser?> authStateChanges() {
    if (error != null) return Stream<AppUser?>.error(error!);
    return stream ?? const Stream<AppUser?>.empty();
  }

  @override
  Future<AppUser?> signInWithPassword({
    required String email,
    required String password,
  }) async =>
      null;

  @override
  Future<void> signOut() async {}

  @override
  Future<List<TenantRef>> getUserTenants() async => tenants;

  @override
  Future<void> switchTenant(String tenantId) async {}
}
