import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasad_erp/core/theme/app_theme.dart';
import 'package:hasad_erp/domain/salaries/salary_repository.dart';
import 'package:hasad_erp/presentation/providers/salaries_providers.dart';
import 'package:hasad_erp/presentation/widgets/salary_sheets.dart';

/// Deterministic action results so the sheet's SnackBar branches are testable
/// (pending message vs. online confirmation), without touching the repository.
class _FakeSalaryActions extends SalaryActions {
  _FakeSalaryActions({this.movementResult, this.payResult});

  final MovementResult? movementResult;
  final SalaryResult? payResult;

  @override
  Future<MovementResult> movement(MovementDraft draft) async =>
      movementResult ?? const MovementResult();

  @override
  Future<SalaryResult> pay(SalaryDraft draft) async =>
      payResult ?? const SalaryResult();
}

final _sep = DateTime(2026, 9, 1);

final _entitlement = EmployeeEntitlement(
  employeeId: 'e1',
  month: _sep,
  baseSalary: 500000,
  arrears: 0,
  entitlements: 0,
  deductions: 0,
  netDue: 450000,
  isPaidForMonth: false,
);

class _Host extends StatelessWidget {
  const _Host({this.movementResult, this.payResult});

  final MovementResult? movementResult;
  final SalaryResult? payResult;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        salaryActionsProvider.overrideWith(
          () => _FakeSalaryActions(
            movementResult: movementResult,
            payResult: payResult,
          ),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: Center(
              child: Builder(
                builder: (btnContext) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton(
                      onPressed: () => showAddMovementSheet(
                        btnContext,
                        employeeId: 'e1',
                        employeeName: 'موظف',
                        month: DateTime(2026, 9, 1),
                      ),
                      child: const Text('فتح الحركة'),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => showPaySalarySheet(
                        btnContext,
                        employeeId: 'e1',
                        employeeName: 'موظف',
                        month: DateTime(2026, 9, 1),
                        entitlement: _entitlement,
                      ),
                      child: const Text('فتح الصرف'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The modal bottom sheet animates open; pumpAndSettle is safe here because
/// no sheet field autofocuses (no cursor blink), but the two-pump form below
/// is deterministic regardless.
Future<void> _pumpSheet(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  testWidgets(
      'an offline movement save shows the sync-later message',
      (tester) async {
    await tester.pumpWidget(_Host(
      movementResult: MovementResult(movementId: 'm-local', pending: true),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('فتح الحركة'));
    await _pumpSheet(tester);
    expect(find.text('حركة شهرية'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'المبلغ'),
      '1000',
    );
    await _pumpSheet(tester);
    await tester.ensureVisible(find.text('حفظ الحركة'));
    await tester.tap(find.text('حفظ الحركة'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(
      find.text('تم حفظ الحركة محليًا وستتم مزامنتها عند عودة الاتصال'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('an online movement save shows the recorded-amount message',
      (tester) async {
    await tester.pumpWidget(_Host(
      movementResult: MovementResult(
        movementId: 'srv-m1',
        amount: 100000,
        pending: false,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('فتح الحركة'));
    await _pumpSheet(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'المبلغ'),
      '1000',
    );
    await _pumpSheet(tester);
    await tester.ensureVisible(find.text('حفظ الحركة'));
    await tester.tap(find.text('حفظ الحركة'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.textContaining('تم تسجيل الحركة'), findsOneWidget);
    expect(find.textContaining('ستتم مزامنتها'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an offline salary pay shows the sync-later message',
      (tester) async {
    await tester.pumpWidget(_Host(
      payResult: SalaryResult(salaryId: 's-local', pending: true),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('فتح الصرف'));
    await _pumpSheet(tester);
    expect(find.text('صرف الراتب'), findsOneWidget);

    await tester.ensureVisible(find.text('تنفيذ الصرف'));
    await tester.tap(find.text('تنفيذ الصرف'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(
      find.text('تم حفظ عملية الصرف محليًا وستتم مزامنتها عند عودة الاتصال'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('an online salary pay shows the entry-number message',
      (tester) async {
    await tester.pumpWidget(_Host(
      payResult: SalaryResult(
        salaryId: 'srv-s1',
        entryNo: 7,
        paid: 450000,
        pending: false,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('فتح الصرف'));
    await _pumpSheet(tester);
    await tester.ensureVisible(find.text('تنفيذ الصرف'));
    await tester.tap(find.text('تنفيذ الصرف'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.textContaining('تم صرف الراتب'), findsOneWidget);
    expect(find.textContaining('ستتم مزامنتها'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}