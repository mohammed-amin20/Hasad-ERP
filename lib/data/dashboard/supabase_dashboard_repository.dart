import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/error/app_exception.dart';
import '../../domain/dashboard/dashboard.dart';

/// [DashboardRepository] backed by the `get_dashboard_summary` RPC.
class SupabaseDashboardRepository implements DashboardRepository {
  const SupabaseDashboardRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<DashboardSummary> summary() async {
    try {
      final result = await _client.rpc('get_dashboard_summary');
      return DashboardSummary.fromJson(result as Map<String, dynamic>);
    } on Object catch (error) {
      throw mapErrorToAppException(error);
    }
  }
}