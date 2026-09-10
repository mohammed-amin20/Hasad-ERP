import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_progress.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../domain/products/product.dart';
import '../../../domain/products/product_draft.dart';
import '../../../domain/suppliers/supplier.dart';
import '../../providers/products_providers.dart';
import '../../providers/suppliers_providers.dart';

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
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
      ref.read(productSearchProvider.notifier).update('');
    }
  }

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(productsListProvider);

    return PageScaffold(
      title: 'المنتجات',
      subtitle: 'منتجات عدّادة ووزنية مع الأسعار والأرصدة',
      actions: [
        IconButton(
          tooltip: _searchOpen ? 'إغلاق البحث' : 'بحث',
          onPressed: _toggleSearch,
          icon: FaIcon(
            _searchOpen
                ? FontAwesomeIcons.xmark
                : FontAwesomeIcons.magnifyingGlass,
          ),
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
                        ref.read(productSearchProvider.notifier).update(v),
                    decoration: InputDecoration(
                      hintText: 'بحث بالاسم أو الباركود...',
                      prefixIcon: const FaIcon(
                        FontAwesomeIcons.magnifyingGlass,
                      ),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              tooltip: 'مسح البحث',
                              icon: const FaIcon(FontAwesomeIcons.xmark),
                              onPressed: () {
                                _searchCtrl.clear();
                                ref
                                    .read(productSearchProvider.notifier)
                                    .update('');
                              },
                            )
                          : null,
                    ),
                  ),
                ),
              Expanded(
                child: listAsync.when(
                  loading: () => const Center(child: AppProgress()),
                  error: (e, _) => _ErrorState(message: e.toString()),
                  data: (products) {
                    if (products.isEmpty) {
                      return const _EmptyState();
                    }
                    return _ProductList(products: products);
                  },
                ),
              ),
            ],
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: FloatingActionButton(
              heroTag: 'products_add',
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
}

class _ProductList extends StatelessWidget {
  const _ProductList({required this.products});

  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: products.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final p = products[index];
        return _ProductTile(
          product: p,
          onEdit: () {
            final screen = context
                .findAncestorStateOfType<_ProductsScreenState>();
            screen?._showProductForm(context, product: p);
          },
          onDelete: () => _confirmDelete(context, p),
        );
      },
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({
    required this.product,
    required this.onEdit,
    required this.onDelete,
  });

  final Product product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWeight = product.unitType == ProductUnitType.weight;
    final unitTypeLabel = isWeight ? 'وزني' : 'عددي';
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
        child: Text(
          product.name.isNotEmpty ? product.name[0] : '?',
          style: theme.textTheme.titleMedium?.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      title: Text(
        product.name,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (product.barcode != null && product.barcode!.isNotEmpty)
            Text(
              'باركود: ${product.barcode}',
              style: theme.textTheme.bodySmall,
            ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: _UnitBadge(unit: product.unit, unitTypeLabel: unitTypeLabel),
          ),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            Money.format(product.salePrice),
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          Text(
            'الكمية: ${formatQty(product.qty, product.unitType)} '
            '${product.unit}',
            style: theme.textTheme.bodySmall,
          ),
          if (product.reorderLevel > 0)
            Text(
              'حد إعادة طلب: ${formatQty(product.reorderLevel, product.unitType)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textMuted,
              ),
            ),
        ],
      ),
      onTap: onEdit,
      onLongPress: onDelete,
      isThreeLine: true,
    );
  }
}

class _UnitBadge extends StatelessWidget {
  const _UnitBadge({required this.unit, required this.unitTypeLabel});

  final String unit;
  final String unitTypeLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(50),
      ),
      child: Text(
        '$unit · $unitTypeLabel',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
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
              Text(
                _isEditing ? 'تعديل المنتج' : 'إضافة منتج جديد',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameCtrl,
                textInputAction: TextInputAction.next,
                autofocus: true,
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
              ElevatedButton(
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

void _confirmDelete(BuildContext context, Product product) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('حذف المنتج'),
      content: Text('هل تريد حذف "${product.name}" نهائياً؟'),
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
                  .read(productsListProvider.notifier)
                  .delete(product.id);
              messenger.showSnackBar(
                const SnackBar(content: Text('تم حذف المنتج')),
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
            FaIcon(
              FontAwesomeIcons.boxesStacked,
              size: 48,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 16),
            Text(
              'لا يوجد منتجات',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'اضغط على + لإضافة أول منتج',
              style: Theme.of(context).textTheme.bodySmall
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
