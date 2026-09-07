import '../invoices/invoice.dart';
import 'purchase_invoice_draft.dart';

/// Result envelope returned by the `create_purchase_invoice` RPC.
class PurchaseInvoiceResult {
  const PurchaseInvoiceResult({
    required this.invoiceId,
    required this.no,
    required this.total,
    required this.paid,
    required this.remaining,
    required this.status,
    required this.ownership,
    required this.entryNo,
  });

  final String invoiceId;
  final String no;
  final int total;
  final int paid;
  final int remaining;
  final InvoiceStatus status;
  final InvoiceOwnership ownership;
  final int entryNo;

  factory PurchaseInvoiceResult.fromJson(Map<String, dynamic> json) =>
      PurchaseInvoiceResult(
        invoiceId: json['invoice_id'] as String,
        no: json['no'] as String,
        total: (json['total'] as num).toInt(),
        paid: (json['paid'] as num).toInt(),
        remaining: (json['remaining'] as num).toInt(),
        status: InvoiceStatus.fromDb(json['status'] as String),
        ownership: InvoiceOwnership.fromDb(json['ownership'] as String),
        entryNo: (json['entry_no'] as num?)?.toInt() ?? 0,
      );
}

/// Creates purchase invoices by calling the RPC (direct vs consignment).
abstract interface class PurchaseRepository {
  Future<PurchaseInvoiceResult> create(PurchaseInvoiceDraft draft);
}