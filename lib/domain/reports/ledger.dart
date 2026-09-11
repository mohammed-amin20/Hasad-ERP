import '../accounts/account.dart';

/// One movement line in an account ledger.
class LedgerLine {
  const LedgerLine({
    required this.date,
    required this.entryNo,
    required this.memo,
    required this.debit,
    required this.credit,
    required this.balance,
  });

  final DateTime date;
  final int entryNo;
  final String memo;
  final int debit;
  final int credit;

  /// Signed running balance (debit - credit) after this line.
  final int balance;

  factory LedgerLine.fromJson(Map<String, dynamic> json) => LedgerLine(
    date: DateTime.parse(json['date'] as String),
    entryNo: (json['entry_no'] as num).toInt(),
    memo: json['memo'] as String? ?? '',
    debit: (json['debit'] as num).toInt(),
    credit: (json['credit'] as num).toInt(),
    balance: (json['balance'] as num).toInt(),
  );
}

/// Full ledger extract for one account (`get_ledger`).
class LedgerStatement {
  const LedgerStatement({
    required this.accountId,
    required this.code,
    required this.name,
    required this.type,
    required this.from,
    required this.to,
    required this.opening,
    required this.lines,
    required this.closing,
  });

  final String accountId;
  final String code;
  final String name;
  final AccountType type;
  final DateTime from;
  final DateTime to;

  /// Signed sample (debit - credit) before [from].
  final int opening;
  final List<LedgerLine> lines;

  /// Signed net (debit - credit) up to [to].
  final int closing;

  int get totalDebit => lines.fold(0, (sum, l) => sum + l.debit);

  int get totalCredit => lines.fold(0, (sum, l) => sum + l.credit);

  factory LedgerStatement.fromJson(Map<String, dynamic> json) =>
      LedgerStatement(
        accountId: json['account_id'] as String,
        code: json['code'] as String,
        name: json['name'] as String,
        type: AccountType.from(json['type'] as String? ?? 'asset'),
        from: DateTime.parse(json['from'] as String),
        to: DateTime.parse(json['to'] as String),
        opening: (json['opening'] as num).toInt(),
        lines: [
          for (final l in json['lines'] as List? ?? const [])
            if (l is Map<String, dynamic>) LedgerLine.fromJson(l),
        ],
        closing: (json['closing'] as num).toInt(),
      );
}
