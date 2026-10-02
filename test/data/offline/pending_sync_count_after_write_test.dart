import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasad_erp/domain/payments/payment_repository.dart';
import 'package:hasad_erp/domain/salaries/salary_repository.dart';
import 'package:hasad_erp/presentation/providers/offline_sync_providers.dart';
import 'package:hasad_erp/presentation/providers/payments_providers.dart';
import 'package:hasad_erp/presentation/providers/salaries_providers.dart';

/// Issue 5, second half: a write that lands in the local queue must move the
/// app-wide pending count — for all four money/movement paths, and only then.
///
/// ## Why the count needs an explicit trigger
///
/// `pendingSyncCountProvider` is a one-shot `FutureProvider` over the sync queue
/// with no self-polling. The screen-side `refreshAfterLocalInvoiceWrite` covers
/// invoice writes, but the four action dispatchers had no equivalent, so after
/// an offline payment the app kept reporting "0 pending" until a drain
/// corrected it. Same defect Phase 2 P2 fixed for invoices, on the other four
/// writes.
///
/// ## How this observes the invalidation, and why that was not the first try
///
/// The count is observed by **re-running the provider's factory**, not by
/// reading its value. Two alternatives both look right and prove nothing:
///
///  * The value stays 0 either way here, because the stubbed repositories
///    enqueue nothing. So a value assertion passes against a dispatcher that
///    invalidates unconditionally, which is the mistake being guarded against.
///  * Counting listener emissions fails for a second reason: an invalidation
///    drives a `FutureProvider` through a nested async rebuild, and consecutive
///    invalidations coalesce. Pumping after every call still measured **2
///    emissions for 4 writes** — which reads as "only two paths invalidate"
///    when it really means the rebuilds merged. Anything built on emission
///    counts is measuring Riverpod's scheduler, not this code.
///
/// A counting override measures the one thing that is actually being asked:
/// was this provider invalidated by this call?
///
/// ## Why the repository is stubbed
///
/// The line under test is `if (pending) ref.invalidate(...)` in each
/// dispatcher. The real coordinator always enqueues, so driving it would make
/// the `pending: false` branch unreachable and there would be no way to prove
/// the gate is a gate. The real write path — a queued leg taking the count
/// 0 → 1 — is covered end-to-end in `offline_payment_sheet_test.dart`.
void main() {
  const employee = 'e1';
  final march = DateTime(2026, 3, 1);

  late int builds;
  ProviderSubscription<AsyncValue<int>>? held;

  setUp(() => builds = 0);

  tearDown(() => held?.close());

  Future<ProviderContainer> open({required bool pending}) async {
    final container = ProviderContainer(
      overrides: [
        // The probe. Re-running this factory IS the invalidation.
        pendingSyncCountProvider.overrideWith((ref) async => ++builds),
        paymentRepositoryProvider
            .overrideWith((ref) => _StubPaymentRepository(pending: pending)),
        salaryRepositoryProvider
            .overrideWith((ref) => _StubSalaryRepository(pending: pending)),
      ],
    );
    addTearDown(container.dispose);
    // Held so the autoDispose provider is not torn down between reads. Without
    // it, every access is also a fresh build and `builds` counts accesses.
    held = container.listen<AsyncValue<int>>(pendingSyncCountProvider, (_, _) {});
    await container.read(pendingSyncCountProvider.future);
    expect(builds, 1, reason: 'only the initial build so far');
    return container;
  }

  /// The four action calls, in one place so the drafts cannot drift apart
  /// between paths and so a count of 4 is attributable to 4 independent calls.
  ///
  /// Reading the future after each call is required, not tidy. An invalidation
  /// marks the provider dirty; the rebuild happens on the next **read**. Four
  /// writes followed by one read coalesce into a single rebuild, so the test
  /// measured 2 builds (1 initial + 1) and read as "only one path invalidates".
  /// Each path does invalidate — proven by driving them one at a time, where
  /// every one produced exactly 1 build.
  Future<void> writeAll(ProviderContainer container) async {
    final payments = container.read(paymentActionsProvider.notifier);
    await payments.record(
        PaymentDraft(invoiceId: 'inv-1', amount: 1000, method: 'cash'));
    await container.read(pendingSyncCountProvider.future);
    await payments.settle(SettlementDraft(
        supplierId: 's1', amount: 1000, method: 'cash'));
    await container.read(pendingSyncCountProvider.future);
    final salaries = container.read(salaryActionsProvider.notifier);
    await salaries.movement(MovementDraft(
      employeeId: employee,
      month: march,
      direction: 'in',
      category: 'bonus',
      amount: 1000,
    ));
    await container.read(pendingSyncCountProvider.future);
    await salaries.pay(SalaryDraft(
        employeeId: employee, month: march, paid: 1000, method: 'cash'));
    await container.read(pendingSyncCountProvider.future);
  }

  test('an enqueued payment, settlement, movement and salary each invalidate '
      'the pending count', () async {
    final container = await open(pending: true);
    final before = builds;

    await writeAll(container);

    expect(builds, before + 4);
  });

  test('a write that reached the server invalidates nothing, so churning the '
      'provider is pure cost', () async {
    final container = await open(pending: false);
    final before = builds;

    await writeAll(container);

    expect(builds, before,
        reason: 'a non-enqueued write must not invalidate the pending count');
  });
}

/// Reports a fixed `pending` so both branches of the gate are reachable. A real
/// coordinator always enqueues, so it cannot express "reached the server".
class _StubPaymentRepository implements PaymentRepository {
  _StubPaymentRepository({required this.pending});

  final bool pending;

  @override
  Future<PaymentResult> record(PaymentDraft draft) async => PaymentResult(
      paymentId: 'p1', invoiceId: draft.invoiceId, pending: pending);

  @override
  Future<SettlementResult> settle(SettlementDraft draft) async =>
      SettlementResult(pending: pending);
}

class _StubSalaryRepository implements SalaryRepository {
  _StubSalaryRepository({required this.pending});

  final bool pending;

  @override
  Future<MovementResult> addMovement(MovementDraft draft) async =>
      MovementResult(movementId: 'm1', amount: 0, pending: pending);

  @override
  Future<SalaryResult> pay(SalaryDraft draft) async => SalaryResult(
      salaryId: 's1', month: draft.month, paid: draft.paid, pending: pending);

  @override
  Future<EmployeeEntitlement> entitlement({
    required String employeeId,
    required DateTime month,
  }) async =>
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

  @override
  Future<List<SalaryRecord>> salaryHistory() async => const <SalaryRecord>[];

  @override
  Future<EmployeeStatement> employeeStatement(
          EmployeeStatementRequest request) async =>
      EmployeeStatement(
        employeeId: request.employeeId,
        monthFrom: DateTime(request.from.year, request.from.month),
        monthTo: request.to,
        opening: 0,
        lines: const <EmployeeMonthLine>[],
        closing: 0,
      );
}
