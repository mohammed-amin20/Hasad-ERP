import 'package:flutter_test/flutter_test.dart';
import 'package:hasad_erp/domain/inventory/inventory.dart';

void main() {
  group('StockAdjustDraft', () {
    test('toJson sends required RPC params', () {
      final draft = StockAdjustDraft(
        productId: '11111111-1111-1111-1111-111111111111',
        countedQty: 12.5,
      );
      final json = draft.toJson();

      expect(json['p_product_id'], '11111111-1111-1111-1111-111111111111');
      expect(json['p_counted_qty'], 12.5);
      expect(json.containsKey('p_reason'), isFalse);
      expect(json.containsKey('p_date'), isFalse);
    });

    test('toJson includes reason and date when set', () {
      final draft = StockAdjustDraft(
        productId: '11111111-1111-1111-1111-111111111111',
        countedQty: 8,
        reason: 'جرد شهري',
        date: DateTime(2026, 9, 30),
      );
      final json = draft.toJson();

      expect(json['p_reason'], 'جرد شهري');
      expect(json['p_date'], '2026-09-30');
    });

    test('blank reason is omitted', () {
      final draft = StockAdjustDraft(
        productId: 'p',
        countedQty: 1,
        reason: '   ',
      );
      expect(draft.toJson().containsKey('p_reason'), isFalse);
    });

    test('omits the idempotency key when no request id is supplied', () {
      final json = const StockAdjustDraft(productId: 'p', countedQty: 1).toJson();
      expect(json.containsKey('p_request_id'), isFalse);
    });

    test('carries the stable request id verbatim when supplied', () {
      // Retries replay the stored params, so the same request id must come back
      // out of the payload on every attempt (0025 dedupes on it).
      final json = const StockAdjustDraft(productId: 'p', countedQty: 7)
          .toJson(requestId: 'req-stable');
      expect(json['p_request_id'], 'req-stable');
      expect(json['p_counted_qty'], 7);
    });
  });

  group('StockAdjustResult', () {
    test('fromJson parses a down-adjust result', () {
      final result = StockAdjustResult.fromJson({
        'product_id': '11111111-1111-1111-1111-111111111111',
        'name': 'طماطم',
        'old_qty': 10,
        'new_qty': 6,
        'delta': -4,
        'changed': true,
      });

      expect(result.productId, '11111111-1111-1111-1111-111111111111');
      expect(result.productName, 'طماطم');
      expect(result.oldQty, 10);
      expect(result.newQty, 6);
      expect(result.delta, -4);
      expect(result.changed, isTrue);
    });

    test('fromJson parses a no-op result', () {
      final result = StockAdjustResult.fromJson({
        'product_id': '11111111-1111-1111-1111-111111111111',
        'name': 'ملح',
        'old_qty': 3,
        'new_qty': 3,
        'delta': 0,
        'changed': false,
      });

      expect(result.changed, isFalse);
      expect(result.delta, 0);
    });
  });
}