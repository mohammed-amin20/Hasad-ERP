import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasad_erp/data/offline/local_database.dart';
import 'package:hasad_erp/data/offline/local_store.dart';
import 'package:path/path.dart' as p;

/// Schema v7 added `sync_queue_items.affects_invoice_ids` (P1.1) so a money
/// leg can be attributed to the invoice rows it restated, even when its RPC
/// params name none (`settle_supplier`).
///
/// The migration is deliberately additive with **no backfill**, and these tests
/// pin both halves of that decision:
///
///  * a v6 install keeps every invoice row, its `pending_money_leg`, its queue,
///    and its cached profile; and
///  * a pre-v7 `record_payment` leg still resolves to its invoice through the
///    `p_invoice_id` params fallback, while a pre-v7 `settle_supplier` leg
///    stays attributed to nothing — the narrow, self-healing residual.
///
/// The upgrade is proved the only honest way: by hand-building a v6-shaped file
/// and letting `AppDatabase`'s own `onUpgrade` migrate it. Opening a fresh v7
/// database proves nothing about `from < 7`.
void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('hasad_v6'));
  tearDown(() => dir.deleteSync(recursive: true));

  /// v6 `local_invoices` — the v5 shape plus `pending_money_leg`, and with no
  /// attribution column (that one lives on the queue, not here).
  const v6InvoicesDdl = '''
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

  /// v6 `sync_queue_items` — identical to v5, because v7's column is the first
  /// change this table has seen.
  const v6QueueDdl = '''
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

  const v6ProfilesDdl = '''
CREATE TABLE local_user_profiles (
  auth_uid TEXT NOT NULL,
  payload TEXT NOT NULL,
  updated_at INTEGER NOT NULL,
  PRIMARY KEY (auth_uid)
)''';

  /// The v6 definition of `local_invoice_items` — `{id}`-keyed, unchanged until
  /// schema 8. Present in every real v6 file (created in schema 1), and the
  /// `from < 8` rebuild reads it. An under-specified fixture must be corrected
  /// here rather than taught around in the migration: a missing table is a
  /// corrupt database, and skipping the read would turn that corruption into a
  /// silently empty table.
  const v6ItemsDdl = '''
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

  /// Builds a v6 file with one invoice carrying a live marker, one already-synced
  /// `record_payment` leg, one still-pending `settle_supplier` leg, and a cached
  /// profile — deliberately without `AppDatabase`, since that would create a v7
  /// schema and `onUpgrade` would never run. The `user_version` pragma is what
  /// `AppDatabase` later reads to decide it must upgrade from 6.
  Future<void> seedV6File(
    File file, {
    required String settlementParams,
  }) async {
    final raw = _RawDatabase(NativeDatabase(file));
    await raw.customStatement(v6InvoicesDdl);
    await raw.customStatement(v6QueueDdl);
    await raw.customStatement(v6ProfilesDdl);
    await raw.customStatement(v6ItemsDdl);
    await raw.customStatement(
      'INSERT INTO local_invoices (id, tenant_id, type, no, party_id, date, '
      'subtotal, total, paid, remaining, status, ownership, synced, '
      'pending_money_leg) VALUES '
      "('inv-old', 't1', 'purchase', 'P-1', 's1', 1756684800000, 10000, "
      "10000, 4000, 6000, 'partial', 'owned', 1, 'leg-settlement')",
    );
    await raw.customStatement(
      'INSERT INTO sync_queue_items (id, tenant_id, rpc, op, params, entity, '
      'local_id, status, created_at, updated_at) VALUES '
      "('leg-payment', 't1', 'record_payment', 'rpc', "
      "'{\"p_invoice_id\":\"inv-old\"}', 'payments', 'inv-old', 'synced', "
      '1756684800000, 1756684800000)',
    );
    await raw.customStatement(
      'INSERT INTO sync_queue_items (id, tenant_id, rpc, op, params, entity, '
      'local_id, status, created_at, updated_at) VALUES '
      "('leg-settlement', 't1', 'settle_supplier', 'rpc', ?, 'payments', "
      "'NULL', 'pending', 1756684800001, 1756684800001)",
      [settlementParams],
    );
    await raw.customStatement(
      'INSERT INTO local_user_profiles (auth_uid, payload, updated_at) VALUES '
      "('auth-1', '{\"tenantId\":\"t1\"}', 1756684800000)",
    );
    await raw.customStatement('PRAGMA user_version = 6');
    await raw.close();
  }

  AppDatabase open(File file) => AppDatabase(NativeDatabase(file));

  test('a v6 file upgrades to v7 keeping mirrors, markers, queue and profile',
      () async {
    final file = File(p.join(dir.path, 'hasad_offline.sqlite'));
    await seedV6File(
      file,
      settlementParams: jsonEncode({'p_supplier_id': 's1', 'p_amount': 1000}),
    );

    final db = open(file);
    addTearDown(db.close);
    final store = DriftLocalStore(db);

    // The v6 marker survives the upgrade: an app that restarts mid-settlement
    // must still know a local money mutation owns that invoice.
    final invoice = await (db.select(db.localInvoices)
          ..where((r) => r.id.equals('inv-old')))
        .getSingle();
    expect(invoice.paid, 4000);
    expect(invoice.remaining, 6000);
    expect(invoice.pendingMoneyLeg, 'leg-settlement');

    // The queue survives, statuses and params intact.
    final legs = await store.queueLegsFor('t1', entity: 'payments');
    expect(legs.map((l) => l.id), containsAll(['leg-payment', 'leg-settlement']));
    final payment = legs.firstWhere((l) => l.id == 'leg-payment');
    expect(payment.status, 'synced');
    expect(jsonDecode(payment.params)['p_invoice_id'], 'inv-old');

    // The cached profile survives: the offline cold start depends on it.
    final profiles = await db.select(db.localUserProfiles).get();
    expect(profiles, hasLength(1));
    expect(profiles.single.authUid, 'auth-1');

    // NO BACKFILL: every pre-v7 leg reads as "no recorded attribution". The
    // reader falls back at query time instead — see the two tests below — so the
    // migration never has to agree with a second implementation.
    for (final leg in legs) {
      expect(leg.affectsInvoiceIds, isNull,
          reason: '${leg.id} must not be rewritten by the migration');
    }
    expect(LocalStore.parseInvoiceAttribution(payment.affectsInvoiceIds), isEmpty);

    // And the new column is genuinely writable on the migrated schema. A *read*
    // is not enough: drift's row reader returns null for a missing column
    // rather than throwing, so a read-only assertion would pass on an
    // un-migrated schema. The typed write is what exercises it.
    await store.enqueue(SyncQueueRow(
      id: 'leg-after-upgrade',
      tenantId: 't1',
      rpc: 'record_payment',
      op: 'rpc',
      params: jsonEncode({'p_invoice_id': 'inv-old'}),
      entity: 'payments',
      status: 'pending',
      attempts: 0,
      affectsInvoiceIds: jsonEncode(['inv-old']),
      createdAt: DateTime(2026, 3, 1),
      updatedAt: DateTime(2026, 3, 1),
    ));
    final written = (await store.queueLegsFor('t1', entity: 'payments'))
        .firstWhere((l) => l.id == 'leg-after-upgrade');
    expect(written.affectsInvoiceIds, '["inv-old"]');
  });

  test('a pre-v7 record_payment leg still resolves through its params',
      () async {
    // The fallback that makes a no-backfill migration safe: a payment leg always
    // named its invoice, so attribution is exactly recoverable from params.
    final file = File(p.join(dir.path, 'payment.sqlite'));
    await seedV6File(
      file,
      settlementParams: jsonEncode({'p_supplier_id': 's1', 'p_amount': 1000}),
    );
    final db = open(file);
    addTearDown(db.close);
    final store = DriftLocalStore(db);

    // Re-queue the synced pre-v7 payment and park the marker on it, as a
    // mid-drain state would look. (These are the two calls `SyncFlusher` makes
    // on success; calling them directly keeps the test on the attribution rule
    // instead of on flush plumbing.)
    await (db.update(db.syncQueueItems)
          ..where((t) => t.id.equals('leg-payment')))
        .write(const SyncQueueItemsCompanion(status: Value('pending')));
    await db.update(db.localInvoices).write(
      const LocalInvoicesCompanion(pendingMoneyLeg: Value('leg-payment')),
    );

    await store.markSynced('leg-payment');
    await store.resolveInvoiceMoneyMarker('t1', 'leg-payment');

    // The still-queued pre-v7 settlement is NOT attributed to anything, so the
    // marker clears — the pre-v7 behaviour, unchanged by the migration.
    final invoice = await (db.select(db.localInvoices)
          ..where((r) => r.id.equals('inv-old')))
        .getSingle();
    expect(invoice.pendingMoneyLeg, isNull);

    // The load-bearing half: the fallback found the leg's own invoice at all.
    // Had `_legInvoiceIds` returned nothing, the resolve would have been a no-op
    // and the marker would still read 'leg-payment'.
    expect(LocalStore.parseLegacyTargetInvoice(
      (await (db.select(db.syncQueueItems)
                ..where((r) => r.id.equals('leg-payment')))
              .getSingle())
          .params),
      {'inv-old'});
  });

  test('a pre-v7 settlement leg stays unattributed, and drains without crash',
      () async {
    // The documented residual, pinned honestly rather than papered over: a
    // settlement queued before v7 named no invoices in its params, and the
    // server — not the client — picks what to allocate, so there is nothing to
    // recover. The consequence is that a later money leg on one of its invoices
    // can still retire its marker if it drains first (today's behaviour, not a
    // regression). It is narrow and self-healing: it can only affect legs that
    // were already queued at upgrade time, and it disappears once they drain.
    final file = File(p.join(dir.path, 'settlement.sqlite'));
    await seedV6File(
      file,
      settlementParams: jsonEncode({'p_supplier_id': 's1', 'p_amount': 1000}),
    );
    final db = open(file);
    addTearDown(db.close);
    final store = DriftLocalStore(db);

    final settlement = (await store.queueLegsFor('t1', entity: 'payments'))
        .firstWhere((l) => l.id == 'leg-settlement');
    expect(LocalStore.parseInvoiceAttribution(settlement.affectsInvoiceIds),
        isEmpty);
    expect(jsonDecode(settlement.params).containsKey('p_invoice_id'), isFalse,
        reason: 'the RPC body never named an invoice — that is the whole reason '
            'attribution is recorded separately');

    // Draining it must still work end to end: markSynced + resolve on a leg
    // that is attributed to nothing is a no-op, not an error.
    await store.markSynced('leg-settlement');
    await store.resolveInvoiceMoneyMarker('t1', 'leg-settlement');
    expect((await store.queueLegsFor('t1', entity: 'payments'))
        .firstWhere((l) => l.id == 'leg-settlement')
        .status, 'synced');

    // The invoice keeps the local figures the settlement produced; only the
    // marker is a no-op.
    final invoice = await (db.select(db.localInvoices)
          ..where((r) => r.id.equals('inv-old')))
        .getSingle();
    expect(invoice.paid, 4000);
    expect(invoice.remaining, 6000);
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
  int get schemaVersion => 6;
}
