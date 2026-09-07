import 'package:uuid/uuid.dart';

import '../products/product.dart';

/// A new product created inline while receiving a purchase.
class NewProductDraft {
  const NewProductDraft({
    required this.name,
    this.unit = 'قطعة',
    this.unitType = ProductUnitType.count,
    this.salePrice = 0,
    this.commissionRate,
  });

  final String name;
  final String unit;
  final ProductUnitType unitType;
  final int salePrice;
  final double? commissionRate;

  Map<String, dynamic> toJson() => {
        'name': name,
        'unit': unit,
        'unit_type': unitType.dbValue,
        'sale_price': salePrice,
        if (commissionRate != null) 'commission_rate': commissionRate,
      };
}

/// A purchase line: either an existing product or an inline-created one.
class PurchaseLineDraft {
  const PurchaseLineDraft({
    this.productId,
    this.newProduct,
    required this.qty,
    this.price,
  }) : assert(productId != null || newProduct != null);

  final String? productId;
  final NewProductDraft? newProduct;
  final double qty;
  final int? price;

  Map<String, dynamic> toJson() => {
        if (productId != null) 'product_id': productId,
        if (newProduct != null) 'new_product': newProduct!.toJson(),
        'qty': qty,
        if (price != null) 'price': price,
      };
}

/// Payload for `create_purchase_invoice`.
class PurchaseInvoiceDraft {
  const PurchaseInvoiceDraft({
    required this.supplierId,
    required this.lines,
    this.date,
    this.paid = 0,
    this.paymentMethod,
    this.memo,
  });

  final String supplierId;
  final List<PurchaseLineDraft> lines;
  final DateTime? date;
  final int paid;
  final String? paymentMethod;
  final String? memo;

  /// Stable request id so a retried call is idempotent server-side.
  Map<String, dynamic> toJson({String? requestId}) => {
        'p_request_id': requestId ?? const Uuid().v4(),
        'p_supplier_id': supplierId,
        'p_items': [
          for (final line in lines) line.toJson(),
        ],
        if (date != null)
          'p_invoice_date': date != null
              ? '${date!.year.toString().padLeft(4, '0')}-'
                  '${date!.month.toString().padLeft(2, '0')}-'
                  '${date!.day.toString().padLeft(2, '0')}'
              : null,
        'p_paid': paid,
        if (paymentMethod != null) 'p_payment_method': paymentMethod,
        if (memo != null && memo!.trim().isNotEmpty) 'p_memo': memo,
      };
}