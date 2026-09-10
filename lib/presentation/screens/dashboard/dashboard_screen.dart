import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_progress.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../core/widgets/stat_card.dart';
import '../../../domain/dashboard/dashboard.dart';
import '../../providers/dashboard_providers.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PageScaffold(
      title: 'لوحة التحكم',
      subtitle: 'مرحباً، نظرة شاملة على أداء الشركة',
      child: _DashboardBody(),
    );
  }
}

class _DashboardBody extends ConsumerWidget {
  const _DashboardBody();

  static const List<StatCard> _statCards = [
    StatCard(
      icon: FontAwesomeIcons.coins,
      iconColor: Color(0xFFF59E0B),
      label: 'مبيعات اليوم',
      value: '—',
      valueColor: Color(0xFF2563EB),
    ),
    StatCard(
      icon: FontAwesomeIcons.cartShopping,
      iconColor: Color(0xFFA855F7),
      label: 'مشتريات اليوم',
      value: '—',
      valueColor: Color(0xFF9333EA),
    ),
    StatCard(
      icon: FontAwesomeIcons.creditCard,
      iconColor: Color(0xFFEF4444),
      label: 'ديون العملاء',
      value: '—',
      valueColor: Color(0xFFDC2626),
      accentColor: Color(0xFFDC2626),
    ),
    StatCard(
      icon: FontAwesomeIcons.handHoldingDollar,
      iconColor: Color(0xFFA855F7),
      label: 'ديون الموردين',
      value: '—',
      valueColor: Color(0xFF7E22CE),
      accentColor: Color(0xFF7C3AED),
    ),
    StatCard(
      icon: FontAwesomeIcons.fileInvoice,
      iconColor: Color(0xFF818CF8),
      label: 'مصروفات الشهر',
      value: '—',
      valueColor: Color(0xFFEF4444),
    ),
    StatCard(
      icon: FontAwesomeIcons.users,
      iconColor: Color(0xFF818CF8),
      label: 'رواتب الشهر',
      value: '—',
      valueColor: Color(0xFFD97706),
    ),
    StatCard(
      icon: FontAwesomeIcons.chartLine,
      iconColor: Color(0xFF16A34A),
      label: 'صافي الربح (الشهر)',
      value: '—',
      valueColor: Color(0xFF15803D),
      backgroundColor: Color(0xFFF0FDF4),
      borderColor: Color(0xFFBBF7D0),
    ),
  ];

  int _statColumns(double width) {
    if (width >= 1040) return 4;
    if (width >= 440) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(dashboardSummaryProvider);
    final summary = summaryAsync.value;
    final error = summaryAsync.error;

    return SingleChildScrollView(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final statCols = _statColumns(width);
          const gap = 20.0;
          final itemWidth = (width - gap * (statCols - 1)) / statCols;
          final sideBySide = width >= 900;

          final cards = summary == null
              ? _statCards
              : [
                  ..._statCards.asMap().entries.map((e) {
                    final index = e.key;
                    final card = e.value;
                    return _valueCard(card, _cardValues(summary)[index]);
                  }),
                ];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (error != null) ...[
                _ErrorBanner(
                  onRetry: () => ref.invalidate(dashboardSummaryProvider),
                ),
                const SizedBox(height: 20),
              ],
              GridView.count(
                crossAxisCount: statCols,
                crossAxisSpacing: gap,
                mainAxisSpacing: gap,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: itemWidth / 116,
                children: cards,
              ),
              const SizedBox(height: 24),
              _SectionCard(
                icon: FontAwesomeIcons.chartColumn,
                iconColor: const Color(0xFF2563EB),
                title: 'المبيعات والمشتريات — آخر 7 أيام',
                body: SizedBox(
                  height: 260,
                  child: _ChartArea(
                    summary: summary,
                    loading: summaryAsync.isLoading,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (sideBySide) ...[
                Row(
                  children: [
                    Expanded(
                      child: _SectionCard(
                        icon: FontAwesomeIcons.triangleExclamation,
                        iconColor: const Color(0xFFEF4444),
                        title: 'أعلى العملاء ديوناً',
                        body: SizedBox(
                          height: 140,
                          child: summary == null
                              ? const _EmptyPanel(
                                  icon: FontAwesomeIcons.userGroup,
                                )
                              : _DebtorsPanel(
                                  debtors: summary.topDebtors,
                                  loading: summaryAsync.isLoading,
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: _SectionCard(
                        icon: FontAwesomeIcons.boxOpen,
                        iconColor: const Color(0xFFF59E0B),
                        title: 'تنبيهات المخزون المنخفض',
                        body: SizedBox(
                          height: 140,
                          child: summary == null
                              ? const _EmptyPanel(
                                  icon: FontAwesomeIcons.boxesStacked,
                                )
                              : _LowStockPanel(
                                  items: summary.lowStock,
                                  loading: summaryAsync.isLoading,
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                _SectionCard(
                  icon: FontAwesomeIcons.triangleExclamation,
                  iconColor: const Color(0xFFEF4444),
                  title: 'أعلى العملاء ديوناً',
                  body: SizedBox(
                    height: 140,
                    child: summary == null
                        ? const _EmptyPanel(icon: FontAwesomeIcons.userGroup)
                        : _DebtorsPanel(
                            debtors: summary.topDebtors,
                            loading: summaryAsync.isLoading,
                          ),
                  ),
                ),
                const SizedBox(height: 20),
                _SectionCard(
                  icon: FontAwesomeIcons.boxOpen,
                  iconColor: const Color(0xFFF59E0B),
                  title: 'تنبيهات المخزون المنخفض',
                  body: SizedBox(
                    height: 140,
                    child: summary == null
                        ? const _EmptyPanel(icon: FontAwesomeIcons.boxesStacked)
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

  StatCard _valueCard(StatCard card, String value) => StatCard(
    icon: card.icon,
    iconColor: card.iconColor,
    label: card.label,
    value: value,
    valueColor: card.valueColor,
    accentColor: card.accentColor,
    backgroundColor: card.backgroundColor,
    borderColor: card.borderColor,
  );

  List<String> _cardValues(DashboardSummary summary) => [
    Money.format(summary.todaySales),
    Money.format(summary.todayPurchases),
    Money.format(summary.customerDebts),
    Money.format(summary.supplierDebts),
    Money.format(summary.monthExpenses),
    Money.format(summary.monthSalaries),
    Money.format(summary.netProfitMonth),
  ];
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          const FaIcon(
            FontAwesomeIcons.circleExclamation,
            size: 16,
            color: Color(0xFFDC2626),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'تعذر تحميل البيانات، يرجى المحاولة مرة أخرى.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF991B1B),
              ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFDC2626),
              visualDensity: VisualDensity.compact,
            ),
            child: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }
}

class _ChartArea extends StatelessWidget {
  const _ChartArea({required this.summary, required this.loading});

  final DashboardSummary? summary;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final days = summary?.last7Days ?? const <DailySalesPurchases>[];
    if (loading) {
      return const _CenteredStatus(child: AppProgress());
    }
    if (days.isEmpty) {
      return const _EmptyPanel(icon: FontAwesomeIcons.chartColumn);
    }
    return Column(
      children: [
        Expanded(child: _TrendChart(days: days)),
        const SizedBox(height: 8),
        const _Legend(),
      ],
    );
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

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: yMax,
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: _gridInterval(yMax),
          getDrawingHorizontalLine: (value) =>
              const FlLine(color: Color(0xFFEEF2F7), strokeWidth: 1),
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
              reservedSize: 62,
              getTitlesWidget: (value, meta) => Text(
                Money.format(value.toInt()),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF94A3B8),
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
                      color: Color(0xFF64748B),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => const Color(0xFF0F172A),
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
          _TrendLine(color: const Color(0xFF2563EB), spots: sales).resolve(),
          _TrendLine(
            color: const Color(0xFF7C3AED),
            spots: purchases,
          ).resolve(),
        ],
      ),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
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

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        _LegendDot(color: Color(0xFF2563EB), label: 'المبيعات'),
        SizedBox(width: 16),
        _LegendDot(color: Color(0xFF7C3AED), label: 'المشتريات'),
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
          style: TextStyle(
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
      return const _CenteredStatus(child: AppProgress());
    }
    if (debtors.isEmpty) {
      return const _EmptyPanel(icon: FontAwesomeIcons.userGroup);
    }
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: debtors.length,
      separatorBuilder: (_, _) =>
          const Divider(height: 1, color: Color(0xFFEEF2F7)),
      itemBuilder: (context, index) {
        final debtor = debtors[index];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: const Color(0xFFFEF2F2),
                child: const FaIcon(
                  FontAwesomeIcons.user,
                  size: 12,
                  color: Color(0xFFDC2626),
                ),
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
                    color: Color(0xFF334155),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                Money.format(debtor.balance),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFDC2626),
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
      return const _CenteredStatus(child: AppProgress());
    }
    if (items.isEmpty) {
      return const _EmptyPanel(icon: FontAwesomeIcons.boxesStacked);
    }
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: items.length,
      separatorBuilder: (_, _) =>
          const Divider(height: 1, color: Color(0xFFEEF2F7)),
      itemBuilder: (context, index) {
        final item = items[index];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: item.outOfStock
                    ? const Color(0xFFFEF2F2)
                    : const Color(0xFFFFF7ED),
                child: FaIcon(
                  item.outOfStock
                      ? FontAwesomeIcons.circleXmark
                      : FontAwesomeIcons.triangleExclamation,
                  size: 12,
                  color: item.outOfStock
                      ? const Color(0xFFDC2626)
                      : const Color(0xFFF59E0B),
                ),
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
                    color: Color(0xFF334155),
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
                  color: item.outOfStock
                      ? const Color(0xFFDC2626)
                      : const Color(0xFFB45309),
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

class _CenteredStatus extends StatelessWidget {
  const _CenteredStatus({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(child: SizedBox(width: 24, height: 24, child: child));
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.body,
  });

  final FaIconData icon;
  final Color iconColor;
  final String title;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D0F172A),
            blurRadius: 6,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              FaIcon(icon, size: 16, color: iconColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF334155),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          body,
        ],
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({required this.icon});

  final FaIconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEF2F7)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FaIcon(icon, size: 24, color: AppColors.textMuted),
            const SizedBox(height: 6),
            Text(
              'لا توجد بيانات بعد',
              style: AppTheme.light.textTheme.bodySmall?.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
