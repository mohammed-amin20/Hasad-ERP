import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasad_erp/data/offline/local_database.dart';
import 'package:hasad_erp/data/offline/local_store.dart';
import 'package:hasad_erp/data/offline/offline_sync.dart';
import 'package:hasad_erp/domain/salaries/salary_repository.dart';
import 'package:hasad_erp/presentation/providers/offline_sync_providers.dart';
import 'package:hasad_erp/presentation/providers/salaries_providers.dart';

import '../tool/shell_stubs.dart';

/// J: a real salary drain must invalidate `salaryHistoryProvider` so an
/// offline-paid salary stops reading as a draft once the queue clears — same
/// contract proven for invoices, parties, and journals.
void main() {
  test('a real salary drain rebuilds salaryHistoryProvider', () async {
    const tenant = 'tenant-a';
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(() => db.close());
    final store = DriftLocalStore(db);
    await store.upsertSalary(LocalSalaryRow(
      id: 's-1', tenantId: tenant, employeeId: 'e1', month: '2026-09',
      paid: 400000, netDue: 400000, requestId: 'req-s', synced: false,
      createdAt: DateTime.utc(2026, 9, 1),
    ));
    await store.enqueue(SyncQueueRow(
      id: 'q-s', tenantId: tenant, rpc: 'pay_salary', op: 'rpc',
      params: '{}', requestId: 'req-s', entity: 'salaries', localId: 's-1',
      status: 'pending', attempts: 0, lastError: null,
      createdAt: DateTime.utc(2026, 1, 1), updatedAt: DateTime.utc(2026, 1, 1),
    ));

    var historyBuilds = 0;
    final container = ProviderContainer(
      overrides: [
        localStoreProvider.overrideWith((ref) async => store),
        currentTenantIdProvider.overrideWithValue(tenant),
        syncFlusherProvider.overrideWith(
          (ref) async => SyncFlusher(store, tenant, ShellNoopSyncTarget()),
        ),
        salaryHistoryProvider.overrideWith((ref) async {
          historyBuilds++;
          return const <SalaryRecord>[];
        }),
      ],
    );
    addTearDown(container.dispose);

    // Listen so the provider is actually built — invalidating a provider
    // nobody has read is not observable.
    final sub = container.listen(salaryHistoryProvider, (_, _) {});
    addTearDown(sub.close);

    await container.read(salaryHistoryProvider.future);
    final before = historyBuilds;
    expect(before, greaterThan(0));

    // A real drain (genuine drift async work), then the leg clears the queue.
    final summary = await container.read(manualSyncNowProvider.future);
    expect(summary.synced, 1);
    expect((await store.salaries(tenant)).single.synced, isTrue);

    // Re-reading the invalidated provider recomputes it.
    await container.read(salaryHistoryProvider.future);
    expect(historyBuilds, greaterThan(before));
  });
}