import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/app_progress.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/status_badge.dart';
import '../../domain/invoices/invoice.dart';
import '../../domain/products/product.dart';
import '../providers/auth_providers.dart';
import '../providers/sales_providers.dart';
import 'payment_sheets.dart';

/// Reusable invoice list (shared by sales and purchases screens).
class InvoiceListView extends StatelessWidget {
  const InvoiceListView({
    super.key,
    required this.invoices,
    required this.onTap,
  });

  final List<Invoice> invoices;
  final ValueChanged<Invoice> onTap;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: invoices.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final invoice = invoices[index];
        return ListTile(
          onTap: () => onTap(invoice),
          leading: CircleAvatar(
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            child: Text(
              _shortNo(invoice.no),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          title: Text(
            invoice.partyName ?? '',
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            'فاتورة ${invoice.no} · ${formatInvoiceDate(invoice.date)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    Money.format(invoice.total),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      StatusBadge(
                        label: invoice.status.label,
                        palette: badgeForStatus(invoice.status),
                      ),
                      if (invoice.ownership ==
                          InvoiceOwnership.consignment) ...[
                        const SizedBox(width: 4),
                        StatusBadge(
                          label: invoice.ownership.label,
                          palette: badgeForOwnership(invoice.ownership),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(width: 4),
              const FaIcon(
                FontAwesomeIcons.chevronLeft,
                color: AppColors.textMuted,
              ),
            ],
          ),
        );
      },
    );
  }

  String _shortNo(String no) =>
      no.length > 3 ? no.substring(no.length - 3) : no;
}

/// Detail bottom sheet for a single invoice (header, lines, totals).
class InvoiceDetailSheet extends ConsumerWidget {
  const InvoiceDetailSheet({super.key, required this.invoice});

  final Invoice invoice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: FutureBuilder<List<InvoiceItem>>(
        future: ref.read(invoiceRepositoryProvider).items(invoice.id),
        builder: (context, snapshot) {
          final items = snapshot.data ?? const <InvoiceItem>[];
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'فاتورة ${invoice.no}',
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  StatusBadge(
                    label: invoice.status.label,
                    palette: badgeForStatus(invoice.status),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${invoice.partyName ?? ''} · ${formatInvoiceDate(invoice.date)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: AppProgress()),
                ),
              for (final item in items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${item.productName ?? 'منتج'} × '
                          '${formatQty(item.qty, item.productUnitType ?? ProductUnitType.count)}'
                          '${item.productUnit != null ? ' ${item.productUnit}' : ''}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        Money.format(item.total),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              const Divider(height: 32),
              _TotalRow(label: 'الإجمالي', value: invoice.total),
              const SizedBox(height: 8),
              _TotalRow(label: 'المدفوع', value: invoice.paid),
              const SizedBox(height: 8),
              _TotalRow(
                label: 'المتبقي',
                value: invoice.remaining,
                emphasized: invoice.remaining > 0,
              ),
              const SizedBox(height: 20),
              if (invoice.remaining > 0 &&
                  invoice.ownership != InvoiceOwnership.consignment &&
                  _canPay(ref)) ...[
                ElevatedButton.icon(
                  onPressed: () =>
                      showRecordPaymentSheet(context, invoice: invoice),
                  icon: const FaIcon(FontAwesomeIcons.moneyBill),
                  label: const Text('تسجيل دفعة'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
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

/// Payment actions are admin + accountant only (consignment already blocked).
bool _canPay(WidgetRef ref) {
  final user = ref.read(authStateProvider).value;
  return user != null && (user.isAdmin || user.isAccountant);
}

/// Shared error state for list screens.
class ListErrorState extends StatelessWidget {
  const ListErrorState({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
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
            Text('حدث خطأ', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final int value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(label, style: theme.textTheme.bodyMedium),
        const Spacer(),
        Text(
          Money.format(value),
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: emphasized ? AppColors.danger : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

String formatInvoiceDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}/${d.month.toString().padLeft(2, '0')}/'
    '${d.day.toString().padLeft(2, '0')}';
