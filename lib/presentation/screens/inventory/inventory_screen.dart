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
import '../../../domain/inventory/inventory.dart';
import '../../../domain/products/product.dart';
import '../../providers/inventory_providers.dart';
import '../../widgets/filter_bar.dart';
import '../../widgets/record_table.dart';
import '../../widgets/state_views.dart';
import '../../widgets/invoice_input_fields.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(inventoryProductsProvider);

    return PageScaffold(
      title: 'المخزون',
      subtitle: 'الأرصدة والجرد الدوري',
      child: Column(
        children: [
          FilterBar(
            searchController: _searchCtrl,
            hintText: 'بحث بالاسم أو الباركود...',
            onSearchChanged: (value) => setState(() => _query = value.trim()),
            onClearSearch: () {
              _searchCtrl.clear();
              setState(() => _query = '');
            },
          ),
          const SizedBox(height: 16),
          Expanded(
            child: AsyncSection<List<Product>>(
              value: listAsync,
              onRetry: () => ref.invalidate(inventoryProductsProvider),
              emptyIcon: FontAwesomeIcons.boxesStacked,
              emptyTitle: 'لا توجد منتجات',
              emptyMessage: 'سجّل المنتجات أولاً ليظهر رصيد المخزون هنا.',
              builder: (context, products) {
                final filtered = _query.isEmpty
                    ? products
                    : products
                          .where(
                            (p) =>
                                p.name.contains(_query) ||
                                (p.barcode?.contains(_query) ?? false),
                          )
                          .toList();
                if (filtered.isEmpty) {
                  return const EmptyStateCard(
                    icon: FontAwesomeIcons.magnifyingGlass,
                    title: 'لا نتائج',
                    message: 'لا يوجد منتج يطابق البحث الحالي.',
                  );
                }
                return RecordTable<Product>(
                  items: filtered,
                  onTap: (p) => _showCountSheet(p),
                  columns: [
                    RecordColumn<Product>(
                      label: 'المنتج',
                      primary: true,
                      flex: 3,
                      cell: (context, p) => Row(
                        children: [
                          const IconChip(
                            icon: FontAwesomeIcons.box,
                            color: AppColors.secondary,
                            size: 32,
                            iconSize: 13,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              p.name,
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
                    RecordColumn<Product>(
                      label: 'الرصيد',
                      flex: 2,
                      cell: (context, p) => _StockCell(product: p),
                    ),
                    RecordColumn<Product>(
                      label: 'الحالة',
                      flex: 2,
                      cell: (context, p) => p.qty <= p.reorderLevel
                          ? StatusBadge(
                              label: p.qty == 0 ? 'نفد' : 'منخفض',
                              palette: BadgePalette.unpaid,
                            )
                          : const StatusBadge(
                              label: 'متوفر',
                              palette: BadgePalette.paid,
                            ),
                    ),
                  ],
                  trailing: (context, p) => OutlinedButton.icon(
                    onPressed: () => _showCountSheet(p),
                    icon: const FaIcon(FontAwesomeIcons.clipboardCheck, size: 12),
                    iconAlignment: IconAlignment.end,
                    label: const Text('جرد'),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
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

class _StockCell extends StatelessWidget {
  const _StockCell({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final qtyText = formatQty(product.qty, product.unitType);
    final reorderText = formatQty(product.reorderLevel, product.unitType);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$qtyText ${product.unit}',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          'حد الإعادة: $reorderText',
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.textMuted,
          ),
        ),
      ],
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
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const IconChip(
                    icon: FontAwesomeIcons.clipboardCheck,
                    color: AppColors.secondary,
                    size: 40,
                    iconSize: 18,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'جرد ${product.name}',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'مخزون النظام حالياً: '
                          '${formatQty(product.qty, product.unitType)} ${product.unit}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
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
                    prefixIcon: FaIcon(FontAwesomeIcons.calendarDay),
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
                  prefixIcon: FaIcon(FontAwesomeIcons.fileLines),
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
                    : const Text('حفظ الجرد'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
