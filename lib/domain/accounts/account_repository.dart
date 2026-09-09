import 'account.dart';
import 'account_draft.dart';

/// Abstract interface for the chart of accounts (M7, migration 0019).
///
/// Concrete implementations live in `data/` — the UI never imports
/// the Supabase client directly.
abstract interface class AccountRepository {
  Future<List<Account>> chart();
  Future<Account> create(AccountDraft draft);
}