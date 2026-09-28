import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:hasad_erp/core/error/app_exception.dart';
import 'package:hasad_erp/core/network/connectivity_providers.dart';
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
import 'package:hasad_erp/presentation/shell/app_shell.dart';
import 'package:hasad_erp/presentation/shell/side_navigation.dart';

import '../data/offline/delegating_local_store.dart';
import '../tool/shell_stubs.dart';

/// M13 Phase 1A — signing out must wipe the workspace's offline data.
///
/// A shared tablet is the threat model: a tenant's invoices, customers, stock
/// and queued writes sit in sqlite, and a sign-out that left them behind hands
/// the next person the previous workspace's data.
///
/// The cases below cover the four paths that matter, and the last one is the
/// one that keeps this from being a lockout bug:
///
///  * nothing pending -> sign out silently, mirrors still wiped;
///  * pending work    -> a danger confirmation quoting the exact count, and
///                       cancelling leaves BOTH the session and the data;
///  * confirmed       -> queue, mirrors and id mappings are all gone;
///  * wipe fails      -> the sign-out STILL happens. A user must never be
///                       locked into a signed-in state over a sqlite failure,
///                       and must never be locked OUT of signing out because
///                       their queue is stuck. Those two failure modes are
///                       opposite, and this case is what stops the fix from
///                       trading one for the other.
void main() {
  const uid = 'auth-uid-1';
  const tenant = 'ef95064e-b867-4b7f-bd98-36748066cc8c';
  final powerOffCodePoint = FontAwesomeIcons.powerOff.codePoint;

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
  late _RecordingAuthRepository auth;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = DriftLocalStore(db);
    auth = _RecordingAuthRepository(signedIn);
  });

  tearDown(() => db.close());

  void useDesktopSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> seedCachedProfile() =>
      store.putUserProfile(uid, jsonEncode(signedIn.toJson()));

  SyncQueueRow leg(String id) => SyncQueueRow(
        id: id,
        tenantId: tenant,
        rpc: 'create_sale_invoice',
        op: 'rpc',
        params: '{}',
        requestId: 'req-$id',
        entity: 'invoices',
        localId: 'inv-$id',
        status: 'pending',
        attempts: 0,
        lastError: null,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );

  /// Seeds a mirror row and a resolved id mapping, so a test can assert on both
  /// families of local data without also queueing something (which would change
  /// which path the sign-out takes).
  Future<void> seedLocalData() async {
    await store.upsertCustomer(LocalCustomerRow(
      id: 'c1',
      tenantId: tenant,
      name: 'عميل',
      phone: null,
      notes: null,
      createdAt: DateTime(2026),
      synced: false,
    ));
    await store.putMapping(
      tenantId: tenant,
      entity: 'customers',
      localId: 'c1',
      serverId: 'srv-c1',
    );
  }

  Future<void> pumpShell(WidgetTester tester, {LocalStore? storeOverride}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStoreProvider
              .overrideWith((ref) async => storeOverride ?? store),
          authRepositoryProvider.overrideWith((ref) async => auth),
          isOnlineProvider.overrideWithValue(false),
          dashboardRepositoryProvider
              .overrideWithValue(ShellFakeDashboardRepository()),
          syncFlusherProvider.overrideWith(
            (ref) async => SyncFlusher(store, tenant, ShellNoopSyncTarget()),
          ),
        ],
        child: const HasadApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// The sign-out control is a Tooltip-wrapped 40x40 `InkWell` carrying only a
  /// glyph, so it is matched by that glyph's code point.
  ///
  /// `FaIcon` stores its icon as `IconData?`, and the `FaIconData` from
  /// `FontAwesomeIcons` does not compare equal to that upcast, so an
  /// `icon == FontAwesomeIcons.powerOff` predicate finds nothing even while the
  /// button is plainly on screen.
  final signOutIcon = find.byWidgetPredicate(
    (w) => w is FaIcon && w.icon?.codePoint == powerOffCodePoint,
    description: 'sign-out icon',
  );

  /// Scrolls the sidebar nav until the sign-out control is materialized, then
  /// taps it.
  ///
  /// The sidebar builds its rows through a `ListView`, so the footer is not in
  /// the tree until the nav is scrolled to the bottom (a documented gotcha of
  /// this widget: the finder simply reports nothing rather than throwing). The
  /// scroll is driven by hand rather than through `scrollUntilVisible`, whose
  /// internal re-resolution of the scrollable finder races the nav's own rebuild
  /// and fails with `Bad state: No element`.
  Future<void> tapSignOut(WidgetTester tester) async {
    final nav = find.descendant(
      of: find.byType(SideNavigation),
      matching: find.byType(Scrollable),
    );
    for (var i = 0; i < 6 && signOutIcon.evaluate().isEmpty; i++) {
      await tester.drag(nav.first, const Offset(0, -200));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(signOutIcon, findsOneWidget,
        reason: 'the sign-out button must be present in the sidebar footer');
    await tester.tap(signOutIcon);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  group('sign-out with no pending work', () {
    testWidgets('signs out and wipes the mirrors without asking anything',
        (tester) async {
      useDesktopSurface(tester);
      await seedCachedProfile();

      await pumpShell(tester);
      await seedLocalData();
      expect(await store.customers(tenant), hasLength(1));

      await tapSignOut(tester);

      expect(
        find.text('تسجيل الخروج مع وجود عمليات غير مزامنة'),
        findsNothing,
        reason: 'nothing is at risk, so a loss warning would be noise',
      );
      expect(auth.signOutCalls, 1, reason: 'the sign-out must go through');
      expect(await store.customers(tenant), isEmpty,
          reason: 'the workspace mirror must not survive the sign-out');
    });
  });

  group('sign-out with pending work', () {
    testWidgets('warns with the exact count and keeps the data if cancelled',
        (tester) async {
      useDesktopSurface(tester);
      await seedCachedProfile();

      await pumpShell(tester);

      // Seeded AFTER the shell settles: `ConnectivityListener` kicks the
      // auto-sync runner on the offline->online edge, and the stubbed flusher
      // replays every leg as a no-op, so anything queued before the pump is
      // already drained by the time the sign-out is tapped. Seeding after
      // reproduces the real situation anyway - the user went offline, the queue
      // filled up, and now they sign out.
      await seedLocalData();
      await store.enqueue(leg('q1'));
      await store.enqueue(leg('q2'));
      expect(await store.pendingCount(tenant), 2,
          reason: 'the queue must be non-empty for the warning path');

      await tapSignOut(tester);

      expect(find.text('تسجيل الخروج مع وجود عمليات غير مزامنة'), findsOneWidget);
      // The count is the point of the dialog: an unquantified "unsynced data"
      // warning gives the user no basis for the decision.
      expect(find.textContaining('2 عملية غير مزامنة'), findsOneWidget);
      expect(find.textContaining('حذفها نهائياً'), findsOneWidget);

      await tester.tap(find.text('إلغاء'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(auth.signOutCalls, 0, reason: 'cancelling must not sign out');
      expect(await store.pendingCount(tenant), 2,
          reason: 'cancelling must not discard the queued writes');
      expect(await store.customers(tenant), hasLength(1));
      expect(await store.serverIdFor(tenant, 'customers', 'c1'), 'srv-c1',
          reason: 'cancelling must not drop the id mappings either');
    });

    testWidgets('confirming wipes queue, mirrors and id mappings',
        (tester) async {
      useDesktopSurface(tester);
      await seedCachedProfile();

      await pumpShell(tester);

      // Seeded after the shell settles, for the reason documented in the case
      // above: the auto-sync runner drains anything queued earlier.
      await seedLocalData();
      await store.enqueue(leg('q1'));
      await store.enqueue(leg('q2'));
      await store.enqueue(leg('q3'));

      await tapSignOut(tester);
      expect(find.textContaining('3 عملية غير مزامنة'), findsOneWidget);

      await tester.tap(find.text('خروج وحذف'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(auth.signOutCalls, 1);
      expect(await store.pendingCount(tenant), 0);
      expect(await db.select(db.syncQueueItems).get(), isEmpty);
      expect(await store.customers(tenant), isEmpty);
      expect(await store.serverIdFor(tenant, 'customers', 'c1'), isNull,
          reason: 'a stale mapping would resolve to a row that no longer exists');
    });

    testWidgets('a failed wipe still signs the user out', (tester) async {
      useDesktopSurface(tester);
      await seedCachedProfile();

      await pumpShell(tester, storeOverride: _ThrowingWipeStore(store));

      await store.enqueue(leg('q1'));

      await tapSignOut(tester);
      await tester.tap(find.text('خروج وحذف'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // The opposite failure is a user with a permanently failing store who can
      // never sign out. Signing out must not depend on the wipe succeeding.
      expect(auth.signOutCalls, 1,
          reason: 'a wipe failure is reported, never enforced');
      expect(find.byType(AppShell), findsOneWidget,
          reason: 'the session survives, so the shell is still mounted');
    });
  });
}

/// Minimal auth double that records whether `signOut` was reached.
class _RecordingAuthRepository implements AuthRepository {
  _RecordingAuthRepository(this.user);

  final AppUser user;
  int signOutCalls = 0;

  @override
  Stream<AppUser?> authStateChanges() => Stream<AppUser?>.value(user);

  @override
  Future<void> signOut() async => signOutCalls++;

  @override
  Future<List<TenantRef>> getUserTenants() async => user.tenants;

  @override
  Future<void> switchTenant(String tenantId) async {}

  @override
  Future<AppUser?> signInWithPassword({
    required String email,
    required String password,
  }) async =>
      user;
}

/// A store whose wipe throws, to prove the sign-out is not gated on it.
class _ThrowingWipeStore extends DelegatingLocalStore {
  _ThrowingWipeStore(super.inner);

  @override
  Future<ClearTenantReport> clearTenant(String tenantId,
          {bool force = false}) async =>
      throw const NetworkException();
}
