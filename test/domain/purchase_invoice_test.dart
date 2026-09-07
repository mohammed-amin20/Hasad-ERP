import 'package:flutter_test/flutter_test.dart';
import 'package:hasad_erp/domain/invoices/invoice.dart';
import 'package:hasad_erp/domain/products/product.dart';
import 'package:hasad_erp/domain/purchases/purchase_invoice_draft.dart';
import 'package:hasad_erp/domain/purchases/purchase_repository.dart';

void main() {
  group('PurchaseInvoiceDraft', () {
    test('toJson sends an existing-product line without a price', () {
      final draft = PurchaseInvoiceDraft(
        supplierId: '22222222-2222-2222-2222-222222222222',
        lines: [
          const PurchaseLineDraft(
            productId: '33333333-3333-3333-3333-333333333333',
            qty: 3,
          ),
        ],
      );
      final json = draft.toJson(requestId: 'request-1');

      expect(json['p_request_id'], 'request-1');
      expect(json['p_supplier_id'], '22222222-2222-2222-2222-222222222222');
      expect(json['p_paid'], 0);
      final item = (json['p_items'] as List).first as Map<String, dynamic>;
      expect(item['product_id'], '33333333-3333-3333-3333-333333333333');
      expect(item['qty'], 3);
      expect(item.containsKey('price'), isFalse);
      expect(item.containsKey('new_product'), isFalse);
    });

    test('toJson serializes an inline new product with full params', () {
      final draft = PurchaseInvoiceDraft(
        supplierId: '22222222-2222-2222-2222-222222222222',
        date: DateTime(2026, 9, 7),
        lines: [
          PurchaseLineDraft(
            newProduct: const NewProductDraft(
              name: 'زيت زيتون',
              unit: 'قارورة',
              unitType: ProductUnitType.count,
              salePrice: 1500,
              commissionRate: 10,
            ),
            qty: 2,
            price: 1100,
          ),
        ],
        paid: 2200,
        paymentMethod: 'cash',
        memo: 'ورود جديدة',
      );
      final json = draft.toJson(requestId: 'request-2');

      expect(json['p_invoice_date'], '2026-09-07');
      expect(json['p_paid'], 2200);
      expect(json['p_payment_method'], 'cash');
      expect(json['p_memo'], 'ورود جديدة');
      final item = (json['p_items'] as List).first as Map<String, dynamic>;
      expect(item.containsKey('product_id'), isFalse);
      expect(item.containsKey('price'), isTrue);
      final np = item['new_product'] as Map<String, dynamic>;
      expect(np['name'], 'زيت زيتون');
      expect(np['unit'], 'قارورة');
      expect(np['unit_type'], 'count');
      expect(np['sale_price'], 1500);
      expect(np['commission_rate'], 10);
    });

    test('new product defaults unit and unit_type', () {
      const draft = NewProductDraft(name: 'ملح');
      final json = draft.toJson();
      expect(json['unit'], 'قطعة');
      expect(json['unit_type'], 'count');
      expect(json['sale_price'], 0);
      expect(json.containsKey('commission_rate'), isFalse);
    });

    test('consignment receipts force zero paid', () {
      final draft = PurchaseInvoiceDraft(
        supplierId: 's1',
        lines: const [
          PurchaseLineDraft(productId: 'p1', qty: 1),
        ],
        paid: 0,
        paymentMethod: null,
      );
      final json = draft.toJson(requestId: 'request-3');
      expect(json['p_paid'], 0);
      expect(json.containsKey('p_payment_method'), isFalse);
    });

    test('request id is unique when omitted', () {
      final draft = PurchaseInvoiceDraft(
        supplierId: 's1',
        lines: const [
          PurchaseLineDraft(productId: 'p1', qty: 1),
        ],
      );
      expect(
        draft.toJson()['p_request_id'],
        isNot(equals(draft.toJson()['p_request_id'])),
      );
    });

    test('PurchaseInvoiceResult parses consignment ownership', () {
      final result = PurchaseInvoiceResult.fromJson({
        'invoice_id': '11111111-1111-1111-1111-111111111111',
        'no': 'FP-000001',
        'total': 5000,
        'paid': 0,
        'remaining': 5000,
        'status': 'unpaid',
        'ownership': 'consignment',
        'entry_no': null,
      });
      expect(result.ownership, InvoiceOwnership.consignment);
      expect(result.status, InvoiceStatus.unpaid);
      expect(result.entryNo, 0);
      expect(result.total, 5000);
    });
  });
}