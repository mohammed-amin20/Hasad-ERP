import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../core/widgets/route_header.dart';
import '../../../domain/products/product.dart';
import '../../../domain/sales/sale_invoice_draft.dart';
import '../../providers/sales_providers.dart';
import '../../widgets/invoice_input_fields.dart';
import '../../widgets/invoice_list.dart';
import '../../widgets/product_picker_sheet.dart';

class SaleInvoicesScreen extends ConsumerStatefulWidget {
  const SaleInvoicesScreen({super.key});

  @override
  ConsumerState<SaleInvoicesScreen> createState() =>
      _SaleInvoicesScreenState();
}

class _SaleInvoicesScreenState extends ConsumerState<SaleInvoicesScreen> {
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
      ref.read(saleSearchProvider.notifier).update('');
    }
  }

  Future<void> _newInvoice() async {
    final no = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const _NewSaleInvoicePage(),
        fullscreenDialog: true,
      ),
    );
    if (!mounted || no == null) return;

    final messenger = ScaffoldMessenger.of(context);
    ref.read(saleInvoicesListProvider.notifier).refresh();
    messenger.showSnackBar(
      SnackBar(content: Text('تم إنشاء فاتورة البيع رقم $no')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(saleInvoicesListProvider);

    return PageScaffold(
      title: 'المبيعات',
      subtitle: 'إنشاء ومتابعة فواتير البيع',
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
                        ref.read(saleSearchProvider.notifier).update(v),
                    decoration: InputDecoration(
                      hintText: 'بحث برقم الفاتورة...',
                      prefixIcon: const FaIcon(FontAwesomeIcons.magnifyingGlass),
                      suffixIcon: _searchCtrl.text.isNotEmpty
? IconButton(
                              tooltip: 'مسح البحث',
                              icon: const FaIcon(FontAwesomeIcons.xmark),
                              onPressed: () {
                                _searchCtrl.clear();
                                ref.read(saleSearchProvider.notifier).update('');
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
                        builder: (_) =>
                            InvoiceDetailSheet(invoice: invoice),
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
              heroTag: 'sale_add',
              onPressed: _newInvoice,
              child: const FaIcon(FontAwesomeIcons.plus),
            ),
          ),
        ],
      ),
    );
  }
}

class _LineEntry {
  _LineEntry({
    required this.product,
    required this.qtyCtrl,
    required this.priceCtrl,
  });

  final Product product;
  final TextEditingController qtyCtrl;
  final TextEditingController priceCtrl;
}

class _NewSaleInvoicePage extends ConsumerStatefulWidget {
  const _NewSaleInvoicePage();

  @override
  ConsumerState<_NewSaleInvoicePage> createState() =>
      _NewSaleInvoicePageState();
}

class _NewSaleInvoicePageState extends ConsumerState<_NewSaleInvoicePage> {
  static const _paymentMethods = [
    (value: 'cash', label: 'نقدي'),
    (value: 'bank', label: 'بنك'),
  ];

  final _formKey = GlobalKey<FormState>();
  String? _customerId;
  DateTime _date = DateTime.now();
  final List<_LineEntry> _lines = [];
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
    final product = await showProductPicker(context);
    if (product == null || !mounted) return;
    setState(() {
      _lines.add(
        _LineEntry(
          product: product,
          qtyCtrl: TextEditingController(),
          priceCtrl: TextEditingController(
            text: _editableAmount(product.salePrice),
          ),
        ),
      );
    });
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
    if (_customerId == null) {
      _showError('اختر العميل');
      return;
    }
    if (_lines.isEmpty) {
      _showError('أضف على الأقل صنفاً واحداً');
      return;
    }
    final paid = priceToAgorot(_paidCtrl.text.trim()) ?? 0;
    if (paid > 0 && _paymentMethod == null) {
      _showError('اختر طريقة الدفع عند الدفع');
      return;
    }
    if (paid > _subtotal) {
      _showError('المدفوع أكبر من إجمالي الفاتورة');
      return;
    }

    setState(() => _submitting = true);
    try {
      final result = await ref.read(saleRepositoryProvider).create(
            SaleInvoiceDraft(
              customerId: _customerId!,
              date: _date,
              lines: [
                for (final line in _lines)
                  SaleLineDraft(
                    productId: line.product.id,
                    qty: double.parse(line.qtyCtrl.text.trim()),
                    price: priceToAgorot(line.priceCtrl.text.trim()),
                  ),
              ],
              paid: paid,
              paymentMethod: _paymentMethod,
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
    final customersAsync = ref.watch(allCustomersProvider);

    return Container(
      color: AppColors.background,
      child: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              RouteHeader(
                title: 'فاتورة بيع جديدة',
                subtitle: 'إدخال فاتورة مبيعات للعميل',
                onClose: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: 16),
              customersAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => ListErrorState(message: e.toString()),
                data: (customers) => DropdownButtonFormField<String>(
                  initialValue: _customerId,
                  decoration: const InputDecoration(
                    labelText: 'العميل',
                    prefixIcon: FaIcon(FontAwesomeIcons.user),
                  ),
                  items: [
                    for (final c in customers)
                      DropdownMenuItem(
                        value: c.id,
                        child: Text(
                          c.phone == null || c.phone!.isEmpty
                              ? c.name
                              : '${c.name} — ${c.phone}',
                        ),
                      ),
                  ],
                  onChanged: (v) => setState(() => _customerId = v),
                ),
              ),
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
                    child: Text(
                      'الأصناف',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _addLine,
                    icon: const FaIcon(FontAwesomeIcons.plus),
                    label: const Text('إضافة صنف'),
                  ),
                ],
              ),
              for (var i = 0; i < _lines.length; i++) ...[
                _LineRow(
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
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _paidCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
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
                        child: CircularProgressIndicator(strokeWidth: 2),
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

/// A single editable line: product name + adaptive qty + price + line total.
class _LineRow extends StatefulWidget {
  const _LineRow({required this.entry, required this.onRemove});

  final _LineEntry entry;
  final VoidCallback onRemove;

  @override
  State<_LineRow> createState() => _LineRowState();
}

class _LineRowState extends State<_LineRow> {
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

  _LineEntry get entry => widget.entry;

  @override
  Widget build(BuildContext context) {
    final product = entry.product;
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
                  child: Text(
                    product.name,
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w600),
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
              '${product.unit} · المخزون: ${formatQty(product.qty, product.unitType)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ProductQuantityField(
                    controller: entry.qtyCtrl,
                    unitType: product.unitType,
                    unit: product.unit,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PriceField(
                    controller: entry.priceCtrl,
                    label: 'السعر',
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
                  Text(
                    'إجمالي السطر: ',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    Money.format(_lineTotal()),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
            FaIcon(FontAwesomeIcons.receipt,
              size: 48,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 16),
            Text('لا توجد فواتير بيع',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'اضغط على + لإنشاء أول فاتورة',
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
