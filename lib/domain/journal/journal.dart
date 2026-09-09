import '../accounts/account.dart';

/// Where a journal entry came from (`journal_entries.source_type`).
enum JournalSourceType {
  manual,
  automatic;

  static JournalSourceType from(String value) => value == 'manual'
      ? JournalSourceType.manual
      : JournalSourceType.automatic;

  String get label => this == JournalSourceType.manual ? 'يدوي' : 'آلي';
}

/// One money side of a journal entry, joined to its account.
class JournalLine {
  const JournalLine({
    required this.accountCode,
    required this.accountName,
    required this.accountType,
    required this.debit,
    required this.credit,
  });

  final String accountCode;
  final String accountName;
  final AccountType accountType;
  final int debit;
  final int credit;

  /// The one-sided amount of this line (agorot).
  int get amount => debit > 0 ? debit : credit;

  factory JournalLine.fromJson(Map<String, dynamic> json) => JournalLine(
        accountCode: json['account_code'] as String? ?? '',
        accountName: json['account_name'] as String? ?? '',
        accountType:
            AccountType.from(json['account_type'] as String? ?? 'asset'),
        debit: (json['debit'] as num?)?.toInt() ?? 0,
        credit: (json['credit'] as num?)?.toInt() ?? 0,
      );
}

/// A posted journal entry (automatic or manual).
class JournalEntry {
  const JournalEntry({
    required this.id,
    required this.entryNo,
    required this.date,
    required this.memo,
    required this.sourceType,
    required this.total,
    required this.lines,
  });

  final String id;
  final int entryNo;
  final DateTime date;
  final String memo;
  final JournalSourceType sourceType;
  final int total;
  final List<JournalLine> lines;

  factory JournalEntry.fromJson(Map<String, dynamic> json) => JournalEntry(
        id: json['entry_id'] as String,
        entryNo: (json['entry_no'] as num).toInt(),
        date: DateTime.parse(json['date'] as String),
        memo: json['memo'] as String? ?? '',
        sourceType:
            JournalSourceType.from(json['source_type'] as String? ?? ''),
        total: (json['total'] as num?)?.toInt() ?? 0,
        lines: [
          for (final l in (json['lines'] as List?) ?? const [])
            if (l is Map<String, dynamic>) JournalLine.fromJson(l),
        ],
      );
}