/// Dashboard payload from the `get_dashboard_summary` RPC — the KPI cards,
/// the 7-day trend chart, the top-debtors list and low-stock alerts.
library;

/// One day of the 7-day sales/purchases trend (date, money in agorot).
class DailySalesPurchases {
  const DailySalesPurchases({
    required this.date,
    required this.sales,
    required this.purchases,
  });

  final DateTime date;
  final int sales;
  final int purchases;

  factory DailySalesPurchases.fromJson(Map<String, dynamic> json) =>
      DailySalesPurchases(
        date: DateTime.parse(json['date'] as String),
        sales: (json['sales'] as num?)?.toInt() ?? 0,
        purchases: (json['purchases'] as num?)?.toInt() ?? 0,
      );
}

/// A customer with outstanding debt (top 5 on the dashboard).
class DebtorSummary {
  const DebtorSummary({
    required this.customerId,
    required this.name,
    required this.balance,
  });

  final String customerId;
  final String name;
  final int balance;

  factory DebtorSummary.fromJson(Map<String, dynamic> json) => DebtorSummary(
    customerId: json['customer_id'] as String,
    name: json['name'] as String? ?? 'غير معروف',
    balance: (json['balance'] as num?)?.toInt() ?? 0,
  );
}

/// A product whose on-hand [qty] is at or below its [reorderLevel].
class LowStockItem {
  const LowStockItem({
    required this.productId,
    required this.name,
    required this.qty,
    required this.reorderLevel,
  });

  final String productId;
  final String name;
  final num qty;
  final num reorderLevel;

  bool get outOfStock => qty <= 0;

  factory LowStockItem.fromJson(Map<String, dynamic> json) => LowStockItem(
    productId: json['product_id'] as String,
    name: json['name'] as String? ?? 'غير معروف',
    qty: (json['qty'] as num?)?.toInt() ?? 0,
    reorderLevel: (json['reorder_level'] as num?)?.toInt() ?? 0,
  );
}

/// Everything the dashboard renders, from one RPC envelope.
class DashboardSummary {
  const DashboardSummary({
    required this.todaySales,
    required this.todayPurchases,
    required this.customerDebts,
    required this.supplierDebts,
    required this.monthExpenses,
    required this.monthSalaries,
    required this.netProfitMonth,
    required this.last7Days,
    required this.topDebtors,
    required this.lowStock,
  });

  final int todaySales;
  final int todayPurchases;
  final int customerDebts;
  final int supplierDebts;
  final int monthExpenses;
  final int monthSalaries;
  final int netProfitMonth;
  final List<DailySalesPurchases> last7Days;
  final List<DebtorSummary> topDebtors;
  final List<LowStockItem> lowStock;

  factory DashboardSummary.fromJson(Map<String, dynamic> json) =>
      DashboardSummary(
        todaySales: (json['today_sales'] as num?)?.toInt() ?? 0,
        todayPurchases: (json['today_purchases'] as num?)?.toInt() ?? 0,
        customerDebts: (json['customer_debts'] as num?)?.toInt() ?? 0,
        supplierDebts: (json['supplier_debts'] as num?)?.toInt() ?? 0,
        monthExpenses: (json['month_expenses'] as num?)?.toInt() ?? 0,
        monthSalaries: (json['month_salaries'] as num?)?.toInt() ?? 0,
        netProfitMonth: (json['net_profit_month'] as num?)?.toInt() ?? 0,
        last7Days: [
          for (final m in (json['last_7_days'] as List?) ?? const [])
            if (m is Map<String, dynamic>) DailySalesPurchases.fromJson(m),
        ],
        topDebtors: [
          for (final m in (json['top_debtors'] as List?) ?? const [])
            if (m is Map<String, dynamic>) DebtorSummary.fromJson(m),
        ],
        lowStock: [
          for (final m in (json['low_stock'] as List?) ?? const [])
            if (m is Map<String, dynamic>) LowStockItem.fromJson(m),
        ],
      );
}

/// Reads the dashboard summary via the `get_dashboard_summary` RPC.
abstract class DashboardRepository {
  Future<DashboardSummary> summary();
}
