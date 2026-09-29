import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasad_erp/core/error/app_exception.dart';
import 'package:hasad_erp/data/offline/local_database.dart';
import 'package:hasad_erp/data/offline/local_store.dart';
import 'package:hasad_erp/data/offline/offline_supplier_repository.dart';
import 'package:hasad_erp/data/offline/offline_write.dart';
import 'package:hasad_erp/domain/suppliers/supplier.dart';
import 'package:hasad_erp/domain/suppliers/supplier_draft.dart';
import 'package:hasad_erp/domain/suppliers/supplier_repository.dart';

/// Records every call and optionally plays the "remote down" NetworkException
/// the offline wrapper uses to decide when to read the mirror.
class _FakeInnerRepository implements SupplierRepository {
  final List<String> calls = <String>[];
  bool offline = false;
  List<Supplier> suppliers = <Supplier>[];
  int _next = 0;

  @override
  Future<List<Supplier>> listAll({String? search}) async {
    calls.add('listAll');
    if (offline) throw const NetworkException();
    return suppliers;
  }

  @override
  Future<Supplier?> getById(String id) async {
    calls.add('getById:$id');
    if (offline) throw const NetworkException();
    for (final s in suppliers) {
      if (s.id == id) return s;
    }
    return null;
  }

  @override
  Future<Supplier> create(SupplierDraft draft) async {
    calls.add('create');
    if (offline) throw const NetworkException();
    _next += 1;
    final supplier = Supplier(
      id: 'server-$_next',
      name: draft.name,
      phone: draft.phone,
      notes: draft.notes,
      dealType: draft.dealType,
      commissionRate: draft.commissionRate,
      createdAt: DateTime.now(),
    );
    suppliers.add(supplier);
    return supplier;
  }

  @override
  Future<void> update({
    required String id,
    required SupplierDraft draft,
  }) async {
    calls.add('update:$id');
    if (offline) throw const NetworkException();
  }

  @override
  Future<void> delete(String id) async {
    calls.add('delete:$id');
    if (offline) throw const NetworkException();
  }
}

void main() {
  const tenant = 'tenant-a';
  late AppDatabase db;
  late DriftLocalStore store;
  late _FakeInnerRepository inner;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = DriftLocalStore(db);
    inner = _FakeInnerRepository();
  });

  tearDown(() => db.close());

  test('writes fall back to the inner repo when no coordinator is wired',
      () async {
    final repo = OfflineSupplierRepository(
      inner,
      store: store,
      tenantId: tenant,
    );
    expect(repo.writesAreLocalFirst, isFalse);

    final created =
        await repo.create(const SupplierDraft(
        name: 'مورد',
        phone: '0599111222',
        dealType: SupplierDealType.direct,
      ));
    expect(created.id, 'server-1');
    await repo.update(id: 'server-1', draft: const SupplierDraft(name: 'محدث', dealType: SupplierDealType.direct));
    await repo.delete('server-1');

    expect(inner.calls, ['create', 'update:server-1', 'delete:server-1']);
  });

  test('with a coordinator, writes are local-first: mirrored and queued',
      () async {
    final coordinator = OfflineWriteCoordinator(store, tenant);
    final repo = OfflineSupplierRepository(
      inner,
      store: store,
      tenantId: tenant,
      coordinator: coordinator,
    );
    expect(repo.writesAreLocalFirst, isTrue);

    final created = await repo.create(const SupplierDraft(
      name: 'مورد',
      phone: '0599111222',
      dealType: SupplierDealType.commission,
      commissionRate: 20,
    ));
    expect(inner.calls, isEmpty,
        reason: 'the coordinator owns the write, not the inner repo');
    expect(created.id, isNotNull);
    expect(created.commissionRate, 20,
        reason: 'the returned supplier keeps the commission rate');
    final row = (await store.suppliers(tenant)).single;
    expect(row.synced, isFalse);
    expect(row.commissionRate, 20,
        reason: 'the mirror keeps the commission rate');
    expect((await store.pendingSync(tenant)).single.localId, created.id);

    await repo.update(id: created.id, draft: const SupplierDraft(name: 'محدث', dealType: SupplierDealType.direct));
    expect((await store.suppliers(tenant)).single.name, 'محدث');
    expect(await store.pendingCount(tenant), 2);

    await repo.delete(created.id);
    expect(await store.pendingDeleteIds(tenant, 'suppliers'), {created.id});
    expect(await store.pendingCount(tenant), 3);
  });

  test('listAll serves the mirror offline and hides pending deletes', () async {
    final coordinator = OfflineWriteCoordinator(store, tenant);
    final repo = OfflineSupplierRepository(
      inner,
      store: store,
      tenantId: tenant,
      coordinator: coordinator,
    );
    inner.offline = true;

    final kept =
        await repo.create(const SupplierDraft(
        name: 'مورد أ',
        phone: '0599111222',
        dealType: SupplierDealType.direct,
      ));
    final deleted =
        await repo.create(const SupplierDraft(
        name: 'مورد ب',
        phone: '0599111333',
        dealType: SupplierDealType.direct,
      ));

    // Before the delete drains, the mirror hides only the deleted row: the
    // other supplier stays visible (an empty visible mirror would surface an
    // honest NetworkException, since cacheFirst rethrows rather than serve []).
    await repo.delete(deleted.id);
    final hidden = await repo.listAll();
    expect(hidden, hasLength(1));
    expect(hidden.single.id, kept.id);

    // A FAILED delete relaxes the filter (requirement #9): the supplier
    // reappears locally even though the server copy still exists.
    final legs = await store.pendingSync(tenant);
    await store.markFailed(legs.last.id, 'server refused the delete');
    expect(
      await store.pendingDeleteIds(tenant, 'suppliers'),
      isEmpty,
      reason: 'only PENDING deletes suppress; a failed one lets the row show',
    );
    final visible = await repo.listAll();
    expect(visible, hasLength(2));
    expect(visible.map((s) => s.id), containsAll([kept.id, deleted.id]));
  });

  test('listAll mirrors the server list when online', () async {
    inner.suppliers = [
      Supplier(
        id: 's1',
        name: 'مورد خادم',
        phone: null,
        notes: null,
        dealType: SupplierDealType.direct,
        commissionRate: null,
        createdAt: DateTime(2026, 1, 1),
      ),
    ];
    final repo = OfflineSupplierRepository(
      inner,
      store: store,
      tenantId: tenant,
    );

    final all = await repo.listAll();
    expect(all, hasLength(1));
    expect((await store.suppliers(tenant)).single.synced, isTrue);
  });

  test('an empty mirror with the remote down rethrows, never silent []',
      () async {
    inner.offline = true;
    final repo = OfflineSupplierRepository(
      inner,
      store: store,
      tenantId: tenant,
    );
    await expectLater(repo.listAll(), throwsA(isA<NetworkException>()));
  });

  test('an offline-managed supplier survives a process restart', () async {
    final dir = await Directory.systemTemp.createTemp('supplier_repo_offline');
    final file = File('${dir.path}/test.db');

    final db1 = AppDatabase(NativeDatabase(file));
    final s1 = DriftLocalStore(db1);
    final repo1 = OfflineSupplierRepository(
      _FakeInnerRepository(),
      store: s1,
      tenantId: tenant,
      coordinator: OfflineWriteCoordinator(s1, tenant),
    );
    final created = await repo1
        .create(const SupplierDraft(
        name: 'مورد',
        phone: '0599111222',
        dealType: SupplierDealType.direct,
      ));
    await db1.close();

    final db2 = AppDatabase(NativeDatabase(file));
    final s2 = DriftLocalStore(db2);
    try {
      final repo2 = OfflineSupplierRepository(
        _FakeInnerRepository(),
        store: s2,
        tenantId: tenant,
        coordinator: OfflineWriteCoordinator(s2, tenant),
      );
      final all = await repo2.listAll();
      expect(all, hasLength(1));
      expect(all.single.id, created.id);
      expect(all.single.name, 'مورد');
    } finally {
      await db2.close();
    }
  });
}