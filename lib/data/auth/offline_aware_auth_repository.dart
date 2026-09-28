import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/error/app_exception.dart';
import '../../domain/auth/app_user.dart';
import '../../domain/auth/auth_repository.dart';
import '../../domain/auth/tenant_ref.dart';
import '../offline/local_store.dart';

/// [AuthRepository] decorator that makes the **boot path** offline-capable.
///
/// ## Why this exists
///
/// `SupabaseAuthRepository.authStateChanges` reads the `users` table and calls
/// the `get_user_tenants` RPC to build an [AppUser]. That is two network round
/// trips, so an offline cold start used to fail, and it failed
/// *catastrophically*:
///
/// ```dart
/// // SupabaseAuthRepository.authStateChanges
/// return _client.auth.onAuthStateChange
///     .map((data) => data.session?.user)
///     .asyncMap((user) => user == null ? null : _profileFor(user));
/// ```
///
/// `asyncMap` forwards a throw as a **stream error, which terminates the
/// stream**. One failed profile read therefore killed `authStateProvider` for
/// the whole process lifetime and `app.dart` fell through to its
/// `error: (_, _) => LoginScreen()` branch, so a valid persisted session could
/// not get past the login screen with no network.
///
/// Caching the profile alone would not have fixed that, so this decorator does
/// three things: it serves the cache **before** any network call, it never lets
/// a network error escape, and it never lets one error kill the stream.
///
/// ## Ordering (deliberate)
///
/// 1. **Cached profile first**, before the inner stream is even subscribed.
///    The auth uid comes from [currentAuthUid], which reads the SDK-persisted
///    session and works with no network, so the shell opens immediately instead
///    of after a multi-second socket timeout.
/// 2. **Live read second.** On success the live value wins (a role or tenant
///    change must apply) and the cache is refreshed.
/// 3. **On [NetworkException] the cached profile stands** and the stream ends
///    *normally*. A `StreamProvider` retains its last value when the stream
///    completes, so the shell stays mounted. Re-attempting happens on the next
///    `ref.invalidate(authStateProvider)`, which `NoWorkspaceView`'s retry and
///    the tenant switcher already call. Phase 3 adds lifecycle re-attachment.
///
/// ## Security boundary
///
/// A signed-out session is **never** satisfied from the cache. If the inner
/// stream yields `null` the result is `null`, so the decorator cannot resurrect
/// a session the server has ended. The cache is also dropped on sign-out, so a
/// signed-out device retains no offline access. It has no TTL: it lives exactly
/// as long as the SDK's own persisted session, which is the same trust boundary
/// the SDK already accepts.
class OfflineAwareAuthRepository implements AuthRepository {
  const OfflineAwareAuthRepository(
    this._inner, {
    required this.store,
    required this.currentAuthUid,
  });

  final AuthRepository _inner;

  /// The offline store holding the cached profile. Public field to match the
  /// named-constructor style of the other `Offline*Repository` wrappers.
  final LocalStore store;

  /// Reads the current auth uid from the persisted SDK session. Offline-safe:
  /// `Supabase.initialize` (awaited in `main`) restores it from disk with no
  /// network round trip.
  final String? Function() currentAuthUid;

  @override
  Stream<AppUser?> authStateChanges() => _resilientAuthStream();

  Stream<AppUser?> _resilientAuthStream() async* {
    // 1. Cached profile, emitted before any network call so an offline cold
    //    start reaches the shell without waiting on a socket timeout.
    final cached = await _cachedProfile();
    if (cached != null) yield cached;

    var emitted = cached != null;
    try {
      await for (final user in _inner.authStateChanges()) {
        // A null emission is a real sign-out. It is passed straight through and
        // the cache is dropped, so a signed-out device cannot be restored from
        // a previous session's profile.
        if (user == null) {
          await _dropCachedProfile();
          emitted = true;
          yield null;
          continue;
        }
        await _cacheProfile(user);
        emitted = true;
        yield user;
      }
    } on NetworkException catch (error, stack) {
      // Expected offline: keep whatever the cache gave us and end the stream
      // cleanly. Never rethrow, because rethrowing is what used to kill the
      // provider for the rest of the process lifetime.
      debugPrint(
        '[auth:offlineBoot] serving cached profile after network failure: '
        '$error\n$stack',
      );
    }

    // A `StreamProvider` that closes without ever emitting stays in
    // `AsyncLoading` forever, so an offline cold start with no cache used to
    // sit on the splash screen indefinitely. Emitting `null` closes that gap:
    // "nothing cached and nothing reachable" is exactly the signed-out state,
    // and the user gets the login screen instead of a spinner that never ends.
    if (!emitted) yield null;
  }

  /// The cached profile for the current auth uid, or null when there is no
  /// session, no cache, or the cache cannot be decoded. A corrupt payload is
  /// treated as "no cache" so it degrades to the normal (login) path instead
  /// of throwing during boot.
  Future<AppUser?> _cachedProfile() async {
    final uid = _safeUid();
    if (uid == null) return null;
    try {
      final row = await store.getUserProfile(uid);
      final payload = row?.payload;
      if (payload == null || payload.isEmpty) return null;
      final decoded = jsonDecode(payload);
      if (decoded is! Map) return null;
      return AppUser.fromJson(decoded.cast<String, dynamic>());
    } on Object catch (error, stack) {
      debugPrint('[auth:cachedProfile] unreadable cache for $uid: $error\n$stack');
      return null;
    }
  }

  Future<void> _cacheProfile(AppUser user) async {
    final uid = _safeUid();
    if (uid == null) return;
    try {
      await store.putUserProfile(uid, jsonEncode(user.toJson()));
    } on Object catch (error, stack) {
      // A failed cache write must never break an otherwise valid sign-in.
      debugPrint('[auth:cacheProfile] $error\n$stack');
    }
  }

  Future<void> _dropCachedProfile() async {
    final uid = _safeUid();
    if (uid == null) return;
    try {
      await store.deleteUserProfile(uid);
    } on Object catch (error, stack) {
      debugPrint('[auth:dropCachedProfile] $error\n$stack');
    }
  }

  /// The auth uid, or null when the callback itself throws (e.g. Supabase not
  /// yet initialized). Never rethrows: boot must survive it.
  String? _safeUid() {
    try {
      final uid = currentAuthUid();
      return (uid == null || uid.isEmpty) ? null : uid;
    } on Object catch (error, stack) {
      debugPrint('[auth:uid] $error\n$stack');
      return null;
    }
  }

  @override
  Future<AppUser?> signInWithPassword({
    required String email,
    required String password,
  }) async {
    final user = await _inner.signInWithPassword(
      email: email,
      password: password,
    );
    if (user != null) await _cacheProfile(user);
    return user;
  }

  @override
  Future<void> signOut() async {
    // Drop the offline profile FIRST. If the SDK sign-out below fails (e.g.
    // already offline), the local copy is still gone, so a device the user
    // believes is signed out holds no offline access. The uid is read before
    // the session is torn down.
    await _dropCachedProfile();
    await _inner.signOut();
  }

  @override
  Future<void> switchTenant(String tenantId) => _inner.switchTenant(tenantId);

  @override
  Future<List<TenantRef>> getUserTenants() => _inner.getUserTenants();
}
