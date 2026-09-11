import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/error/app_exception.dart';
import '../../domain/auth/app_role.dart';
import '../../domain/auth/app_user.dart';
import '../../domain/auth/auth_repository.dart';
import '../../domain/auth/tenant_ref.dart';

/// AuthRepository backed by Supabase Auth + the `users` table (RLS-scoped).
class SupabaseAuthRepository implements AuthRepository {
  const SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  @override
  Stream<AppUser?> authStateChanges() {
    return _client.auth.onAuthStateChange
        .map((data) => data.session?.user)
        .asyncMap((user) => user == null ? null : _profileFor(user));
  }

  @override
  Future<AppUser?> signInWithPassword({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final user = response.user;
      return user == null ? null : await _profileFor(user);
    } on AuthException {
      rethrow;
    } on Object catch (error) {
      throw mapErrorToAppException(error);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } on Object catch (error) {
      throw mapErrorToAppException(error);
    }
  }

  @override
  Future<void> switchTenant(String tenantId) async {
    try {
      await _client.rpc('switch_tenant', params: {'p_tenant_id': tenantId});
    } on Object catch (error) {
      throw mapErrorToAppException(error);
    }
  }

  @override
  Future<List<TenantRef>> getUserTenants() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return [];

      final rows = await _client
          .from('user_tenants')
          .select('tenant_id, role, tenants!inner(name)')
          .eq('user_id', _client.auth.currentUser!.id);

      return rows.map((row) {
        final tenant = row['tenants'] as Map<String, dynamic>;
        return TenantRef(
          id: row['tenant_id'] as String,
          name: tenant['name'] as String,
          role: AppRole.fromDb(row['role'] as String?),
        );
      }).toList();
    } on Object catch (error) {
      throw mapErrorToAppException(error);
    }
  }

  Future<AppUser?> _profileFor(User user) async {
    try {
      final row = await _client
          .from('users')
          .select('id, tenant_id, current_tenant_id, name, role')
          .eq('auth_user_id', user.id)
          .maybeSingle();

      if (row == null) {
        return AppUser(
          id: user.id,
          email: user.email ?? '',
          role: AppRole.unknown,
        );
      }

      // Use current_tenant_id as the active tenant, fall back to tenant_id
      final currentTenantId =
          (row['current_tenant_id'] as String?) ??
          (row['tenant_id'] as String?);

      // Fetch user's tenants
      final tenants = await getUserTenants();

      return AppUser(
        id: row['id'] as String,
        tenantId: currentTenantId,
        name: row['name'] as String?,
        email: user.email ?? '',
        role: AppRole.fromDb(row['role'] as String?),
        tenants: tenants,
      );
    } on Object catch (error) {
      throw mapErrorToAppException(error);
    }
  }
}
