import 'package:hasad_erp/data/offline/local_database.dart';
import 'package:hasad_erp/data/offline/local_store.dart';

/// Forwards every [LocalStore] call to [inner], so a test can override exactly
/// one method and inherit the rest.
///
/// Dart's `implements` cannot forward automatically — a class that declares any
/// member must implement all of them, and `noSuchMethod` is never reached for
/// the declared ones. This explicit forwarder is the supported way to build a
/// partial double, and it also keeps the double compiling when [LocalStore]
/// grows a method: the compiler flags the missing forwarder at build time
/// instead of the test failing at runtime.
///
/// Subclass it and override the one method under test.
class DelegatingLocalStore implements LocalStore {
  DelegatingLocalStore(this.inner);

  final LocalStore inner;

  @override
  bool get isAvailable => inner.isAvailable;

  @override
  AppDatabase get db => inner.db;

  // ---- master data -------------------------------------------------

  @override
  Future<List<LocalCustomerRow>> customers(String tenantId) =>
      inner.customers(tenantId);

  @override
  Future<void> mirrorCustomers(String tenantId, List<LocalCustomerRow> rows) =>
      inner.mirrorCustomers(tenantId, rows);

  @override
  Future<void> upsertCustomer(LocalCustomerRow row) => inner.upsertCustomer(row);

  @override
  Future<List<LocalSupplierRow>> suppliers(String tenantId) =>
      inner.suppliers(tenantId);

  @override
  Future<void> mirrorSuppliers(String tenantId, List<LocalSupplierRow> rows) =>
      inner.mirrorSuppliers(tenantId, rows);

  @override
  Future<void> upsertSupplier(LocalSupplierRow row) => inner.upsertSupplier(row);

  @override
  Future<List<LocalProductRow>> products(String tenantId) =>
      inner.products(tenantId);

  @override
  Future<void> mirrorProducts(String tenantId, List<LocalProductRow> rows) =>
      inner.mirrorProducts(tenantId, rows);

  @override
  Future<void> upsertProduct(LocalProductRow row) => inner.upsertProduct(row);

  @override
  Future<List<LocalEmployeeRow>> employees(String tenantId) =>
      inner.employees(tenantId);

  @override
  Future<void> mirrorEmployees(String tenantId, List<LocalEmployeeRow> rows) =>
      inner.mirrorEmployees(tenantId, rows);

  @override
  Future<void> upsertEmployee(LocalEmployeeRow row) => inner.upsertEmployee(row);

  @override
  Future<List<LocalAccountRow>> accounts(String tenantId) =>
      inner.accounts(tenantId);

  @override
  Future<void> mirrorAccounts(String tenantId, List<LocalAccountRow> rows) =>
      inner.mirrorAccounts(tenantId, rows);

  @override
  Future<void> upsertAccount(LocalAccountRow row) => inner.upsertAccount(row);

  @override
  Future<List<LocalAccountRow>> ensureBaselineChart(String tenantId) =>
      inner.ensureBaselineChart(tenantId);

  // ---- financial ----------------------------------------------------

  @override
  Future<List<LocalInvoiceRow>> invoices(String tenantId, {String? type}) =>
      inner.invoices(tenantId, type: type);

  @override
  Future<void> upsertInvoice(LocalInvoiceRow row) => inner.upsertInvoice(row);

  @override
  Future<void> deleteInvoice(String tenantId, String id) =>
      inner.deleteInvoice(tenantId, id);

  @override
  Future<LocalInvoiceRow?> invoice(String tenantId, String id) =>
      inner.invoice(tenantId, id);

  @override
  Future<void> mirrorInvoices(String tenantId, List<LocalInvoiceRow> rows) =>
      inner.mirrorInvoices(tenantId, rows);

  @override
  Future<void> clearInvoiceMoneyMarker(String tenantId, String legId) =>
      inner.clearInvoiceMoneyMarker(tenantId, legId);

  @override
  Future<void> resolveInvoiceMoneyMarker(String tenantId, String legId) =>
      inner.resolveInvoiceMoneyMarker(tenantId, legId);

  @override
  Future<List<LocalInvoiceItemRow>> invoiceItems(
    String tenantId,
    String invoiceId,
  ) =>
      inner.invoiceItems(tenantId, invoiceId);

  @override
  Future<void> upsertInvoiceItems(List<LocalInvoiceItemRow> rows) =>
      inner.upsertInvoiceItems(rows);

  @override
  Future<void> mirrorInvoiceItems(
    String tenantId,
    String invoiceId,
    List<LocalInvoiceItemRow> rows,
  ) =>
      inner.mirrorInvoiceItems(tenantId, invoiceId, rows);

  @override
  Future<void> upsertPayment(LocalPaymentRow row) => inner.upsertPayment(row);

  @override
  Future<List<LocalPaymentRow>> payments(String tenantId) =>
      inner.payments(tenantId);

  @override
  Future<List<LocalCommissionDueRow>> commissionDues(
    String tenantId, {
    String? supplierId,
  }) =>
      inner.commissionDues(tenantId, supplierId: supplierId);

  @override
  Future<void> upsertCommissionDue(LocalCommissionDueRow row) =>
      inner.upsertCommissionDue(row);

  @override
  Future<void> insertJournalEntry(LocalJournalEntryRow row) =>
      inner.insertJournalEntry(row);

  @override
  Future<List<LocalJournalEntryRow>> journalEntries(String tenantId) =>
      inner.journalEntries(tenantId);

  @override
  Future<List<LocalEmployeeMovementRow>> employeeMovements(
    String tenantId, {
    String? employeeId,
  }) =>
      inner.employeeMovements(tenantId, employeeId: employeeId);

  @override
  Future<void> upsertEmployeeMovement(LocalEmployeeMovementRow row) =>
      inner.upsertEmployeeMovement(row);

  @override
  Future<List<LocalSalaryRow>> salaries(String tenantId, {String? employeeId}) =>
      inner.salaries(tenantId, employeeId: employeeId);

  @override
  Future<void> upsertSalary(LocalSalaryRow row) => inner.upsertSalary(row);

  // ---- sync -----------------------------------------------------------

  @override
  Future<void> enqueue(SyncQueueRow row) => inner.enqueue(row);

  @override
  Future<List<SyncQueueRow>> pendingSync(String tenantId) =>
      inner.pendingSync(tenantId);

  @override
  Future<int> pendingCount(String tenantId) => inner.pendingCount(tenantId);

  @override
  Future<Map<String, String>> queueStatuses(String tenantId) =>
      inner.queueStatuses(tenantId);

  @override
  Future<List<SyncQueueRow>> queueLegsFor(
    String tenantId, {
    String? entity,
  }) => inner.queueLegsFor(tenantId, entity: entity);

  @override
  Future<Set<String>> pendingDeleteIds(String tenantId, String entity) =>
      inner.pendingDeleteIds(tenantId, entity);

  @override
  Future<void> removeMirrorRows(
    String tenantId,
    String entity,
    List<String> ids,
  ) => inner.removeMirrorRows(tenantId, entity, ids);

  @override
  Future<Set<String>> invoiceIdsWithDurableItems(
    String tenantId,
    List<String> invoiceIds,
  ) =>
      inner.invoiceIdsWithDurableItems(tenantId, invoiceIds);

  @override
  Future<T> transaction<T>(Future<T> Function(LocalStore store) action) =>
      // `this`, not `inner`: a subclass override (e.g. a poisoned `enqueue`)
      // must stay enlisted in the caller's transaction.
      inner.transaction((_) => action(this));

  @override
  Future<void> markSynced(String id) => inner.markSynced(id);

  @override
  Future<void> markFailed(String id, String error) => inner.markFailed(id, error);

  @override
  Future<void> requeueRetry(String id, String error, int attempts) =>
      inner.requeueRetry(id, error, attempts);

  @override
  Future<void> markReplaySynced({
    required String tenantId,
    required String entity,
    required String localId,
    String? serverId,
    String? officialNo,
  }) =>
      inner.markReplaySynced(
        tenantId: tenantId,
        entity: entity,
        localId: localId,
        serverId: serverId,
        officialNo: officialNo,
      );

  @override
  Future<String?> serverIdFor(String tenantId, String entity, String localId) =>
      inner.serverIdFor(tenantId, entity, localId);

  @override
  Future<String?> localIdFor(String tenantId, String entity, String serverId) =>
      inner.localIdFor(tenantId, entity, serverId);

  @override
  Future<void> putMapping({
    required String tenantId,
    required String entity,
    required String localId,
    required String serverId,
  }) =>
      inner.putMapping(
        tenantId: tenantId,
        entity: entity,
        localId: localId,
        serverId: serverId,
      );

  // ---- cache & settings ------------------------------------------------

  @override
  Future<void> putReport(String tenantId, String key, String payload) =>
      inner.putReport(tenantId, key, payload);

  @override
  Future<String?> report(String tenantId, String key) =>
      inner.report(tenantId, key);

  @override
  Future<CachedReportData?> cachedReport(String tenantId, String key) =>
      inner.cachedReport(tenantId, key);

  @override
  Future<void> putSetting(String tenantId, String key, String? value) =>
      inner.putSetting(tenantId, key, value);

  @override
  Future<String?> getSetting(String tenantId, String key) =>
      inner.getSetting(tenantId, key);

  // ---- offline user profile (M13 Phase 0) ---------------------------------

  @override
  Future<void> putUserProfile(String authUid, String payload) =>
      inner.putUserProfile(authUid, payload);

  @override
  Future<LocalUserProfileRow?> getUserProfile(String authUid) =>
      inner.getUserProfile(authUid);

  @override
  Future<void> deleteUserProfile(String authUid) =>
      inner.deleteUserProfile(authUid);

  // ---- lifecycle ----------------------------------------------------------

  @override
  Future<bool> hasUnsyncedCustomers(String tenantId) =>
      inner.hasUnsyncedCustomers(tenantId);

  @override
  Future<bool> hasUnsyncedSuppliers(String tenantId) =>
      inner.hasUnsyncedSuppliers(tenantId);

  @override
  Future<bool> hasUnsyncedProducts(String tenantId) =>
      inner.hasUnsyncedProducts(tenantId);

  @override
  Future<bool> hasUnsyncedEmployees(String tenantId) =>
      inner.hasUnsyncedEmployees(tenantId);

  @override
  Future<bool> hasUnsyncedInvoices(String tenantId) =>
      inner.hasUnsyncedInvoices(tenantId);

  @override
  Future<bool> hasUnsyncedPayments(String tenantId) =>
      inner.hasUnsyncedPayments(tenantId);

  @override
  Future<bool> hasUnsyncedJournalEntries(String tenantId) =>
      inner.hasUnsyncedJournalEntries(tenantId);

  @override
  Future<bool> hasUnsyncedEmployeeMovements(String tenantId) =>
      inner.hasUnsyncedEmployeeMovements(tenantId);

  @override
  Future<bool> hasUnsyncedSalaries(String tenantId) =>
      inner.hasUnsyncedSalaries(tenantId);

  @override
  Future<bool> hasUnsyncedAccounts(String tenantId) =>
      inner.hasUnsyncedAccounts(tenantId);

  @override
  Future<ClearTenantReport> clearTenant(String tenantId, {bool force = false}) =>
      inner.clearTenant(tenantId, force: force);

  @override
  Future<void> dispose() => inner.dispose();
}
