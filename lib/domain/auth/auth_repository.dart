import 'package:hasad_erp/core/error/app_exception.dart';

import 'app_user.dart';

/// Contract for authentication. Implementations live in `data/`.
///
/// The UI depends only on this interface — never on Supabase directly.
abstract interface class AuthRepository {
  /// Emits the current signed-in user, or null when signed out.
  Stream<AppUser?> authStateChanges();

  /// Signs in with email + password (Supabase Auth JWT session).
  ///
  /// Throws a mapped [AppException] on failure.
  Future<AppUser?> signInWithPassword({
    required String email,
    required String password,
  });

  /// Signs out the current session.
  Future<void> signOut();
}