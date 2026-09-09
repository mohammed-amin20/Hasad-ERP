import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../domain/accounts/account.dart';
import '../../../domain/reports/ledger.dart' as ledger_models;
import '../../providers/accounts_providers.dart';
import '../../providers/report_providers.dart';

class LedgerScreen extends ConsumerStatefulWidget {
  const LedgerScreen({super.key});

  @override
  ConsumerState<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends ConsumerState<LedgerScreen> {
  @override
  Widget build(BuildContext context) {
    final query = ref.watch(ledgerQueryProvider);
    final statementAsync = ref.watch(ledgerStatementProvider);

    return PageScaffold(
      title: 'الأستاذ العام',
      subtitle: 'حركات الحساب الجارية',
      actions: [
        IconButton(
          tooltip: 'تحديث',
          onPressed: () => ref.invalidate(ledgerStatementProvider),
          icon: const FaIcon(FontAwesomeIcons.rotate),
        ),
      ],
      child: Column(
        children: [
          _LedgerControls(
            accountId: query.accountId,
            from: query.from,
            to: query.to,
            onAccountChanged: (accountId) =>
                ref.read(ledgerQueryProvider.notifier).update(accountId: accountId),
            onFromTap: _pickFrom,
            onToTap: _pickTo,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: statementAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrorState(message: e.toString()),
              data: (statement) => statement == null
                  ? const _SelectAccountState()
                  : _LedgerView(statement: statement),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickFrom() async {
    final query = ref.read(ledgerQueryProvider);
    final picked = await showDatePicker(
      context: context,
      initialDate: query.from,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    ref.read(ledgerQueryProvider.notifier).update(
          from: picked,
          to: query.to.isBefore(picked) ? picked : query.to,
        );
  }

  Future<void> _pickTo() async {
    final query = ref.read(ledgerQueryProvider);
    final picked = await showDatePicker(
      context: context,
      initialDate: query.to,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    ref.read(ledgerQueryProvider.notifier).update(
          to: picked,
          from: query.from.isAfter(picked) ? picked : query.from,
        );
  }
}

class _LedgerControls extends ConsumerWidget {
  const _LedgerControls({
    required this.accountId,
    required this.from,
    required this.to,
    required this.onAccountChanged,
    required this.onFromTap,
    required this.onToTap,
  });

  final String? accountId;
  final DateTime from;
  final DateTime to;
  final ValueChanged<String?> onAccountChanged;
  final VoidCallback onFromTap;
  final VoidCallback onToTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chartAsync = ref.watch(chartOfAccountsProvider);
    final accounts = chartAsync.maybeWhen(
      data: (list) => list,
      orElse: () => const <Account>[],
    );

    return Column(
      children: [
        DropdownButtonFormField<String>(
          initialValue: accountId,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'الحساب',
            prefixIcon: FaIcon(FontAwesomeIcons.sitemap),
          ),
          items: [
            for (final account in accounts)
              DropdownMenuItem(
                value: account.id,
                child: Text('${account.code} — ${account.name}'),
              ),
          ],
          onChanged: chartAsync.hasError || accounts.isEmpty
              ? null
              : onAccountChanged,
        ),
        if (chartAsync.hasError) ...[
          const SizedBox(height: 4),
          Text(
            'تعذّر تحميل الحسابات — حدّث دليل الحسابات ثم أعد المحاولة',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.danger,
                ),
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _DateChip(label: 'من', date: from, onTap: onFromTap),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _DateChip(label: 'إلى', date: to, onTap: onToTap),
            ),
          ],
        ),
      ],
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
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LedgerView extends StatelessWidget {
  const _LedgerView({required this.statement});

  final ledger_models.LedgerStatement statement;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      statement.code,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      statement.name,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    statement.type.label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _SummaryItem(
                    label: 'رصيد افتتاحي',
                    value: statement.opening,
                  ),
                  const Spacer(),
                  _SummaryItem(
                    label: 'الرصيد الختامي',
                    value: statement.closing,
                    emphasize: true,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _LedgerTable(statement: statement),
      ],
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final int value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          Money.format(value),
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: emphasize
                ? (value < 0 ? AppColors.danger : AppColors.success)
                : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _LedgerTable extends StatelessWidget {
  const _LedgerTable({required this.statement});

  final ledger_models.LedgerStatement statement;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (statement.lines.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            const FaIcon(
              FontAwesomeIcons.bookOpen,
              size: 40,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 12),
            Text(
              'لا توجد حركات في هذه الفترة',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      );
    }

    final cell = theme.textTheme.bodySmall?.copyWith(
      fontWeight: FontWeight.w600,
    );
    final header = theme.textTheme.bodySmall?.copyWith(
      color: AppColors.textMuted,
      fontWeight: FontWeight.w800,
    );

    return Container(
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
                Expanded(flex: 3, child: Text('التاريخ', style: header)),
                Expanded(flex: 2, child: Text('رقم القيد', style: header)),
                Expanded(flex: 4, child: Text('البيان', style: header)),
                Expanded(flex: 2, child: Text('مدين', style: header)),
                Expanded(flex: 2, child: Text('دائن', style: header)),
                Expanded(flex: 2, child: Text('الرصيد', style: header)),
              ],
            ),
          ),
          const Divider(height: 1),
          for (final line in statement.lines)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(_fmtDate(line.date), style: cell),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text('${line.entryNo}', style: cell),
                  ),
                  Expanded(
                    flex: 4,
                    child: Text(
                      line.memo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: cell,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      line.debit > 0 ? Money.format(line.debit) : '',
                      style: cell,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      line.credit > 0 ? Money.format(line.credit) : '',
                      style: cell,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      Money.format(line.balance),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: line.balance < 0
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
                const Expanded(flex: 3, child: SizedBox.shrink()),
                const Spacer(),
                Text(
                  'الإجمالي',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 24),
                Text(
                  Money.format(statement.totalDebit),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 24),
                Text(
                  Money.format(statement.totalCredit),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 36),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectAccountState extends StatelessWidget {
  const _SelectAccountState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const FaIcon(
              FontAwesomeIcons.sitemap,
              size: 48,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 16),
            Text(
              'اختر حساباً لعرض حركاته',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
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