import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_progress.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../core/widgets/route_header.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../domain/products/product.dart';
import '../../../domain/purchases/purchase_invoice_draft.dart';
import '../../../domain/suppliers/supplier.dart';
import '../../providers/purchases_providers.dart';
import '../../widgets/invoice_input_fields.dart';
import '../../widgets/invoice_list.dart';
import '../../widgets/new_product_sheet.dart';
import '../../widgets/product_picker_sheet.dart';

class PurchaseInvoicesScreen extends ConsumerStatefulWidget {
  const PurchaseInvoicesScreen({super.key});

  @override
  ConsumerState<PurchaseInvoicesScreen> createState() =>
      _PurchaseInvoicesScreenState();
}

class _PurchaseInvoicesScreenState
    extends ConsumerState<PurchaseInvoicesScreen> {
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
      ref.read(purchaseSearchProvider.notifier).update('');
    }
  }

  Future<void> _newInvoice() async {
    final no = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const _NewPurchaseInvoicePage(),
        fullscreenDialog: true,
      ),
    );
    if (!mounted || no == null) return;

    final messenger = ScaffoldMessenger.of(context);
    ref.read(purchaseInvoicesListProvider.notifier).refresh();
    messenger.showSnackBar(
      SnackBar(content: Text('تم إنشاء فاتورة الشراء رقم $no')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(purchaseInvoicesListProvider);

    return PageScaffold(
      title: 'المشتريات',
      subtitle: 'استلام مباشر وبالعمولة (بضاعة أمانة)',
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
                        ref.read(purchaseSearchProvider.notifier).update(v),
                    decoration: InputDecoration(
                      hintText: 'بحث برقم الفاتورة...',
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
                                    .read(purchaseSearchProvider.notifier)
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
                  error: (e, _) => ListErrorState(message: e.toString()),
                  data: (invoices) {
                    if (invoices.isEmpty) {
                      return const _EmptyState();
                    }
                    return InvoiceListView(
                      invoices: invoices,
                      onTap: (invoice) => showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        useSafeArea: true,
                        builder: (_) => InvoiceDetailSheet(invoice: invoice),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: FloatingActionButton(
              heroTag: 'purchase_add',
              onPressed: _newInvoice,
              child: const FaIcon(FontAwesomeIcons.plus),
            ),
          ),
        ],
      ),
    );
  }
}

class _PurchaseLineEntry {
  _PurchaseLineEntry({
    required this.name,
    required this.unit,
    required this.unitType,
    required this.isNew,
    this.productId,
    this.newProduct,
    required this.qtyCtrl,
    required this.priceCtrl,
  }) : assert(productId != null || newProduct != null);

  final String name;
  final String unit;
  final ProductUnitType unitType;
  final bool isNew;
  final String? productId;
  final NewProductDraft? newProduct;
  final TextEditingController qtyCtrl;
  final TextEditingController priceCtrl;
}

class _NewPurchaseInvoicePage extends ConsumerStatefulWidget {
  const _NewPurchaseInvoicePage();

  @override
  ConsumerState<_NewPurchaseInvoicePage> createState() =>
      _NewPurchaseInvoicePageState();
}

class _NewPurchaseInvoicePageState
    extends ConsumerState<_NewPurchaseInvoicePage> {
  static const _paymentMethods = [
    (value: 'cash', label: 'نقدي'),
    (value: 'bank', label: 'بنك'),
  ];

  final _formKey = GlobalKey<FormState>();
  String? _supplierId;
  Supplier? _supplier;
  DateTime _date = DateTime.now();
  final List<_PurchaseLineEntry> _lines = [];
  final _paidCtrl = TextEditingController();
  String? _paymentMethod;
  final _memoCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    for (final line in _lines) {
      line.qtyCtrl.dispose();
      line.priceCtrl.dispose();
    }
    _paidCtrl.dispose();
    _memoCtrl.dispose();
    super.dispose();
  }

  bool get _isConsignment => _supplier?.dealType == SupplierDealType.commission;

  int get _subtotal {
    var sum = 0;
    for (final line in _lines) {
      final qty = double.tryParse(line.qtyCtrl.text.trim());
      final price = priceToAgorot(line.priceCtrl.text.trim());
      if (qty != null && price != null) {
        sum += (qty * price).round();
      }
    }
    return sum;
  }

  Future<void> _addLine() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const FaIcon(FontAwesomeIcons.boxesStacked),
              title: const Text('منتج موجود'),
              subtitle: const Text('فيستعمل سعر الشراء والسجل الحالي'),
              onTap: () => Navigator.of(context).pop('existing'),
            ),
            ListTile(
              leading: const FaIcon(FontAwesomeIcons.squarePlus),
              title: const Text('منتج جديد'),
              subtitle: const Text('يُضاف للسجل ضمن نفس العملية'),
              onTap: () => Navigator.of(context).pop('new'),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;

    if (choice == 'existing') {
      final product = await showProductPicker(context);
      if (product == null || !mounted) return;
      setState(() {
        _lines.add(
          _PurchaseLineEntry(
            name: product.name,
            unit: product.unit,
            unitType: product.unitType,
            isNew: false,
            productId: product.id,
            qtyCtrl: TextEditingController(),
            priceCtrl: TextEditingController(
              text: _editableAmount(product.purchasePrice),
            ),
          ),
        );
      });
    } else {
      final draft = await showNewProductSheet(context);
      if (draft == null || !mounted) return;
      setState(() {
        _lines.add(
          _PurchaseLineEntry(
            name: draft.name,
            unit: draft.unit,
            unitType: draft.unitType,
            isNew: true,
            newProduct: draft,
            qtyCtrl: TextEditingController(),
            priceCtrl: TextEditingController(),
          ),
        );
      });
    }
  }

  String _editableAmount(int agorot) {
    final value = Money.toAmount(agorot);
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
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
    if (_supplierId == null || _supplier == null) {
      _showError('اختر المورد');
      return;
    }
    if (_lines.isEmpty) {
      _showError('أضف على الأقل صنفاً واحداً');
      return;
    }
    final paid = _isConsignment
        ? 0
        : (priceToAgorot(_paidCtrl.text.trim()) ?? 0);
    if (!_isConsignment && paid > 0 && _paymentMethod == null) {
      _showError('اختر طريقة الدفع عند الدفع');
      return;
    }
    if (paid > _subtotal) {
      _showError('المدفوع أكبر من إجمالي الفاتورة');
      return;
    }

    setState(() => _submitting = true);
    try {
      final result = await ref
          .read(purchaseRepositoryProvider)
          .create(
            PurchaseInvoiceDraft(
              supplierId: _supplierId!,
              date: _date,
              lines: [
                for (final line in _lines)
                  PurchaseLineDraft(
                    productId: line.productId,
                    newProduct: line.newProduct,
                    qty: double.parse(line.qtyCtrl.text.trim()),
                    price: priceToAgorot(line.priceCtrl.text.trim()),
                  ),
              ],
              paid: paid,
              paymentMethod: _isConsignment ? null : _paymentMethod,
              memo: _memoCtrl.text.trim().isEmpty
                  ? null
                  : _memoCtrl.text.trim(),
            ),
          );
      if (mounted) Navigator.of(context).pop(result.no);
    } on Object catch (error) {
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: AppColors.danger,
            content: Text(mapErrorToAppException(error).message),
          ),
        );
      }
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
    final theme = Theme.of(context);
    final suppliersAsync = ref.watch(allSuppliersProvider);

    return Container(
      color: AppColors.background,
      child: SafeArea(
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              RouteHeader(
                title: '������ ���� �����',
                subtitle: '����� ������ ������� �� ������',
                onClose: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: 16),
              suppliersAsync.when(
                loading: () => const Center(child: AppProgress()),
                error: (e, _) => ListErrorState(message: e.toString()),
                data: (suppliers) => DropdownButtonFormField<String>(
                  initialValue: _supplierId,
                  decoration: const InputDecoration(
                    labelText: 'المورد',
                    prefixIcon: FaIcon(FontAwesomeIcons.store),
                  ),
                  items: [
                    for (final s in suppliers)
                      DropdownMenuItem(
                        value: s.id,
                        child: Text(
                          s.dealType == SupplierDealType.commission
                              ? '${s.name} (عمولة)'
                              : s.name,
                        ),
                      ),
                  ],
                  onChanged: (v) {
                    setState(() {
                      _supplierId = v;
                      Supplier? selected;
                      for (final s in suppliers) {
                        if (s.id == v) {
                          selected = s;
                          break;
                        }
                      }
                      _supplier = selected;
                      if (_isConsignment) {
                        _paidCtrl.clear();
                        _paymentMethod = null;
                      }
                    });
                  },
                ),
              ),
              if (_isConsignment) ...[
                const SizedBox(height: 12),
                StatusBadge(
                  label: 'بضاعة أمانة — لا يُستلم إلا كمخزون، ويُسدَّد لاحقاً',
                  palette: BadgePalette.commission,
                ),
              ],
              const SizedBox(height: 12),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'تاريخ الفاتورة',
                    prefixIcon: FaIcon(FontAwesomeIcons.calendarDay),
                  ),
                  child: Text(formatInvoiceDate(_date)),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text('الأصناف', style: theme.textTheme.titleMedium),
                  ),
                  TextButton.icon(
                    onPressed: _addLine,
                    icon: const FaIcon(FontAwesomeIcons.plus),
                    label: const Text('إضافة صنف'),
                  ),
                ],
              ),
              for (var i = 0; i < _lines.length; i++) ...[
                _PurchaseLineRow(
                  entry: _lines[i],
                  onRemove: () => setState(() {
                    _lines[i].qtyCtrl.dispose();
                    _lines[i].priceCtrl.dispose();
                    _lines.removeAt(i);
                  }),
                ),
                if (i < _lines.length - 1) const SizedBox(height: 12),
              ],
              if (_lines.isNotEmpty) ...[
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text('الإجمالي: ', style: theme.textTheme.bodyLarge),
                    const SizedBox(width: 8),
                    Text(
                      Money.format(_subtotal),
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              AbsorbPointer(
                absorbing: _isConsignment,
                child: Opacity(
                  opacity: _isConsignment ? 0.5 : 1,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _paidCtrl,
                          enabled: !_isConsignment,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'المدفوع',
                            prefixIcon: FaIcon(FontAwesomeIcons.moneyBill),
                          ),
                          validator: (v) {
                            final text = (v ?? '').trim();
                            if (text.isEmpty) return null;
                            if (double.tryParse(text) == null) {
                              return 'قيمة غير صالحة';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _paymentMethod,
                          decoration: const InputDecoration(
                            labelText: 'طريقة الدفع',
                            prefixIcon: FaIcon(FontAwesomeIcons.wallet),
                          ),
                          items: [
                            for (final m in _paymentMethods)
                              DropdownMenuItem(
                                value: m.value,
                                child: Text(m.label),
                              ),
                          ],
                          onChanged: (v) => setState(() => _paymentMethod = v),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _memoCtrl,
                textInputAction: TextInputAction.done,
                maxLines: 2,
                decoration: const InputDecoration(
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
                    : const Text('حفظ الفاتورة'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A single editable purchase line; new product lines require a price.
class _PurchaseLineRow extends StatefulWidget {
  const _PurchaseLineRow({required this.entry, required this.onRemove});

  final _PurchaseLineEntry entry;
  final VoidCallback onRemove;

  @override
  State<_PurchaseLineRow> createState() => _PurchaseLineRowState();
}

class _PurchaseLineRowState extends State<_PurchaseLineRow> {
  @override
  void initState() {
    super.initState();
    widget.entry.qtyCtrl.addListener(_recompute);
    widget.entry.priceCtrl.addListener(_recompute);
  }

  @override
  void dispose() {
    widget.entry.qtyCtrl.removeListener(_recompute);
    widget.entry.priceCtrl.removeListener(_recompute);
    super.dispose();
  }

  void _recompute() => setState(() {});

  _PurchaseLineEntry get entry => widget.entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          entry.name,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (entry.isNew) ...[
                        const SizedBox(width: 8),
                        StatusBadge(
                          label: 'منتج جديد',
                          palette: BadgePalette.commission,
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  onPressed: widget.onRemove,
                  icon: const FaIcon(FontAwesomeIcons.xmark),
                  color: AppColors.textMuted,
                  tooltip: 'إزالة الصنف',
                ),
              ],
            ),
            Text(
              '${entry.unit} · ${entry.isNew ? 'يُضاف للسجل الآن' : 'استلام منتج موجود'}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ProductQuantityField(
                    controller: entry.qtyCtrl,
                    unitType: entry.unitType,
                    unit: entry.unit,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PriceField(
                    controller: entry.priceCtrl,
                    label: 'سعر الشراء',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('إجمالي السطر: ', style: theme.textTheme.bodySmall),
                  const SizedBox(width: 4),
                  Text(
                    Money.format(_lineTotal()),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _lineTotal() {
    final qty = double.tryParse(entry.qtyCtrl.text.trim());
    final price = priceToAgorot(entry.priceCtrl.text.trim());
    if (qty == null || price == null) return 0;
    return (qty * price).round();
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
            FaIcon(
              FontAwesomeIcons.bookOpen,
              size: 48,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 16),
            Text(
              'لا توجد فواتير شراء',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'اضغط على + لإنشاء أول فاتورة',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
