import 'package:flutter_test/flutter_test.dart';
import 'package:hasad_erp/domain/customers/customer.dart';
import 'package:hasad_erp/domain/customers/customer_draft.dart';

void main() {
  group('Customer', () {
    test('fromJson maps all fields', () {
      final customer = Customer.fromJson({
        'id': '11111111-1111-1111-1111-111111111111',
        'name': 'محمد أحمد',
        'phone': '0599000000',
        'notes': 'عميل دائم',
        'created_at': '2026-01-01T10:00:00.000Z',
      });

      expect(customer.id, '11111111-1111-1111-1111-111111111111');
      expect(customer.name, 'محمد أحمد');
      expect(customer.phone, '0599000000');
      expect(customer.notes, 'عميل دائم');
      expect(customer.createdAt, DateTime.utc(2026, 1, 1, 10));
    });

    test('fromJson handles nullable fields', () {
      final customer = Customer.fromJson({
        'id': '11111111-1111-1111-1111-111111111111',
        'name': 'عميل',
      });

      expect(customer.phone, isNull);
      expect(customer.notes, isNull);
      expect(customer.createdAt, isNull);
    });

    test('toJson omits null optional fields', () {
      final customer = Customer(
        id: '11111111-1111-1111-1111-111111111111',
        name: 'عميل',
      );

      final json = customer.toJson();
      expect(json['name'], 'عميل');
      expect(json.containsKey('phone'), isFalse);
      expect(json.containsKey('notes'), isFalse);
    });
  });

  group('CustomerDraft', () {
    test('toJson includes provided fields', () {
      const draft = CustomerDraft(name: 'عميل', phone: '0555', notes: 'x');
      final json = draft.toJson();
      expect(json['name'], 'عميل');
      expect(json['phone'], '0555');
      expect(json['notes'], 'x');
    });
  });
}