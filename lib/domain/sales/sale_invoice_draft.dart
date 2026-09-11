import 'package:uuid/uuid.dart';

/// A line item awaiting a sale invoice: existing product + adaptive qty.
class SaleLineDraft {
  const SaleLineDraft({required this.productId, required this.qty, this.price});

  final String productId;
  final double qty;
  final int? price;

  Map<String, dynamic> toJson() => {
    'product_id': productId,
    'qty': qty,
    if (price != null) 'price': price,
  };
}

/// Payload for `create_sale_invoice`.
class SaleInvoiceDraft {
  const SaleInvoiceDraft({
    required this.customerId,
    required this.lines,
    this.date,
    this.paid = 0,
    this.paymentMethod,
    this.memo,
  });

  final String customerId;
  final List<SaleLineDraft> lines;
  final DateTime? date;
  final int paid;
  final String? paymentMethod;
  final String? memo;

  /// Stable request id so a retried call is idempotent server-side.
  Map<String, dynamic> toJson({String? requestId}) => {
    'p_request_id': requestId ?? const Uuid().v4(),
    'p_customer_id': customerId,
    'p_items': [for (final line in lines) line.toJson()],
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
