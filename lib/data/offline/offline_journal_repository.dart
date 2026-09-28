import 'dart:convert';

import '../../core/error/app_exception.dart';
import '../../domain/journal/journal.dart';
import '../../domain/journal/journal_repository.dart';
import '../../domain/journal/manual_journal_draft.dart';
import 'local_database.dart';
import 'local_store.dart';
import 'offline_reads.dart';
import 'offline_write.dart';
import 'report_keys.dart';

/// [JournalRepository] that cache-lasts the journal list per date range and,
/// like [OfflineInvoiceRepository], merges unsynced locally-created MANUAL
/// entries into the served list, so an offline-created entry shows up
/// immediately (and survives restarts) until the drain marks it synced.
///
/// Auto-generated entries that belong to a pending sale/purchase/payment stay
/// owned by those flows and are deliberately NOT merged here.
class OfflineJournalRepository implements JournalRepository {
  OfflineJournalRepository(
    this._inner, {
    required this.store,
    required this.tenantId,
    this.coordinator,
  });

  final JournalRepository _inner;
  final LocalStore? store;
  final String? tenantId;

  /// Local-first write path; when null (no local store — web/unauthenticated)
  /// [createManual] falls through to [_inner]'s live RPC exactly as before.
  final OfflineWriteCoordinator? coordinator;

  @override
  Future<List<JournalEntry>> entries({
    required DateTime from,
    required DateTime to,
  }) async {
    final key = journalKey(from, to);
    final List<JournalEntry> base;
    try {
      base = await cacheLast(
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
    } on NetworkException {
      final drafts = await _localDrafts();
      if (drafts.isNotEmpty) {
        return _merged(const [], drafts, from: from, to: to);
      }
      rethrow;
    }
    final drafts = await _localDrafts();
    return _merged(base, drafts, from: from, to: to);
  }

  @override
  Future<JournalEntryResult> createManual(ManualJournalDraft draft) {
    final c = coordinator;
    if (c != null) return c.createJournal(draft);
    return _inner.createManual(draft);
  }

  /// Unsynced locally-created manual entries (mirror rows with `synced ==
  /// false && sourceType == 'manual'`).
  Future<List<LocalJournalEntryRow>> _localDrafts() async {
    final s = store;
    final t = tenantId;
    if (s == null || t == null) return const [];
    final rows = await s.journalEntries(t);
    return [
      for (final r in rows)
        if (!r.synced && r.sourceType == 'manual') r,
    ];
  }

  Future<List<JournalEntry>> _merged(
    List<JournalEntry> base,
    List<LocalJournalEntryRow> drafts, {
    required DateTime from,
    required DateTime to,
  }) async {
    if (drafts.isEmpty) return base;
    final known = {for (final e in base) e.id};
    final result = <JournalEntry>[...base];
    for (final r in drafts) {
      if (r.date.isBefore(from)) continue;
      if (r.date.isAfter(to)) continue;
      if (known.contains(r.id)) continue;
      result.add(_rowToEntry(r));
      known.add(r.id);
    }
    result.sort((a, b) => b.date.compareTo(a.date));
    return result;
  }

  static JournalEntry _rowToEntry(LocalJournalEntryRow r) {
    final lineMaps = <Map<String, dynamic>>[
      for (final m in jsonDecode(r.lines) as List)
        if (m is Map) m.cast<String, dynamic>(),
    ];
    return JournalEntry(
      id: r.id,
      entryNo: 0,
      date: r.date,
      memo: r.memo,
      sourceType: JournalSourceType.manual,
      total: lineMaps.fold(
        0,
        (sum, l) => sum + ((l['debit'] as num?)?.toInt() ?? 0),
      ),
      lines: [for (final l in lineMaps) JournalLine.fromJson(l)],
    );
  }
}