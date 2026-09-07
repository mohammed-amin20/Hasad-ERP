/// Input payload for creating or updating a customer.
class CustomerDraft {
  const CustomerDraft({
    required this.name,
    this.phone,
    this.notes,
  });

  final String name;
  final String? phone;
  final String? notes;

  Map<String, dynamic> toJson() => {
        'name': name,
        'phone': phone,
        'notes': notes,
      };
}