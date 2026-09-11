import '../invoices/invoice.dart';
import 'sale_invoice_draft.dart';

/// Result envelope returned by the `create_sale_invoice` RPC.
class SaleInvoiceResult {
  const SaleInvoiceResult({
    required this.invoiceId,
    required this.no,
    required this.total,
    required this.paid,
    required this.remaining,
    required this.status,
    required this.entryNo,
  });

  final String invoiceId;
  final String no;
  final int total;
  final int paid;
  final int remaining;
  final InvoiceStatus status;
  final int entryNo;

  factory SaleInvoiceResult.fromJson(Map<String, dynamic> json) =>
      SaleInvoiceResult(
        invoiceId: json['invoice_id'] as String,
        no: json['no'] as String,
        total: (json['total'] as num).toInt(),
        paid: (json['paid'] as num).toInt(),
        remaining: (json['remaining'] as num).toInt(),
        status: InvoiceStatus.fromDb(json['status'] as String),
        entryNo: (json['entry_no'] as num).toInt(),
      );
}

/// Creates sale invoices by calling the balanced-double-entry RPC.
abstract interface class SaleRepository {
  Future<SaleInvoiceResult> create(SaleInvoiceDraft draft);
}
