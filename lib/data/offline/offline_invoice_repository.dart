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
/// Unsynced locally-created drafts merge on top of whatever the network or
/// cache returned, so an offline-created invoice shows up in the list (and its
/// items resolve locally) until the drain marks it synced.
class OfflineInvoiceRepository implements InvoiceRepository {
  OfflineInvoiceRepository(this._inner, {required this.store, required this.tenantId});

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
        network: () => _inner.list(type: type, search: search, from: from, to: to),
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
      final drafts = await _localDrafts();
      if (drafts.isNotEmpty) {
        return _merged(const [], drafts, type: type, search: search, from: from, to: to);
      }
      rethrow;
    }
    final drafts = await _localDrafts();
    return _merged(base, drafts, type: type, search: search, from: from, to: to);
  }

  @override
  Future<List<InvoiceItem>> items(String invoiceId) async {
    final key = 'invItems:$invoiceId';
    try {
      return await cacheLast(
        store: store,
        tenantId: tenantId,
        key: key,
        network: () => _inner.items(invoiceId),
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
    } on NetworkException {
      return _localItems(invoiceId);
    }
  }

  /// Unsynced invoice drafts (row synced == false), including draft items.
  Future<List<LocalInvoiceRow>> _localDrafts() async {
    final s = store;
    final t = tenantId;
    if (s == null || t == null) return const [];
    final rows = await s.invoices(t);
    return [for (final r in rows) if (!r.synced) r];
  }

  Future<List<Invoice>> _merged(
    List<Invoice> base,
    List<LocalInvoiceRow> drafts, {
    required String type,
    String? search,
    DateTime? from,
    DateTime? to,
  }) async {
    if (drafts.isEmpty) return base;
    final known = {for (final i in base) i.id};
    final sql = search?.trim().toLowerCase();
    final result = <Invoice>[...base];
    for (final r in drafts) {
      if (r.type != type) continue;
      if (from != null && r.date.isBefore(from)) continue;
      if (to != null && r.date.isAfter(to)) continue;
      if (sql != null && sql.isNotEmpty) {
        final hay = '${r.no} ${r.partyName ?? ''}'.toLowerCase();
        if (!hay.contains(sql)) continue;
      }
      if (known.contains(r.id)) continue;
      result.add(_rowToInvoice(r));
      known.add(r.id);
    }
    if (drafts.isNotEmpty) {
      result.sort((a, b) => b.date.compareTo(a.date));
    }
    return result;
  }

  Future<List<InvoiceItem>> _localItems(String invoiceId) async {
    final s = store;
    if (s == null || tenantId == null) return const [];
    return [
      for (final r in await s.invoiceItems(invoiceId))
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