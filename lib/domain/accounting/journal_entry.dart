import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

/// Represents a single line in a journal entry (debit or credit)
class JournalLine extends Equatable {
  const JournalLine({
    required this.accountId,
    required this.accountCode,
    required this.accountName,
    required this.debit,
    required this.credit,
    this.description,
  });

  final String accountId;
  final String accountCode;
  final String accountName;
  final int debit; // Agorot
  final int credit; // Agorot
  final String? description;

  bool get isDebit => debit > 0;
  bool get isCredit => credit > 0;
  int get amount => debit > 0 ? debit : credit;

  @override
  List<Object?> get props => [
    accountId,
    accountCode,
    accountName,
    debit,
    credit,
    description,
  ];

  Map<String, dynamic> toJson() => {
    'account_id': accountId,
    'account_code': accountCode,
    'account_name': accountName,
    'debit': debit,
    'credit': credit,
    'description': description,
  };

  factory JournalLine.fromJson(Map<String, dynamic> json) => JournalLine(
    accountId: json['account_id'] as String,
    accountCode: json['account_code'] as String,
    accountName: json['account_name'] as String,
    debit: json['debit'] as int,
    credit: json['credit'] as int,
    description: json['description'] as String?,
  );
}

/// A complete journal entry with multiple lines
class JournalEntry extends Equatable {
  const JournalEntry({
    required this.id,
    required this.date,
    required this.memo,
    required this.lines,
    this.sourceType = 'manual',
    this.sourceId,
    this.createdAt,
  });

  final String id;
  final DateTime date;
  final String memo;
  final List<JournalLine> lines;
  final String
  sourceType; // 'manual', 'sale', 'purchase', 'payment', 'salary', 'inventory'
  final String?
  sourceId; // Reference to source document (invoice_id, payment_id, etc.)
  final DateTime? createdAt;

  int get totalDebit => lines.fold(0, (sum, l) => sum + l.debit);
  int get totalCredit => lines.fold(0, (sum, l) => sum + l.credit);
  bool get isBalanced => totalDebit == totalCredit;
  int get imbalance => totalDebit - totalCredit;

  @override
  List<Object?> get props => [
    id,
    date,
    memo,
    lines,
    sourceType,
    sourceId,
    createdAt,
  ];

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String().split('T').first,
    'memo': memo,
    'lines': lines.map((l) => l.toJson()).toList(),
    'source_type': sourceType,
    'source_id': sourceId,
    'created_at': createdAt?.toIso8601String(),
  };

  factory JournalEntry.fromJson(Map<String, dynamic> json) => JournalEntry(
    id: json['id'] as String,
    date: DateTime.parse(json['date'] as String),
    memo: json['memo'] as String,
    lines: (json['lines'] as List).map((l) => JournalLine.fromJson(l)).toList(),
    sourceType: json['source_type'] as String? ?? 'manual',
    sourceId: json['source_id'] as String?,
    createdAt: json['created_at'] != null
        ? DateTime.parse(json['created_at'] as String)
        : null,
  );

  static JournalEntry create({
    required DateTime date,
    required String memo,
    required List<JournalLine> lines,
    String sourceType = 'manual',
    String? sourceId,
  }) {
    return JournalEntry(
      id: const Uuid().v4(),
      date: date,
      memo: memo,
      lines: lines,
      sourceType: sourceType,
      sourceId: sourceId,
      createdAt: DateTime.now(),
    );
  }
}

/// Exception thrown when journal entry is not balanced
class UnbalancedEntryException implements Exception {
  UnbalancedEntryException(this.entry, this.message);
  final JournalEntry entry;
  final String message;

  @override
  String toString() =>
      'UnbalancedEntryException: $message (debit: ${entry.totalDebit}, credit: ${entry.totalCredit})';
}
