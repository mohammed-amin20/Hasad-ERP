import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_progress.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/hasad_card.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../domain/suppliers/supplier.dart';
import '../../../domain/suppliers/supplier_draft.dart';
import '../../providers/suppliers_providers.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/filter_bar.dart';
import '../../widgets/record_table.dart';

class SuppliersScreen extends ConsumerStatefulWidget {
  const SuppliersScreen({super.key});

  @override
  ConsumerState<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends ConsumerState<SuppliersScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(suppliersListProvider);

    return PageScaffold(
      title: 'الموردون',
      subtitle: 'الموردون المباشرون وبالعمولة',
      child: Stack(
        children: [
          Column(
            children: [
              FilterBar(
                searchController: _searchCtrl,
                hintText: 'بحث بالاسم أو رقم الهاتف...',
                onSearchChanged: (value) =>
                    ref.read(supplierSearchProvider.notifier).update(value),
                onClearSearch: () {
                  _searchCtrl.clear();
                  ref.read(supplierSearchProvider.notifier).update('');
                  setState(() {});
                },
              ),
              const SizedBox(height: 16),
              Expanded(
                child: AsyncSection<List<Supplier>>(
                  value: listAsync,
                  onRetry: () => ref.invalidate(suppliersListProvider),
                  emptyIcon: FontAwesomeIcons.building,
                  emptyTitle: 'لا يوجد موردون',
                  emptyMessage: 'اضغط على زر الإضافة لتسجيل أول مورد.',
                  emptyAction: FilledButton.icon(
                    onPressed: () => _showSupplierForm(context),
                    icon: const FaIcon(FontAwesomeIcons.plus, size: 13),
                    iconAlignment: IconAlignment.end,
                    label: const Text('إضافة مورد'),
                  ),
                  builder: (context, suppliers) => RecordTable<Supplier>(
                    items: suppliers,
                    columns: [
                      RecordColumn<Supplier>(
                        label: 'المورد',
                        primary: true,
                        flex: 3,
                        cell: (context, s) => Row(
                          children: [
                            IconChip(
                              icon: FontAwesomeIcons.building,
                              color: AppColors.secondary,
                              size: 32,
                              iconSize: 13,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                s.name,
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
                      RecordColumn<Supplier>(
                        label: 'الهاتف',
                        flex: 2,
                        cell: (context, s) => Text(
                          s.phone?.isNotEmpty == true ? s.phone! : '—',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      RecordColumn<Supplier>(
                        label: 'نوع التعامل',
                        flex: 2,
                        cell: (context, s) => s.dealType ==
                                SupplierDealType.commission
                            ? _CommissionBadge(rate: s.commissionRate)
                            : const StatusBadge(
                                label: 'مباشر',
                                palette: BadgePalette.neutral,
                              ),
                      ),
                    ],
                    trailing: (context, s) => PopupMenuButton<String>(
                      tooltip: 'إجراءات المورد',
                      onSelected: (value) {
                        if (value == 'edit') {
                          _showSupplierForm(context, supplier: s);
                        }
                        if (value == 'delete') _confirmDelete(s);
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('تعديل')),
                        PopupMenuItem(value: 'delete', child: Text('حذف')),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            left: 0,
            bottom: 0,
            child: FloatingActionButton(
              heroTag: 'suppliers_add',
              tooltip: 'إضافة مورد',
              onPressed: () => _showSupplierForm(context),
              child: const FaIcon(FontAwesomeIcons.plus),
            ),
          ),
        ],
      ),
    );
  }

  void _showSupplierForm(BuildContext context, {Supplier? supplier}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _SupplierFormSheet(
        supplier: supplier,
        onSave: (draft) async {
          final messenger = ScaffoldMessenger.of(context);
          try {
            final notifier = ref.read(suppliersListProvider.notifier);
            if (supplier == null) {
              await notifier.create(draft);
            } else {
              await notifier.updateSupplier(id: supplier.id, draft: draft);
            }
            if (context.mounted) Navigator.of(context).pop();
            messenger.showSnackBar(
              SnackBar(
                content: Text(
                  supplier == null ? 'تمت إضافة المورد' : 'تم تعديل المورد',
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
          }
        },
      ),
    );
  }

  Future<void> _confirmDelete(Supplier supplier) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'حذف المورد',
      message: 'هل تريد حذف "${supplier.name}" نهائياً؟',
      confirmLabel: 'حذف',
      tone: ConfirmTone.danger,
    );
    if (!confirmed || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(suppliersListProvider.notifier).delete(supplier.id);
      messenger.showSnackBar(const SnackBar(content: Text('تم حذف المورد')));
    } on Object catch (error) {
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: AppColors.danger,
          content: Text(mapErrorToAppException(error).message),
        ),
      );
    }
  }
}

class _CommissionBadge extends StatelessWidget {
  const _CommissionBadge({required this.rate});

  final double? rate;

  @override
  Widget build(BuildContext context) {
    final label = rate == null ? 'بالعمولة' : 'بالعمولة — $rate%';
    return StatusBadge(
      label: label,
      palette: BadgePalette.warning,
    );
  }
}

class _SupplierFormSheet extends StatefulWidget {
  const _SupplierFormSheet({required this.onSave, this.supplier});

  final Future<void> Function(SupplierDraft draft) onSave;
  final Supplier? supplier;

  @override
  State<_SupplierFormSheet> createState() => _SupplierFormSheetState();
}

class _SupplierFormSheetState extends State<_SupplierFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _notesCtrl;
  late final TextEditingController _commissionCtrl;
  late SupplierDealType _dealType;
  bool _submitting = false;

  bool get _isEditing => widget.supplier != null;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.supplier?.name ?? '');
    _phoneCtrl = TextEditingController(text: widget.supplier?.phone ?? '');
    _notesCtrl = TextEditingController(text: widget.supplier?.notes ?? '');
    _dealType = widget.supplier?.dealType ?? SupplierDealType.direct;
    final rate = widget.supplier?.commissionRate;
    _commissionCtrl = TextEditingController(
      text: rate == null ? '' : _formatRate(rate),
    );
  }

  String _formatRate(double rate) =>
      rate == rate.roundToDouble() ? rate.toStringAsFixed(0) : rate.toString();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _notesCtrl.dispose();
    _commissionCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final isCommission = _dealType == SupplierDealType.commission;
    final rateText = _commissionCtrl.text.trim();

    if (!_formKey.currentState!.validate()) return;
    if (isCommission && rateText.isEmpty) {
      _showError('أدخل نسبة العمولة');
      return;
    }

    setState(() => _submitting = true);
    try {
      await widget.onSave(
        SupplierDraft(
          name: _nameCtrl.text.trim(),
          phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          dealType: _dealType,
          commissionRate: isCommission
              ? double.parse(rateText.replaceAll('٪', ''))
              : null,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: AppColors.danger, content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    final isCommission = _dealType == SupplierDealType.commission;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomPadding),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const IconChip(
                    icon: FontAwesomeIcons.building,
                    color: AppColors.secondary,
                    size: 40,
                    iconSize: 18,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _isEditing ? 'تعديل المورد' : 'إضافة مورد جديد',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameCtrl,
                textInputAction: TextInputAction.next,
                autofocus: true,
                autofillHints: const [AutofillHints.name],
                decoration: const InputDecoration(
                  labelText: 'اسم المورد',
                  prefixIcon: FaIcon(FontAwesomeIcons.building),
                ),
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'أدخل اسم المورد' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneCtrl,
                textInputAction: TextInputAction.next,
                keyboardType: TextInputType.phone,
                autofillHints: const [AutofillHints.telephoneNumber],
                decoration: const InputDecoration(
                  labelText: 'رقم الهاتف',
                  prefixIcon: FaIcon(FontAwesomeIcons.phone),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<SupplierDealType>(
                initialValue: _dealType,
                decoration: const InputDecoration(
                  labelText: 'نوع التعامل',
                  prefixIcon: FaIcon(FontAwesomeIcons.handshake),
                ),
                items: const [
                  DropdownMenuItem(
                    value: SupplierDealType.direct,
                    child: Text('شراء مباشر'),
                  ),
                  DropdownMenuItem(
                    value: SupplierDealType.commission,
                    child: Text('بالعمولة (أمانة)'),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _dealType = v);
                },
              ),
              if (isCommission) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _commissionCtrl,
                  textInputAction: TextInputAction.done,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'نسبة العمولة %',
                    prefixIcon: FaIcon(FontAwesomeIcons.percent),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'أدخل نسبة العمولة';
                    }
                    final rate = double.tryParse(v.trim());
                    if (rate == null || rate < 0 || rate > 100) {
                      return 'نسبة بين 0 و 100';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesCtrl,
                textInputAction: TextInputAction.done,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'ملاحظات',
                  prefixIcon: FaIcon(FontAwesomeIcons.fileLines),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: AppProgress(strokeWidth: 2),
                      )
                    : Text(_isEditing ? 'حفظ التعديلات' : 'إضافة'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
