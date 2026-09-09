import '../accounts/account.dart';

/// One account row in the trial balance.
class TrialBalanceRow {
  const TrialBalanceRow({
    required this.accountId,
    required this.code,
    required this.name,
    required this.type,
    required this.debit,
    required this.credit,
    required this.balance,
  });

  final String accountId;
  final String code;
  final String name;
  final AccountType type;
  final int debit;
  final int credit;

  /// Signed net (debit - credit) for this account.
  final int balance;

  factory TrialBalanceRow.fromJson(Map<String, dynamic> json) =>
      TrialBalanceRow(
        accountId: json['account_id'] as String,
        code: json['code'] as String,
        name: json['name'] as String,
        type: AccountType.from(json['type'] as String? ?? 'asset'),
        debit: (json['debit'] as num).toInt(),
        credit: (json['credit'] as num).toInt(),
        balance: (json['balance'] as num).toInt(),
      );
}

/// Trial balance as of a date (`get_trial_balance`).
class TrialBalanceReport {
  const TrialBalanceReport({
    required this.asOf,
    required this.rows,
    required this.totalDebit,
    required this.totalCredit,
  });

  final DateTime asOf;
  final List<TrialBalanceRow> rows;
  final int totalDebit;
  final int totalCredit;

  bool get balanced => totalDebit == totalCredit;

  factory TrialBalanceReport.fromJson(Map<String, dynamic> json) {
    final totals = (json['totals'] as Map<String, dynamic>? ?? const {});
    return TrialBalanceReport(
      asOf: DateTime.parse(json['as_of'] as String),
      rows: [
        for (final r in json['accounts'] as List? ?? const [])
          if (r is Map<String, dynamic>) TrialBalanceRow.fromJson(r),
      ],
      totalDebit: (totals['debit'] as num?)?.toInt() ?? 0,
      totalCredit: (totals['credit'] as num?)?.toInt() ?? 0,
    );
  }
}