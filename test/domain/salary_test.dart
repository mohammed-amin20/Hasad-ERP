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

  group('buildEmployeeStatement', () {
    const emp = '11111111-1111-1111-1111-111111111111';

    test('computes monotonic months with arrears, movements and paid', () {
      final st = buildEmployeeStatement(
        employeeId: emp,
        employeeBase: 200000,
        from: DateTime(2026, 1, 1),
        to: DateTime(2026, 12, 31),
        salaryRows: [
          EmployeeSalaryRow(
            month: DateTime(2026, 9, 1),
            base: 200000,
            paid: 180000,
          ),
          EmployeeSalaryRow(
            month: DateTime(2026, 10, 1),
            base: 200000,
            paid: 200000,
          ),
        ],
        movementRows: [
          EmployeeMovementRow(
            month: DateTime(2026, 9, 1),
            isIn: true,
            amount: 5000,
          ),
          EmployeeMovementRow(
            month: DateTime(2026, 9, 1),
            isIn: false,
            amount: 15000,
          ),
        ],
      );

      expect(st.lines, hasLength(2));
      final sep = st.lines[0];
      expect(sep.month, DateTime(2026, 9));
      expect(sep.arrears, 0);
      expect(sep.entitlements, 5000);
      expect(sep.deductions, 15000);
      expect(sep.netDue, 200000 + 5000 - 15000);
      expect(sep.remaining, 190000 - 180000); // 10000 carried
      final oct = st.lines[1];
      expect(oct.arrears, 20000); // unpaid salary of September
      expect(oct.netDue, 200000 + 20000);
      expect(oct.remaining, 20000);
      expect(st.opening, 0);
      expect(st.closing, 20000);
    });

    test('uses current employee base when a month has no salary row', () {
      final st = buildEmployeeStatement(
        employeeId: emp,
        employeeBase: 150000,
        from: DateTime(2026, 1),
        to: DateTime(2026, 12),
        salaryRows: const [],
        movementRows: [
          EmployeeMovementRow(
            month: DateTime(2026, 4, 1),
            isIn: true,
            amount: 10000,
          ),
        ],
      );

      expect(st.lines, hasLength(1));
      expect(st.lines[0].baseSalary, 150000);
      expect(st.lines[0].netDue, 160000);
      expect(st.closing, 160000);
    });

    test('clips to requested range and skips months without any data', () {
      final st = buildEmployeeStatement(
        employeeId: emp,
        employeeBase: 100000,
        from: DateTime(2026, 10, 1),
        to: DateTime(2026, 11, 30),
        salaryRows: [
          EmployeeSalaryRow(
            month: DateTime(2026, 8, 1),
            base: 100000,
            paid: 80000,
          ),
          EmployeeSalaryRow(
            month: DateTime(2026, 10, 1),
            base: 100000,
            paid: 100000,
          ),
        ],
        movementRows: const [],
      );

      expect(st.opening, 20000); // unpaid August salary
      expect(st.lines, hasLength(1));
      expect(st.lines[0].month, DateTime(2026, 10));
      expect(st.lines[0].arrears, 20000);
      expect(st.closing, 20000);
    });

    test('empty history yields opening as closing', () {
      final st = buildEmployeeStatement(
        employeeId: emp,
        employeeBase: 100000,
        from: DateTime(2026, 1),
        to: DateTime(2026, 12),
        salaryRows: const [],
        movementRows: const [],
      );

      expect(st.lines, isEmpty);
      expect(st.opening, 0);
      expect(st.closing, 0);
    });
  });
}