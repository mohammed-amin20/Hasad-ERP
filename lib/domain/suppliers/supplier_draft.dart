import 'supplier.dart';

/// Input payload for creating or updating a supplier.
class SupplierDraft {
  const SupplierDraft({
    required this.name,
    this.phone,
    this.notes,
    required this.dealType,
    this.commissionRate,
  });

  final String name;
  final String? phone;
  final String? notes;
  final SupplierDealType dealType;
  final double? commissionRate;

  Map<String, dynamic> toJson() => {
    'name': name,
    'phone': phone,
    'notes': notes,
    'deal_type': dealType.dbValue,
    'commission_rate': commissionRate,
  };
}
