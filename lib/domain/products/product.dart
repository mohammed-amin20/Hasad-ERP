/// How product quantities are measured (schema `unit_type`).
enum ProductUnitType {
  count,
  weight;

  static ProductUnitType fromDb(String value) =>
      value == 'weight' ? ProductUnitType.weight : ProductUnitType.count;

  String get dbValue => name;
}

/// A product / inventory item stored in the `products` table.
class Product {
  const Product({
    required this.id,
    required this.name,
    this.barcode,
    required this.unit,
    required this.unitType,
    required this.salePrice,
    required this.purchasePrice,
    required this.qty,
    required this.reorderLevel,
    this.supplierId,
    this.commissionRate,
  });

  final String id;
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

  factory Product.fromJson(Map<String, dynamic> json) => Product(
    id: json['id'] as String,
    name: json['name'] as String,
    barcode: json['barcode'] as String?,
    unit: json['unit'] as String,
    unitType: ProductUnitType.fromDb(json['unit_type'] as String? ?? 'count'),
    salePrice: (json['sale_price'] as num).toInt(),
    purchasePrice: (json['purchase_price'] as num).toInt(),
    qty: (json['qty'] as num?)?.toDouble() ?? 0,
    reorderLevel: (json['reorder_level'] as num?)?.toDouble() ?? 0,
    supplierId: json['supplier_id'] as String?,
    commissionRate: (json['commission_rate'] as num?)?.toDouble(),
  );
}

/// Quantity string for the given unit type: whole numbers for count,
/// up to three decimals for weight (schema `numeric(15,3)`).
String formatQty(double qty, ProductUnitType unitType) {
  final rounded = unitType == ProductUnitType.count ? qty.roundToDouble() : qty;
  return rounded == rounded.roundToDouble()
      ? rounded.toStringAsFixed(0)
      : rounded.toStringAsFixed(3);
}
