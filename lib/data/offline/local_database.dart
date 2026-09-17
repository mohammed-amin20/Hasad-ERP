import 'package:drift/drift.dart';

part 'local_database.g.dart';

@DataClassName('LocalCustomerRow')
class LocalCustomers extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text()();
  TextColumn get name => text()();
  TextColumn get phone => text().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().nullable()();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('LocalSupplierRow')
class LocalSuppliers extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text()();
  TextColumn get name => text()();
  TextColumn get phone => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get dealType => text().withDefault(const Constant('direct'))();
  RealColumn get commissionRate => real().nullable()();
  DateTimeColumn get createdAt => dateTime().nullable()();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('LocalProductRow')
class LocalProducts extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text()();
  TextColumn get name => text()();
  TextColumn get barcode => text().nullable()();
  TextColumn get unit => text()();
  TextColumn get unitType => text().withDefault(const Constant('count'))();
  IntColumn get salePrice => integer()();
  IntColumn get purchasePrice => integer()();
  RealColumn get qty => real().withDefault(const Constant(0))();
  RealColumn get reorderLevel => real().withDefault(const Constant(0))();
  TextColumn get supplierId => text().nullable()();
  RealColumn get commissionRate => real().nullable()();
  DateTimeColumn get createdAt => dateTime().nullable()();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('LocalEmployeeRow')
class LocalEmployees extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text()();
  TextColumn get name => text()();
  TextColumn get jobTitle => text().nullable()();
  TextColumn get phone => text().nullable()();
  IntColumn get baseSalary => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().nullable()();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('LocalAccountRow')
class LocalAccounts extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text()();
  TextColumn get code => text()();
  TextColumn get name => text()();
  TextColumn get type => text()();
  TextColumn get parentCode => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Invoice header mirror. `id` is the local row id: for server-mirrored
/// invoices this equals the server uuid; for offline-created invoices it is a
/// local uuid until sync resolves it through [IdMappings].
@DataClassName('LocalInvoiceRow')
class LocalInvoices extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text()();
  TextColumn get type => text()(); // 'sale' | 'purchase'
  TextColumn get no => text()(); // temp 'D-…' until server number adopted
  TextColumn get partyId => text()();
  TextColumn get partyName => text().nullable()();
  DateTimeColumn get date => dateTime()();
  IntColumn get subtotal => integer()();
  IntColumn get total => integer()();
  IntColumn get paid => integer()();
  IntColumn get remaining => integer()();
  TextColumn get status => text()(); // 'paid' | 'partial' | 'unpaid'
  TextColumn get ownership => text()(); // 'owned' | 'consignment'
  TextColumn get requestId => text().nullable()();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('LocalInvoiceItemRow')
class LocalInvoiceItems extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text()();
  TextColumn get invoiceId => text()();
  TextColumn get productId => text().nullable()();
  TextColumn get productName => text().nullable()();
  TextColumn get productUnit => text().nullable()();
  TextColumn get productUnitType => text().nullable()();
  RealColumn get qty => real()();
  IntColumn get price => integer()();
  IntColumn get total => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('LocalPaymentRow')
class LocalPayments extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text()();
  TextColumn get invoiceId => text().nullable()();
  TextColumn get partyId => text().nullable()();
  TextColumn get partyName => text().nullable()();
  IntColumn get amount => integer()();
  TextColumn get method => text()(); // 'cash' | 'bank'
  DateTimeColumn get date => dateTime()();
  TextColumn get note => text().nullable()();
  TextColumn get requestId => text().nullable()();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('LocalCommissionDueRow')
class LocalCommissionDues extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text()();
  TextColumn get invoiceId => text()();
  TextColumn get productId => text()();
  TextColumn get supplierId => text()();
  IntColumn get dueAmount => integer()();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  DateTimeColumn get createdAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Offline journal entries. `lines` holds the serialized journal lines JSON.
@DataClassName('LocalJournalEntryRow')
class LocalJournalEntries extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text()();
  DateTimeColumn get date => dateTime()();
  TextColumn get memo => text()();
  TextColumn get lines => text()(); // JSON array of JournalLine maps
  TextColumn get sourceType => text()();
  TextColumn get sourceId => text().nullable()();
  TextColumn get requestId => text().nullable()();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('LocalEmployeeMovementRow')
class LocalEmployeeMovements extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text()();
  TextColumn get employeeId => text()();
  TextColumn get month => text().nullable()(); // 'yyyy-MM'
  TextColumn get direction => text()(); // 'deduct' | 'entitle'
  TextColumn get category => text()(); // 'advance'|'goods'|'bonus'|'allowance'|'other'
  IntColumn get amount => integer()();
  DateTimeColumn get date => dateTime()();
  TextColumn get note => text().nullable()();
  TextColumn get requestId => text().nullable()();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('LocalSalaryRow')
class LocalSalaries extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text()();
  TextColumn get employeeId => text()();
  TextColumn get month => text()(); // 'yyyy-MM'
  IntColumn get paid => integer()();
  IntColumn get netDue => integer()();
  TextColumn get requestId => text().nullable()();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// One pending offline write, to be replayed against the Supabase RPCs in
/// chronological order once back online.
@DataClassName('SyncQueueRow')
class SyncQueueItems extends Table {
  TextColumn get id => text()(); // uuid
  TextColumn get tenantId => text()();
  TextColumn get rpc => text()(); // rpc name, or 'table:customers' for masters
  TextColumn get op => text().withDefault(const Constant('rpc'))(); // 'rpc' | 'table_crud'
  TextColumn get params => text()(); // JSON params for .rpc() / .from()
  TextColumn get requestId => text().nullable()();
  TextColumn get entity => text().nullable()(); // e.g. 'invoices', 'customers'
  TextColumn get localId => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Resolves offline-created local uuids to the server-assigned uuids returned
/// when the queued write is replayed.
@DataClassName('IdMappingRow')
class IdMappings extends Table {
  TextColumn get entity => text()(); // 'customers'|'suppliers'|'products'|'employees'|'invoices'
  TextColumn get localId => text()();
  TextColumn get serverId => text()();
  DateTimeColumn get syncedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {entity, localId};
}

@DataClassName('LocalTenantSettingRow')
class LocalTenantSettings extends Table {
  TextColumn get tenantId => text()();
  TextColumn get key => text()();
  TextColumn get value => text().nullable()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {tenantId, key};
}

/// Cache-last storage for report/dashboard/statement envelopes.
@DataClassName('ReportCacheRow')
class ReportCacheEntries extends Table {
  TextColumn get tenantId => text()();
  TextColumn get key => text()();
  TextColumn get payload => text()(); // JSON envelope
  DateTimeColumn get fetchedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {tenantId, key};
}

@DriftDatabase(
  tables: [
    LocalCustomers,
    LocalSuppliers,
    LocalProducts,
    LocalEmployees,
    LocalAccounts,
    LocalInvoices,
    LocalInvoiceItems,
    LocalPayments,
    LocalCommissionDues,
    LocalJournalEntries,
    LocalEmployeeMovements,
    LocalSalaries,
    SyncQueueItems,
    IdMappings,
    LocalTenantSettings,
    ReportCacheEntries,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) => m.createAll(),
    // Schema 2 adds the offline-create `synced` marker to the three master
    // mirror tables that lacked it. LocalCustomers.synced ships in v1, so the
    // migration only touches suppliers/products/employees.
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 2) {
        await m.addColumn(localSuppliers, localSuppliers.synced);
        await m.addColumn(localProducts, localProducts.synced);
        await m.addColumn(localEmployees, localEmployees.synced);
      }
    },
  );
}