/// Deal arrangement with a supplier.
enum SupplierDealType {
  direct,
  commission;

  static SupplierDealType fromDb(String value) => value == 'commission'
      ? SupplierDealType.commission
      : SupplierDealType.direct;

  String get dbValue => name;
}

/// A business supplier record stored in the `suppliers` table.
class Supplier {
  const Supplier({
    required this.id,
    required this.name,
    this.phone,
    this.notes,
    required this.dealType,
    this.commissionRate,
    this.createdAt,
  });

  final String id;
  final String name;
  final String? phone;
  final String? notes;
  final SupplierDealType dealType;
  final double? commissionRate;
  final DateTime? createdAt;

  factory Supplier.fromJson(Map<String, dynamic> json) => Supplier(
        id: json['id'] as String,
        name: json['name'] as String,
        phone: json['phone'] as String?,
        notes: json['notes'] as String?,
        dealType: SupplierDealType.fromDb(json['deal_type'] as String? ?? 'direct'),
        commissionRate: (json['commission_rate'] as num?)?.toDouble(),
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'] as String)
            : null,
      );
}