import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasad_erp/data/offline/local_database.dart';
import 'package:hasad_erp/data/offline/local_store.dart';
import 'package:path/path.dart' as p;

/// Schema v8 moves `tenant_id` into `local_invoice_items`'s primary key, so a
/// mirrored line set for one workspace can no longer replace another workspace's
/// row with the same id. Drift cannot alter a primary key, so the step is a
/// rebuild.
///
/// ## What these cases pin, and why they cannot be satisfied by reading the code
///
/// Every migration fixture in this suite hand-builds its file, which means the
/// OLD definition has to be written out again by hand. That is a real risk: a
/// fixture that quietly drifts toward the *current* definition proves nothing,
/// because the upgrade would then have nothing to do. So each case asserts the
/// pre-upgrade file's own DDL — read back out of `sqlite_master` while the
/// fixture's own connection is still open — before `AppDatabase` ever touches
/// the file. If that assertion ever reports the new composite key, the fixture
/// drifted and this whole file has been proving nothing.
///
/// ## What is deliberately NOT here
///
/// No sentinel column and no backfill, unlike schema 5. `tenant_id` was already
/// `NOT NULL` here and always has been, so every pre-v8 row already states its
/// own owner and the rows move across unchanged. "The tenant is still the
/// original one" is therefore the same assertion as "the row survived", and it is
/// made below rather than asserted as a separate rule.
void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('hasad_v7'));
  tearDown(() => dir.deleteSync(recursive: true));

  /// The v7 `local_invoice_items`: identical to v6/v5, because schema 8 is the
  /// first change this table has ever seen — which is exactly why `{id}` alone
  /// was its key for every prior schema version.
  const v7ItemsDdl = '''
CREATE TABLE local_invoice_items (
  id TEXT NOT NULL,
  tenant_id TEXT NOT NULL,
  invoice_id TEXT NOT NULL,
  product_id TEXT NULL,
  product_name TEXT NULL,
  product_unit TEXT NULL,
  product_unit_type TEXT NULL,
  qty REAL NOT NULL,
  price INTEGER NOT NULL,
  total INTEGER NOT NULL,
  PRIMARY KEY (id)
)''';

  const v7InvoicesDdl = '''
CREATE TABLE local_invoices (
  id TEXT NOT NULL,
  tenant_id TEXT NOT NULL,
  type TEXT NOT NULL,
  no TEXT NOT NULL,
  party_id TEXT NOT NULL,
  party_name TEXT NULL,
  date INTEGER NOT NULL,
  subtotal INTEGER NOT NULL,
  total INTEGER NOT NULL,
  paid INTEGER NOT NULL,
  remaining INTEGER NOT NULL,
  status TEXT NOT NULL,
  ownership TEXT NOT NULL,
  request_id TEXT NULL,
  synced INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NULL,
  pending_money_leg TEXT NULL,
  PRIMARY KEY (id)
)''';

  const v7QueueDdl = '''
CREATE TABLE sync_queue_items (
  id TEXT NOT NULL,
  tenant_id TEXT NOT NULL,
  rpc TEXT NOT NULL,
  op TEXT NOT NULL DEFAULT 'rpc',
  params TEXT NOT NULL,
  request_id TEXT NULL,
  entity TEXT NULL,
  local_id TEXT NULL,
  status TEXT NOT NULL DEFAULT 'pending',
  attempts INTEGER NOT NULL DEFAULT 0,
  last_error TEXT NULL,
  depends_on TEXT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  PRIMARY KEY (id)
)''';

  const v7ProfilesDdl = '''
CREATE TABLE local_user_profiles (
  auth_uid TEXT NOT NULL,
  payload TEXT NOT NULL,
  updated_at INTEGER NOT NULL,
  PRIMARY KEY (auth_uid)
)''';

  const v7MappingsDdl = '''
CREATE TABLE id_mappings (
  tenant_id TEXT NOT NULL,
  entity TEXT NOT NULL,
  local_id TEXT NOT NULL,
  server_id TEXT NOT NULL,
  PRIMARY KEY (tenant_id, entity, local_id)
)''';

  /// Every table the post-v7 upgrade chain touches, on one connection that is
  /// closed before the fixture returns. `local_invoice_items` has existed since
  /// schema 1, so a real v7 file always has it — an under-specified fixture that
  /// omits it fails as "no such table" (the same rule
  /// `pending_money_migration_test.dart` records for `sync_queue_items`).
  ///
  /// Returns the file's own stored DDL for `local_invoice_items`, read back from
  /// `sqlite_master` while this connection is still open, so the caller can pin
  /// the shape it is upgrading FROM.
  Future<String> seedV7File(File file, {bool withItems = true}) async {
    final raw = _RawDatabase(NativeDatabase(file));
    await raw.customStatement(v7InvoicesDdl);
    await raw.customStatement(v7QueueDdl);
    await raw.customStatement(v7ProfilesDdl);
    await raw.customStatement(v7MappingsDdl);
    if (withItems) {
      await raw.customStatement(v7ItemsDdl);
      await raw.customStatement(
        'INSERT INTO local_invoices (id, tenant_id, type, no, party_id, date, '
        'subtotal, total, paid, remaining, status, ownership, synced, '
        'pending_money_leg) VALUES '
        "('inv-old', 't1', 'sale', 'S-1', 'c1', 1756684800000, 1000, 1000, 0, "
        "1000, 'unpaid', 'owned', 1, NULL)",
      );
      await raw.customStatement(
        'INSERT INTO local_invoice_items (id, tenant_id, invoice_id, product_id, '
        'product_name, product_unit, product_unit_type, qty, price, total) '
        "VALUES ('legacy-line-uuid', 't1', 'inv-old', 'p1', 'سلعة', 'قطعة', "
        "'count', 2, 500, 1000)",
      );
    }
    final rows = await raw
        .customSelect(
          "SELECT sql FROM sqlite_master WHERE type = 'table' AND name = ?",
          variables: [Variable<String>('local_invoice_items')],
        )
        .get();
    await raw.customStatement('PRAGMA user_version = 7');
    await raw.close();
    return rows.isEmpty ? '' : rows.single.read<String>('sql');
  }

  test('a v7 file upgrades to v8 and every line row survives with its own tenant',
      () async {
    final file = File(p.join(dir.path, 'hasad_offline.sqlite'));
    final before = await seedV7File(file);

    // The precondition, read from the FILE rather than from our own DDL string.
    expect(before, contains('PRIMARY KEY (id)'),
        reason: 'precondition: v7 keyed this table by id alone, so the rebuild '
            'has a real primary key to change');
    expect(before, isNot(contains('PRIMARY KEY (tenant_id, id)')));

    final db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);
    final store = DriftLocalStore(db);

    // Rows carried across verbatim — same id, same tenant, same money. The id is
    // a bare uuid because that is what the pre-v8 writer minted; it is NOT
    // rewritten into the positional scheme, because the original ordinal of a
    // uuid row was never recorded and inventing one would be fiction.
    final rows = await db.select(db.localInvoiceItems).get();
    expect(rows, hasLength(1));
    expect(rows.single.id, 'legacy-line-uuid');
    expect(rows.single.tenantId, 't1');
    expect(rows.single.invoiceId, 'inv-old');
    expect(rows.single.productId, 'p1');
    expect(rows.single.productName, 'سلعة');
    expect(rows.single.productUnit, 'قطعة');
    expect(rows.single.qty, 2);
    expect(rows.single.price, 500);
    expect(rows.single.total, 1000);

    // The neighbours the rebuild must not touch.
    expect((await db.select(db.localInvoices).get()).single.id, 'inv-old');
    expect(await db.select(db.localUserProfiles).get(), isEmpty);
    expect(await db.select(db.idMappings).get(), isEmpty);
    expect(await db.select(db.syncQueueItems).get(), isEmpty);

    // The typed write is what proves the new key, and therefore the collision
    // fix. A read-only assertion would pass on the old schema too — drift's row
    // reader happily returns a row from a table whose key is weaker than the
    // code believes.
    await store.upsertInvoiceItems([
      for (final t in ['t1', 't2'])
        LocalInvoiceItemRow(
          id: 'shared-line-id',
          tenantId: t,
          invoiceId: 'inv-old',
          productId: 'p-$t',
          productName: 'سلعة',
          productUnit: 'قطعة',
          productUnitType: 'count',
          qty: 1,
          price: 100,
          total: 100,
        ),
    ]);
    expect(
        (await store.invoiceItems('t1', 'inv-old')).map((r) => r.productId),
        containsAll(['p1', 'p-t1']));
    expect((await store.invoiceItems('t2', 'inv-old')).single.productId, 'p-t2',
        reason: 'on the v7 key the second insert would have REPLACED the first '
            'workspace row instead of adding its own');
  });

  test('the same line id in two workspaces is impossible on v7, which is the '
      'defect the step exists for', () async {
    // Not a test of the migration but of its PREMISE, and it earns its place
    // because the fixture above would otherwise be taken on faith: if v7 could
    // hold this pair, the composite key would be fixing nothing.
    final file = File(p.join(dir.path, 'premise.sqlite'));
    final db = _RawDatabase(NativeDatabase(file));
    await db.customStatement(v7ItemsDdl);
    await db.customStatement(
      'INSERT INTO local_invoice_items (id, tenant_id, invoice_id, product_id, '
      'product_name, product_unit, product_unit_type, qty, price, total) '
      "VALUES ('x', 't1', 'inv', 'p1', 'سلعة', 'قطعة', 'count', 1, 100, 100)",
    );
    await expectLater(
      db.customStatement(
        'INSERT INTO local_invoice_items (id, tenant_id, invoice_id, product_id, '
        'product_name, product_unit, product_unit_type, qty, price, total) '
        "VALUES ('x', 't2', 'inv', 'p2', 'سلعة', 'قطعة', 'count', 1, 100, 100)",
      ),
      throwsA(isA<SqliteException>()),
      reason: 'on v7 the id alone is the key, so the second workspace cannot '
          'store its line at all — and because the real writer uses '
          'insertOrReplace, the practical failure is silently REPLACING the '
          'first workspace row instead',
    );
    await db.close();
  });

  test('a v7 file with no line rows still gets the table', () async {
    final file = File(p.join(dir.path, 'empty.sqlite'));
    final raw = _RawDatabase(NativeDatabase(file));
    await raw.customStatement(v7InvoicesDdl);
    await raw.customStatement(v7QueueDdl);
    await raw.customStatement(v7ProfilesDdl);
    await raw.customStatement(v7MappingsDdl);
    await raw.customStatement(v7ItemsDdl);
    await raw.customStatement('PRAGMA user_version = 7');
    await raw.close();

    final db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);
    final store = DriftLocalStore(db);

    expect(await db.select(db.localInvoiceItems).get(), isEmpty);

    // Writable afterwards, which is the assertion a read cannot make.
    await store.upsertInvoiceItems([
      const LocalInvoiceItemRow(
        id: 'fresh:0000',
        tenantId: 't1',
        invoiceId: 'fresh',
        productId: 'p1',
        productName: 'سلعة',
        productUnit: 'قطعة',
        productUnitType: 'count',
        qty: 1,
        price: 100,
        total: 100,
      ),
    ]);
    expect((await store.invoiceItems('t1', 'fresh')).single.id, 'fresh:0000');
  });

  test('a database missing the line table fails the upgrade loudly instead of '
      'silently emptying it', () async {
    // The counterpart to the note in `local_database.dart`. A guard that skipped
    // the read would turn a corrupt file into a *successful* upgrade with an
    // empty table, and the user would find their invoice lines gone with nothing
    // logged. Failing routes the device to the repair screen instead, which is
    // the honest outcome.
    final file = File(p.join(dir.path, 'corrupt.sqlite'));
    await seedV7File(file, withItems: false);

    final db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);
    await expectLater(
      db.select(db.localInvoiceItems).get(),
      throwsA(isA<SqliteException>()),
    );
  });
}

/// A bare drift database with no tables of its own, used only to run raw DDL
/// against a file before `AppDatabase` opens it. `customStatement` opens the
/// executor properly, which calling `runCustom` on a `NativeDatabase` directly
/// does not.
class _RawDatabase extends GeneratedDatabase {
  _RawDatabase(super.e);

  @override
  Iterable<TableInfo> get allTables => const [];

  @override
  int get schemaVersion => 7;
}
