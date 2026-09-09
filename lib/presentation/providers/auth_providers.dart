import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/auth/supabase_auth_repository.dart';
import '../../data/supabase_client.dart';
import '../../domain/auth/app_user.dart';
import '../../domain/auth/auth_repository.dart';
import '../../domain/auth/tenant_ref.dart';

part 'auth_providers.g.dart';

/// The concrete repository wired at the composition root.
@riverpod
AuthRepository authRepository(Ref ref) =>
    SupabaseAuthRepository(ref.watch(supabaseClientProvider));

/// Stream of the current signed-in user (null when signed out).
@riverpod
Stream<AppUser?> authState(Ref ref) =>
    ref.watch(authRepositoryProvider).authStateChanges();

/// Fetch all tenants the current user has access to.
@riverpod
Future<List<TenantRef>> availableTenants(Ref ref) async {
  final repo = ref.watch(authRepositoryProvider);
  return repo.getUserTenants();
}

/// Tenant switch action — switches the current tenant and invalidates all dependent providers.
@riverpod
class TenantSwitch extends _$TenantSwitch {
  @override
  FutureOr<void> build() {}

  Future<void> switchTo(String tenantId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() =>
        ref.read(authRepositoryProvider).switchTenant(tenantId));
    if (state.hasError) return;
    // Invalidate ALL data providers on successful switch
    ref.invalidate(availableTenantsProvider);
    ref.invalidate(authStateProvider);
    // All downstream providers (dashboard, customers, invoices, etc.) auto-invalidate
    // because they depend on authStateProvider or use tenant-scoped queries.
  }
}