import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/error/app_exception.dart';
import '../../domain/invoices/invoice.dart';
import '../../domain/statements/debts_repository.dart';
import '../../domain/statements/statement.dart';

/// [StatementRepository] backed by the `get_party_statement` RPC.
class SupabaseStatementRepository implements StatementRepository {
  const SupabaseStatementRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<PartyStatement> statement(StatementRequest request) async {
    try {
      final result = await _client.rpc(
        'get_party_statement',
        params: request.toJson(),
      );
      return PartyStatement.fromJson(result as Map<String, dynamic>);
    } on Object catch (error) {
      throw mapErrorToAppException(error);
    }
  }
}

/// [DebtsRepository] backed by direct RLS-protected reads of `invoices` and
/// `commission_dues` (no business logic, so plain table access is fine).
class SupabaseDebtsRepository implements DebtsRepository {
  const SupabaseDebtsRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<PartyBalance>> customerBalances() => _partyBalances(
        select: 'party_id, name, remaining',
        table: 'invoices',
        join: 'customers(name)',
        type: 'sale',
        partyKey: 'customers',
      );

  @override
  Future<List<PartyBalance>> supplierBalances() async {
    final owned = await _partyBalances(
      select: 'party_id, name, remaining',
      table: 'invoices',
      join: 'suppliers(name)',
      type: 'purchase',
      partyKey: 'suppliers',
      ownedOnly: true,
    );
    final dues = await _commissionBalances();
    return _merge(owned, dues);
  }

  @override
  Future<int> supplierInvoiceDebt(String supplierId) async {
    try {
      final rows = await _client
          .from('invoices')
          .select('remaining')
          .eq('type', 'purchase')
          .eq('ownership', 'owned')
          .eq('party_id', supplierId);
      return rows.fold<int>(0, (sum, r) => sum + ((r['remaining'] as num?)?.toInt() ?? 0));
    } on Object catch (error) {
      throw mapErrorToAppException(error);
    }
  }

  @override
  Future<int> supplierCommissionDebt(String supplierId) async {
    try {
      final rows = await _client
          .from('commission_dues')
          .select('remaining')
          .eq('supplier_id', supplierId);
      return rows.fold<int>(0, (sum, r) => sum + ((r['remaining'] as num?)?.toInt() ?? 0));
    } on Object catch (error) {
      throw mapErrorToAppException(error);
    }
  }

  @override
  Future<List<Invoice>> partyInvoices({
    required String type,
    required String partyId,
  }) async {
    try {
      final rows = await _client
          .from('invoices')
          .select('id, type, no, party_id, date, subtotal, total, paid, '
              'remaining, status, ownership')
          .eq('type', type)
          .eq('party_id', partyId)
          .order('date', ascending: false);
      return rows.map(Invoice.fromJson).toList();
    } on Object catch (error) {
      throw mapErrorToAppException(error);
    }
  }

  Future<List<PartyBalance>> _partyBalances({
    required String select,
    required String table,
    required String join,
    required String type,
    required String partyKey,
    bool ownedOnly = false,
  }) async {
    try {
      var query = _client
          .from(table)
          .select('$select, $join')
          .eq('type', type);
      if (ownedOnly) query = query.eq('ownership', 'owned');
      query = query.gt('remaining', 0);
      final rows = await query;

      final balances = <String, PartyBalance>{};
      for (final r in rows) {
        final id = r['party_id'] as String;
        final amount = (r['remaining'] as num?)?.toInt() ?? 0;
        final name = (r[partyKey] as Map?)?['name'] as String? ?? 'غير معروف';
        final prev = balances[id];
        balances[id] = PartyBalance(
          id: id,
          name: name,
          amount: (prev?.amount ?? 0) + amount,
        );
      }
      return balances.values.toList()
        ..sort((a, b) => b.amount.compareTo(a.amount));
    } on Object catch (error) {
      throw mapErrorToAppException(error);
    }
  }

  Future<List<PartyBalance>> _commissionBalances() async {
    try {
      final rows = await _client
          .from('commission_dues')
          .select('supplier_id, remaining, suppliers(name)')
          .gt('remaining', 0);
      return [
        for (final r in rows)
          PartyBalance(
            id: r['supplier_id'] as String,
            name: (r['suppliers'] as Map?)?['name'] as String? ?? 'غير معروف',
            amount: (r['remaining'] as num?)?.toInt() ?? 0,
          ),
      ];
    } on Object catch (error) {
      throw mapErrorToAppException(error);
    }
  }

  List<PartyBalance> _merge(List<PartyBalance> a, List<PartyBalance> b) {
    final byId = <String, PartyBalance>{};
    for (final p in [...a, ...b]) {
      final prev = byId[p.id];
      byId[p.id] = PartyBalance(
        id: p.id,
        name: p.name,
        amount: (prev?.amount ?? 0) + p.amount,
      );
    }
    final list = byId.values.toList()
      ..sort((x, y) => y.amount.compareTo(x.amount));
    // Drop zero/negative entries.
    return list.where((p) => p.amount > 0).toList();
  }
}