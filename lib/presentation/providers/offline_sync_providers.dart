import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/connectivity_providers.dart';
import '../../../data/offline/local_store.dart';
import '../../../data/offline/offline_sync.dart';
import '../../../data/offline/supabase_sync_target.dart';
import '../../../data/supabase_client.dart' as data;
import 'offline_providers.dart' as offline;

/// Current signed-in tenant id (falls back to empty string so the flusher
/// providers stay constructible before auth resolves).
final Provider<String> currentTenantIdProvider = Provider<String>(
  (ref) => ref.watch(offline.currentTenantIdProvider) ?? '',
);

/// Async count of legs still queued for the current tenant. Recomputed on
/// demand and refreshed via [ref.invalidate] by the explicit flush/reconnect/
/// manual triggers (no self-polling timer, so widget tests stay settleable).
final FutureProvider<int> pendingSyncCountProvider = FutureProvider<int>(
  (ref) async {
    final flusher = await ref.watch(syncFlusherProvider.future);
    return flusher.pendingCount();
  },
);

/// The tenant's queue flusher, bound to the Supabase-backed [SyncTarget].
final FutureProvider<SyncFlusher> syncFlusherProvider =
    FutureProvider<SyncFlusher>((ref) async {
  final tenantId = ref.watch(currentTenantIdProvider);
  final store = await ref.watch(localStoreProvider.future);
  final client = ref.watch(data.supabaseClientProvider);
  final target = SupabaseSyncTarget(client);
  return SyncFlusher(store, tenantId, target);
});

/// One-shot manual flush trigger: reads it to start a pass (returns the
/// [SyncFlushSummary]). Also refreshes the pending count so the badge tracks
/// the resulting state immediately.
final FutureProvider<SyncFlushSummary> manualSyncNowProvider =
    FutureProvider<SyncFlushSummary>((ref) async {
  await Future<void>.delayed(Duration.zero);
  final flusher = await ref.watch(syncFlusherProvider.future);
  final summary = await flusher.flush();
  ref.invalidate(pendingSyncCountProvider);
  return summary;
});

/// Auto-sync-on-reconnect runner bound to the tenant's [SyncFlusher]. Kick it
/// from the offline→online edge ([AutoSyncRunner.kick]); while the queue keeps
/// draining it paces follow-up passes with the [kSyncBackoffSeconds] ladder.
/// Single-flight: a kick while one is running is ignored, and the loop stops
/// once the queue drains or connectivity drops.
final Provider<AutoSyncRunner> autoSyncRunnerProvider =
    Provider<AutoSyncRunner>((ref) {
  return AutoSyncRunner(
    flush: () async {
      final flusher = await ref.read(syncFlusherProvider.future);
      final summary = await flusher.flush();
      ref.invalidate(pendingSyncCountProvider);
      return summary;
    },
    pendingCount: () async {
      final flusher = await ref.read(syncFlusherProvider.future);
      return flusher.pendingCount();
    },
    isOnline: () => ref.read(verifiedOnlineProvider).value ?? false,
  );
});
