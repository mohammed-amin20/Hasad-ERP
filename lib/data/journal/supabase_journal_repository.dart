import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../core/error/app_exception.dart';
import '../../domain/journal/journal.dart';
import '../../domain/journal/journal_repository.dart';
import '../../domain/journal/manual_journal_draft.dart';

/// [JournalRepository] backed by the 0019 journal RPCs.
class SupabaseJournalRepository implements JournalRepository {
  const SupabaseJournalRepository(this._client);

  final SupabaseClient _client;
  static final _uuid = Uuid();

  @override
  Future<List<JournalEntry>> entries({
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final result = await _client.rpc(
        'get_journal_entries',
        params: {'p_from': _isoDate(from), 'p_to': _isoDate(to)},
      );
      final rows = result as List;
      return [
        for (final r in rows)
          if (r is Map<String, dynamic>) JournalEntry.fromJson(r),
      ];
    } on Object catch (error) {
      throw mapErrorToAppException(error);
    }
  }

  @override
  Future<JournalEntryResult> createManual(ManualJournalDraft draft) async {
    try {
      final result = await _client.rpc(
        'create_journal_entry',
        params: draft.toJson(requestId: _uuid.v4()),
      ) as Map<String, dynamic>;
      if (result['duplicate'] == true) {
        return JournalEntryResult.fromJson(
          result['entry'] as Map<String, dynamic>,
        );
      }
      return JournalEntryResult.fromJson(result);
    } on Object catch (error) {
      throw mapErrorToAppException(error);
    }
  }

  static String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
