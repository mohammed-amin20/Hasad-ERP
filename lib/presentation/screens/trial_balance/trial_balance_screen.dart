import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_progress.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../domain/reports/trial_balance.dart';
import '../../providers/report_providers.dart';

class TrialBalanceScreen extends ConsumerStatefulWidget {
  const TrialBalanceScreen({super.key});

  @override
  ConsumerState<TrialBalanceScreen> createState() => _TrialBalanceScreenState();
}

class _TrialBalanceScreenState extends ConsumerState<TrialBalanceScreen> {
  Future<void> _pickDate() async {
    final current = ref.read(asOfDateProvider);
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    ref.read(asOfDateProvider.notifier).update(picked);
  }

  @override
  Widget build(BuildContext context) {
    final asOf = ref.watch(asOfDateProvider);
    final reportAsync = ref.watch(trialBalanceProvider);

    return PageScaffold(
      title: 'ميزان المراجعة',
      subtitle: 'مطابقة المدين والدائن',
      actions: [
        IconButton(
          tooltip: 'تحديث',
          onPressed: () => ref.invalidate(trialBalanceProvider),
          icon: const FaIcon(FontAwesomeIcons.rotate),
        ),
      ],
      child: Column(
        children: [
          _AsOfChip(label: 'كالتاريخ', date: asOf, onTap: _pickDate),
          const SizedBox(height: 16),
          Expanded(
            child: reportAsync.when(
              loading: () => const Center(child: AppProgress()),
              error: (e, _) => _ErrorState(message: e.toString()),
              data: (report) => _TrialBalanceView(report: report),
            ),
          ),
        ],
      ),
    );
  }
}

class _AsOfChip extends StatelessWidget {
  const _AsOfChip({
    required this.label,
    required this.date,
    required this.onTap,
  });

  final String label;
  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Material(
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
              mainAxisSize: MainAxisSize.min,
              children: [
                const FaIcon(
                  FontAwesomeIcons.calendarDays,
                  size: 16,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  '$label ${_fmtDate(date)}',
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TrialBalanceView extends StatelessWidget {
  const _TrialBalanceView({required this.report});

  final TrialBalanceReport report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Row(
          children: [
            Expanded(child: _BalancePill(balanced: report.balanced)),
            const SizedBox(width: 12),
            Expanded(
              child: _TotalsCard(
                label: 'المجاميع',
                debit: report.totalDebit,
                credit: report.totalCredit,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text('الكود', style: _header(theme)),
                    ),
                    Expanded(
                      flex: 5,
                      child: Text('الحساب', style: _header(theme)),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text('مدين', style: _header(theme)),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text('دائن', style: _header(theme)),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text('الرصيد', style: _header(theme)),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              for (final row in report.rows)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          row.code,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 5,
                        child: Text(
                          row.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          row.debit > 0 ? Money.format(row.debit) : '',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          row.credit > 0 ? Money.format(row.credit) : '',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          Money.format(row.balance),
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: row.balance < 0
                                ? AppColors.danger
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Row(
                  children: [
                    const Expanded(flex: 7, child: SizedBox.shrink()),
                    Expanded(
                      flex: 3,
                      child: Text(
                        Money.format(report.totalDebit),
                        textAlign: TextAlign.end,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        Money.format(report.totalCredit),
                        textAlign: TextAlign.end,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        Money.format(report.totalDebit - report.totalCredit),
                        textAlign: TextAlign.end,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  TextStyle? _header(ThemeData theme) => theme.textTheme.bodySmall?.copyWith(
    color: AppColors.textMuted,
    fontWeight: FontWeight.w800,
  );
}

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({
    required this.label,
    required this.debit,
    required this.credit,
  });

  final String label;
  final int debit;
  final int credit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Text(
            'مدين ${Money.format(debit)}',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            'دائن ${Money.format(credit)}',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _BalancePill extends StatelessWidget {
  const _BalancePill({required this.balanced});

  final bool balanced;

  @override
  Widget build(BuildContext context) {
    final color = balanced ? AppColors.success : AppColors.danger;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FaIcon(
            balanced ? FontAwesomeIcons.check : FontAwesomeIcons.circleXmark,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              balanced ? 'الميزان متوازن' : 'الميزان غير متوازن',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: color, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const FaIcon(
              FontAwesomeIcons.circleExclamation,
              size: 48,
              color: AppColors.danger,
            ),
            const SizedBox(height: 16),
            Text('حدث خطأ', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _fmtDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}/${d.month.toString().padLeft(2, '0')}/'
    '${d.day.toString().padLeft(2, '0')}';
