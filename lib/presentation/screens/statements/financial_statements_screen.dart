import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_progress.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/hasad_card.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../data/offline/report_keys.dart';
import '../../../domain/reports/balance_sheet.dart' as sheet_models;
import '../../../domain/reports/income_statement.dart' as pnl_models;
import '../../providers/report_providers.dart';
import '../../widgets/freshness_chip.dart';

class FinancialStatementsScreen extends ConsumerStatefulWidget {
  const FinancialStatementsScreen({super.key});

  @override
  ConsumerState<FinancialStatementsScreen> createState() =>
      _FinancialStatementsScreenState();
}

class _FinancialStatementsScreenState
    extends ConsumerState<FinancialStatementsScreen> {
  bool _showBalanceSheet = false;

  @override
  Widget build(BuildContext context) {
    final reportAsync = _showBalanceSheet
        ? ref.watch(balanceSheetProvider)
        : ref.watch(incomeStatementProvider);
    final range = ref.watch(incomeRangeProvider);
    final asOf = ref.watch(asOfDateProvider);
    final cacheKey = _showBalanceSheet ? balanceKey(asOf) : incomeKey(range.from, range.to);

    return PageScaffold(
      title: 'القوائم المالية',
      subtitle: 'قائمة الدخل والميزانية العمومية',
      actions: [
        FreshnessChip(cacheKey: cacheKey),
        IconButton(
          tooltip: 'تحديث',
          onPressed: () => ref.invalidate(
            _showBalanceSheet ? balanceSheetProvider : incomeStatementProvider,
          ),
          icon: const FaIcon(FontAwesomeIcons.rotate),
        ),
      ],
      child: Column(
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('قائمة الدخل')),
              ButtonSegment(value: true, label: Text('الميزانية العمومية')),
            ],
            selected: {_showBalanceSheet},
            onSelectionChanged: (selection) =>
                setState(() => _showBalanceSheet = selection.first),
          ),
          const SizedBox(height: 16),
          if (_showBalanceSheet) _AsOfControl() else _RangeControl(),
          const SizedBox(height: 16),
          Expanded(
            child: reportAsync.when(
              loading: () => const Center(child: AppProgress()),
              error: (e, _) => ErrorStateView(
                message: mapErrorToAppException(e).message,
                onRetry: () => ref.invalidate(
                  _showBalanceSheet ? balanceSheetProvider : incomeStatementProvider,
                ),
              ),
              data: (data) => _showBalanceSheet
                  ? _BalanceSheetView(sheet: data as sheet_models.BalanceSheet)
                  : _IncomeView(statement: data as pnl_models.IncomeStatement),
            ),
          ),
        ],
      ),
    );
  }
}

class _RangeControl extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(incomeRangeProvider);

    Future<void> pick(bool isFrom) async {
      final picked = await showDatePicker(
        context: context,
        initialDate: isFrom ? range.from : range.to,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
      );
      if (picked == null) return;
      ref
          .read(incomeRangeProvider.notifier)
          .update(
            from: isFrom
                ? picked
                : (range.from.isAfter(picked) ? picked : range.from),
            to: isFrom
                ? (picked.isAfter(range.to) ? picked : range.to)
                : picked,
          );
    }

    return Row(
      children: [
        Expanded(
          child: _DateChip(
            label: 'من',
            date: range.from,
            onTap: () => pick(true),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _DateChip(
            label: 'إلى',
            date: range.to,
            onTap: () => pick(false),
          ),
        ),
      ],
    );
  }
}

class _AsOfControl extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asOf = ref.watch(asOfDateProvider);
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: _DateChip(
        label: 'كالتاريخ',
        date: asOf,
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: asOf,
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
          );
          if (picked != null) {
            ref.read(asOfDateProvider.notifier).update(picked);
          }
        },
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({
    required this.label,
    required this.date,
    required this.onTap,
  });

  final String label;
  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              const FaIcon(
                FontAwesomeIcons.calendarDays,
                size: 16,
                color: AppColors.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '$label ${_fmtDate(date)}',
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IncomeView extends StatelessWidget {
  const _IncomeView({required this.statement});

  final pnl_models.IncomeStatement statement;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final net = statement.net;
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _SectionCard(
          title: 'الإيرادات',
          icon: FontAwesomeIcons.arrowTrendUp,
          color: AppColors.primary,
          rows: [
            for (final revenue in statement.revenues)
              (code: revenue.code, name: revenue.name, amount: revenue.amount),
          ],
          total: statement.revenueTotal,
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'المصاريف',
          icon: FontAwesomeIcons.arrowTrendDown,
          color: AppColors.warning,
          rows: [
            for (final expense in statement.expenses)
              (code: expense.code, name: expense.name, amount: expense.amount),
          ],
          total: statement.expenseTotal,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerRight,
              end: Alignment.centerLeft,
              colors: net >= 0
                  ? [
                      AppColors.success.withValues(alpha: 0.14),
                      AppColors.surface,
                    ]
                  : [
                      AppColors.danger.withValues(alpha: 0.12),
                      AppColors.surface,
                    ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: net >= 0 ? AppColors.success : AppColors.danger,
            ),
          ),
          child: Row(
            children: [
              FaIcon(
                net >= 0
                    ? FontAwesomeIcons.circleCheck
                    : FontAwesomeIcons.triangleExclamation,
                size: 28,
                color: net >= 0 ? AppColors.success : AppColors.danger,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'صافي الربح (الخسارة)',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                Money.format(net),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: net >= 0 ? AppColors.success : AppColors.danger,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BalanceSheetView extends StatelessWidget {
  const _BalanceSheetView({required this.sheet});

  final sheet_models.BalanceSheet sheet;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _SectionCard(
          title: 'الأصول',
          icon: FontAwesomeIcons.boxArchive,
          color: AppColors.success,
          rows: [
            for (final a in sheet.assets)
              (code: a.code, name: a.name, amount: a.amount),
          ],
          total: sheet.assetsTotal,
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'الخصوم',
          icon: FontAwesomeIcons.creditCard,
          color: AppColors.danger,
          rows: [
            for (final l in sheet.liabilities)
              (code: l.code, name: l.name, amount: l.amount),
          ],
          total: sheet.liabilitiesTotal,
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'حقوق الملكية',
          icon: FontAwesomeIcons.sackDollar,
          color: AppColors.secondary,
          rows: [
            for (final e in sheet.equity)
              (code: e.code, name: e.name, amount: e.amount),
            (
              code: '0001',
              name: 'صافي الدخل حتى اليوم',
              amount: sheet.netIncomeYtd,
            ),
          ],
          total: sheet.equityTotal,
        ),
        const SizedBox(height: 12),
        _SheetCheckCard(sheet: sheet),
      ],
    );
  }
}

class _SheetCheckCard extends StatelessWidget {
  const _SheetCheckCard({required this.sheet});

  final sheet_models.BalanceSheet sheet;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = sheet.balanced ? AppColors.success : AppColors.danger;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Flexible(
                child: Text(
                  'الأصول',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Spacer(),
              Text(
                Money.format(sheet.assetsTotal),
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Flexible(
                child: Text(
                  'الخصوم + حقوق الملكية',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Spacer(),
              Text(
                Money.format(sheet.liabilitiesTotal + sheet.equityTotal),
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              FaIcon(
                sheet.balanced
                    ? FontAwesomeIcons.circleCheck
                    : FontAwesomeIcons.circleXmark,
                size: 18,
                color: color,
              ),
              const SizedBox(width: 8),
              Text(
                sheet.balanced
                    ? 'الميزانية متوازنة'
                    : 'الميزانية غير متوازنة (فرق ${Money.format(sheet.check)})',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.rows,
    required this.total,
  });

  final String title;
  final FaIconData icon;
  final Color color;
  final List<({String code, String name, int amount})> rows;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return HasadCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          CardHeader(
            title: title,
            icon: icon,
            iconColor: color,
            trailing: Text(
              Money.format(total),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: color,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'لا توجد بنود',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            )
          else
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    SizedBox(
                      width: 56,
                      child: Text(
                        rows[i].code,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        rows[i].name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      Money.format(rows[i].amount),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ],
        ],
      ),
    );
  }
}

String _fmtDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}/${d.month.toString().padLeft(2, '0')}/'
    '${d.day.toString().padLeft(2, '0')}';
