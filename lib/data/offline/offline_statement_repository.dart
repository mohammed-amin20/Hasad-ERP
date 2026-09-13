import 'dart:convert';

import '../../domain/invoices/invoice.dart';
import '../../domain/statements/debts_repository.dart';
import '../../domain/statements/statement.dart';
import 'local_store.dart';
import 'offline_reads.dart';
import 'report_keys.dart';

/// [StatementRepository] that cache-lasts the party statement envelope.
class OfflineStatementRepository implements StatementRepository {
  OfflineStatementRepository(this._inner, {required this.store, required this.tenantId});

  final StatementRepository _inner;
  final LocalStore? store;
  final String? tenantId;

  @override
  Future<PartyStatement> statement(StatementRequest request) {
    final key = statementKey(request);
    return cacheLast(
      store: store,
      tenantId: tenantId,
      key: key,
      network: () => _inner.statement(request),
      fromCached: (payload) =>
          PartyStatement.fromJson((jsonDecode(payload) as Map).cast<String, dynamic>()),
      toPayload: (s) => jsonEncode({
        'party_type': s.partyType,
        'party_id': s.partyId,
        'from': cacheDate(s.from),
        'to': cacheDate(s.to),
        'opening': s.opening,
        'closing': s.closing,
        'lines': [
          for (final l in s.lines)
            {
              'date': cacheDate(l.date),
              'kind': switch (l.kind) {
                StatementLineKind.payment => 'payment',
                StatementLineKind.commission => 'commission',
                StatementLineKind.invoice => 'invoice',
              },
              'ref': l.ref,
              'note': l.note,
              'debit': l.debit,
              'credit': l.credit,
            },
        ],
      }),
    );
  }
}

/// [DebtsRepository] that cache-lasts the aggregated party balances.
class OfflineDebtsRepository implements DebtsRepository {
  OfflineDebtsRepository(this._inner, {required this.store, required this.tenantId});

  final DebtsRepository _inner;
  final LocalStore? store;
  final String? tenantId;

  static const _customersKey = debtsCustomersKey;
  static const _suppliersKey = debtsSuppliersKey;

  @override
  Future<List<PartyBalance>> customerBalances() => _cacheBalances(
        key: _customersKey,
        network: _inner.customerBalances,
      );

  @override
  Future<List<PartyBalance>> supplierBalances() => _cacheBalances(
        key: _suppliersKey,
        network: _inner.supplierBalances,
      );

  @override
  Future<int> supplierInvoiceDebt(String supplierId) =>
      _inner.supplierInvoiceDebt(supplierId);

  @override
  Future<int> supplierCommissionDebt(String supplierId) =>
      _inner.supplierCommissionDebt(supplierId);

  @override
  Future<List<Invoice>> partyInvoices({
    required String type,
    required String partyId,
  }) {
    final key = partyInvoicesKey(type, partyId);
    return cacheLast(
      store: store,
      tenantId: tenantId,
      key: key,
      network: () => _inner.partyInvoices(type: type, partyId: partyId),
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
  }

  Future<List<PartyBalance>> _cacheBalances({
    required String key,
    required Future<List<PartyBalance>> Function() network,
  }) => cacheLast(
        store: store,
        tenantId: tenantId,
        key: key,
        network: network,
        fromCached: (payload) => [
          for (final m in jsonDecode(payload) as List)
            if (m is Map)
              PartyBalance(
                id: m['id'] as String,
                name: m['name'] as String,
                amount: (m['amount'] as num).toInt(),
              ),
        ],
        toPayload: (balances) => jsonEncode([
          for (final b in balances)
            {'id': b.id, 'name': b.name, 'amount': b.amount},
        ]),
      );
}