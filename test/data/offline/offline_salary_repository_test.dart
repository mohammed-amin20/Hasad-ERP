import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasad_erp/core/error/app_exception.dart';
import 'package:hasad_erp/data/offline/local_database.dart';
import 'package:hasad_erp/data/offline/local_store.dart';
import 'package:hasad_erp/data/offline/offline_salary_repository.dart';
import 'package:hasad_erp/data/offline/offline_write.dart';
import 'package:hasad_erp/domain/salaries/salary_repository.dart';

/// Configurable inner repo so the wrapper's live-first/offline-fallback and
/// write-routing behaviour are deterministic.
class _FakeSalaryRepository implements SalaryRepository {
  _FakeSalaryRepository({
    this.entitlementResult,
    this.historyResult,
    this.failWith,
  });

  EmployeeEntitlement? entitlementResult;
  List<SalaryRecord>? historyResult;
  EmployeeStatement? statementResult;
  MovementResult? movementResult;
  SalaryResult? payResult;
  NetworkException? failWith;

  int entitlementCalls = 0;
  int historyCalls = 0;
  int statementCalls = 0;
  int addMovementCalls = 0;
  int payCalls = 0;

  void _throwIfOffline() {
    final f = failWith;
    if (f != null) throw f;
  }

  @override
  Future<EmployeeEntitlement> entitlement({
    required String employeeId,
    required DateTime month,
  }) async {
    entitlementCalls++;
    _throwIfOffline();
    return entitlementResult ??
        EmployeeEntitlement(
          employeeId: employeeId,
          month: month,
          baseSalary: 0,
          arrears: 0,
          entitlements: 0,
          deductions: 0,
          netDue: 0,
          isPaidForMonth: false,
        );
  }

  @override
  Future<List<SalaryRecord>> salaryHistory() async {
    historyCalls++;
    _throwIfOffline();
    return historyResult ?? const [];
  }

  @override
  Future<EmployeeStatement> employeeStatement(
    EmployeeStatementRequest request,
  ) async {
    statementCalls++;
    _throwIfOffline();
    if (statementResult != null) return statementResult!;
    throw UnimplementedError();
  }

  @override
  Future<MovementResult> addMovement(MovementDraft draft) async {
    addMovementCalls++;
    final r = movementResult;
    return r ?? const MovementResult();
  }

  @override
  Future<SalaryResult> pay(SalaryDraft draft) async {
    payCalls++;
    final r = payResult;
    return r ?? const SalaryResult();
  }
}

void main() {
  const tenant = 'tenant-a';

  late AppDatabase db;
  late DriftLocalStore store;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = DriftLocalStore(db);
  });

  tearDown(() => db.close());

  Future<void> seedEmployeeAndChart() async {
    Future<void> account(String id, String code, String type) =>
        store.upsertAccount(LocalAccountRow(
          id: id, tenantId: tenant, code: code, name: code, type: type,
          parentCode: null,
        ));
    await account('a1', '1010', 'asset');
    await account('a2', '1015', 'asset');
    await account('a6', '2030', 'liability');
    await account('a8', '5030', 'expense');
    await store.upsertEmployee(LocalEmployeeRow(
      id: 'e1', tenantId: tenant, name: 'موظف', jobTitle: 'sales',
      phone: null, baseSalary: 500000, createdAt: DateTime(2026, 1, 1),
      synced: false,
    ));
  }

  OfflineSalaryRepository repo({
    _FakeSalaryRepository? inner,
    OfflineWriteCoordinator? coordinator,
  }) =>
      OfflineSalaryRepository(
        inner ?? _FakeSalaryRepository(),
        store: store,
        tenantId: tenant,
        coordinator: coordinator,
      );

  group('OfflineSalaryRepository writes (routing)', () {
    test('addMovement routes through the coordinator when one is present',
        () async {
      await seedEmployeeAndChart();
      final inner = _FakeSalaryRepository()
        ..movementResult = const MovementResult(duplicate: false);
      final routed = repo(
        inner: inner,
        coordinator: OfflineWriteCoordinator(store, tenant),
      );

      final result = await routed.addMovement(MovementDraft(
        employeeId: 'e1',
        month: DateTime(2026, 9, 1),
        direction: 'out',
        category: 'advance',
        amount: 100000,
      ));

      expect(inner.addMovementCalls, 0, reason: 'must not reach the live RPC');
      expect(result.pending, isTrue);
      expect((await store.pendingSync(tenant)).single.rpc,
          'add_employee_movement');
      expect(await store.employeeMovements(tenant), hasLength(1));
    });

    test('pay routes through the coordinator when one is present', () async {
      await seedEmployeeAndChart();
      final inner = _FakeSalaryRepository()
        ..payResult = const SalaryResult(duplicate: false);
      final routed = repo(
        inner: inner,
        coordinator: OfflineWriteCoordinator(store, tenant),
      );

      final result = await routed.pay(SalaryDraft(
        employeeId: 'e1',
        month: DateTime(2026, 9, 1),
        paid: 400000,
        method: 'cash',
      ));

      expect(inner.payCalls, 0, reason: 'must not reach the live RPC');
      expect(result.pending, isTrue);
      expect((await store.pendingSync(tenant)).single.rpc, 'pay_salary');
      expect(await store.salaries(tenant), hasLength(1));
    });

    test('addMovement falls back to the inner repo without a coordinator',
        () async {
      final inner = _FakeSalaryRepository()
        ..movementResult = const MovementResult(
          movementId: 'srv-m1',
          amount: 100000,
          pending: false,
        );

      final result = await repo(inner: inner).addMovement(MovementDraft(
        employeeId: 'e1',
        month: DateTime(2026, 9, 1),
        direction: 'out',
        category: 'advance',
        amount: 100000,
      ));

      expect(inner.addMovementCalls, 1);
      expect(result.pending, isFalse);
      expect(result.movementId, 'srv-m1');
      expect(await store.pendingSync(tenant), isEmpty);
    });

    test('pay falls back to the inner repo without a coordinator', () async {
      final inner = _FakeSalaryRepository()
        ..payResult = const SalaryResult(
          salaryId: 'srv-s1',
          paid: 400000,
          pending: false,
        );

      final result = await repo(inner: inner).pay(SalaryDraft(
        employeeId: 'e1',
        month: DateTime(2026, 9, 1),
        paid: 400000,
        method: 'cash',
      ));

      expect(inner.payCalls, 1);
      expect(result.pending, isFalse);
      expect(result.salaryId, 'srv-s1');
      expect(await store.pendingSync(tenant), isEmpty);
    });
  });

  group('OfflineSalaryRepository reads (offline fallback)', () {
    test('entitlement is live-first and falls back to the local mirrors',
        () async {
      await store.upsertEmployee(LocalEmployeeRow(
        id: 'e1', tenantId: tenant, name: 'موظف', jobTitle: 'sales',
        phone: null, baseSalary: 500000, createdAt: DateTime(2026, 1, 1),
        synced: false,
      ));
      await store.upsertEmployeeMovement(LocalEmployeeMovementRow(
        id: 'm1', tenantId: tenant, employeeId: 'e1',
        month: '2026-09', direction: 'out', category: 'advance',
        amount: 100000, date: DateTime(2026, 9, 5), note: null,
        requestId: 'req-m1', synced: false, createdAt: DateTime(2026, 9, 5),
      ));

      final live = _FakeSalaryRepository(
        entitlementResult: EmployeeEntitlement(
          employeeId: 'e1',
          month: DateTime(2026, 9, 1),
          baseSalary: 500000,
          arrears: 0,
          entitlements: 0,
          deductions: 0,
          netDue: 500000,
          isPaidForMonth: false,
        ),
      );
      final served = await repo(inner: live).entitlement(
        employeeId: 'e1',
        month: DateTime(2026, 9, 1),
      );
      expect(live.entitlementCalls, 1);
      expect(served.netDue, 500000);

      final offliner = _FakeSalaryRepository(
        failWith: const NetworkException(),
      );
      final local = await repo(inner: offliner).entitlement(
        employeeId: 'e1',
        month: DateTime(2026, 9, 1),
      );
      expect(local.baseSalary, 500000);
      expect(local.deductions, 100000);
      expect(local.netDue, 400000);
    });

    test('salaryHistory merges unsynced local rows newest-first', () async {
      await store.upsertEmployee(LocalEmployeeRow(
        id: 'e1', tenantId: tenant, name: 'موظف', jobTitle: 'sales',
        phone: null, baseSalary: 500000, createdAt: DateTime(2026, 1, 1),
        synced: false,
      ));
      await store.upsertSalary(LocalSalaryRow(
        id: 's-local', tenantId: tenant, employeeId: 'e1', month: '2026-09',
        paid: 400000, netDue: 400000, requestId: 'req-s1', synced: false,
        createdAt: DateTime(2026, 9, 20, 10),
      ));
      await store.upsertSalary(LocalSalaryRow(
        id: 's-synced', tenantId: tenant, employeeId: 'e1', month: '2026-08',
        paid: 300000, netDue: 300000, requestId: 'req-s2', synced: true,
        createdAt: DateTime(2026, 8, 20, 10),
      ));

      final inner = _FakeSalaryRepository(
        historyResult: [
          SalaryRecord(
            employeeId: 'e1',
            month: DateTime(2026, 8, 1),
            baseSalary: 500000,
            paid: 300000,
            date: DateTime(2026, 8, 1),
          ),
        ],
      );

      final served = await repo(inner: inner).salaryHistory();

      expect(inner.historyCalls, 1);
      expect(served, hasLength(2), reason: 'one server + one unsynced local');
      expect(served.first.month, DateTime(2026, 9, 1), reason: 'newest first');
      final local = served.singleWhere((r) => r.employeeId == 'e1' &&
          r.month == DateTime(2026, 9, 1));
      expect(local.baseSalary, 500000, reason: 'base from the employee mirror');
      expect(local.paid, 400000);
    });

    test('salaryHistory serves local rows on NetworkException, else rethrows',
        () async {
      final empty = _FakeSalaryRepository(failWith: const NetworkException());
      await expectLater(repo(inner: empty).salaryHistory(),
          throwsA(isA<NetworkException>()));

      await store.upsertSalary(LocalSalaryRow(
        id: 's-local', tenantId: tenant, employeeId: 'e1', month: '2026-09',
        paid: 400000, netDue: 400000, requestId: 'req-s1', synced: false,
        createdAt: DateTime(2026, 9, 20, 10),
      ));
      final offliner = _FakeSalaryRepository(failWith: const NetworkException());
      final served = await repo(inner: offliner).salaryHistory();
      expect(served, hasLength(1));
      expect(served.single.month, DateTime(2026, 9, 1));
    });

    test('employeeStatement falls back to the local mirrors', () async {
      await store.upsertEmployee(LocalEmployeeRow(
        id: 'e1', tenantId: tenant, name: 'موظف', jobTitle: 'sales',
        phone: null, baseSalary: 500000, createdAt: DateTime(2026, 1, 1),
        synced: false,
      ));
      await store.upsertSalary(LocalSalaryRow(
        id: 's-local', tenantId: tenant, employeeId: 'e1', month: '2026-09',
        paid: 400000, netDue: 400000, requestId: 'req-s1', synced: false,
        createdAt: DateTime(2026, 9, 20, 10),
      ));
      await store.upsertEmployeeMovement(LocalEmployeeMovementRow(
        id: 'm1', tenantId: tenant, employeeId: 'e1',
        month: '2026-09', direction: 'out', category: 'advance',
        amount: 100000, date: DateTime(2026, 9, 5), note: null,
        requestId: 'req-m1', synced: false, createdAt: DateTime(2026, 9, 5),
      ));

      final offliner = _FakeSalaryRepository(
        failWith: const NetworkException(),
      );
      final st = await repo(inner: offliner).employeeStatement(
        EmployeeStatementRequest(
          employeeId: 'e1',
          from: DateTime(2026, 9, 1),
          to: DateTime(2026, 9, 30),
        ),
      );

      expect(st.lines, hasLength(1));
      final line = st.lines.single;
      expect(line.baseSalary, 500000);
      expect(line.deductions, 100000);
      expect(line.netDue, 400000);
      expect(line.paid, 400000);
      expect(line.remaining, 0);
      expect(st.closing, 0);
    });
  });

  group('OfflineSalaryRepository restart durability (file-backed)', () {
    test('offline salary and movement survive a process restart', () async {
      final dir = await Directory.systemTemp.createTemp('hasad_salary_p1b');
      addTearDown(() async {
        await dir.delete(recursive: true);
      });
      final file = File('${dir.path}/salary.sqlite');

      final first = AppDatabase(NativeDatabase(file));
      final firstStore = DriftLocalStore(first);
      await _seedEmployeeAndChartOn(firstStore);

      final inner = _FakeSalaryRepository(
        failWith: const NetworkException(),
      );
      final repo1 = OfflineSalaryRepository(
        inner,
        store: firstStore,
        tenantId: tenant,
        coordinator: OfflineWriteCoordinator(firstStore, tenant),
      );

      final movement = await repo1.addMovement(MovementDraft(
        employeeId: 'e1',
        month: DateTime(2026, 9, 1),
        direction: 'out',
        category: 'advance',
        amount: 100000,
      ));
      expect(movement.pending, isTrue);
      final salary = await repo1.pay(SalaryDraft(
        employeeId: 'e1',
        month: DateTime(2026, 9, 1),
        paid: 400000,
        method: 'cash',
      ));
      expect(salary.pending, isTrue);
      await first.close();

      final second = AppDatabase(NativeDatabase(file));
      addTearDown(second.close);
      final secondStore = DriftLocalStore(second);
      expect(await secondStore.employeeMovements(tenant), hasLength(1));
      expect(await secondStore.salaries(tenant), hasLength(1));
      expect(await secondStore.pendingSync(tenant), hasLength(2));

      final repo2 = OfflineSalaryRepository(
        _FakeSalaryRepository(failWith: const NetworkException()),
        store: secondStore,
        tenantId: tenant,
      );

      final entitlement = await repo2.entitlement(
        employeeId: 'e1',
        month: DateTime(2026, 9, 1),
      );
      expect(entitlement.baseSalary, 500000);
      expect(entitlement.deductions, 100000);

      final history = await repo2.salaryHistory();
      expect(history, hasLength(1));
      expect(history.single.paid, 400000);

      final st = await repo2.employeeStatement(
        EmployeeStatementRequest(
          employeeId: 'e1',
          from: DateTime(2026, 1, 1),
          to: DateTime(2026, 12, 31),
        ),
      );
      expect(st.lines, hasLength(1));
      expect(st.closing, 0);
    });
  });
}

Future<void> _seedEmployeeAndChartOn(DriftLocalStore s) async {
  const tenant = 'tenant-a';
  Future<void> account(String id, String code, String type) =>
      s.upsertAccount(LocalAccountRow(
        id: id, tenantId: tenant, code: code, name: code, type: type,
        parentCode: null,
      ));
  await account('a1', '1010', 'asset');
  await account('a2', '1015', 'asset');
  await account('a6', '2030', 'liability');
  await account('a8', '5030', 'expense');
  await s.upsertEmployee(LocalEmployeeRow(
    id: 'e1', tenantId: tenant, name: 'موظف', jobTitle: 'sales',
    phone: null, baseSalary: 500000, createdAt: DateTime(2026, 1, 1),
    synced: false,
  ));
}