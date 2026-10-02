import 'dart:convert';

import '../../core/error/app_exception.dart';
import '../../domain/invoices/invoice.dart';
import '../../domain/products/product.dart';
import '../invoices/invoice_repository.dart';
import 'local_database.dart';
import 'local_store.dart';
import 'offline_reads.dart';
import 'report_keys.dart';

/// [InvoiceRepository] that cache-lasts invoice lists and their line items
/// (headers already carry party names, so the resolved list round-trips).
///
/// The local mirror is authoritative for exactly two situations, and for
/// nothing else: an unsynced draft (`synced == false`), and a synced row a
/// pending money leg has restated (`pendingMoneyLeg != null`). Anything else
/// keeps the network/cache representation, so a stale mirror can never
/// overwrite a fresher server row. See [_localOverrides] for the rule and
/// [_merged] for how the two representations combine.
class OfflineInvoiceRepository implements InvoiceRepository {
  OfflineInvoiceRepository(
    this._inner, {
    required this.store,
    required this.tenantId,
  });

  final InvoiceRepository _inner;
  final LocalStore? store;
  final String? tenantId;

  @override
  Future<List<Invoice>> list({
    required String type,
    String? search,
    DateTime? from,
    DateTime? to,
  }) async {
    final key = invoiceListKey(type: type, search: search, from: from, to: to);
    final List<Invoice> base;
    try {
      base = await cacheLast(
        store: store,
        tenantId: tenantId,
        key: key,
        network: () =>
            _inner.list(type: type, search: search, from: from, to: to),
        fromCached: (payload) => [
          for (final m in jsonDecode(payload) as List)
            if (m is Map) Invoice.fromJson(m.cast<String, dynamic>()),
        ],
        toPayload: (invoices) => jsonEncode([
          for (final i in invoices)
            {
              'id': i.id,
              'type': i.type,
              'no': i.no,
              'party_id': i.partyId,
              'party_name': i.partyName,
              'date': cacheDate(i.date),
              'subtotal': i.subtotal,
              'total': i.total,
              'paid': i.paid,
              'remaining': i.remaining,
              'status': i.status.dbValue,
              'ownership': i.ownership.name,
            },
        ]),
      );
    } on NetworkException {
      // No network and no cached report: the only rows on offer are the local
      // overrides, and those were read OUT of the mirror, so every returned
      // invoice is already locally resolvable. There is nothing to hydrate.
      final local = await _localOverrides();
      if (local.isNotEmpty) {
        return _merged(
          const [],
          local,
          type: type,
          search: search,
          from: from,
          to: to,
        );
      }
      rethrow;
    }
    final local = await _localOverrides();
    final merged = await _merged(
      base,
      local,
      type: type,
      search: search,
      from: from,
      to: to,
    );
    // Issue 3 / Phase 2: the durable cache is the one list source that used to
    // skip the mirror entirely, so an invoice painted from `report_cache` had
    // no `local_invoices` row and `recordPayment` / `settleSupplier` rejected it
    // as "الفاتورة غير موجودة محلياً" — visible but not writable.
    //
    // Hydration is therefore a REPOSITORY BOUNDARY obligation, not a
    // `cacheLast` concern, and it runs on the FINAL list so it covers whichever
    // source answered (network, or the report-cache key for THIS exact
    // type/search/date filter). `cacheLast` reports nothing about which branch
    // produced its value, so a cache-only path is not expressible without
    // changing the shared helper — hence one point, and no `mirror:` callback
    // above (it would mirror the network path a second time).
    //
    // Deliberately NOT wrapped in a swallow: returning a list whose hydration
    // failed is precisely the "visible but not locally writable" state this
    // fixes. The only cross-tenant same-PK id is skipped inside `mirrorInvoices`
    // by partitioning (the documented structural exception), so nothing
    // expected raises here — a genuine storage fault is surfaced, not hidden.
    await _mirrorHeaders(merged);
    await _prefetchDetails(merged);
    return merged;
  }

  /// Hydrates the LINE detail of every listed invoice that does not already
  /// have durable lines, so opening a detail sheet offline shows a body instead
  /// of an empty list.
  ///
  /// ## Why this is not simply `items()` in a loop
  ///
  /// P1.E made the lines durable, but only for the invoice the user actually
  /// opened: `items(id)` is what writes `local_invoice_items`, so a device that
  /// listed twenty invoices and opened none of them had headers and no lines.
  /// That is the defect this closes — and the obvious fix, a loop of
  /// `items(id)`, is exactly what must not be written:
  ///
  ///  * **It is N+1.** Twenty invoices is twenty round trips, twenty chances to
  ///    fail halfway, and a list screen that used to be one request now stalls
  ///    on twenty. The whole point of the batch API is that one logical call
  ///    covers the page, and `InvoiceRepository.itemsForInvoices` owns the
  ///    100-id transport bound on its own.
  ///  * **It would re-fetch forever.** `items(id)` cache-lasts per invoice, and
  ///    re-asking an invoice whose lines are already durable buys nothing while
  ///    costing a request on EVERY list refresh — including every refresh the
  ///    app makes while offline, which would then fail one request per invoice
  ///    per refresh. So the candidates are narrowed by ONE bulk local query
  ///    (`invoiceIdsWithDurableItems`, a single grouped scan) and only the
  ///    genuinely missing ones are asked for.
  ///
  /// ## Ordering, and which ids are asked for
  ///
  /// This runs AFTER `_mirrorHeaders` on purpose. `mirrorInvoiceItems` refuses
  /// to sweep an unsynced header, and the header write is what turns a
  /// server-listed id into a local row the lines can be keyed against.
  ///
  /// The candidates are the ids of `merged` as the caller SEES them, which for a
  /// replayed invoice is the SERVER id while its rows are keyed by the LOCAL one.
  /// That mismatch has to be resolved on BOTH sides of the prefetch, and each side
  /// once: `invoiceIdsWithDurableItems` maps the candidates before comparing, or a
  /// replayed invoice whose lines are already durable looks permanently missing and
  /// is re-requested on every refresh forever; and every answer is re-keyed through
  /// `localIdFor` before it is mirrored, or mirroring under the server id creates a
  /// SECOND set of lines beside the local one — the same id-space split this file has
  /// already been bitten by twice. An unsynced draft's local id *is* its
  /// server-shaped id here (the server never issued it), so it has no mapping row,
  /// resolves to itself on both sides, and is unchanged.
  ///
  /// ## Failure is not empty
  ///
  /// `InvoiceItemsBatch` keeps "answered with nothing" (`items[id] == []`) apart
  /// from "not answered" (`failed`). Only the first is mirrored — and an empty
  /// answer legitimately CLEARS a synced invoice's lines, because the server is
  /// the authority for a synced invoice and it just said there are none. An id
  /// in `failed` is never mirrored, so an offline or partial read leaves the
  /// durable rows exactly as they were.
  ///
  /// The list itself must never depend on this, so a `NetworkException` from the
  /// read is swallowed: the headers are already mirrored and returned either
  /// way, and hydration is an improvement, not a precondition. The `failed` set
  /// is what carries the outcome when the read half-succeeds.
  Future<void> _prefetchDetails(List<Invoice> invoices) async {
    final s = store;
    final t = tenantId;
    if (s == null || t == null || invoices.isEmpty) return;

    // The candidates are the ids of `merged` as the caller SEES them. That is the
    // SERVER id for a replayed invoice while its rows are keyed by the LOCAL one,
    // so the durable comparison resolves the mapping — inside the store, as one
    // bounded lookup (see `LocalStore.invoiceIdsWithDurableItems`).
    final ids = <String>{for (final i in invoices) i.id};
    if (ids.isEmpty) return;

    final durable = await s.invoiceIdsWithDurableItems(t, ids.toList());
    final missing = [
      for (final id in ids)
        if (!durable.contains(id)) id,
    ];
    if (missing.isEmpty) return;

    // `NetworkException` only, and only around the network read. The production
    // repository answers with `failed` per chunk rather than throwing, so this
    // is the belt to that braces: an inner repository that DOES throw on an
    // unreachable server must not take the header list down with it, which is
    // the exact symptom this hydration is optional for.
    //
    // Deliberately not `catch (Object)`. The durable-lookup above and the
    // mirror below are local drift work, and P1.D already recorded why a
    // genuine drift failure there must surface rather than be reported as a
    // successful read whose invoices silently do not resolve.
    final InvoiceItemsBatch batch;
    try {
      batch = await _inner.itemsForInvoices(missing);
    } on NetworkException {
      return;
    }
    for (final id in batch.items.keys) {
      // Resolve into the LOCAL id space before writing. See the class comment:
      // mirroring under the server id would duplicate a replayed invoice's
      // lines instead of refreshing them.
      final localId = await s.localIdFor(t, 'invoices', id) ?? id;
      await _mirrorItems(t, localId, batch.items[id]!);
    }
    // `batch.failed` is intentionally NOT iterated: it means "unanswered", and
    // the only correct response to unanswered is to leave the mirror alone.
  }

  /// The detail body: the products, quantities and per-line totals of one
  /// invoice.
  ///
  /// ## What P1.E changed, and why each half is load-bearing
  ///
  /// Before, this cache-lasted the response and returned it, and nothing else:
  /// `local_invoice_items` was written ONLY by the offline create paths, so a
  /// server invoice's lines lived only as a JSON blob in `report_cache` and the
  /// sheet went empty the moment that one key was gone. Two further breaks fell
  /// out of the same trace:
  ///
  ///  * **The id may be the server's.** `markReplaySynced` keeps the LOCAL uuid
  ///    as `local_invoices.id` (the sync badge joins the queue on the leg's
  ///    `localId`) and records local to server in `id_map`, while the list
  ///    serves the SERVER row. So the sheet is handed a server id while the
  ///    lines are keyed by the local one — the same id-space split P1.D fixed
  ///    for headers, and it is why `_invoice` resolves through `localIdFor`.
  ///  * **A cached `[]` masks good local rows.** `cacheLast` writes whatever the
  ///    network returned, including an empty list. Open a *pending* draft while
  ///    online (the server answers `[]`, having never seen it), go offline, and
  ///    `fromCached` returns `[]` before the `NetworkException` fallback can
  ///    ever reach the rows `writeSale` durably wrote.
  ///
  /// Hence the order below: an unsynced draft never touches `cacheLast` at all,
  /// and a synced read mirrors whatever finally answered — network OR cache —
  /// so a device holding only a legacy cache entry self-heals on first read with
  /// no Clear Data.
  ///
  /// The mirror is deliberately NOT wrapped in a swallow, and NOT delegated to
  /// `cacheLast`'s `mirror:` hook, for the two reasons P1.D established: the
  /// hook only fires on the network branch (the one that already worked), and a
  /// genuine storage fault reported as a successful read is the "visible but not
  /// locally resolvable" lie this phase exists to remove.
  @override
  Future<List<InvoiceItem>> items(String invoiceId) async {
    final s = store;
    final t = tenantId;
    if (s == null || t == null) return _inner.items(invoiceId);

    // A replayed invoice is stored under the local uuid and served under the
    // server one, so the mapping is resolved BEFORE anything is read or written
    // — otherwise a refresh would create a second set under the server id and
    // the two would never agree.
    final localId = await s.localIdFor(t, 'invoices', invoiceId) ?? invoiceId;

    // The SYMMETRIC lookup, and the reason a detail read is normalized in both
    // directions. A read can legitimately arrive holding the LOCAL uuid: a sheet
    // mounted before the replay captured the row under L, and `_liveInvoice`
    // resolves by that captured id, so it no longer matches the S the list now
    // exposes and falls back to the snapshot. The server has never issued an L,
    // so reading it asks the server about an invoice that does not exist — the
    // empty answer that starts all of this.
    //
    // `id_map` already holds L→S, so the REMOTE read is normalized into the
    // server's id space here, while the local side stays [localId], which is
    // where the mirror is keyed. Doing it in this layer rather than in the widget
    // keeps id-map knowledge out of the presentation layer — and it also means a
    // stale caller cannot ask the server an unanswerable question, which is what
    // lets a non-empty answer repair rows an older build already erased.
    final remoteId = await s.serverIdFor(t, 'invoices', localId) ?? invoiceId;

    // A draft the server has never seen has exactly one source of truth. Its
    // header carries `synced == false`, and its lines were written in the same
    // transaction that created it, so the local rows are already durable and the
    // cacheLast path can only ever contribute a stale or empty answer.
    final header = await s.invoice(t, localId);
    if (header != null && !header.synced) return _localItems(t, localId);

    try {
      final value = await cacheLast(
        store: store,
        tenantId: tenantId,
        // The historical key, kept as a literal on purpose: every device that
        // ever opened a detail online has a row under exactly this key, and
        // the self-heal above is only possible because the key did not move.
        //
        // Keyed by the REMOTE id, which for a non-replayed invoice is the id
        // that was passed in — so no existing key moves, and the legacy
        // self-heal is unaffected. For a replayed invoice read under its local
        // uuid it moves to `invItems:<S>`, which sidesteps the empty entry the
        // stale read wrote under `invItems:<L>`.
        key: 'invItems:$remoteId',
        network: () => _inner.items(remoteId),
        fromCached: (payload) => [
          for (final m in jsonDecode(payload) as List)
            if (m is Map) _itemFromJson(m.cast<String, dynamic>()),
        ],
        toPayload: (items) => jsonEncode([
          for (final it in items)
            {
              'product_id': it.productId,
              'product_name': it.productName,
              'product_unit': it.productUnit,
              'product_unit_type': it.productUnitType?.name,
              'qty': it.qty,
              'price': it.price,
              'total': it.total,
            },
        ]),
      );
      // The FINAL value, so whichever branch answered is the one that becomes
      // durable. This is what makes the legacy self-heal free.
      //
      // An EMPTY result is never authoritative, and must never be mirrored.
      // `create_sale_invoice` and `create_purchase_invoice` both reject a
      // zero-line invoice, so no state a supported server can be in has an
      // invoice with no lines: an empty answer means the server was asked about
      // an identity it never issued (or answered incompletely), not that the
      // invoice lost its lines. `mirrorInvoiceItems` sweeps before it inserts,
      // so mirroring `[]` would DELETE the only durable copy of them, and that
      // loss survives a restart — permanently unrecoverable for the user.
      //
      // This is deliberately NOT a change to `mirrorInvoiceItems`, which is
      // correct replace-all semantics for a caller that has just been handed the
      // full truth. The "an empty answer is not the truth" rule belongs here,
      // where what a remote `[]` MEANS for invoice detail is known. A non-empty
      // answer stays authoritative below, which is also what repairs rows an
      // older build already erased.
      if (value.isEmpty) {
        final durable = await _localItems(t, localId);
        return durable;
      }

      await _mirrorItems(t, localId, value);
      return value;
    } on NetworkException {
      return _localItems(t, localId);
    }
  }

  /// A PASS-THROUGH, deliberately.
  ///
  /// The offline wrapper exists to hydrate the mirror, and that job belongs to
  /// `list()` ([_prefetchDetails]) where the whole candidate set is known — one
  /// bulk read and one batch call. This method is the raw transport, and it
  /// must not mirror: mirroring here would (a) make `itemsForInvoices` write
  /// while the caller is still deciding what is durable, and (b) tempt a future
  /// caller into resolving ids without the `localIdFor` re-key, reintroducing
  /// the duplicate-line defect documented on [items]. A caller that genuinely
  /// wants the mirror should call `items()` per invoice, which already does it.
  @override
  Future<InvoiceItemsBatch> itemsForInvoices(List<String> invoiceIds) =>
      _inner.itemsForInvoices(invoiceIds);

  /// Writes a synced invoice's lines into the mirror so the detail body survives
  /// an offline restart.
  ///
  /// Runs on the final value rather than inside the network branch — the
  /// network is not the only thing that produces lines, and a cache-only device
  /// is exactly the one that needs the mirror most.
  Future<void> _mirrorItems(
    String tenant,
    String invoiceLocalId,
    List<InvoiceItem> items,
  ) async {
    final s = store;
    if (s == null) return;
    await s.mirrorInvoiceItems(tenant, invoiceLocalId, [
      for (final it in items)
        LocalInvoiceItemRow(
          id: '',
          tenantId: tenant,
          invoiceId: invoiceLocalId,
          productId: it.productId,
          productName: it.productName,
          productUnit: it.productUnit,
          productUnitType: it.productUnitType?.dbValue,
          qty: it.qty,
          price: it.price,
          total: it.total,
        ),
    ]);
  }

  /// Invoice rows the local mirror is authoritative for, i.e. exactly two
  /// kinds and nothing else:
  ///
  ///  * **unsynced drafts** (`synced == false`) — created offline, never seen by
  ///    the server at all;
  ///  * **synced rows with an outstanding money leg** (`pendingMoneyLeg !=
  ///    null`) — an offline `record_payment` / `settle_supplier` allocation
  ///    restated the row's `paid` / `remaining` / `status`, and the server has
  ///    not confirmed it yet.
  ///
  /// A synced row with a null marker is deliberately **excluded**: it is just a
  /// mirror copy of a server row, so letting it into the merge would let a
  /// stale mirror overwrite fresher server data (and could resurrect a row the
  /// server dropped). The marker is what proves a local mutation is pending,
  /// which is exactly the condition under which the local figures are the
  /// truth.
  /// Writes the server's invoice headers into the mirror (issue 3).
  ///
  /// Header fields only, copied verbatim, and with every piece of local
  /// metadata synthesised as "this row belongs to the server": `synced: true`
  /// so the read path keeps treating the server as authoritative for it, and
  /// `requestId` / `createdAt` / `pendingMoneyLeg` all null, because no local
  /// write ever produced this row — inventing a request id would make the row
  /// look like a replayable local mutation. A null `partyName` stays null;
  /// `LocalInvoiceRow.partyName` is nullable precisely so the mirror does not
  /// have to invent one.
  ///
  /// Only the fields an invoice header actually has are copied. Line items are
  /// NOT mirrored: nothing on the payment or settlement path needs them, and
  /// caching them would invent a second source of truth for line-level data.
  Future<void> _mirrorHeaders(List<Invoice> invoices) async {
    final s = store;
    final t = tenantId;
    if (s == null || t == null || invoices.isEmpty) return;
    await s.mirrorInvoices(t, [
      for (final i in invoices)
        LocalInvoiceRow(
          id: i.id,
          tenantId: t,
          type: i.type,
          no: i.no,
          partyId: i.partyId,
          partyName: i.partyName,
          date: i.date,
          subtotal: i.subtotal,
          total: i.total,
          paid: i.paid,
          remaining: i.remaining,
          status: i.status.dbValue,
          ownership: i.ownership.name,
          requestId: null,
          synced: true,
          createdAt: null,
          pendingMoneyLeg: null,
        ),
    ]);
  }

  Future<List<LocalInvoiceRow>> _localOverrides() async {
    final s = store;
    final t = tenantId;
    if (s == null || t == null) return const [];
    final rows = await s.invoices(t);
    return [
      for (final r in rows)
        if (!r.synced || r.pendingMoneyLeg != null) r,
    ];
  }

  Future<List<Invoice>> _merged(
    List<Invoice> base,
    List<LocalInvoiceRow> local, {
    required String type,
    String? search,
    DateTime? from,
    DateTime? to,
  }) async {
    if (local.isEmpty) return base;
    final known = {for (final i in base) i.id: i};
    final sql = search?.trim().toLowerCase();
    final result = <Invoice>[...base];
    var added = false;
    for (final r in local) {
      if (r.type != type) continue;
      if (from != null && r.date.isBefore(from)) continue;
      if (to != null && r.date.isAfter(to)) continue;
      if (sql != null && sql.isNotEmpty) {
        final hay = '${r.no} ${r.partyName ?? ''}'.toLowerCase();
        if (!hay.contains(sql)) continue;
      }
      final existing = known[r.id];
      if (existing == null) {
        // A local row the server/cache does not carry at all: an unsynced
        // draft, or a marked row the filtered server list dropped. Either way
        // the local row is the only representation there is, so it is shown.
        result.add(_rowToInvoice(r));
        known[r.id] = _rowToInvoice(r);
        added = true;
        continue;
      }
      if (r.synced) {
        // Synced + marked: the server stays authoritative for identity (its
        // official number, party, date, totals — the ones a background refresh
        // may have moved on) and only the money fields the pending leg changed
        // are taken locally. An unmarked synced row never reaches this branch.
        result[result.indexWhere((i) => i.id == r.id)] = _withLocalMoney(
          existing,
          r,
        );
        known[r.id] = _withLocalMoney(existing, r);
      }
      // An unsynced draft already present in the server list is a leftover, not
      // something to overwrite: the draft id is a local uuid the server has
      // never issued, so the base entry is a different invoice.
    }
    if (added || local.isNotEmpty) {
      result.sort((a, b) => b.date.compareTo(a.date));
    }
    return result;
  }

  /// Server row + locally-mutated money fields, keeping the server's identity.
  static Invoice _withLocalMoney(Invoice server, LocalInvoiceRow local) =>
      Invoice(
        id: server.id,
        type: server.type,
        no: server.no,
        partyId: server.partyId,
        partyName: server.partyName,
        date: server.date,
        subtotal: server.subtotal,
        total: server.total,
        paid: local.paid,
        remaining: local.remaining,
        status: InvoiceStatus.fromDb(local.status),
        ownership: server.ownership,
      );

  Future<List<InvoiceItem>> _localItems(String tenant, String invoiceId) async {
    final s = store;
    if (s == null) return const [];
    return [
      for (final r in await s.invoiceItems(tenant, invoiceId))
        InvoiceItem(
          productId: r.productId ?? '',
          productName: r.productName,
          productUnit: r.productUnit,
          productUnitType: r.productUnitType == null
              ? null
              : ProductUnitType.fromDb(r.productUnitType!),
          qty: r.qty,
          price: r.price,
          total: r.total,
        ),
    ];
  }

  static Invoice _rowToInvoice(LocalInvoiceRow r) => Invoice(
    id: r.id,
    type: r.type,
    no: r.no,
    partyId: r.partyId,
    partyName: r.partyName,
    date: r.date,
    subtotal: r.subtotal,
    total: r.total,
    paid: r.paid,
    remaining: r.remaining,
    status: InvoiceStatus.fromDb(r.status),
    ownership: r.ownership == 'consignment'
        ? InvoiceOwnership.consignment
        : InvoiceOwnership.owned,
  );

  static InvoiceItem _itemFromJson(Map<String, dynamic> json) => InvoiceItem(
    productId: json['product_id'] as String,
    productName: json['product_name'] as String?,
    productUnit: json['product_unit'] as String?,
    productUnitType: json['product_unit_type'] == null
        ? null
        : ProductUnitType.fromDb(json['product_unit_type'] as String),
    qty: (json['qty'] as num).toDouble(),
    price: (json['price'] as num).toInt(),
    total: (json['total'] as num).toInt(),
  );
}
