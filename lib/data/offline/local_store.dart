import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'local_database.dart';
import 'offline_factory.dart';

/// A cached report envelope plus when it was stored (freshness indicator).
class CachedReportData {
  const CachedReportData({required this.payload, required this.fetchedAt});

  final String payload;
  final DateTime fetchedAt;
}

/// What a [LocalStore.clearTenant] call did, and what it nearly did.
///
/// `atRisk` is the number of locally-authored rows (queued writes plus
/// `synced: false` mirror rows) that the clear would have destroyed. A caller
/// that gets `cleared == false` must surface that count and re-call with
/// `force: true` only after the user explicitly confirms the loss.
class ClearTenantReport {
  const ClearTenantReport({
    required this.cleared,
    required this.pendingQueueItems,
    required this.unsyncedMirrorRows,
  });

  /// False means the wipe was REFUSED because [atRisk] work was pending.
  const ClearTenantReport.refused({
    required this.pendingQueueItems,
    required this.unsyncedMirrorRows,
  }) : cleared = false;

  /// True when the tenant's rows were actually deleted.
  final bool cleared;

  /// Queued writes (`pending`/`staged`) that the clear would remove.
  final int pendingQueueItems;

  /// Mirror rows still marked `synced: false` that the clear would remove.
  final int unsyncedMirrorRows;

  /// Total local work that a clear would destroy.
  int get atRisk => pendingQueueItems + unsyncedMirrorRows;
}

/// Thrown when the local database cannot be opened or migrated.
///
/// The app gate (`localStoreProvider`) treats this as a fatal-store state and
/// renders the Arabic repair UI (retry + destructive reset) instead of quietly
/// degrading to `NullLocalStore` — that silent degradation is the "kill the
/// app offline, reopen, and every cached screen is empty" cold-start collapse.
class LocalStoreOpenException implements Exception {
  const LocalStoreOpenException(this.debugInfo);

  /// Human-readable reason (directory tried, underlying error, stack) shown in
  /// the repair screen's detail line.
  final String debugInfo;

  @override
  String toString() => 'LocalStoreOpenException: $debugInfo';
}

/// Repository over the offline sqlite store. The UI never touches this
/// directly - offline-first wrappers in `data/` decide the source.
abstract class LocalStore {
  bool get isAvailable;

  AppDatabase get db;

  // ---- master data -------------------------------------------------

  Future<List<LocalCustomerRow>> customers(String tenantId);
  Future<void> mirrorCustomers(String tenantId, List<LocalCustomerRow> rows);
  Future<void> upsertCustomer(LocalCustomerRow row);

  Future<List<LocalSupplierRow>> suppliers(String tenantId);
  Future<void> mirrorSuppliers(String tenantId, List<LocalSupplierRow> rows);
  Future<void> upsertSupplier(LocalSupplierRow row);

  Future<List<LocalProductRow>> products(String tenantId);
  Future<void> mirrorProducts(String tenantId, List<LocalProductRow> rows);
  Future<void> upsertProduct(LocalProductRow row);

  Future<List<LocalEmployeeRow>> employees(String tenantId);
  Future<void> mirrorEmployees(String tenantId, List<LocalEmployeeRow> rows);
  Future<void> upsertEmployee(LocalEmployeeRow row);

  Future<List<LocalAccountRow>> accounts(String tenantId);
  Future<void> mirrorAccounts(String tenantId, List<LocalAccountRow> rows);
  Future<void> upsertAccount(LocalAccountRow row);

  /// Ensures [tenantId] has a usable chart of accounts when the device has never
  /// seen one. If the mirror is already non-empty, this is a no-op (it never
  /// clobbers real data). Otherwise it copies the 14 embedded default accounts
  /// into [LocalAccounts] so a fresh device can create a sale invoice offline.
  /// Returns the resulting chart (possibly empty on a null/no-op store).
  Future<List<LocalAccountRow>> ensureBaselineChart(String tenantId);

  // ---- financial ----------------------------------------------------

  /// The durable line-item id for one position of one invoice: the invoice id,
  /// a colon, then a 4-digit zero-padded ordinal.
  ///
  /// Shared by [mirrorInvoiceItems] and the offline create paths
  /// (`writeSale` / `writePurchase`) so the two can never disagree — a mirror
  /// that re-minted ids differently from the writer would leave the writer's rows
  /// to be deleted and rewritten on every refresh.
  ///
  /// Three properties this shape is chosen for, each one pinned by a test:
  ///
  ///  * **Positional, so `ORDER BY id` IS the invoice's order.** The detail
  ///    sheet iterates the list as given, and the server query has no `ORDER BY`,
  ///    so the order has to be recorded somewhere. The zero padding is not
  ///    cosmetic: unpadded, `'x:10' < 'x:2'` lexicographically, and it only
  ///    becomes visible at 10+ lines.
  ///  * **Idempotent, so a repeated refresh replaces rather than appends.** The
  ///    same list always produces the same keys.
  ///  * **Not product-keyed.** An invoice may legitimately carry the same product
  ///    twice with a different qty/price, and a product-keyed id would collapse
  ///    those two lines into one.
  static String invoiceLineId(String invoiceId, int index) =>
      '$invoiceId:${index.toString().padLeft(4, '0')}';

  Future<List<LocalInvoiceRow>> invoices(String tenantId, {String? type});
  Future<void> upsertInvoice(LocalInvoiceRow row);
  Future<void> deleteInvoice(String tenantId, String id);

  /// One invoice header by id, or null when this device holds no such row.
  ///
  /// Added for P1.E: the detail read has to know whether an invoice is a local
  /// draft before it decides which source to trust, and the only alternative was
  /// pulling the tenant's entire invoice list to find one row. Tenant-scoped, so
  /// a cross-tenant probe cannot even learn that the id exists.
  Future<LocalInvoiceRow?> invoice(String tenantId, String id);

  /// Mirrors server-owned invoice headers so the local write path can resolve
  /// them (issue 3).
  ///
  /// Deliberately narrower than the master mirrors, which delete-and-replace
  /// per tenant: an invoice list read is FILTERED (search / date range), so a
  /// tenant-wide clear would discard every invoice outside the filter window
  /// the user happens to be looking at. This one never deletes. An incoming row
  /// replaces the same-id server-owned row, and a row carrying local work is
  /// left exactly as it is — see [DriftLocalStore.mirrorInvoices] for which
  /// rows count as local work and why a stale server copy must not land.
  Future<void> mirrorInvoices(String tenantId, List<LocalInvoiceRow> rows);

  /// Clears [LocalInvoices.pendingMoneyLeg] on every row still stamped with
  /// [legId], unconditionally — and only those.
  ///
  /// The raw primitive. Prefer [resolveInvoiceMoneyMarker] from the flusher:
  /// clearing on leg-id equality alone is NOT sufficient, because the marker
  /// only ever names the newest leg, so an older leg that is still queued would
  /// be forgotten. Retained for direct-store tests and for any caller that has
  /// already proven no other money leg is outstanding. Rows with a null marker
  /// never match.
  Future<void> clearInvoiceMoneyMarker(String tenantId, String legId);

  /// Retires [legId] as a money marker.
  ///
  /// Re-evaluates every invoice the leg restated — the union of the rows it
  /// currently stamps and the set recorded in
  /// [SyncQueueItem.affectsInvoiceIds] — and for each one:
  ///
  ///  * if another money leg of [tenantId] that affects the invoice has not
  ///    reached `synced` (still `pending`/retrying, or parked `failed`), the
  ///    marker is re-stamped to the oldest such leg;
  ///  * otherwise it is cleared, returning the row to server authority.
  ///
  /// Attribution comes from the durable column, with a pre-v7
  /// `p_invoice_id` params fallback — never from the settlement's allocation,
  /// which the server decides at replay time. Fully tenant-scoped: an invoice
  /// and a leg are both matched on `tenant_id` as well as id, so one workspace
  /// can never decide another's marker.
  Future<void> resolveInvoiceMoneyMarker(String tenantId, String legId);

  /// Line items of one invoice, in the order the detail sheet must paint them.
  ///
  /// Tenant-SCOPED, and the tenant is not optional: P1.E made this table the
  /// durable copy of a server invoice's lines, and a read keyed on `invoiceId`
  /// alone returns another workspace's rows for the same invoice id. The
  /// ordering is `id` ASC, which is why the mirror mints positional ids
  /// (`<invoiceId>:<0000-padded ordinal>`) — see [mirrorInvoiceItems].
  Future<List<LocalInvoiceItemRow>> invoiceItems(
    String tenantId,
    String invoiceId,
  );

  /// Whether any durable `local_invoice_items` row of [tenantId] references
  /// [productId]. Used by the product delete rule to mirror the server's FK
  /// (`invoice_items.product_id` is NOT NULL, NO ACTION): deleting a product
  /// that a mirrored invoice still references would be refused by the server,
  /// so it is refused locally first with an Arabic validation message.
  ///
  /// Tenant-scoped — a foreign workspace's lines can never block a delete here.
  /// The answer is only as complete as the mirrored data: an invoice this
  /// device has never opened is invisible, and a server-side reject is then
  /// handled by the existing failed-delete path (row stays visible, retried).
  Future<bool> invoiceItemsReferenceProduct(
    String tenantId,
    String productId,
  );

  Future<void> upsertInvoiceItems(List<LocalInvoiceItemRow> rows);

  /// Replaces one invoice's mirrored line set wholesale (P1.E).
  ///
  /// ## Why replace-all and not `upsertInvoiceItems`
  ///
  /// Two reasons, both load-bearing:
  ///
  ///  * **Stale rows.** The ids are positional, so a refresh to FEWER lines
  ///    leaves an orphan at every ordinal past the new length. An
  ///    insert-or-replace cannot express "this invoice now has three lines".
  ///  * **A refresh may legitimately empty the set.** A server invoice whose
  ///    last line was deleted reads back as `[]`; treating that as "no change"
  ///    would leave the deleted line on the device forever.
  ///
  /// Both halves run in ONE transaction, and a plain (non-replacing) insert is
  /// used after the tenant-scoped delete, so a same-id row belonging to another
  /// workspace can never be touched — the primary key is `{tenantId, id}` since
  /// schema 8, and the delete is scoped anyway so the two agree.
  ///
  /// Rows carrying local work are excluded: an invoice whose header is
  /// `synced == false` is a local draft the server has never seen, so its lines
  /// are the only copy that exists. See [DriftLocalStore.mirrorInvoiceItems].
  Future<void> mirrorInvoiceItems(
    String tenantId,
    String invoiceId,
    List<LocalInvoiceItemRow> rows,
  );

  Future<void> upsertPayment(LocalPaymentRow row);
  Future<List<LocalPaymentRow>> payments(String tenantId);

  Future<List<LocalCommissionDueRow>> commissionDues(
    String tenantId, {
    String? supplierId,
  });
  Future<void> upsertCommissionDue(LocalCommissionDueRow row);

  Future<void> insertJournalEntry(LocalJournalEntryRow row);
  Future<List<LocalJournalEntryRow>> journalEntries(String tenantId);

  Future<List<LocalEmployeeMovementRow>> employeeMovements(
    String tenantId, {
    String? employeeId,
  });
  Future<void> upsertEmployeeMovement(LocalEmployeeMovementRow row);

  Future<List<LocalSalaryRow>> salaries(String tenantId, {String? employeeId});
  Future<void> upsertSalary(LocalSalaryRow row);

  // ---- sync -----------------------------------------------------------

  Future<void> enqueue(SyncQueueRow row);
  Future<List<SyncQueueRow>> pendingSync(String tenantId);
  Future<int> pendingCount(String tenantId);

  /// Ids of the master rows for [entity] whose delete has been written locally
  /// but has not reached the server yet: the ids of `table_crud` legs that are
  /// still `'pending'` and carry a delete-shape `params` (`{'id': …}` with no
  /// `row`).
  ///
  /// A repository must hide these rows from reads so a deleted record cannot
  /// keep showing (or be resurrected by a background refresh that predates the
  /// delete) before the flusher drains it. When the delete eventually parks
  /// `failed`, the id drops out of this set and the row becomes visible again —
  /// “still available locally” while the delete is retryable.
  Future<Set<String>> pendingDeleteIds(String tenantId, String entity);

  /// Physically removes the mirrored master rows [ids] of [entity] for
  /// [tenantId]. Called by the flusher once a `table_crud` delete leg has been
  /// acknowledged server-side, so the local mirror stops showing a record the
  /// server no longer has. Unknown ids / entities are no-ops.
  Future<void> removeMirrorRows(
    String tenantId,
    String entity,
    List<String> ids,
  );

  /// Which of [invoiceIds] already have at least one durable
  /// `local_invoice_items` row for [tenantId].
  ///
  /// One bulk `GROUP BY` query, never one query per invoice: the list-time
  /// detail prefetch uses it to ask "which of these do I actually still need
  /// from the network?", so an offline list refresh of a workspace whose lines
  /// are already durable issues **zero** detail requests instead of one failing
  /// batch per refresh.
  ///
  /// This is a *durable availability* check, not a completeness check. A
  /// server invoice that genuinely has zero lines has no line row, so it can
  /// never appear in the result and will be re-asked for on every list read
  /// until it does. That is accepted deliberately — see
  /// `OfflineInvoiceRepository._prefetchDetails`. Do not "fix" it by adding
  /// completeness metadata, a marker row or a schema migration: an empty answer
  /// must stay distinguishable from an unknown one.
  ///
  /// Tenant-scoped, so a foreign workspace's lines can never mark an id as
  /// durable. Ids with no rows (and an empty [invoiceIds]) simply do not appear.
  ///
  /// ## Ids are accepted in EITHER space, and answered in the caller's
  ///
  /// [invoiceIds] may be server ids, local ids, or a mix: a replayed invoice is
  /// stored under its local uuid and served under the server's, so the list-time
  /// prefetch passes the server id while the rows it is comparing against are
  /// keyed by the local one. Comparing those directly never matches, which looks
  /// identical to "these lines were never fetched" and re-requests them on every
  /// refresh forever. Implementations MUST therefore resolve the mapping, and
  /// MUST return only ids that were passed in — in the form they were passed.
  ///
  /// Resolving this inside the store rather than at the call site is what keeps
  /// it one bounded lookup: a per-id `localIdFor` probe would be N extra queries.
  Future<Set<String>> invoiceIdsWithDurableItems(
    String tenantId,
    List<String> invoiceIds,
  );

  /// Status of every queued leg for [tenantId], keyed by leg id — including
  /// `failed` legs, which [pendingSync] omits. Used by the flusher to resolve
  /// `dependsOn` prerequisites without re-querying per leg.
  Future<Map<String, String>> queueStatuses(String tenantId);

  /// Every queued leg for [tenantId], oldest first, optionally narrowed to a
  /// single `entity` (e.g. `'invoices'`).
  ///
  /// Unlike [pendingSync] this includes `synced` and `failed` legs, which is
  /// what a sync indicator needs: a finished leg is *marked* synced, never
  /// deleted, so the history is still there to read.
  Future<List<SyncQueueRow>> queueLegsFor(String tenantId, {String? entity});

  /// Ids of the legs that [SyncQueueItem.dependsOn] names, parsed from its JSON
  /// array. Returns an empty list for a null/empty/malformed value so a corrupt
  /// column can never crash a flush.
  static List<String> parseDependencies(String? dependsOnJson) {
    if (dependsOnJson == null || dependsOnJson.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(dependsOnJson);
      if (decoded is! List) return const [];
      return [
        for (final v in decoded)
          if (v is String && v.isNotEmpty) v,
      ];
    } on FormatException {
      return const [];
    }
  }

  /// Ids of the invoice rows whose money figures [SyncQueueItem.affectsInvoiceIds]
  /// records this leg as restating, parsed from its JSON array. Returns an empty
  /// list for a null/empty/malformed value.
  ///
  /// Malformed JSON degrades to "no recorded attribution" rather than throwing,
  /// mirroring [parseDependencies]: a corrupt column must not be able to crash a
  /// flush. That degradation is deliberately NOT silently treated as "this leg
  /// affects nothing" by the caller — see [_legInvoiceIds] for why.
  static List<String> parseInvoiceAttribution(String? json) {
    if (json == null || json.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(json);
      if (decoded is! List) return const [];
      return [
        for (final v in decoded)
          if (v is String && v.isNotEmpty) v,
      ];
    } on FormatException {
      return const [];
    }
  }

  /// Every invoice id a money leg restates locally, from its durable attribution
  /// first and its RPC params only as a legacy fallback.
  ///
  /// The fallback exists for pre-v7 legs, whose column is NULL. It is exact for
  /// `record_payment` (`p_invoice_id` is the RPC's own target argument) and
  /// empty for `settle_supplier` — and that is the correct, non-invented answer:
  /// a settlement's invoice set is decided by the SERVER at replay time, so for
  /// a leg queued before the attribution column existed there is no local
  /// evidence of what it touched and none is fabricated. The residual is narrow
  /// and self-healing (it applies only to settlements already queued at upgrade
  /// time, and disappears once they drain).
  static Set<String> _legInvoiceIds(SyncQueueRow leg) {
    final recorded = parseInvoiceAttribution(leg.affectsInvoiceIds);
    if (recorded.isNotEmpty) return recorded.toSet();
    return {for (final id in parseLegacyTargetInvoice(leg.params)) id};
  }

  /// The pre-v7 attribution: the `p_invoice_id` a money leg's params name.
  ///
  /// Kept only as a fallback for legs written before `affects_invoice_ids`
  /// existed. A `settle_supplier` leg names no invoices — the server picks what
  /// to allocate — so it returns nothing and is correctly attributed to no
  /// invoice rather than to a guessed one.
  static Set<String> parseLegacyTargetInvoice(String paramsJson) {
    if (paramsJson.trim().isEmpty) return const {};
    try {
      final decoded = jsonDecode(paramsJson);
      if (decoded is! Map) return const {};
      final id = decoded['p_invoice_id'];
      return id is String && id.isNotEmpty ? {id} : const {};
    } on FormatException {
      return const {};
    }
  }

  /// Ids of the product rows whose stock figures
  /// [SyncQueueItem.affectsProductIds] records this leg as restating, parsed from
  /// its JSON array. Returns an empty list for a null/empty/malformed value.
  ///
  /// Degrades to "no recorded attribution" rather than throwing, mirroring
  /// [parseInvoiceAttribution]: a corrupt column must not be able to crash a
  /// stock refresh. The caller falls back to the narrow `params` shapes in
  /// [affectedProductIdsOf].
  static List<String> parseProductAttribution(String? json) {
    if (json == null || json.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(json);
      if (decoded is! List) return const [];
      return [
        for (final v in decoded)
          if (v is String && v.isNotEmpty) v,
      ];
    } on FormatException {
      return const [];
    }
  }

  /// Every product id a stock-affecting leg restates locally, from its durable
  /// attribution first and its RPC/stored-row shape only as a legacy fallback.
  ///
  /// The fallback exists for pre-v9 legs, whose column is NULL. It is exact for
  /// the three leg shapes that touched product stock before the column existed —
  /// see [_legacyProductIds] — and empty otherwise. It never fabricates
  /// attribution: a legacy purchase `new_product` row whose `product_id` cannot
  /// be derived is attributed to no product rather than to a guessed one.
  static Set<String> affectedProductIdsOf(SyncQueueRow leg) {
    final recorded = parseProductAttribution(leg.affectsProductIds);
    if (recorded.isNotEmpty) return recorded.toSet();
    return _legacyProductIds(leg.rpc, leg.op, leg.localId, leg.params);
  }

  /// The pre-v9 product attribution derived from a leg's wire shape.
  ///
  /// Exactly three shapes can be recovered, and only these:
  ///
  ///  * `create_sale_invoice` / `create_purchase_invoice` — every
  ///    `p_items[*].product_id`. New-product items carry their generated
  ///    `product_id`, so an offline-created product is covered too.
  ///  * `add_employee_movement` — `p_product_id`, but only when present; a
  ///    cash-only movement deducts no stock and has no product.
  ///  * a `table:products` `table_crud` leg whose stored row contains `qty` —
  ///    a product CREATE (or a pre-DECISION-2 EDIT that still carried qty).
  ///    An EDIT whose replay payload omits `qty` is correctly not a stock leg.
  ///
  /// Anything else returns empty. No generic recursive scanner: a nested
  /// `product_id` in an unrelated field would be a plausible-looking but wrong
  /// attribution, and a wrong attribution freezes a product's local quantity.
  static Set<String> _legacyProductIds(
    String rpc,
    String op,
    String? localId,
    String paramsJson,
  ) {
    if (paramsJson.trim().isEmpty) return const {};
    try {
      final decoded = jsonDecode(paramsJson);
      if (decoded is! Map) return const {};

      if (op == 'table_crud') {
        if (rpc == 'table:products' && decoded.containsKey('qty')) {
          final id = decoded['id'] ?? localId;
          return id is String && id.isNotEmpty ? {id} : const {};
        }
        return const {};
      }

      switch (rpc) {
        case 'create_sale_invoice':
        case 'create_purchase_invoice':
          final items = decoded['p_items'];
          if (items is! List) return const {};
          return {
            for (final it in items)
              if (it is Map &&
                  it['product_id'] is String &&
                  (it['product_id'] as String).isNotEmpty)
                it['product_id'] as String,
          };
        case 'add_employee_movement':
          final id = decoded['p_product_id'];
          return id is String && id.isNotEmpty ? {id} : const {};
        default:
          return const {};
      }
    } on FormatException {
      return const {};
    }
  }

  /// Runs [action] inside ONE database transaction, handing it a store bound to
  /// that transaction. Every write inside [action] therefore commits together
  /// or rolls back together — this is what makes a multi-table offline write
  /// (invoice + lines + journal + stock + queue) atomic rather than a sequence
  /// of independent commits that a crash could interleave.
  ///
  /// Implementations with no real database still run [action] against `this`
  /// so the business logic is identical; only the rollback guarantee is absent.
  Future<T> transaction<T>(Future<T> Function(LocalStore store) action);

  Future<void> markSynced(String id);
  Future<void> markFailed(String id, String error);

  /// Re-queues a leg that failed transiently as `pending` again after bumping
  /// [attempts], so the next flush pass can retry it (bounded by
  /// [kSyncMaxAttempts]). Mirrors [markFailed] but leaves the leg in the queue.
  Future<void> requeueRetry(String id, String error, int attempts);

  /// Applies the result of a successful replay to the local mirror: marks the
  /// mirrored row for [entity] at [localId] as `synced`, records the
  /// local→server mapping when a [serverId] was returned, and (for invoices) a
  /// dopt the official [officialNo] from the RPC envelope so the real number
  /// shows instead of the temporary `D-…`.
  Future<void> markReplaySynced({
    required String tenantId,
    required String entity,
    required String localId,
    String? serverId,
    String? officialNo,
  });

  /// Local uuid <-> server uuid resolution. Every lookup is tenant-scoped
  /// (schema 5): the ids are unique on their own, but scoping is what lets
  /// [clearTenant] remove a signed-out workspace's mappings.
  Future<String?> serverIdFor(String tenantId, String entity, String localId);
  Future<String?> localIdFor(String tenantId, String entity, String serverId);
  Future<void> putMapping({
    required String tenantId,
    required String entity,
    required String localId,
    required String serverId,
  });

  // ---- cache & settings ------------------------------------------------

  Future<void> putReport(String tenantId, String key, String payload);
  Future<String?> report(String tenantId, String key);
  Future<CachedReportData?> cachedReport(String tenantId, String key);

  Future<void> putSetting(String tenantId, String key, String? value);
  Future<String?> getSetting(String tenantId, String key);

  // ---- offline user profile (M13 Phase 0) ---------------------------------

  /// Stores the last-known signed-in profile for [authUid], replacing any
  /// previous value. The store owns [LocalUserProfiles.updatedAt] so callers
  /// cannot stamp it wrong. [payload] is the JSON-encoded `AppUser`.
  Future<void> putUserProfile(String authUid, String payload);

  /// The cached profile for [authUid], or null when this device has never
  /// stored one (first run, or after a sign-out cleared it).
  Future<LocalUserProfileRow?> getUserProfile(String authUid);

  /// Drops the cached profile for [authUid]. Called on sign-out so a signed-out
  /// device retains no offline access. Absent uid is a no-op.
  Future<void> deleteUserProfile(String authUid);

  /// Wipes every tenant-scoped mirror, queue, and cache row for [tenantId].
  ///
  /// **Never destroys unsynced work by accident.** A clear is refused while
  /// anything local is still waiting for the server; the returned report says
  /// how much was at risk so the caller can ask the user to confirm. Passing
  /// `force: true` is the caller saying "yes, discard it" — the wipe then runs
  /// and the report still records exactly what was lost.
  ///
  /// The `local_user_profiles` table is deliberately untouched: it is keyed by
  /// auth uid, not tenant, and is cleared on sign-out instead.
  Future<ClearTenantReport> clearTenant(String tenantId, {bool force = false});

  Future<void> dispose();

  // ---- pending data protection ----------------------------------------

  Future<bool> hasUnsyncedCustomers(String tenantId);
  Future<bool> hasUnsyncedSuppliers(String tenantId);
  Future<bool> hasUnsyncedProducts(String tenantId);
  Future<bool> hasUnsyncedEmployees(String tenantId);
  Future<bool> hasUnsyncedInvoices(String tenantId);
  Future<bool> hasUnsyncedPayments(String tenantId);
  Future<bool> hasUnsyncedJournalEntries(String tenantId);
  Future<bool> hasUnsyncedEmployeeMovements(String tenantId);
  Future<bool> hasUnsyncedSalaries(String tenantId);
  Future<bool> hasUnsyncedAccounts(String tenantId);
}

/// No-op store returned when the host cannot provide sqlite3 (web dev builds).
class NullLocalStore implements LocalStore {
  const NullLocalStore();

  @override
  bool get isAvailable => false;

  @override
  AppDatabase get db => throw UnsupportedError('Local store unavailable');

  @override
  Future<List<LocalCustomerRow>> customers(String tenantId) async => const [];

  @override
  Future<void> mirrorCustomers(
    String tenantId,
    List<LocalCustomerRow> rows,
  ) async {}

  @override
  Future<void> upsertCustomer(LocalCustomerRow row) async {}

  @override
  Future<List<LocalSupplierRow>> suppliers(String tenantId) async => const [];

  @override
  Future<void> mirrorSuppliers(
    String tenantId,
    List<LocalSupplierRow> rows,
  ) async {}

  @override
  Future<void> upsertSupplier(LocalSupplierRow row) async {}

  @override
  Future<List<LocalProductRow>> products(String tenantId) async => const [];

  @override
  Future<void> mirrorProducts(
    String tenantId,
    List<LocalProductRow> rows,
  ) async {}

  @override
  Future<void> upsertProduct(LocalProductRow row) async {}

  @override
  Future<List<LocalEmployeeRow>> employees(String tenantId) async => const [];

  @override
  Future<void> mirrorEmployees(
    String tenantId,
    List<LocalEmployeeRow> rows,
  ) async {}

  @override
  Future<void> upsertEmployee(LocalEmployeeRow row) async {}

  @override
  Future<List<LocalAccountRow>> accounts(String tenantId) async => const [];

  @override
  Future<void> mirrorAccounts(
    String tenantId,
    List<LocalAccountRow> rows,
  ) async {}

  @override
  Future<void> upsertAccount(LocalAccountRow row) async {}

  @override
  Future<List<LocalAccountRow>> ensureBaselineChart(String tenantId) async =>
      const [];

  @override
  Future<List<LocalInvoiceRow>> invoices(
    String tenantId, {
    String? type,
  }) async => const [];

  @override
  Future<void> upsertInvoice(LocalInvoiceRow row) async {}

  @override
  Future<void> deleteInvoice(String tenantId, String id) async {}

  @override
  Future<LocalInvoiceRow?> invoice(String tenantId, String id) async => null;

  @override
  Future<void> mirrorInvoices(
    String tenantId,
    List<LocalInvoiceRow> rows,
  ) async {}

  @override
  Future<void> clearInvoiceMoneyMarker(String tenantId, String legId) async {}

  @override
  Future<void> resolveInvoiceMoneyMarker(String tenantId, String legId) async {}

  @override
  Future<List<LocalInvoiceItemRow>> invoiceItems(
    String tenantId,
    String invoiceId,
  ) async => const [];

  @override
  Future<bool> invoiceItemsReferenceProduct(
    String tenantId,
    String productId,
  ) async =>
      false;

  @override
  Future<void> upsertInvoiceItems(List<LocalInvoiceItemRow> rows) async {}

  @override
  Future<void> mirrorInvoiceItems(
    String tenantId,
    String invoiceId,
    List<LocalInvoiceItemRow> rows,
  ) async {}

  @override
  Future<void> upsertPayment(LocalPaymentRow row) async {}

  @override
  Future<List<LocalPaymentRow>> payments(String tenantId) async => const [];

  @override
  Future<List<LocalCommissionDueRow>> commissionDues(
    String tenantId, {
    String? supplierId,
  }) async => const [];

  @override
  Future<void> upsertCommissionDue(LocalCommissionDueRow row) async {}

  @override
  Future<void> insertJournalEntry(LocalJournalEntryRow row) async {}

  @override
  Future<List<LocalJournalEntryRow>> journalEntries(String tenantId) async =>
      const [];

  @override
  Future<List<LocalEmployeeMovementRow>> employeeMovements(
    String tenantId, {
    String? employeeId,
  }) async => const [];

  @override
  Future<void> upsertEmployeeMovement(LocalEmployeeMovementRow row) async {}

  @override
  Future<List<LocalSalaryRow>> salaries(
    String tenantId, {
    String? employeeId,
  }) async => const [];

  @override
  Future<void> upsertSalary(LocalSalaryRow row) async {}

  @override
  Future<void> enqueue(SyncQueueRow row) async {}

  @override
  Future<List<SyncQueueRow>> pendingSync(String tenantId) async => const [];

  @override
  Future<int> pendingCount(String tenantId) async => 0;

  @override
  Future<Map<String, String>> queueStatuses(String tenantId) async => {};

  @override
  Future<List<SyncQueueRow>> queueLegsFor(
    String tenantId, {
    String? entity,
  }) async => const [];

  @override
  Future<Set<String>> pendingDeleteIds(String tenantId, String entity) async =>
      const {};

  @override
  Future<void> removeMirrorRows(
    String tenantId,
    String entity,
    List<String> ids,
  ) async {}

  @override
  Future<Set<String>> invoiceIdsWithDurableItems(
    String tenantId,
    List<String> invoiceIds,
  ) async =>
      // Nothing is ever durable without a database, so every candidate looks
      // missing and the caller simply asks the network for all of them.
      const <String>{};

  @override
  Future<T> transaction<T>(Future<T> Function(LocalStore store) action) =>
      // No database means no rollback, but the write path stays identical so
      // callers never need a Null-vs-real branch.
      action(this);

  @override
  Future<void> markSynced(String id) async {}

  @override
  Future<void> markFailed(String id, String error) async {}

  @override
  Future<void> requeueRetry(String id, String error, int attempts) async {}

  @override
  Future<void> markReplaySynced({
    required String tenantId,
    required String entity,
    required String localId,
    String? serverId,
    String? officialNo,
  }) async {}

  @override
  Future<String?> serverIdFor(
    String tenantId,
    String entity,
    String localId,
  ) async => localId;

  @override
  Future<String?> localIdFor(
    String tenantId,
    String entity,
    String serverId,
  ) async => serverId;

  @override
  Future<void> putMapping({
    required String tenantId,
    required String entity,
    required String localId,
    required String serverId,
  }) async {}

  @override
  Future<void> putReport(String tenantId, String key, String payload) async {}

  @override
  Future<String?> report(String tenantId, String key) async => null;

  @override
  Future<CachedReportData?> cachedReport(String tenantId, String key) async =>
      null;

  @override
  Future<void> putSetting(String tenantId, String key, String? value) async {}

  @override
  Future<String?> getSetting(String tenantId, String key) async => null;

  @override
  Future<void> putUserProfile(String authUid, String payload) async {}

  @override
  Future<LocalUserProfileRow?> getUserProfile(String authUid) async => null;

  @override
  Future<void> deleteUserProfile(String authUid) async {}

  @override
  Future<ClearTenantReport> clearTenant(
    String tenantId, {
    bool force = false,
  }) async => const ClearTenantReport(
    cleared: true,
    pendingQueueItems: 0,
    unsyncedMirrorRows: 0,
  );

  @override
  Future<void> dispose() async {}

  @override
  Future<bool> hasUnsyncedCustomers(String tenantId) async => false;

  @override
  Future<bool> hasUnsyncedSuppliers(String tenantId) async => false;

  @override
  Future<bool> hasUnsyncedProducts(String tenantId) async => false;

  @override
  Future<bool> hasUnsyncedEmployees(String tenantId) async => false;

  @override
  Future<bool> hasUnsyncedInvoices(String tenantId) async => false;

  @override
  Future<bool> hasUnsyncedPayments(String tenantId) async => false;

  @override
  Future<bool> hasUnsyncedJournalEntries(String tenantId) async => false;

  @override
  Future<bool> hasUnsyncedEmployeeMovements(String tenantId) async => false;

  @override
  Future<bool> hasUnsyncedSalaries(String tenantId) async => false;

  @override
  Future<bool> hasUnsyncedAccounts(String tenantId) async => false;
}

/// Default implementation backed by the drift [AppDatabase].
class DriftLocalStore implements LocalStore {
  DriftLocalStore(this._db);

  final AppDatabase _db;

  @override
  bool get isAvailable => true;

  @override
  AppDatabase get db => _db;

  // ---- master data -------------------------------------------------

  @override
  Future<List<LocalCustomerRow>> customers(String tenantId) => (_db.select(
    _db.localCustomers,
  )..where((r) => r.tenantId.equals(tenantId))).get();

  @override
  Future<void> mirrorCustomers(String tenantId, List<LocalCustomerRow> rows) =>
      _mirrorPreservingUnsynced<LocalCustomerRow>(
        serverRows: rows,
        idOf: (r) => r.id,
        readPendingIds: () async => {
          for (final r
              in await (_db.select(_db.localCustomers)..where(
                    (r) => r.tenantId.equals(tenantId) & r.synced.equals(false),
                  ))
                  .get())
            r.id,
        },
        deleteSynced: () =>
            (_db.delete(_db.localCustomers)..where(
                  (r) => r.tenantId.equals(tenantId) & r.synced.equals(true),
                ))
                .go(),
        insertAll: (rs) =>
            _db.batch((b) => b.insertAll(_db.localCustomers, rs)),
      );

  @override
  Future<void> upsertCustomer(LocalCustomerRow row) => _db
      .into(_db.localCustomers)
      .insert(row, mode: InsertMode.insertOrReplace);

  @override
  Future<List<LocalSupplierRow>> suppliers(String tenantId) => (_db.select(
    _db.localSuppliers,
  )..where((r) => r.tenantId.equals(tenantId))).get();

  @override
  Future<void> mirrorSuppliers(String tenantId, List<LocalSupplierRow> rows) =>
      _mirrorPreservingUnsynced<LocalSupplierRow>(
        serverRows: rows,
        idOf: (r) => r.id,
        readPendingIds: () async => {
          for (final r
              in await (_db.select(_db.localSuppliers)..where(
                    (r) => r.tenantId.equals(tenantId) & r.synced.equals(false),
                  ))
                  .get())
            r.id,
        },
        deleteSynced: () =>
            (_db.delete(_db.localSuppliers)..where(
                  (r) => r.tenantId.equals(tenantId) & r.synced.equals(true),
                ))
                .go(),
        insertAll: (rs) =>
            _db.batch((b) => b.insertAll(_db.localSuppliers, rs)),
      );

  @override
  Future<void> upsertSupplier(LocalSupplierRow row) => _db
      .into(_db.localSuppliers)
      .insert(row, mode: InsertMode.insertOrReplace);

  @override
  Future<List<LocalProductRow>> products(String tenantId) => (_db.select(
    _db.localProducts,
  )..where((r) => r.tenantId.equals(tenantId))).get();

  @override
  Future<void> mirrorProducts(String tenantId, List<LocalProductRow> rows) =>
      _mirrorProductsWithQtyAuthority(tenantId, rows);

  /// Product mirror with **per-product quantity authority** layered on top of
  /// the pending-master rule.
  ///
  /// A product's master fields (name/price/supplier…) and its quantity have
  /// separate owners, and only quantity needs protecting:
  ///
  ///  * a `synced: false` local row is pending master CRUD, so the whole row is
  ///    kept and an incoming copy is skipped — the M14 rule, unchanged;
  ///  * a **pending stock leg** (identified by
  ///    [LocalStore.affectedProductIdsOf]) owns the quantity even when the row
  ///    itself is `synced: true` — an offline sale/purchase/movement on a
  ///    server product mutates `qty` while leaving `synced` true. For that id
  ///    the server's master fields are accepted, but the local quantity is
  ///    preserved so a background refresh cannot erase the user's stock change
  ///    before the leg replays;
  ///  * otherwise the server copy is authoritative for everything, quantity
  ///    included.
  ///
  /// Authority is per-row and only `status == 'pending'` legs count, so the
  /// freeze is exactly the products some un-replayed stock mutation names — a
  /// terminal `failed` leg is diagnostic and does not freeze quantity, and an
  /// unrelated product B is never affected by a pending leg on A.
  Future<void> _mirrorProductsWithQtyAuthority(
    String tenantId,
    List<LocalProductRow> rows,
  ) async {
    await _db.transaction(() async {
      final local = {
        for (final r in await products(tenantId)) r.id: r,
      };
      final pendingMasterIds = {
        for (final e in local.entries)
          if (!e.value.synced) e.key,
      };
      final pendingStockIds = await _pendingStockProductIds(tenantId);

      // Replace this tenant's server-owned rows; pending master rows are not
      // matched by `synced == true`, so they survive untouched.
      await (_db.delete(_db.localProducts)..where(
            (r) => r.tenantId.equals(tenantId) & r.synced.equals(true),
          ))
          .go();

      final incoming = <LocalProductRow>[];
      for (final r in rows) {
        if (pendingMasterIds.contains(r.id)) continue;
        final localRow = local[r.id];
        if (localRow != null && pendingStockIds.contains(r.id)) {
          incoming.add(r.copyWith(qty: localRow.qty));
        } else {
          incoming.add(r);
        }
      }
      if (incoming.isNotEmpty) {
        await _db.batch((b) => b.insertAll(_db.localProducts, incoming));
      }
    });
  }

  /// Product ids a still-pending stock leg names, across every pending leg for
  /// [tenantId]. Terminal `failed`/`synced` legs are excluded: only a leg that
  /// has not yet reached the server owns the local quantity.
  Future<Set<String>> _pendingStockProductIds(String tenantId) async {
    final legs = await (_db.select(_db.syncQueueItems)..where(
          (r) => r.tenantId.equals(tenantId) & r.status.equals('pending'),
        ))
        .get();
    return {
      for (final leg in legs) ...LocalStore.affectedProductIdsOf(leg),
    };
  }

  @override
  Future<void> upsertProduct(LocalProductRow row) =>
      _db.into(_db.localProducts).insert(row, mode: InsertMode.insertOrReplace);

  @override
  Future<List<LocalEmployeeRow>> employees(String tenantId) => (_db.select(
    _db.localEmployees,
  )..where((r) => r.tenantId.equals(tenantId))).get();

  @override
  Future<void> mirrorEmployees(String tenantId, List<LocalEmployeeRow> rows) =>
      _mirrorPreservingUnsynced<LocalEmployeeRow>(
        serverRows: rows,
        idOf: (r) => r.id,
        readPendingIds: () async => {
          for (final r
              in await (_db.select(_db.localEmployees)..where(
                    (r) => r.tenantId.equals(tenantId) & r.synced.equals(false),
                  ))
                  .get())
            r.id,
        },
        deleteSynced: () =>
            (_db.delete(_db.localEmployees)..where(
                  (r) => r.tenantId.equals(tenantId) & r.synced.equals(true),
                ))
                .go(),
        insertAll: (rs) =>
            _db.batch((b) => b.insertAll(_db.localEmployees, rs)),
      );

  @override
  Future<void> upsertEmployee(LocalEmployeeRow row) => _db
      .into(_db.localEmployees)
      .insert(row, mode: InsertMode.insertOrReplace);

  @override
  Future<List<LocalAccountRow>> accounts(String tenantId) => (_db.select(
    _db.localAccounts,
  )..where((r) => r.tenantId.equals(tenantId))).get();

  @override
  Future<void> mirrorAccounts(
    String tenantId,
    List<LocalAccountRow> rows,
  ) async {
    // Never let a background/online refresh destroy locally-modified accounts
    // that the server has not seen yet. If any `synced=false` row exists for
    // this tenant, skip the destructive clear-and-replace entirely.
    final hasUnsynced = await hasUnsyncedAccounts(tenantId);
    if (hasUnsynced) return;
    await _db.transaction(() async {
      await (_db.delete(
        _db.localAccounts,
      )..where((r) => r.tenantId.equals(tenantId))).go();
      if (rows.isNotEmpty) {
        await _db.batch((b) => b.insertAll(_db.localAccounts, rows));
      }
    });
  }

  @override
  Future<List<LocalAccountRow>> ensureBaselineChart(String tenantId) async {
    final existing = await accounts(tenantId);
    if (existing.isNotEmpty) return existing;
    final templates = await _db.select(_db.localAccountTemplates).get();
    if (templates.isEmpty) return existing;
    final rows = [
      for (final t in templates)
        LocalAccountRow(
          // A generated tenant-local id, NOT a shared constant. A fixed id like
          // `baseline:1010` is the same primary key in every tenant, so the
          // second tenant's insert collides with the first tenant's row and
          // (with insertOrReplace semantics) either steals or destroys another
          // tenant's account. Baseline accounts are local placeholders anyway;
          // the real id arrives with the first successful chart mirror.
          id: const Uuid().v4(),
          tenantId: tenantId,
          code: t.code,
          name: t.name,
          type: t.type,
          // The server seed leaves parent_code/parent_id NULL for all 14
          // defaults; the baseline reproduces that exactly so a later online
          // mirror does not disagree with it.
          parentCode: null,
          parentId: null,
        ),
    ];
    await _db.transaction(() async {
      await _db.batch((b) => b.insertAll(_db.localAccounts, rows));
    });
    return accounts(tenantId);
  }

  @override
  Future<void> upsertAccount(LocalAccountRow row) =>
      _db.into(_db.localAccounts).insert(row, mode: InsertMode.insertOrReplace);

  // ---- financial ----------------------------------------------------

  @override
  Future<List<LocalInvoiceRow>> invoices(String tenantId, {String? type}) =>
      (_db.select(_db.localInvoices)..where(
            (r) => type == null
                ? r.tenantId.equals(tenantId)
                : r.tenantId.equals(tenantId) & r.type.equals(type),
          ))
          .get();

  @override
  Future<void> upsertInvoice(LocalInvoiceRow row) =>
      _db.into(_db.localInvoices).insert(row, mode: InsertMode.insertOrReplace);

  @override
  Future<LocalInvoiceRow?> invoice(String tenantId, String id) =>
      (_db.select(_db.localInvoices)
            ..where((r) => r.tenantId.equals(tenantId) & r.id.equals(id)))
          .getSingleOrNull();

  /// Deletes an invoice and its line items, scoped to the owning workspace.
  ///
  /// Tenant scoping on BOTH deletes is a P1.E correction, not a formality: the
  /// cascade used to match `invoice_id` / `id` alone, so a delete in one
  /// workspace could remove another workspace's lines for the same invoice id.
  /// (The header table is still keyed `{id}` alone, so the header delete cannot
  /// be made collision-proof by filtering — it can only be scoped to the tenant
  /// that owns it, which is what happens here.)
  @override
  Future<void> deleteInvoice(String tenantId, String id) async {
    await (_db.delete(
      _db.localInvoiceItems,
    )..where((r) => r.tenantId.equals(tenantId) & r.invoiceId.equals(id))).go();
    await (_db.delete(
      _db.localInvoices,
    )..where((r) => r.tenantId.equals(tenantId) & r.id.equals(id))).go();
  }

  /// Server-owned invoice headers land here so `recordPayment` /
  /// `settleSupplier` can resolve an invoice the device only ever saw over the
  /// network (issue 3).
  ///
  /// ## Why this is not `_mirrorPreservingUnsynced`
  ///
  /// Two properties force a bespoke shape:
  ///
  /// 1. **It never sweeps the tenant.** An invoice list read is filtered
  ///    (search / date range), so the master mirrors' tenant-wide
  ///    delete-and-replace would discard every invoice outside the window the
  ///    user happens to be looking at. The delete here is scoped to the
  ///    incoming ids.
  /// 2. **A same-id row owned by another tenant must fail, not replace.** The
  ///    primary key is `{id}` alone, so `insertOrReplace` would silently
  ///    OVERWRITE another workspace's locally-owned row — the exact
  ///    cross-tenant damage the id-only key is documented to risk. So the
  ///    replacement is an explicit delete-then-insert: the delete is
  ///    tenant-scoped, and the insert is a plain insert that raises UNIQUE on a
  ///    foreign collision. Both halves sit in one transaction, so a collision
  ///    rolls the whole mirror back and leaves the other tenant's row intact.
  ///
  /// Rows carrying local work are excluded from both halves: an unsynced draft
  /// (`synced == false`) is a local invoice the server has never seen, and a
  /// synced row still stamped with `pendingMoneyLeg` holds
  /// `paid`/`remaining`/`status` corrections a queued leg has not yet replayed
  /// — the server's copy is the one from BEFORE that payment. Re-inserting it
  /// is how issue 3 recurs through a narrower door.
  ///
  /// **That exclusion is evaluated in the LOCAL id space.** A row this device
  /// minted is stored under its local uuid while the server calls it something
  /// else, so the incoming server id must be resolved through `id_map` *before*
  /// it is tested against the protected set. Filtering on the raw server id
  /// protects nothing for exactly those rows — see the resolution block below.
  @override
  Future<void> mirrorInvoices(
    String tenantId,
    List<LocalInvoiceRow> rows,
  ) async {
    if (rows.isEmpty) return;
    await _db.transaction(() async {
      // **Resolve the id space FIRST, then compare.** [protectedIds] is built
      // from LOCAL rows; [rows] arrive from the SERVER. For a row this device
      // minted those two ids differ (`id_map` links them), so filtering on the
      // raw incoming id asks "is this server id in the set of local ids?" —
      // which is false for exactly the mapped rows that must NOT be touched.
      // The mapped row then fell through to the update branch below and the
      // server's pre-payment money was written over the local correction,
      // clearing `pendingMoneyLeg` in the same statement and letting the next
      // server read hand the invoice back to a figure the queue had not
      // reached yet.
      //
      // So every incoming id is mapped to its effective LOCAL id up front, and
      // BOTH the protection filter and the update branch consume that same
      // value. Comparing like with like is the whole fix.
      //
      // This costs exactly what the old code already cost: one indexed
      // `id_map` read per incoming row (the update branch used to do it too),
      // just hoisted above the filter instead of below it.
      final localIdByServerId = <String, String>{
        for (final row in rows)
          row.id: await localIdFor(tenantId, 'invoices', row.id) ?? row.id,
      };
      final protectedIds = {
        for (final r
            in await (_db.select(_db.localInvoices)..where(
                  (r) =>
                      r.tenantId.equals(tenantId) &
                      (r.synced.equals(false) |
                          r.pendingMoneyLeg.isNull().not()),
                ))
                .get())
          r.id,
      };
      // A protected mapped row now drops out of `incoming` entirely, so BOTH
      // its money columns and its marker survive — protecting only the money
      // would leave the row looking server-owned while showing local figures.
      final incoming = <({LocalInvoiceRow row, String localId})>[
        for (final row in rows)
          if (!protectedIds.contains(localIdByServerId[row.id]!))
            (row: row, localId: localIdByServerId[row.id]!),
      ];
      if (incoming.isEmpty) return;

      // A row this device minted is still stored under its LOCAL id after a
      // replay — `markReplaySynced` updates `no`/`synced` in place and records
      // local→server in `id_map` rather than re-keying the row. So the server's
      // copy of that same invoice arrives here under a DIFFERENT id, and
      // inserting it blindly lands a second row beside the local one: the
      // invoice appears twice, and the sync badge's join (which keys on the
      // queue leg's `localId`) silently stops matching. `id_map` is the only
      // link, so it is consulted above and the row is refreshed IN PLACE —
      // re-keying it to the server id would break that join instead.
      //
      // This is the same `id_map` the P2 drain test depends on, and it is why
      // `markReplaySynced` deliberately keeps the local id.
      //
      // An UNPROTECTED mapped row still lands here, which is the point: once the
      // money leg drains and `resolveInvoiceMoneyMarker` clears the marker, the
      // server's figures are authoritative again and must be allowed to land.
      final fresh = <LocalInvoiceRow>[];
      for (final e in incoming) {
        if (e.localId == e.row.id) {
          fresh.add(e.row);
          continue;
        }
        await (_db.update(
          _db.localInvoices,
        )..where((r) => r.id.equals(e.localId) & r.tenantId.equals(tenantId)))
        // `nullToAbsent: false` writes the NULLs through, which is the
        // contract: a server-owned row carries no requestId, no local
        // createdAt and no pending money leg.
        .write(e.row.copyWith(id: e.localId).toCompanion(false));
      }
      if (fresh.isEmpty) return;

      // `local_invoices` is keyed `{id}` ALONE, so a same-id row owned by
      // another tenant is a real primary-key collision. The safe primitive stays
      // a tenant-scoped delete + a PLAIN insert: `insertOrReplace` matches the
      // key alone, so it would silently replace the other workspace's invoice
      // and destroy it on a tenant switch.
      //
      // The collision is resolved by SKIPPING the offending id, not by letting
      // the insert raise. Letting it raise rolls back the whole transaction —
      // including the delete above — so ONE colliding invoice in a page of
      // twenty would leave the other nineteen unhydrated: the same "visible but
      // not locally writable" defect one level down. The colliding ids are
      // therefore partitioned out first, and their safe siblings are written.
      //
      // The skipped invoice is the ONE documented exception to "an invoice
      // returned to `list()` is locally resolvable": the schema cannot hold both
      // tenants' rows under one key, and the read cannot invent the other
      // workspace's row. A payment against it still fails honestly with
      // 'الفاتورة غير موجودة محلياً'. Tenant isolation is never traded away to
      // make a page look complete.
      final foreignIds = {
        for (final r
            in await (_db.select(_db.localInvoices)..where(
                  (r) =>
                      r.id.isIn([for (final r in fresh) r.id]) &
                      r.tenantId.equals(tenantId).not(),
                ))
                .get())
          r.id,
      };
      final insertable = [
        for (final r in fresh)
          if (!foreignIds.contains(r.id)) r,
      ];
      if (insertable.isEmpty) return;

      // Replace only THIS tenant's own server-owned copy of those exact ids.
      await (_db.delete(_db.localInvoices)..where(
            (r) =>
                r.tenantId.equals(tenantId) &
                r.synced.equals(true) &
                r.pendingMoneyLeg.isNull() &
                r.id.isIn([for (final r in insertable) r.id]),
          ))
          .go();

      await _db.batch((b) => b.insertAll(_db.localInvoices, insertable));
    });
  }

  @override
  Future<void> clearInvoiceMoneyMarker(String tenantId, String legId) async {
    await (_db.update(_db.localInvoices)..where(
          (r) => r.tenantId.equals(tenantId) & r.pendingMoneyLeg.equals(legId),
        ))
        .write(const LocalInvoicesCompanion(pendingMoneyLeg: Value(null)));
  }

  @override
  Future<void> resolveInvoiceMoneyMarker(String tenantId, String legId) async {
    // Every invoice the completing leg restated, taken as the union of the rows
    // it currently stamps and the set recorded in its attribution column.
    //
    // Attribution is the primary answer: it is the only source that survives the
    // marker being taken over by a newer leg, which is exactly the case
    // `settle_supplier` needs (its RPC body names no invoices). The stamped set
    // is the floor — it guarantees a leg can never silently stop re-deciding
    // rows it wrote itself if its attribution is missing or unreadable (a
    // pre-v7 settlement, a corrupt column).
    //
    // Honest note on the union's two halves, established by mutation rather
    // than assumption: under every state reachable through the write path, the
    // two halves AGREE, because a resolve only ever re-stamps to another
    // *outstanding* leg or clears, and after any resolve the marker names either
    // null or an outstanding leg. Dropping the stamped half therefore passes the
    // whole suite, as does dropping the attribution half except for the
    // self-healing case pinned by `resolution depends on the queue`. The stamped
    // half is kept because it is the definition of "the invoices this leg
    // restated" and it costs one line — not because a current test needs it.
    final stamped =
        await (_db.select(_db.localInvoices)..where(
              (r) =>
                  r.tenantId.equals(tenantId) & r.pendingMoneyLeg.equals(legId),
            ))
            .get();
    final completed =
        await (_db.select(_db.syncQueueItems)
              ..where((r) => r.id.equals(legId) & r.tenantId.equals(tenantId)))
            .getSingleOrNull();

    final affected = <String>{
      for (final r in stamped) r.id,
      if (completed != null) ...LocalStore._legInvoiceIds(completed),
    };
    if (affected.isEmpty) return;

    // Money legs that have not reached `synced` yet, excluding the one being
    // resolved. This includes `pending` (retrying) and `failed` (parked) legs
    // on purpose: both are local financial mutations the server has not
    // accepted, so both must keep owning the invoice. The cost is liveness — a
    // permanently parked leg holds its invoices' local figures indefinitely —
    // and the trade is deliberate, because the alternative re-exposes figures
    // that predate the user's own write. Recovery UX is a separate concern.
    final outstanding = await _pendingMoneyLegsExcluding(tenantId, legId);

    for (final invoiceId in affected) {
      // The server is authoritative for this invoice only once EVERY local
      // money mutation on it has replayed. Clearing on *this* leg's success
      // alone is not enough: the marker only ever names the newest leg, so an
      // older leg that is still queued would be forgotten and the row would
      // fall back to a server figure that knows about neither.
      final stillQueued =
          outstanding
              .where((l) => LocalStore._legInvoiceIds(l).contains(invoiceId))
              .toList()
            // Deterministic order. `createdAt` alone is NOT a total order: legs
            // enqueued in the same millisecond share a timestamp, so which one is
            // "oldest" would otherwise depend on row order. Ids are uuids, so
            // comparing them is arbitrary but stable.
            ..sort((a, b) {
              final byTime = a.createdAt.compareTo(b.createdAt);
              return byTime != 0 ? byTime : a.id.compareTo(b.id);
            });

      await (_db.update(
            _db.localInvoices,
          )..where((r) => r.id.equals(invoiceId) & r.tenantId.equals(tenantId)))
          .write(
            LocalInvoicesCompanion(
              // Re-stamp to a leg that genuinely has not landed, so the next clear can
              // still match by equality. Pointing at this already-synced leg would
              // leave a marker nothing could ever clear.
              pendingMoneyLeg: Value(
                stillQueued.isEmpty ? null : stillQueued.first.id,
              ),
            ),
          );
    }
  }

  /// Money legs (payments / settlements) that have not reached `synced` yet,
  /// excluding the one currently being resolved.
  Future<List<SyncQueueRow>> _pendingMoneyLegsExcluding(
    String tenantId,
    String excludedLegId,
  ) async {
    final legs =
        await (_db.select(_db.syncQueueItems)..where(
              (r) =>
                  r.tenantId.equals(tenantId) &
                  r.entity.equals('payments') &
                  r.status.isNotValue('synced') &
                  r.id.equals(excludedLegId).not(),
            ))
            .get();
    return legs;
  }

  /// Tenant-scoped, and ordered by `id` — the detail sheet iterates this list
  /// in order, and `id` is the mirror's positional `<invoiceId>:<ordinal>` key,
  /// so the painted order is the server's order.
  ///
  /// Rows whose id predates the positional scheme (a bare uuid, written by an
  /// older build's `writeSale`) have no recoverable original position, so they
  /// come back ordered by their uuid. That limitation is documented rather than
  /// hidden: the alternative — inventing a column to store a position that was
  /// never recorded — is a second source of truth with no evidence behind it.
  @override
  Future<List<LocalInvoiceItemRow>> invoiceItems(
    String tenantId,
    String invoiceId,
  ) =>
      (_db.select(_db.localInvoiceItems)
            ..where(
              (r) =>
                  r.tenantId.equals(tenantId) & r.invoiceId.equals(invoiceId),
            )
            ..orderBy([(r) => OrderingTerm.asc(r.id)]))
          .get();

  @override
  Future<bool> invoiceItemsReferenceProduct(
    String tenantId,
    String productId,
  ) async {
    final rows =
        await (_db.select(_db.localInvoiceItems)
              ..where(
                (r) =>
                    r.tenantId.equals(tenantId) & r.productId.equals(productId),
              )
              ..limit(1))
            .get();
    return rows.isNotEmpty;
  }

  @override
  Future<void> upsertInvoiceItems(List<LocalInvoiceItemRow> rows) async {
    if (rows.isEmpty) return;
    await _db.batch(
      (b) => b.insertAll(
        _db.localInvoiceItems,
        rows,
        mode: InsertMode.insertOrReplace,
      ),
    );
  }

  /// See [LocalStore.mirrorInvoiceItems] for why this replaces the whole set.
  ///
  /// The local-work guard is what keeps a pending draft safe: its lines are the
  /// only copy on the device (the server has never seen the invoice), so a
  /// refresh must not sweep them. `pendingMoneyLeg` is deliberately NOT consulted
  /// here, unlike [mirrorInvoices]: that marker is about money figures on the
  /// header, and nothing in the app edits an existing invoice's lines, so
  /// treating it as line authority would invent a rule with no reachable state
  /// behind it.
  ///
  /// Ids are re-minted positionally rather than trusted from the caller, so a
  /// caller cannot make two lines collide (or make an upsert's `replace` half
  /// clobber a sibling) by reusing an id. Four-digit zero padding is what makes
  /// `ORDER BY id` equal the server's order: `'x:10'` sorts before `'x:2'`
  /// without it, and that only surfaces at 10+ lines.
  @override
  Future<void> mirrorInvoiceItems(
    String tenantId,
    String invoiceId,
    List<LocalInvoiceItemRow> rows,
  ) async {
    await _db.transaction(() async {
      final header =
          await (_db.select(_db.localInvoices)..where(
                (r) => r.tenantId.equals(tenantId) & r.id.equals(invoiceId),
              ))
              .getSingleOrNull();
      if (header != null && !header.synced) return;

      await (_db.delete(_db.localInvoiceItems)..where(
            (r) => r.tenantId.equals(tenantId) & r.invoiceId.equals(invoiceId),
          ))
          .go();

      final stamped = <LocalInvoiceItemRow>[
        for (final (i, r) in rows.indexed)
          r.copyWith(
            id: LocalStore.invoiceLineId(invoiceId, i),
            tenantId: tenantId,
            invoiceId: invoiceId,
          ),
      ];
      if (stamped.isEmpty) return;
      // A PLAIN insert after a tenant-scoped delete: the key is `{tenantId,id}`
      // since schema 8, so a foreign row cannot be matched, and the delete
      // above could not have reached it either.
      await _db.batch((b) => b.insertAll(_db.localInvoiceItems, stamped));
    });
  }

  @override
  Future<void> upsertPayment(LocalPaymentRow row) =>
      _db.into(_db.localPayments).insert(row, mode: InsertMode.insertOrReplace);

  @override
  Future<List<LocalPaymentRow>> payments(String tenantId) => (_db.select(
    _db.localPayments,
  )..where((r) => r.tenantId.equals(tenantId))).get();

  @override
  Future<List<LocalCommissionDueRow>> commissionDues(
    String tenantId, {
    String? supplierId,
  }) =>
      (_db.select(_db.localCommissionDues)..where(
            (r) => supplierId == null
                ? r.tenantId.equals(tenantId)
                : r.tenantId.equals(tenantId) & r.supplierId.equals(supplierId),
          ))
          .get();

  @override
  Future<void> upsertCommissionDue(LocalCommissionDueRow row) => _db
      .into(_db.localCommissionDues)
      .insert(row, mode: InsertMode.insertOrReplace);

  @override
  Future<void> insertJournalEntry(LocalJournalEntryRow row) =>
      _db.into(_db.localJournalEntries).insert(row);

  @override
  Future<List<LocalJournalEntryRow>> journalEntries(String tenantId) =>
      (_db.select(_db.localJournalEntries)
            ..where((r) => r.tenantId.equals(tenantId))
            ..orderBy([(r) => OrderingTerm.asc(r.date)]))
          .get();

  @override
  Future<List<LocalEmployeeMovementRow>> employeeMovements(
    String tenantId, {
    String? employeeId,
  }) =>
      (_db.select(_db.localEmployeeMovements)..where(
            (r) => employeeId == null
                ? r.tenantId.equals(tenantId)
                : r.tenantId.equals(tenantId) & r.employeeId.equals(employeeId),
          ))
          .get();

  @override
  Future<void> upsertEmployeeMovement(LocalEmployeeMovementRow row) => _db
      .into(_db.localEmployeeMovements)
      .insert(row, mode: InsertMode.insertOrReplace);

  @override
  Future<List<LocalSalaryRow>> salaries(
    String tenantId, {
    String? employeeId,
  }) =>
      (_db.select(_db.localSalaries)..where(
            (r) => employeeId == null
                ? r.tenantId.equals(tenantId)
                : r.tenantId.equals(tenantId) & r.employeeId.equals(employeeId),
          ))
          .get();

  @override
  Future<void> upsertSalary(LocalSalaryRow row) =>
      _db.into(_db.localSalaries).insert(row, mode: InsertMode.insertOrReplace);

  // ---- sync -----------------------------------------------------------

  @override
  Future<void> enqueue(SyncQueueRow row) async {
    await _db.into(_db.syncQueueItems).insert(row, mode: InsertMode.insert);
  }

  @override
  Future<List<SyncQueueRow>> pendingSync(String tenantId) =>
      (_db.select(_db.syncQueueItems)
            ..where(
              (r) => r.tenantId.equals(tenantId) & r.status.equals('pending'),
            )
            ..orderBy([(r) => OrderingTerm.asc(r.createdAt)]))
          .get();

  @override
  Future<int> pendingCount(String tenantId) async {
    final count = _db.customSelect(
      'SELECT COUNT(*) AS c FROM sync_queue_items '
      'WHERE tenant_id = ? AND status = \'pending\'',
      variables: [Variable.withString(tenantId)],
    );
    final row = await count.getSingle();
    return row.read<int>('c');
  }

  @override
  Future<void> markSynced(String id) async {
    await (_db.update(_db.syncQueueItems)..where((r) => r.id.equals(id))).write(
      SyncQueueItemsCompanion(
        status: const Value('synced'),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<Map<String, String>> queueStatuses(String tenantId) async {
    final rows = await (_db.select(
      _db.syncQueueItems,
    )..where((r) => r.tenantId.equals(tenantId))).get();
    return {for (final r in rows) r.id: r.status};
  }

  @override
  Future<List<SyncQueueRow>> queueLegsFor(String tenantId, {String? entity}) {
    final query = _db.select(_db.syncQueueItems)
      ..where(
        (r) =>
            r.tenantId.equals(tenantId) &
            (entity == null ? const Constant(true) : r.entity.equals(entity)),
      )
      ..orderBy([(r) => OrderingTerm.asc(r.createdAt)]);
    return query.get();
  }

  @override
  Future<Set<String>> pendingDeleteIds(String tenantId, String entity) async {
    final legs = await queueLegsFor(tenantId, entity: entity);
    final hidden = <String>{};
    for (final leg in legs) {
      if (leg.op != 'table_crud' || leg.status != 'pending') continue;
      final localId = leg.localId;
      if (localId == null) continue;
      final params = leg.params == ''
          ? <String, dynamic>{}
          : jsonDecode(leg.params) as Map<String, dynamic>;
      // Delete-shape legs hold a bare `{'id': …}` (no `row`); an upsert-leg
      // row must keep showing until the flusher re-marks it synced.
      if (params.containsKey('id') && !params.containsKey('row')) {
        hidden.add(localId);
      }
    }
    return hidden;
  }

  @override
  Future<Set<String>> invoiceIdsWithDurableItems(
    String tenantId,
    List<String> invoiceIds,
  ) async {
    if (invoiceIds.isEmpty) return <String>{};

    // Resolve the id space ONCE for the whole set, because the two sides of
    // this comparison are written in different spaces: a caller holds ids as
    // the network serves them (a replayed invoice arrives under its SERVER id,
    // P1.C's `markReplaySynced` keeping the local uuid as the row key), while
    // `local_invoice_items.invoiceId` is written under the LOCAL id. A raw id
    // therefore never matches a mapped row, and the invoice looks permanently
    // "missing" — which reads exactly like "these lines were never fetched" and
    // re-requests them on every list refresh forever.
    //
    // ONE `isIn` read of the whole set here replaces one `localIdFor` probe per
    // invoice, so this stays two bounded local queries rather than N+1.
    final mappings =
        await (_db.select(_db.idMappings)..where(
              (r) =>
                  r.tenantId.equals(tenantId) &
                  r.entity.equals('invoices') &
                  r.serverId.isIn(invoiceIds),
            ))
            .get();
    final localByServer = <String, String>{
      for (final m in mappings) m.serverId: m.localId,
    };
    // Unsynced drafts have no mapping row at all — their local id IS their
    // server-shaped id — so `invoiceIds` is unioned in unchanged.
    final candidates = <String>{...invoiceIds, ...localByServer.values};

    // ONE grouped query for the whole candidate set. `selectOnly` +
    // `groupBy` asks sqlite for distinct invoice ids, so the cost is one
    // indexed scan instead of one probe per invoice.
    final distinct =
        await (_db.selectOnly(_db.localInvoiceItems)
              ..addColumns([_db.localInvoiceItems.invoiceId])
              ..where(
                _db.localInvoiceItems.tenantId.equals(tenantId) &
                    _db.localInvoiceItems.invoiceId.isIn(candidates),
              )
              ..groupBy([_db.localInvoiceItems.invoiceId]))
            .get();
    final stored = distinct
        .map((r) => r.read(_db.localInvoiceItems.invoiceId))
        .whereType<String>()
        .toSet();

    // Answer in the CALLER's id space, so the caller can compare its own ids
    // against the result without knowing a mapping exists: an input id counts as
    // durable when its own rows exist OR when the local row it maps to has them.
    return {
      for (final id in invoiceIds)
        if (stored.contains(id) || stored.contains(localByServer[id])) id,
    };
  }

  @override
  Future<void> removeMirrorRows(
    String tenantId,
    String entity,
    List<String> ids,
  ) async {
    if (ids.isEmpty) return;
    switch (entity) {
      case 'customers':
        await (_db.delete(
          _db.localCustomers,
        )..where((r) => r.tenantId.equals(tenantId) & r.id.isIn(ids))).go();
        break;
      case 'suppliers':
        await (_db.delete(
          _db.localSuppliers,
        )..where((r) => r.tenantId.equals(tenantId) & r.id.isIn(ids))).go();
        break;
      case 'products':
        await (_db.delete(
          _db.localProducts,
        )..where((r) => r.tenantId.equals(tenantId) & r.id.isIn(ids))).go();
        break;
      case 'employees':
        await (_db.delete(
          _db.localEmployees,
        )..where((r) => r.tenantId.equals(tenantId) & r.id.isIn(ids))).go();
        break;
      default:
        break;
    }
  }

  @override
  Future<T> transaction<T>(Future<T> Function(LocalStore store) action) =>
      // Drift's transaction zone is ambient: every query issued through this
      // same `_db` while the callback runs is enlisted in the transaction, so
      // the inner store can be `this` and a throw anywhere rolls back all of it.
      _db.transaction(() => action(this));

  @override
  Future<void> markFailed(String id, String error) async {
    await (_db.update(_db.syncQueueItems)..where((r) => r.id.equals(id))).write(
      SyncQueueItemsCompanion(
        status: const Value('failed'),
        lastError: Value(error),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<void> requeueRetry(String id, String error, int attempts) async {
    await (_db.update(_db.syncQueueItems)..where((r) => r.id.equals(id))).write(
      SyncQueueItemsCompanion(
        status: const Value('pending'),
        attempts: Value(attempts),
        lastError: Value(error),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<void> markReplaySynced({
    required String tenantId,
    required String entity,
    required String localId,
    String? serverId,
    String? officialNo,
  }) async {
    final finalServerId = serverId ?? localId;
    if (finalServerId != localId) {
      await putMapping(
        tenantId: tenantId,
        entity: entity,
        localId: localId,
        serverId: finalServerId,
      );
    }
    switch (entity) {
      case 'invoices':
        await (_db.update(
          _db.localInvoices,
        )..where((r) => r.id.equals(localId))).write(
          LocalInvoicesCompanion(
            no: officialNo == null ? const Value.absent() : Value(officialNo),
            synced: const Value(true),
          ),
        );
        break;
      case 'payments':
        await (_db.update(_db.localPayments)
              ..where((r) => r.id.equals(localId)))
            .write(LocalPaymentsCompanion(synced: const Value(true)));
        break;
      case 'journal_entries':
        await (_db.update(_db.localJournalEntries)
              ..where((r) => r.id.equals(localId)))
            .write(LocalJournalEntriesCompanion(synced: const Value(true)));
        break;
      case 'employee_movements':
        await (_db.update(_db.localEmployeeMovements)
              ..where((r) => r.id.equals(localId)))
            .write(LocalEmployeeMovementsCompanion(synced: const Value(true)));
        break;
      case 'salaries':
        await (_db.update(_db.localSalaries)
              ..where((r) => r.id.equals(localId)))
            .write(LocalSalariesCompanion(synced: const Value(true)));
        break;
      case 'customers':
        await (_db.update(_db.localCustomers)
              ..where((r) => r.id.equals(localId)))
            .write(LocalCustomersCompanion(synced: const Value(true)));
        break;
      case 'suppliers':
        await (_db.update(_db.localSuppliers)
              ..where((r) => r.id.equals(localId)))
            .write(LocalSuppliersCompanion(synced: const Value(true)));
        break;
      case 'products':
        await (_db.update(_db.localProducts)
              ..where((r) => r.id.equals(localId)))
            .write(LocalProductsCompanion(synced: const Value(true)));
        break;
      case 'employees':
        await (_db.update(_db.localEmployees)
              ..where((r) => r.id.equals(localId)))
            .write(LocalEmployeesCompanion(synced: const Value(true)));
        break;
      default:
        break;
    }
  }

  @override
  Future<String?> serverIdFor(
    String tenantId,
    String entity,
    String localId,
  ) async {
    final row =
        await (_db.select(_db.idMappings)..where(
              (r) =>
                  r.tenantId.equals(tenantId) &
                  r.entity.equals(entity) &
                  r.localId.equals(localId),
            ))
            .getSingleOrNull();
    return row?.serverId;
  }

  @override
  Future<String?> localIdFor(
    String tenantId,
    String entity,
    String serverId,
  ) async {
    final row =
        await (_db.select(_db.idMappings)..where(
              (r) =>
                  r.tenantId.equals(tenantId) &
                  r.entity.equals(entity) &
                  r.serverId.equals(serverId),
            ))
            .getSingleOrNull();
    return row?.localId;
  }

  @override
  Future<void> putMapping({
    required String tenantId,
    required String entity,
    required String localId,
    required String serverId,
  }) => _db
      .into(_db.idMappings)
      .insert(
        IdMappingsCompanion.insert(
          tenantId: tenantId,
          entity: entity,
          localId: localId,
          serverId: serverId,
        ),
        mode: InsertMode.insertOrReplace,
      );

  // ---- cache & settings ------------------------------------------------

  @override
  Future<void> putReport(String tenantId, String key, String payload) => _db
      .into(_db.reportCacheEntries)
      .insert(
        ReportCacheEntriesCompanion.insert(
          tenantId: tenantId,
          key: key,
          payload: payload,
        ),
        mode: InsertMode.insertOrReplace,
      );

  @override
  Future<String?> report(String tenantId, String key) async {
    final row =
        await (_db.select(_db.reportCacheEntries)
              ..where((r) => r.tenantId.equals(tenantId) & r.key.equals(key)))
            .getSingleOrNull();
    return row?.payload;
  }

  @override
  Future<CachedReportData?> cachedReport(String tenantId, String key) async {
    final row =
        await (_db.select(_db.reportCacheEntries)
              ..where((r) => r.tenantId.equals(tenantId) & r.key.equals(key)))
            .getSingleOrNull();
    if (row == null) return null;
    return CachedReportData(payload: row.payload, fetchedAt: row.fetchedAt);
  }

  @override
  Future<void> putSetting(String tenantId, String key, String? value) => _db
      .into(_db.localTenantSettings)
      .insert(
        LocalTenantSettingsCompanion.insert(
          tenantId: tenantId,
          key: key,
          value: Value(value),
        ),
        mode: InsertMode.insertOrReplace,
      );

  @override
  Future<String?> getSetting(String tenantId, String key) async {
    final row =
        await (_db.select(_db.localTenantSettings)
              ..where((r) => r.tenantId.equals(tenantId) & r.key.equals(key)))
            .getSingleOrNull();
    return row?.value;
  }

  @override
  Future<void> putUserProfile(String authUid, String payload) async {
    await _db
        .into(_db.localUserProfiles)
        .insert(
          LocalUserProfilesCompanion.insert(
            authUid: authUid,
            payload: payload,
            updatedAt: Value(DateTime.now()),
          ),
          mode: InsertMode.insertOrReplace,
        );
  }

  @override
  Future<LocalUserProfileRow?> getUserProfile(String authUid) {
    return (_db.select(
      _db.localUserProfiles,
    )..where((r) => r.authUid.equals(authUid))).getSingleOrNull();
  }

  @override
  Future<void> deleteUserProfile(String authUid) async {
    await (_db.delete(
      _db.localUserProfiles,
    )..where((r) => r.authUid.equals(authUid))).go();
  }

  @override
  Future<ClearTenantReport> clearTenant(
    String tenantId, {
    bool force = false,
  }) async {
    // Count what a wipe would destroy BEFORE deciding, so a refusal can tell
    // the caller exactly how much is at stake.
    final pendingQueueItems = await _countPendingQueue(tenantId);
    final unsyncedMirrorRows = await _countUnsyncedMirror(tenantId);

    if (!force && (pendingQueueItems > 0 || unsyncedMirrorRows > 0)) {
      // Refuse. Deleting queued writes would silently lose invoices the user
      // believes are saved; there is no way to recover them client-side.
      return ClearTenantReport.refused(
        pendingQueueItems: pendingQueueItems,
        unsyncedMirrorRows: unsyncedMirrorRows,
      );
    }

    await _db.transaction(() async {
      await (_db.delete(
        _db.localCustomers,
      )..where((r) => r.tenantId.equals(tenantId))).go();
      await (_db.delete(
        _db.localSuppliers,
      )..where((r) => r.tenantId.equals(tenantId))).go();
      await (_db.delete(
        _db.localProducts,
      )..where((r) => r.tenantId.equals(tenantId))).go();
      await (_db.delete(
        _db.localEmployees,
      )..where((r) => r.tenantId.equals(tenantId))).go();
      await (_db.delete(
        _db.localAccounts,
      )..where((r) => r.tenantId.equals(tenantId))).go();
      await (_db.delete(
        _db.localInvoices,
      )..where((r) => r.tenantId.equals(tenantId))).go();
      await (_db.delete(
        _db.localInvoiceItems,
      )..where((r) => r.tenantId.equals(tenantId))).go();
      await (_db.delete(
        _db.localPayments,
      )..where((r) => r.tenantId.equals(tenantId))).go();
      await (_db.delete(
        _db.localCommissionDues,
      )..where((r) => r.tenantId.equals(tenantId))).go();
      await (_db.delete(
        _db.localJournalEntries,
      )..where((r) => r.tenantId.equals(tenantId))).go();
      await (_db.delete(
        _db.localEmployeeMovements,
      )..where((r) => r.tenantId.equals(tenantId))).go();
      await (_db.delete(
        _db.localSalaries,
      )..where((r) => r.tenantId.equals(tenantId))).go();
      await (_db.delete(
        _db.syncQueueItems,
      )..where((r) => r.tenantId.equals(tenantId))).go();
      // Schema 5: id_mappings is tenant-scoped, so it is finally clearable.
      // A stale mapping is not harmless -- it resolves a fresh local row to a
      // server row belonging to a session that has ended.
      await (_db.delete(
        _db.idMappings,
      )..where((r) => r.tenantId.equals(tenantId))).go();
      await (_db.delete(
        _db.reportCacheEntries,
      )..where((r) => r.tenantId.equals(tenantId))).go();
    });

    return ClearTenantReport(
      cleared: true,
      pendingQueueItems: pendingQueueItems,
      unsyncedMirrorRows: unsyncedMirrorRows,
    );
  }

  /// Queued writes for [tenantId] that have not yet reached the server.
  Future<int> _countPendingQueue(String tenantId) async {
    final count = _db.syncQueueItems.id.count();
    final query = _db.selectOnly(_db.syncQueueItems)
      ..addColumns([count])
      ..where(
        _db.syncQueueItems.tenantId.equals(tenantId) &
            _db.syncQueueItems.status.isIn(['pending', 'staged']),
      );
    return (await query.getSingle()).read(count) ?? 0;
  }

  /// Mirror rows for [tenantId] still flagged `synced: false`.
  ///
  /// `local_accounts` is deliberately absent: schema 4 gives it no `synced`
  /// column (account writes are not exposed offline yet) and it is fully
  /// re-derivable from the server chart, so it is not "work at risk".
  /// `id_mappings` is global (no `tenant_id`) and also not tenant-scoped.
  Future<int> _countUnsyncedMirror(String tenantId) async {
    final c = _db;
    final lists = await Future.wait([
      (c.select(
            c.localCustomers,
          )..where((r) => r.tenantId.equals(tenantId) & r.synced.equals(false)))
          .get(),
      (c.select(
            c.localSuppliers,
          )..where((r) => r.tenantId.equals(tenantId) & r.synced.equals(false)))
          .get(),
      (c.select(
            c.localProducts,
          )..where((r) => r.tenantId.equals(tenantId) & r.synced.equals(false)))
          .get(),
      (c.select(
            c.localEmployees,
          )..where((r) => r.tenantId.equals(tenantId) & r.synced.equals(false)))
          .get(),
      (c.select(
            c.localInvoices,
          )..where((r) => r.tenantId.equals(tenantId) & r.synced.equals(false)))
          .get(),
      (c.select(
            c.localPayments,
          )..where((r) => r.tenantId.equals(tenantId) & r.synced.equals(false)))
          .get(),
      (c.select(
            c.localJournalEntries,
          )..where((r) => r.tenantId.equals(tenantId) & r.synced.equals(false)))
          .get(),
      (c.select(
            c.localEmployeeMovements,
          )..where((r) => r.tenantId.equals(tenantId) & r.synced.equals(false)))
          .get(),
      (c.select(
            c.localSalaries,
          )..where((r) => r.tenantId.equals(tenantId) & r.synced.equals(false)))
          .get(),
    ]);
    return lists.fold<int>(0, (sum, rows) => sum + rows.length);
  }

  @override
  Future<bool> hasUnsyncedCustomers(String tenantId) async {
    return (_db.select(_db.localCustomers)
          ..where((r) => r.tenantId.equals(tenantId) & r.synced.equals(false))
          ..limit(1))
        .get()
        .then((rows) => rows.isNotEmpty);
  }

  @override
  Future<bool> hasUnsyncedSuppliers(String tenantId) async {
    return (_db.select(_db.localSuppliers)
          ..where((r) => r.tenantId.equals(tenantId) & r.synced.equals(false))
          ..limit(1))
        .get()
        .then((rows) => rows.isNotEmpty);
  }

  @override
  Future<bool> hasUnsyncedProducts(String tenantId) async {
    return (_db.select(_db.localProducts)
          ..where((r) => r.tenantId.equals(tenantId) & r.synced.equals(false))
          ..limit(1))
        .get()
        .then((rows) => rows.isNotEmpty);
  }

  @override
  Future<bool> hasUnsyncedEmployees(String tenantId) async {
    return (_db.select(_db.localEmployees)
          ..where((r) => r.tenantId.equals(tenantId) & r.synced.equals(false))
          ..limit(1))
        .get()
        .then((rows) => rows.isNotEmpty);
  }

  @override
  Future<bool> hasUnsyncedInvoices(String tenantId) async {
    return (_db.select(_db.localInvoices)
          ..where((r) => r.tenantId.equals(tenantId) & r.synced.equals(false))
          ..limit(1))
        .get()
        .then((rows) => rows.isNotEmpty);
  }

  @override
  Future<bool> hasUnsyncedPayments(String tenantId) async {
    return (_db.select(_db.localPayments)
          ..where((r) => r.tenantId.equals(tenantId) & r.synced.equals(false))
          ..limit(1))
        .get()
        .then((rows) => rows.isNotEmpty);
  }

  @override
  Future<bool> hasUnsyncedJournalEntries(String tenantId) async {
    return (_db.select(_db.localJournalEntries)
          ..where((r) => r.tenantId.equals(tenantId) & r.synced.equals(false))
          ..limit(1))
        .get()
        .then((rows) => rows.isNotEmpty);
  }

  @override
  Future<bool> hasUnsyncedEmployeeMovements(String tenantId) async {
    return (_db.select(_db.localEmployeeMovements)
          ..where((r) => r.tenantId.equals(tenantId) & r.synced.equals(false))
          ..limit(1))
        .get()
        .then((rows) => rows.isNotEmpty);
  }

  @override
  Future<bool> hasUnsyncedSalaries(String tenantId) async {
    return (_db.select(_db.localSalaries)
          ..where((r) => r.tenantId.equals(tenantId) & r.synced.equals(false))
          ..limit(1))
        .get()
        .then((rows) => rows.isNotEmpty);
  }

  @override
  Future<bool> hasUnsyncedAccounts(String tenantId) async {
    // Account writes are not exposed offline in Phase 1A, so there is no
    // `accounts.synced` column to read yet. The authoritative "the server has
    // not seen a local account change" signal is the sync queue itself: any
    // pending/staged account leg means a local change is still in flight and a
    // background chart refresh must not clobber it.
    final rows =
        await (_db.select(_db.syncQueueItems)
              ..where(
                (r) =>
                    r.tenantId.equals(tenantId) &
                    r.entity.equals('accounts') &
                    r.status.isIn(['pending', 'staged']),
              )
              ..limit(1))
            .get();
    return rows.isNotEmpty;
  }

  @override
  Future<void> dispose() => _db.close();

  /// Applies a server snapshot to a mirror table WITHOUT destroying
  /// locally-authored rows the server has not seen yet.
  ///
  /// The naive mirror is `delete(tenant) + insert(snapshot)`, which is a
  /// data-loss bug the moment a write is pending: a background refresh landing
  /// between an offline create and its replay silently deleted the user's
  /// record, and the queue leg then replayed an invoice naming a customer that
  /// no longer existed locally. The rule is **local pending work is
  /// authoritative** until the server acknowledges it:
  ///
  ///  - `synced: false` rows are left completely alone (not deleted, not
  ///    overwritten by a stale server copy);
  ///  - `synced: true` rows are deleted and replaced, because the server copy
  ///    is now the truth for them;
  ///  - an incoming server row whose id matches a preserved local row is
  ///    skipped, so an offline EDIT of an existing row is not reverted by a
  ///    refresh that happened before the edit synced.
  Future<void> _mirrorPreservingUnsynced<T extends DataClass>({
    required List<T> serverRows,
    required String Function(T row) idOf,
    required Future<Set<String>> Function() readPendingIds,
    required Future<void> Function() deleteSynced,
    required Future<void> Function(List<T> rows) insertAll,
  }) => _db.transaction(() async {
    // The pending rows are NOT deleted by `deleteSynced`, so they are still
    // in the table and must not be inserted again -- only their ids matter,
    // to decide whether the server's stale copy of the same row may land.
    final pendingIds = await readPendingIds();

    await deleteSynced();

    final incoming = <T>[
      for (final r in serverRows)
        if (!pendingIds.contains(idOf(r))) r,
    ];
    if (incoming.isNotEmpty) await insertAll(incoming);
  });
}

/// Composition root: opens the store once (native hosts) or a no-op store.
final localStoreProvider = FutureProvider<LocalStore>((ref) async {
  final stopwatch = Stopwatch()..start();
  final store = await openLocalStore();
  ref.onDispose(() => store.dispose());
  stopwatch.stop();
  // Measured, not assumed: the app gates its first frame on this future, so a
  // slow open is a slow splash. Logged so that path is measurable on a real
  // device rather than guessed at.
  debugPrint(
    '[offline:store] opened in ${stopwatch.elapsedMilliseconds}ms '
    '(available: ${store.isAvailable})',
  );
  return store;
});

/// Opens the local store and forces the schema to materialize NOW.
///
/// ## The loud-failure contract (cold-start data blackout fix)
///
/// The open (`openAppDatabase`) is lazy on native — `createInBackground` defers
/// the actual file open, so a corrupt `hasad_offline.sqlite` or a failing
/// migration (e.g. the schema 4 → 5 `id_mappings` rebuild) would otherwise
/// surface mid-read as a generic screen error, and an open that fails at
/// construction would resolve the gate to `NullLocalStore` — a silent total
/// data blackout indistinguishable from "the user has no cache". Three rules:
///
/// 1. A null open on native is a real failure and is thrown, never a silent
///    `NullLocalStore` (only the web stub legitimately returns null).
/// 2. The first drift query (schema `createAll` / `onUpgrade`) runs here, so a
///    corrupt file or failing migration errors the gate loudly.
/// 3. The failure is wrapped as [LocalStoreOpenException] with the directory
///    tried and the original error, which the app gate renders as the Arabic
///    repair state (retry + explicit destructive reset — never an auto-delete).
Future<LocalStore> openLocalStore({String? overrideDirectory}) async {
  final appDb = await openAppDatabase(overrideDirectory: overrideDirectory);
  if (appDb == null && !kIsWeb) {
    throw const LocalStoreOpenException(
      'database open failed (null) — refusing to silently degrade',
    );
  }
  final store = appDb != null ? DriftLocalStore(appDb) : const NullLocalStore();
  if (appDb != null) {
    try {
      // First query materializes createAll / onUpgrade. Return value is
      // irrelevant (a cache miss for the probe key is the normal case).
      await store.report('__offline_probe__', '__offline_probe__');
    } on Object catch (error, stack) {
      final directory =
          overrideDirectory ?? '<getApplicationDocumentsDirectory>';
      debugPrint(
        '[offline:store] OPEN FAILED — rendering repair state.\n'
        'directory: $directory\n$error\n$stack',
      );
      // Release the half-opened connection before surfacing the error. A
      // desktop host cannot delete/replace the sqlite file while the probe's
      // open handle is still live, and the reset action needs to do exactly
      // that. The failure is reported regardless; a wedged connection is
      // abandoned and the retry opens a fresh one.
      try {
        await store.dispose();
      } on Object catch (_) {}
      throw LocalStoreOpenException('directory: $directory\n$error\n$stack');
    }
  }
  return store;
}

/// Injectable seam for the "Reset local data" action: deletes the on-disc
/// sqlite file. Overridable in tests. The default calls the native factory.
/// The caller (repair UI) must dispose the live drift connection before this —
/// desktop hosts cannot delete an open sqlite file — and must warn the user
/// that all unsynced local work is destroyed before invoking.
final resetLocalDatabaseProvider = Provider<Future<void> Function()>((ref) {
  return resetLocalDatabase;
});
