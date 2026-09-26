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
import 'record_table.dart';
import 'state_views.dart';
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
    return RecordTable<Invoice>(
      items: invoices,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 4),
      columns: [
        RecordColumn<Invoice>(
          label: 'الفاتورة',
          primary: true,
          flex: 3,
          cell: (context, invoice) => Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _shortNo(invoice.no),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  invoice.partyName ?? '',
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
        RecordColumn<Invoice>(
          label: 'التاريخ',
          flex: 2,
          cell: (context, invoice) => Text(
            formatInvoiceDate(invoice.date),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
        RecordColumn<Invoice>(
          label: 'الحالة',
          flex: 2,
          cell: (context, invoice) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              StatusBadge(
                label: invoice.status.label,
                palette: badgeForStatus(invoice.status),
              ),
              if (invoice.ownership == InvoiceOwnership.consignment) ...[
                const SizedBox(width: 4),
                StatusBadge(
                  label: invoice.ownership.label,
                  palette: badgeForOwnership(invoice.ownership),
                ),
              ],
            ],
          ),
        ),
        RecordColumn<Invoice>(
          label: 'الإجمالي',
          flex: 2,
          emphasis: true,
          alignment: AlignmentDirectional.centerEnd,
          cell: (context, invoice) => Text(
            Money.format(invoice.total),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }

  String _shortNo(String no) =>
      no.length > 3 ? no.substring(no.length - 3) : no;
}
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
bool _canPay(WidgetRef ref) {
  final user = ref.read(authStateProvider).value;
  return user != null && (user.isAdmin || user.isAccountant);
}
class ListErrorState extends StatelessWidget {
  const ListErrorState({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ErrorStateCard(
          title: 'حدث خطأ',
          message: message,
          onRetry: onRetry,
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
