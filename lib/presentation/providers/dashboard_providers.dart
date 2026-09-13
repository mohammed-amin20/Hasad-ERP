import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/dashboard/supabase_dashboard_repository.dart';
import '../../data/offline/local_store.dart';
import '../../data/offline/offline_dashboard_repository.dart';
import '../../data/supabase_client.dart';
import '../../domain/dashboard/dashboard.dart';
import 'auth_providers.dart';

part 'dashboard_providers.g.dart';

/// Reads the dashboard summary — offline-first (cache-last the KPI envelope).
/// Override in tests with a fake.
@riverpod
DashboardRepository dashboardRepository(Ref ref) =>
    OfflineDashboardRepository(
      SupabaseDashboardRepository(ref.watch(supabaseClientProvider)),
      store: ref.watch(localStoreProvider).value,
      tenantId: ref.watch(authStateProvider).value?.tenantId,
    );

/// Fetches the dashboard summary once. Invalidate to reload.
@riverpod
class DashboardSummaryNotifier extends _$DashboardSummaryNotifier {
  @override
  Future<DashboardSummary> build() {
    return ref.watch(dashboardRepositoryProvider).summary();
  }
}
