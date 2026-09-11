/// One revenue or expense row in the income statement.
class IncomeStatementLine {
  const IncomeStatementLine({
    required this.accountId,
    required this.code,
    required this.name,
    required this.amount,
  });

  final String accountId;
  final String code;
  final String name;

  /// Net contribution (revenue: credit - debit, expense: debit - credit).
  final int amount;

  factory IncomeStatementLine.fromJson(Map<String, dynamic> json) =>
      IncomeStatementLine(
        accountId: json['account_id'] as String,
        code: json['code'] as String,
        name: json['name'] as String,
        amount: (json['amount'] as num).toInt(),
      );
}

/// Profit-and-loss between two dates (`get_income_statement`).
class IncomeStatement {
  const IncomeStatement({
    required this.from,
    required this.to,
    required this.revenues,
    required this.expenses,
    required this.revenueTotal,
    required this.expenseTotal,
    required this.net,
  });

  final DateTime from;
  final DateTime to;
  final List<IncomeStatementLine> revenues;
  final List<IncomeStatementLine> expenses;
  final int revenueTotal;
  final int expenseTotal;
  final int net;

  factory IncomeStatement.fromJson(Map<String, dynamic> json) =>
      IncomeStatement(
        from: DateTime.parse(json['from'] as String),
        to: DateTime.parse(json['to'] as String),
        revenues: [
          for (final r in json['revenues'] as List? ?? const [])
            if (r is Map<String, dynamic>) IncomeStatementLine.fromJson(r),
        ],
        expenses: [
          for (final e in json['expenses'] as List? ?? const [])
            if (e is Map<String, dynamic>) IncomeStatementLine.fromJson(e),
        ],
        revenueTotal: (json['revenue_total'] as num).toInt(),
        expenseTotal: (json['expense_total'] as num).toInt(),
        net: (json['net'] as num).toInt(),
      );
}
