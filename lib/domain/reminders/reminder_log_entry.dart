import '../../core/utils/money.dart';

/// One row of the read-only `reminder_log` feed (display only, never the
/// sending path — the database owns sending).
class ReminderLogEntry {
  const ReminderLogEntry({
    required this.id,
    this.customerId,
    this.customerName,
    this.amount,
    this.phone,
    this.message = '',
    required this.status,
    required this.createdAt,
  });

  /// Tolerates deleted customers (no embedded `customers` row) and null
  /// amount/phone.
  factory ReminderLogEntry.fromJson(Map<String, dynamic> json) {
    final customer = json['customers'] as Map<String, dynamic>?;
    return ReminderLogEntry(
      id: json['id'] as String,
      customerId: json['customer_id'] as String?,
      customerName: customer?['name'] as String?,
      amount: (json['amount'] as num?)?.toInt(),
      phone: json['phone'] as String?,
      message: json['message'] as String? ?? '',
      status: json['status'] as String? ?? 'sent',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  final String id;
  final String? customerId;

  /// Materialized via the `customers(name)` embed; null when the customer was
  /// deleted (`on delete set null`).
  final String? customerName;

  /// Outstanding amount at send time, in agorot.
  final int? amount;
  final String? phone;
  final String message;

  /// `'sent'` (queued to the webhook) or `'failed'` per migration 0013.
  final String status;
  final DateTime createdAt;

  bool get failed => status == 'failed';

  /// [Money.format] of [amount]; null when the amount is missing.
  String? get amountText => amount == null ? null : Money.format(amount!);
}
