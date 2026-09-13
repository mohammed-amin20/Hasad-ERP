import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/offline/local_store.dart';
import '../../data/offline/offline_statement_repository.dart';
import '../../data/statements/supabase_statement_repository.dart';
import '../../data/supabase_client.dart';
import '../../domain/statements/debts_repository.dart';
import '../../domain/statements/statement.dart';
import 'auth_providers.dart';

part 'statements_providers.g.dart';

@riverpod
StatementRepository statementRepository(Ref ref) => OfflineStatementRepository(
      SupabaseStatementRepository(ref.watch(supabaseClientProvider)),
      store: ref.watch(localStoreProvider).value,
      tenantId: ref.watch(authStateProvider).value?.tenantId,
    );

@riverpod
DebtsRepository debtsRepository(Ref ref) => OfflineDebtsRepository(
      SupabaseDebtsRepository(ref.watch(supabaseClientProvider)),
      store: ref.watch(localStoreProvider).value,
      tenantId: ref.watch(authStateProvider).value?.tenantId,
    );

/// Customer outstanding balances (what customers owe us).
@riverpod
Future<List<PartyBalance>> customerDebts(Ref ref) =>
    ref.watch(debtsRepositoryProvider).customerBalances();

/// Supplier outstanding balances (what we owe suppliers: owned invoices +
/// commission dues).
@riverpod
Future<List<PartyBalance>> supplierDebts(Ref ref) =>
    ref.watch(debtsRepositoryProvider).supplierBalances();

/// A single party's statement, keyed by (type, id, from, to).
@riverpod
Future<PartyStatement> partyStatement(Ref ref, StatementRequest request) =>
    ref.watch(statementRepositoryProvider).statement(request);
