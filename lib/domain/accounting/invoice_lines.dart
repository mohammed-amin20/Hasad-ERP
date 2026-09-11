import 'package:equatable/equatable.dart';

/// Sale invoice line for double-entry engine
class SaleInvoiceLine extends Equatable {
  const SaleInvoiceLine({
    required this.productId,
    required this.qty,
    required this.price,
  });

  final String productId;
  final int qty;
  final int price; // Unit price in agorot

  int get lineTotal => qty * price;

  @override
  List<Object?> get props => [productId, qty, price];

  Map<String, dynamic> toJson() => {
    'product_id': productId,
    'qty': qty,
    'price': price,
  };
}

/// Purchase invoice line for double-entry engine
class PurchaseInvoiceLine extends Equatable {
  const PurchaseInvoiceLine({
    this.productId,
    this.newProduct,
    required this.qty,
    required this.price,
  });

  final String? productId;
  final ProductDraft? newProduct;
  final int qty;
  final int price; // Unit price in agorot

  int get lineTotal => qty * price;
  bool get isNewProduct => newProduct != null;

  @override
  List<Object?> get props => [productId, newProduct, qty, price];

  Map<String, dynamic> toJson() => {
    if (productId != null) 'product_id': productId,
    if (newProduct != null) 'new_product': newProduct!.toJson(),
    'qty': qty,
    'price': price,
  };
}

/// Product draft for inline creation in purchase
class ProductDraft extends Equatable {
  const ProductDraft({
    required this.name,
    required this.unitType,
    required this.unit,
    required this.salePrice,
    this.costPrice = 0,
    this.qtyOnHand = 0,
    this.reorderLevel = 0,
    this.supplierId,
    this.commissionRate,
  });

  final String name;
  final String unitType; // 'count' | 'weight'
  final String unit;
  final int salePrice;
  final int costPrice;
  final int qtyOnHand;
  final int reorderLevel;
  final String? supplierId;
  final double? commissionRate;

  @override
  List<Object?> get props => [
    name,
    unitType,
    unit,
    salePrice,
    costPrice,
    qtyOnHand,
    reorderLevel,
    supplierId,
    commissionRate,
  ];

  Map<String, dynamic> toJson() => {
    'name': name,
    'unit_type': unitType,
    'unit': unit,
    'sale_price': salePrice,
    'cost_price': costPrice,
    'qty_on_hand': qtyOnHand,
    'reorder_level': reorderLevel,
    'supplier_id': supplierId,
    'commission_rate': commissionRate,
  };
}
