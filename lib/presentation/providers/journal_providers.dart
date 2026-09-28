import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/journal/supabase_journal_repository.dart';
import '../../data/offline/local_store.dart';
import '../../data/offline/offline_journal_repository.dart';
import '../../data/offline/offline_write.dart';
import '../../data/supabase_client.dart';
import '../../domain/journal/journal.dart';
import '../../domain/journal/journal_repository.dart';
import '../../domain/journal/manual_journal_draft.dart';
import 'accounts_providers.dart';
import 'auth_providers.dart';

part 'journal_providers.g.dart';

/// Journal repository — offline-first reads (cache-last per date range) and,
/// when a local store exists, local-first writes routed through
/// [OfflineWriteCoordinator.createJournal]. No local store (web/unauthenticated)
/// means nothing can be queued, so writes fall back to the live RPC rather
/// than pretending they are durable — same shape as the sales/purchases/
/// payments providers.
@riverpod
JournalRepository journalRepository(Ref ref) {
  final store = ref.watch(localStoreProvider).value;
  final tenantId = ref.watch(authStateProvider).value?.tenantId;
  if (store == null || tenantId == null) {
    return SupabaseJournalRepository(ref.watch(supabaseClientProvider));
  }
  return OfflineJournalRepository(
    SupabaseJournalRepository(ref.watch(supabaseClientProvider)),
    store: store,
    tenantId: tenantId,
    coordinator: OfflineWriteCoordinator(
      store,
      tenantId,
      () => ref.read(accountRepositoryProvider).chart(),
    ),
  );
}

/// Current journal date range (first day of the month → today by default).
@riverpod
class JournalRange extends _$JournalRange {
  @override
  ({DateTime from, DateTime to}) build() {
    final now = DateTime.now();
    return (from: DateTime(now.year, now.month, 1), to: now);
  }

  void update({required DateTime from, required DateTime to}) =>
      state = (from: from, to: to);
}

/// Journal entries in the selected range, newest first.
@riverpod
class JournalList extends _$JournalList {
  @override
  Future<List<JournalEntry>> build() async {
    final range = ref.watch(journalRangeProvider);
    return ref
        .watch(journalRepositoryProvider)
        .entries(from: range.from, to: range.to);
  }

  /// Post a manual entry, then reload the list.
  Future<JournalEntryResult> createManual(ManualJournalDraft draft) async {
    final repo = ref.read(journalRepositoryProvider);
    final result = await repo.createManual(draft);
    ref.invalidateSelf();
    return result;
  }
}
