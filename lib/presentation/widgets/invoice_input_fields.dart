import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/utils/money.dart';
import '../../domain/products/product.dart';

/// Adaptive quantity input: whole numbers for count, up to 3 decimals for
/// weight (PROJECT_SPEC §7).
class ProductQuantityField extends StatelessWidget {
  const ProductQuantityField({
    super.key,
    required this.controller,
    required this.unitType,
    required this.unit,
    this.enabled = true,
    this.onChanged,
  });

  final TextEditingController controller;
  final ProductUnitType unitType;
  final String unit;
  final bool enabled;
  final ValueChanged<double>? onChanged;

  bool get _isWeight => unitType == ProductUnitType.weight;

  String? _validate(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'أدخل الكمية';
    if (_isWeight) {
      if (!RegExp(r'^\d+(\.\d{1,3})?$').hasMatch(text)) {
        return 'حتى 3 خانات عشرية';
      }
    } else {
      if (!RegExp(r'^\d+$').hasMatch(text)) {
        return 'عدد صحيح فقط';
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.numberWithOptions(decimal: _isWeight),
      inputFormatters: [
        _isWeight
            ? FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
            : FilteringTextInputFormatter.digitsOnly,
      ],
      decoration: InputDecoration(
        labelText: 'الكمية',
        suffixText: unit,
        hintText: _isWeight ? 'مثلاً 1.250' : 'مثلاً 10',
      ),
      validator: _validate,
      onChanged: onChanged == null
          ? null
          : (v) {
              final value = double.tryParse(v.trim());
              if (value != null) onChanged!(value);
            },
    );
  }
}

/// Price input that stores agorot (schema bigint) while editing in decimals.
class PriceField extends StatelessWidget {
  const PriceField({
    super.key,
    required this.controller,
    required this.label,
    this.requiredMessage,
    this.extraValidator,
  });

  final TextEditingController controller;
  final String label;
  final String? requiredMessage;
  final String? Function(String? value)? extraValidator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label),
      validator: (v) {
        final text = (v ?? '').trim();
        if (text.isEmpty && requiredMessage != null) return requiredMessage;
        if (extraValidator != null) {
          final extra = extraValidator!(v);
          if (extra != null) return extra;
        }
        if (text.isNotEmpty && double.tryParse(text) == null) {
          return 'قيمة غير صالحة';
        }
        return null;
      },
    );
  }
}

/// Parse an editable price string into agorot (empty → 0, errors → null).
int? priceToAgorot(String text, {bool allowZero = true}) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return allowZero ? 0 : null;
  final value = double.tryParse(trimmed);
  if (value == null) return null;
  return Money.fromAmount(value);
}
