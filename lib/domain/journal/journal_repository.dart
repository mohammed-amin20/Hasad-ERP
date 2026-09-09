import 'journal.dart';
import 'manual_journal_draft.dart';

/// Result of posting a manual journal entry (or an idempotent replay).
class JournalEntryResult {
  const JournalEntryResult({
    required this.entryId,
    required this.entryNo,
    required this.total,
  });

  final String entryId;
  final int entryNo;
  final int total;

  factory JournalEntryResult.fromJson(Map<String, dynamic> json) =>
      JournalEntryResult(
        entryId: json['entry_id'] as String,
        entryNo: (json['entry_no'] as num).toInt(),
        total: (json['total'] as num?)?.toInt() ?? 0,
      );
}

/// Abstract interface for the journal (M7, migration 0019).
///
/// Concrete implementations live in `data/` — the UI never imports
/// the Supabase client directly.
abstract interface class JournalRepository {
  Future<List<JournalEntry>> entries({
    required DateTime from,
    required DateTime to,
  });

  Future<JournalEntryResult> createManual(ManualJournalDraft draft);
}