import '../products/product.dart';

/// Payment status of an invoice (schema `invoices.status`).
enum InvoiceStatus {
  paid,
  partial,
  unpaid;

  static InvoiceStatus fromDb(String value) => switch (value) {
    'paid' => InvoiceStatus.paid,
    'partial' => InvoiceStatus.partial,
    _ => InvoiceStatus.unpaid,
  };

  String get dbValue => name;

  String get label => switch (this) {
    InvoiceStatus.paid => 'مدفوعة',
    InvoiceStatus.partial => 'جزئية',
    InvoiceStatus.unpaid => 'غير مدفوعة',
  };
}

/// Ownership of a purchase invoice (schema `invoices.ownership`).
enum InvoiceOwnership {
  owned,
  consignment;

  static InvoiceOwnership fromDb(String value) => value == 'consignment'
      ? InvoiceOwnership.consignment
      : InvoiceOwnership.owned;

  String get label => switch (this) {
    InvoiceOwnership.owned => 'ملك',
    InvoiceOwnership.consignment => 'بضاعة أمانة',
  };
}

/// An invoice header read back from the `invoices` table.
class Invoice {
  const Invoice({
    required this.id,
    required this.type,
    required this.no,
    required this.partyId,
    this.partyName,
    required this.date,
    required this.subtotal,
    required this.total,
    required this.paid,
    required this.remaining,
    required this.status,
    required this.ownership,
  });

  final String id;
  final String type;
  final String no;
  final String partyId;
  final String? partyName;
  final DateTime date;
  final int subtotal;
  final int total;
  final int paid;
  final int remaining;
  final InvoiceStatus status;
  final InvoiceOwnership ownership;

  factory Invoice.fromJson(Map<String, dynamic> json) => Invoice(
    id: json['id'] as String,
    type: json['type'] as String,
    no: json['no'] as String,
    partyId: json['party_id'] as String,
    date: DateTime.parse(json['date'] as String),
    subtotal: (json['subtotal'] as num).toInt(),
    total: (json['total'] as num).toInt(),
    paid: (json['paid'] as num).toInt(),
    remaining: (json['remaining'] as num).toInt(),
    status: InvoiceStatus.fromDb(json['status'] as String),
    ownership: InvoiceOwnership.fromDb(json['ownership'] as String),
  );
}

/// A single line of an existing invoice (`invoice_items`).
class InvoiceItem {
  const InvoiceItem({
    required this.productId,
    this.productName,
    this.productUnit,
    this.productUnitType,
    required this.qty,
    required this.price,
    required this.total,
  });

  final String productId;
  final String? productName;
  final String? productUnit;
  final ProductUnitType? productUnitType;
  final double qty;
  final int price;
  final int total;
}
