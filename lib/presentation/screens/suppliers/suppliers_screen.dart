import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../domain/suppliers/supplier.dart';
import '../../../domain/suppliers/supplier_draft.dart';
import '../../providers/suppliers_providers.dart';

class SuppliersScreen extends ConsumerStatefulWidget {
  const SuppliersScreen({super.key});

  @override
  ConsumerState<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends ConsumerState<SuppliersScreen> {
  final _searchCtrl = TextEditingController();
  bool _searchOpen = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() => _searchOpen = !_searchOpen);
    if (!_searchOpen) {
      _searchCtrl.clear();
      ref.read(supplierSearchProvider.notifier).update('');
    }
  }

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(suppliersListProvider);

    return PageScaffold(
      title: 'الموردون',
      subtitle: 'الموردون المباشرون وبالعمولة',
      actions: [
        IconButton(
          tooltip: _searchOpen ? 'إغلاق البحث' : 'بحث',
          onPressed: _toggleSearch,
          icon: FaIcon(_searchOpen ? FontAwesomeIcons.xmark : FontAwesomeIcons.magnifyingGlass),
        ),
      ],
      child: Stack(
        children: [
          Column(
            children: [
              if (_searchOpen)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: TextField(
                    controller: _searchCtrl,
                    autofocus: true,
                    textInputAction: TextInputAction.search,
                    onChanged: (v) =>
                        ref.read(supplierSearchProvider.notifier).update(v),
                    decoration: InputDecoration(
                      hintText: 'بحث بالاسم أو رقم الهاتف...',
                      prefixIcon: const FaIcon(FontAwesomeIcons.magnifyingGlass),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              tooltip: 'مسح البحث',
                              icon: const FaIcon(FontAwesomeIcons.xmark),
                              onPressed: () {
                                _searchCtrl.clear();
                                ref
                                    .read(supplierSearchProvider.notifier)
                                    .update('');
                              },
                            )
                          : null,
                    ),
                  ),
                ),
              Expanded(
                child: listAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => _ErrorState(message: e.toString()),
                  data: (suppliers) {
                    if (suppliers.isEmpty) {
                      return const _EmptyState();
                    }
                    return _SupplierList(suppliers: suppliers);
                  },
                ),
              ),
            ],
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: FloatingActionButton(
              heroTag: 'suppliers_add',
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
}

class _SupplierList extends StatelessWidget {
  const _SupplierList({required this.suppliers});

  final List<Supplier> suppliers;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: suppliers.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final s = suppliers[index];
        return _SupplierTile(
          supplier: s,
          onEdit: () {
            final screen =
                context.findAncestorStateOfType<_SuppliersScreenState>();
            screen?._showSupplierForm(context, supplier: s);
          },
          onDelete: () => _confirmDelete(context, s),
        );
      },
    );
  }
}

class _SupplierTile extends StatelessWidget {
  const _SupplierTile({
    required this.supplier,
    required this.onEdit,
    required this.onDelete,
  });

  final Supplier supplier;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCommission = supplier.dealType == SupplierDealType.commission;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.secondary.withValues(alpha: 0.1),
        child: Text(
          supplier.name.isNotEmpty ? supplier.name[0] : '?',
          style: theme.textTheme.titleMedium?.copyWith(
            color: AppColors.secondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      title: Text(
        supplier.name,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (supplier.phone != null && supplier.phone!.isNotEmpty)
            Text(supplier.phone!, style: theme.textTheme.bodySmall),
          if (isCommission)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: _CommissionBadge(rate: supplier.commissionRate),
            ),
        ],
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (v) {
          if (v == 'edit') onEdit();
          if (v == 'delete') onDelete();
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'edit', child: Text('تعديل')),
          PopupMenuItem(value: 'delete', child: Text('حذف')),
        ],
      ),
    );
  }
}

class _CommissionBadge extends StatelessWidget {
  const _CommissionBadge({required this.rate});

  final double? rate;

  @override
  Widget build(BuildContext context) {
    final label = rate == null ? 'بالعمولة' : 'بالعمولة — $rate%';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(50),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF92400E),
            ),
      ),
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
          phone: _phoneCtrl.text.trim().isEmpty
              ? null
              : _phoneCtrl.text.trim(),
          notes: _notesCtrl.text.trim().isEmpty
              ? null
              : _notesCtrl.text.trim(),
          dealType: _dealType,
          commissionRate:
              isCommission ? double.parse(rateText.replaceAll('٪', '')) : null,
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
              Text(
                _isEditing ? 'تعديل المورد' : 'إضافة مورد جديد',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameCtrl,
                textInputAction: TextInputAction.next,
                autofocus: true,
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
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
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
              ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
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

void _confirmDelete(BuildContext context, Supplier supplier) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('حذف المورد'),
      content: Text('هل تريد حذف "${supplier.name}" نهائياً؟'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: () async {
            final navigator = Navigator.of(context);
            final messenger = ScaffoldMessenger.of(context);
            final container = ProviderScope.containerOf(context);
            navigator.pop();
            try {
              await container
                  .read(suppliersListProvider.notifier)
                  .delete(supplier.id);
              messenger.showSnackBar(
                const SnackBar(content: Text('تم حذف المورد')),
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
          child: const Text('حذف'),
        ),
      ],
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FaIcon(FontAwesomeIcons.building,
              size: 48,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 16),
            Text('لا يوجد موردون', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'اضغط على + لإضافة أول مورد',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
                  ),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const FaIcon(FontAwesomeIcons.circleExclamation, size: 48, color: AppColors.danger),
            const SizedBox(height: 16),
            Text(
              'حدث خطأ',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}