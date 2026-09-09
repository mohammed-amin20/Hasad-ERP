import 'balance_sheet.dart';
import 'income_statement.dart';
import 'ledger.dart';
import 'trial_balance.dart';

/// Abstract interface for the M7 report RPCs (migration 0019).
///
/// Concrete implementations live in `data/` — the UI never imports
/// the Supabase client directly.
abstract interface class ReportRepository {
  Future<LedgerStatement> ledger({
    required String accountId,
    required DateTime from,
    required DateTime to,
  });

  Future<TrialBalanceReport> trialBalance(DateTime asOf);

  Future<IncomeStatement> incomeStatement({
    required DateTime from,
    required DateTime to,
  });

  Future<BalanceSheet> balanceSheet(DateTime asOf);
}