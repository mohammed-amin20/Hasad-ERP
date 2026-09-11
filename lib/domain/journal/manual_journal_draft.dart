/// A single [debit] or [credit] leg for a manual journal entry.
class ManualJournalLineDraft {
  const ManualJournalLineDraft({
    required this.accountId,
    this.debit = 0,
    this.credit = 0,
  });

  final String accountId;
  final int debit;
  final int credit;

  Map<String, dynamic> toJson() => {
    'account_id': accountId,
    'debit': debit,
    'credit': credit,
  };
}

/// Input payload for `create_journal_entry` (source_type = manual).
class ManualJournalDraft {
  const ManualJournalDraft({
    required this.date,
    required this.memo,
    required this.lines,
  });

  final DateTime date;
  final String memo;
  final List<ManualJournalLineDraft> lines;

  int get debitTotal => lines.fold(0, (sum, l) => sum + l.debit);

  int get creditTotal => lines.fold(0, (sum, l) => sum + l.credit);

  bool get hasAtLeastTwoLines => lines.length >= 2;

  bool get isBalanced => hasAtLeastTwoLines && debitTotal == creditTotal;

  String get _isoDate =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> toJson({required String requestId}) => {
    'p_request_id': requestId,
    'p_date': _isoDate,
    'p_memo': memo,
    'p_lines': [for (final l in lines) l.toJson()],
  };
}
