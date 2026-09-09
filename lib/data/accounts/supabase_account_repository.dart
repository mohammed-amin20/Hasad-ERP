import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/error/app_exception.dart';
import '../../domain/accounts/account.dart';
import '../../domain/accounts/account_draft.dart';
import '../../domain/accounts/account_repository.dart';

/// [AccountRepository] backed by the 0019 chart-of-accounts RPCs.
class SupabaseAccountRepository implements AccountRepository {
  const SupabaseAccountRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Account>> chart() async {
    try {
      final result = await _client.rpc('get_chart_of_accounts');
      final rows = result as List;
      return [
        for (final r in rows)
          if (r is Map<String, dynamic>) Account.fromJson(r),
      ];
    } on Object catch (error) {
      throw mapErrorToAppException(error);
    }
  }

  @override
  Future<Account> create(AccountDraft draft) async {
    try {
      final result = await _client
          .rpc('create_account', params: draft.toJson()) as Map<String, dynamic>;
      if (result['duplicate'] == true) {
        throw ValidationException('كود الحساب "${draft.code}" مستخدم مسبقاً');
      }
      return Account(
        id: result['account_id'] as String,
        code: result['code'] as String,
        name: result['name'] as String,
        type: AccountType.from(result['type'] as String? ?? 'asset'),
        parentId: result['parent_id'] as String?,
        balance: 0,
      );
    } on Object catch (error) {
      throw mapErrorToAppException(error);
    }
  }
}