import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/connectivity_providers.dart';
import '../../../data/offline/local_store.dart';
import '../../../data/offline/offline_sync.dart';
import '../../../data/offline/supabase_sync_target.dart';
import '../../../data/supabase_client.dart' as data;
import '../../../domain/invoices/invoice_sync.dart';
import 'dashboard_providers.dart';
import 'inventory_providers.dart';
import 'journal_providers.dart';
import 'offline_providers.dart' as offline;
import 'products_providers.dart';
import 'purchases_providers.dart';
import 'report_providers.dart';
import 'salaries_providers.dart';
import 'sales_providers.dart';
import 'statements_providers.dart';

/// Refreshes every read that a completed drain invalidates: the pending count,
/// the per-row sync badge, the two invoice lists, the money views that a
/// drained payment (or settlement) changes, the product/inventory views
/// that a drained purchase receipt (with new stock) changes, and the
/// journal/accounting views that any drained journal write changes.
///
/// The list refresh is the reason a row stops showing the *local* placeholder
/// number: once the mirror row is `synced` it drops out of
/// `OfflineInvoiceRepository._localDrafts()`, so the refetch is what replaces it
/// with the official server copy. Without this the badge would say "synced" next
/// to a number the server never issued. The debt totals are included because a
/// payment reduces what a customer owes and a settlement what we owe a supplier;
/// they are top-level (non-family) providers, so a plain invalidate is safe.
/// The product and inventory lists follow because a drained purchase receipt
/// changed stock and may have created a product. The journal list and the
/// accounting reports (ledger, trial balance, income statement, balance sheet)
/// and the dashboard KPI envelope are all journal-derived, so a drained manual
/// journal entry refreshes them; party statements are deliberately NOT here
/// (a manual journal is not linked to a party). The salary history list is top
/// level (non-family) and a drained salary payment marks its row synced, so it
/// is invalidated too; the per-employee `salaryRun`/`employeeStatement`
/// families cannot be drain-invalidated without keys and are instead refreshed
/// by [SalaryActions] on each write.
///
/// This is a refresh trigger only — it changes no business logic, and the
/// `SaleInvoicesList`/`PurchaseInvoicesList`/debt/product/journal/report
/// notifiers keep owning how they load.
void _refreshAfterDrain(Ref ref) {
  ref.invalidate(pendingSyncCountProvider);
  ref.invalidate(invoiceSyncStatesProvider);
  ref.invalidate(saleInvoicesListProvider);
  ref.invalidate(purchaseInvoicesListProvider);
  ref.invalidate(customerDebtsProvider);
  ref.invalidate(supplierDebtsProvider);
  ref.invalidate(productsListProvider);
  ref.invalidate(inventoryProductsProvider);
  ref.invalidate(journalListProvider);
  ref.invalidate(ledgerStatementProvider);
  ref.invalidate(trialBalanceProvider);
  ref.invalidate(incomeStatementProvider);
  ref.invalidate(balanceSheetProvider);
  ref.invalidate(dashboardSummaryProvider);
  ref.invalidate(salaryHistoryProvider);
}

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

/// Per-invoice sync state for the invoice lists, keyed by the **local** invoice
/// id (the `sync_queue.localId` of the leg), read live from the queue.
///
/// A synced invoice gets no badge at all, so an invoice missing from the map is
/// treated as [InvoiceSyncState.synced]. That also makes the join correct after
/// a drain for free: the list refetches from the server under a *different* id,
/// so nothing matches and the row reads as synced.
///
/// Ordering note: a spread overwrite means the newest leg for a local id wins,
/// which is the right precedence if a retry re-enqueues one.
final FutureProvider<Map<String, InvoiceSyncState>> invoiceSyncStatesProvider =
    FutureProvider<Map<String, InvoiceSyncState>>((ref) async {
      final tenantId = ref.watch(currentTenantIdProvider);
      if (tenantId.isEmpty) return const <String, InvoiceSyncState>{};
      try {
        final store = await ref.watch(localStoreProvider.future);
        final legs = await store.queueLegsFor(tenantId, entity: 'invoices');
        return {
          for (final leg in legs)
            if (leg.localId != null)
              leg.localId!: InvoiceSyncState.fromQueueStatus(leg.status),
        };
      } catch (_) {
        // A sync *indicator* must never be able to take down the list it
        // annotates, and an uncaught provider error surfaces in its own zone
        // where a widget test cannot drain it. Degrade to "no badges".
        return const <String, InvoiceSyncState>{};
      }
    });

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
/// [SyncFlushSummary]). Also refreshes everything a completed drain
/// invalidates (see [_refreshAfterDrain]) so the badge tracks the resulting
/// state immediately.
final FutureProvider<SyncFlushSummary> manualSyncNowProvider =
    FutureProvider<SyncFlushSummary>((ref) async {
  await Future<void>.delayed(Duration.zero);
  final flusher = await ref.watch(syncFlusherProvider.future);
  final summary = await flusher.flush();
  _refreshAfterDrain(ref);
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
      _refreshAfterDrain(ref);
      return summary;
    },
    pendingCount: () async {
      final flusher = await ref.read(syncFlusherProvider.future);
      return flusher.pendingCount();
    },
    isOnline: () => ref.read(verifiedOnlineProvider).value ?? false,
  );
});
