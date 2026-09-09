// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'accounts_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Chart-of-accounts repository wired to Supabase.

@ProviderFor(accountRepository)
final accountRepositoryProvider = AccountRepositoryProvider._();

/// Chart-of-accounts repository wired to Supabase.

final class AccountRepositoryProvider
    extends
        $FunctionalProvider<
          AccountRepository,
          AccountRepository,
          AccountRepository
        >
    with $Provider<AccountRepository> {
  /// Chart-of-accounts repository wired to Supabase.
  AccountRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'accountRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$accountRepositoryHash();

  @$internal
  @override
  $ProviderElement<AccountRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AccountRepository create(Ref ref) {
    return accountRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AccountRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AccountRepository>(value),
    );
  }
}

String _$accountRepositoryHash() => r'05e743d79dd8d787997d9ffca0862f0faf8627b9';

/// The tenant's chart of accounts.

@ProviderFor(ChartOfAccounts)
final chartOfAccountsProvider = ChartOfAccountsProvider._();

/// The tenant's chart of accounts.
final class ChartOfAccountsProvider
    extends $AsyncNotifierProvider<ChartOfAccounts, List<Account>> {
  /// The tenant's chart of accounts.
  ChartOfAccountsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'chartOfAccountsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$chartOfAccountsHash();

  @$internal
  @override
  ChartOfAccounts create() => ChartOfAccounts();
}

String _$chartOfAccountsHash() => r'720765a3160d3947c38b9e1056a8a6c331165bcd';

/// The tenant's chart of accounts.

abstract class _$ChartOfAccounts extends $AsyncNotifier<List<Account>> {
  FutureOr<List<Account>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<Account>>, List<Account>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<Account>>, List<Account>>,
              AsyncValue<List<Account>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
