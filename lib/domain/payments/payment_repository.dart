import 'package:uuid/uuid.dart';

String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Pay down one invoice via the `record_payment` RPC (sale or purchase).
class PaymentDraft {
  const PaymentDraft({
    required this.invoiceId,
    required this.amount,
    required this.method,
    this.date,
    this.note,
  });

  final String invoiceId;
  final int amount;
  final String method;
  final DateTime? date;
  final String? note;

  Map<String, dynamic> toJson({String? requestId}) => {
        'p_request_id': requestId ?? const Uuid().v4(),
        'p_invoice_id': invoiceId,
        'p_amount': amount,
        'p_method': method,
        if (date != null) 'p_date': _isoDate(date!),
        if (note != null && note!.trim().isNotEmpty) 'p_note': note,
      };
}

/// Bulk-settle a supplier's oldest owned invoices + commission dues via the
/// `settle_supplier` RPC.
class SettlementDraft {
  const SettlementDraft({
    required this.supplierId,
    required this.amount,
    required this.method,
    this.date,
    this.note,
  });

  final String supplierId;
  final int amount;
  final String method;
  final DateTime? date;
  final String? note;

  Map<String, dynamic> toJson({String? requestId}) => {
        'p_request_id': requestId ?? const Uuid().v4(),
        'p_supplier_id': supplierId,
        'p_amount': amount,
        'p_method': method,
        if (date != null) 'p_date': _isoDate(date!),
        if (note != null && note!.trim().isNotEmpty) 'p_note': note,
      };
}

/// Result of `record_payment` (idempotent duplicates replay the same row).
class PaymentResult {
  const PaymentResult({
    this.duplicate = false,
    this.paymentId,
    this.invoiceId,
    this.no = '',
    this.total = 0,
    this.paid = 0,
    this.remaining = 0,
    this.status = '',
    this.entryNo = 0,
  });

  final bool duplicate;
  final String? paymentId;
  final String? invoiceId;
  final String no;
  final int total;
  final int paid;
  final int remaining;
  final String status;
  final int entryNo;

  factory PaymentResult.fromJson(Map<String, dynamic> json) {
    final duplicate = json['duplicate'] == true;
    final payload =
        duplicate ? (json['payment'] as Map?) ?? const {} : json;
    return PaymentResult(
      duplicate: duplicate,
      paymentId: payload['payment_id'] as String?,
      invoiceId: payload['invoice_id'] as String?,
      no: payload['no'] as String? ?? '',
      total: (payload['total'] as num?)?.toInt() ?? 0,
      paid: (payload['paid'] as num?)?.toInt() ?? 0,
      remaining: (payload['remaining'] as num?)?.toInt() ?? 0,
      status: payload['status'] as String? ?? '',
      entryNo: (payload['entry_no'] as num?)?.toInt() ?? 0,
    );
  }
}

/// One allocation inside a bulk supplier settlement.
class SettlementAllocation {
  const SettlementAllocation({
    required this.invoiceId,
    this.no,
    this.dueId,
    required this.amount,
  });

  final String invoiceId;
  final String? no;
  final String? dueId;
  final int amount;

  factory SettlementAllocation.fromJson(Map<String, dynamic> json) =>
      SettlementAllocation(
        invoiceId: json['invoice_id'] as String,
        no: json['no'] as String?,
        dueId: json['due_id'] as String?,
        amount: (json['amount'] as num?)?.toInt() ?? 0,
      );
}

/// Result of `settle_supplier`.
class SettlementResult {
  const SettlementResult({
    this.duplicate = false,
    this.total = 0,
    this.invoicesCount = 0,
    this.duesCount = 0,
    this.entryNo = 0,
    this.allocations = const [],
  });

  final bool duplicate;
  final int total;
  final int invoicesCount;
  final int duesCount;
  final int entryNo;
  final List<SettlementAllocation> allocations;

  factory SettlementResult.fromJson(Map<String, dynamic> json) {
    final duplicate = json['duplicate'] == true;
    final payload =
        duplicate ? (json['result'] as Map?) ?? const {} : json;
    return SettlementResult(
      duplicate: duplicate,
      total: (payload['total'] as num?)?.toInt() ?? 0,
      invoicesCount: (payload['invoices_count'] as num?)?.toInt() ?? 0,
      duesCount: (payload['dues_count'] as num?)?.toInt() ?? 0,
      entryNo: (payload['entry_no'] as num?)?.toInt() ?? 0,
      allocations: [
        for (final a in (payload['allocations'] as List?) ?? const [])
          if (a is Map<String, dynamic>)
            SettlementAllocation.fromJson(a),
      ],
    );
  }
}

/// Writes payments/settlements (only RPCs — the tables are SELECT-only).
abstract class PaymentRepository {
  Future<PaymentResult> record(PaymentDraft draft);

  Future<SettlementResult> settle(SettlementDraft draft);
}