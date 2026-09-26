import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/app_progress.dart';
import '../../../core/widgets/hasad_card.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../core/widgets/section_card.dart';
import '../../../core/widgets/stat_card.dart';
import '../../../data/offline/report_keys.dart';
import '../../../domain/dashboard/dashboard.dart';
import '../../providers/dashboard_providers.dart';
import '../../widgets/freshness_chip.dart';
import '../../widgets/staggered_entrance.dart';
import '../../widgets/state_views.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PageScaffold(
      title: 'لوحة التحكم',
      subtitle: 'مرحباً، نظرة شاملة على أداء الشركة',
      icon: FontAwesomeIcons.gaugeHigh,
      actions: const [FreshnessChip(cacheKey: dashboardKey)],
      child: const _DashboardBody(),
    );
  }
}

class _DashboardBody extends ConsumerWidget {
  const _DashboardBody();

  static const List<_KpiSpec> _specs = [
    _KpiSpec(
      icon: FontAwesomeIcons.coins,
      iconColor: Color(0xFFF59E0B),
      label: 'مبيعات اليوم',
      valueColor: Color(0xFF2563EB),
    ),
    _KpiSpec(
      icon: FontAwesomeIcons.cartShopping,
      iconColor: Color(0xFFA855F7),
      label: 'مشتريات اليوم',
      valueColor: Color(0xFF7E22CE),
    ),
    _KpiSpec(
      icon: FontAwesomeIcons.creditCard,
      iconColor: Color(0xFFEF4444),
      label: 'ديون العملاء',
      valueColor: Color(0xFFDC2626),
      accent: Color(0xFFDC2626),
    ),
    _KpiSpec(
      icon: FontAwesomeIcons.handHoldingDollar,
      iconColor: Color(0xFF7C3AED),
      label: 'ديون الموردين',
      valueColor: Color(0xFF7E22CE),
      accent: Color(0xFF7C3AED),
    ),
    _KpiSpec(
      icon: FontAwesomeIcons.fileInvoice,
      iconColor: Color(0xFF818CF8),
      label: 'مصروفات الشهر',
      valueColor: Color(0xFFEF4444),
    ),
    _KpiSpec(
      icon: FontAwesomeIcons.users,
      iconColor: Color(0xFF0EA5E9),
      label: 'رواتب الشهر',
      valueColor: Color(0xFFD97706),
    ),
    _KpiSpec(
      icon: FontAwesomeIcons.chartLine,
      iconColor: Color(0xFF16A34A),
      label: 'صافي الربح (الشهر)',
      valueColor: Color(0xFF15803D),
      surface: Color(0xFFF6FEF9),
      border: Color(0xFFBBF7D0),
      spanTwo: true,
    ),
  ];

  static List<String> _values(DashboardSummary summary) => [
    Money.format(summary.todaySales),
    Money.format(summary.todayPurchases),
    Money.format(summary.customerDebts),
    Money.format(summary.supplierDebts),
    Money.format(summary.monthExpenses),
    Money.format(summary.monthSalaries),
    Money.format(summary.netProfitMonth),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(dashboardSummaryProvider);
    final summary = summaryAsync.value;
    final error = summaryAsync.error;
    final values = summary == null ? null : _values(summary);

    return SingleChildScrollView(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final sideBySide = constraints.maxWidth >= 900;

          return StaggeredColumn(
            children: [
              if (error != null)
                ErrorStateCard(
                  title: 'تعذر تحميل البيانات',
                  message: 'تعذر جلب ملخص لوحة التحكم. تحقق من الاتصال ثم أعد المحاولة.',
                  onRetry: () => ref.invalidate(dashboardSummaryProvider),
                ),
              StatCardGrid(
                cards: [
                  for (var i = 0; i < _specs.length; i++) _buildCard(_specs[i], values?[i]),
                ],
              ),
              SectionCard(
                icon: FontAwesomeIcons.chartColumn,
                iconColor: AppColors.primary,
                title: 'المبيعات والمشتريات — آخر 7 أيام',
                subtitle: 'مقارنة يومية للحركتين خلال الأسبوع الماضي',
                trailing: sideBySide ? _ChartLegend() : null,
                child: SizedBox(
                  height: sideBySide ? 280 : 268,
                  child: Column(
                    children: [
                      Expanded(
                        child: _ChartArea(
                          summary: summary,
                          loading: summaryAsync.isLoading,
                        ),
                      ),
                      if (!sideBySide) ...[
                        const SizedBox(height: 12),
                        _ChartLegend(),
                      ],
                    ],
                  ),
                ),
              ),
              if (sideBySide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: SectionCard(
                        icon: FontAwesomeIcons.triangleExclamation,
                        iconColor: AppColors.danger,
                        title: 'أعلى العملاء ديوناً',
                        child: SizedBox(
                          height: 180,
                          child: summary == null
                              ? const SkeletonList(count: 2, itemHeight: 40)
                              : _DebtorsPanel(
                                  debtors: summary.topDebtors,
                                  loading: summaryAsync.isLoading,
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppConfig.cardGap),
                    Expanded(
                      child: SectionCard(
                        icon: FontAwesomeIcons.boxOpen,
                        iconColor: AppColors.warning,
                        title: 'تنبيهات المخزون المنخفض',
                        child: SizedBox(
                          height: 180,
                          child: summary == null
                              ? const SkeletonList(count: 2, itemHeight: 40)
                              : _LowStockPanel(
                                  items: summary.lowStock,
                                  loading: summaryAsync.isLoading,
                                ),
                        ),
                      ),
                    ),
                  ],
                )
              else ...[
                SectionCard(
                  icon: FontAwesomeIcons.triangleExclamation,
                  iconColor: AppColors.danger,
                  title: 'أعلى العملاء ديوناً',
                  child: SizedBox(
                    height: 180,
                    child: summary == null
                        ? const SkeletonList(count: 2, itemHeight: 40)
                        : _DebtorsPanel(
                            debtors: summary.topDebtors,
                            loading: summaryAsync.isLoading,
                          ),
                  ),
                ),
                SectionCard(
                  icon: FontAwesomeIcons.boxOpen,
                  iconColor: AppColors.warning,
                  title: 'تنبيهات المخزون المنخفض',
                  child: SizedBox(
                    height: 180,
                    child: summary == null
                        ? const SkeletonList(count: 2, itemHeight: 40)
                        : _LowStockPanel(
                            items: summary.lowStock,
                            loading: summaryAsync.isLoading,
                          ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildCard(_KpiSpec spec, String? value) {
    return StatCard(
      icon: spec.icon,
      iconColor: spec.iconColor,
      label: spec.label,
      value: value ?? '—',
      valueColor: spec.valueColor,
      accentColor: spec.accent,
      backgroundColor: spec.surface,
      borderColor: spec.border,
    );
  }
}

class _KpiSpec {
  const _KpiSpec({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.valueColor,
    this.accent,
    this.surface,
    this.border,
    this.spanTwo = false,
  });

  final FaIconData icon;
  final Color iconColor;
  final String label;
  final Color valueColor;
  final Color? accent;
  final Color? surface;
  final Color? border;
  final bool spanTwo;
}

class _ChartArea extends StatelessWidget {
  const _ChartArea({required this.summary, required this.loading});

  final DashboardSummary? summary;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final days = summary?.last7Days ?? const <DailySalesPurchases>[];
    if (loading) {
      return const Center(
        child: SizedBox(width: 24, height: 24, child: AppProgress()),
      );
    }
    if (days.isEmpty) {
      return EmptyStateCard(
        compact: true,
        icon: FontAwesomeIcons.chartColumn,
        title: 'لا توجد حركة بعد',
        message: 'ستظهر هنا حركة المبيعات والمشتريات خلال آخر سبعة أيام.',
      );
    }
    return _TrendChart(days: days);
  }
}

class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.days});

  final List<DailySalesPurchases> days;

  @override
  Widget build(BuildContext context) {
    final sales = <FlSpot>[
      for (var i = 0; i < days.length; i++)
        FlSpot(i.toDouble(), days[i].sales.toDouble()),
    ];
    final purchases = <FlSpot>[
      for (var i = 0; i < days.length; i++)
        FlSpot(i.toDouble(), days[i].purchases.toDouble()),
    ];
    final maxY = math.max(
      sales.fold<double>(0, (m, s) => math.max(m, s.y)),
      purchases.fold<double>(0, (m, s) => math.max(m, s.y)),
    );
    final yMax = math.max(maxY * 1.15, 1.0);
    final animate = AppMotion.of(context, const Duration(milliseconds: 400));

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: yMax,
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: _gridInterval(yMax),
          getDrawingHorizontalLine: (value) => const FlLine(
            color: AppColors.chartGrid,
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 56,
              getTitlesWidget: (value, meta) => Text(
                Money.format(value.toInt()),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              reservedSize: 26,
              getTitlesWidget: (value, meta) {
                final index = value.round();
                if (index < 0 || index >= days.length) {
                  return const SizedBox.shrink();
                }
                final day = days[index].date;
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '${day.day}/${day.month}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppColors.textPrimary,
            getTooltipItems: (spots) => [
              for (final spot in spots)
                LineTooltipItem(
                  '${spot.barIndex == 0 ? 'مبيعات' : 'مشتريات'}\n'
                  '${Money.format(spot.y.toInt())}',
                  const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  textDirection: TextDirection.rtl,
                ),
            ],
          ),
        ),
        lineBarsData: [
          _TrendLine(color: AppColors.chartSales, spots: sales).resolve(),
          _TrendLine(
            color: AppColors.chartPurchases,
            spots: purchases,
          ).resolve(),
        ],
      ),
      duration: animate,
      curve: AppMotion.enter,
    );
  }

  double _gridInterval(double yMax) {
    final target = yMax / 4;
    if (target <= 100) return 100;
    if (target <= 500) return 500;
    if (target <= 1000) return 1000;
    if (target <= 5000) return 5000;
    if (target <= 10000) return 10000;
    return 50000;
  }
}

class _TrendLine {
  const _TrendLine({required this.color, required this.spots});

  final Color color;
  final List<FlSpot> spots;

  LineChartBarData resolve() => LineChartBarData(
    spots: spots,
    isCurved: true,
    curveSmoothness: 0.3,
    barWidth: 2.5,
    color: color,
    belowBarData: BarAreaData(
      show: true,
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.18), color.withValues(alpha: 0.02)],
      ),
    ),
    dotData: FlDotData(
      show: true,
      getDotPainter: (_, _, _, _) => FlDotCirclePainter(
        radius: 3.5,
        color: color,
        strokeWidth: 2,
        strokeColor: Colors.white,
      ),
    ),
  );
}

class _ChartLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _LegendDot(color: AppColors.chartSales, label: 'المبيعات'),
        SizedBox(width: 16),
        _LegendDot(color: AppColors.chartPurchases, label: 'المشتريات'),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _DebtorsPanel extends StatelessWidget {
  const _DebtorsPanel({required this.debtors, required this.loading});

  final List<DebtorSummary> debtors;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const SkeletonList(count: 2, itemHeight: 32);
    }
    if (debtors.isEmpty) {
      return EmptyStateCard(
        compact: true,
        icon: FontAwesomeIcons.userGroup,
        title: 'لا توجد ديون',
        message: 'كل العملاء مسددون حتى الآن.',
      );
    }
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: debtors.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final debtor = debtors[index];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              const IconChip(
                icon: FontAwesomeIcons.user,
                color: AppColors.danger,
                size: 32,
                iconSize: 13,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  debtor.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                Money.format(debtor.balance),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.danger,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LowStockPanel extends StatelessWidget {
  const _LowStockPanel({required this.items, required this.loading});

  final List<LowStockItem> items;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const SkeletonList(count: 2, itemHeight: 32);
    }
    if (items.isEmpty) {
      return EmptyStateCard(
        compact: true,
        icon: FontAwesomeIcons.boxesStacked,
        title: 'المخزون بخير',
        message: 'لا توجد أصناف تحت حد إعادة الطلب.',
      );
    }
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: items.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = items[index];
        final color = item.outOfStock ? AppColors.danger : AppColors.warning;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              IconChip(
                icon: item.outOfStock
                    ? FontAwesomeIcons.circleXmark
                    : FontAwesomeIcons.triangleExclamation,
                color: color,
                size: 32,
                iconSize: 13,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                item.outOfStock
                    ? 'نفد'
                    : '${_formatQty(item.qty)} / حد ${_formatQty(item.reorderLevel)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: item.outOfStock ? AppColors.danger : AppColors.warning,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatQty(num value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);
}
