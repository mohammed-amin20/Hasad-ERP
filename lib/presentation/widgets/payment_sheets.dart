import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/error/app_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/money.dart';
import '../../domain/invoices/invoice.dart';
import '../../domain/payments/payment_repository.dart';
import '../providers/payments_providers.dart';
import 'invoice_input_fields.dart';
import 'invoice_list.dart';

/// Bottom sheet to pay down one invoice via `record_payment`.
void showRecordPaymentSheet(BuildContext context, {required Invoice invoice}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _RecordPaymentSheet(invoice: invoice),
  );
}

/// Bottom sheet to bulk-settle a supplier via `settle_supplier`.
void showSettleSupplierSheet(
  BuildContext context, {
  required String supplierId,
  required String supplierName,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) =>
        _SettleSupplierSheet(supplierId: supplierId, supplierName: supplierName),
  );
}

class _RecordPaymentSheet extends ConsumerStatefulWidget {
  const _RecordPaymentSheet({required this.invoice});

  final Invoice invoice;

  @override
  ConsumerState<_RecordPaymentSheet> createState() =>
      _RecordPaymentSheetState();
}

class _RecordPaymentSheetState extends ConsumerState<_RecordPaymentSheet> {
  final _amountCtrl = TextEditingController();
  String? _method = 'cash';
  DateTime _date = DateTime.now();
  final _noteCtrl = TextEditingController();
  bool _submitting = false;

  Invoice get invoice => widget.invoice;

  @override
  void initState() {
    super.initState();
    _amountCtrl.text = Money.editable(invoice.remaining);
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final amount = priceToAgorot(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      messenger.showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.danger,
          content: Text('أدخل مبلغ دفع صحيحاً'),
        ),
      );
      return;
    }
    if (amount > invoice.remaining) {
      messenger.showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.danger,
          content: Text('المبلغ أكبر من المتبقي على الفاتورة'),
        ),
      );
      return;
    }
    if (_method == null) {
      messenger.showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.danger,
          content: Text('اختر طريقة الدفع'),
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final result = await ref.read(paymentActionsProvider.notifier).record(
            PaymentDraft(
              invoiceId: invoice.id,
              amount: amount,
              method: _method!,
              date: _date,
              note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
            ),
          );
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            result.duplicate
                ? 'الدفعة مسجلة بالفعل — الباقي ${Money.format(invoice.remaining)}'
                : 'تم تسجيل الدفعة — الباقي ${Money.format(result.remaining)}',
          ),
        ),
      );
    } on Object catch (error) {
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: AppColors.danger,
          content: Text(mapErrorToAppException(error).message),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'تسجيل دفعة',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            'فاتورة ${invoice.no} · المتبقي ${Money.format(invoice.remaining)}',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: PriceField(
                  controller: _amountCtrl,
                  label: 'المبلغ',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _method,
                  decoration: InputDecoration(
                    labelText: 'طريقة الدفع',
                    prefixIcon: FaIcon(FontAwesomeIcons.wallet),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'cash', child: Text('نقدي')),
                    DropdownMenuItem(value: 'bank', child: Text('بنك')),
                  ],
                  onChanged: (v) => setState(() => _method = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _pickDate,
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'تاريخ الدفعة',
                prefixIcon: FaIcon(FontAwesomeIcons.calendarDay),
              ),
              child: Text(formatInvoiceDate(_date)),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _noteCtrl,
            textInputAction: TextInputAction.done,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'ملاحظات',
              prefixIcon: FaIcon(FontAwesomeIcons.fileLines),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _submitting ? null : _submit,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            child: _submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('حفظ الدفعة'),
          ),
        ],
      ),
    );
  }
}

class _SettleSupplierSheet extends ConsumerStatefulWidget {
  const _SettleSupplierSheet({
    required this.supplierId,
    required this.supplierName,
  });

  final String supplierId;
  final String supplierName;

  @override
  ConsumerState<_SettleSupplierSheet> createState() =>
      _SettleSupplierSheetState();
}

class _SettleSupplierSheetState extends ConsumerState<_SettleSupplierSheet> {
  final _amountCtrl = TextEditingController();
  String? _method = 'cash';
  DateTime _date = DateTime.now();
  final _noteCtrl = TextEditingController();
  bool _submitting = false;

  String get supplierId => widget.supplierId;
  String get supplierName => widget.supplierName;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final amount = priceToAgorot(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      messenger.showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.danger,
          content: Text('أدخل مبلغ تسوية صحيحاً'),
        ),
      );
      return;
    }
    if (_method == null) {
      messenger.showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.danger,
          content: Text('اختر طريقة الدفع'),
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final result = await ref.read(paymentActionsProvider.notifier).settle(
            SettlementDraft(
              supplierId: supplierId,
              amount: amount,
              method: _method!,
              date: _date,
              note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
            ),
          );
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            result.duplicate
                ? 'التسوية مسجلة بالفعل'
                : 'تمت التسوية: ${result.invoicesCount} فاتورة و '
                    '${result.duesCount} عمولة بإجمالي ${Money.format(result.total)}',
          ),
        ),
      );
    } on Object catch (error) {
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: AppColors.danger,
          content: Text(mapErrorToAppException(error).message),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'تسوية المورد',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            '$supplierName — تُسوى أقدم الفواتير والعمولات أولاً',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: PriceField(
                  controller: _amountCtrl,
                  label: 'المبلغ',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _method,
                  decoration: InputDecoration(
                    labelText: 'طريقة الدفع',
                    prefixIcon: FaIcon(FontAwesomeIcons.wallet),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'cash', child: Text('نقدي')),
                    DropdownMenuItem(value: 'bank', child: Text('بنك')),
                  ],
                  onChanged: (v) => setState(() => _method = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _pickDate,
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'تاريخ التسوية',
                prefixIcon: FaIcon(FontAwesomeIcons.calendarDay),
              ),
              child: Text(formatInvoiceDate(_date)),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _noteCtrl,
            textInputAction: TextInputAction.done,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'ملاحظات',
              prefixIcon: FaIcon(FontAwesomeIcons.fileLines),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _submitting ? null : _submit,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            child: _submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('تنفيذ التسوية'),
          ),
        ],
      ),
    );
  }
}