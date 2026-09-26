import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/error/app_exception.dart';
import '../../domain/auth/app_role.dart';
import '../../domain/auth/app_user.dart';
import '../../domain/auth/auth_repository.dart';
import '../../domain/auth/legacy_tenant_ref.dart';
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
    } on Object catch (error, stack) {
      // Log the raw error + stack BEFORE normalization so an unknown failure
      // is diagnosable instead of the generic Arabic message.
      debugPrint('[auth:signIn] $error\n$stack');
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
      if (_client.auth.currentUser == null) return [];

      final rows =
          (await _client.rpc('get_user_tenants')) as List<dynamic>? ?? const [];

      final tenants = rows.map((row) {
        final r = row as Map<String, dynamic>;
        return TenantRef(
          id: r['tenant_id'] as String,
          name: r['tenant_name'] as String,
          role: AppRole.fromDb(r['role'] as String?),
        );
      }).toList();

      // Legacy/orphaned accounts (pre-0023): users row carries tenant_id +
      // current_tenant_id but has NO user_tenants membership, so the RPC
      // returns []. Synthesize a single workspace from the users stamp so the
      // account is usable until migration 0024 backfills the membership.
      if (tenants.isEmpty) {
        final legacy = await _legacyTenantFromUsers();
        if (legacy != null) tenants.add(legacy);
      }
      return tenants;
    } on Object catch (error, stack) {
      debugPrint('[auth:getUserTenants] $error\n$stack');
      throw mapErrorToAppException(error);
    }
  }

  /// Reads the users row's tenant stamp and builds a [TenantRef] directly,
  /// so pre-0023 orphaned accounts still get a usable workspace. Returns null
  /// when the user has no stamped tenant / known role.
  Future<TenantRef?> _legacyTenantFromUsers() async {
    try {
      final authUser = _client.auth.currentUser;
      if (authUser == null) return null;

      final row = await _client
          .from('users')
          .select('id, tenant_id, current_tenant_id, role')
          .eq('auth_user_id', authUser.id)
          .maybeSingle();
      if (row == null) return null;

      final ref_ = tenantRefFromStamp(
        currentTenantId: row['current_tenant_id'] as String?,
        legacyTenantId: row['tenant_id'] as String?,
        roleDbValue: row['role'] as String?,
      );
      if (ref_ == null) return null;

      var name = '';
      try {
        final tenant = await _client
            .from('tenants')
            .select('name')
            .eq('id', ref_.id)
            .maybeSingle();
        name = (tenant?['name'] as String?) ?? '';
      } on Object catch (error, stack) {
        debugPrint('[auth:legacyTenantName] $error\n$stack');
      }
      return TenantRef(id: ref_.id, name: name, role: ref_.role);
    } on Object catch (error, stack) {
      debugPrint('[auth:legacyUsers] $error\n$stack');
      return null;
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
