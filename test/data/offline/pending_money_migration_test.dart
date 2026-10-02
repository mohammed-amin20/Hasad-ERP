import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasad_erp/data/offline/local_database.dart';
import 'package:hasad_erp/data/offline/local_store.dart';
import 'package:path/path.dart' as p;

/// Schema v6 added `local_invoices.pendingMoneyLeg` (issue 3). The migration is
/// additive, so an app upgrading over an existing v5 file must keep every
/// invoice row *and* the queue, and each pre-existing row must read back as
/// `pendingMoneyLeg == null` — the exact state it was already in ("no local
/// money mutation outstanding").
///
/// The upgrade is proved the only honest way: by hand-building a v5-shaped file
/// and letting `AppDatabase`'s own `onUpgrade` migrate it. A test that opens a
/// fresh v6 database proves nothing about `from < 6`.
void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('hasad_v5'));
  tearDown(() => dir.deleteSync(recursive: true));

  /// The v5 definition of `local_invoices` — every column except the new one,
  /// so the file genuinely lacks `pending_money_leg` before migrating.
  const v5InvoicesDdl = '''
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
  PRIMARY KEY (id)
)''';

  /// The real v5 definition of `sync_queue_items` (schema v4 added
  /// `depends_on`, v5 tenant-scoped `id_mappings`; neither touches this table).
  const v5QueueDdl = '''
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

  const v5ProfilesDdl = '''
CREATE TABLE local_user_profiles (
  auth_uid TEXT NOT NULL,
  payload TEXT NOT NULL,
  updated_at INTEGER NOT NULL,
  PRIMARY KEY (auth_uid)
)''';

  /// The v5/v6 definition of `local_invoice_items` — `{id}`-keyed, unchanged
  /// until schema 8. It exists in every real v5 file (created in schema 1), and
  /// the `from < 8` rebuild reads it, so an under-specified fixture that omits it
  /// fails as "no such table" — exactly as the `sync_queue_items` omission below
  /// did. Same rule: fix the fixture, do not teach the migration to skip a table
  /// it must read.
  const v5ItemsDdl = '''
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

  /// Builds a v5 file with one invoice and one queue leg, deliberately without
  /// `AppDatabase` — that would create a v6 schema and the upgrade would never
  /// run. The `user_version` pragma is what `AppDatabase` later reads to decide
  /// it must run `onUpgrade` with `from < 6`.
  Future<void> seedV5File(File file) async {
    final raw = _RawDatabase(NativeDatabase(file));
    await raw.customStatement(v5InvoicesDdl);
    await raw.customStatement(v5QueueDdl);
    await raw.customStatement(v5ProfilesDdl);
    await raw.customStatement(v5ItemsDdl);
    await raw.customStatement(
      'INSERT INTO local_invoices (id, tenant_id, type, no, party_id, date, '
      'subtotal, total, paid, remaining, status, ownership, synced) VALUES '
      "('inv-old', 't1', 'sale', 'S-1', 'c1', 1756684800000, 10000, 10000, "
      "4000, 6000, 'partial', 'owned', 1)",
    );
    await raw.customStatement(
      'INSERT INTO sync_queue_items (id, tenant_id, rpc, op, params, entity, '
      'local_id, status, created_at, updated_at) VALUES '
      "('leg-old', 't1', 'record_payment', 'rpc', '{}', 'invoices', "
      "'inv-old', 'synced', 1756684800000, 1756684800000)",
    );
    await raw.customStatement('PRAGMA user_version = 5');
    await raw.close();
  }

  test('a v5 file upgrades to v6 keeping its invoice and queue rows', () async {
    final file = File(p.join(dir.path, 'hasad_offline.sqlite'));
    await seedV5File(file);

    // Opening with AppDatabase is what runs onUpgrade(from: 5).
    final db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);
    final store = DriftLocalStore(db);

    final rows = await db.select(db.localInvoices).get();
    expect(rows, hasLength(1));
    expect(rows.single.id, 'inv-old');
    expect(rows.single.total, 10000);
    expect(rows.single.paid, 4000);
    expect(rows.single.remaining, 6000);

    // The point of an additive migration: an old row reads as "no pending
    // local money mutation", which is exactly what it was before v6.
    expect(rows.single.pendingMoneyLeg, isNull);

    // The queue is untouched by the migration, so a v5 install's work is not
    // lost on upgrade.
    final legs = await store.queueLegsFor('t1');
    expect(legs.map((l) => l.id), contains('leg-old'));

    // And the new column is writable on the migrated schema.
    await db.update(db.localInvoices).write(
      const LocalInvoicesCompanion(pendingMoneyLeg: Value('leg-new')),
    );
    final after = await db.select(db.localInvoices).get();
    expect(after.single.pendingMoneyLeg, 'leg-new');
  });

  test('a v5 file with no invoice rows still gains the column', () async {
    final file = File(p.join(dir.path, 'empty.sqlite'));
    final raw = _RawDatabase(NativeDatabase(file));
    await raw.customStatement(v5InvoicesDdl);
    // Every table the post-v5 upgrade chain touches must be here. This fixture is
    // only allowed to omit a table while no migration step reads or writes it;
    // schema 7 added a step on `sync_queue_items` and schema 8 a rebuild of
    // `local_invoice_items`, each of which made the omission visible as "no such
    // table". The fixture is under-specified, not the migration: silently
    // skipping an upgrade step would hide a genuinely corrupt database.
    await raw.customStatement(v5QueueDdl);
    await raw.customStatement(v5ProfilesDdl);
    await raw.customStatement(v5ItemsDdl);
    await raw.customStatement('PRAGMA user_version = 5');
    await raw.close();

    final db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);

    await db.customStatement(
      'INSERT INTO local_invoices (id, tenant_id, type, no, party_id, date, '
      'subtotal, total, paid, remaining, status, ownership) VALUES '
      "('inv-fresh', 't1', 'sale', 'S-2', 'c1', 1756684800000, 500, 500, "
      "500, 0, 'paid', 'owned')",
    );
    final row = await (db.select(db.localInvoices)
          ..where((r) => r.id.equals('inv-fresh')))
        .getSingle();
    expect(row.pendingMoneyLeg, isNull);

    // A *read* is not enough to prove the column exists: drift's row reader
    // returns null for a missing column rather than throwing, so a read-only
    // assertion passes even on an un-migrated schema. The typed write is what
    // actually exercises it.
    await db.update(db.localInvoices).write(
      const LocalInvoicesCompanion(pendingMoneyLeg: Value('leg-fresh')),
    );
    final marked = await (db.select(db.localInvoices)
          ..where((r) => r.id.equals('inv-fresh')))
        .getSingle();
    expect(marked.pendingMoneyLeg, 'leg-fresh');
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
  int get schemaVersion => 5;
}
