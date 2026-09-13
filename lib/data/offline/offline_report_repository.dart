import 'dart:convert';

import '../../domain/reports/balance_sheet.dart';
import '../../domain/reports/income_statement.dart';
import '../../domain/reports/ledger.dart';
import '../../domain/reports/report_repository.dart';
import '../../domain/reports/trial_balance.dart';
import 'local_store.dart';
import 'offline_reads.dart';
import 'report_keys.dart';

/// [ReportRepository] that cache-lasts every report envelope (ledger, trial
/// balance, income statement, balance sheet) for offline viewing.
class OfflineReportRepository implements ReportRepository {
  OfflineReportRepository(this._inner, {required this.store, required this.tenantId});

  final ReportRepository _inner;
  final LocalStore? store;
  final String? tenantId;

  @override
  Future<LedgerStatement> ledger({
    required String accountId,
    required DateTime from,
    required DateTime to,
  }) {
    final key = ledgerKey(accountId: accountId, from: from, to: to);
    return cacheLast(
      store: store,
      tenantId: tenantId,
      key: key,
      network: () => _inner.ledger(accountId: accountId, from: from, to: to),
      fromCached: (payload) =>
          LedgerStatement.fromJson(_asMap(payload)),
      toPayload: (s) => jsonEncode({
        'account_id': s.accountId,
        'code': s.code,
        'name': s.name,
        'type': s.type.name,
        'from': cacheDate(s.from),
        'to': cacheDate(s.to),
        'opening': s.opening,
        'closing': s.closing,
        'lines': [
          for (final l in s.lines)
            {
              'date': cacheDate(l.date),
              'entry_no': l.entryNo,
              'memo': l.memo,
              'debit': l.debit,
              'credit': l.credit,
              'balance': l.balance,
            },
        ],
      }),
    );
  }

  @override
  Future<TrialBalanceReport> trialBalance(DateTime asOf) {
    final key = trialKey(asOf);
    return cacheLast(
      store: store,
      tenantId: tenantId,
      key: key,
      network: () => _inner.trialBalance(asOf),
      fromCached: (payload) => TrialBalanceReport.fromJson(_asMap(payload)),
      toPayload: (r) => jsonEncode({
        'as_of': cacheDate(r.asOf),
        'accounts': [
          for (final row in r.rows)
            {
              'account_id': row.accountId,
              'code': row.code,
              'name': row.name,
              'type': row.type.name,
              'debit': row.debit,
              'credit': row.credit,
              'balance': row.balance,
            },
        ],
        'totals': {'debit': r.totalDebit, 'credit': r.totalCredit},
      }),
    );
  }

  @override
  Future<IncomeStatement> incomeStatement({
    required DateTime from,
    required DateTime to,
  }) {
    final key = incomeKey(from, to);
    return cacheLast(
      store: store,
      tenantId: tenantId,
      key: key,
      network: () => _inner.incomeStatement(from: from, to: to),
      fromCached: (payload) => IncomeStatement.fromJson(_asMap(payload)),
      toPayload: (r) => jsonEncode({
        'from': cacheDate(r.from),
        'to': cacheDate(r.to),
        'revenues': [for (final l in r.revenues) _lineToJson(l)],
        'expenses': [for (final l in r.expenses) _lineToJson(l)],
        'revenue_total': r.revenueTotal,
        'expense_total': r.expenseTotal,
        'net': r.net,
      }),
    );
  }

  @override
  Future<BalanceSheet> balanceSheet(DateTime asOf) {
    final key = balanceKey(asOf);
    return cacheLast(
      store: store,
      tenantId: tenantId,
      key: key,
      network: () => _inner.balanceSheet(asOf),
      fromCached: (payload) => BalanceSheet.fromJson(_asMap(payload)),
      toPayload: (r) => jsonEncode({
        'as_of': cacheDate(r.asOf),
        'assets': [for (final a in r.assets) _sheetLineToJson(a)],
        'liabilities': [for (final a in r.liabilities) _sheetLineToJson(a)],
        'equity': [for (final a in r.equity) _sheetLineToJson(a)],
        'assets_total': r.assetsTotal,
        'liabilities_total': r.liabilitiesTotal,
        'equity_total': r.equityTotal,
        'net_income_ytd': r.netIncomeYtd,
        'check': r.check,
      }),
    );
  }

  static Map<String, dynamic> _asMap(String payload) =>
      (jsonDecode(payload) as Map).cast<String, dynamic>();

  static Map<String, dynamic> _lineToJson(IncomeStatementLine l) => {
        'account_id': l.accountId,
        'code': l.code,
        'name': l.name,
        'amount': l.amount,
      };

  static Map<String, dynamic> _sheetLineToJson(BalanceSheetAccount a) => {
        'account_id': a.accountId,
        'code': a.code,
        'name': a.name,
        'amount': a.amount,
      };
}