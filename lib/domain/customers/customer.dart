/// A business customer record stored in the `customers` table.
class Customer {
  const Customer({
    required this.id,
    required this.name,
    this.phone,
    this.notes,
    this.createdAt,
  });

  final String id;
  final String name;
  final String? phone;
  final String? notes;
  final DateTime? createdAt;

  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
    id: json['id'] as String,
    name: json['name'] as String,
    phone: json['phone'] as String?,
    notes: json['notes'] as String?,
    createdAt: json['created_at'] != null
        ? DateTime.parse(json['created_at'] as String)
        : null,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    if (phone != null) 'phone': phone,
    if (notes != null) 'notes': notes,
  };
}
