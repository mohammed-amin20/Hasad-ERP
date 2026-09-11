import 'product.dart';

/// Input payload for creating or updating a product.
class ProductDraft {
  const ProductDraft({
    required this.name,
    required this.unit,
    required this.unitType,
    required this.salePrice,
    required this.purchasePrice,
    required this.qty,
    required this.reorderLevel,
    this.barcode,
    this.supplierId,
    this.commissionRate,
  });

  final String name;
  final String? barcode;
  final String unit;
  final ProductUnitType unitType;
  final int salePrice;
  final int purchasePrice;
  final double qty;
  final double reorderLevel;
  final String? supplierId;
  final double? commissionRate;

  Map<String, dynamic> toJson() => {
    'name': name,
    'barcode': barcode,
    'unit': unit,
    'unit_type': unitType.dbValue,
    'sale_price': salePrice,
    'purchase_price': purchasePrice,
    'qty': qty,
    'reorder_level': reorderLevel,
    'supplier_id': supplierId,
    'commission_rate': commissionRate,
  };
}
