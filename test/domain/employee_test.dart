import 'package:flutter_test/flutter_test.dart';
import 'package:hasad_erp/domain/employees/employee.dart';
import 'package:hasad_erp/domain/employees/employee_draft.dart';

void main() {
  group('Employee', () {
    test('fromJson maps all fields', () {
      final employee = Employee.fromJson({
        'id': '11111111-1111-1111-1111-111111111111',
        'name': 'أحمد',
        'job_title': 'محاسب',
        'phone': '0599000000',
        'base_salary': 200000,
        'created_at': '2026-01-01T10:00:00.000Z',
      });

      expect(employee.name, 'أحمد');
      expect(employee.jobTitle, 'محاسب');
      expect(employee.phone, '0599000000');
      expect(employee.baseSalary, 200000);
      expect(employee.createdAt, DateTime.utc(2026, 1, 1, 10));
    });

    test('fromJson defaults optional fields', () {
      final employee = Employee.fromJson({
        'id': '11111111-1111-1111-1111-111111111111',
        'name': 'خالد',
      });

      expect(employee.jobTitle, isNull);
      expect(employee.phone, isNull);
      expect(employee.baseSalary, 0);
      expect(employee.createdAt, isNull);
    });
  });

  group('EmployeeDraft', () {
    test('toJson serializes all fields', () {
      final draft = EmployeeDraft(
        name: 'أحمد',
        jobTitle: 'محاسب',
        phone: '0599000000',
        baseSalary: 200000,
      );

      expect(draft.toJson()['name'], 'أحمد');
      expect(draft.toJson()['job_title'], 'محاسب');
      expect(draft.toJson()['phone'], '0599000000');
      expect(draft.toJson()['base_salary'], 200000);
    });

    test('toJson omits empty optional fields as null', () {
      final draft = EmployeeDraft(name: 'أ', baseSalary: 0);

      expect(draft.toJson()['job_title'], isNull);
      expect(draft.toJson()['phone'], isNull);
    });
  });
}