import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/accounts/supabase_account_repository.dart';
import '../../data/supabase_client.dart';
import '../../domain/accounts/account.dart';
import '../../domain/accounts/account_draft.dart';
import '../../domain/accounts/account_repository.dart';

part 'accounts_providers.g.dart';

/// Chart-of-accounts repository wired to Supabase.
@riverpod
AccountRepository accountRepository(Ref ref) =>
    SupabaseAccountRepository(ref.watch(supabaseClientProvider));

/// The tenant's chart of accounts.
@riverpod
class ChartOfAccounts extends _$ChartOfAccounts {
  @override
  Future<List<Account>> build() =>
      ref.watch(accountRepositoryProvider).chart();

  /// Create a new account, then refresh the chart.
  Future<Account> create(AccountDraft draft) async {
    final repo = ref.read(accountRepositoryProvider);
    final account = await repo.create(draft);
    ref.invalidateSelf();
    return account;
  }
}