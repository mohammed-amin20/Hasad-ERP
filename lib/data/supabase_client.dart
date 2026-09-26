import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/app_config.dart';

/// Lets the app bootstrap go through a single initialization path.
abstract final class HasadSupabase {
  static Future<void> initialize() {
    return Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabaseAnonKey,
    );
  }
}

/// Composition-root access to the client. Only `data/` code reads this.
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});
