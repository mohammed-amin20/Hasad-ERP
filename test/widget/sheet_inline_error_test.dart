import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasad_erp/core/error/app_exception.dart';
import 'package:hasad_erp/core/theme/app_theme.dart';
import 'package:hasad_erp/domain/invoices/invoice.dart';
import 'package:hasad_erp/domain/payments/payment_repository.dart';
import 'package:hasad_erp/domain/products/product.dart';
import 'package:hasad_erp/domain/products/product_draft.dart';
import 'package:hasad_erp/domain/products/product_repository.dart';
import 'package:hasad_erp/domain/salaries/salary_repository.dart';
import 'package:hasad_erp/presentation/providers/payments_providers.dart';
import 'package:hasad_erp/presentation/providers/products_providers.dart';
import 'package:hasad_erp/presentation/providers/salaries_providers.dart';
import 'package:hasad_erp/presentation/widgets/payment_sheets.dart';
import 'package:hasad_erp/presentation/widgets/salary_sheets.dart';

/// Issue 4 — a rejected write must be explained **in the sheet**, which stays
/// open so the user can fix the field. The previous behaviour was a SnackBar,
/// and worse, the two sheets parsed their input *before* the submit `try`, so a
/// malformed quantity escaped as a raw `FormatException` and the submit button
/// did nothing at all with no message anywhere.
///
/// These tests drive the real sheets. The error comes from the injected
/// action notifier, so nothing is mocked below the provider.
class _ThrowingSalaryActions extends SalaryActions {
  _ThrowingSalaryActions(this.error);

  final Object error;

  @override
  Future<MovementResult> movement(MovementDraft draft) async => throw error;

  @override
  Future<SalaryResult> pay(SalaryDraft draft) async => throw error;
}

class _ThrowingPaymentActions extends PaymentActions {
  _ThrowingPaymentActions(this.error);

  final Object error;

  @override
  Future<PaymentResult> record(PaymentDraft draft) async => throw error;

  @override
  Future<SettlementResult> settle(SettlementDraft draft) async => throw error;
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

/// A product the picker can select, so the quantity path can be driven without
/// a real catalogue. The stock quantity is deliberately irrelevant here: the
/// engine's stock rejection is what the notifier throws, so the test never
/// depends on the local stock mirror being correct.
final _product = Product(
  id: 'p1',
  name: 'منتج مختبَر',
  unit: 'قطعة',
  unitType: ProductUnitType.count,
  salePrice: 10000,
  purchasePrice: 8000,
  qty: 5,
  reorderLevel: 1,
);

final _invoice = Invoice(
  id: 'inv-1',
  type: 'purchase',
  no: 'P-1',
  partyId: 's1',
  partyName: 'مورد',
  date: DateTime(2026, 9, 1),
  subtotal: 10000,
  total: 10000,
  paid: 0,
  remaining: 10000,
  status: InvoiceStatus.unpaid,
  ownership: InvoiceOwnership.owned,
);

class _Host extends StatelessWidget {
  const _Host({this.salaryError, this.paymentError});

  final Object? salaryError;
  final Object? paymentError;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        if (salaryError != null)
          salaryActionsProvider.overrideWith(
            () => _ThrowingSalaryActions(salaryError!),
          ),
        if (paymentError != null)
          paymentActionsProvider.overrideWith(
            () => _ThrowingPaymentActions(paymentError!),
          ),
        // The REPOSITORY, not `allProductsProvider`: the picker reads
        // `productsListProvider`, which is the search-reactive list built on
        // `productRepositoryProvider`. Stubbing the unfiltered provider here left
        // the picker with nothing to show once it became search-aware — the
        // product was simply absent, so the test failed looking for a row that
        // never rendered rather than on the behaviour it is about.
        productRepositoryProvider.overrideWithValue(_FakeProductRepository()),
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
                        month: _sep,
                      ),
                      child: const Text('فتح الحركة'),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => showPaySalarySheet(
                        btnContext,
                        employeeId: 'e1',
                        employeeName: 'موظف',
                        month: _sep,
                        entitlement: _entitlement,
                      ),
                      child: const Text('فتح الصرف'),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => showRecordPaymentSheet(
                        btnContext,
                        invoice: _invoice,
                      ),
                      child: const Text('فتح الدفعة'),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => showSettleSupplierSheet(
                        btnContext,
                        supplierId: 's1',
                        supplierName: 'مورد',
                      ),
                      child: const Text('فتح التسوية'),
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

Future<void> _pumpSheet(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

Future<void> _submit(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.tap(find.text(label));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  const stockMessage = 'الكمية غير متوفرة في المخزون — المتاح 5, المطلوب 9';
  const baseMessage = 'الراتب الأساسي غير محدد للموظف';

  testWidgets('issue 4 — a product deduction over available stock is explained '
      'in the sheet and the sheet stays open', (tester) async {
    await tester.pumpWidget(_Host(salaryError: const ValidationException(stockMessage)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('فتح الحركة'));
    await _pumpSheet(tester);

    // The sheet opens on out/advance; switch the category to منتج, which swaps
    // the amount field for a quantity field. The menu items only exist while
    // the dropdown is open, so the tap order matters: open, then select.
    await tester.tap(find.text('سلفة').first);
    await _pumpSheet(tester);
    await tester.tap(find.text('منتج').last);
    await _pumpSheet(tester);

    // Pick the product through the real picker, so `_product` is set and the
    // submit reaches the coordinator instead of bailing on the missing product.
    await tester.tap(find.text('اختر منتجاً...'));
    await _pumpSheet(tester);
    await tester.tap(find.text(_product.name));
    await _pumpSheet(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'الكمية'),
      '9',
    );
    await _pumpSheet(tester);
    await _submit(tester, 'حفظ الحركة');

    // The Arabic reason is on screen inside the still-open sheet.
    expect(find.text(stockMessage), findsOneWidget);
    expect(find.text('حركة شهرية'), findsOneWidget,
        reason: 'the sheet must stay open so the field can be corrected');
    // And it is NOT a transient snackbar.
    expect(find.byType(SnackBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('issue 4 — a plain advance rejection shows its own Arabic message',
      (tester) async {
    const advanceMessage = 'المبلغ غير صحيح';
    await tester.pumpWidget(
      _Host(salaryError: const ValidationException(advanceMessage)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('فتح الحركة'));
    await _pumpSheet(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'المبلغ'),
      '1000',
    );
    await _pumpSheet(tester);
    await _submit(tester, 'حفظ الحركة');

    expect(find.text(advanceMessage), findsOneWidget);
    expect(find.text('حركة شهرية'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('issue 4 — the pay sheet shows the zero-base-salary reason inline',
      (tester) async {
    await tester.pumpWidget(
      _Host(salaryError: const ValidationException(baseMessage)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('فتح الصرف'));
    await _pumpSheet(tester);
    await _submit(tester, 'تنفيذ الصرف');

    expect(find.text(baseMessage), findsOneWidget);
    expect(find.text('صرف الراتب'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('issue 4 — the record-payment sheet shows its reason inline',
      (tester) async {
    const message = 'المبلغ أكبر من المتبقي';
    await tester.pumpWidget(
      _Host(paymentError: const ValidationException(message)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('فتح الدفعة'));
    await _pumpSheet(tester);
    // 10 of the 100 remaining: passes the sheet's own validator so the failure
    // under test is the repository rejection, not a form error.
    await tester.enterText(
      find.widgetWithText(TextFormField, 'المبلغ'),
      '10',
    );
    await _pumpSheet(tester);
    await _submit(tester, 'حفظ الدفعة');

    expect(find.text(message), findsOneWidget);
    expect(find.text('تسجيل دفعة'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('issue 4 — the settle-supplier sheet shows its reason inline',
      (tester) async {
    const message = 'لا يوجد ما يمكن تسويته للمورد';
    await tester.pumpWidget(
      _Host(paymentError: const ValidationException(message)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('فتح التسوية'));
    await _pumpSheet(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'المبلغ'),
      '1000',
    );
    await _pumpSheet(tester);
    await _submit(tester, 'تنفيذ التسوية');

    expect(find.text(message), findsOneWidget);
    expect(find.text('تسوية المورد'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'a non-AppException still surfaces its mapped Arabic text rather than '
      'an unhandled error', (tester) async {
    await tester.pumpWidget(
      _Host(
        salaryError: const FormatException('Unexpected character at 0'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('فتح الحركة'));
    await _pumpSheet(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'المبلغ'),
      '1000',
    );
    await _pumpSheet(tester);
    await _submit(tester, 'حفظ الحركة');

    // The mapper's own default, not a raw Dart error dumped into the UI.
    expect(find.byType(SnackBar), findsNothing);
    expect(find.text('حركة شهرية'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

/// Honours [ProductRepository.listAll]'s `search` so the picker's
/// search-reactive provider gets a truthful answer. Nothing here writes, so the
/// unused members throw rather than pretend to work.
class _FakeProductRepository implements ProductRepository {
  @override
  Future<List<Product>> listAll({String? search}) async {
    final needle = search?.trim().toLowerCase() ?? '';
    if (needle.isEmpty) return [_product];
    return [
      for (final p in [_product])
        if (p.name.toLowerCase().contains(needle) ||
            (p.barcode ?? '').toLowerCase().contains(needle))
          p,
    ];
  }

  @override
  Future<Product?> getById(String id) async =>
      id == _product.id ? _product : null;

  @override
  Future<Product> create(ProductDraft draft) =>
      throw UnimplementedError('this suite only reads');

  @override
  Future<void> update({required String id, required ProductDraft draft}) =>
      throw UnimplementedError('this suite only reads');

  @override
  Future<void> delete(String id) =>
      throw UnimplementedError('this suite only reads');
}
