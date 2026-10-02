import 'dart:convert';

import '../../domain/invoices/invoice.dart';
import '../../domain/statements/debts_repository.dart';
import '../../domain/statements/statement.dart';
import 'local_database.dart';
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
  Future<List<PartyBalance>> customerBalances() async =>
      _withPendingMoney(
        await _cacheBalances(
          key: _customersKey,
          network: _inner.customerBalances,
        ),
      );

  @override
  Future<List<PartyBalance>> supplierBalances() async =>
      _withPendingMoney(
        await _cacheBalances(
          key: _suppliersKey,
          network: _inner.supplierBalances,
        ),
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

  /// Subtracts every payment this device has recorded but the server has not
  /// seen yet, from the party it was paid to.
  ///
  /// The balances above come from an aggregate over the server's invoices and
  /// commission dues, so a locally-recorded payment is invisible to them: the
  /// cached figure counts money the user has already handed over. Subtracting
  /// the unsynced payments is what makes an offline payment show up on the
  /// debts screen immediately, instead of only after the queue drains.
  ///
  /// Two rules keep this honest:
  ///  - Only `synced == false` payment rows count. A replayed payment is
  ///    already in the server's aggregate, so subtracting it again would
  ///    understate the debt.
  ///  - A payment is dropped once its amount reaches zero or below, which is
  ///    what the debts screen means by "no debt" — an offline payment that
  ///    settles an invoice in full must not leave a negative row.
  ///
  /// A party with no row in the base list is not added: the server did not
  /// consider it a debtor, and inventing a row from a payment alone would also
  /// get the name wrong (the mirror's `partyName` can be stale).
  Future<List<PartyBalance>> _withPendingMoney(List<PartyBalance> base) async {
    final s = store;
    if (s == null || tenantId == null) return base;

    List<LocalPaymentRow> pending;
    Set<String> draftInvoiceIds;
    try {
      final all = await s.payments(tenantId!);
      pending = all.where((p) => !p.synced).toList();
      draftInvoiceIds = {
        for (final i in await s.invoices(tenantId!))
          if (!i.synced) i.id,
      };
    } on Object {
      // Best effort: a store that cannot be read must not turn a working
      // debts screen into an error. The server figure is still served.
      return base;
    }
    if (pending.isEmpty) return base;

    final byParty = <String, int>{};
    for (final p in pending) {
      final id = p.partyId;
      if (id == null) continue;
      // A payment against an invoice the server has never seen is NOT part of
      // the server's aggregate, so it cannot be subtracted from it. Paying off a
      // locally-created draft reduces that draft, not the balance the aggregate
      // reports — subtracting here would understate the real debt.
      if (p.invoiceId != null && draftInvoiceIds.contains(p.invoiceId)) continue;
      byParty[id] = (byParty[id] ?? 0) + p.amount;
    }
    if (byParty.isEmpty) return base;

    return [
      for (final b in base)
        () {
          final paid = byParty[b.id];
          if (paid == null) return b;
          final amount = b.amount - paid;
          if (amount <= 0) return null;
          return PartyBalance(id: b.id, name: b.name, amount: amount);
        }(),
    ].whereType<PartyBalance>().toList();
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