import 'dart:math' show min;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/error/app_exception.dart';
import '../../domain/invoices/invoice.dart';
import '../../domain/products/product.dart';

/// The answer to "give me the lines of these invoices", as ONE call.
///
/// A named class rather than a bare map or a `(items, ok)` pair, because the
/// three outcomes a caller must never confuse are easy to collapse by accident:
///
/// * `items[id]` is **present and non-empty** — answered, and it has lines.
/// * `items[id]` is **present and empty** — answered, and it genuinely has NO
///   lines. `mirrorInvoiceItems` is replace-all, so mirroring this empties the
///   invoice's local lines, which is correct: the server is the authority for a
///   synced invoice.
/// * `id in failed` — **not answered at all**. The caller's existing durable
///   local rows for that invoice MUST be left exactly as they are. Erasing them
///   because a network read failed is how durable lines disappear offline.
///
/// `items` and `failed` are disjoint: an id is in exactly one of them.
class InvoiceItemsBatch {
  const InvoiceItemsBatch({required this.items, required this.failed});

  const InvoiceItemsBatch.empty()
      : items = const {},
        failed = const {};

  /// Requested invoice id -> its lines, sorted by the server's `invoice_items.id`.
  /// A key is present iff that invoice was answered successfully, so an empty
  /// list is a real answer rather than a missing one.
  final Map<String, List<InvoiceItem>> items;

  /// Requested ids that were not answered. A `Set`, not a `List`: the caller
  /// only ever tests membership, and duplicates carry no information.
  final Set<String> failed;

  /// Every requested id this batch had an opinion about.
  Iterable<String> get answered => items.keys;
}

/// Hard ceiling on how many invoice ids may appear in ONE PostgREST
/// `inFilter('invoice_id', …)` request.
///
/// A URL-length ceiling the SDK cannot negotiate, so it is enforced here, in
/// the one method that owns the transport. 100 is deliberately far below the
/// practical PostgREST/header limit: a page of invoices is at most a few
/// hundred, so this is normally a single request.
const int kInvoiceItemsBatchSize = 100;

/// Splits [ids] into consecutive chunks of at most [size].
///
/// Extracted from `InvoiceRepository.itemsForInvoices` so the bound is
/// testable without a live Supabase client — the fake a test controls cannot
/// observe how the real client would have chunked, so asserting the bound on a
/// fake proves nothing about production. This is the SAME function production
/// uses, not a re-implementation: a test-only copy of a chunker is a test of
/// the copy.
///
/// Not annotated `@visibleForTesting` on purpose: `package:meta` is not a
/// direct dependency of this package and importing it transitively is an
/// analyzer `depend_on_referenced_packages` error.
List<List<String>> chunkInvoiceIds(
  List<String> ids, {
  int size = kInvoiceItemsBatchSize,
}) {
  if (size < 1) throw ArgumentError.value(size, 'size', 'must be >= 1');
  if (ids.isEmpty) return const [];
  final out = <List<String>>[];
  for (var i = 0; i < ids.length; i += size) {
    out.add(ids.sublist(i, min(i + size, ids.length)));
  }
  return out;
}

/// Reads invoice headers (and line item detail) from the `invoices` table,
/// protected by RLS. Party names are resolved in Dart because invoices use a
/// polymorphic party_id (customer or supplier).
class InvoiceRepository {
  const InvoiceRepository(this._client);

  final SupabaseClient _client;

  Future<List<Invoice>> list({
    required String type,
    String? search,
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      var query = _client
          .from('invoices')
          .select(
            'id, type, no, party_id, date, subtotal, total, paid, '
            'remaining, status, ownership',
          );

      if (search != null && search.trim().isNotEmpty) {
        query = query.or('no.ilike.%${search.trim()}%');
      }
      if (from != null) {
        query = query.gte('date', _isoDate(from));
      }
      if (to != null) {
        query = query.lte('date', _isoDate(to));
      }

      final rows = await query.eq('type', type).order('date', ascending: false);
      final invoices = rows.map(Invoice.fromJson).toList();
      return await _attachPartyNames(invoices);
    } on Object catch (error) {
      throw mapErrorToAppException(error);
    }
  }

  Future<List<InvoiceItem>> items(String invoiceId) async {
    try {
      final rows = await _client
          .from('invoice_items')
          .select(
            'product_id, qty, price, total, products(name, unit, unit_type)',
          )
          .eq('invoice_id', invoiceId);

      return [
        for (final r in rows)
          InvoiceItem(
            productId: r['product_id'] as String,
            productName: (r['products'] as Map?)?['name'] as String?,
            productUnit: (r['products'] as Map?)?['unit'] as String?,
            productUnitType: _unitTypeOf(r['products'] as Map?),
            qty: (r['qty'] as num).toDouble(),
            price: (r['price'] as num).toInt(),
            total: (r['total'] as num).toInt(),
          ),
      ];
    } on Object catch (error) {
      throw mapErrorToAppException(error);
    }
  }

  /// Line items for MANY invoices in one logical batch, so a list read can
  /// hydrate its detail without an N+1 request storm.
  ///
  /// This is the ONLY place invoice-id chunking lives. Callers pass the whole
  /// candidate set once and this method guarantees the transport invariant: no
  /// PostgREST request ever carries more than [kInvoiceItemsBatchSize] ids.
  /// Do not add a chunk loop to a caller — a second loop is a second place to
  /// get the bound wrong, and it cannot be observed from here.
  ///
  /// [items] and [InvoiceItemsBatch.failed] are disjoint by contract. A chunk
  /// that throws puts its ids in [failed] and touches nothing else, so one
  /// failing chunk cannot erase the durable lines of the invoices that
  /// succeeded. Sequential, not parallel: the chunks are all part of one
  /// user-visible list read and a slow link should degrade one chunk at a time
  /// rather than open N sockets at once.
  ///
  /// Never throws for a per-chunk failure — inspect [failed] instead. An
  /// all-failed call is a legitimate answer (the device is offline), and it
  /// must not read as "every invoice has no lines".
  Future<InvoiceItemsBatch> itemsForInvoices(List<String> invoiceIds) async {
    if (invoiceIds.isEmpty) return const InvoiceItemsBatch.empty();

    // De-duplicate while PRESERVING order: the same id listed twice must not
    // consume two slots in a chunk and shrink the effective batch size.
    final ids = <String>[];
    final seen = <String>{};
    for (final id in invoiceIds) {
      if (seen.add(id)) ids.add(id);
    }

    final items = <String, List<InvoiceItem>>{};
    final failed = <String>{};
    for (final chunk in chunkInvoiceIds(ids)) {
      try {
        // `invoice_id` is in the select because this is the grouping key; the
        // single-invoice path never needed it.
        //
        // `.order('id')` is a STABLE total order (invoice_items.id is a uuid
        // primary key), which is what re-hydration idempotence needs: the same
        // invoice read twice must produce the same line sequence so the local
        // positional ids it is assigned do not reshuffle. It is deliberately
        // NOT the original insertion order — the table has no ordinal column
        // and inventing one is a schema change this slice does not make. See
        // the P1.E note on legacy bare-uuid line ids being unrecoverable in the
        // same way.
        final rows = await _client
            .from('invoice_items')
            .select(
              'invoice_id, product_id, qty, price, total, '
              'products(name, unit, unit_type)',
            )
            .inFilter('invoice_id', chunk)
            .order('id');

        final byInvoice = <String, List<InvoiceItem>>{
          for (final id in chunk) id: <InvoiceItem>[],
        };
        for (final r in rows) {
          final invoiceId = r['invoice_id'] as String;
          // RLS can only ever return rows for invoices we asked about, but a
          // row whose key is missing would silently vanish — create the bucket
          // instead of dropping a line on the floor.
          (byInvoice[invoiceId] ??= <InvoiceItem>[]).add(
            InvoiceItem(
              productId: r['product_id'] as String,
              productName: (r['products'] as Map?)?['name'] as String?,
              productUnit: (r['products'] as Map?)?['unit'] as String?,
              productUnitType: _unitTypeOf(r['products'] as Map?),
              qty: (r['qty'] as num).toDouble(),
              price: (r['price'] as num).toInt(),
              total: (r['total'] as num).toInt(),
            ),
          );
        }
        items.addAll(byInvoice);
      } on Object catch (_) {
        failed.addAll(chunk);
      }
    }
    return InvoiceItemsBatch(items: items, failed: failed);
  }

  ProductUnitType? _unitTypeOf(Map? product) => product == null
      ? null
      : ProductUnitType.fromDb(product['unit_type'] as String? ?? 'count');

  Future<List<Invoice>> _attachPartyNames(List<Invoice> invoices) async {
    if (invoices.isEmpty) return invoices;
    final customerIds = <String>{
      for (final i in invoices)
        if (i.type == 'sale') i.partyId,
    };
    final supplierIds = <String>{
      for (final i in invoices)
        if (i.type == 'purchase') i.partyId,
    };

    final names = <String, String>{};
    if (customerIds.isNotEmpty) {
      final rows = await _client
          .from('customers')
          .select('id, name')
          .inFilter('id', customerIds.toList());
      for (final r in rows) {
        names[r['id'] as String] = r['name'] as String;
      }
    }
    if (supplierIds.isNotEmpty) {
      final rows = await _client
          .from('suppliers')
          .select('id, name')
          .inFilter('id', supplierIds.toList());
      for (final r in rows) {
        names[r['id'] as String] = r['name'] as String;
      }
    }

    return [
      for (final i in invoices)
        Invoice(
          id: i.id,
          type: i.type,
          no: i.no,
          partyId: i.partyId,
          partyName: names[i.partyId],
          date: i.date,
          subtotal: i.subtotal,
          total: i.total,
          paid: i.paid,
          remaining: i.remaining,
          status: i.status,
          ownership: i.ownership,
        ),
    ];
  }

  String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
