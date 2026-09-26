import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_progress.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/hasad_card.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../domain/products/product.dart';
import '../../../domain/products/product_draft.dart';
import '../../../domain/suppliers/supplier.dart';
import '../../providers/products_providers.dart';
import '../../providers/suppliers_providers.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/filter_bar.dart';
import '../../widgets/record_table.dart';

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(productsListProvider);

    return PageScaffold(
      title: 'المنتجات',
      subtitle: 'منتجات عدّادة ووزنية مع الأسعار والأرصدة',
      child: Stack(
        children: [
          Column(
            children: [
              FilterBar(
                searchController: _searchCtrl,
                hintText: 'بحث بالاسم أو الباركود...',
                onSearchChanged: (value) =>
                    ref.read(productSearchProvider.notifier).update(value),
                onClearSearch: () {
                  _searchCtrl.clear();
                  ref.read(productSearchProvider.notifier).update('');
                  setState(() {});
                },
              ),
              const SizedBox(height: 16),
              Expanded(
                child: AsyncSection<List<Product>>(
                  value: listAsync,
                  onRetry: () => ref.invalidate(productsListProvider),
                  emptyIcon: FontAwesomeIcons.box,
                  emptyTitle: 'لا توجد منتجات',
                  emptyMessage: 'اضغط على زر الإضافة لتسجيل أول منتج.',
                  emptyAction: FilledButton.icon(
                    onPressed: () => _showProductForm(context),
                    icon: const FaIcon(FontAwesomeIcons.plus, size: 13),
                    iconAlignment: IconAlignment.end,
                    label: const Text('إضافة منتج'),
                  ),
                  builder: (context, products) => RecordTable<Product>(
                    items: products,
                    columns: [
                      RecordColumn<Product>(
                        label: 'المنتج',
                        primary: true,
                        flex: 3,
                        cell: (context, p) => Row(
                          children: [
                            IconChip(
                              icon: p.unitType == ProductUnitType.weight
                                  ? FontAwesomeIcons.weightHanging
                                  : FontAwesomeIcons.box,
                              color: AppColors.primary,
                              size: 32,
                              iconSize: 13,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    p.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  if (p.barcode?.isNotEmpty == true)
                                    Text(
                                      'باركود: ${p.barcode}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      RecordColumn<Product>(
                        label: 'الوحدة',
                        flex: 2,
                        cell: (context, p) => _UnitBadge(
                          unit: p.unit,
                          unitTypeLabel: p.unitType == ProductUnitType.weight
                              ? 'وزني'
                              : 'عددي',
                        ),
                      ),
                      RecordColumn<Product>(
                        label: 'الكمية',
                        flex: 2,
                        cell: (context, p) => _StockText(product: p),
                      ),
                      RecordColumn<Product>(
                        label: 'سعر البيع',
                        flex: 2,
                        emphasis: true,
                        alignment: AlignmentDirectional.centerEnd,
                        cell: (context, p) => Text(
                          Money.format(p.salePrice),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ],
                    trailing: (context, p) => PopupMenuButton<String>(
                      tooltip: 'إجراءات المنتج',
                      onSelected: (value) {
                        if (value == 'edit') {
                          _showProductForm(context, product: p);
                        }
                        if (value == 'delete') _confirmDelete(p);
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
              heroTag: 'products_add',
              tooltip: 'إضافة منتج',
              onPressed: () => _showProductForm(context),
              child: const FaIcon(FontAwesomeIcons.plus),
            ),
          ),
        ],
      ),
    );
  }

  void _showProductForm(BuildContext context, {Product? product}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ProductFormSheet(
        product: product,
        onSave: (draft) async {
          final messenger = ScaffoldMessenger.of(context);
          try {
            final notifier = ref.read(productsListProvider.notifier);
            if (product == null) {
              await notifier.create(draft);
            } else {
              await notifier.updateProduct(id: product.id, draft: draft);
            }
            if (context.mounted) Navigator.of(context).pop();
            messenger.showSnackBar(
              SnackBar(
                content: Text(
                  product == null ? 'تمت إضافة المنتج' : 'تم تعديل المنتج',
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

  Future<void> _confirmDelete(Product product) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'حذف المنتج',
      message: 'هل تريد حذف "${product.name}" نهائياً؟',
      confirmLabel: 'حذف',
      tone: ConfirmTone.danger,
    );
    if (!confirmed || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(productsListProvider.notifier).delete(product.id);
      messenger.showSnackBar(const SnackBar(content: Text('تم حذف المنتج')));
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

class _StockText extends StatelessWidget {
  const _StockText({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final low = product.reorderLevel > 0 && product.qty <= product.reorderLevel;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${formatQty(product.qty, product.unitType)} ${product.unit}',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: low ? AppColors.danger : AppColors.textPrimary,
          ),
        ),
        if (low)
          Text(
            'حد إعادة الطلب ${formatQty(product.reorderLevel, product.unitType)}',
            style: const TextStyle(fontSize: 11, color: AppColors.danger),
          ),
      ],
    );
  }
}

class _UnitBadge extends StatelessWidget {
  const _UnitBadge({required this.unit, required this.unitTypeLabel});

  final String unit;
  final String unitTypeLabel;

  @override
  Widget build(BuildContext context) {
    return StatusBadge(
      label: '$unit · $unitTypeLabel',
      palette: BadgePalette.neutral,
    );
  }
}

class _ProductFormSheet extends ConsumerStatefulWidget {
  const _ProductFormSheet({required this.onSave, this.product});

  final Future<void> Function(ProductDraft draft) onSave;
  final Product? product;

  @override
  ConsumerState<_ProductFormSheet> createState() => _ProductFormSheetState();
}

class _ProductFormSheetState extends ConsumerState<_ProductFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _barcodeCtrl;
  late final TextEditingController _unitCtrl;
  late final TextEditingController _salePriceCtrl;
  late final TextEditingController _purchasePriceCtrl;
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _reorderCtrl;
  late final TextEditingController _commissionCtrl;
  late ProductUnitType _unitType;
  Supplier? _supplier;
  List<Supplier> _suppliers = [];
  bool _submitting = false;

  bool get _isEditing => widget.product != null;

  bool get _isWeight => _unitType == ProductUnitType.weight;

  bool get _showCommission =>
      _supplier?.dealType == SupplierDealType.commission;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _barcodeCtrl = TextEditingController(text: p?.barcode ?? '');
    _unitCtrl = TextEditingController(text: p?.unit ?? '');
    _salePriceCtrl = TextEditingController(
      text: p == null ? '' : Money.format(p.salePrice),
    );
    _purchasePriceCtrl = TextEditingController(
      text: p == null ? '' : Money.format(p.purchasePrice),
    );
    _qtyCtrl = TextEditingController(
      text: p == null ? '' : formatQty(p.qty, p.unitType),
    );
    _reorderCtrl = TextEditingController(
      text: p == null ? '' : formatQty(p.reorderLevel, p.unitType),
    );
    _commissionCtrl = TextEditingController(
      text: p?.commissionRate == null ? '' : _trimRate(p!.commissionRate!),
    );
    _unitType = p?.unitType ?? ProductUnitType.count;
    // When editing, remember an existing commission attachment even before
    // the supplier list loads, so the commission-rate field stays visible.
    if (p?.commissionRate != null) {
      _supplier = const Supplier(
        id: '_placeholder',
        name: '',
        dealType: SupplierDealType.commission,
      );
    }
    _loadSuppliers();
  }

  String _trimRate(double rate) =>
      rate == rate.roundToDouble() ? rate.toStringAsFixed(0) : rate.toString();

  Future<void> _loadSuppliers() async {
    try {
      final suppliers = await ref.read(supplierRepositoryProvider).listAll();
      if (!mounted) return;
      setState(() {
        _suppliers = suppliers;
        final product = widget.product;
        if (product?.supplierId != null && suppliers.isNotEmpty) {
          _supplier = suppliers.firstWhere(
            (s) => s.id == product!.supplierId,
            orElse: () => _supplier!,
          );
        }
      });
    } catch (_) {
      // Suppliers are optional; a failed load shows an empty dropdown.
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _barcodeCtrl.dispose();
    _unitCtrl.dispose();
    _salePriceCtrl.dispose();
    _purchasePriceCtrl.dispose();
    _qtyCtrl.dispose();
    _reorderCtrl.dispose();
    _commissionCtrl.dispose();
    super.dispose();
  }

  double? _parseAmount(TextEditingController ctrl) {
    final text = ctrl.text.trim();
    if (text.isEmpty) return 0;
    return double.tryParse(text.replaceAll('%', ''));
  }

  String? _validateQuantity(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;
    if (_isWeight) {
      if (!RegExp(r'^\d+(\.\d{1,3})?$').hasMatch(text)) {
        return 'اكتب رقماً بحد أقصى 3 خانات عشرية';
      }
    } else {
      if (!RegExp(r'^\d+$').hasMatch(text)) {
        return 'اكتب عدداً صحيحاً فالمقاس عددي';
      }
    }
    return null;
  }

  String? _validatePrice(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;
    if (double.tryParse(text) == null) return 'سعر غير صالح';
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final saleAmount = _parseAmount(_salePriceCtrl);
    final purchaseAmount = _parseAmount(_purchasePriceCtrl);
    if (saleAmount == null || purchaseAmount == null) {
      _showError('أدخل سعراً صحيحاً');
      return;
    }

    final qty = _parseAmount(_qtyCtrl) ?? 0;
    final reorder = _parseAmount(_reorderCtrl) ?? 0;

    double? commissionRate;
    if (_showCommission) {
      final text = _commissionCtrl.text.trim();
      if (text.isEmpty) {
        _showError('أدخل نسبة العمولة');
        return;
      }
      commissionRate = double.tryParse(text);
      if (commissionRate == null ||
          commissionRate < 0 ||
          commissionRate > 100) {
        _showError('نسبة العمولة بين 0 و 100');
        return;
      }
    }

    setState(() => _submitting = true);
    try {
      await widget.onSave(
        ProductDraft(
          name: _nameCtrl.text.trim(),
          barcode: _barcodeCtrl.text.trim().isEmpty
              ? null
              : _barcodeCtrl.text.trim(),
          unit: _unitCtrl.text.trim().isEmpty ? 'وحدة' : _unitCtrl.text.trim(),
          unitType: _unitType,
          salePrice: Money.fromAmount(saleAmount),
          purchasePrice: Money.fromAmount(purchaseAmount),
          qty: _isWeight ? qty : qty.roundToDouble(),
          reorderLevel: _isWeight ? reorder : reorder.roundToDouble(),
          supplierId: _supplier?.id == null || _supplier!.id.isEmpty
              ? null
              : _supplier!.id,
          commissionRate: commissionRate,
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
    final theme = Theme.of(context);
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
                    icon: FontAwesomeIcons.box,
                    color: AppColors.primary,
                    size: 40,
                    iconSize: 18,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _isEditing ? 'تعديل المنتج' : 'إضافة منتج جديد',
                      style: theme.textTheme.titleLarge,
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
                  labelText: 'اسم المنتج',
                  prefixIcon: FaIcon(FontAwesomeIcons.tableCells),
                ),
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'أدخل اسم المنتج' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _barcodeCtrl,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'الباركود',
                  prefixIcon: FaIcon(FontAwesomeIcons.qrcode),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _unitCtrl,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'الوحدة',
                        prefixIcon: FaIcon(FontAwesomeIcons.ruler),
                        hintText: 'كجم، قطعة، كيس...',
                      ),
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'أدخل الوحدة'
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<ProductUnitType>(
                      initialValue: _unitType,
                      decoration: const InputDecoration(
                        labelText: 'نوع القياس',
                        prefixIcon: FaIcon(FontAwesomeIcons.scaleBalanced),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: ProductUnitType.count,
                          child: Text('عددي'),
                        ),
                        DropdownMenuItem(
                          value: ProductUnitType.weight,
                          child: Text('وزني'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _unitType = v);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildQuantityField(
                      ctrl: _qtyCtrl,
                      label: 'الكمية',
                      hint: _isWeight ? 'مثلاً 1.250' : 'مثلاً 10',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildQuantityField(
                      ctrl: _reorderCtrl,
                      label: 'حد إعادة الطلب',
                      hint: 'اختياري',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _salePriceCtrl,
                      textInputAction: TextInputAction.next,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'سعر البيع',
                        prefixIcon: FaIcon(FontAwesomeIcons.tag),
                      ),
                      validator: _validatePrice,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _purchasePriceCtrl,
                      textInputAction: TextInputAction.next,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'سعر الشراء',
                        prefixIcon: FaIcon(FontAwesomeIcons.cartShopping),
                      ),
                      validator: _validatePrice,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: _supplier?.id != null && _supplier!.id.isNotEmpty
                    ? _supplier!.id
                    : null,
                decoration: const InputDecoration(
                  labelText: 'المورد',
                  prefixIcon: FaIcon(FontAwesomeIcons.warehouse),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('بدون مورد'),
                  ),
                  for (final s in _suppliers)
                    DropdownMenuItem<String?>(
                      value: s.id,
                      child: Text(
                        s.dealType == SupplierDealType.commission
                            ? '${s.name} (بالعمولة)'
                            : s.name,
                      ),
                    ),
                ],
                onChanged: (id) {
                  setState(() {
                    _supplier = id == null
                        ? null
                        : _suppliers.firstWhere((s) => s.id == id);
                  });
                },
              ),
              if (_showCommission) ...[
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
                    final text = (v ?? '').trim();
                    if (text.isEmpty) return 'أدخل نسبة العمولة';
                    final rate = double.tryParse(text);
                    if (rate == null || rate < 0 || rate > 100) {
                      return 'نسبة بين 0 و 100';
                    }
                    return null;
                  },
                ),
              ],
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

  Widget _buildQuantityField({
    required TextEditingController ctrl,
    required String label,
    required String hint,
  }) {
    return TextFormField(
      controller: ctrl,
      textInputAction: TextInputAction.next,
      keyboardType: TextInputType.numberWithOptions(decimal: _isWeight),
      inputFormatters: [
        _isWeight
            ? FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
            : FilteringTextInputFormatter.digitsOnly,
      ],
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: const FaIcon(FontAwesomeIcons.hashtag),
      ),
      validator: _validateQuantity,
    );
  }
}
