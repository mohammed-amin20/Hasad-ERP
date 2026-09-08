import 'package:flutter_test/flutter_test.dart';
import 'package:hasad_erp/domain/salaries/salary_repository.dart';

void main() {
  group('EmployeeEntitlement', () {
    test('fromJson maps all fields', () {
      final ent = EmployeeEntitlement.fromJson({
        'employee_id': '11111111-1111-1111-1111-111111111111',
        'month': '2026-09-01',
        'base_salary': 200000,
        'arrears': 0,
        'entitlements': 5000,
        'deductions': 15000,
        'net_due': 190000,
      });

      expect(ent.baseSalary, 200000);
      expect(ent.entitlements, 5000);
      expect(ent.deductions, 15000);
      expect(ent.netDue, 190000);
      expect(ent.month, DateTime(2026, 9, 1));
    });

    test('fromJson tolerates missing numeric fields', () {
      final ent = EmployeeEntitlement.fromJson({
        'employee_id': '11111111-1111-1111-1111-111111111111',
        'month': '2026-09-01',
      });

      expect(ent.baseSalary, 0);
      expect(ent.netDue, 0);
    });
  });

  group('MovementDraft', () {
    test('toJson serializes a cash advance', () {
      final draft = MovementDraft(
        employeeId: '11111111-1111-1111-1111-111111111111',
        month: DateTime(2026, 9, 1),
        direction: 'out',
        category: 'advance',
        amount: 50000,
        description: 'سلفة',
      );

      final json = draft.toJson(requestId: 'r1');
      expect(json['p_request_id'], 'r1');
      expect(json['p_employee_id'], '11111111-1111-1111-1111-111111111111');
      expect(json['p_month'], '2026-09-01');
      expect(json['p_direction'], 'out');
      expect(json['p_category'], 'advance');
      expect(json['p_amount'], 50000);
    });

    test('toJson serializes a product deduction without amount', () {
      final draft = MovementDraft(
        employeeId: '11111111-1111-1111-1111-111111111111',
        month: DateTime(2026, 9, 1),
        direction: 'out',
        category: 'product',
        productId: '22222222-2222-2222-2222-222222222222',
        qty: 2,
      );

      final json = draft.toJson();
      expect(json['p_product_id'], '22222222-2222-2222-2222-222222222222');
      expect(json['p_qty'], 2);
      expect(json.containsKey('p_amount'), isFalse);
    });
  });

  group('MovementResult', () {
    test('fromJson maps fresh result', () {
      final r = MovementResult.fromJson({
        'movement_id': 'm1',
        'amount': 120000,
      });

      expect(r.duplicate, isFalse);
      expect(r.movementId, 'm1');
      expect(r.amount, 120000);
    });

    test('fromJson unwraps duplicate payload', () {
      final r = MovementResult.fromJson({
        'duplicate': true,
        'movement': {'movement_id': 'm1', 'amount': 5000},
      });

      expect(r.duplicate, isTrue);
      expect(r.movementId, 'm1');
      expect(r.amount, 5000);
    });
  });

  group('SalaryDraft', () {
    test('toJson serializes a payment', () {
      final draft = SalaryDraft(
        employeeId: '11111111-1111-1111-1111-111111111111',
        month: DateTime(2026, 9, 1),
        paid: 190000,
        method: 'bank',
        date: DateTime(2026, 9, 30),
        note: 'راتب شهر 9',
      );

      final json = draft.toJson(requestId: 'r2');
      expect(json['p_request_id'], 'r2');
      expect(json['p_paid'], 190000);
      expect(json['p_method'], 'bank');
      expect(json['p_date'], '2026-09-30');
      expect(json['p_note'], 'راتب شهر 9');
    });
  });

  group('SalaryResult', () {
    test('fromJson maps a fresh payment with carried arrears', () {
      final r = SalaryResult.fromJson({
        'salary_id': 's1',
        'month': '2026-09-01',
        'base_salary': 200000,
        'arrears': 10000,
        'entitlements': 0,
        'deductions': 0,
        'net_due': 210000,
        'paid': 200000,
        'arrears_carried': 10000,
        'entry_no': 42,
      });

      expect(r.duplicate, isFalse);
      expect(r.paid, 200000);
      expect(r.arrearsCarried, 10000);
      expect(r.entryNo, 42);
      expect(r.month, DateTime(2026, 9, 1));
    });

    test('fromJson unwraps duplicate payload', () {
      final r = SalaryResult.fromJson({
        'duplicate': true,
        'salary': {'salary_id': 's1', 'paid': 200000},
      });

      expect(r.duplicate, isTrue);
      expect(r.salaryId, 's1');
      expect(r.paid, 200000);
    });
  });

  group('SalaryRecord', () {
    test('fromJson maps paid salary row', () {
      final r = SalaryRecord.fromJson({
        'employee_id': '11111111-1111-1111-1111-111111111111',
        'month': '2026-09-01',
        'base_salary': 200000,
        'paid': 200000,
        'date': '2026-09-30',
      });

      expect(r.employeeId, '11111111-1111-1111-1111-111111111111');
      expect(r.paid, 200000);
      expect(r.date, DateTime(2026, 9, 30));
    });
  });
}