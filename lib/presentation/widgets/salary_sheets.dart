import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/app_progress.dart';
import '../../core/error/app_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/money.dart';
import '../../domain/products/product.dart';
import '../../domain/salaries/salary_repository.dart';
import '../providers/salaries_providers.dart';
import 'invoice_input_fields.dart';
import 'product_picker_sheet.dart';

/// Bottom sheet to record one employee movement via `add_employee_movement`.
void showAddMovementSheet(
  BuildContext context, {
  required String employeeId,
  required String employeeName,
  required DateTime month,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _AddMovementSheet(
      employeeName: employeeName,
      employeeId: employeeId,
      month: month,
    ),
  );
}

/// Bottom sheet to pay salary via `pay_salary`.
void showPaySalarySheet(
  BuildContext context, {
  required String employeeId,
  required String employeeName,
  required DateTime month,
  required EmployeeEntitlement entitlement,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _PaySalarySheet(
      employeeId: employeeId,
      employeeName: employeeName,
      month: month,
      entitlement: entitlement,
    ),
  );
}

class _AddMovementSheet extends ConsumerStatefulWidget {
  const _AddMovementSheet({
    required this.employeeId,
    required this.employeeName,
    required this.month,
  });

  final String employeeId;
  final String employeeName;
  final DateTime month;

  @override
  ConsumerState<_AddMovementSheet> createState() => _AddMovementSheetState();
}

class _AddMovementSheetState extends ConsumerState<_AddMovementSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();
  String? _direction = 'out';
  String? _category = 'advance';
  Product? _product;
  DateTime _date = DateTime.now();
  bool _submitting = false;

  String get _employeeId => widget.employeeId;
  DateTime get _month => widget.month;

  bool get _isOut => _direction == 'out';
  bool get _isProduct => _isOut && _category == 'product';

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  List<String> _categories(String direction) => direction == 'in'
      ? const ['bonus', 'allowance']
      : const ['advance', 'product', 'other'];

  String _categoryLabel(String c) => switch (c) {
    'bonus' => 'مكافأة',
    'allowance' => 'بدل',
    'advance' => 'سلفة',
    'product' => 'منتج',
    'other' => 'أخرى',
    _ => c,
  };

  void _onDirectionChanged(String? v) {
    if (v == null) return;
    setState(() {
      _direction = v;
      final cats = _categories(v);
      if (!cats.contains(_category)) _category = cats.first;
    });
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

  Future<void> _pickProduct() async {
    final product = await showProductPicker(context);
    if (product != null) setState(() => _product = product);
  }

  Future<void> _submit() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    if (_isProduct && _product == null) {
      messenger.showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.danger,
          content: Text('اختر المنتج'),
        ),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    int? amount;
    double? qty;
    if (_isProduct) {
      qty = double.parse(_qtyCtrl.text.trim());
      _amountCtrl.clear();
    } else {
      amount = priceToAgorot(_amountCtrl.text.trim(), allowZero: false)!;
    }

    setState(() => _submitting = true);
    try {
      final result = await ref
          .read(salaryActionsProvider.notifier)
          .movement(
            MovementDraft(
              employeeId: _employeeId,
              month: _month,
              direction: _direction!,
              category: _category!,
              amount: amount,
              description: _noteCtrl.text.trim().isEmpty
                  ? null
                  : _noteCtrl.text.trim(),
              productId: _product?.id,
              qty: qty,
              date: _date,
            ),
          );
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            result.duplicate
                ? 'هذه الحركة مسجلة بالفعل'
                : 'تم تسجيل الحركة — بمبلغ ${Money.format(result.amount)}',
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
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('حركة شهرية', style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                '${widget.employeeName} · ${_month.year}/${_month.month.toString().padLeft(2, '0')}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _direction,
                      decoration: InputDecoration(
                        labelText: 'الجهة',
                        prefixIcon: FaIcon(FontAwesomeIcons.arrowsUpDown),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'in', child: Text('إضافة')),
                        DropdownMenuItem(value: 'out', child: Text('خصم')),
                      ],
                      onChanged: _onDirectionChanged,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _category,
                      decoration: InputDecoration(
                        labelText: 'النوع',
                        prefixIcon: Icon(Icons.category_outlined),
                      ),
                      items: [
                        for (final c in _categories(_direction!))
                          DropdownMenuItem(
                            value: c,
                            child: Text(_categoryLabel(c)),
                          ),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _category = v);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_isProduct) ...[
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _pickProduct,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'المنتج',
                      prefixIcon: FaIcon(FontAwesomeIcons.boxesStacked),
                    ),
                    child: Text(
                      _product == null
                          ? 'اختر منتجاً...'
                          : '${_product!.name} · المتوفر ${formatQty(_product!.qty, _product!.unitType)}',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ProductQuantityField(
                  controller: _qtyCtrl,
                  unitType: _product?.unitType ?? ProductUnitType.count,
                  unit: _product?.unit ?? 'قطعة',
                ),
              ] else ...[
                PriceField(
                  controller: _amountCtrl,
                  label: 'المبلغ',
                  requiredMessage: 'أدخل مبلغاً صحيحاً',
                  extraValidator: (v) {
                    final amount = priceToAgorot(v ?? '');
                    if (amount == null || amount <= 0) {
                      return 'أدخل مبلغاً صحيحاً';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 12),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'تاريخ الحركة',
                    prefixIcon: FaIcon(FontAwesomeIcons.calendarDay),
                  ),
                  child: Text(
                    '${_date.year}/${_date.month.toString().padLeft(2, '0')}/${_date.day.toString().padLeft(2, '0')}',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _noteCtrl,
                textInputAction: TextInputAction.done,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'وصف الحركة',
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
                        child: AppProgress(strokeWidth: 2),
                      )
                    : Text('حفظ الحركة'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaySalarySheet extends ConsumerStatefulWidget {
  const _PaySalarySheet({
    required this.employeeId,
    required this.employeeName,
    required this.month,
    required this.entitlement,
  });

  final String employeeId;
  final String employeeName;
  final DateTime month;
  final EmployeeEntitlement entitlement;

  @override
  ConsumerState<_PaySalarySheet> createState() => _PaySalarySheetState();
}

class _PaySalarySheetState extends ConsumerState<_PaySalarySheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  String? _method = 'cash';
  DateTime _date = DateTime.now();
  bool _submitting = false;

  EmployeeEntitlement get entitlement => widget.entitlement;

  @override
  void initState() {
    super.initState();
    if (entitlement.netDue > 0) {
      _amountCtrl.text = Money.editable(entitlement.netDue);
    }
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

    if (!_formKey.currentState!.validate()) return;
    final paid = priceToAgorot(_amountCtrl.text.trim(), allowZero: false)!;

    setState(() => _submitting = true);
    try {
      final result = await ref
          .read(salaryActionsProvider.notifier)
          .pay(
            SalaryDraft(
              employeeId: widget.employeeId,
              month: widget.month,
              paid: paid,
              method: _method!,
              date: _date,
              note: _noteCtrl.text.trim().isEmpty
                  ? null
                  : _noteCtrl.text.trim(),
            ),
          );
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            result.duplicate
                ? 'راتب هذا الشهر مسجل بالفعل'
                : 'تم صرف الراتب — قيد ${result.entryNo}'
                      '${result.arrearsCarried > 0 ? ' (متبقي ${Money.format(result.arrearsCarried)})' : ''}',
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
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('صرف الراتب', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              '${widget.employeeName} · صافي المستحقات ${Money.format(entitlement.netDue)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: PriceField(
                    controller: _amountCtrl,
                    label: 'المبلغ المصروف',
                    requiredMessage: 'أدخل مبلغ صرف صحيحاً',
                    extraValidator: (v) {
                      final paid = priceToAgorot(v ?? '');
                      if (paid == null || paid <= 0) {
                        return 'أدخل مبلغ صرف صحيحاً';
                      }
                      if (paid > entitlement.netDue) {
                        return 'المبلغ أكبر من صافي المستحقات';
                      }
                      return null;
                    },
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
                    validator: (v) => v == null ? 'اختر طريقة الدفع' : null,
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
                  labelText: 'تاريخ الصرف',
                  prefixIcon: FaIcon(FontAwesomeIcons.calendarDay),
                ),
                child: Text(
                  '${_date.year}/${_date.month.toString().padLeft(2, '0')}/${_date.day.toString().padLeft(2, '0')}',
                ),
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
                      child: AppProgress(strokeWidth: 2),
                    )
                  : const Text('تنفيذ الصرف'),
            ),
          ],
        ),
      ),
    );
  }
}
