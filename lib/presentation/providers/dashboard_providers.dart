import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/dashboard/supabase_dashboard_repository.dart';
import '../../data/supabase_client.dart';
import '../../domain/dashboard/dashboard.dart';

part 'dashboard_providers.g.dart';

/// Reads the dashboard summary from Supabase. Override in tests with a fake.
@riverpod
DashboardRepository dashboardRepository(Ref ref) =>
    SupabaseDashboardRepository(ref.watch(supabaseClientProvider));

/// Fetches the dashboard summary once. Invalidate to reload.
@riverpod
class DashboardSummaryNotifier extends _$DashboardSummaryNotifier {
  @override
  Future<DashboardSummary> build() {
    return ref.watch(dashboardRepositoryProvider).summary();
  }
}