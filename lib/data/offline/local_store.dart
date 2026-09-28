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

  Future<List<LocalInvoiceRow>> invoices(String tenantId, {String? type});
  Future<void> upsertInvoice(LocalInvoiceRow row);
  Future<void> deleteInvoice(String id);

  Future<List<LocalInvoiceItemRow>> invoiceItems(String invoiceId);
  Future<void> upsertInvoiceItems(List<LocalInvoiceItemRow> rows);

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
  Future<List<SyncQueueRow>> queueLegsFor(
    String tenantId, {
    String? entity,
  });

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
  Future<ClearTenantReport> clearTenant(String tenantId,
      {bool force = false});

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
  Future<void> mirrorCustomers(String tenantId, List<LocalCustomerRow> rows) async {}

  @override
  Future<void> upsertCustomer(LocalCustomerRow row) async {}

  @override
  Future<List<LocalSupplierRow>> suppliers(String tenantId) async => const [];

  @override
  Future<void> mirrorSuppliers(String tenantId, List<LocalSupplierRow> rows) async {}

  @override
  Future<void> upsertSupplier(LocalSupplierRow row) async {}

  @override
  Future<List<LocalProductRow>> products(String tenantId) async => const [];

  @override
  Future<void> mirrorProducts(String tenantId, List<LocalProductRow> rows) async {}

  @override
  Future<void> upsertProduct(LocalProductRow row) async {}

  @override
  Future<List<LocalEmployeeRow>> employees(String tenantId) async => const [];

  @override
  Future<void> mirrorEmployees(String tenantId, List<LocalEmployeeRow> rows) async {}

  @override
  Future<void> upsertEmployee(LocalEmployeeRow row) async {}

  @override
  Future<List<LocalAccountRow>> accounts(String tenantId) async => const [];

  @override
  Future<void> mirrorAccounts(String tenantId, List<LocalAccountRow> rows) async {}

  @override
  Future<void> upsertAccount(LocalAccountRow row) async {}

  @override
  Future<List<LocalAccountRow>> ensureBaselineChart(String tenantId) async =>
      const [];

  @override
  Future<List<LocalInvoiceRow>> invoices(String tenantId, {String? type}) async =>
      const [];

  @override
  Future<void> upsertInvoice(LocalInvoiceRow row) async {}

  @override
  Future<void> deleteInvoice(String id) async {}

  @override
  Future<List<LocalInvoiceItemRow>> invoiceItems(String invoiceId) async =>
      const [];

  @override
  Future<void> upsertInvoiceItems(List<LocalInvoiceItemRow> rows) async {}

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
  Future<List<LocalSalaryRow>> salaries(String tenantId, {String? employeeId}) async =>
      const [];

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
          String tenantId, String entity, String localId) async =>
      localId;

  @override
  Future<String?> localIdFor(
          String tenantId, String entity, String serverId) async =>
      serverId;

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
  Future<ClearTenantReport> clearTenant(String tenantId,
      {bool force = false}) async =>
      const ClearTenantReport(
          cleared: true, pendingQueueItems: 0, unsyncedMirrorRows: 0);

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
  Future<List<LocalCustomerRow>> customers(String tenantId) =>
      (_db.select(_db.localCustomers)
            ..where((r) => r.tenantId.equals(tenantId)))
          .get();

  @override
  Future<void> mirrorCustomers(String tenantId, List<LocalCustomerRow> rows) =>
      _mirrorPreservingUnsynced<LocalCustomerRow>(
        serverRows: rows,
        idOf: (r) => r.id,
        readPendingIds: () async => {
              for (final r in await (_db.select(_db.localCustomers)
                    ..where((r) =>
                        r.tenantId.equals(tenantId) & r.synced.equals(false)))
                  .get())
                r.id
            },
        deleteSynced: () => (_db.delete(_db.localCustomers)
              ..where((r) => r.tenantId.equals(tenantId) & r.synced.equals(true)))
            .go(),
        insertAll: (rs) => _db.batch((b) => b.insertAll(_db.localCustomers, rs)),
      );

  @override
  Future<void> upsertCustomer(LocalCustomerRow row) => _db
      .into(_db.localCustomers)
      .insert(row, mode: InsertMode.insertOrReplace);

  @override
  Future<List<LocalSupplierRow>> suppliers(String tenantId) =>
      (_db.select(_db.localSuppliers)
            ..where((r) => r.tenantId.equals(tenantId)))
          .get();

  @override
  Future<void> mirrorSuppliers(String tenantId, List<LocalSupplierRow> rows) =>
      _mirrorPreservingUnsynced<LocalSupplierRow>(
        serverRows: rows,
        idOf: (r) => r.id,
        readPendingIds: () async => {
              for (final r in await (_db.select(_db.localSuppliers)
                    ..where((r) =>
                        r.tenantId.equals(tenantId) & r.synced.equals(false)))
                  .get())
                r.id
            },
        deleteSynced: () => (_db.delete(_db.localSuppliers)
              ..where((r) => r.tenantId.equals(tenantId) & r.synced.equals(true)))
            .go(),
        insertAll: (rs) => _db.batch((b) => b.insertAll(_db.localSuppliers, rs)),
      );

  @override
  Future<void> upsertSupplier(LocalSupplierRow row) => _db
      .into(_db.localSuppliers)
      .insert(row, mode: InsertMode.insertOrReplace);

  @override
  Future<List<LocalProductRow>> products(String tenantId) =>
      (_db.select(_db.localProducts)
            ..where((r) => r.tenantId.equals(tenantId)))
          .get();

  @override
  Future<void> mirrorProducts(String tenantId, List<LocalProductRow> rows) =>
      _mirrorPreservingUnsynced<LocalProductRow>(
        serverRows: rows,
        idOf: (r) => r.id,
        readPendingIds: () async => {
              for (final r in await (_db.select(_db.localProducts)
                    ..where((r) =>
                        r.tenantId.equals(tenantId) & r.synced.equals(false)))
                  .get())
                r.id
            },
        deleteSynced: () => (_db.delete(_db.localProducts)
              ..where((r) => r.tenantId.equals(tenantId) & r.synced.equals(true)))
            .go(),
        insertAll: (rs) => _db.batch((b) => b.insertAll(_db.localProducts, rs)),
      );

  @override
  Future<void> upsertProduct(LocalProductRow row) => _db
      .into(_db.localProducts)
      .insert(row, mode: InsertMode.insertOrReplace);

  @override
  Future<List<LocalEmployeeRow>> employees(String tenantId) =>
      (_db.select(_db.localEmployees)
            ..where((r) => r.tenantId.equals(tenantId)))
          .get();

  @override
  Future<void> mirrorEmployees(String tenantId, List<LocalEmployeeRow> rows) =>
      _mirrorPreservingUnsynced<LocalEmployeeRow>(
        serverRows: rows,
        idOf: (r) => r.id,
        readPendingIds: () async => {
              for (final r in await (_db.select(_db.localEmployees)
                    ..where((r) =>
                        r.tenantId.equals(tenantId) & r.synced.equals(false)))
                  .get())
                r.id
            },
        deleteSynced: () => (_db.delete(_db.localEmployees)
              ..where((r) => r.tenantId.equals(tenantId) & r.synced.equals(true)))
            .go(),
        insertAll: (rs) => _db.batch((b) => b.insertAll(_db.localEmployees, rs)),
      );

  @override
  Future<void> upsertEmployee(LocalEmployeeRow row) => _db
      .into(_db.localEmployees)
      .insert(row, mode: InsertMode.insertOrReplace);

  @override
  Future<List<LocalAccountRow>> accounts(String tenantId) =>
      (_db.select(_db.localAccounts)
            ..where((r) => r.tenantId.equals(tenantId)))
          .get();

  @override
  Future<void> mirrorAccounts(String tenantId, List<LocalAccountRow> rows) async {
    // Never let a background/online refresh destroy locally-modified accounts
    // that the server has not seen yet. If any `synced=false` row exists for
    // this tenant, skip the destructive clear-and-replace entirely.
    final hasUnsynced = await hasUnsyncedAccounts(tenantId);
    if (hasUnsynced) return;
    await _db.transaction(() async {
      await (_db.delete(_db.localAccounts)
            ..where((r) => r.tenantId.equals(tenantId)))
          .go();
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
  Future<void> upsertAccount(LocalAccountRow row) => _db
      .into(_db.localAccounts)
      .insert(row, mode: InsertMode.insertOrReplace);

  // ---- financial ----------------------------------------------------

  @override
  Future<List<LocalInvoiceRow>> invoices(String tenantId, {String? type}) =>
      (_db.select(_db.localInvoices)
            ..where((r) => type == null
                ? r.tenantId.equals(tenantId)
                : r.tenantId.equals(tenantId) & r.type.equals(type)))
          .get();

  @override
  Future<void> upsertInvoice(LocalInvoiceRow row) =>
      _db.into(_db.localInvoices).insert(row, mode: InsertMode.insertOrReplace);

  @override
  Future<void> deleteInvoice(String id) async {
    await (_db.delete(_db.localInvoiceItems)
          ..where((r) => r.invoiceId.equals(id)))
        .go();
    await (_db.delete(_db.localInvoices)
          ..where((r) => r.id.equals(id)))
        .go();
  }

  @override
  Future<List<LocalInvoiceItemRow>> invoiceItems(String invoiceId) =>
      (_db.select(_db.localInvoiceItems)
            ..where((r) => r.invoiceId.equals(invoiceId)))
          .get();

  @override
  Future<void> upsertInvoiceItems(List<LocalInvoiceItemRow> rows) async {
    if (rows.isEmpty) return;
    await _db.batch((b) => b.insertAll(_db.localInvoiceItems, rows, mode: InsertMode.insertOrReplace));
  }

  @override
  Future<void> upsertPayment(LocalPaymentRow row) =>
      _db.into(_db.localPayments).insert(row, mode: InsertMode.insertOrReplace);

  @override
  Future<List<LocalPaymentRow>> payments(String tenantId) =>
      (_db.select(_db.localPayments)
            ..where((r) => r.tenantId.equals(tenantId)))
          .get();

  @override
  Future<List<LocalCommissionDueRow>> commissionDues(
    String tenantId, {
    String? supplierId,
  }) =>
      (_db.select(_db.localCommissionDues)
            ..where((r) => supplierId == null
                ? r.tenantId.equals(tenantId)
                : r.tenantId.equals(tenantId) & r.supplierId.equals(supplierId)))
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
      (_db.select(_db.localEmployeeMovements)
            ..where((r) => employeeId == null
                ? r.tenantId.equals(tenantId)
                : r.tenantId.equals(tenantId) & r.employeeId.equals(employeeId)))
          .get();

  @override
  Future<void> upsertEmployeeMovement(LocalEmployeeMovementRow row) => _db
      .into(_db.localEmployeeMovements)
      .insert(row, mode: InsertMode.insertOrReplace);

  @override
  Future<List<LocalSalaryRow>> salaries(String tenantId, {String? employeeId}) =>
      (_db.select(_db.localSalaries)
            ..where((r) => employeeId == null
                ? r.tenantId.equals(tenantId)
                : r.tenantId.equals(tenantId) & r.employeeId.equals(employeeId)))
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
            ..where((r) => r.tenantId.equals(tenantId) & r.status.equals('pending'))
            ..orderBy([(r) => OrderingTerm.asc(r.createdAt)]))
          .get();

  @override
  Future<int> pendingCount(String tenantId) async {
    final count = _db
        .customSelect(
          'SELECT COUNT(*) AS c FROM sync_queue_items '
          'WHERE tenant_id = ? AND status = \'pending\'',
          variables: [Variable.withString(tenantId)],
        );
    final row = await count.getSingle();
    return row.read<int>('c');
  }

  @override
  Future<void> markSynced(String id) async {
    await (_db.update(_db.syncQueueItems)
          ..where((r) => r.id.equals(id)))
        .write(SyncQueueItemsCompanion(
          status: const Value('synced'),
          updatedAt: Value(DateTime.now()),
        ));
      }

  @override
  Future<Map<String, String>> queueStatuses(String tenantId) async {
    final rows = await (_db.select(_db.syncQueueItems)
          ..where((r) => r.tenantId.equals(tenantId)))
        .get();
    return {for (final r in rows) r.id: r.status};
  }

  @override
  Future<List<SyncQueueRow>> queueLegsFor(
    String tenantId, {
    String? entity,
  }) {
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
  Future<T> transaction<T>(Future<T> Function(LocalStore store) action) =>
      // Drift's transaction zone is ambient: every query issued through this
      // same `_db` while the callback runs is enlisted in the transaction, so
      // the inner store can be `this` and a throw anywhere rolls back all of it.
      _db.transaction(() => action(this));


  @override
  Future<void> markFailed(String id, String error) async {
    await (_db.update(_db.syncQueueItems)
          ..where((r) => r.id.equals(id)))
        .write(SyncQueueItemsCompanion(
          status: const Value('failed'),
          lastError: Value(error),
          updatedAt: Value(DateTime.now()),
        ));
  }

  @override
  Future<void> requeueRetry(String id, String error, int attempts) async {
    await (_db.update(_db.syncQueueItems)
          ..where((r) => r.id.equals(id)))
        .write(SyncQueueItemsCompanion(
          status: const Value('pending'),
          attempts: Value(attempts),
          lastError: Value(error),
          updatedAt: Value(DateTime.now()),
        ));
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
        await (_db.update(_db.localInvoices)
              ..where((r) => r.id.equals(localId)))
            .write(
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
  Future<String?> serverIdFor(String tenantId, String entity, String localId) async {
    final row = await (_db.select(_db.idMappings)
          ..where((r) =>
              r.tenantId.equals(tenantId) &
              r.entity.equals(entity) &
              r.localId.equals(localId)))
        .getSingleOrNull();
    return row?.serverId;
  }

  @override
  Future<String?> localIdFor(
      String tenantId, String entity, String serverId) async {
    final row = await (_db.select(_db.idMappings)
          ..where((r) =>
              r.tenantId.equals(tenantId) &
              r.entity.equals(entity) &
              r.serverId.equals(serverId)))
        .getSingleOrNull();
    return row?.localId;
  }

  @override
  Future<void> putMapping({
    required String tenantId,
    required String entity,
    required String localId,
    required String serverId,
  }) =>
      _db.into(_db.idMappings).insert(
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
    final row = await (_db.select(_db.reportCacheEntries)
          ..where((r) => r.tenantId.equals(tenantId) & r.key.equals(key)))
        .getSingleOrNull();
    return row?.payload;
  }

  @override
  Future<CachedReportData?> cachedReport(String tenantId, String key) async {
    final row = await (_db.select(_db.reportCacheEntries)
          ..where((r) => r.tenantId.equals(tenantId) & r.key.equals(key)))
        .getSingleOrNull();
    if (row == null) return null;
    return CachedReportData(payload: row.payload, fetchedAt: row.fetchedAt);
  }

  @override
  Future<void> putSetting(String tenantId, String key, String? value) =>
      _db.into(_db.localTenantSettings).insert(
            LocalTenantSettingsCompanion.insert(
              tenantId: tenantId,
              key: key,
              value: Value(value),
            ),
            mode: InsertMode.insertOrReplace,
          );

  @override
  Future<String?> getSetting(String tenantId, String key) async {
    final row = await (_db.select(_db.localTenantSettings)
          ..where((r) => r.tenantId.equals(tenantId) & r.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  @override
  Future<void> putUserProfile(String authUid, String payload) async {
    await _db.into(_db.localUserProfiles).insert(
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
    return (_db.select(_db.localUserProfiles)
          ..where((r) => r.authUid.equals(authUid)))
        .getSingleOrNull();
  }

  @override
  Future<void> deleteUserProfile(String authUid) async {
    await (_db.delete(_db.localUserProfiles)
          ..where((r) => r.authUid.equals(authUid)))
        .go();
  }

  @override
  Future<ClearTenantReport> clearTenant(String tenantId,
      {bool force = false}) async {
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
      await (_db.delete(_db.localCustomers)
            ..where((r) => r.tenantId.equals(tenantId)))
          .go();
      await (_db.delete(_db.localSuppliers)
            ..where((r) => r.tenantId.equals(tenantId)))
          .go();
      await (_db.delete(_db.localProducts)
            ..where((r) => r.tenantId.equals(tenantId)))
          .go();
      await (_db.delete(_db.localEmployees)
            ..where((r) => r.tenantId.equals(tenantId)))
          .go();
      await (_db.delete(_db.localAccounts)
            ..where((r) => r.tenantId.equals(tenantId)))
          .go();
      await (_db.delete(_db.localInvoices)
            ..where((r) => r.tenantId.equals(tenantId)))
          .go();
      await (_db.delete(_db.localInvoiceItems)
            ..where((r) => r.tenantId.equals(tenantId)))
          .go();
      await (_db.delete(_db.localPayments)
            ..where((r) => r.tenantId.equals(tenantId)))
          .go();
      await (_db.delete(_db.localCommissionDues)
            ..where((r) => r.tenantId.equals(tenantId)))
          .go();
      await (_db.delete(_db.localJournalEntries)
            ..where((r) => r.tenantId.equals(tenantId)))
          .go();
      await (_db.delete(_db.localEmployeeMovements)
            ..where((r) => r.tenantId.equals(tenantId)))
          .go();
      await (_db.delete(_db.localSalaries)
            ..where((r) => r.tenantId.equals(tenantId)))
          .go();
      await (_db.delete(_db.syncQueueItems)
            ..where((r) => r.tenantId.equals(tenantId)))
          .go();
      // Schema 5: id_mappings is tenant-scoped, so it is finally clearable.
      // A stale mapping is not harmless -- it resolves a fresh local row to a
      // server row belonging to a session that has ended.
      await (_db.delete(_db.idMappings)
            ..where((r) => r.tenantId.equals(tenantId)))
          .go();
      await (_db.delete(_db.reportCacheEntries)
            ..where((r) => r.tenantId.equals(tenantId)))
          .go();
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
      ..where(_db.syncQueueItems.tenantId.equals(tenantId) &
          _db.syncQueueItems.status.isIn(['pending', 'staged']));
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
      (c.select(c.localCustomers)
            ..where((r) =>
                r.tenantId.equals(tenantId) & r.synced.equals(false)))
          .get(),
      (c.select(c.localSuppliers)
            ..where((r) =>
                r.tenantId.equals(tenantId) & r.synced.equals(false)))
          .get(),
      (c.select(c.localProducts)
            ..where((r) =>
                r.tenantId.equals(tenantId) & r.synced.equals(false)))
          .get(),
      (c.select(c.localEmployees)
            ..where((r) =>
                r.tenantId.equals(tenantId) & r.synced.equals(false)))
          .get(),
      (c.select(c.localInvoices)
            ..where((r) =>
                r.tenantId.equals(tenantId) & r.synced.equals(false)))
          .get(),
      (c.select(c.localPayments)
            ..where((r) =>
                r.tenantId.equals(tenantId) & r.synced.equals(false)))
          .get(),
      (c.select(c.localJournalEntries)
            ..where((r) =>
                r.tenantId.equals(tenantId) & r.synced.equals(false)))
          .get(),
      (c.select(c.localEmployeeMovements)
            ..where((r) =>
                r.tenantId.equals(tenantId) & r.synced.equals(false)))
          .get(),
      (c.select(c.localSalaries)
            ..where((r) =>
                r.tenantId.equals(tenantId) & r.synced.equals(false)))
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
    final rows = await (_db.select(_db.syncQueueItems)
          ..where((r) =>
              r.tenantId.equals(tenantId) &
              r.entity.equals('accounts') &
              r.status.isIn(['pending', 'staged']))
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
  }) =>
      _db.transaction(() async {
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
  final appDb = await openAppDatabase();
  final store = appDb != null ? DriftLocalStore(appDb) : const NullLocalStore();
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