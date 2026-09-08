import 'package:uuid/uuid.dart';

String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// First day of the month, as used by every salary RPC.
DateTime firstOfMonth(DateTime d) => DateTime(d.year, d.month, 1);

/// Result of `get_employee_entitlement(employee_id, month)`.
class EmployeeEntitlement {
  const EmployeeEntitlement({
    required this.employeeId,
    required this.month,
    required this.baseSalary,
    required this.arrears,
    required this.entitlements,
    required this.deductions,
    required this.netDue,
  });

  final String employeeId;
  final DateTime month;
  final int baseSalary;
  final int arrears;
  final int entitlements;
  final int deductions;
  final int netDue;

  factory EmployeeEntitlement.fromJson(Map<String, dynamic> json) =>
      EmployeeEntitlement(
        employeeId: json['employee_id'] as String,
        month: DateTime.parse(json['month'] as String),
        baseSalary: (json['base_salary'] as num?)?.toInt() ?? 0,
        arrears: (json['arrears'] as num?)?.toInt() ?? 0,
        entitlements: (json['entitlements'] as num?)?.toInt() ?? 0,
        deductions: (json['deductions'] as num?)?.toInt() ?? 0,
        netDue: (json['net_due'] as num?)?.toInt() ?? 0,
      );
}

/// One employee movement via the `add_employee_movement` RPC.
class MovementDraft {
  const MovementDraft({
    required this.employeeId,
    required this.month,
    required this.direction,
    required this.category,
    this.amount,
    this.description,
    this.productId,
    this.qty,
    this.date,
  });

  final String employeeId;

  /// Month the movement is linked to (must be first of month).
  final DateTime month;

  /// `in` (bonus/allowance) or `out` (advance/product/other).
  final String direction;

  /// `bonus` | `allowance` | `advance` | `product` | `other`.
  final String category;

  /// Cash value in agorot — required for every category except `product`
  /// (the RPC computes product value as qty × cost price).
  final int? amount;
  final String? description;
  final String? productId;
  final double? qty;
  final DateTime? date;

  Map<String, dynamic> toJson({String? requestId}) => {
        'p_request_id': requestId ?? const Uuid().v4(),
        'p_employee_id': employeeId,
        'p_month': _isoDate(month),
        'p_direction': direction,
        'p_category': category,
        if (amount != null) 'p_amount': amount,
        if (description != null && description!.trim().isNotEmpty)
          'p_description': description,
        if (productId != null) 'p_product_id': productId,
        if (qty != null) 'p_qty': qty,
        if (date != null) 'p_date': _isoDate(date!),
      };
}

/// Result of `add_employee_movement` (idempotent duplicates replay the row).
class MovementResult {
  const MovementResult({
    this.duplicate = false,
    this.movementId,
    this.amount = 0,
  });

  final bool duplicate;
  final String? movementId;
  final int amount;

  factory MovementResult.fromJson(Map<String, dynamic> json) {
    final duplicate = json['duplicate'] == true;
    final payload =
        duplicate ? (json['movement'] as Map?) ?? const {} : json;
    return MovementResult(
      duplicate: duplicate,
      movementId: payload['movement_id'] as String?,
      amount: (payload['amount'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Actual cash paid to an employee via the `pay_salary` RPC.
class SalaryDraft {
  const SalaryDraft({
    required this.employeeId,
    required this.month,
    required this.paid,
    required this.method,
    this.date,
    this.note,
  });

  final String employeeId;
  final DateTime month;
  final int paid;
  final String method;
  final DateTime? date;
  final String? note;

  Map<String, dynamic> toJson({String? requestId}) => {
        'p_request_id': requestId ?? const Uuid().v4(),
        'p_employee_id': employeeId,
        'p_month': _isoDate(month),
        'p_paid': paid,
        'p_method': method,
        if (date != null) 'p_date': _isoDate(date!),
        if (note != null && note!.trim().isNotEmpty) 'p_note': note,
      };
}

/// Result of `pay_salary` (idempotent duplicates replay the row).
class SalaryResult {
  const SalaryResult({
    this.duplicate = false,
    this.salaryId,
    this.month,
    this.baseSalary = 0,
    this.arrears = 0,
    this.entitlements = 0,
    this.deductions = 0,
    this.netDue = 0,
    this.paid = 0,
    this.arrearsCarried = 0,
    this.entryNo = 0,
  });

  final bool duplicate;
  final String? salaryId;
  final DateTime? month;
  final int baseSalary;
  final int arrears;
  final int entitlements;
  final int deductions;
  final int netDue;
  final int paid;
  final int arrearsCarried;
  final int entryNo;

  factory SalaryResult.fromJson(Map<String, dynamic> json) {
    final duplicate = json['duplicate'] == true;
    final payload = duplicate ? (json['salary'] as Map?) ?? const {} : json;
    return SalaryResult(
      duplicate: duplicate,
      salaryId: payload['salary_id'] as String?,
      month: payload['month'] != null
          ? DateTime.parse(payload['month'] as String)
          : null,
      baseSalary: (payload['base_salary'] as num?)?.toInt() ?? 0,
      arrears: (payload['arrears'] as num?)?.toInt() ?? 0,
      entitlements: (payload['entitlements'] as num?)?.toInt() ?? 0,
      deductions: (payload['deductions'] as num?)?.toInt() ?? 0,
      netDue: (payload['net_due'] as num?)?.toInt() ?? 0,
      paid: (payload['paid'] as num?)?.toInt() ?? 0,
      arrearsCarried: (payload['arrears_carried'] as num?)?.toInt() ?? 0,
      entryNo: (payload['entry_no'] as num?)?.toInt() ?? 0,
    );
  }
}

/// A single paid-salary row read from the `salaries` table.
class SalaryRecord {
  const SalaryRecord({
    required this.employeeId,
    required this.month,
    required this.baseSalary,
    required this.paid,
    this.date,
  });

  final String employeeId;
  final DateTime month;
  final int baseSalary;
  final int paid;
  final DateTime? date;

  factory SalaryRecord.fromJson(Map<String, dynamic> json) => SalaryRecord(
        employeeId: json['employee_id'] as String,
        month: DateTime.parse(json['month'] as String),
        baseSalary: (json['base_salary'] as num?)?.toInt() ?? 0,
        paid: (json['paid'] as num?)?.toInt() ?? 0,
        date: json['date'] != null
            ? DateTime.parse(json['date'] as String)
            : null,
      );
}

/// One month's salary computation shown in an employee statement.
class EmployeeMonthLine {
  const EmployeeMonthLine({
    required this.month,
    required this.baseSalary,
    required this.arrears,
    required this.entitlements,
    required this.deductions,
    required this.netDue,
    required this.paid,
    required this.remaining,
  });

  final DateTime month;
  final int baseSalary;

  /// Unpaid salary from earlier months per the RPC rule
  /// (`max(base - paid, 0)` per previous month).
  final int arrears;
  final int entitlements;
  final int deductions;
  final int netDue;
  final int paid;

  /// What actually stayed unpaid after this month (`netDue - paid`).
  final int remaining;
}

/// Request for a per-month employee salary statement over [from]..[to].
class EmployeeStatementRequest {
  const EmployeeStatementRequest({
    required this.employeeId,
    required this.from,
    required this.to,
  });

  final String employeeId;
  final DateTime from;
  final DateTime to;
}

/// Client-side aggregate of salary/movement history for one employee.
class EmployeeStatement {
  const EmployeeStatement({
    required this.employeeId,
    required this.monthFrom,
    required this.monthTo,
    required this.opening,
    required this.lines,
    required this.closing,
  });

  final String employeeId;
  final DateTime monthFrom;
  final DateTime monthTo;
  final int opening;
  final List<EmployeeMonthLine> lines;
  final int closing;
}

/// One row of `employee_movements` as used by statement building.
class EmployeeMovementRow {
  const EmployeeMovementRow({
    required this.month,
    required this.isIn,
    required this.amount,
  });

  final DateTime month;
  final bool isIn;
  final int amount;
}

/// One row of `salaries` as used by statement building.
class EmployeeSalaryRow {
  const EmployeeSalaryRow({
    required this.month,
    required this.base,
    required this.paid,
  });

  final DateTime month;
  final int base;
  final int paid;
}

/// Builds a per-month statement from raw read-only rows.
///
/// Mirrors the `get_salary_entitlement` RPC (migration 0010): arrears for a
/// month equal the sum over earlier months of `max(base - paid, 0)`; months
/// with neither a salary nor a movement record are skipped entirely.
EmployeeStatement buildEmployeeStatement({
  required String employeeId,
  required int employeeBase,
  required DateTime from,
  required DateTime to,
  required List<EmployeeSalaryRow> salaryRows,
  required List<EmployeeMovementRow> movementRows,
}) {
  final months = <DateTime>{};
  final salaryByMonth = <DateTime, EmployeeSalaryRow>{};
  final inByMonth = <DateTime, int>{};
  final outByMonth = <DateTime, int>{};

  for (final row in salaryRows) {
    final month = firstOfMonth(row.month);
    months.add(month);
    salaryByMonth[month] = row;
  }
  for (final row in movementRows) {
    final month = firstOfMonth(row.month);
    months.add(month);
    if (row.isIn) {
      inByMonth[month] = (inByMonth[month] ?? 0) + row.amount;
    } else {
      outByMonth[month] = (outByMonth[month] ?? 0) + row.amount;
    }
  }

  final monthFrom = firstOfMonth(from);
  final monthTo = firstOfMonth(to);
  final sorted = months.toList()..sort();

  int arrearsAt(DateTime month) {
    var total = 0;
    for (final m in sorted) {
      if (m.isAfter(month)) break;
      if (m.isBefore(month)) {
        final s = salaryByMonth[m];
        final diff = (s?.base ?? employeeBase) - (s?.paid ?? 0);
        if (diff > 0) total += diff;
      }
    }
    return total;
  }

  final opening = arrearsAt(monthFrom);

  final lines = <EmployeeMonthLine>[
    for (final m in sorted)
      if (m.compareTo(monthFrom) >= 0 && m.compareTo(monthTo) <= 0)
        () {
          final s = salaryByMonth[m];
          final base = s?.base ?? employeeBase;
          final paid = s?.paid ?? 0;
          final entitlements = inByMonth[m] ?? 0;
          final deductions = outByMonth[m] ?? 0;
          final netDue = base + arrearsAt(m) + entitlements - deductions;
          final remaining = (netDue - paid) < 0 ? 0 : netDue - paid;
          return EmployeeMonthLine(
            month: m,
            baseSalary: base,
            arrears: arrearsAt(m),
            entitlements: entitlements,
            deductions: deductions,
            netDue: netDue,
            paid: paid,
            remaining: remaining,
          );
        }(),
  ];

  return EmployeeStatement(
    employeeId: employeeId,
    monthFrom: monthFrom,
    monthTo: monthTo,
    opening: opening,
    lines: lines,
    closing: lines.isEmpty ? opening : lines.last.remaining,
  );
}

/// Writes salary movements/payments (only RPCs — the tables are SELECT-only).
abstract interface class SalaryRepository {
  Future<EmployeeEntitlement> entitlement({
    required String employeeId,
    required DateTime month,
  });
  Future<MovementResult> addMovement(MovementDraft draft);
  Future<SalaryResult> pay(SalaryDraft draft);

  /// All paid-salary rows for the tenant (read-only), newest first.
  Future<List<SalaryRecord>> salaryHistory();

  /// Per-month salary statement computed client-side from the read-only
  /// `salaries` + `employee_movements` tables (no statement RPC exists).
  Future<EmployeeStatement> employeeStatement(EmployeeStatementRequest request);
}