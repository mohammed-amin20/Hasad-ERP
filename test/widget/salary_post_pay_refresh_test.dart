/// The salary is paid offline and the screen still offers to pay it again.
///
/// ## What the device showed
///
/// The write succeeded — the durable row is there, which is why the *second*
/// attempt is correctly refused with `تم صرف راتب هذا الشهر مسبقاً` — and yet
/// right after the first payout the run card still showed the full `5000` under
/// `صافي المستحقات` with no indication the month was settled.
///
/// ## Why refreshing does not help
///
/// `SalariesScreen` watches `salaryRunProvider(employeeId, _month)`, and
/// `SalaryActions.pay()` already invalidates exactly that family key
/// (`salaries_providers.dart:122`). So the provider *is* re-read after the write
/// and still returns the gross `netDue`, because nothing in the read model can
/// express "this month is paid":
///
/// * `_localEntitlement` derives arrears from earlier months only, so paying the
///   target month cannot move the entitlement — and per the locked contract it
///   must not;
/// * `EmployeeEntitlement` has no `isPaidForMonth` / `currentPayable`;
/// * `_buildRun` computes `canPay = ent.netDue > 0` (`salaries_screen.dart:161`)
///   and renders `ent.netDue` under `صافي المستحقات` (`:188-192`).
///
/// The cache is not stale. The read model is.
///
/// ## The locked contract
///
/// After a successful offline pay the screen must show the paid state
/// (`تم صرف راتب هذا الشهر`), a payable of `0` (`المتبقي للصرف: 0`), and must
/// not offer the payout again. `netDue` itself stays the gross `5000`; if the
/// gross is still shown it is an entitlement, so it is relabelled
/// `استحقاق الشهر` rather than `صافي المستحقات`.
///
/// Everything below the separator is production: the real `SalariesScreen`, the
/// real `OfflineSalaryRepository` over a real drift store, the real
/// `OfflineWriteCoordinator`, and the real pay sheet driven through its own
/// submit button. Only the server is a fake that is permanently unreachable.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasad_erp/core/error/app_exception.dart';
import 'package:hasad_erp/core/theme/app_theme.dart';
import 'package:hasad_erp/data/offline/local_database.dart';
import 'package:hasad_erp/data/offline/local_store.dart';
import 'package:hasad_erp/data/offline/offline_salary_repository.dart';
import 'package:hasad_erp/data/offline/offline_write.dart';
import 'package:hasad_erp/domain/employees/employee.dart';
import 'package:hasad_erp/domain/salaries/salary_repository.dart';
import 'package:hasad_erp/presentation/providers/employees_providers.dart';
import 'package:hasad_erp/presentation/providers/salaries_providers.dart';
import 'package:hasad_erp/presentation/screens/salaries/salaries_screen.dart';
import 'package:hasad_erp/presentation/widgets/sheet_error_banner.dart';

/// The gross, in agorot. `Money.format(500000)` renders `5000`.
const gross = 500000;
const tenant = 'tenant-a';

void main() {
  late AppDatabase db;
  late DriftLocalStore store;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    store = DriftLocalStore(db);
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
    await store.upsertEmployee(LocalEmployeeRow(
      id: 'e1',
      tenantId: tenant,
      name: 'موظف الاختبار',
      jobTitle: 'sales',
      phone: null,
      baseSalary: gross,
      createdAt: DateTime(2026, 1, 1),
      synced: true,
    ));
  });

  tearDown(() => db.close());

  Future<ProviderContainer> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // The real offline wrapper over an unreachable server, with the real
    // coordinator — so the payout is a genuine local write.
    final repo = OfflineSalaryRepository(
      _UnreachableServer(),
      store: store,
      tenantId: tenant,
      coordinator: OfflineWriteCoordinator(store, tenant),
    );

    final container = ProviderContainer(
      overrides: [
        localStoreProvider.overrideWith((ref) async => store),
        salaryRepositoryProvider.overrideWith((ref) => repo),
        allEmployeesProvider.overrideWith((ref) async => [
              const Employee(
                id: 'e1',
                name: 'موظف الاختبار',
                jobTitle: 'sales',
                phone: null,
                baseSalary: gross,
              ),
            ]),
        // The history table is not what is under test, and offline it would
        // otherwise put the screen into an error state.
        salaryHistoryProvider.overrideWith((ref) async => const []),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light,
        home: const Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: SalariesScreen()),
        ),
      ),
    ));
    // The run card only exists once an employee is selected, and the employee
    // list resolves through a real drift read.
    await settle(tester);
    await tester.tap(find.byType(DropdownButtonFormField<String?>));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('موظف الاختبار').last);
    await settle(tester);
    return container;
  }

  testWidgets('after an offline payout the run card reports it as paid',
      (tester) async {
    await pumpScreen(tester);

    // --- the pre-pay baseline, which already works ---
    //
    // Probes are derived from the rendered label + value pairs, never from a
    // bare amount. The card prints `5000` twice before the payout (gross and
    // payable are equal when unpaid), so `find.text('5000')` would pass no
    // matter which row it matched — and after the relabel it would match the
    // gross alone, reading as a half-fix. The label is what distinguishes them.
    expect(find.text('استحقاق الشهر'), findsOneWidget,
        reason: 'the gross is shown, and labelled as the month\'s entitlement '
            'rather than as a second payable');
    expect(find.text('المتبقي للصرف'), findsOneWidget);
    expect(find.text('تم صرف راتب هذا الشهر'), findsNothing,
        reason: 'precondition: nothing has been paid yet');
    final payButton = find.widgetWithText(FilledButton, 'صرف الراتب');
    expect(payButton, findsOneWidget);
    expect(tester.widget<FilledButton>(payButton).onPressed, isNotNull,
        reason: 'an unpaid month is payable');

    // --- pay, through the real sheet and its own submit button ---
    await tester.tap(payButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.enterText(find.byType(TextFormField).first, '5000');
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'تنفيذ الصرف'));
    await tester.pump();
    await settle(tester);

    // The write landed, and only then does the sheet close on success.
    expect((await store.salaries(tenant)).single.paid, gross,
        reason: 'precondition: the payout is durable');
    expect(find.widgetWithText(ElevatedButton, 'تنفيذ الصرف'), findsNothing,
        reason: 'a successful payout closes the sheet; if it stayed open it '
            'rendered an error banner reading: ${_bannerText(tester)}');

    // --- the defect: the card still presents the month as payable ---
    expect(find.text('تم صرف راتب هذا الشهر'), findsOneWidget,
        reason: 'a month with a durable salary row is paid and must say so');
    expect(find.text('المتبقي للصرف'), findsOneWidget);
    expect(find.text('0'), findsWidgets,
        reason: 'the payable is now 0');
    expect(find.text('5000'), findsWidgets,
        reason: 'the gross survives the payment: netDue is what the month '
            'earned, so zeroing it would be the tempting wrong fix and would '
            'also break the arrears base');
    expect(tester.widget<FilledButton>(payButton).onPressed, isNull,
        reason: 'a paid month must not offer the payout again — canPay is '
            'currently netDue > 0, which a payment never changes');
  });

  testWidgets('forced invalidation of the salary run still shows it payable',
      (tester) async {
    final container = await pumpScreen(tester);

    await OfflineWriteCoordinator(store, tenant).paySalary(
      SalaryDraft(
        employeeId: 'e1',
        month: firstOfMonth(DateTime.now()),
        paid: gross,
        method: 'cash',
        date: DateTime.now(),
      ),
    );
    await settle(tester);

    // Force the read the way a user would expect a refresh to: drop the
    // provider's value and read it again. The exact family key
    // `SalaryActions._refresh` invalidates.
    container.invalidate(salaryRunProvider('e1', firstOfMonth(DateTime.now())));
    final ent = await container.read(
      salaryRunProvider('e1', firstOfMonth(DateTime.now())).future,
    );
    await settle(tester);

    expect(ent.netDue, gross,
        reason: 'the entitlement is unchanged by design — a payment does not '
            'rewrite what the month earned');
    expect(ent.isPaidForMonth, isTrue,
        reason: 'a forced re-read is the last chance to observe the paid state, '
            'so its absence here is the read model, not a stale cache');
  });
}

/// The salary run and the employee list both resolve through real drift work,
/// which cannot complete inside the fake-async zone, so the reads are settled in
/// bounded real-timer rounds rather than with an unbounded `pumpAndSettle`
/// (which the `AppProgress` skeleton would never satisfy anyway). Every
/// assertion is made afterwards against what is on screen, so the bound cannot
/// turn a broken read into a pass.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
  }
  // One long frame so a route transition (the pay sheet's ~300ms exit) can
  // finish. `pumpAndSettle` is not an option: the `SkeletonBox` animation
  // repeats forever. A zero-duration `pump` advances no clock, so without this
  // a dismissed sheet is still in the tree and every "it closed" assertion is a
  // false negative.
  await tester.pump(const Duration(milliseconds: 600));
}

/// The text a still-open sheet is reporting, so a failure says *why* rather than
/// only that something is still on screen. Per the P1.C note, the inline banner
/// is the only observable proof of a submit failure — a SnackBar can be absent
/// and leave the test green.
String _bannerText(WidgetTester tester) {
  final banner = find.byType(SheetErrorBanner);
  if (banner.evaluate().isEmpty) return '(no banner)';
  final texts = find.descendant(of: banner, matching: find.byType(Text));
  final data = texts
      .evaluate()
      .map((e) => (e.widget as Text).data)
      .whereType<String>()
      .toList();
  return data.isEmpty ? '(banner with no text)' : data.join(' | ');
}

/// A server that is not there. Every read throws [NetworkException], which is
/// the state an offline device is in; the write goes local through the
/// coordinator.
class _UnreachableServer implements SalaryRepository {
  @override
  Future<EmployeeEntitlement> entitlement({
    required String employeeId,
    required DateTime month,
  }) async =>
      throw const NetworkException();

  @override
  Future<List<SalaryRecord>> salaryHistory() async =>
      throw const NetworkException();

  @override
  Future<EmployeeStatement> employeeStatement(
    EmployeeStatementRequest request,
  ) async =>
      throw const NetworkException();

  @override
  Future<MovementResult> addMovement(MovementDraft draft) async =>
      throw const NetworkException();

  @override
  Future<SalaryResult> pay(SalaryDraft draft) async =>
      throw const NetworkException();
}
