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
}