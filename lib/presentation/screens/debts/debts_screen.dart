import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../domain/statements/debts_repository.dart';
import '../../providers/statements_providers.dart';
import '../../widgets/payment_sheets.dart';
import '../../widgets/invoice_list.dart';
import '../statements/statement_screen.dart';

/// Debts overview: what customers owe us + what we owe suppliers.
class DebtsScreen extends ConsumerWidget {
  const DebtsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customersAsync = ref.watch(customerDebtsProvider);
    final suppliersAsync = ref.watch(supplierDebtsProvider);

    return PageScaffold(
      title: 'الذمم والاستحقاقات',
      subtitle: 'ما لنا على العملاء وما علينا للموردين',
      child: ListView(
        children: [
          _sectionTitle(context, 'لنا على العملاء'),
          const SizedBox(height: 8),
          customersAsync.when(
            loading: () => const _LoadingRow(label: 'جاري تحميل ديون العملاء...'),
            error: (e, _) => ListErrorState(message: e.toString()),
            data: (balances) => balances.isEmpty
                ? const _EmptyHint(label: 'لا توجد ديون مسجلة للعملاء')
                : _partyList(
                    context,
                    ref,
                    balances,
                    partyType: 'customer',
                    leadingColor: AppColors.primary,
                  ),
          ),
          const SizedBox(height: 24),
          _sectionTitle(context, 'علينا للموردين'),
          const SizedBox(height: 8),
          suppliersAsync.when(
            loading: () => const _LoadingRow(label: 'جاري تحميل ديون الموردين...'),
            error: (e, _) => ListErrorState(message: e.toString()),
            data: (balances) => balances.isEmpty
                ? const _EmptyHint(label: 'لا توجد ديون مسجلة للموردين')
                : _partyList(
                    context,
                    ref,
                    balances,
                    partyType: 'supplier',
                    leadingColor: AppColors.danger,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    final theme = Theme.of(context);
    return Text(title, style: theme.textTheme.titleLarge);
  }

  Widget _partyList(
    BuildContext context,
    WidgetRef ref,
    List<PartyBalance> balances, {
    required String partyType,
    required Color leadingColor,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < balances.length; i++) ...[
            _PartyTile(
              balance: balances[i],
              leadingColor: leadingColor,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => StatementScreen(
                      partyType: partyType,
                      partyId: balances[i].id,
                      partyName: balances[i].name,
                    ),
                  ),
                );
              },
              onSettle: partyType == 'supplier'
                  ? () => showSettleSupplierSheet(
                        context,
                        supplierId: balances[i].id,
                        supplierName: balances[i].name,
                      )
                  : null,
            ),
            if (i < balances.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

class _PartyTile extends StatelessWidget {
  const _PartyTile({
    required this.balance,
    required this.leadingColor,
    required this.onTap,
    this.onSettle,
  });

  final PartyBalance balance;
  final Color leadingColor;
  final VoidCallback onTap;
  final VoidCallback? onSettle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: leadingColor.withValues(alpha: 0.12),
        child: Text(
          balance.name.isEmpty ? '؟' : balance.name.substring(0, 1),
          style: TextStyle(
            color: leadingColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      title: Text(
        balance.name,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                Money.format(balance.amount),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: leadingColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  StatusBadge(
                    label: onSettle != null ? 'مورد' : 'عميل',
                    palette: onSettle != null
                        ? BadgePalette.info
                        : BadgePalette.partial,
                  ),
                  if (onSettle != null) ...[
                    const SizedBox(width: 4),
                    TextButton(
                      onPressed: onSettle,
                      child: const Text('تسوية'),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_left, color: AppColors.textMuted),
        ],
      ),
    );
  }
}

class _LoadingRow extends StatelessWidget {
  const _LoadingRow({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: AppColors.textMuted),
      ),
    );
  }
}
