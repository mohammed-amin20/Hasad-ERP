import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/services.dart';

import '../../domain/products/product.dart';
import '../../domain/purchases/purchase_invoice_draft.dart';
import 'invoice_input_fields.dart';

/// Opens a bottom sheet to describe a brand-new product and returns its draft,
/// or null if dismissed.
Future<NewProductDraft?> showNewProductSheet(BuildContext context) {
  return showModalBottomSheet<NewProductDraft>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const _NewProductSheet(),
  );
}

class _NewProductSheet extends StatefulWidget {
  const _NewProductSheet();

  @override
  State<_NewProductSheet> createState() => _NewProductSheetState();
}

class _NewProductSheetState extends State<_NewProductSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _unitCtrl = TextEditingController();
  final _salePriceCtrl = TextEditingController();
  final _commissionCtrl = TextEditingController();
  late ProductUnitType _unitType;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _unitType = ProductUnitType.count;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _unitCtrl.dispose();
    _salePriceCtrl.dispose();
    _commissionCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final commissionText = _commissionCtrl.text.trim();
    setState(() => _submitting = true);
    Navigator.of(context).pop(
      NewProductDraft(
        name: _nameCtrl.text.trim(),
        unit: _unitCtrl.text.trim().isEmpty ? 'قطعة' : _unitCtrl.text.trim(),
        unitType: _unitType,
        salePrice: priceToAgorot(_salePriceCtrl.text.trim()) ?? 0,
        commissionRate: commissionText.isEmpty
            ? null
            : double.tryParse(commissionText),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
              Text(
                'منتج جديد أثناء الاستلام',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameCtrl,
                autofocus: true,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'اسم المنتج',
                  prefixIcon: FaIcon(FontAwesomeIcons.boxesStacked),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'أدخل اسم المنتج' : null,
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _unitCtrl,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'الوحدة',
                        hintText: 'قطعة',
                        prefixIcon: Icon(Icons.straighten),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<ProductUnitType>(
                      initialValue: _unitType,
                      decoration: const InputDecoration(
                        labelText: 'نوع الكمية',
                        prefixIcon: FaIcon(FontAwesomeIcons.scaleBalanced),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: ProductUnitType.count,
                          child: Text('عدد'),
                        ),
                        DropdownMenuItem(
                          value: ProductUnitType.weight,
                          child: Text('وزن'),
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
              TextFormField(
                controller: _salePriceCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'سعر البيع (اختياري)',
                  prefixIcon: FaIcon(FontAwesomeIcons.tag),
                ),
                validator: (v) {
                  final text = (v ?? '').trim();
                  if (text.isEmpty) return null;
                  if (double.tryParse(text) == null) return 'قيمة غير صالحة';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _commissionCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'نسبة العمولة % (اختياري)',
                  prefixIcon: FaIcon(FontAwesomeIcons.percent),
                ),
                validator: (v) {
                  final text = (v ?? '').trim();
                  if (text.isEmpty) return null;
                  final rate = double.tryParse(text);
                  if (rate == null || rate < 0 || rate > 100) {
                    return 'نسبة بين 0 و 100';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: const Text('إضافة المنتج'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
