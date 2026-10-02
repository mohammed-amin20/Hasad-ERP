/// The one salary-entitlement computation, shared by the offline write
/// coordinator and the offline read path.
///
/// It exists because the two used to implement the same rule separately and
/// drifted: the coordinator counted arrears over earlier months and matched
/// movement direction only on the legacy `'in'` value, while the offline read
/// did the same with a subtly different filter. Two copies of an accounting
/// rule is a defect waiting to happen — a preview that disagrees with the
/// payment it authorizes. Pure Dart with no drift/riverpod/repository imports,
/// so both the `data/` and `presentation/` layers can call it and unit tests
/// can pin it without any fixture.
library;

/// One month of a salary row, as far as the arithmetic is concerned.
class SalaryPeriodRow {
  const SalaryPeriodRow({required this.month, required this.paid});

  /// First day of the month the row belongs to.
  final DateTime month;

  /// What was actually paid for that month.
  final int paid;
}

/// One employee movement, as far as the arithmetic is concerned.
class SalaryMovementInput {
  const SalaryMovementInput({
    required this.month,
    required this.direction,
    required this.amount,
  });

  final DateTime month;

  /// Raw stored direction. Legacy rows carry `'in'` / `'out'`; the domain
  /// vocabulary is `'entitle'` / `'deduct'`. Both spellings are accepted
  /// because the mirror table has existed with both conventions.
  final String direction;

  final int amount;
}

/// The computed entitlement for one employee-month.
class SalaryComputation {
  const SalaryComputation({
    required this.baseSalary,
    required this.arrears,
    required this.entitlements,
    required this.deductions,
    required this.netDue,
  });

  final int baseSalary;
  final int arrears;
  final int entitlements;
  final int deductions;

  /// `baseSalary + arrears + entitlements - deductions`. May be <= 0 when
  /// deductions exceed the base — that is a real state, not an error.
  final int netDue;
}

/// First day of [month], the identity under which months are compared.
DateTime salaryMonthOf(DateTime month) => DateTime(month.year, month.month);

/// The month key as `local_salaries.month` PERSISTS it: `yyyy-MM`.
///
/// This is the local persisted representation, and it is exactly what the
/// offline write guard's duplicate check compares. The paid-state read must call
/// this same function rather than formatting its own: two independently
/// maintained month strings that happen to look identical are a rule that can
/// drift, and drift here is not cosmetic — it means the screen says "paid"
/// while the write guard still accepts a second payout for the month, or the
/// reverse, with neither side able to explain the disagreement.
String salaryMonthKey(DateTime month) {
  final m = salaryMonthOf(month);
  return '${m.year}-${m.month.toString().padLeft(2, '0')}';
}

/// The month as the `salaries.month` DATE column is compared: `yyyy-MM-01`.
///
/// The Postgres column is a date, and `get_employee_entitlement`'s `p_month`
/// already arrives in this form, so the server-side paid-state query has to use
/// it as well. Deliberately a separate function from [salaryMonthKey] instead of
/// one helper with a flag: the two representations really are different, and
/// naming that difference is what stops someone "unifying" them into one
/// function that then silently fails to match one of the two stores.
String salaryMonthDate(DateTime month) => '${salaryMonthKey(month)}-01';

/// True when [direction] adds to the entitlement.
///
/// The mirror has persisted `'in'` and the domain vocabulary is `'entitle'`;
/// both are honored, and anything unrecognised is treated as a **deduction** so
/// an unknown value can never silently inflate a payroll.
bool isEntitlementDirection(String direction) =>
    direction == 'in' || direction == 'entitle';

/// Unpaid amount carried into [target] from every earlier month.
///
/// Mirrors `0010`'s `max(base - paid, 0)` per earlier month: a month that was
/// over-paid contributes nothing (never a negative offset), a month with no
/// salary row contributes nothing either — arrears are only owed for months
/// that actually had a payment recorded against them.
int computeArrears({
  required DateTime target,
  required int baseSalary,
  required Iterable<SalaryPeriodRow> salaryRows,
}) {
  final targetMonth = salaryMonthOf(target);
  var total = 0;
  for (final row in salaryRows) {
    final month = salaryMonthOf(row.month);
    if (!month.isBefore(targetMonth)) continue;
    final diff = baseSalary - row.paid;
    if (diff > 0) total += diff;
  }
  return total;
}

/// Computes the full entitlement for one employee-month.
///
/// [salaryRows] and [movements] may contain any month; only the target's own
/// movements and the earlier months' salary rows are read, so a caller can pass
/// an employee's whole history without pre-filtering.
SalaryComputation computeSalaryComputation({
  required DateTime month,
  required int baseSalary,
  required Iterable<SalaryPeriodRow> salaryRows,
  required Iterable<SalaryMovementInput> movements,
}) {
  final targetMonth = salaryMonthOf(month);
  final arrears = computeArrears(
    target: targetMonth,
    baseSalary: baseSalary,
    salaryRows: salaryRows,
  );

  var entitlements = 0;
  var deductions = 0;
  for (final mv in movements) {
    if (salaryMonthOf(mv.month) != targetMonth) continue;
    if (isEntitlementDirection(mv.direction)) {
      entitlements += mv.amount;
    } else {
      deductions += mv.amount;
    }
  }

  return SalaryComputation(
    baseSalary: baseSalary,
    arrears: arrears,
    entitlements: entitlements,
    deductions: deductions,
    netDue: baseSalary + arrears + entitlements - deductions,
  );
}
