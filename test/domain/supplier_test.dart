import 'package:flutter_test/flutter_test.dart';
import 'package:hasad_erp/domain/suppliers/supplier.dart';
import 'package:hasad_erp/domain/suppliers/supplier_draft.dart';

void main() {
  group('Supplier', () {
    test('fromJson maps all fields with commission deal', () {
      final supplier = Supplier.fromJson({
        'id': '11111111-1111-1111-1111-111111111111',
        'name': 'مؤسسة النور',
        'phone': '0599000000',
        'notes': 'مورد بضاعة أمانة',
        'deal_type': 'commission',
        'commission_rate': 12.5,
        'created_at': '2026-01-01T10:00:00.000Z',
      });

      expect(supplier.name, 'مؤسسة النور');
      expect(supplier.dealType, SupplierDealType.commission);
      expect(supplier.commissionRate, 12.5);
      expect(supplier.createdAt, DateTime.utc(2026, 1, 1, 10));
    });

    test('fromJson defaults to direct when deal_type missing', () {
      final supplier = Supplier.fromJson({
        'id': '11111111-1111-1111-1111-111111111111',
        'name': 'مورد مباشر',
      });

      expect(supplier.dealType, SupplierDealType.direct);
      expect(supplier.commissionRate, isNull);
    });
  });

  group('SupplierDraft', () {
    test('toJson serializes commission supplier', () {
      final draft =
          SupplierDraft(name: 'أ', dealType: SupplierDealType.commission,
              commissionRate: 10);
      expect(draft.toJson()['deal_type'], 'commission');
      expect(draft.toJson()['commission_rate'], 10);
    });

    test('toJson for direct supplier', () {
      final draft = SupplierDraft(name: 'أ', dealType: SupplierDealType.direct);
      expect(draft.toJson()['deal_type'], 'direct');
      expect(draft.toJson()['commission_rate'], isNull);
    });
  });
}