import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasad_erp/core/theme/app_theme.dart';
import 'package:hasad_erp/domain/salaries/salary_repository.dart';
import 'package:hasad_erp/presentation/providers/salaries_providers.dart';
import 'package:hasad_erp/presentation/widgets/salary_sheets.dart';
import 'package:hasad_erp/presentation/widgets/sheet_error_banner.dart';

/// Issue 5 — can ONE user interaction cause more than one salary payout?
///
/// ## The structural suspicion
///
/// `_PaySalarySheet._submit` has no imperative re-entrancy guard. The button is
/// `onPressed: _submitting ? null : _submit`, so the ONLY protection is a
/// disabled-button state read at build time. `setState` only marks the element
/// dirty: the button still on screen keeps its live `onPressed` until the next
/// frame rebuilds it. A real `pay` (chart read + drift transaction + enqueue)
/// spans many frames, so a second tap lands long after `_submitting` was set.
///
/// ## Why the duplicate-month guard does NOT answer the question
///
/// `OfflineWriteCoordinator.paySalary` refuses a second payout for the same
/// employee+month by reading `local_salaries`, whose only writer on this device
/// is `paySalary` itself (server salary rows are deliberately not mirrored). So
/// the guard firing proves a local salary row already existed — which is
/// consistent with BOTH a double submit AND one earlier successful attempt in
/// the same session. Only an invocation counter separates them, which is why
/// this suite counts `SalaryRepository.pay()` entries rather than reading the
/// Arabic error the guard produces.
///
/// ## The race is produced deterministically, not by timing
///
/// `tester.tap` dispatches pointer events WITHOUT building a frame. Two
/// consecutive taps with nothing between them are therefore two taps inside a
/// single frame — the device condition, with none of real timing's flakiness.
/// The fake `pay` stays pending until time is pumped, so the first invocation
/// is guaranteed to still be in flight when the second arrives.
void main() {
  /// Real `SalaryActions` + real `_PaySalarySheet`; only the repository is
  /// substituted, so the code under test is the production submit path.
  ///
  /// **No `container.listen(salaryActionsProvider)` here, deliberately.** An
  /// earlier revision held one open with a comment claiming it was load-bearing.
  /// It was — but for the wrong reason. `SalaryActions` was autoDispose and the
  /// sheet only `read`s it, so Riverpod disposed the notifier between the
  /// `await` and `_refresh`, and the sheet reported `UnmountedRefException` as
  /// the generic `حدث خطأ غير متوقع` banner. The listener papered over a real
  /// defect. The fix is `@Riverpod(keepAlive: true)` on the dispatcher.
  ///
  /// **How that stays proven, which is not obvious:** the sheet's own `catch`
  /// swallows the exception and renders it as a `SheetErrorBanner`, and
  /// `tester.takeException()` is `null` either way — so a plain "did it pay
  /// once?" assertion passes *with the defect present*. Verified by mutation:
  /// reverting `keepAlive` leaves `payCalls == 1` green. The
  /// `SheetErrorBanner` assertion below is the only thing that fails, which is
  /// why it is there. If you re-add a listener here, delete that assertion and
  /// the lifecycle regression becomes invisible again.
  Future<ProviderContainer> openSheet(
    WidgetTester tester,
    _CountingSalaryRepository repo,
  ) async {
    final container = ProviderContainer(
      overrides: [salaryRepositoryProvider.overrideWith((ref) => repo)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light,
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: const Scaffold(body: _PayLauncher()),
        ),
      ),
    ));
    await tester.pump();
    // Sheet entrance animation. No autofocused field, so this settles.
    await tester.pump(const Duration(milliseconds: 600));
    return container;
  }

  Finder submitButton() =>
      find.widgetWithText(ElevatedButton, 'تنفيذ الصرف');

  testWidgets('BASELINE: a single tap reaches pay exactly once', (tester) async {
    final repo = _CountingSalaryRepository();
    await openSheet(tester, repo);

    await tester.enterText(find.byType(TextFormField).first, '5000');
    await tester.pump();

    expect(submitButton(), findsOneWidget);
    await tester.tap(submitButton());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // This must hold whatever the race verdict turns out to be — it is what
    // makes a count above 1 attributable to the second tap.
    expect(repo.payCalls, 1);
    expect(tester.takeException(), isNull);

    // The repository succeeded, so a banner here is NOT about the input: it is
    // `_refresh` throwing AFTER the await. With `SalaryActions` autoDispose (no
    // `keepAlive`) the notifier is disposed between the two, `ref.invalidate`
    // throws `UnmountedRefException`, and the sheet's own `catch` turns it into
    // this banner — so the write lands and the user is told it failed.
    // `takeException()` is null either way, which is exactly why asserting the
    // banner is the only way this suite proves the lifecycle fix.
    expect(find.byType(SheetErrorBanner), findsNothing,
        reason: 'a successful write must not surface a post-await failure');
  });

  testWidgets(
      'two taps without a pump must not pay twice: the submit needs an '
      'imperative re-entrancy guard', (tester) async {
    final repo = _CountingSalaryRepository();
    await openSheet(tester, repo);

    await tester.enterText(find.byType(TextFormField).first, '5000');
    await tester.pump();

    expect(submitButton(), findsOneWidget);

    // NO pump between the taps. The first tap only marks the element dirty; the
    // button the user is still looking at remains enabled, which is exactly
    // the window the second tap exploits on a device.
    await tester.tap(submitButton());
    await tester.tap(submitButton());

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // A second entry into the write path is the defect. `OfflineWriteCoordinator`
    // would then decide the outcome via its duplicate-month guard, so the user
    // sees a rejection for a payout they only ever asked for once.
    expect(repo.payCalls, 1,
        reason: 'one user intent must enter the salary write path once');
  });

  testWidgets(
      'a sheet opened before the month was paid refuses to pay an already-paid '
      'month', (tester) async {
    // The stale-snapshot window, and the one the duplicate-month guard cannot
    // close.
    //
    // The sheet is opened while the month is unpaid, so every figure it shows
    // is correct at that instant. The month is then paid — by another window,
    // another device, or a drain landing in between — and the user taps submit
    // on a sheet that never saw it happen.
    //
    // `OfflineWriteCoordinator.paySalary` inspects `local_salaries`, which is
    // this device's own mirror. So on a device whose mirror was cleared, or one
    // that has been offline, the guard has nothing to find and would happily
    // queue a second payout for a month the server already holds. The only
    // thing standing there is `SalaryActions.pay` re-reading the live
    // entitlement first.
    //
    // Proven by counting `pay` entries, as above: the repository is never
    // reached, so this is not "the write was refused" but "the write was never
    // attempted".
    final repo = _CountingSalaryRepository(entitlementPaid: false);
    await openSheet(tester, repo);

    await tester.enterText(find.byType(TextFormField).first, '5000');
    await tester.pump();

    // The month is paid by someone else while the sheet sits open.
    repo.entitlementPaid = true;

    await tester.tap(submitButton());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(repo.payCalls, 0,
        reason: 'a payout for an already-paid month must never reach the write '
            'path — queueing it would restate the salary on the server');
    expect(find.byType(SheetErrorBanner), findsOneWidget,
        reason: 'the only observable proof of a submit failure is the inline '
            'banner, per the P1.C note; a SnackBar can be absent and leave the '
            'test green');
    expect(
      find.descendant(
        of: find.byType(SheetErrorBanner),
        matching: find.text('تم صرف راتب هذا الشهر مسبقاً'),
      ),
      findsOneWidget,
      reason: 'the user is told the month is already paid, in the same words '
          'the write-side guard uses, instead of a server validation error',
    );
  });
}

/// Counts entries into the repository. A count of 2 means the production write
/// path was entered twice — not that a double was simulated.
class _CountingSalaryRepository implements SalaryRepository {
  _CountingSalaryRepository({this.entitlementPaid = false});

  int payCalls = 0;

  /// Mutable so a test can change what the read model reports *after* the sheet
  /// has already read it — which is the whole point of the stale-sheet case.
  /// It is a field rather than a fixed stub because a repository whose answer
  /// never changes cannot express "the state moved while the sheet was open".
  bool entitlementPaid;

  @override
  Future<SalaryResult> pay(SalaryDraft draft) async {
    payCalls++;
    // Stays pending until time is pumped, so invocation 2 lands while
    // invocation 1 is still in flight.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    return const SalaryResult(duplicate: false, pending: true, entryNo: 1);
  }

  @override
  Future<MovementResult> addMovement(MovementDraft draft) async =>
      const MovementResult(movementId: 'm1', amount: 0, pending: true);

  @override
  Future<EmployeeEntitlement> entitlement({
    required String employeeId,
    required DateTime month,
  }) async =>
      EmployeeEntitlement(
        employeeId: employeeId,
        month: month,
        baseSalary: 500000,
        arrears: 0,
        entitlements: 0,
        deductions: 0,
        netDue: 500000,
        // Deliberately `currentPayable`-consistent rather than hardcoded 0: the
        // guard reads this flag, and a stub that reported paid while still
        // showing a full payable would be an impossible state.
        isPaidForMonth: entitlementPaid,
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

/// Opens the real pay sheet on mount, the way the salaries screen does.
///
/// Stateful and one-shot for the reason proven in `offline_payment_sheet_test`:
/// a `ConsumerWidget` launcher rebuilds when a provider it watches is
/// invalidated, and `SalaryActions._refresh` invalidates four. A stateless
/// launcher that re-ran its `addPostFrameCallback` would open a SECOND sheet on
/// top of the first, so a test that counts writes would be counting the wrong
/// thing. `_opened` is the fix; do not simplify this back to a `ConsumerWidget`.
class _PayLauncher extends ConsumerStatefulWidget {
  const _PayLauncher();

  @override
  ConsumerState<_PayLauncher> createState() => _PayLauncherState();
}

class _PayLauncherState extends ConsumerState<_PayLauncher> {
  bool _opened = false;

  @override
  Widget build(BuildContext context) {
    if (!_opened) {
      _opened = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showPaySalarySheet(
          context,
          employeeId: 'e1',
          employeeName: 'موظف الاختبار',
          month: DateTime(2026, 3, 1),
          entitlement: EmployeeEntitlement(
            employeeId: 'e1',
            month: DateTime(2026, 3),
            baseSalary: 500000,
            arrears: 0,
            entitlements: 0,
            deductions: 0,
            netDue: 500000,
            isPaidForMonth: false,
          ),
        );
      });
    }
    return const SizedBox.shrink();
  }
}
