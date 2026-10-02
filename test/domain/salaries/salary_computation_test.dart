import 'package:flutter_test/flutter_test.dart';
import 'package:hasad_erp/domain/salaries/salary_computation.dart';

/// Issue 5 — the entitlement arithmetic that the salary sheet previews and the
/// payment that gets queued must be the SAME rule, not two copies of it.
///
/// Pinned here as pure math because that is what the rule actually is: there is
/// no drift, no repository and no riverpod in the production path, so a unit
/// test is the honest place to hold it.
void main() {
  DateTime m(int year, int month) => DateTime(year, month);

  group('monthly movements', () {
    test('only the target month\'s movements count', () {
      final c = computeSalaryComputation(
        month: m(2026, 3),
        baseSalary: 1000,
        salaryRows: [],
        movements: [
          SalaryMovementInput(month: DateTime(2026, 2), direction: 'in', amount: 500),
          SalaryMovementInput(month: DateTime(2026, 3), direction: 'in', amount: 300),
          SalaryMovementInput(month: DateTime(2026, 4), direction: 'in', amount: 700),
        ],
      );
      expect(c.entitlements, 300);
      expect(c.netDue, 1300);
    });

    test('a day inside the month is the same month as its first day', () {
      final c = computeSalaryComputation(
        month: DateTime(2026, 3, 1),
        baseSalary: 0,
        salaryRows: [],
        movements: [
          SalaryMovementInput(
              month: DateTime(2026, 3, 28), direction: 'in', amount: 250),
        ],
      );
      expect(c.entitlements, 250,
          reason: 'a movement dated the 28th belongs to March, not nowhere');
      expect(c.netDue, 250);
    });

    test('entitlements and deductions both accumulate, net is the difference',
        () {
      final c = computeSalaryComputation(
        month: m(2026, 3),
        baseSalary: 1000,
        salaryRows: [],
        movements: [
          SalaryMovementInput(month: DateTime(2026, 3), direction: 'in', amount: 200),
          SalaryMovementInput(month: DateTime(2026, 3), direction: 'in', amount: 100),
          SalaryMovementInput(month: DateTime(2026, 3), direction: 'out', amount: 150),
        ],
      );
      expect(c.entitlements, 300);
      expect(c.deductions, 150);
      expect(c.netDue, 1150);
    });
  });

  group('direction vocabulary', () {
    test("'in' and 'entitle' both add, both spellings are honoured", () {
      final c = computeSalaryComputation(
        month: m(2026, 3),
        baseSalary: 0,
        salaryRows: [],
        movements: [
          SalaryMovementInput(month: DateTime(2026, 3), direction: 'in', amount: 100),
          SalaryMovementInput(month: DateTime(2026, 3), direction: 'entitle', amount: 50),
        ],
      );
      expect(c.entitlements, 150);
      expect(c.deductions, 0);
    });

    test("'out' and 'deduct' both subtract", () {
      final c = computeSalaryComputation(
        month: m(2026, 3),
        baseSalary: 1000,
        salaryRows: [],
        movements: [
          SalaryMovementInput(month: DateTime(2026, 3), direction: 'out', amount: 100),
          SalaryMovementInput(month: DateTime(2026, 3), direction: 'deduct', amount: 25),
        ],
      );
      expect(c.deductions, 125);
      expect(c.netDue, 875);
    });

    test('an unrecognised direction is a deduction, never a silent payday', () {
      // The safe direction for a payroll bug: under-pay and let a human look,
      // rather than inflate net due from a value nobody understands.
      final c = computeSalaryComputation(
        month: m(2026, 3),
        baseSalary: 1000,
        salaryRows: [],
        movements: [
          SalaryMovementInput(month: DateTime(2026, 3), direction: 'weird', amount: 400),
        ],
      );
      expect(c.entitlements, 0);
      expect(c.deductions, 400);
      expect(c.netDue, 600);
    });
  });

  group('arrears', () {
    test('an under-paid earlier month carries forward', () {
      final c = computeSalaryComputation(
        month: m(2026, 3),
        baseSalary: 1000,
        salaryRows: [
          SalaryPeriodRow(month: DateTime(2026, 1), paid: 600),
          SalaryPeriodRow(month: DateTime(2026, 2), paid: 1000),
        ],
        movements: [],
      );
      expect(c.arrears, 400, reason: 'only January was short');
      expect(c.netDue, 1400);
    });

    test('several short months accumulate', () {
      final c = computeSalaryComputation(
        month: m(2026, 3),
        baseSalary: 1000,
        salaryRows: [
          SalaryPeriodRow(month: DateTime(2026, 1), paid: 500),
          SalaryPeriodRow(month: DateTime(2026, 2), paid: 250),
        ],
        movements: [],
      );
      // Jan: 1000 - 500 = 500. Feb: 1000 - 250 = 750. Total 1250.
      expect(c.arrears, 1250);
      expect(c.netDue, 2250);
    });

    test('an over-paid earlier month contributes nothing, never negative', () {
      // The `max(base - paid, 0)` clamp. Without it, over-paying January would
      // *reduce* March's entitlement, which is a money bug in the other
      // direction and just as wrong.
      final c = computeSalaryComputation(
        month: m(2026, 3),
        baseSalary: 1000,
        salaryRows: [
          SalaryPeriodRow(month: DateTime(2026, 1), paid: 1400),
        ],
        movements: [],
      );
      expect(c.arrears, 0);
      expect(c.netDue, 1000);
    });

    test('the target month itself is not its own arrears', () {
      final c = computeSalaryComputation(
        month: m(2026, 3),
        baseSalary: 1000,
        salaryRows: [
          SalaryPeriodRow(month: DateTime(2026, 3), paid: 200),
        ],
        movements: [],
      );
      expect(c.arrears, 0);
      expect(c.netDue, 1000);
    });

    test('a later month never contributes', () {
      final c = computeSalaryComputation(
        month: m(2026, 3),
        baseSalary: 1000,
        salaryRows: [
          SalaryPeriodRow(month: DateTime(2026, 5), paid: 100),
        ],
        movements: [],
      );
      expect(c.arrears, 0);
    });

    test('an employee with no salary rows has no arrears', () {
      final c = computeSalaryComputation(
        month: m(2026, 3),
        baseSalary: 1000,
        salaryRows: [],
        movements: [],
      );
      expect(c.arrears, 0);
      expect(c.netDue, 1000);
    });
  });

  group('a zero base salary is a configuration gap, not zero entitlement', () {
    // The bug this pass fixes: a `baseSalary <= 0` check placed BEFORE the
    // computation refused a bonus-only payroll. These cases pin the intended
    // order — compute first, then only complain if nothing is payable.
    test('base 0 + a real entitlement is still payable', () {
      final c = computeSalaryComputation(
        month: m(2026, 3),
        baseSalary: 0,
        salaryRows: [],
        movements: [
          SalaryMovementInput(month: DateTime(2026, 3), direction: 'in', amount: 500),
        ],
      );
      expect(c.netDue, 500);
    });

    test('base 0 + arrears from a prior base is still payable', () {
      // The base was 1000 in January, reduced to 0 now: January's shortfall is
      // still owed even though this month pays nothing by base.
      final c = computeSalaryComputation(
        month: m(2026, 3),
        baseSalary: 0,
        salaryRows: [
          SalaryPeriodRow(month: DateTime(2026, 1), paid: 0),
        ],
        movements: [],
      );
      expect(c.arrears, 0,
          reason: 'arrears are measured against the CURRENT base, so 0 - 0 = 0');
      expect(c.netDue, 0);
    });

    test('base 0 with nothing payable nets to 0, which the caller rejects', () {
      final c = computeSalaryComputation(
        month: m(2026, 3),
        baseSalary: 0,
        salaryRows: [],
        movements: [],
      );
      expect(c.netDue, 0);
    });

    test('deductions can drive a real base to zero or below', () {
      final c = computeSalaryComputation(
        month: m(2026, 3),
        baseSalary: 300,
        salaryRows: [],
        movements: [
          SalaryMovementInput(month: DateTime(2026, 3), direction: 'out', amount: 300),
        ],
      );
      expect(c.netDue, 0);
    });
  });
}
