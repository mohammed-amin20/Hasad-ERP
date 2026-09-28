import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/auth/offline_aware_auth_repository.dart';
import '../../data/auth/supabase_auth_repository.dart';
import '../../data/offline/local_store.dart';
import '../../data/supabase_client.dart';
import '../../domain/auth/app_user.dart';
import '../../domain/auth/auth_repository.dart';
import '../../domain/auth/tenant_ref.dart';

part 'auth_providers.g.dart';

/// The concrete repository wired at the composition root.
///
/// Wrapped in [OfflineAwareAuthRepository] so a cold start with no network
/// restores the last-known profile from the local store instead of failing the
/// `users` read and dropping the user on the login screen. The decorator needs
/// the already-open store, so it is awaited here — this provider is only read
/// by [authState]/[availableTenants], neither of which participates in the
/// store's own provider graph, so there is no cycle.
@riverpod
Future<AuthRepository> authRepository(Ref ref) async {
  final supabase = SupabaseAuthRepository(ref.watch(supabaseClientProvider));
  final store = await ref.watch(localStoreProvider.future);
  return OfflineAwareAuthRepository(
    supabase,
    store: store,
    // Offline-safe: the SDK restores this from the persisted session during
    // `Supabase.initialize` (awaited in main), with no network round trip.
    currentAuthUid: () => Supabase.instance.client.auth.currentUser?.id,
  );
}

/// Stream of the current signed-in user (null when signed out).
///
/// An `async*` generator rather than a direct delegation so it can await the
/// offline-aware repository: that decorator must be constructed with the
/// already-open [LocalStore], and awaiting here means the stream's *first*
/// emission is the cached profile on an offline cold start.
@riverpod
Stream<AppUser?> authState(Ref ref) async* {
  final repo = await ref.watch(authRepositoryProvider.future);
  yield* repo.authStateChanges();
}

/// Fetch all tenants the current user has access to.
@riverpod
Future<List<TenantRef>> availableTenants(Ref ref) async {
  final repo = await ref.watch(authRepositoryProvider.future);
  return repo.getUserTenants();
}

/// Tenant switch action — switches the current tenant and invalidates all dependent providers.
@riverpod
class TenantSwitch extends _$TenantSwitch {
  @override
  FutureOr<void> build() {}

  Future<void> switchTo(String tenantId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = await ref.read(authRepositoryProvider.future);
      return repo.switchTenant(tenantId);
    });
    if (state.hasError) return;
    // Invalidate ALL data providers on successful switch
    ref.invalidate(availableTenantsProvider);
    ref.invalidate(authStateProvider);
    // All downstream providers (dashboard, customers, invoices, etc.) auto-invalidate
    // because they depend on authStateProvider or use tenant-scoped queries.
  }
}
