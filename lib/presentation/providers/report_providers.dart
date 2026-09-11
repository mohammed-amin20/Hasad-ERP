import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/reports/supabase_report_repository.dart';
import '../../data/supabase_client.dart';
import '../../domain/reports/balance_sheet.dart' as sheet_models;
import '../../domain/reports/income_statement.dart' as pnl_models;
import '../../domain/reports/ledger.dart' as ledger_models;
import '../../domain/reports/report_repository.dart';
import '../../domain/reports/trial_balance.dart' as tb_models;

part 'report_providers.g.dart';

/// Report repository wired to Supabase.
@riverpod
ReportRepository reportRepository(Ref ref) =>
    SupabaseReportRepository(ref.watch(supabaseClientProvider));

/// Ledger selection: account + date range (default: from first-of-month to now).
@riverpod
class LedgerQuery extends _$LedgerQuery {
  @override
  ({String? accountId, DateTime from, DateTime to}) build() {
    final now = DateTime.now();
    return (accountId: null, from: DateTime(now.year, now.month, 1), to: now);
  }

  void update({String? accountId, DateTime? from, DateTime? to}) {
    final current = state;
    state = (
      accountId: accountId ?? current.accountId,
      from: from ?? current.from,
      to: to ?? current.to,
    );
  }
}

/// Ledger statement for the selected account + range (null until one is chosen).
@riverpod
class LedgerStatement extends _$LedgerStatement {
  @override
  Future<ledger_models.LedgerStatement?> build() async {
    final query = ref.watch(ledgerQueryProvider);
    final accountId = query.accountId;
    if (accountId == null) return null;
    return ref
        .watch(reportRepositoryProvider)
        .ledger(accountId: accountId, from: query.from, to: query.to);
  }
}

/// Shared "as of" date for the trial balance and the balance sheet.
@riverpod
class AsOfDate extends _$AsOfDate {
  @override
  DateTime build() => DateTime.now();

  void update(DateTime date) => state = date;
}

/// Trial balance as of [asOfDateProvider].
@riverpod
class TrialBalance extends _$TrialBalance {
  @override
  Future<tb_models.TrialBalanceReport> build() => ref
      .watch(reportRepositoryProvider)
      .trialBalance(ref.watch(asOfDateProvider));
}

/// Income statement range (default: from first-of-month to now).
@riverpod
class IncomeRange extends _$IncomeRange {
  @override
  ({DateTime from, DateTime to}) build() {
    final now = DateTime.now();
    return (from: DateTime(now.year, now.month, 1), to: now);
  }

  void update({required DateTime from, required DateTime to}) =>
      state = (from: from, to: to);
}

/// Profit-and-loss for [incomeRangeProvider].
@riverpod
class IncomeStatement extends _$IncomeStatement {
  @override
  Future<pnl_models.IncomeStatement> build() {
    final range = ref.watch(incomeRangeProvider);
    return ref
        .watch(reportRepositoryProvider)
        .incomeStatement(from: range.from, to: range.to);
  }
}

/// Balance sheet as of [asOfDateProvider].
@riverpod
class BalanceSheet extends _$BalanceSheet {
  @override
  Future<sheet_models.BalanceSheet> build() => ref
      .watch(reportRepositoryProvider)
      .balanceSheet(ref.watch(asOfDateProvider));
}
