import 'dart:convert';

import '../../domain/journal/journal.dart';
import '../../domain/journal/journal_repository.dart';
import '../../domain/journal/manual_journal_draft.dart';
import 'local_store.dart';
import 'offline_reads.dart';
import 'report_keys.dart';

/// [JournalRepository] that cache-lasts the journal list per date range.
class OfflineJournalRepository implements JournalRepository {
  OfflineJournalRepository(this._inner, {required this.store, required this.tenantId});

  final JournalRepository _inner;
  final LocalStore? store;
  final String? tenantId;

  @override
  Future<List<JournalEntry>> entries({
    required DateTime from,
    required DateTime to,
  }) {
    final key = journalKey(from, to);
    return cacheLast(
      store: store,
      tenantId: tenantId,
      key: key,
      network: () => _inner.entries(from: from, to: to),
      fromCached: (payload) => [
        for (final m in jsonDecode(payload) as List)
          if (m is Map) JournalEntry.fromJson(m.cast<String, dynamic>()),
      ],
      toPayload: (entries) => jsonEncode([
        for (final e in entries)
          {
            'entry_id': e.id,
            'entry_no': e.entryNo,
            'date': cacheDate(e.date),
            'memo': e.memo,
            'source_type': e.sourceType.name,
            'total': e.total,
            'lines': [
              for (final l in e.lines)
                {
                  'account_code': l.accountCode,
                  'account_name': l.accountName,
                  'account_type': l.accountType.name,
                  'debit': l.debit,
                  'credit': l.credit,
                },
            ],
          },
      ]),
    );
  }

  @override
  Future<JournalEntryResult> createManual(ManualJournalDraft draft) =>
      _inner.createManual(draft);
}