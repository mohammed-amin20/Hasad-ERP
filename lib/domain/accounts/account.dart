/// Account kind in the chart of accounts (`accounts.type`).
enum AccountType {
  asset,
  liability,
  equity,
  revenue,
  expense;

  /// Safe parser — unknown values fall back to [AccountType.asset].
  static AccountType from(String value) => switch (value) {
        'liability' => AccountType.liability,
        'equity' => AccountType.equity,
        'revenue' => AccountType.revenue,
        'expense' => AccountType.expense,
        _ => AccountType.asset,
      };

  String get label => switch (this) {
        AccountType.asset => 'أصول',
        AccountType.liability => 'خصوم',
        AccountType.equity => 'حقوق ملكية',
        AccountType.revenue => 'إيرادات',
        AccountType.expense => 'مصاريف',
      };

  String get apiValue => name;
}

/// One account in the tenant's chart of accounts (`get_chart_of_accounts`).
class Account {
  const Account({
    required this.id,
    required this.code,
    required this.name,
    required this.type,
    this.parentId,
    this.parentCode,
    required this.balance,
  });

  final String id;
  final String code;
  final String name;
  final AccountType type;
  final String? parentId;
  final String? parentCode;

  /// Net to-date balance (debit - credit) in agorot.
  final int balance;

  factory Account.fromJson(Map<String, dynamic> json) => Account(
        id: json['account_id'] as String,
        code: json['code'] as String,
        name: json['name'] as String,
        type: AccountType.from(json['type'] as String? ?? 'asset'),
        parentId: json['parent_id'] as String?,
        parentCode: json['parent_code'] as String?,
        balance: (json['balance'] as num?)?.toInt() ?? 0,
      );
}