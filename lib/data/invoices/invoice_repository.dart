import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/error/app_exception.dart';
import '../../domain/invoices/invoice.dart';
import '../../domain/products/product.dart';

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
          .select('id, type, no, party_id, date, subtotal, total, paid, '
              'remaining, status, ownership');

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
          .select('product_id, qty, price, total, products(name, unit, unit_type)')
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