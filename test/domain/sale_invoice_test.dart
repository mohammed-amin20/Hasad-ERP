import 'package:flutter_test/flutter_test.dart';
import 'package:hasad_erp/domain/invoices/invoice.dart';
import 'package:hasad_erp/domain/sales/sale_invoice_draft.dart';

void main() {
  group('InvoiceStatus', () {
    test('fromDb parses all statuses and defaults to unpaid', () {
      expect(InvoiceStatus.fromDb('paid'), InvoiceStatus.paid);
      expect(InvoiceStatus.fromDb('partial'), InvoiceStatus.partial);
      expect(InvoiceStatus.fromDb('unpaid'), InvoiceStatus.unpaid);
      expect(InvoiceStatus.fromDb('anything'), InvoiceStatus.unpaid);
    });

    test('labels are Arabic', () {
      expect(InvoiceStatus.paid.label, 'مدفوعة');
      expect(InvoiceStatus.partial.label, 'جزئية');
      expect(InvoiceStatus.unpaid.label, 'غير مدفوعة');
    });
  });

  group('InvoiceOwnership', () {
    test('fromDb maps consignment and defaults to owned', () {
      expect(InvoiceOwnership.fromDb('consignment'), InvoiceOwnership.consignment);
      expect(InvoiceOwnership.fromDb('owned'), InvoiceOwnership.owned);
      expect(InvoiceOwnership.fromDb('x'), InvoiceOwnership.owned);
    });
  });

  group('Invoice', () {
    test('fromJson maps header fields', () {
      final invoice = Invoice.fromJson({
        'id': '11111111-1111-1111-1111-111111111111',
        'type': 'sale',
        'no': 'FS-000123',
        'party_id': '22222222-2222-2222-2222-222222222222',
        'date': '2026-09-05',
        'subtotal': 1500,
        'total': 1500,
        'paid': 1000,
        'remaining': 500,
        'status': 'partial',
        'ownership': 'owned',
      });

      expect(invoice.type, 'sale');
      expect(invoice.no, 'FS-000123');
      expect(invoice.date.year, 2026);
      expect(invoice.status, InvoiceStatus.partial);
      expect(invoice.remaining, 500);
    });
  });

  group('SaleInvoiceDraft', () {
    test('toJson sends required RPC params', () {
      final draft = SaleInvoiceDraft(
        customerId: '22222222-2222-2222-2222-222222222222',
        lines: [
          const SaleLineDraft(productId: '33333333-3333-3333-3333-333333333333', qty: 2),
        ],
      );
      final json = draft.toJson(requestId: 'request-1');

      expect(json['p_request_id'], 'request-1');
      expect(json['p_customer_id'], '22222222-2222-2222-2222-222222222222');
      expect(json['p_paid'], 0);
      final items = json['p_items'] as List;
      expect(items, hasLength(1));
      final first = items.first as Map<String, dynamic>;
      expect(first['qty'], 2);
      expect(first.containsKey('price'), isFalse);
      expect(json.containsKey('p_invoice_date'), isFalse);
      expect(json.containsKey('p_payment_method'), isFalse);
      expect(json.containsKey('p_memo'), isFalse);
    });

    test('toJson includes price, date, method and memo when set', () {
      final draft = SaleInvoiceDraft(
        customerId: '22222222-2222-2222-2222-222222222222',
        date: DateTime(2026, 9, 7),
        lines: [
          SaleLineDraft(
            productId: '33333333-3333-3333-3333-333333333333',
            qty: 1.5,
            price: 1200,
          ),
        ],
        paid: 1800,
        paymentMethod: 'cash',
        memo: 'توصيل',
      );
      final json = draft.toJson(requestId: 'request-2');

      expect(json['p_invoice_date'], '2026-09-07');
      expect(json['p_payment_method'], 'cash');
      expect(json['p_paid'], 1800);
      expect(json['p_memo'], 'توصيل');
      final first = (json['p_items'] as List).first as Map<String, dynamic>;
      expect(first['price'], 1200);
      expect(first['qty'], 1.5);
    });

    test('blank memo is omitted', () {
      final draft = SaleInvoiceDraft(
        customerId: '22222222-2222-2222-2222-222222222222',
        lines: const [
          SaleLineDraft(productId: 'p', qty: 1),
        ],
        paid: 0,
        paymentMethod: null,
        memo: '   ',
      );
      final json = draft.toJson(requestId: 'request-3');
      expect(json.containsKey('p_memo'), isFalse);
    });

    test('request id is unique when omitted', () {
      final draft = SaleInvoiceDraft(
        customerId: '22222222-2222-2222-2222-222222222222',
        lines: const [
          SaleLineDraft(productId: 'p', qty: 1),
        ],
      );
      final a = draft.toJson()['p_request_id'];
      final b = draft.toJson()['p_request_id'];
      expect(a, isNot(equals(b)));
    });
  });
}