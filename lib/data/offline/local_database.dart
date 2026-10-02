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
  TextColumn get parentId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// The 14 default accounts a server tenant is born with — a byte-for-byte copy
/// of `seed_chart_of_accounts` in migration `0005` (codes, Arabic names, and
/// `type` values included, and `parent_code` is NULL for every one of them
/// because the server seeds them flat).
///
/// This is a **tenant-agnostic template**, not a tenant mirror row, and that
/// is the whole reason it is a separate table: a Drift migration runs when the
/// database file is opened, long before any tenant is known, so it cannot
/// insert into the tenant-partitioned [LocalAccounts]. Embedding the defaults
/// here lets the schema own them while [LocalStore.ensureBaselineChart] copies
/// them into [LocalAccounts] per tenant at runtime.
@DataClassName('LocalAccountTemplateRow')
class LocalAccountTemplates extends Table {
  TextColumn get code => text()(); // e.g. '1010'
  TextColumn get name => text()();
  TextColumn get type => text()(); // 'asset' | 'liability' | …

  @override
  Set<Column> get primaryKey => {code};
}

/// The embedded default chart, seeded by `createAll` on a fresh install and by
/// the v4 migration on an existing one. Order is the server's insertion order
/// and is irrelevant to correctness — the copy is keyed by `code`.
const List<LocalAccountTemplatesCompanion> _defaultChartTemplates = [
  LocalAccountTemplatesCompanion(
    code: Value('1010'),
    name: Value('النقدية'),
    type: Value('asset'),
  ),
  LocalAccountTemplatesCompanion(
    code: Value('1015'),
    name: Value('البنك'),
    type: Value('asset'),
  ),
  LocalAccountTemplatesCompanion(
    code: Value('1020'),
    name: Value('الذمم المدينة'),
    type: Value('asset'),
  ),
  LocalAccountTemplatesCompanion(
    code: Value('1030'),
    name: Value('المخزون'),
    type: Value('asset'),
  ),
  LocalAccountTemplatesCompanion(
    code: Value('1040'),
    name: Value('الأصول الثابتة'),
    type: Value('asset'),
  ),
  LocalAccountTemplatesCompanion(
    code: Value('2010'),
    name: Value('الذمم الدائنة'),
    type: Value('liability'),
  ),
  LocalAccountTemplatesCompanion(
    code: Value('2030'),
    name: Value('رواتب مستحقة'),
    type: Value('liability'),
  ),
  LocalAccountTemplatesCompanion(
    code: Value('3010'),
    name: Value('رأس المال'),
    type: Value('equity'),
  ),
  LocalAccountTemplatesCompanion(
    code: Value('3020'),
    name: Value('الأرباح المحتجزة'),
    type: Value('equity'),
  ),
  LocalAccountTemplatesCompanion(
    code: Value('4010'),
    name: Value('إيرادات المبيعات'),
    type: Value('revenue'),
  ),
  LocalAccountTemplatesCompanion(
    code: Value('4020'),
    name: Value('مردودات المبيعات'),
    type: Value('revenue'),
  ),
  LocalAccountTemplatesCompanion(
    code: Value('5010'),
    name: Value('تكلفة البضاعة المباعة'),
    type: Value('expense'),
  ),
  LocalAccountTemplatesCompanion(
    code: Value('5020'),
    name: Value('المصروفات التشغيلية'),
    type: Value('expense'),
  ),
  LocalAccountTemplatesCompanion(
    code: Value('5030'),
    name: Value('الأجور والرواتب'),
    type: Value('expense'),
  ),
];

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

  /// Id of the queued money leg that last changed this row's `paid` /
  /// `remaining` / `status` locally (an offline `record_payment` or
  /// `settle_supplier` allocation) — null once that leg has replayed.
  ///
  /// This is the "has a pending local money mutation" signal the read path
  /// needs, and it deliberately carries a *single* leg id rather than a
  /// dirty-flag. A boolean could not express the overlapping-write case
  /// (payment A still pending, then payment B recorded on the same invoice)
  /// safely: when A finally drains, clearing a boolean would also discard B's
  /// claim, and the list would fall back to a server value that knows about
  /// neither. With a leg id, [LocalStore.clearInvoiceMoneyMarker] matches by
  /// equality, so replaying A leaves B's marker intact and the row stays
  /// authoritative until B drains too.
  TextColumn get pendingMoneyLeg => text().nullable()();

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

  /// Tenant-qualified since schema 8.
  ///
  /// An `id` alone was the same key in every workspace, and `upsertInvoiceItems`
  /// writes with `insertOrReplace` — so mirroring one workspace's lines for an
  /// invoice id the other workspace also holds silently REPLACED the other
  /// workspace's row. This is the documented `{id}`-only trap that
  /// `local_invoices` and `local_suppliers` still carry; line items do not have
  /// to. See the `from < 8` migration for why no backfill is needed.
  @override
  Set<Column> get primaryKey => {tenantId, id};
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

  /// JSON array of the `sync_queue_items.id` uuids this item must be replayed
  /// AFTER, e.g. `'["…","…"]'`. Null (or `'[]'`) means "no prerequisites".
  ///
  /// Replay is ordered by [createdAt] and, within equal timestamps, by
  /// dependency: an item whose prerequisite is still `pending`/`staged` is
  /// skipped this pass instead of being sent first and failing on a
  /// not-yet-created parent. A `failed` prerequisite permanently blocks the
  /// dependent (see `offline_sync.dart`).
  TextColumn get dependsOn => text().nullable()();

  /// JSON array of the invoice ids whose money figures this leg restated
  /// locally, e.g. `'["?","?"]'`. Null (or `'[]'`) means "no recorded
  /// attribution" — see [LocalStore.resolveInvoiceMoneyMarker].
  ///
  /// A leg's RPC `params` cannot answer this: `record_payment` names
  /// `p_invoice_id`, but `settle_supplier` names only a supplier because the
  /// SERVER chooses what to settle, so the invoice set exists nowhere but in
  /// the local settlement algorithm's `allocations`. Losing that set would let
  /// a later money leg retiring first clear a marker the settlement still owns.
  ///
  /// This is **local-only metadata** and is never part of the RPC body sent to
  /// Supabase — [params] is the wire payload, this column is not. Written once
  /// at enqueue, inside the same transaction as the invoice writes, and never
  /// mutated afterwards: a leg's activity is expressed by [status] alone.
  TextColumn get affectsInvoiceIds => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Resolves offline-created local uuids to the server-assigned uuids returned
/// when the queued write is replayed.
///
/// [tenantId] is part of the primary key (schema 5). Without it this table was
/// the one thing `clearTenant` could NOT delete, because it had no tenant
/// column to filter on -- so signing out left every localId->serverId mapping
/// for that tenant on the device. A stale mapping is worse than a missing one:
/// it resolves a fresh local row to a server row that no longer belongs to
/// this session. `localId` values are generated uuids, so the key was already
/// unique in practice; adding the tenant makes the isolation explicit instead
/// of accidental, and lets the wipe scope itself.
@DataClassName('IdMappingRow')
class IdMappings extends Table {
  TextColumn get tenantId => text()();
  TextColumn get entity => text()(); // 'customers'|'suppliers'|'products'|'employees'|'invoices'
  TextColumn get localId => text()();
  TextColumn get serverId => text()();
  DateTimeColumn get syncedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {tenantId, entity, localId};
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

/// Last-known user profile, so an offline cold start can restore the signed-in
/// identity (role + active tenant) without a live `users` read.
///
/// Keyed by the Supabase **auth uid**, not the tenant id: the tenant is what
/// this row is trying to supply, so a tenant-keyed table would be
/// chicken-and-egg. The auth uid is available offline from the SDK-persisted
/// session, so it is the one identifier that is known before the first network
/// call. Deliberately NOT cleared by `clearTenant` — this row is
/// user-scoped, not tenant-scoped; it is deleted on sign-out.
@DataClassName('LocalUserProfileRow')
class LocalUserProfiles extends Table {
  TextColumn get authUid => text()(); // Supabase auth user id
  TextColumn get payload => text()(); // JSON-encoded AppUser
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {authUid};
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
    LocalUserProfiles,
    LocalAccountTemplates,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 8;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
      await _seedAccountTemplates();
    },
    // Schema 2 added the offline-create `synced` marker to the three master
    // mirror tables that lacked it. LocalCustomers.synced ships in v1, so the
    // migration only touches suppliers/products/employees.
    // Schema 3 (M13 Phase 0) adds the offline user-profile cache. It is purely
    // additive: no existing table is touched, so no mirror/queue/report row is
    // at risk, and `createAll` on a fresh install picks it up automatically.
    // Schema 4 (M13 Phase 1A) makes the chart of accounts offline-usable and
    // the queue dependency-aware. Both columns are nullable and additive, so
    // no existing row's meaning changes:
    //   * local_accounts.parent_id  — the account's parent by id, not just by
    //     code. Nullable, and the baseline/online chart both leave it null
    //     exactly as the server seed does.
    //   * sync_queue_items.depends_on — JSON array of prerequisite queue-item
    //     uuids. Null means "no prerequisites", which is the behaviour every
    //     pre-v4 row already had.
    // Schema 5 (M13 Phase 1A) adds id_mappings.tenant_id and moves it into the
    // primary key. This one is NOT purely additive: the column is NOT NULL in
    // the new primary key, but every pre-v5 row belongs to some tenant and the
    // table does not record which one. Rebuilding is therefore the only correct
    // migration, and the safe one is to carry the old rows over as an orphaned
    // sentinel rather than guess a tenant -- a wrong tenant_id would let one
    // tenant's wipe delete another tenant's mappings. The sentinel is a value
    // no real tenant id can take, and it keeps the data visible for debugging
    // instead of silently dropping mappings the user may still need.
    // Schema 6 (M13 Phase 2 P1) adds local_invoices.pending_money_leg. Purely
    // additive and nullable: every pre-v6 row reads back as NULL, which is
    // exactly the state it was already in (no local money mutation is
    // outstanding). The column names the queue leg that last changed the row's
    // paid/remaining/status locally, so an offline payment shows its new
    // figures in the list before the drain and the server is authoritative
    // again the moment that leg replays. No mirror, queue, report-cache or
    // profile row is touched, so nothing can be lost.
    // Schema 8 (M13 Phase 2 P1.E) moves `tenant_id` into local_invoice_items'
    // primary key, so a mirrored line set can no longer replace another
    // workspace's row for the same id. Unlike schema 5 this is a rebuild with
    // NO sentinel and NO backfill: every pre-v8 row already carries its real,
    // non-null tenant_id (it is NOT NULL in the table and always has been), so
    // the rows move across unchanged and none can be misattributed.
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 2) {
        await m.addColumn(localSuppliers, localSuppliers.synced);
        await m.addColumn(localProducts, localProducts.synced);
        await m.addColumn(localEmployees, localEmployees.synced);
      }
      if (from < 3) {
        await m.createTable(localUserProfiles);
      }
      if (from < 4) {
        await m.addColumn(localAccounts, localAccounts.parentId);
        await m.addColumn(syncQueueItems, syncQueueItems.dependsOn);
        await m.createTable(localAccountTemplates);
        await _seedAccountTemplates();
      }
      if (from < 5) {
        // Drift cannot change a primary key, so rebuild the table and move the
        // rows across under the orphaned-tenant sentinel.
        final old = await m.database.select(idMappings).get();
        await m.deleteTable('id_mappings');
        await m.createTable(idMappings);
        if (old.isNotEmpty) {
          await m.database.batch((b) => b.insertAll(
                idMappings,
                [
                  for (final r in old)
                    IdMappingsCompanion.insert(
                      // Pre-v5 rows have no tenant; they are not attributed to
                      // any workspace, so no workspace's clearTenant will touch
                      // them and no lookup can match them by tenant.
                      tenantId: _orphanedIdMappingTenant,
                      entity: r.entity,
                      localId: r.localId,
                      serverId: r.serverId,
                    ),
                ],
              ));
        }
      }
      if (from < 6) {
        // Additive: existing invoice rows read back as NULL, which means "no
        // local money mutation is outstanding" — the state they were already in.
        await m.addColumn(localInvoices, localInvoices.pendingMoneyLeg);
      }
      if (from < 7) {
        // Additive: every pre-v7 leg reads back as NULL, which resolves to "no
        // recorded attribution".
        //
        // There is deliberately NO backfill from `params` here, even though a
        // `record_payment` leg's `p_invoice_id` could be copied. A migration
        // that rewrites user rows to a value a second implementation must then
        // keep in agreement is strictly worse than leaving the column NULL and
        // letting the reader fall back at query time (see
        // `LocalStore._legInvoiceIds`). More importantly a `settle_supplier`
        // leg's set **cannot** be reconstructed: the server chose the
        // allocation and the local mirror may have changed since, so any value
        // written here would be invention rather than evidence. The residual is
        // therefore narrow and self-healing: a settlement already queued at
        // upgrade time keeps today's behaviour and is attributed by nothing
        // until it drains, after which it can never reoccur.
        //
        // Mutation-proven both ways by `leg_attribution_migration_test.dart`:
        // removing this `addColumn` fails the typed write (a *read* would not —
        // drift's row reader returns null for a missing column), and adding the
        // `p_invoice_id` backfill above fails the "must not be rewritten"
        // assertion.
        await m.addColumn(syncQueueItems, syncQueueItems.affectsInvoiceIds);
      }
      if (from < 8) {
        // Drift cannot change a primary key, so the table is rebuilt — the same
        // shape as the schema-5 `id_mappings` rebuild above, and deliberately
        // NOT `migratedTable`, which would be a no-op on a device whose
        // pre-v8 file has no migration state to read.
        //
        // Rows are carried across VERBATIM, with no sentinel and no backfill,
        // and that is the difference from schema 5: `tenant_id` was already NOT
        // NULL here and every writer has always set it, so each row's owner is
        // known. Re-attributing anything here would be invention, and dropping
        // a row would be silent data loss on a user's offline invoice.
        //
        // There is deliberately NO "does this table exist?" guard, unlike a
        // tolerant migration would have. `local_invoice_items` has existed since
        // schema 1, so a file without it is corrupt, and skipping the read would
        // convert that corruption into a silently empty table — the upgrade would
        // report success and the user would find their invoice lines gone with
        // nothing logged. Failing here is what routes the device to the repair
        // screen, which is the honest outcome. (Same rule as the v7 fixture note
        // in `pending_money_migration_test.dart`: an under-specified fixture gets
        // corrected, it does not get a migration that hides it.)
        final old = await m.database.select(localInvoiceItems).get();
        await m.deleteTable('local_invoice_items');
        await m.createTable(localInvoiceItems);
        if (old.isNotEmpty) {
          await m.database.batch((b) => b.insertAll(localInvoiceItems, old));
        }
      }
    },
  );

  /// Sentinel [IdMappings.tenantId] for rows written before schema 5.
  ///
  /// A real tenant id is a server-assigned uuid, so a value that is not a uuid
  /// can never collide with one. Keeping these rows is deliberate: they are
  /// still-valid mappings whose owner we simply cannot prove, and a silent
  /// delete would be worse than an orphan that no query can reach.
  static const String _orphanedIdMappingTenant = '__unknown_tenant__';

  /// Populates the tenant-agnostic default-chart template table. Idempotent
  /// (`insertOrReplace`) so a re-run cannot duplicate a code.
  Future<void> _seedAccountTemplates() {
    return batch((b) {
      b.insertAll(localAccountTemplates, _defaultChartTemplates,
          mode: InsertMode.insertOrReplace);
    });
  }
}