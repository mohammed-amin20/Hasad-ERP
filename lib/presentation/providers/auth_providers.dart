import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/auth/supabase_auth_repository.dart';
import '../../data/supabase_client.dart';
import '../../domain/auth/app_user.dart';
import '../../domain/auth/auth_repository.dart';

part 'auth_providers.g.dart';

/// The concrete repository wired at the composition root.
@riverpod
AuthRepository authRepository(Ref ref) =>
    SupabaseAuthRepository(ref.watch(supabaseClientProvider));

/// Stream of the current signed-in user (null when signed out).
@riverpod
Stream<AppUser?> authState(Ref ref) =>
    ref.watch(authRepositoryProvider).authStateChanges();