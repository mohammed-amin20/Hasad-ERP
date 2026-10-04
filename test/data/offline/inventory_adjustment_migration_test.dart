import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasad_erp/data/offline/local_database.dart';
import 'package:hasad_erp/data/offline/local_store.dart';
import 'package:path/path.dart' as p;

/// Schema v9 added `sync_queue_items.affects_product_ids` (Standalone Inventory
/// Adjustment). The migration is purely additive and nullable, with **no
/// backfill**: every pre-v9 leg reads back as NULL, which resolves to "no
/// recorded product attribution", and the reader falls back to the narrow
/// `params` shapes at query time (`LocalStore.affectedProductIdsOf`).
///
/// Proved the honest way: hand-build a v8-shaped file and let `AppDatabase`'s
/// own `onUpgrade` migrate it. Opening a fresh v9 database proves nothing about
/// `from < 9`.
void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('hasad_v8'));
  tearDown(() => dir.deleteSync(recursive: true));

  /// v8 `sync_queue_items` — the v7 shape (with `affects_invoice_ids`) plus
  /// `depends_on`, and **without** `affects_product_ids`.
  const v8QueueDdl = '''
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
  affects_invoice_ids TEXT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  PRIMARY KEY (id)
)''';

  Future<void> seedV8File(File file) async {
    final raw = _RawDatabase(NativeDatabase(file));
    await raw.customStatement(v8QueueDdl);
    await raw.customStatement(
      'INSERT INTO sync_queue_items (id, tenant_id, rpc, op, params, entity, '
      'local_id, status, created_at, updated_at) VALUES '
      "('leg-sale', 't1', 'create_sale_invoice', 'rpc', ?, 'invoices', "
      "'inv-1', 'pending', 1756684800000, 1756684800000)",
      [
        jsonEncode({
          'p_items': [
            {'product_id': 'p-old', 'qty': 2},
          ],
        }),
      ],
    );
    await raw.customStatement('PRAGMA user_version = 8');
    await raw.close();
  }

  AppDatabase open(File file) => AppDatabase(NativeDatabase(file));

  test('a v8 file upgrades to v9 keeping its queue and adding the column',
      () async {
    final file = File(p.join(dir.path, 'hasad_offline.sqlite'));
    await seedV8File(file);

    final db = open(file);
    addTearDown(db.close);
    final store = DriftLocalStore(db);

    // The queue survives untouched.
    final legs = await store.queueLegsFor('t1');
    expect(legs, hasLength(1));
    final saleLeg = legs.single;
    expect(saleLeg.rpc, 'create_sale_invoice');
    expect(saleLeg.status, 'pending');

    // NO BACKFILL: a pre-v9 leg reads as "no recorded attribution"...
    expect(saleLeg.affectsProductIds, isNull);
    // ...and the reader derives the product from the wire shape instead.
    expect(LocalStore.affectedProductIdsOf(saleLeg), {'p-old'});

    // The new column is genuinely writable. A *read* is not enough: drift's row
    // reader returns null for a missing column rather than throwing, so only the
    // typed write exercises it.
    await store.enqueue(SyncQueueRow(
      id: 'leg-after',
      tenantId: 't1',
      rpc: 'adjust_inventory',
      op: 'rpc',
      params: jsonEncode({'p_product_id': 'p1', 'p_counted_qty': 5}),
      requestId: 'req-1',
      entity: null,
      localId: 'p1',
      status: 'pending',
      attempts: 0,
      lastError: null,
      dependsOn: null,
      affectsInvoiceIds: null,
      affectsProductIds: jsonEncode(['p1']),
      createdAt: DateTime(2026, 3, 1),
      updatedAt: DateTime(2026, 3, 1),
    ));
    final written = (await store.queueLegsFor('t1'))
        .firstWhere((l) => l.id == 'leg-after');
    expect(written.affectsProductIds, '["p1"]');
    expect(LocalStore.affectedProductIdsOf(written), {'p1'});
  });

  test('a v8 file with no queue rows still gains the column', () async {
    final file = File(p.join(dir.path, 'empty.sqlite'));
    final raw = _RawDatabase(NativeDatabase(file));
    await raw.customStatement(v8QueueDdl);
    await raw.customStatement('PRAGMA user_version = 8');
    await raw.close();

    final db = open(file);
    addTearDown(db.close);
    final store = DriftLocalStore(db);

    await store.enqueue(SyncQueueRow(
      id: 'leg-fresh',
      tenantId: 't1',
      rpc: 'adjust_inventory',
      op: 'rpc',
      params: '{}',
      requestId: null,
      entity: null,
      localId: 'p1',
      status: 'pending',
      attempts: 0,
      lastError: null,
      dependsOn: null,
      affectsInvoiceIds: null,
      affectsProductIds: jsonEncode(['p9']),
      createdAt: DateTime(2026, 3, 2),
      updatedAt: DateTime(2026, 3, 2),
    ));

    final row = (await store.queueLegsFor('t1'))
        .firstWhere((l) => l.id == 'leg-fresh');
    expect(row.affectsProductIds, '["p9"]');
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
  int get schemaVersion => 8;
}
