// The P1.G contract, pinned below the UI where nothing can hide it. An invoice
// created offline used to lose its product lines for good once it replayed and
// the user opened its detail; the contract these cases enforce is the fix:
//
//   * A remote answer of `[]` on a detail read must NOT delete the durable rows
//     (R6), and they are still there after the process restarts (R3).
//   * A NON-empty answer still replaces them wholesale (the control case) — the
//     empty guard must not degenerate into "lines never change".
//   * A damaged invoice recovers through the ordinary public read path (R4/R7),
//     because the mirror is replace-all and a non-empty detail read is therefore
//     the repair mechanism; no schema change and no server-side fix.
//
// The widget suite (`test/widget/invoice_detail_items_identity_test.dart`) pins
// what the USER sees; this suite pins the durable table underneath it. Every
// assertion is made against the raw `local_invoice_items` table, never against a
// rendered widget, so a test cannot pass because a screen happened to rebuild.
//
// Everything here runs through the real `OfflineWriteCoordinator`, the real
// `DriftLocalStore`, the real `SyncFlusher` and the real
// `OfflineInvoiceRepository`. Only the network edge and the replay target are
// fakes.
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasad_erp/data/offline/local_database.dart';
import 'package:hasad_erp/data/offline/local_store.dart';
import 'package:hasad_erp/data/offline/offline_invoice_repository.dart';
import 'package:hasad_erp/data/offline/offline_sync.dart';
import 'package:hasad_erp/data/offline/offline_write.dart';
import 'package:hasad_erp/domain/invoices/invoice.dart';
import 'package:hasad_erp/domain/purchases/purchase_invoice_draft.dart';
import 'package:hasad_erp/domain/sales/sale_invoice_draft.dart';

import '../../tool/offline_invoice_harness.dart';

const serverId = 'srv-p1g-1';

/// The raw durable rows. Deliberately not the repository's answer: a defect that
/// served the right lines while destroying them would still be data loss, and
/// this is the only read that cannot be papered over by a mirror refresh.
Future<List<String>> durableLineNames(
    DriftLocalStore store, String invoiceId) async =>
    [
      for (final r in await store.invoiceItems(harnessTenant, invoiceId))
        r.productName ?? ''
    ];

void main() {
  group('P1.G data layer — the empty mirror', () {
    late OfflineInvoiceHarness h;

    setUp(() async {
      h = await OfflineInvoiceHarness.create();
    });
    tearDown(() => h.close());

    // ---------------------------------------------------------------------
    // R6 — the destructive step, isolated from any UI at all.
    // ---------------------------------------------------------------------
    test('R6. a synced invoice\'s durable lines survive a successful remote '
        'read that answers with no lines', () async {
      final localId = await writeThroughTheRealCoordinator(h, 'sale');
      expect(await durableLineNames(h.store, localId), hasLength(2),
          reason: 'precondition: the offline create wrote two durable lines');

      await drainWithServerIdentity(h, serverId);

      // The server has the invoice. It simply has no answer for the LOCAL uuid:
      // no id the server issues is ever a client-minted uuid.
      h.network.itemsById = const {};

      final repo = OfflineInvoiceRepository(
        h.network,
        store: h.store,
        tenantId: harnessTenant,
      );

      // Asking by the id the SERVER issued is the correct, mapping-aware read.
      final served = await repo.items(serverId);

      expect(
        served.map((i) => i.productName),
        containsAll(<String>[seedProductName, secondProductName]),
        reason: 'the lines the user is shown must stay CORRECT: an empty remote '
            'answer is discarded, so the durable set is served, not nothing',
      );
      expect(
        await durableLineNames(h.store, localId),
        hasLength(2),
        reason: 'a successful remote read that answered [] must never delete '
            'this invoice\'s only durable copy of its lines. The rows are the '
            'record; an empty answer for an id the server never issued is not '
            'evidence that the invoice has none.',
      );
      expect(
        h.network.itemsCalls,
        contains(serverId),
        reason: 'precondition, and the whole point: the server WAS asked and '
            'did answer [] — this is a successful read, not a network failure '
            'falling back to the mirror. Without this, the case would also pass '
            'if the guard were merely the offline branch.',
      );
    });

    // ---------------------------------------------------------------------
    // R3 — the user's actual complaint, end to end and across a restart.
    // ---------------------------------------------------------------------
    test('R3. the lines are still on the device after a restart, so the loss is '
        'permanent rather than a cache miss', () async {
      final dir = Directory.systemTemp.createTempSync('hasad_p1g_lines');
      addTearDown(() {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      });
      final file = File('${dir.path}/lines.db');

      // A file, not NativeDatabase.memory(): "the app restarts" is the whole
      // point, and an in-memory database proves nothing about it.
      final db1 = AppDatabase(NativeDatabase(file));
      final store1 = DriftLocalStore(db1);
      await seedInvoiceMasterData(store1, harnessTenant);

      final h1 = OfflineInvoiceHarness.adopt(
        db: db1,
        store: store1,
        network: FakeNetworkInvoices(),
        target: RecordingSyncTarget(),
      );

      final localId = await writeThroughTheRealCoordinator(h1, 'purchase');
      expect(await durableLineNames(store1, localId), hasLength(2),
          reason: 'precondition: the offline purchase wrote two durable lines');

      await drainWithServerIdentity(h1, serverId);
      h1.network.itemsById = const {};

      // The user opens the invoice. This is the read the sheet performs.
      await OfflineInvoiceRepository(
        h1.network,
        store: store1,
        tenantId: harnessTenant,
      ).items(serverId);

      await db1.close();

      // The app restarts and reads the invoice again — offline this time.
      final db2 = AppDatabase(NativeDatabase(file));
      addTearDown(db2.close);
      final store2 = DriftLocalStore(db2);

      expect(
        await durableLineNames(store2, localId),
        hasLength(2),
        reason: 'the lines must still be on disk after a restart. If this fails, '
            'the rows were physically deleted by a read and the invoice is '
            'unrecoverable for the user — not merely unreadable until the next '
            'refresh.',
      );
      expect(
        await durableLineNames(store2, localId),
        containsAll(<String>[seedProductName, secondProductName]),
        reason: 'and they must be the right lines, not merely two rows',
      );
    });

    // ---------------------------------------------------------------------
    // R4 — the guard rail. This one is expected to PASS today, and it must: it
    // proves the suite is pinned to the L/S mismatch and not to a general
    // "lines never persist" failure.
    // ---------------------------------------------------------------------
    test('R4. the durable lookup and the detail read agree once the L→S '
        'mapping exists, so the mismatch is the only variable', () async {
      final localId = await writeThroughTheRealCoordinator(h, 'sale');
      await drainWithServerIdentity(h, serverId);

      expect(await h.store.serverIdFor(harnessTenant, 'invoices', localId),
          serverId,
          reason: 'precondition: the replay recorded L→S');
      expect(await h.store.localIdFor(harnessTenant, 'invoices', serverId),
          localId,
          reason: 'precondition: and the mapping resolves back to L');

      // Given the mapping, the batch durable lookup — which is what decides
      // whether a list refresh re-requests lines — sees the rows as durable.
      expect(
        await h.store.invoiceIdsWithDurableItems(harnessTenant, [serverId]),
        contains(serverId),
        reason: 'the bulk lookup must answer in the CALLER\'s id space, so a '
            'replayed invoice\'s lines are recognised as already fetched',
      );

      // And the server answers the server id with the lines.
      h.network.itemsById = {
        serverId: [
          for (final r in await h.store.invoiceItems(harnessTenant, localId))
            InvoiceItem(
              productId: r.productId ?? '',
              productName: r.productName,
              productUnit: r.productUnit,
              qty: r.qty,
              price: r.price,
              total: r.total,
            ),
        ],
      };

      final served = await OfflineInvoiceRepository(
        h.network,
        store: h.store,
        tenantId: harnessTenant,
      ).items(serverId);

      expect(served, hasLength(2),
          reason: 'a detail read for the SERVER id must return the lines');
    });

    // ---------------------------------------------------------------------
    // Control. Without this, R6 is unfalsifiable: "the rows are gone" would also
    // be consistent with a suite that can never persist a line.
    // ---------------------------------------------------------------------
    test('control. the same read, answered with lines, mirrors them — so the '
        'suite is capable of seeing durable rows survive', () async {
      final localId = await writeThroughTheRealCoordinator(h, 'sale');
      await drainWithServerIdentity(h, serverId);

      h.network.itemsById = {
        serverId: [
          InvoiceItem(
            productId: 'pX',
            productName: 'منتج من الخادم',
            productUnit: 'قطعة',
            qty: 7,
            price: 1000,
            total: 7000,
          ),
        ],
      };

      final served = await OfflineInvoiceRepository(
        h.network,
        store: h.store,
        tenantId: harnessTenant,
      ).items(serverId);

      expect(served.single.qty, 7, reason: 'the server\'s lines are served');
      expect(await durableLineNames(h.store, localId), hasLength(1),
          reason: 'and they replace the local set — a non-empty answer still '
              'mirrors, so the empty-answer case is the anomaly');
      expect(await durableLineNames(h.store, localId), ['منتج من الخادم'],
          reason: 'the mirror really was rewritten, not merged or left alone');
    });

    // ---------------------------------------------------------------------
    // R7 — RECOVERY. The fix ships as an APK installed OVER the device's
    // existing data, WITHOUT Clear Data, so some invoices were already damaged
    // by the old build: their durable lines are gone, and only the server still
    // has them. This case proves such an invoice heals itself.
    // ---------------------------------------------------------------------
    test('R7. an invoice whose local lines were already erased heals from a '
        'non-empty remote read, and stays healed across a restart while '
        'offline', () async {
      final dir = Directory.systemTemp.createTempSync('hasad_p1g_repair');
      addTearDown(() {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      });
      final file = File('${dir.path}/repair.db');

      final db1 = AppDatabase(NativeDatabase(file));
      final store1 = DriftLocalStore(db1);
      await seedInvoiceMasterData(store1, harnessTenant);
      final h1 = OfflineInvoiceHarness.adopt(
        db: db1,
        store: store1,
        network: FakeNetworkInvoices(),
        target: RecordingSyncTarget(),
      );

      // --- build the post-damage shape for real, not by hand --------------
      final localId = await writeThroughTheRealCoordinator(h1, 'sale');
      await drainWithServerIdentity(h1, serverId);
      expect(await store1.serverIdFor(harnessTenant, 'invoices', localId),
          serverId,
          reason: 'precondition: the header is keyed by L and L→S is mapped');

      // The server still holds both lines.
      h1.network.itemsById = {
        serverId: [
          for (final r in await store1.invoiceItems(harnessTenant, localId))
            InvoiceItem(
              productId: r.productId ?? '',
              productName: r.productName,
              productUnit: r.productUnit,
              qty: r.qty,
              price: r.price,
              total: r.total,
            ),
        ],
      };

      // Now erase the local rows exactly as the old destructive path did. Doing
      // it through the BUGGY read rather than by deleting rows keeps the fixture
      // honest: it is the damage the old build actually did, not a shape I
      // invented.
      await h1.store.mirrorInvoiceItems(harnessTenant, localId, const []);
      expect(await durableLineNames(store1, localId), isEmpty,
          reason: 'precondition: the damage is reproduced — the durable lines '
              'are gone while the header and the mapping both survive');

      // --- 1/2. the normal detail path, by the identity the list exposes ----
      final served = await OfflineInvoiceRepository(
        h1.network,
        store: store1,
        tenantId: harnessTenant,
      ).items(serverId);

      expect(served, hasLength(2),
          reason: 'a damaged invoice must read from the server, not stay empty');
      expect(served.map((i) => i.productName),
          containsAll(<String>[seedProductName, secondProductName]));

      // --- 3. and the rows come back under the NORMALIZED local identity L ---
      expect(
        await durableLineNames(store1, localId),
        hasLength(2),
        reason: 'the repair must be mirrored under the LOCAL identity L, where '
            'the rest of the mirror already looks for it — under S it would be '
            'invisible to every offline read and to the list-time prefetch',
      );
      expect(await durableLineNames(store1, serverId), isEmpty,
          reason: 'and NOT under the server id, which would create the duplicate '
              'second set of lines P1.F documented');

      await db1.close();

      // --- 4/5/6. restart, go offline, read again ---------------------------
      final db2 = AppDatabase(NativeDatabase(file));
      addTearDown(db2.close);
      final store2 = DriftLocalStore(db2);
      final offlineNetwork = FakeNetworkInvoices()
        ..offline = true
        ..itemsById = const {};

      final afterRestart = await OfflineInvoiceRepository(
        offlineNetwork,
        store: store2,
        tenantId: harnessTenant,
      ).items(serverId);

      expect(
        afterRestart,
        hasLength(2),
        reason: 'the repaired lines must be readable OFFLINE after a restart. '
            'Without this the repair only ever lived in the cache, and the user '
            'would still see an empty invoice the moment they lost signal — '
            'which is the same symptom, on a different day.',
      );
      expect(afterRestart.map((i) => i.productName),
          containsAll(<String>[seedProductName, secondProductName]));
    });
  });
}

/// Writes an invoice through the REAL `OfflineWriteCoordinator`, exactly as the
/// offline-aware repository does when the device cannot reach the server.
///
/// The account-chart closure is `() async => []` on purpose: the coordinator's
/// `_chart()` is emptiness-gated and every required code is already mirrored by
/// [seedInvoiceMasterData], so a live chart call is not part of this defect and
/// must not become a second way for these cases to fail.
Future<String> writeThroughTheRealCoordinator(
    OfflineInvoiceHarness h, String type) async {
  final coordinator =
      OfflineWriteCoordinator(h.store, harnessTenant, () async => []);
  if (type == 'sale') {
    final r = await coordinator.writeSale(SaleInvoiceDraft(
      customerId: seedCustomerId,
      lines: const [
        SaleLineDraft(productId: seedProductId, qty: 2, price: 100000),
        SaleLineDraft(productId: secondProductId, qty: 1, price: 50000),
      ],
    ));
    return r.invoiceId;
  }
  final r = await coordinator.writePurchase(PurchaseInvoiceDraft(
    supplierId: seedSupplierId,
    lines: const [
      PurchaseLineDraft(productId: seedProductId, qty: 2, price: 60000),
      PurchaseLineDraft(productId: secondProductId, qty: 1, price: 30000),
    ],
  ));
  return r.invoiceId;
}

/// Runs the real `SyncFlusher` so the invoice reaches the state the device is in
/// after a reconnect: the header is keyed by the LOCAL uuid, `id_mappings`
/// carries L→S, and the line rows are still under L.
Future<void> drainWithServerIdentity(
    OfflineInvoiceHarness h, String serverId) async {
  h.target.nextServerId = serverId;
  h.target.nextServerNo = 'SERVER-9100';
  final summary = await SyncFlusher(h.store, harnessTenant, h.target).flush();
  expect(summary.synced, greaterThan(0),
      reason: 'precondition: the create leg really replayed. If it did not, the '
          'invoice stays an unsynced draft, `items()` short-circuits to the '
          'local branch, and every assertion below passes vacuously.');
}