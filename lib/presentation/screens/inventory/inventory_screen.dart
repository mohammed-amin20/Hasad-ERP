import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../domain/inventory/inventory.dart';
import '../../../domain/products/product.dart';
import '../../providers/inventory_providers.dart';
import '../../widgets/invoice_input_fields.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  final _searchCtrl = TextEditingController();
  bool _searchOpen = false;
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _searchOpen = !_searchOpen;
      if (!_searchOpen) {
        _searchCtrl.clear();
        _query = '';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(inventoryProductsProvider);

    return PageScaffold(
      title: 'المخزون',
      subtitle: 'الأرصدة والجرد الدوري',
      actions: [
        IconButton(
          tooltip: _searchOpen ? 'إغلاق البحث' : 'بحث',
          onPressed: _toggleSearch,
          icon: Icon(_searchOpen ? Icons.close : Icons.search),
        ),
      ],
      child: Column(
        children: [
          if (_searchOpen)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onChanged: (v) => setState(() => _query = v.trim()),
                decoration: InputDecoration(
                  hintText: 'بحث بالاسم أو الباركود...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _query = '');
                          },
                        )
                      : null,
                ),
              ),
            ),
          Expanded(
            child: listAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrorState(message: e.toString()),
              data: (products) {
                final filtered = _query.isEmpty
                    ? products
                    : products
                        .where((p) =>
                            p.name.contains(_query) ||
                            (p.barcode?.contains(_query) ?? false))
                        .toList();
                if (filtered.isEmpty) {
                  return const _EmptyState();
                }
                return ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) => _ProductStockTile(
                    product: filtered[i],
                    onCount: () => _showCountSheet(filtered[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showCountSheet(Product product) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _CountSheet(
        product: product,
        onSave: (draft) async {
          final messenger = ScaffoldMessenger.of(context);
          try {
            await ref.read(lastAdjustProvider.notifier).adjust(draft);
            if (mounted) Navigator.of(context).pop();
            messenger.showSnackBar(
              SnackBar(
                content: Text(
                  'تم تحديث المخزون: '
                  '${formatQty(draft.countedQty, product.unitType)} ${product.unit}',
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

class _ProductStockTile extends StatelessWidget {
  const _ProductStockTile({required this.product, required this.onCount});

  final Product product;
  final VoidCallback onCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final qtyText = formatQty(product.qty, product.unitType);
    final reorderText = formatQty(product.reorderLevel, product.unitType);
    final isLow = product.qty <= product.reorderLevel;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.secondary.withValues(alpha: 0.1),
        child: Text(
          product.name.isNotEmpty ? product.name[0] : '?',
          style: theme.textTheme.titleMedium?.copyWith(
            color: AppColors.secondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      title: Text(
        product.name,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Row(
        children: [
          Text(
            '$qtyText ${product.unit} · حد الإعادة: $reorderText',
            style: theme.textTheme.bodySmall,
          ),
          if (isLow) ...[
            const SizedBox(width: 8),
            StatusBadge(
              label: product.qty == 0 ? 'نفد' : 'منخفض',
              palette: BadgePalette.unpaid,
            ),
          ],
        ],
      ),
      trailing: OutlinedButton.icon(
        onPressed: onCount,
        icon: const Icon(Icons.fact_check_outlined, size: 18),
        label: const Text('جرد'),
        style: OutlinedButton.styleFrom(
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}

class _CountSheet extends StatefulWidget {
  const _CountSheet({required this.product, required this.onSave});

  final Product product;
  final Future<void> Function(StockAdjustDraft draft) onSave;

  @override
  State<_CountSheet> createState() => _CountSheetState();
}

class _CountSheetState extends State<_CountSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _countCtrl;
  final _reasonCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _countCtrl = TextEditingController(
      text: formatQty(widget.product.qty, widget.product.unitType),
    );
  }

  @override
  void dispose() {
    _countCtrl.dispose();
    _reasonCtrl.dispose();
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
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await widget.onSave(
        StockAdjustDraft(
          productId: widget.product.id,
          countedQty: double.parse(_countCtrl.text.trim()),
          reason: _reasonCtrl.text.trim().isEmpty
              ? null
              : _reasonCtrl.text.trim(),
          date: _date,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
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
                'جرد ${product.name}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'مخزون النظام حالياً: '
                '${formatQty(product.qty, product.unitType)} ${product.unit}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 20),
              ProductQuantityField(
                controller: _countCtrl,
                unitType: product.unitType,
                unit: product.unit,
              ),
              const SizedBox(height: 12),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'تاريخ الجرد',
                    prefixIcon: Icon(Icons.calendar_today_outlined),
                  ),
                  child: Text(
                    '${_date.year.toString().padLeft(4, '0')}/'
                    '${_date.month.toString().padLeft(2, '0')}/'
                    '${_date.day.toString().padLeft(2, '0')}',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _reasonCtrl,
                textInputAction: TextInputAction.done,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'سبب التعديل',
                  hintText: 'جرد شهري، تلف، بضاعة إضافية...',
                  prefixIcon: Icon(Icons.notes_outlined),
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
                    : const Text('حفظ الجرد'),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
            const Icon(Icons.inventory_2_outlined,
                size: 48, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text('لا توجد منتجات', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'أضف منتجات من شاشة المنتجات ثم قم بجردها هنا',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textMuted),
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
            const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
            const SizedBox(height: 16),
            Text('حدث خطأ', style: Theme.of(context).textTheme.titleMedium),
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