import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasad_erp/core/error/app_exception.dart';
import 'package:hasad_erp/data/auth/offline_aware_auth_repository.dart';
import 'package:hasad_erp/data/offline/local_database.dart';
import 'package:hasad_erp/data/offline/local_store.dart';
import 'package:hasad_erp/domain/auth/app_role.dart';
import 'package:hasad_erp/domain/auth/app_user.dart';
import 'package:hasad_erp/domain/auth/auth_repository.dart';
import 'package:hasad_erp/domain/auth/tenant_ref.dart';

/// M13 Phase 0 — offline-capable auth boot.
///
/// The defect this pins is a *stream* defect as much as a caching one:
/// `SupabaseAuthRepository.authStateChanges` used `asyncMap`, so a single
/// offline profile read errored the stream and terminated it for the rest of
/// the process. These tests exist to make that unreintroducible: every
/// offline case must end with the stream **completing normally**, never
/// erroring.
void main() {
  late AppDatabase db;
  late DriftLocalStore store;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = DriftLocalStore(db);
  });

  tearDown(() => db.close());

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

  Future<void> seedCache([AppUser? user]) =>
      store.putUserProfile(uid, jsonEncode((user ?? signedIn).toJson()));

  /// Collects every emission and records whether the stream errored.
  Future<({List<AppUser?> values, Object? error})> collect(
    Stream<AppUser?> stream,
  ) async {
    final values = <AppUser?>[];
    Object? error;
    try {
      await for (final v in stream) {
        values.add(v);
      }
    } on Object catch (e) {
      error = e;
    }
    return (values: values, error: error);
  }

  group('offline cold start', () {
    test('emits the cached profile BEFORE the network is ever consulted',
        () async {
      await seedCache();
      // Records the order of events so "cache first" is proven, not assumed.
      final order = <String>[];
      final inner = _FakeAuthRepository(
        onListen: () => order.add('network-subscribed'),
      );

      final repo = OfflineAwareAuthRepository(
        inner,
        store: store,
        currentAuthUid: () {
          order.add('uid-read');
          return uid;
        },
      );

      final values = <AppUser?>[];
      await for (final v in repo.authStateChanges()) {
        order.add('emitted');
        values.add(v);
      }

      expect(values.single, isNotNull);
      expect(values.single!.role, AppRole.admin);
      expect(values.single!.tenantId, tenant);
      expect(
        order,
        ['uid-read', 'emitted', 'network-subscribed'],
        reason: 'the cached profile must be the first thing delivered, so the '
            'shell opens without waiting on a socket timeout',
      );
    });

    test('a network failure keeps the cached profile and never errors',
        () async {
      await seedCache();
      final inner = _FakeAuthRepository(error: const NetworkException());

      final result = await collect(
        OfflineAwareAuthRepository(
          inner,
          store: store,
          currentAuthUid: () => uid,
        ).authStateChanges(),
      );

      expect(result.error, isNull,
          reason: 'erroring the stream is the exact defect being fixed');
      expect(result.values.single, isNotNull);
      expect(result.values.single!.tenantId, tenant);
    });

    test('an offline cold start with no cache yields nothing and does not '
        'error (degrades to the login path)', () async {
      final inner = _FakeAuthRepository(error: const NetworkException());

      final result = await collect(
        OfflineAwareAuthRepository(
          inner,
          store: store,
          currentAuthUid: () => uid,
        ).authStateChanges(),
      );

      expect(result.error, isNull);
      // Emits `null` rather than nothing: a StreamProvider that closes without
      // a value stays AsyncLoading forever, which left the app spinning on the
      // splash screen instead of ever showing the login screen.
      expect(result.values, [null]);
    });
  });

  group('online behaviour is unchanged', () {
    test('a live profile wins over the cache and refreshes it', () async {
      await seedCache();
      final live = AppUser(
        id: 'u1',
        email: 'owner@test.local',
        role: AppRole.sales,
        tenantId: 'tenant-new',
      );
      final inner = _FakeAuthRepository(stream: Stream<AppUser?>.value(live));

      final values = <AppUser?>[];
      await for (final v in OfflineAwareAuthRepository(
        inner,
        store: store,
        currentAuthUid: () => uid,
      ).authStateChanges()) {
        values.add(v);
      }

      // Stale cache first (offline-first), then the authoritative live value.
      expect(values.length, 2);
      expect(values.first!.role, AppRole.admin);
      expect(values.last!.role, AppRole.sales,
          reason: 'a role change must apply once the network answers');
      expect(values.last!.tenantId, 'tenant-new');

      // ...and the cache now holds the live value for the next cold start.
      final cached = await store.getUserProfile(uid);
      expect(jsonDecode(cached!.payload)['role'], 'sales');
      expect(jsonDecode(cached.payload)['tenant_id'], 'tenant-new');
    });

    test('a non-network error still surfaces (a revoked session must not be '
        'masked by a stale cache)', () async {
      await seedCache();
      final inner = _FakeAuthRepository(
        error: const ValidationException('جلسة غير صالحة'),
      );

      final result = await collect(
        OfflineAwareAuthRepository(
          inner,
          store: store,
          currentAuthUid: () => uid,
        ).authStateChanges(),
      );

      // Only NetworkException is swallowed. Anything else must reach app.dart
      // so a genuine auth failure still lands on the login screen.
      expect(result.error, isA<ValidationException>());
    });
  });

  group('sign-out is not survivable', () {
    test('a null emission is passed through and drops the cache', () async {
      await seedCache();
      final inner = _FakeAuthRepository(stream: Stream<AppUser?>.value(null));

      final values = <AppUser?>[];
      await for (final v in OfflineAwareAuthRepository(
        inner,
        store: store,
        currentAuthUid: () => uid,
      ).authStateChanges()) {
        values.add(v);
      }

      expect(
        values,
        contains(null),
        reason: 'a real sign-out must never be satisfied from the cache',
      );
      expect(values.last, isNull);
      expect(await store.getUserProfile(uid), isNull);
    });

    test('signOut clears the profile even when the SDK call fails', () async {
      await seedCache();
      final inner = _FakeAuthRepository(signOutError: const NetworkException());

      await expectLater(
        OfflineAwareAuthRepository(
          inner,
          store: store,
          currentAuthUid: () => uid,
        ).signOut(),
        throwsA(isA<NetworkException>()),
      );

      expect(
        await store.getUserProfile(uid),
        isNull,
        reason: 'the local copy is dropped first, so a device the user believes '
            'is signed out holds no offline access even if the SDK call fails',
      );
    });

    test('signIn caches the returned profile', () async {
      final inner = _FakeAuthRepository(signInResult: signedIn);

      final user = await OfflineAwareAuthRepository(
        inner,
        store: store,
        currentAuthUid: () => uid,
      ).signInWithPassword(email: 'owner@test.local', password: 'secret');

      expect(user, isNotNull);
      expect(await store.getUserProfile(uid), isNotNull);
    });
  });

  group('boot must survive a broken environment', () {
    test('a corrupt cache payload degrades to no cache instead of throwing',
        () async {
      await store.putUserProfile(uid, 'not-json{{');
      final inner = _FakeAuthRepository(error: const NetworkException());

      final result = await collect(
        OfflineAwareAuthRepository(
          inner,
          store: store,
          currentAuthUid: () => uid,
        ).authStateChanges(),
      );

      expect(result.error, isNull);
      expect(result.values, [null]);
    });

    test('a null auth uid skips the cache without failing the stream',
        () async {
      await seedCache();
      final inner = _FakeAuthRepository(error: const NetworkException());

      final result = await collect(
        OfflineAwareAuthRepository(
          inner,
          store: store,
          currentAuthUid: () => null,
        ).authStateChanges(),
      );

      expect(result.error, isNull);
      expect(result.values, [null]);
    });

    test('a throwing auth-uid callback does not break boot', () async {
      final inner = _FakeAuthRepository(error: const NetworkException());

      final result = await collect(
        OfflineAwareAuthRepository(
          inner,
          store: store,
          currentAuthUid: () => throw StateError('Supabase not initialized'),
        ).authStateChanges(),
      );

      expect(result.error, isNull);
      expect(result.values, [null]);
    });

    test('a store that cannot be read does not break a valid sign-in',
        () async {
      final inner = _FakeAuthRepository(
        stream: Stream<AppUser?>.value(signedIn),
        throwOnSignIn: true,
      );

      final values = <AppUser?>[];
      await for (final v in OfflineAwareAuthRepository(
        inner,
        store: store,
        currentAuthUid: () => uid,
      ).authStateChanges()) {
        values.add(v);
      }

      expect(values, isNotEmpty);
      expect(values.last, signedIn);
    });
  });
}

/// AuthRepository fake whose inner stream is fully scriptable, so each test can
/// choose between a live value, a network failure, or a hard error.
class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({
    this.stream,
    this.error,
    this.signInResult,
    this.signOutError,
    this.throwOnSignIn = false,
    this._onListen,
  });

  final Stream<AppUser?>? stream;
  final Object? error;
  final AppUser? signInResult;
  final Object? signOutError;
  final bool throwOnSignIn;
  final void Function()? _onListen;

  int authStateChangesCalls = 0;

  @override
  Stream<AppUser?> authStateChanges() {
    authStateChangesCalls += 1;
    _onListen?.call();
    if (error != null) return Stream<AppUser?>.error(error!);
    return stream ?? const Stream<AppUser?>.empty();
  }

  @override
  Future<AppUser?> signInWithPassword({
    required String email,
    required String password,
  }) async {
    if (throwOnSignIn) throw StateError('store unavailable');
    return signInResult;
  }

  @override
  Future<void> signOut() async {
    if (signOutError != null) throw signOutError!;
  }

  @override
  Future<void> switchTenant(String tenantId) async {}

  @override
  Future<List<TenantRef>> getUserTenants() async => const [];
}
