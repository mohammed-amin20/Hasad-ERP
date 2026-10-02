/// The salary is paid, the write is durable, and the month still reads as unpaid.
///
/// ## What is already proven
///
/// `offline_write_test.dart` and the device run both show the durable half
/// working: `paySalary` writes a `local_salaries` row with `synced: false` and
/// `paid: draft.paid`, and a second attempt for the same month is refused by the
/// write-side guard with `تم صرف راتب هذا الشهر مسبقاً`. The row therefore
/// exists — the duplicate guard reads it back out of the same table.
///
/// ## What is missing
///
/// Nothing in the **read** model can express "this month is paid":
///
/// * `_localEntitlement` reconstructs an `EmployeeEntitlement` from the employee
///   mirror and calls `computeSalaryComputation`, which derives arrears from
///   *earlier* months only. Paying the target month cannot move `netDue` — and
///   per the locked contract it must not: `netDue` stays the gross `X`.
/// * `EmployeeEntitlement` has no `isPaidForMonth` and no `currentPayable`.
/// * `salaries_screen.dart` renders `netDue` under the label `صافي المستحقات`
///   and gates the pay action on it, so a paid month is still presented as
///   payable, with no status at all.
///
/// `salaryRunProvider(employeeId, month)` supplies exactly that value, and
/// `SalaryActions._refresh` already invalidates exactly that family key — which
/// is why forced invalidation does not help. The read model is stale, not the
/// cache.
///
/// ## The locked contract these cases encode
///
/// | fact | value |
/// |---|---|
/// | `netDue` after paying | unchanged gross `X` (never zeroed) |
/// | paid state | `isPaidForMonth == true` |
/// | presented payable | `currentPayable = isPaidForMonth ? 0 : netDue` |
/// | paid label | `تم صرف راتب هذا الشهر` |
/// | payable label when paid | `المتبقي للصرف: 0` |
/// | gross, if still shown | must read `استحقاق الشهر: X` |
///
/// ## The production surface these cases now compile against
///
/// `EmployeeEntitlement.isPaidForMonth` (required) and the derived
/// `currentPayable` exist, so this file references them **directly**. The
/// dynamic probes this file carried while the members were still missing are
/// gone: they swallowed a
/// missing member into "unpaid", which is indistinguishable from the bug being
/// pinned, and a dynamic read asserts nothing about a real member's type.
/// A direct `ent.isPaidForMonth` that stops compiling is the stronger signal.
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasad_erp/core/error/app_exception.dart';
import 'package:hasad_erp/data/offline/local_database.dart';
import 'package:hasad_erp/data/offline/local_store.dart';
import 'package:hasad_erp/data/offline/offline_salary_repository.dart';
import 'package:hasad_erp/data/offline/offline_write.dart';
import 'package:hasad_erp/domain/salaries/salary_repository.dart';

void main() {
  const tenantA = 'tenant-a';
  const tenantB = 'tenant-b';
  const gross = 500000;

  late AppDatabase db;
  late DriftLocalStore store;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = DriftLocalStore(db);
  });

  tearDown(() => db.close());

  /// 1010 pays, 2030 is the salary payable, 5030 the expense — the three
  /// accounts `paySalary` pre-validates against the local chart.
  Future<void> seedChart(String tenant) async {
    for (final a in const [
      ('a1', '1010', 'نقدية', 'asset'),
      ('a6', '2030', 'رواتب مستحقة', 'liability'),
      ('a8', '5030', 'مصروف رواتب', 'expense'),
    ]) {
      await store.upsertAccount(LocalAccountRow(
        id: a.$1,
        tenantId: tenant,
        code: a.$2,
        name: a.$3,
        type: a.$4,
        parentCode: null,
      ));
    }
  }

  Future<void> seedEmployee(String tenant, String id) async {
    await store.upsertEmployee(LocalEmployeeRow(
      id: id,
      tenantId: tenant,
      name: 'موظف',
      jobTitle: 'sales',
      phone: null,
      baseSalary: gross,
      createdAt: DateTime(2026, 1, 1),
      synced: true,
    ));
  }

  final month = DateTime(2026, 3, 1);
  final prevMonth = DateTime(2026, 2, 1);
  final nextMonth = DateTime(2026, 4, 1);

  /// Pays the salary for [employeeId]/[month] offline, through the real
  /// coordinator, and returns nothing: the write side is already proven.
  Future<void> payOffline(String tenant, String employeeId) async {
    await OfflineWriteCoordinator(store, tenant).paySalary(
      SalaryDraft(
        employeeId: employeeId,
        month: month,
        paid: gross,
        method: 'cash',
        date: DateTime(2026, 3, 30),
      ),
    );
  }

  /// The live entitlement the server would report: the gross figure for the
  /// month, unchanged by a local payment the server has not seen yet.
  ///
  /// [isPaidForMonth] is the server's own `salaries` answer. The two must be
  /// independent arguments, not one derived from the other: S3a pairs a
  /// pre-payment server view with a paid local row, while S7b pairs a
  /// post-drain server view with no local row at all. Collapsing them would let
  /// a test set the state it is trying to prove.
  EmployeeEntitlement liveEntitlement({
    required String employeeId,
    bool isPaidForMonth = false,
  }) =>
      EmployeeEntitlement(
        employeeId: employeeId,
        month: month,
        baseSalary: gross,
        arrears: 0,
        entitlements: 0,
        deductions: 0,
        netDue: gross,
        isPaidForMonth: isPaidForMonth,
      );

  group('S1. the durable half (already true today, kept as the precondition)', () {
    test('S1a. paying offline leaves a durable unsynced salary row', () async {
      await seedChart(tenantA);
      await seedEmployee(tenantA, 'e1');

      await payOffline(tenantA, 'e1');

      final rows = await store.salaries(tenantA);
      expect(rows, hasLength(1));
      expect(rows.single.month, '2026-03');
      expect(rows.single.synced, isFalse);
      expect(rows.single.paid, gross);
    });

    test('S1b. a second pay for the same month is refused by the write guard',
        () async {
      await seedChart(tenantA);
      await seedEmployee(tenantA, 'e1');
      await payOffline(tenantA, 'e1');

      await expectLater(
        OfflineWriteCoordinator(store, tenantA).paySalary(
          SalaryDraft(
            employeeId: 'e1',
            month: month,
            paid: gross,
            method: 'cash',
            date: DateTime(2026, 3, 30),
          ),
        ),
        throwsA(isA<ValidationException>()),
        reason: 'the durable row is what the duplicate guard reads, so its '
            'presence is the proof the write half works — the read half is '
            'where the device report lives',
      );
    });
  });

  group('S2. the offline paid state', () {
    test('S2a. a paid month must report isPaidForMonth', () async {
      await seedChart(tenantA);
      await seedEmployee(tenantA, 'e1');
      await payOffline(tenantA, 'e1');

      final repo = OfflineSalaryRepository(
        _Server(unreachable: true),
        store: store,
        tenantId: tenantA,
        coordinator: OfflineWriteCoordinator(store, tenantA),
      );
      final ent = await repo.entitlement(employeeId: 'e1', month: month);

      expect(ent.isPaidForMonth, isTrue,
          reason: 'a durable salary row for the target month means the month is '
              'paid; the read model must be able to say so');
    });

    test('S2b. the gross netDue must stay X after paying', () async {
      // The opposite trap. Zeroing netDue would look like a fix and would be
      // wrong: netDue is the month's entitlement, and a paid month is
      // represented by the paid state, not by falsifying the entitlement.
      await seedChart(tenantA);
      await seedEmployee(tenantA, 'e1');
      await payOffline(tenantA, 'e1');

      final repo = OfflineSalaryRepository(
        _Server(unreachable: true),
        store: store,
        tenantId: tenantA,
        coordinator: OfflineWriteCoordinator(store, tenantA),
      );
      final ent = await repo.entitlement(employeeId: 'e1', month: month);

      expect(ent.netDue, gross);
    });

    test('S2c. a paid month must present a current payable of 0', () async {
      await seedChart(tenantA);
      await seedEmployee(tenantA, 'e1');
      await payOffline(tenantA, 'e1');

      final repo = OfflineSalaryRepository(
        _Server(unreachable: true),
        store: store,
        tenantId: tenantA,
        coordinator: OfflineWriteCoordinator(store, tenantA),
      );
      final ent = await repo.entitlement(employeeId: 'e1', month: month);

      expect(ent.currentPayable, 0,
          reason: 'currentPayable = isPaidForMonth ? 0 : netDue; today the '
              'screen shows the full X as still payable after it was paid');
    });
  });

  group('S3. online/live read with a pending local payment', () {
    test('S3a. a live gross entitlement is overlaid with the unsynced payment',
        () async {
      await seedChart(tenantA);
      await seedEmployee(tenantA, 'e1');
      await payOffline(tenantA, 'e1');

      // Back online: the server answers, and still reports the pre-payment
      // figures because the leg has not replayed.
      final repo = OfflineSalaryRepository(
        _Server(entitlementResult: liveEntitlement(employeeId: 'e1')),
        store: store,
        tenantId: tenantA,
        coordinator: OfflineWriteCoordinator(store, tenantA),
      );
      final ent = await repo.entitlement(employeeId: 'e1', month: month);

      expect(ent.netDue, gross,
          reason: 'the live entitlement is authoritative for the amount');
      expect(ent.isPaidForMonth, isTrue,
          reason: 'the unsynced local salary row must still mark the month as '
              'paid — otherwise reconnecting silently un-pays it');
    });

    test('S3b. a server-paid month stays paid with no local row at all', () async {
      // The mirror is device-local. A device that never paid this month (a
      // second phone, or a fresh install) has no `local_salaries` row, so the
      // server half of the OR is the only thing that can prevent a second
      // payout. If the composition ever regresses to "local row wins", this
      // case silently starts offering to pay a salary that is already in the
      // ledger.
      await seedEmployee(tenantA, 'e1');

      final repo = OfflineSalaryRepository(
        _Server(
          entitlementResult:
              liveEntitlement(employeeId: 'e1', isPaidForMonth: true),
        ),
        store: store,
        tenantId: tenantA,
        coordinator: OfflineWriteCoordinator(store, tenantA),
      );
      final ent = await repo.entitlement(employeeId: 'e1', month: month);

      expect(ent.isPaidForMonth, isTrue,
          reason: 'the server row is authoritative; the local mirror is a '
              'per-device cache and may be empty or stale in either direction');
      expect(ent.currentPayable, 0);
    });
  });

  group('S4. restart durability of the paid state', () {
    test('S4a. a paid month still reads as paid after an app restart', () async {
      final dir = Directory.systemTemp.createTempSync('hasad_salary_paid');
      addTearDown(() {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      });
      final file = File('${dir.path}/salary.db');

      final db1 = AppDatabase(NativeDatabase(file));
      final store1 = DriftLocalStore(db1);
      await seedChartFor(store1, tenantA);
      await store1.upsertEmployee(LocalEmployeeRow(
        id: 'e1',
        tenantId: tenantA,
        name: 'موظف',
        jobTitle: 'sales',
        phone: null,
        baseSalary: gross,
        createdAt: DateTime(2026, 1, 1),
        synced: true,
      ));
      await OfflineWriteCoordinator(store1, tenantA).paySalary(
        SalaryDraft(
          employeeId: 'e1',
          month: month,
          paid: gross,
          method: 'cash',
          date: DateTime(2026, 3, 30),
        ),
      );
      await db1.close();

      // The app restarts, still offline.
      final db2 = AppDatabase(NativeDatabase(file));
      final store2 = DriftLocalStore(db2);
      addTearDown(db2.close);
      final repo = OfflineSalaryRepository(
        _Server(unreachable: true),
        store: store2,
        tenantId: tenantA,
        coordinator: OfflineWriteCoordinator(store2, tenantA),
      );

      final ent = await repo.entitlement(employeeId: 'e1', month: month);
      expect(ent.isPaidForMonth, isTrue);
      expect(ent.currentPayable, 0);
    });
  });

  group('S5. month isolation', () {
    test('S5a. paying March must not mark April as paid', () async {
      await seedChart(tenantA);
      await seedEmployee(tenantA, 'e1');
      await payOffline(tenantA, 'e1');

      final repo = OfflineSalaryRepository(
        _Server(unreachable: true),
        store: store,
        tenantId: tenantA,
        coordinator: OfflineWriteCoordinator(store, tenantA),
      );
      final march = await repo.entitlement(employeeId: 'e1', month: month);
      final april = await repo.entitlement(employeeId: 'e1', month: nextMonth);

      expect(march.isPaidForMonth, isTrue);
      expect(april.isPaidForMonth, isFalse,
          reason: 'the paid state is per employee-month, never a sticky flag');
      expect(april.netDue, gross,
          reason: 'an unpaid next month is still fully payable');
      expect(april.currentPayable, gross);
    });

    test('S5b. paying March must not mark the month BEFORE it as paid',
        () async {
      // The arrears computation reads *earlier* months' salary rows, so the
      // backward direction is where the collision risk actually lives: a
      // "does this employee have any salary row" implementation reports paid
      // for February, March and every earlier month, forever. February is
      // therefore the case with teeth here, not a duplicate of S5a.
      await seedChart(tenantA);
      await seedEmployee(tenantA, 'e1');
      await payOffline(tenantA, 'e1');

      final repo = OfflineSalaryRepository(
        _Server(unreachable: true),
        store: store,
        tenantId: tenantA,
        coordinator: OfflineWriteCoordinator(store, tenantA),
      );
      final february =
          await repo.entitlement(employeeId: 'e1', month: prevMonth);

      expect(february.isPaidForMonth, isFalse,
          reason: 'an earlier month is not paid because a later one was');
      expect(february.currentPayable, gross);
    });
  });

  group('S6. tenant isolation', () {
    test('S6a. a neighbouring workspace\'s paid month must not mark this one '
        'paid', () async {
      // Note what this does NOT do: it does not read tenant B's employee
      // through tenant A's repository. `LocalEmployees` is keyed `{id}` alone, so
      // the same id cannot exist in two tenants, and asking A for B's employee
      // only proves `_employeeRow` throws — a state no user can reach, since
      // the employee list is tenant-scoped too. The reachable leak is the
      // reverse direction: a *shared* month in which B is paid and A is not,
      // which is exactly the window a user in A hits on a Monday morning after
      // a colleague paid from another device. Matching paid state on the month
      // alone, or scanning salary rows without the tenant filter, fails here.
      await seedChart(tenantA);
      await seedChart(tenantB);
      await seedEmployee(tenantA, 'e1');
      await seedEmployee(tenantB, 'e2');
      await payOffline(tenantB, 'e2');

      expect((await store.salaries(tenantB)), hasLength(1),
          reason: 'precondition: the neighbouring workspace did pay March');
      expect(await store.salaries(tenantA), isEmpty,
          reason: 'precondition: this workspace has no salary row at all');

      final repoA = OfflineSalaryRepository(
        _Server(unreachable: true),
        store: store,
        tenantId: tenantA,
        coordinator: OfflineWriteCoordinator(store, tenantA),
      );
      final ent = await repoA.entitlement(employeeId: 'e1', month: month);

      expect(ent.isPaidForMonth, isFalse,
          reason: 'the salary mirror is read tenant-scoped; a neighbouring '
              'workspace\'s payment must not leak into this one');
      expect(ent.currentPayable, gross);
    });

    test('S6b. a tenant cannot read the paid state through another tenant\'s '
        'employee id', () async {
      // The companion to S6a, pinning the half that is a *throw* rather than a
      // wrong answer: reading B's employee from A's repository must fail
      // closed with the Arabic local-mirror error, never resolve to some other
      // figure by falling through to a different lookup.
      await seedChart(tenantA);
      await seedChart(tenantB);
      await seedEmployee(tenantA, 'e1');
      await seedEmployee(tenantB, 'e2');
      await payOffline(tenantB, 'e2');

      final repoA = OfflineSalaryRepository(
        _Server(unreachable: true),
        store: store,
        tenantId: tenantA,
        coordinator: OfflineWriteCoordinator(store, tenantA),
      );

      await expectLater(
        repoA.entitlement(employeeId: 'e2', month: month),
        throwsA(isA<ValidationException>()),
        reason: 'failing closed is the required behaviour: an employee outside '
            'this tenant is not an entitlement of zero, it is no entitlement',
      );
    });
  });

  group('S7. the transition after the leg drains', () {
    test('S7a. the paid state survives the leg draining', () async {
      await seedChart(tenantA);
      await seedEmployee(tenantA, 'e1');
      await payOffline(tenantA, 'e1');

      // The leg replays: `markReplaySynced` flips the mirror row to synced and
      // stamps the server id. The paid state must not be a function of `synced`
      // — a synced row is the normal steady state, not a lost payment.
      final row = (await store.salaries(tenantA)).single;
      await store.markReplaySynced(
        tenantId: tenantA,
        entity: 'salaries',
        localId: row.id,
        serverId: 'sal-server-1',
        officialNo: null,
      );
      final drained = (await store.salaries(tenantA)).single;
      expect(drained.synced, isTrue, reason: 'precondition: the leg drained');

      final repo = OfflineSalaryRepository(
        _Server(unreachable: true),
        store: store,
        tenantId: tenantA,
        coordinator: OfflineWriteCoordinator(store, tenantA),
      );
      final ent = await repo.entitlement(employeeId: 'e1', month: month);

      expect(ent.isPaidForMonth, isTrue,
          reason: 'a replayed salary is still a paid salary');
    });
  });
}

/// Chart seed taking a store, so the file-backed case can seed through its own
/// connection.
Future<void> seedChartFor(DriftLocalStore store, String tenant) async {
  for (final a in const [
    ('a1', '1010', 'نقدية', 'asset'),
    ('a6', '2030', 'رواتب مستحقة', 'liability'),
    ('a8', '5030', 'مصروف رواتب', 'expense'),
  ]) {
    await store.upsertAccount(LocalAccountRow(
      id: a.$1,
      tenantId: tenant,
      code: a.$2,
      name: a.$3,
      type: a.$4,
      parentCode: null,
    ));
  }
}

/// The server side of the wrapper. `_unreachable` is the offline device; the
/// default answers `entitlementResult` so the live-first branch is exercised.
class _Server implements SalaryRepository {
  _Server({this.entitlementResult, this.unreachable = false});

  final EmployeeEntitlement? entitlementResult;

  /// The offline device: every read throws, so the wrapper must fall back to
  /// the local reconstruction.
  final bool unreachable;

  void _guard() {
    if (unreachable) throw const NetworkException();
  }

  @override
  Future<EmployeeEntitlement> entitlement({
    required String employeeId,
    required DateTime month,
  }) async {
    _guard();
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
    _guard();
    return const [];
  }

  @override
  Future<EmployeeStatement> employeeStatement(
    EmployeeStatementRequest request,
  ) async {
    _guard();
    throw UnimplementedError();
  }

  @override
  Future<MovementResult> addMovement(MovementDraft draft) async =>
      const MovementResult();

  @override
  Future<SalaryResult> pay(SalaryDraft draft) async => const SalaryResult();
}
