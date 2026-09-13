import 'dart:convert';

import '../../domain/dashboard/dashboard.dart';
import 'local_store.dart';
import 'offline_reads.dart';
import 'report_keys.dart';

/// [DashboardRepository] that cache-lasts the KPI envelope for offline viewing.
class OfflineDashboardRepository implements DashboardRepository {
  OfflineDashboardRepository(this._inner, {required this.store, required this.tenantId});

  final DashboardRepository _inner;
  final LocalStore? store;
  final String? tenantId;

  @override
  Future<DashboardSummary> summary() => cacheLast(
        store: store,
        tenantId: tenantId,
        key: dashboardKey,
        network: _inner.summary,
        fromCached: (payload) =>
            DashboardSummary.fromJson((jsonDecode(payload) as Map).cast<String, dynamic>()),
        toPayload: (s) => jsonEncode({
          'today_sales': s.todaySales,
          'today_purchases': s.todayPurchases,
          'customer_debts': s.customerDebts,
          'supplier_debts': s.supplierDebts,
          'month_expenses': s.monthExpenses,
          'month_salaries': s.monthSalaries,
          'net_profit_month': s.netProfitMonth,
          'last_7_days': [
            for (final d in s.last7Days)
              {
                'date': cacheDate(d.date),
                'sales': d.sales,
                'purchases': d.purchases,
              },
          ],
          'top_debtors': [
            for (final d in s.topDebtors)
              {
                'customer_id': d.customerId,
                'name': d.name,
                'balance': d.balance,
              },
          ],
          'low_stock': [
            for (final p in s.lowStock)
              {
                'product_id': p.productId,
                'name': p.name,
                'qty': p.qty,
                'reorder_level': p.reorderLevel,
              },
          ],
        }),
      );
}