import 'package:flutter_test/flutter_test.dart';
import 'package:hasad_erp/domain/products/product.dart';
import 'package:hasad_erp/domain/products/product_draft.dart';

void main() {
  group('Product', () {
    test('fromJson maps all fields incl weight + prices', () {
      final product = Product.fromJson({
        'id': '11111111-1111-1111-1111-111111111111',
        'name': 'طماطم',
        'barcode': '6291000000012',
        'unit': 'كجم',
        'unit_type': 'weight',
        'sale_price': 500,
        'purchase_price': 350,
        'qty': 12.5,
        'reorder_level': 5,
        'supplier_id': '22222222-2222-2222-2222-222222222222',
        'commission_rate': null,
      });

      expect(product.name, 'طماطم');
      expect(product.barcode, '6291000000012');
      expect(product.unitType, ProductUnitType.weight);
      expect(product.salePrice, 500);
      expect(product.purchasePrice, 350);
      expect(product.qty, 12.5);
      expect(product.reorderLevel, 5);
      expect(product.supplierId, '22222222-2222-2222-2222-222222222222');
      expect(product.commissionRate, isNull);
    });

    test('fromJson defaults count and zero quantities', () {
      final product = Product.fromJson({
        'id': '11111111-1111-1111-1111-111111111111',
        'name': 'طحينة',
        'unit': 'برطمان',
        'sale_price': 0,
        'purchase_price': 0,
      });

      expect(product.unitType, ProductUnitType.count);
      expect(product.qty, 0);
      expect(product.reorderLevel, 0);
    });

    test('formatQty keeps integers for count, 3 decimals for weight', () {
      expect(formatQty(10, ProductUnitType.count), '10');
      expect(formatQty(10.0, ProductUnitType.count), '10');
      expect(formatQty(12.5, ProductUnitType.weight), '12.500');
      expect(formatQty(2, ProductUnitType.weight), '2');
    });
  });

  group('ProductDraft', () {
    test('toJson serializes a weight product', () {
      const draft = ProductDraft(
        name: 'بندورة',
        unit: 'كجم',
        unitType: ProductUnitType.weight,
        salePrice: 500,
        purchasePrice: 350,
        qty: 8.125,
        reorderLevel: 2,
      );
      final json = draft.toJson();
      expect(json['unit_type'], 'weight');
      expect(json['sale_price'], 500);
      expect(json['qty'], 8.125);
      expect(json['supplier_id'], isNull);
      expect(json['commission_rate'], isNull);
    });
  });
}