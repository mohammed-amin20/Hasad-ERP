/// One asset / liability / equity row in the balance sheet.
class BalanceSheetAccount {
  const BalanceSheetAccount({
    required this.accountId,
    required this.code,
    required this.name,
    required this.amount,
  });

  final String accountId;
  final String code;
  final String name;

  /// Signed balance (assets: debit - credit, liabilities/equity: credit - debit).
  final int amount;

  factory BalanceSheetAccount.fromJson(Map<String, dynamic> json) =>
      BalanceSheetAccount(
        accountId: json['account_id'] as String,
        code: json['code'] as String,
        name: json['name'] as String,
        amount: (json['amount'] as num).toInt(),
      );
}

/// Balance sheet as of a date (`get_balance_sheet`).
class BalanceSheet {
  const BalanceSheet({
    required this.asOf,
    required this.assets,
    required this.liabilities,
    required this.equity,
    required this.assetsTotal,
    required this.liabilitiesTotal,
    required this.equityTotal,
    required this.netIncomeYtd,
    required this.check,
  });

  final DateTime asOf;
  final List<BalanceSheetAccount> assets;
  final List<BalanceSheetAccount> liabilities;
  final List<BalanceSheetAccount> equity;
  final int assetsTotal;
  final int liabilitiesTotal;

  /// Includes a period net income line, so assets = liabilities + equity.
  final int equityTotal;
  final int netIncomeYtd;

  /// `assets_total - liabilities_total - equity_total`; 0 = the sheet balances.
  final int check;

  bool get balanced => check == 0;

  factory BalanceSheet.fromJson(Map<String, dynamic> json) => BalanceSheet(
        asOf: DateTime.parse(json['as_of'] as String),
        assets: [
          for (final r in json['assets'] as List? ?? const [])
            if (r is Map<String, dynamic>)
              BalanceSheetAccount.fromJson(r),
        ],
        liabilities: [
          for (final r in json['liabilities'] as List? ?? const [])
            if (r is Map<String, dynamic>)
              BalanceSheetAccount.fromJson(r),
        ],
        equity: [
          for (final r in json['equity'] as List? ?? const [])
            if (r is Map<String, dynamic>) BalanceSheetAccount.fromJson(r),
        ],
        assetsTotal: (json['assets_total'] as num).toInt(),
        liabilitiesTotal: (json['liabilities_total'] as num).toInt(),
        equityTotal: (json['equity_total'] as num).toInt(),
        netIncomeYtd: (json['net_income_ytd'] as num).toInt(),
        check: (json['check'] as num).toInt(),
      );
}