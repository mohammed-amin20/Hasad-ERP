// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'report_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Report repository wired to Supabase.

@ProviderFor(reportRepository)
final reportRepositoryProvider = ReportRepositoryProvider._();

/// Report repository wired to Supabase.

final class ReportRepositoryProvider
    extends
        $FunctionalProvider<
          ReportRepository,
          ReportRepository,
          ReportRepository
        >
    with $Provider<ReportRepository> {
  /// Report repository wired to Supabase.
  ReportRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'reportRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$reportRepositoryHash();

  @$internal
  @override
  $ProviderElement<ReportRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ReportRepository create(Ref ref) {
    return reportRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ReportRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ReportRepository>(value),
    );
  }
}

String _$reportRepositoryHash() => r'e3275aa42f3c9c38375f76c2c193fcea30b2b69d';

/// Ledger selection: account + date range (default: from first-of-month to now).

@ProviderFor(LedgerQuery)
final ledgerQueryProvider = LedgerQueryProvider._();

/// Ledger selection: account + date range (default: from first-of-month to now).
final class LedgerQueryProvider
    extends
        $NotifierProvider<
          LedgerQuery,
          ({String? accountId, DateTime from, DateTime to})
        > {
  /// Ledger selection: account + date range (default: from first-of-month to now).
  LedgerQueryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'ledgerQueryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$ledgerQueryHash();

  @$internal
  @override
  LedgerQuery create() => LedgerQuery();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(
    ({String? accountId, DateTime from, DateTime to}) value,
  ) {
    return $ProviderOverride(
      origin: this,
      providerOverride:
          $SyncValueProvider<({String? accountId, DateTime from, DateTime to})>(
            value,
          ),
    );
  }
}

String _$ledgerQueryHash() => r'fa4a2d93384714e127c7f681b9ec7217ec4f8a8c';

/// Ledger selection: account + date range (default: from first-of-month to now).

abstract class _$LedgerQuery
    extends $Notifier<({String? accountId, DateTime from, DateTime to})> {
  ({String? accountId, DateTime from, DateTime to}) build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              ({String? accountId, DateTime from, DateTime to}),
              ({String? accountId, DateTime from, DateTime to})
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                ({String? accountId, DateTime from, DateTime to}),
                ({String? accountId, DateTime from, DateTime to})
              >,
              ({String? accountId, DateTime from, DateTime to}),
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Ledger statement for the selected account + range (null until one is chosen).

@ProviderFor(LedgerStatement)
final ledgerStatementProvider = LedgerStatementProvider._();

/// Ledger statement for the selected account + range (null until one is chosen).
final class LedgerStatementProvider
    extends
        $AsyncNotifierProvider<
          LedgerStatement,
          ledger_models.LedgerStatement?
        > {
  /// Ledger statement for the selected account + range (null until one is chosen).
  LedgerStatementProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'ledgerStatementProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$ledgerStatementHash();

  @$internal
  @override
  LedgerStatement create() => LedgerStatement();
}

String _$ledgerStatementHash() => r'ea01185f990d85bfc9e863632a441dd852c16eae';

/// Ledger statement for the selected account + range (null until one is chosen).

abstract class _$LedgerStatement
    extends $AsyncNotifier<ledger_models.LedgerStatement?> {
  FutureOr<ledger_models.LedgerStatement?> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<ledger_models.LedgerStatement?>,
              ledger_models.LedgerStatement?
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<ledger_models.LedgerStatement?>,
                ledger_models.LedgerStatement?
              >,
              AsyncValue<ledger_models.LedgerStatement?>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Shared "as of" date for the trial balance and the balance sheet.

@ProviderFor(AsOfDate)
final asOfDateProvider = AsOfDateProvider._();

/// Shared "as of" date for the trial balance and the balance sheet.
final class AsOfDateProvider extends $NotifierProvider<AsOfDate, DateTime> {
  /// Shared "as of" date for the trial balance and the balance sheet.
  AsOfDateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'asOfDateProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$asOfDateHash();

  @$internal
  @override
  AsOfDate create() => AsOfDate();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DateTime value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DateTime>(value),
    );
  }
}

String _$asOfDateHash() => r'4d23d70985e8916cd03c16e770e3c4144b09caae';

/// Shared "as of" date for the trial balance and the balance sheet.

abstract class _$AsOfDate extends $Notifier<DateTime> {
  DateTime build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<DateTime, DateTime>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<DateTime, DateTime>,
              DateTime,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Trial balance as of [asOfDateProvider].

@ProviderFor(TrialBalance)
final trialBalanceProvider = TrialBalanceProvider._();

/// Trial balance as of [asOfDateProvider].
final class TrialBalanceProvider
    extends $AsyncNotifierProvider<TrialBalance, tb_models.TrialBalanceReport> {
  /// Trial balance as of [asOfDateProvider].
  TrialBalanceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'trialBalanceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$trialBalanceHash();

  @$internal
  @override
  TrialBalance create() => TrialBalance();
}

String _$trialBalanceHash() => r'6bd4aa62c4ddd94c4b8ed5104569354f926df6f6';

/// Trial balance as of [asOfDateProvider].

abstract class _$TrialBalance
    extends $AsyncNotifier<tb_models.TrialBalanceReport> {
  FutureOr<tb_models.TrialBalanceReport> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<tb_models.TrialBalanceReport>,
              tb_models.TrialBalanceReport
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<tb_models.TrialBalanceReport>,
                tb_models.TrialBalanceReport
              >,
              AsyncValue<tb_models.TrialBalanceReport>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Income statement range (default: from first-of-month to now).

@ProviderFor(IncomeRange)
final incomeRangeProvider = IncomeRangeProvider._();

/// Income statement range (default: from first-of-month to now).
final class IncomeRangeProvider
    extends $NotifierProvider<IncomeRange, ({DateTime from, DateTime to})> {
  /// Income statement range (default: from first-of-month to now).
  IncomeRangeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'incomeRangeProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$incomeRangeHash();

  @$internal
  @override
  IncomeRange create() => IncomeRange();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(({DateTime from, DateTime to}) value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<({DateTime from, DateTime to})>(
        value,
      ),
    );
  }
}

String _$incomeRangeHash() => r'2ba97ea2c77872908c459e2acaf8c71cf401a462';

/// Income statement range (default: from first-of-month to now).

abstract class _$IncomeRange extends $Notifier<({DateTime from, DateTime to})> {
  ({DateTime from, DateTime to}) build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              ({DateTime from, DateTime to}),
              ({DateTime from, DateTime to})
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                ({DateTime from, DateTime to}),
                ({DateTime from, DateTime to})
              >,
              ({DateTime from, DateTime to}),
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Profit-and-loss for [incomeRangeProvider].

@ProviderFor(IncomeStatement)
final incomeStatementProvider = IncomeStatementProvider._();

/// Profit-and-loss for [incomeRangeProvider].
final class IncomeStatementProvider
    extends
        $AsyncNotifierProvider<IncomeStatement, pnl_models.IncomeStatement> {
  /// Profit-and-loss for [incomeRangeProvider].
  IncomeStatementProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'incomeStatementProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$incomeStatementHash();

  @$internal
  @override
  IncomeStatement create() => IncomeStatement();
}

String _$incomeStatementHash() => r'f171dc17041f4635b5b83266a0414fb722063934';

/// Profit-and-loss for [incomeRangeProvider].

abstract class _$IncomeStatement
    extends $AsyncNotifier<pnl_models.IncomeStatement> {
  FutureOr<pnl_models.IncomeStatement> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<pnl_models.IncomeStatement>,
              pnl_models.IncomeStatement
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<pnl_models.IncomeStatement>,
                pnl_models.IncomeStatement
              >,
              AsyncValue<pnl_models.IncomeStatement>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Balance sheet as of [asOfDateProvider].

@ProviderFor(BalanceSheet)
final balanceSheetProvider = BalanceSheetProvider._();

/// Balance sheet as of [asOfDateProvider].
final class BalanceSheetProvider
    extends $AsyncNotifierProvider<BalanceSheet, sheet_models.BalanceSheet> {
  /// Balance sheet as of [asOfDateProvider].
  BalanceSheetProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'balanceSheetProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$balanceSheetHash();

  @$internal
  @override
  BalanceSheet create() => BalanceSheet();
}

String _$balanceSheetHash() => r'4af2465a6abdfba8c733cc50f12e89db8e93e25d';

/// Balance sheet as of [asOfDateProvider].

abstract class _$BalanceSheet
    extends $AsyncNotifier<sheet_models.BalanceSheet> {
  FutureOr<sheet_models.BalanceSheet> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<sheet_models.BalanceSheet>,
              sheet_models.BalanceSheet
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<sheet_models.BalanceSheet>,
                sheet_models.BalanceSheet
              >,
              AsyncValue<sheet_models.BalanceSheet>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
