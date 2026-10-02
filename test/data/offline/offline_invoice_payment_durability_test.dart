/// **FAILURE C: an offline payment on a replayed invoice is silently
/// overwritten by the next list refresh — FIXED, and pinned by the cases
/// below.**
///
/// ## The reported symptom, and the real defect
///
/// The report was "the invoice appears twice AND the payment disappears".
/// Only the second half reproduced, and the two halves have different causes,
/// so they must not be merged into one story.
///
/// **Symptom 1 - a duplicated row: NOT reproduced.** `markReplaySynced`
/// deliberately keeps the LOCAL uuid in `local_invoices.id` (the sync badge
/// joins the queue on the leg's `localId`) and records `L -> S` in `id_map`,
/// and `mirrorInvoices` resolves each incoming server id through `localIdFor`
/// before it writes. C1 pins that one logical invoice yields exactly one row
/// - it is a guard, and it PASSES. Any claim that the list duplicates must be
/// re-verified before it is repeated. **No `_merged`/dedup refactor was made
/// for this file.**
///
/// **Symptom 2 - the payment "disappeared".** The write is durable.
/// `recordPayment(S)` resolves `S -> L` through `_invoice`, then commits ONE
/// transaction: the invoice's `paid`/`remaining`/`status`, a
/// `pending_money_leg` marker, a `local_payments` row, and a
/// `record_payment` leg with `affectsInvoiceIds: [L]`. Every one of those
/// survives a restart (C2).
///
/// The next list read then destroyed them. `mirrorInvoices.protectedIds`
/// collects LOCAL ids while the incoming server row carries the SERVER id, so
/// the like-with-like comparison did not protect the mapped row; and the
/// mapped write ended in `row.copyWith(id: localId).toCompanion(false)`,
/// which - as C4 proves against the generated code - emits an explicit
/// `Value(null)` for the nullable `pendingMoneyLeg`. The refresh therefore
/// stamped STALE money over the local figures AND EXPLICITLY CLEARED the
/// marker, in one write.
///
/// **The fix** is to resolve `S -> L` BEFORE the protection comparison, so a
/// mapped protected row is excluded from `incoming` entirely and neither its
/// money nor its marker is written. C3/C5 pin that, C4 still pins the
/// `toCompanion(false)` semantics that make it necessary, and **C7 pins the
/// other side**: a mapped row that is `synced` with a NULL marker is NOT
/// protected and must still accept fresher server figures, or every replayed
/// invoice would freeze at whatever the server said at replay time.
///
/// So the payment was **not lost** (the queue leg and `local_payments` both
/// survive) and it was never merely **hidden**: the invoice's local money
/// authority was physically overwritten. C3 asserts money and marker together
/// so those two failures cannot be confused with one another.
///
/// ## Ids are deliberately distinct
///
/// `L` and `S` are different literal UUIDs everywhere. A test that reused one
/// id for both would pass through the exact-id lookup and never reach the
/// mapping code the defect lives in.
///
/// ## C6 is why the defect was invisible
///
/// The user eventually reconnects, the queue drains, the server has the
/// payment, and the figures come back - so the defect was self-healing after a
/// flush and invisible in a test that stopped at the mirror. Worse, the mirror
/// had ALREADY cleared the marker, so a later "the marker was cleared after a
/// successful replay" observation proved nothing: it was never there to clear.
/// C6 now pins the honest version - the marker SURVIVES the stale refresh and
/// the DRAIN is what finally clears it. Same end state, and the difference is
/// the whole defect.
library;

import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasad_erp/data/invoices/invoice_repository.dart';
import 'package:hasad_erp/data/offline/local_database.dart';
import 'package:hasad_erp/data/offline/local_store.dart';
import 'package:hasad_erp/data/offline/offline_invoice_repository.dart';
import 'package:hasad_erp/data/offline/offline_sync.dart';
import 'package:hasad_erp/data/offline/offline_write.dart';
import 'package:hasad_erp/domain/invoices/invoice.dart';
import 'package:hasad_erp/domain/payments/payment_repository.dart';

/// The LOCAL uuid `markReplaySynced` keeps in `local_invoices.id`.
const _localId = '11111111-1111-4111-8111-111111111111';

/// The SERVER uuid the same invoice is served under.
const _serverId = '22222222-2222-4222-8222-222222222222';

const _tenant = 'tenant-a';
const _total = 10000;

void main() {
  group('C1. one logical invoice, one row', () {
    test('C1: after the replay mapping exists, list() returns ONE invoice with '
        'the server identity', () async {
      final h = await _Harness.boot();

      await h.replayInvoice();

      final rows = await h.repo(online: true).list(type: 'sale');

      expect(
        rows.where((i) => i.no == 'SALE-3001'),
        hasLength(1),
        reason:
            'GUARD, and it passes. `mirrorInvoices` resolves the incoming '
            'server id through `localIdFor` before writing, so the mapped local '
            'row is updated in place rather than appended. Pinned because the '
            'reported symptom said the list duplicates: if this ever fails, '
            'the duplication is real and needs its own diagnosis, but today it '
            'must NOT be reported as a defect.',
      );
      final shown = rows.firstWhere((i) => i.no == 'SALE-3001');
      expect(
        shown.id,
        _serverId,
        reason:
            'the list hands the UI the server identity; that is what '
            'P1.D made resolvable and what the payment path resolves back '
            'through id_map',
      );
      expect(shown.total, _total);
      expect(shown.remaining, _total);
    });
  });

  group('C2. the payment write is durable (this part is correct today)', () {
    test('C2: recordPayment commits money, marker, payment row and leg in one '
        'transaction, and they survive a restart', () async {
      final h = await _Harness.boot();
      await h.replayInvoice();

      await h.writer.recordPayment(
        PaymentDraft(
          invoiceId: _serverId,
          amount: 4000,
          method: 'cash',
          date: DateTime(2026, 3, 5),
        ),
      );

      await h.restart();
      final row = await h.invoiceRow(_localId);
      expect(row.paid, 4000, reason: 'the local money write did land');
      expect(row.remaining, 6000);
      expect(row.status, 'partial');
      expect(
        row.pendingMoneyLeg,
        isNotNull,
        reason:
            'the marker is what tells the read path this row is locally '
            'corrected - losing it is the actual defect',
      );

      expect(
        await h.payments(),
        hasLength(1),
        reason:
            'the local_payments row survives, which is why this is '
            '"authority overwritten", NOT "payment write lost"',
      );
      expect((await h.pendingLegs()), hasLength(1));
    });
  });

  group('C3. the mapped mirror must not overwrite the local money', () {
    test('C3: after a list refresh carrying STALE server money, the local '
        'figures and the marker both survive', () async {
      final h = await _Harness.boot();
      await h.replayInvoice();

      await h.writer.recordPayment(
        PaymentDraft(
          invoiceId: _serverId,
          amount: 4000,
          method: 'cash',
          date: DateTime(2026, 3, 5),
        ),
      );
      final marker = (await h.invoiceRow(_localId)).pendingMoneyLeg;
      expect(marker, isNotNull);

      // The device refreshes while still offline: the server row is the
      // pre-payment one, so this is a legitimate STALE answer, not a wrong one.
      await h.repo(online: true).list(type: 'sale');

      final after = await h.invoiceRow(_localId);
      // Money and marker are asserted TOGETHER on purpose: a bare
      // `expect(paid, 4000)` would stop at the first mismatch and the marker
      // half - the active part of the defect - would never run. One record
      // means one failure reports all three fields.
      expect(
        (
          paid: after.paid,
          remaining: after.remaining,
          leg: after.pendingMoneyLeg,
        ),
        (paid: 4000, remaining: 6000, leg: marker),
        reason:
            'both halves at once, and the mutation that breaks this case is '
            'restoring the raw-id comparison.\n'
            '(1) MONEY: `mirrorInvoices.protectedIds` collects LOCAL ids (L) '
            'while the incoming row carries the SERVER id (S), so a '
            'like-with-like comparison needs S -> L resolved FIRST. The user '
            'paid 4000; a stale mirror must not be able to put 0 back.\n'
            '(2) MARKER: the mapped write is '
            '`copyWith(id: localId).toCompanion(false)`, which emits an '
            'explicit `Value(null)` for this nullable column (pinned in C4). '
            'So a refresh that is NOT excluded writes the marker away - which '
            'is why the fix excludes the protected row from `incoming` '
            'entirely instead of trying to null-guard the write.',
      );
      expect(
        await h.payments(),
        hasLength(1),
        reason:
            'the payment row itself is untouched - this is what '
            'distinguishes "authority overwritten" from "payment write '
            'lost", and the two must never be reported interchangeably',
      );
      expect(
        await h.pendingLegs(),
        hasLength(1),
        reason:
            'the queue leg is untouched too, so the payment is still on '
            'its way to the server',
      );
    });
  });

  group('C4. characterization: toCompanion(false) writes explicit nulls', () {
    test('C4: the row shape _mirrorHeaders builds nulls the marker EXPLICITLY '
        'when it is copied onto the mapped local id', () {
      // Built exactly the way `OfflineInvoiceRepository._mirrorHeaders` builds
      // it: a FRESH server-owned row, which by contract carries no
      // `pendingMoneyLeg` because the server has no such concept.
      final fromServer = LocalInvoiceRow(
        id: _serverId,
        tenantId: _tenant,
        type: 'sale',
        no: 'SALE-3001',
        partyId: 'c1',
        partyName: 'عميل',
        date: DateTime(2026, 3, 4),
        subtotal: _total,
        total: _total,
        paid: 0,
        remaining: _total,
        status: 'unpaid',
        ownership: 'owned',
        requestId: null,
        synced: true,
        createdAt: null,
        pendingMoneyLeg: null,
      );

      // The mapped write: `row.copyWith(id: localId).toCompanion(false)`.
      final companion = fromServer.copyWith(id: _localId).toCompanion(false);

      expect(
        companion.pendingMoneyLeg.present,
        isTrue,
        reason:
            'drift\'s `toCompanion(false)` emits `Value(null)` for every '
            'nullable field, NOT `Value.absent()`. So the mapped write does '
            'not merely FAIL to protect the marker - it actively clears it. '
            'Pinned so a fix cannot be "stop passing false" by accident: that '
            'one argument also decides `requestId` and `createdAt`, which the '
            'server-owned shape genuinely does want nulled.',
      );
      expect(companion.pendingMoneyLeg.value, isNull);
    });
  });

  group('C5. the whole lifecycle against a real sqlite file', () {
    test('C5: BEFORE the mirror the local money is authoritative; AFTER it, a '
        'restart serves the overwritten figures', () async {
      final dir = Directory.systemTemp.createTempSync('hasad_payment_c');
      addTearDown(() {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      });
      final file = File('${dir.path}/hasad_offline.sqlite');

      var db = AppDatabase(NativeDatabase(file));
      var store = DriftLocalStore(db);
      // Closures, not tear-offs: this test closes and reopens the database
      // twice, and on Windows the still-open connection would block deleting
      // the temp directory in teardown.
      addTearDown(() => db.close());
      await _seedChart(store);

      // A replayed invoice: stored under L, served under S. The row itself is
      // minted locally first - `markReplaySynced` only stamps an existing row
      // (it updates by local id) and records the L -> S mapping.
      await store.upsertInvoice(_localInvoiceRow());
      await store.markReplaySynced(
        tenantId: _tenant,
        entity: 'invoices',
        localId: _localId,
        serverId: _serverId,
        officialNo: 'SALE-3001',
      );
      await db.close();

      // --- restart #1: a brand new connection over the same file -----------
      db = AppDatabase(NativeDatabase(file));
      store = DriftLocalStore(db);
      await _seedChart(store);

      final writer = OfflineWriteCoordinator(store, _tenant);
      await writer.recordPayment(
        PaymentDraft(
          invoiceId: _serverId,
          amount: 4000,
          method: 'cash',
          date: DateTime(2026, 3, 5),
        ),
      );

      final before = await _readRow(db, _localId);
      expect(before.paid, 4000);
      expect(before.pendingMoneyLeg, isNotNull);

      // The refresh that destroys it.
      await OfflineInvoiceRepository(
        _ServerInvoices([_serverInvoice()]),
        store: store,
        tenantId: _tenant,
      ).list(type: 'sale');

      // Read the PHYSICAL row, not the drift object: this is the file's own
      // bytes on disk, so a defect that only existed in a decoded object
      // could not survive here. (`package:sqlite3` is a transitive dependency
      // and must not be imported - AGENTS.md - so this goes through drift's
      // own `customSelect`.)
      final raw = await db
          .customSelect(
            'SELECT paid, remaining, pending_money_leg FROM local_invoices '
            'WHERE id = ? AND tenant_id = ?',
            variables: [Variable<String>(_localId), Variable<String>(_tenant)],
          )
          .getSingle();
      expect(
        (
          paid: raw.read<int>('paid'),
          remaining: raw.read<int>('remaining'),
          leg: raw.read<String?>('pending_money_leg'),
        ),
        (paid: 4000, remaining: 6000, leg: before.pendingMoneyLeg),
        reason:
            'the same overwrite as C3, now proven against a FILE '
            'and against the raw SQL row, so it cannot be an artifact of an '
            'in-memory database or of drift\'s row decoding',
      );

      await db.close();

      // --- restart #2: what a cold start now serves -------------------------
      db = AppDatabase(NativeDatabase(file));
      store = DriftLocalStore(db);

      final served = await _servedAfterColdStart(store);
      expect(
        served.paid,
        4000,
        reason:
            'a restart must not resurrect the lost payment: the local row '
            'is the only authority this device has, and it was overwritten',
      );
      expect(served.pendingMoneyLeg, isNotNull);
      expect(
        await store.payments(_tenant),
        hasLength(1),
        reason:
            'the payment row survived the whole sequence, so the defect '
            'is located on the invoice header, not on the payment',
      );
    });
  });

group('C6. the drain — not a stale mirror — is what hands the row back', () {
    test('C6: the marker SURVIVES the pre-reconnect refresh, and the drain is '
        'what finally clears it', () async {
      final h = await _Harness.boot();
      await h.replayInvoice();

      await h.writer.recordPayment(
        PaymentDraft(
          invoiceId: _serverId,
          amount: 4000,
          method: 'cash',
          date: DateTime(2026, 3, 5),
        ),
      );

      final marked = await h.invoiceRow(_localId);
      expect(marked.pendingMoneyLeg, isNotNull);

      // The device refreshes before reconnecting, and the server still reports
      // the PRE-payment figures.
      await h.repo(online: true).list(type: 'sale');
      expect(
        await h.invoiceRow(_localId),
        isA<LocalInvoiceRow>()
            .having((r) => r.paid, 'paid', 4000)
            .having((r) => r.remaining, 'remaining', 6000)
            .having((r) => r.pendingMoneyLeg, 'pendingMoneyLeg',
                marked.pendingMoneyLeg),
        reason:
            'the marker is still there to clear, which is the whole point: a '
            'mirror that silently retired it made the later drain untestable '
            'and left the row looking server-owned while showing local money',
      );

      // Reconnect: the queue drains and the server now holds the payment.
      h.serverPaid = 4000;
      final summary = await SyncFlusher(h.store, _tenant, _OkTarget()).flush();
      expect(summary.synced, 1, reason: 'the leg does reach the server');

      // Then the post-reconnect refresh the app performs, which is what
      // actually carries the payment into the mirror.
      await h.repo(online: true).list(type: 'sale');

      await h.restart();
      final row = await h.invoiceRow(_localId);
      expect(
        row.paid,
        4000,
        reason:
            'a later server refresh carries the payment, so the figures '
            'self-heal; that is why C5 (before any drain) is the case that '
            'matters',
      );
      expect(
        row.pendingMoneyLeg,
        isNull,
        reason:
            'and now the marker is cleared by the DRAIN that retired the leg - '
            'not by a stale mirror that arrived before it. Same end state, '
            'and the difference is the entire defect',
      );
      expect(await h.payments(), hasLength(1));
    });
  });

  group('C7. an UNPROTECTED mapped row must still accept the server', () {
    test('C7: synced + no marker + mapped, so a fresher server figure lands',
        () async {
      final h = await _Harness.boot();
      await h.replayInvoice();

      final row = await h.invoiceRow(_localId);
      expect(row.synced, isTrue);
      expect(
        row.pendingMoneyLeg,
        isNull,
        reason:
            'the precondition: this row is server-owned with no local money '
            'correction outstanding, so the server copy IS the authority',
      );

      // The server moves on and reports a figure this device has never seen.
      // The mapped identity must NOT stop it from landing — that would freeze
      // every replayed invoice at whatever the server said at replay time.
      final fresh = _serverInvoice(paid: 1500);
      final updated = await OfflineInvoiceRepository(
        _ServerInvoices([fresh]),
        store: h.store,
        tenantId: _tenant,
      ).list(type: 'sale');

      expect(updated, hasLength(1), reason: 'still exactly one row');
      final after = await h.invoiceRow(_localId);
      expect(
        (paid: after.paid, remaining: after.remaining),
        (paid: 1500, remaining: 8500),
        reason:
            'the regression guard against over-protecting: resolving the id '
            'space must skip rows that are synced AND unmarked, or a mapped '
            'invoice would never accept the server again',
      );
      expect(
        [for (final r in await h.store.invoices(_tenant, type: 'sale')) r.id],
        [_localId],
        reason: 'refreshed in place under the LOCAL id, not re-keyed',
      );
    });
  });
}


/// One file-backed database, opened and closed like real process runs.
class _Harness {
  _Harness._(this.dir, this.file, this.db, this.store);

  final Directory dir;
  final File file;
  AppDatabase db;
  DriftLocalStore store;

  OfflineWriteCoordinator get writer => OfflineWriteCoordinator(store, _tenant);

  /// What the fake server would report as the invoice's paid figure. Mutable,
  /// because C6 needs the state to change between two reads - a fixed stub
  /// makes "the state changed underneath" cases vacuous.
  int serverPaid = 0;

  static Future<_Harness> boot() async {
    final dir = Directory.systemTemp.createTempSync('hasad_payment_c');
    final file = File('${dir.path}/hasad_offline.sqlite');
    final db = AppDatabase(NativeDatabase(file));
    final h = _Harness._(dir, file, db, DriftLocalStore(db));
    // Read the FIELD at teardown time: `restart()` replaces `db`, and on
    // Windows a connection left open blocks deleting the temp directory.
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    // A CLOSURE, not a tear-off: `restart()` replaces `h.db`, and on Windows a
    // connection left open would block the delete above. tear-offs bind the
    // object they were read from, so only the closure sees the newest one.
    addTearDown(() => h.db.close());
    await _seedChart(h.store);
    return h;
  }

  /// Puts the device in the exact post-replay state: the invoice lives under
  /// L, the mapping L -> S exists, and it is marked synced.
  ///
  /// The row is minted locally first, because `markReplaySynced` only UPDATES
  /// an existing row (it writes by local id) - it never inserts the invoice.
  /// Replaying a queued invoice is what puts the row there in production.
  Future<void> replayInvoice() async {
    await store.upsertInvoice(_localInvoiceRow());
    await store.markReplaySynced(
      tenantId: _tenant,
      entity: 'invoices',
      localId: _localId,
      serverId: _serverId,
      officialNo: 'SALE-3001',
    );
  }

  Future<LocalInvoiceRow> invoiceRow(String id) async => (await store.invoices(
    _tenant,
    type: 'sale',
  )).firstWhere((r) => r.id == id);

  Future<List<LocalPaymentRow>> payments() => store.payments(_tenant);

  Future<List<SyncQueueRow>> pendingLegs() => store.pendingSync(_tenant);

  Future<void> restart() async {
    await db.close();
    db = AppDatabase(NativeDatabase(file));
    store = DriftLocalStore(db);
    await _seedChart(store);
  }

  OfflineInvoiceRepository repo({required bool online}) =>
      OfflineInvoiceRepository(
        _ServerInvoices([_serverInvoice(paid: serverPaid)]),
        store: store,
        tenantId: _tenant,
      );
}

/// The mirror header a replayed invoice leaves on the device: LOCAL id L,
/// unpaid, `synced == false` (the pre-replay draft state).
LocalInvoiceRow _localInvoiceRow() => LocalInvoiceRow(
  id: _localId,
  tenantId: _tenant,
  type: 'sale',
  no: 'D-0001',
  partyId: 'c1',
  partyName: 'عميل',
  date: DateTime(2026, 3, 4),
  subtotal: _total,
  total: _total,
  paid: 0,
  remaining: _total,
  status: 'unpaid',
  ownership: 'owned',
  requestId: null,
  synced: false,
  createdAt: DateTime(2026, 3, 4),
);

Invoice _serverInvoice({int paid = 0}) => Invoice(
  id: _serverId,
  type: 'sale',
  no: 'SALE-3001',
  partyId: 'c1',
  partyName: 'عميل',
  date: DateTime(2026, 3, 4),
  subtotal: _total,
  total: _total,
  paid: paid,
  remaining: _total - paid,
  status: paid == 0 ? InvoiceStatus.unpaid : InvoiceStatus.partial,
  ownership: InvoiceOwnership.owned,
);

Future<void> _seedChart(DriftLocalStore store) async {
  for (final a in const [
    ('a1', '1010', 'نقدية', 'asset'),
    ('a2', '1015', 'بنك', 'asset'),
    ('a3', '1020', 'ذمم مدينة', 'asset'),
    ('a4', '1030', 'مخزون', 'asset'),
    ('a5', '2010', 'ذمم دائنة', 'liability'),
    ('a7', '4010', 'إيرادات مبيعات', 'revenue'),
  ]) {
    await store.upsertAccount(
      LocalAccountRow(
        id: a.$1,
        tenantId: _tenant,
        code: a.$2,
        name: a.$3,
        type: a.$4,
        parentCode: null,
      ),
    );
  }
  await store.upsertCustomer(
    LocalCustomerRow(
      id: 'c1',
      tenantId: _tenant,
      name: 'عميل',
      phone: null,
      notes: null,
      createdAt: DateTime(2026, 1, 1),
      synced: true,
    ),
  );
}

Future<LocalInvoiceRow> _readRow(AppDatabase db, String id) =>
    (db.select(db.localInvoices)..where((r) => r.id.equals(id))).getSingle();

/// What the invoice list serves after a cold start, with no network: the mirror
/// header, overlaid by the authority rule.
Future<LocalInvoiceRow> _servedAfterColdStart(DriftLocalStore store) async {
  final rows = await store.invoices(_tenant, type: 'sale');
  return rows.firstWhere((r) => r.id == _localId);
}

class _ServerInvoices implements InvoiceRepository {
  _ServerInvoices(this.rows);

  final List<Invoice> rows;

  @override
  Future<List<Invoice>> list({
    required String type,
    String? search,
    DateTime? from,
    DateTime? to,
  }) async => [
    for (final r in rows)
      if (r.type == type) r,
  ];

  @override
  Future<List<InvoiceItem>> items(String invoiceId) async => const [];

  /// This suite is about the invoice HEADER's money authority, never its lines,
  /// so the batch answer is deliberately empty for every id rather than absent:
  /// an empty answer is "the server has no lines", which mirrors nothing harmful
  /// here, while a `failed` id would have exercised the wrong code path.
  @override
  Future<InvoiceItemsBatch> itemsForInvoices(List<String> invoiceIds) async =>
      InvoiceItemsBatch(
        items: {for (final id in invoiceIds) id: const <InvoiceItem>[]},
        failed: const {},
      );
}

class _OkTarget implements SyncTarget {
  @override
  Future<Map<String, dynamic>> rpc(
    String name,
    Map<String, dynamic> params,
  ) async => <String, dynamic>{'payment_id': 'server-payment-1'};

  @override
  Future<Map<String, dynamic>> tableUpsert(
    String entity,
    String id,
    Map<String, dynamic> row,
  ) async => <String, dynamic>{...row, 'id': id};

  @override
  Future<void> tableDelete(String entity, String id) async {}
}
