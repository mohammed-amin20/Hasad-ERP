import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../core/widgets/stat_card.dart';

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

class _DashboardBody extends StatelessWidget {
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
    if (width >= 480) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final statCols = _statColumns(width);
          const gap = 20.0;
          final itemWidth = (width - gap * (statCols - 1)) / statCols;
          final sideBySide = width >= 900;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GridView.count(
                crossAxisCount: statCols,
                crossAxisSpacing: gap,
                mainAxisSpacing: gap,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: itemWidth / 116,
                children: _statCards,
              ),
              const SizedBox(height: 24),
              const _SectionCard(
                icon: FontAwesomeIcons.chartColumn,
                iconColor: Color(0xFF2563EB),
                title: 'المبيعات والمشتريات — آخر 7 أيام',
                body: SizedBox(height: 260, child: _ChartPlaceholder()),
              ),
              const SizedBox(height: 20),
              if (sideBySide) ...[
                Row(
                  children: const [
                    Expanded(
                      child: _SectionCard(
                        icon: FontAwesomeIcons.triangleExclamation,
                        iconColor: Color(0xFFEF4444),
                        title: 'أعلى العملاء ديوناً',
                        body: SizedBox(
                          height: 140,
                          child: _EmptyPanel(icon: FontAwesomeIcons.userGroup),
                        ),
                      ),
                    ),
                    SizedBox(width: 20),
                    Expanded(
                      child: _SectionCard(
                        icon: FontAwesomeIcons.boxOpen,
                        iconColor: Color(0xFFF59E0B),
                        title: 'تنبيهات المخزون المنخفض',
                        body: SizedBox(
                          height: 140,
                          child: _EmptyPanel(
                            icon: FontAwesomeIcons.boxesStacked,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                const _SectionCard(
                  icon: FontAwesomeIcons.triangleExclamation,
                  iconColor: Color(0xFFEF4444),
                  title: 'أعلى العملاء ديوناً',
                  body: SizedBox(
                    height: 140,
                    child: _EmptyPanel(icon: FontAwesomeIcons.userGroup),
                  ),
                ),
                const SizedBox(height: 20),
                const _SectionCard(
                  icon: FontAwesomeIcons.boxOpen,
                  iconColor: Color(0xFFF59E0B),
                  title: 'تنبيهات المخزون المنخفض',
                  body: SizedBox(
                    height: 140,
                    child: _EmptyPanel(icon: FontAwesomeIcons.boxesStacked),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
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

class _ChartPlaceholder extends StatelessWidget {
  const _ChartPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEF2F7)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const FaIcon(
              FontAwesomeIcons.chartColumn,
              size: 34,
              color: Color(0xFFCBD5E1),
            ),
            const SizedBox(height: 8),
            Text(
              '—',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
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
              style: AppTheme.light.textTheme.bodySmall
                  ?.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}