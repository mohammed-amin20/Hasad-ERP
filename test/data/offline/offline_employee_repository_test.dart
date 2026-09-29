import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasad_erp/core/error/app_exception.dart';
import 'package:hasad_erp/data/offline/local_database.dart';
import 'package:hasad_erp/data/offline/local_store.dart';
import 'package:hasad_erp/data/offline/offline_employee_repository.dart';
import 'package:hasad_erp/data/offline/offline_write.dart';
import 'package:hasad_erp/domain/employees/employee.dart';
import 'package:hasad_erp/domain/employees/employee_draft.dart';
import 'package:hasad_erp/domain/employees/employee_repository.dart';

/// Records every call and optionally plays the "remote down" NetworkException
/// the offline wrapper uses to decide when to read the mirror.
class _FakeInnerRepository implements EmployeeRepository {
  final List<String> calls = <String>[];
  bool offline = false;
  List<Employee> employees = <Employee>[];
  int _next = 0;

  @override
  Future<List<Employee>> listAll({String? search}) async {
    calls.add('listAll');
    if (offline) throw const NetworkException();
    return employees;
  }

  @override
  Future<Employee?> getById(String id) async {
    calls.add('getById:$id');
    if (offline) throw const NetworkException();
    for (final e in employees) {
      if (e.id == id) return e;
    }
    return null;
  }

  @override
  Future<Employee> create(EmployeeDraft draft) async {
    calls.add('create');
    if (offline) throw const NetworkException();
    _next += 1;
    final employee = Employee(
      id: 'server-$_next',
      name: draft.name,
      jobTitle: draft.jobTitle,
      phone: draft.phone,
      baseSalary: draft.baseSalary,
      createdAt: DateTime.now(),
    );
    employees.add(employee);
    return employee;
  }

  @override
  Future<void> update({
    required String id,
    required EmployeeDraft draft,
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
    final repo = OfflineEmployeeRepository(
      inner,
      store: store,
      tenantId: tenant,
    );
    expect(repo.writesAreLocalFirst, isFalse);

    final created = await repo.create(
      const EmployeeDraft(name: 'موظف', phone: '0599111222', baseSalary: 500000),
    );
    expect(created.id, 'server-1');
    await repo.update(id: 'server-1', draft: const EmployeeDraft(name: 'محدث', baseSalary: 600000));
    await repo.delete('server-1');

    expect(inner.calls, ['create', 'update:server-1', 'delete:server-1']);
  });

  test('with a coordinator, writes are local-first: mirrored and queued',
      () async {
    final coordinator = OfflineWriteCoordinator(store, tenant);
    final repo = OfflineEmployeeRepository(
      inner,
      store: store,
      tenantId: tenant,
      coordinator: coordinator,
    );
    expect(repo.writesAreLocalFirst, isTrue);

    final created = await repo.create(
      const EmployeeDraft(name: 'موظف', phone: '0599111222', baseSalary: 500000),
    );
    expect(inner.calls, isEmpty,
        reason: 'the coordinator owns the write, not the inner repo');
    expect(created.id, isNotNull);
    final row = (await store.employees(tenant)).single;
    expect(row.synced, isFalse);
    expect(row.name, 'موظف');
    expect((await store.pendingSync(tenant)).single.localId, created.id);

    await repo.update(id: created.id, draft: const EmployeeDraft(name: 'محدث', baseSalary: 600000));
    expect((await store.employees(tenant)).single.name, 'محدث');
    expect(await store.pendingCount(tenant), 2);

    await repo.delete(created.id);
    expect(await store.pendingDeleteIds(tenant, 'employees'), {created.id});
    expect(await store.pendingCount(tenant), 3);
  });

  test('listAll serves the mirror offline and hides pending deletes', () async {
    final coordinator = OfflineWriteCoordinator(store, tenant);
    final repo = OfflineEmployeeRepository(
      inner,
      store: store,
      tenantId: tenant,
      coordinator: coordinator,
    );
    inner.offline = true;

    final kept = await repo.create(
      const EmployeeDraft(name: 'موظف أ', baseSalary: 500000),
    );
    final deleted = await repo.create(
      const EmployeeDraft(name: 'موظف ب', baseSalary: 500000),
    );

    // Before the delete drains, the mirror hides only the deleted row: the
    // other employee stays visible (an empty visible mirror would surface an
    // honest NetworkException, since cacheFirst rethrows rather than serve []).
    await repo.delete(deleted.id);
    final hidden = await repo.listAll();
    expect(hidden, hasLength(1));
    expect(hidden.single.id, kept.id);

    // A FAILED delete relaxes the filter (requirement #9): the employee
    // reappears locally even though the server copy still exists.
    final legs = await store.pendingSync(tenant);
    await store.markFailed(legs.last.id, 'server refused the delete');
    expect(
      await store.pendingDeleteIds(tenant, 'employees'),
      isEmpty,
      reason: 'only PENDING deletes suppress; a failed one lets the row show',
    );
    final visible = await repo.listAll();
    expect(visible, hasLength(2));
    expect(visible.map((e) => e.id), containsAll([kept.id, deleted.id]));
  });

  test('getById serves the mirror offline and hides pending deletes', () async {
    final coordinator = OfflineWriteCoordinator(store, tenant);
    final repo = OfflineEmployeeRepository(
      inner,
      store: store,
      tenantId: tenant,
      coordinator: coordinator,
    );
    inner.offline = true;

    final kept = await repo.create(
      const EmployeeDraft(name: 'موظف أ', baseSalary: 500000),
    );
    final deleted = await repo.create(
      const EmployeeDraft(name: 'موظف ب', baseSalary: 500000),
    );
    await repo.delete(deleted.id);

    expect((await repo.getById(kept.id))?.id, kept.id);
    // A pending delete hides the row from the local read, so cacheFirst has
    // nothing to serve and falls through to the unreachable network — an
    // honest NetworkException, never a fabricated null (parity with listAll
    // rethrowing rather than serving a silent empty).
    await expectLater(
      repo.getById(deleted.id),
      throwsA(isA<NetworkException>()),
    );
  });

  test('listAll mirrors the server list when online', () async {
    inner.employees = [
      Employee(
        id: 'e1',
        name: 'موظف خادم',
        jobTitle: null,
        phone: null,
        baseSalary: 500000,
        createdAt: DateTime(2026, 1, 1),
      ),
    ];
    final repo = OfflineEmployeeRepository(
      inner,
      store: store,
      tenantId: tenant,
    );

    final all = await repo.listAll();
    expect(all, hasLength(1));
    expect((await store.employees(tenant)).single.synced, isTrue);
  });

  test('an empty mirror with the remote down rethrows, never silent []',
      () async {
    inner.offline = true;
    final repo = OfflineEmployeeRepository(
      inner,
      store: store,
      tenantId: tenant,
    );
    await expectLater(repo.listAll(), throwsA(isA<NetworkException>()));
  });

  test('an offline-managed employee survives a process restart', () async {
    final dir = await Directory.systemTemp.createTemp('employee_repo_offline');
    final file = File('${dir.path}/test.db');

    final db1 = AppDatabase(NativeDatabase(file));
    final s1 = DriftLocalStore(db1);
    final repo1 = OfflineEmployeeRepository(
      _FakeInnerRepository(),
      store: s1,
      tenantId: tenant,
      coordinator: OfflineWriteCoordinator(s1, tenant),
    );
    final created = await repo1
        .create(const EmployeeDraft(name: 'موظف', phone: '0599111222', baseSalary: 500000));
    await db1.close();

    final db2 = AppDatabase(NativeDatabase(file));
    final s2 = DriftLocalStore(db2);
    try {
      final repo2 = OfflineEmployeeRepository(
        _FakeInnerRepository(),
        store: s2,
        tenantId: tenant,
        coordinator: OfflineWriteCoordinator(s2, tenant),
      );
      final all = await repo2.listAll();
      expect(all, hasLength(1));
      expect(all.single.id, created.id);
      expect(all.single.name, 'موظف');
    } finally {
      await db2.close();
    }
  });
}