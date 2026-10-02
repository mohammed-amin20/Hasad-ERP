import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/app_progress.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/status_badge.dart';
import '../../domain/invoices/invoice.dart';
import '../../domain/invoices/invoice_sync.dart';
import '../../domain/products/product.dart';
import '../providers/auth_providers.dart';
import '../providers/offline_sync_providers.dart';
import '../providers/purchases_providers.dart';
import '../providers/sales_providers.dart';
import 'payment_sheets.dart';
import 'record_table.dart';
import 'state_views.dart';
class InvoiceListView extends ConsumerWidget {
  const InvoiceListView({
    super.key,
    required this.invoices,
    required this.onTap,
  });

  final List<Invoice> invoices;
  final ValueChanged<Invoice> onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // No `valueOrNull` in this project's Riverpod; an error/loading state
    // degrades to "no badges" rather than an empty list.
    final syncStates = ref.watch(invoiceSyncStatesProvider).maybeWhen(
      data: (v) => v,
      orElse: () => const <String, InvoiceSyncState>{},
    );
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
          cell: (context, invoice) {
            // Absence of a badge means fully synced, so only the states that
            // still need attention are rendered.
            final sync =
                syncStates[invoice.id] ?? InvoiceSyncState.synced;
            // `Wrap`, not a `Row`: this cell is `flex: 2` (~155px at 768, the
            // narrowest the table layout ever gets) and an unsynced
            // consignment invoice makes three badges. Wrap degrades to a
            // second line; a `mainAxisSize.min` Row would throw
            // RenderFlex overflow. Spacing is a multiple of 4 per DESIGN_SYSTEM.
            return Wrap(
              spacing: 4,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                StatusBadge(
                  label: invoice.status.label,
                  palette: badgeForStatus(invoice.status),
                ),
                if (invoice.ownership == InvoiceOwnership.consignment)
                  StatusBadge(
                    label: invoice.ownership.label,
                    palette: badgeForOwnership(invoice.ownership),
                  ),
                if (sync != InvoiceSyncState.synced)
                  StatusBadge(label: sync.label, palette: badgeForSync(sync)),
              ],
            );
          },
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
    // Every header/money field below reads `live`, NOT the captured [invoice].
    // See [_liveInvoice] for why the snapshot alone is wrong.
    final live = _liveInvoice(ref, invoice);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: FutureBuilder<List<InvoiceItem>>(
        // [invoice], deliberately NOT [live]. `_liveInvoice` resolves a row by
        // `row.id == captured.id` or returns `captured`, so `live.id` is always
        // this same string: changing it here would be a no-op. The real fix is
        // one layer down — `OfflineInvoiceRepository.items()` normalizes EITHER
        // id space through `id_map` before it reaches the network, because a
        // captured local uuid is not an id the server ever issued. Normalizing
        // there also keeps `id_map` knowledge out of the presentation layer.
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
                      'فاتورة ${live.no}',
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  StatusBadge(
                    label: live.status.label,
                    palette: badgeForStatus(live.status),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${live.partyName ?? ''} · ${formatInvoiceDate(live.date)}',
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
              _TotalRow(label: 'الإجمالي', value: live.total),
              const SizedBox(height: 8),
              _TotalRow(label: 'المدفوع', value: live.paid),
              const SizedBox(height: 8),
              _TotalRow(
                label: 'المتبقي',
                value: live.remaining,
                emphasized: live.remaining > 0,
              ),
              const SizedBox(height: 20),
              if (live.remaining > 0 &&
                  live.ownership != InvoiceOwnership.consignment &&
                  _canPay(ref)) ...[
                ElevatedButton.icon(
                  onPressed: () =>
                      showRecordPaymentSheet(context, invoice: live),
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

/// The row the invoice list currently holds for the invoice this sheet was
/// opened on, falling back to [captured] while the list is loading, has failed,
/// or no longer lists it.
///
/// ## Why the captured snapshot cannot be the only source
///
/// Both invoice screens open this sheet as
/// `builder: (_) => InvoiceDetailSheet(invoice: invoice)` — a snapshot of the
/// row as the list held it at tap time. A modal route is not rebuilt when the
/// widget that opened it rebuilds, and this sheet watched nothing, so it kept
/// rendering the frozen `paid` / `remaining` / `status`. That is the whole
/// defect: recording a payment offline restates the figures in the local mirror
/// and `PaymentActions._refresh()` invalidates the list, but the sheet above the
/// list never saw it — so the user watched old numbers while the SnackBar the
/// write raised quoted the new remaining.
///
/// Watching the list provider is therefore a *reuse*, not a new read: the
/// invalidation already rebuilds that exact provider for the list behind the
/// sheet, so this adds a second subscriber to one in-flight read and no I/O of
/// its own. It also keeps [_merged] the single authority for local pending money
/// instead of re-deriving that rule in the UI.
///
/// The fallback is a real limitation and is deliberate: a row the active search
/// or date filter excludes would resolve to the stale snapshot. It was opened
/// from that same filtered list, and recording a payment changes neither the
/// invoice's type, number, party nor date, so it cannot leave the filter on its
/// own.
Invoice _liveInvoice(WidgetRef ref, Invoice captured) {
  final rows = ref.watch(
    captured.type == 'sale'
        ? saleInvoicesListProvider
        : purchaseInvoicesListProvider,
  );
  final invoices = rows.maybeWhen(
    data: (v) => v,
    orElse: () => const <Invoice>[],
  );
  for (final row in invoices) {
    if (row.id == captured.id) return row;
  }
  return captured;
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
