import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/accounts/supabase_account_repository.dart';
import '../../data/offline/local_store.dart';
import '../../data/offline/offline_account_repository.dart';
import '../../data/supabase_client.dart';
import '../../domain/accounts/account.dart';
import '../../domain/accounts/account_draft.dart';
import '../../domain/accounts/account_repository.dart';
import 'auth_providers.dart';

part 'accounts_providers.g.dart';

/// Chart-of-accounts repository — offline-first (cache-last the RPC envelope).
@riverpod
AccountRepository accountRepository(Ref ref) => OfflineAccountRepository(
      SupabaseAccountRepository(ref.watch(supabaseClientProvider)),
      store: ref.watch(localStoreProvider).value,
      tenantId: ref.watch(authStateProvider).value?.tenantId,
    );

/// The tenant's chart of accounts.
@riverpod
class ChartOfAccounts extends _$ChartOfAccounts {
  @override
  Future<List<Account>> build() => ref.watch(accountRepositoryProvider).chart();

  /// Create a new account, then refresh the chart.
  Future<Account> create(AccountDraft draft) async {
    final repo = ref.read(accountRepositoryProvider);
    final account = await repo.create(draft);
    ref.invalidateSelf();
    return account;
  }
}
