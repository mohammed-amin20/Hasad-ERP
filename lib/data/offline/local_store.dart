import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'local_database.dart';
import 'offline_factory.dart';

/// A cached report envelope plus when it was stored (freshness indicator).
class CachedReportData {
  const CachedReportData({required this.payload, required this.fetchedAt});

  final String payload;
  final DateTime fetchedAt;
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
  Future<void> markSynced(String id);
  Future<void> markFailed(String id, String error);

  Future<String?> serverIdFor(String entity, String localId);
  Future<String?> localIdFor(String entity, String serverId);
  Future<void> putMapping({
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

  Future<void> clearTenant(String tenantId);

  Future<void> dispose();
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
  Future<void> markSynced(String id) async {}

  @override
  Future<void> markFailed(String id, String error) async {}

  @override
  Future<String?> serverIdFor(String entity, String localId) async => localId;

  @override
  Future<String?> localIdFor(String entity, String serverId) async => serverId;

  @override
  Future<void> putMapping({
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
  Future<void> clearTenant(String tenantId) async {}

  @override
  Future<void> dispose() async {}
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
      _mirror(
        clear: () => (_db.delete(_db.localCustomers)
              ..where((r) => r.tenantId.equals(tenantId)))
            .go(),
        insert: () async {
          if (rows.isNotEmpty) {
            await _db.batch((b) => b.insertAll(_db.localCustomers, rows));
          }
        },
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
      _mirror(
        clear: () => (_db.delete(_db.localSuppliers)
              ..where((r) => r.tenantId.equals(tenantId)))
            .go(),
        insert: () async {
          if (rows.isNotEmpty) {
            await _db.batch((b) => b.insertAll(_db.localSuppliers, rows));
          }
        },
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
      _mirror(
        clear: () => (_db.delete(_db.localProducts)
              ..where((r) => r.tenantId.equals(tenantId)))
            .go(),
        insert: () async {
          if (rows.isNotEmpty) {
            await _db.batch((b) => b.insertAll(_db.localProducts, rows));
          }
        },
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
      _mirror(
        clear: () => (_db.delete(_db.localEmployees)
              ..where((r) => r.tenantId.equals(tenantId)))
            .go(),
        insert: () async {
          if (rows.isNotEmpty) {
            await _db.batch((b) => b.insertAll(_db.localEmployees, rows));
          }
        },
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
  Future<void> mirrorAccounts(String tenantId, List<LocalAccountRow> rows) =>
      _mirror(
        clear: () => (_db.delete(_db.localAccounts)
              ..where((r) => r.tenantId.equals(tenantId)))
            .go(),
        insert: () async {
          if (rows.isNotEmpty) {
            await _db.batch((b) => b.insertAll(_db.localAccounts, rows));
          }
        },
      );

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
  Future<String?> serverIdFor(String entity, String localId) async {
    final row = await (_db.select(_db.idMappings)
          ..where((r) => r.entity.equals(entity) & r.localId.equals(localId)))
        .getSingleOrNull();
    return row?.serverId;
  }

  @override
  Future<String?> localIdFor(String entity, String serverId) async {
    final row = await (_db.select(_db.idMappings)
          ..where((r) => r.entity.equals(entity) & r.serverId.equals(serverId)))
        .getSingleOrNull();
    return row?.localId;
  }

  @override
  Future<void> putMapping({
    required String entity,
    required String localId,
    required String serverId,
  }) =>
      _db.into(_db.idMappings).insert(
            IdMappingsCompanion.insert(
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
  Future<void> clearTenant(String tenantId) async {
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
      await (_db.delete(_db.reportCacheEntries)
            ..where((r) => r.tenantId.equals(tenantId)))
          .go();
    });
  }

  @override
  Future<void> dispose() => _db.close();

  Future<void> _mirror({
    required Future<void> Function() clear,
    required Future<void> Function() insert,
  }) async {
    await _db.transaction(() async {
      await clear();
      await insert();
    });
  }
}

/// Composition root: opens the store once (native hosts) or a no-op store.
final localStoreProvider = FutureProvider<LocalStore>((ref) async {
  final appDb = await openAppDatabase();
  final store = appDb != null ? DriftLocalStore(appDb) : const NullLocalStore();
  ref.onDispose(() => store.dispose());
  return store;
});