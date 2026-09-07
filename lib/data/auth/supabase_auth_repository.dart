import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/error/app_exception.dart';
import '../../domain/auth/app_role.dart';
import '../../domain/auth/app_user.dart';
import '../../domain/auth/auth_repository.dart';

/// AuthRepository backed by Supabase Auth + the `users` table (RLS-scoped).
class SupabaseAuthRepository implements AuthRepository {
  const SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  @override
  Stream<AppUser?> authStateChanges() {
    return _client.auth
        .onAuthStateChange
        .map((data) => data.session?.user)
        .asyncMap((user) => user == null ? null : _profileFor(user));
  }

  @override
  Future<AppUser?> signInWithPassword({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth
          .signInWithPassword(email: email, password: password);
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

  Future<AppUser?> _profileFor(User user) async {
    try {
      final row = await _client
          .from('users')
          .select('id, tenant_id, name, role')
          .eq('auth_user_id', user.id)
          .maybeSingle();

      if (row == null) {
        return AppUser(
          id: user.id,
          email: user.email ?? '',
          role: AppRole.unknown,
        );
      }

      return AppUser(
        id: row['id'] as String,
        tenantId: row['tenant_id'] as String?,
        name: row['name'] as String?,
        email: user.email ?? '',
        role: AppRole.fromDb(row['role'] as String?),
      );
    } on Object catch (error) {
      throw mapErrorToAppException(error);
    }
  }
}