import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/error/app_exception.dart';
import '../../domain/reports/balance_sheet.dart';
import '../../domain/reports/income_statement.dart';
import '../../domain/reports/ledger.dart';
import '../../domain/reports/report_repository.dart';
import '../../domain/reports/trial_balance.dart';

String _iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// [ReportRepository] backed by the 0019 report RPCs.
class SupabaseReportRepository implements ReportRepository {
  const SupabaseReportRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<LedgerStatement> ledger({
    required String accountId,
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final result = await _client.rpc(
        'get_ledger',
        params: {
          'p_account_id': accountId,
          'p_from': _iso(from),
          'p_to': _iso(to),
        },
      ) as Map<String, dynamic>;
      return LedgerStatement.fromJson(result);
    } on Object catch (error) {
      throw mapErrorToAppException(error);
    }
  }

  @override
  Future<TrialBalanceReport> trialBalance(DateTime asOf) async {
    try {
      final result = await _client.rpc(
        'get_trial_balance',
        params: {'p_as_of_date': _iso(asOf)},
      ) as Map<String, dynamic>;
      return TrialBalanceReport.fromJson(result);
    } on Object catch (error) {
      throw mapErrorToAppException(error);
    }
  }

  @override
  Future<IncomeStatement> incomeStatement({
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final result = await _client.rpc(
        'get_income_statement',
        params: {'p_from': _iso(from), 'p_to': _iso(to)},
      ) as Map<String, dynamic>;
      return IncomeStatement.fromJson(result);
    } on Object catch (error) {
      throw mapErrorToAppException(error);
    }
  }

  @override
  Future<BalanceSheet> balanceSheet(DateTime asOf) async {
    try {
      final result = await _client.rpc(
        'get_balance_sheet',
        params: {'p_as_of_date': _iso(asOf)},
      ) as Map<String, dynamic>;
      return BalanceSheet.fromJson(result);
    } on Object catch (error) {
      throw mapErrorToAppException(error);
    }
  }
}