/// Single source of truth for the `report_cache` keys that the offline
/// repository wrappers (Slice B) use, so screens can derive the same key for
/// the freshness indicator without duplicating the wrapper logic.
library;

import '../../domain/statements/statement.dart';
import 'offline_reads.dart';

String invoiceListKey({
  required String type,
  String? search,
  DateTime? from,
  DateTime? to,
}) {
  final term = search?.trim();
  final searchPart = (term == null || term.isEmpty) ? 'all' : term.toLowerCase();
  return 'inv:$type:$searchPart'
      ':${from != null ? cacheDate(from) : '_'}:${to != null ? cacheDate(to) : '_'}';
}

String chartOfAccountsKey = 'chart_of_accounts';

const dashboardKey = 'dashboard';

String journalKey(DateTime from, DateTime to) =>
    'journal:${cacheDate(from)}:${cacheDate(to)}';

String ledgerKey({
  required String accountId,
  required DateTime from,
  required DateTime to,
}) =>
    'ledger:$accountId:${cacheDate(from)}:${cacheDate(to)}';

String trialKey(DateTime asOf) => 'trial:${cacheDate(asOf)}';

String incomeKey(DateTime from, DateTime to) =>
    'income:${cacheDate(from)}:${cacheDate(to)}';

String balanceKey(DateTime asOf) => 'balance:${cacheDate(asOf)}';

String statementKey(StatementRequest request) =>
    'statement:${request.partyType}:${request.partyId}'
    ':${cacheDate(request.from)}:${cacheDate(request.to)}';

String partyInvoicesKey(String type, String partyId) => 'partyInvoices:$type:$partyId';

const debtsCustomersKey = 'debts:customers';

const debtsSuppliersKey = 'debts:suppliers';