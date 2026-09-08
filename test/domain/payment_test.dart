import 'package:flutter_test/flutter_test.dart';
import 'package:hasad_erp/domain/payments/payment_repository.dart';

void main() {
  const invoiceId = 'cccccccc-cccc-cccc-cccc-cccccccccccc';

  group('PaymentDraft', () {
    test('toJson sends required RPC params', () {
      final json = PaymentDraft(
        invoiceId: invoiceId,
        amount: 5000,
        method: 'cash',
      ).toJson(requestId: 'req-1');

      expect(json['p_request_id'], 'req-1');
      expect(json['p_invoice_id'], invoiceId);
      expect(json['p_amount'], 5000);
      expect(json['p_method'], 'cash');
      expect(json.containsKey('p_date'), isFalse);
      expect(json.containsKey('p_note'), isFalse);
    });

    test('toJson includes date and note when set', () {
      final json = PaymentDraft(
        invoiceId: invoiceId,
        amount: 120,
        method: 'bank',
        date: DateTime(2026, 9, 30),
        note: 'سداد جزئي',
      ).toJson(requestId: 'req-2');

      expect(json['p_date'], '2026-09-30');
      expect(json['p_note'], 'سداد جزئي');
    });

    test('blank note is omitted', () {
      final json = PaymentDraft(
        invoiceId: invoiceId,
        amount: 10,
        method: 'cash',
        note: '   ',
      ).toJson();
      expect(json.containsKey('p_note'), isFalse);
      expect(json['p_request_id'], isNotNull);
    });
  });

  group('SettlementDraft', () {
    test('toJson sends supplier + amount', () {
      final json = SettlementDraft(
        supplierId: 'dddddddd-dddd-dddd-dddd-dddddddddddd',
        amount: 800,
        method: 'bank',
      ).toJson(requestId: 'req-3');

      expect(json['p_supplier_id'], 'dddddddd-dddd-dddd-dddd-dddddddddddd');
      expect(json['p_amount'], 800);
      expect(json['p_method'], 'bank');
      expect(json.containsKey('p_date'), isFalse);
    });
  });

  group('PaymentResult', () {
    test('fromJson parses a fresh payment', () {
      final r = PaymentResult.fromJson({
        'payment_id': 'p1',
        'invoice_id': invoiceId,
        'no': 'S-100',
        'total': 5000,
        'paid': 5000,
        'remaining': 0,
        'status': 'paid',
        'entry_no': 7,
      });

      expect(r.duplicate, isFalse);
      expect(r.no, 'S-100');
      expect(r.remaining, 0);
      expect(r.status, 'paid');
      expect(r.entryNo, 7);
    });

    test('fromJson replays a duplicate', () {
      final r = PaymentResult.fromJson({
        'duplicate': true,
        'payment': {
          'no': 'S-100',
          'remaining': 0,
          'status': 'paid',
        },
      });

      expect(r.duplicate, isTrue);
      expect(r.status, 'paid');
    });
  });

  group('SettlementResult', () {
    test('fromJson parses allocations', () {
      final r = SettlementResult.fromJson({
        'total': 900,
        'invoices_count': 1,
        'dues_count': 1,
        'entry_no': 8,
        'allocations': [
          {'invoice_id': 'i1', 'no': 'P-2', 'amount': 500},
          {'invoice_id': 'i2', 'due_id': 'd1', 'amount': 400},
        ],
      });

      expect(r.total, 900);
      expect(r.invoicesCount, 1);
      expect(r.duesCount, 1);
      expect(r.entryNo, 8);
      expect(r.allocations.length, 2);
      expect(r.allocations[0].no, 'P-2');
      expect(r.allocations[1].dueId, 'd1');
      expect(r.allocations[1].amount, 400);
    });

    test('fromJson replays duplicate result', () {
      final r = SettlementResult.fromJson({
        'duplicate': true,
        'result': {'total': 100, 'invoices_count': 1, 'dues_count': 0},
      });
      expect(r.duplicate, isTrue);
      expect(r.total, 100);
    });
  });
}