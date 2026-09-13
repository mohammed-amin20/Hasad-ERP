import 'dart:convert';

import '../../domain/accounts/account.dart';
import '../../domain/accounts/account_draft.dart';
import '../../domain/accounts/account_repository.dart';
import 'local_database.dart';
import 'local_store.dart';
import 'offline_reads.dart';
import 'report_keys.dart';

/// [AccountRepository] that cache-lasts the chart of accounts: the RPC result
/// (with live balances) is serialized into `report_cache` while online and
/// rehydrated from it when offline.
class OfflineAccountRepository implements AccountRepository {
  OfflineAccountRepository(this._inner, {required this.store, required this.tenantId});

  final AccountRepository _inner;
  final LocalStore? store;
  final String? tenantId;

  @override
  Future<List<Account>> chart() => cacheLast(
        store: store,
        tenantId: tenantId,
        key: chartOfAccountsKey,
        network: _inner.chart,
        fromCached: (payload) => [
          for (final m in jsonDecode(payload) as List)
            if (m is Map) Account.fromJson(m.cast<String, dynamic>()),
        ],
        toPayload: (accounts) => jsonEncode([
          for (final a in accounts)
            {
              'account_id': a.id,
              'code': a.code,
              'name': a.name,
              'type': a.type.apiValue,
              'parent_id': a.parentId,
              'parent_code': a.parentCode,
              'balance': a.balance,
            },
        ]),
      );

  @override
  Future<Account> create(AccountDraft draft) async {
    final account = await _inner.create(draft);
    final s = store;
    final t = tenantId;
    if (s != null && t != null) {
      try {
        await s.upsertAccount(
          LocalAccountRow(
            id: account.id,
            tenantId: t,
            code: account.code,
            name: account.name,
            type: account.type.apiValue,
            parentCode: account.parentCode,
          ),
        );
      } on Object {
        // best-effort local mirror; the chart cache re-mirrors on next read
      }
    }
    return account;
  }
}