import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/hasad_card.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../domain/statements/debts_repository.dart';
import '../../providers/statements_providers.dart';
import '../../widgets/filter_bar.dart';
import '../../widgets/record_table.dart';
import '../../widgets/payment_sheets.dart';
import '../statements/statement_screen.dart';

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
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              FilterBar(
                hintText: 'بحث في ديون العملاء...',
                onSearchChanged: (_) {},
                onClearSearch: () {},
              ),
              const SizedBox(height: 16),
              AsyncSection<List<PartyBalance>>(
                value: customersAsync,
                onRetry: () => ref.invalidate(customerDebtsProvider),
                emptyIcon: FontAwesomeIcons.users,
                emptyTitle: 'لا توجد ديون للعملاء',
                emptyMessage: 'سجل فواتير مبيعات لعملاء لظهور الذمم هنا.',
                builder: (context, balances) => _PartyTable(
                  balances: balances,
                  partyType: 'customer',
                  leadingColor: AppColors.primary,
                  onTap: (balance) => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => StatementScreen(
                        partyType: 'customer',
                        partyId: balance.id,
                        partyName: balance.name,
                      ),
                    ),
                  ),
                  onSettle: null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              FilterBar(
                hintText: 'بحث في ديون الموردين...',
                onSearchChanged: (_) {},
                onClearSearch: () {},
              ),
              const SizedBox(height: 16),
              AsyncSection<List<PartyBalance>>(
                value: suppliersAsync,
                onRetry: () => ref.invalidate(supplierDebtsProvider),
                emptyIcon: FontAwesomeIcons.store,
                emptyTitle: 'لا توجد ديون للموردين',
                emptyMessage: 'سجل فواتير مشتريات من موردين لظهور الذمم هنا.',
                builder: (context, balances) => _PartyTable(
                  balances: balances,
                  partyType: 'supplier',
                  leadingColor: AppColors.danger,
                  onTap: (balance) => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => StatementScreen(
                        partyType: 'supplier',
                        partyId: balance.id,
                        partyName: balance.name,
                      ),
                    ),
                  ),
                  onSettle: (balance) => showSettleSupplierSheet(
                    context,
                    supplierId: balance.id,
                    supplierName: balance.name,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PartyTable extends StatelessWidget {
  const _PartyTable({
    required this.balances,
    required this.partyType,
    required this.leadingColor,
    required this.onTap,
    this.onSettle,
  });

  final List<PartyBalance> balances;
  final String partyType;
  final Color leadingColor;
  final void Function(PartyBalance) onTap;
  final void Function(PartyBalance)? onSettle;

  @override
  Widget build(BuildContext context) {
    return RecordTable<PartyBalance>(
      items: balances,
      onTap: onTap,
      columns: [
        RecordColumn<PartyBalance>(
          label: partyType == 'customer' ? 'العميل' : 'المورد',
          primary: true,
          flex: 3,
          cell: (context, b) => Row(
            children: [
              IconChip(
                icon: partyType == 'customer'
                    ? FontAwesomeIcons.user
                    : FontAwesomeIcons.store,
                color: leadingColor,
                size: 32,
                iconSize: 13,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  b.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
        RecordColumn<PartyBalance>(
          label: 'الرصيد',
          flex: 2,
          cell: (context, b) => Text(
            Money.format(b.amount),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: leadingColor,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        RecordColumn<PartyBalance>(
          label: 'النوع',
          flex: 2,
          cell: (context, b) => StatusBadge(
            label: onSettle != null ? 'مورد' : 'عميل',
            palette: onSettle != null
                ? BadgePalette.commission
                : BadgePalette.partial,
          ),
        ),
      ],
      trailing: (context, b) => onSettle != null
          ? OutlinedButton.icon(
              onPressed: () => onSettle!(b),
              icon: const FaIcon(FontAwesomeIcons.handHoldingDollar, size: 12),
              iconAlignment: IconAlignment.end,
              label: const Text('تسوية'),
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
            )
          : const FaIcon(
              FontAwesomeIcons.chevronLeft,
              color: AppColors.textMuted,
            ),
    );
  }
}
