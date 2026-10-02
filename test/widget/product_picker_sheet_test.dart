import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasad_erp/core/network/connectivity_providers.dart';
import 'package:hasad_erp/core/theme/app_theme.dart';
import 'package:hasad_erp/data/invoices/invoice_repository.dart';
import 'package:hasad_erp/domain/auth/app_role.dart';
import 'package:hasad_erp/domain/auth/app_user.dart';
import 'package:hasad_erp/domain/customers/customer.dart';
import 'package:hasad_erp/domain/customers/customer_draft.dart';
import 'package:hasad_erp/domain/customers/customer_repository.dart';
import 'package:hasad_erp/domain/invoices/invoice.dart';
import 'package:hasad_erp/domain/products/product.dart';
import 'package:hasad_erp/domain/products/product_draft.dart';
import 'package:hasad_erp/domain/products/product_repository.dart';
import 'package:hasad_erp/domain/suppliers/supplier.dart';
import 'package:hasad_erp/domain/suppliers/supplier_draft.dart';
import 'package:hasad_erp/domain/suppliers/supplier_repository.dart';
import 'package:hasad_erp/presentation/providers/auth_providers.dart';
import 'package:hasad_erp/presentation/providers/customers_providers.dart';
import 'package:hasad_erp/presentation/providers/products_providers.dart';
import 'package:hasad_erp/presentation/providers/sales_providers.dart';
import 'package:hasad_erp/presentation/providers/suppliers_providers.dart';
import 'package:hasad_erp/presentation/screens/purchases/purchase_invoices_screen.dart';
import 'package:hasad_erp/presentation/screens/sales/sale_invoices_screen.dart';
import 'package:hasad_erp/presentation/widgets/product_picker_sheet.dart';
import 'package:hasad_erp/presentation/widgets/salary_sheets.dart';

/// Regression: the product picker is a `showModalBottomSheet(isScrollControlled:
/// true)` whose search field is `autofocus: true`, so the keyboard is raised
/// the instant it opens. Its body used to be a fixed
/// `SizedBox(height: MediaQuery.height * 0.7)` wrapping a `Column` — a
/// fraction of the FULL screen height. Once the keyboard covers part of the
/// screen there is no longer room for it, and the height-constrained `Column`
/// reported a BOTTOM OVERFLOW (debug stripe; clipped content in release).
///
/// The keyboard is simulated with `tester.view.viewInsets`, which is exactly
/// what a real keyboard changes: `MediaQuery.size` stays the full screen while
/// `viewInsets.bottom` reports the covered strip. That mismatch is the bug.
///
/// Reached from the sale form, the purchase form, and the salary movement
/// sheet, so all three entry points are pinned here.
const _user = AppUser(
  id: 'u1',
  email: 'admin@test.local',
  name: 'مدير النظام',
  role: AppRole.admin,
  tenantId: 't1',
);

/// Realistic device viewports. The old sweep only varied width at a fixed
/// 900px height, which is why a vertical overflow could never surface.
const _phones = <String, Size>{
  'small Android 360x640': Size(360, 640),
  'iPhone SE 375x667': Size(375, 667),
  'iPhone 14 390x844': Size(390, 844),
  'Pixel 7 412x915': Size(412, 915),
};

const _keyboard = 300.0;

/// `pumpAndSettle` cannot be used once a sheet with an autofocused field is
/// open: the `EditableText` cursor blink reschedules frames forever. Drive the
/// bottom-sheet transition with explicit pumps instead.
Future<void> _pumpSheet(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  for (final phone in _phones.entries) {
    testWidgets(
      'product picker fits the visible area with the keyboard open on ${phone.key}',
      (tester) async {
        tester.view.physicalSize = phone.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          _host(
            Center(
              child: ElevatedButton(
                onPressed: () => showProductPicker(
                  tester.element(find.byType(ElevatedButton)),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byType(ElevatedButton));
        await _pumpSheet(tester);
        expect(find.text('اختيار منتج'), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'sheet while idle');

        // The keyboard its own autofocus field raised.
        tester.view.viewInsets = const FakeViewPadding(bottom: _keyboard);
        await tester.pump();

        expect(
          tester.takeException(),
          isNull,
          reason: 'product picker with the keyboard open on ${phone.key}',
        );
      },
    );
  }

  testWidgets(
    'product picker still opens the product list with the keyboard open',
    (tester) async {
      tester.view.physicalSize = const Size(375, 667);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _host(
          Center(
            child: ElevatedButton(
              onPressed: () => showProductPicker(
                tester.element(find.byType(ElevatedButton)),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(ElevatedButton));
      await _pumpSheet(tester);

      tester.view.viewInsets = const FakeViewPadding(bottom: _keyboard);
      await tester.pump();

      expect(tester.takeException(), isNull);
      // The results list still has room to render products while squeezed.
      expect(find.text('ماسحورة ليزر ملونة للأشعة'), findsOneWidget);
    },
  );

  testWidgets(
    'New Sale Invoice "add item" opens the picker without overflow when the keyboard is open',
    (tester) async {
      tester.view.physicalSize = const Size(375, 667);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_host(const SaleInvoicesScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(find.text('فاتورة بيع جديدة'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'new sale form on open');

      await tester.ensureVisible(find.text('إضافة صنف'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('إضافة صنف'));
      await _pumpSheet(tester);
      expect(find.text('اختيار منتج'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'picker while idle');

      tester.view.viewInsets = const FakeViewPadding(bottom: _keyboard);
      await tester.pump();

      expect(
        tester.takeException(),
        isNull,
        reason: 'sale invoice picker with the keyboard open',
      );
    },
  );

  testWidgets(
    'New Purchase Invoice "add item" opens the picker without overflow when the keyboard is open',
    (tester) async {
      tester.view.physicalSize = const Size(375, 667);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_host(const PurchaseInvoicesScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(find.text('فاتورة شراء جديدة'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'new purchase form on open');

      await tester.ensureVisible(find.text('إضافة صنف'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('إضافة صنف'));
      await _pumpSheet(tester);
      // The purchase form asks existing-vs-new before it opens the picker.
      expect(find.text('منتج موجود'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'line-kind choice sheet');

      await tester.tap(find.text('منتج موجود'));
      await _pumpSheet(tester);
      expect(find.text('اختيار منتج'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'picker while idle');

      tester.view.viewInsets = const FakeViewPadding(bottom: _keyboard);
      await tester.pump();

      expect(
        tester.takeException(),
        isNull,
        reason: 'purchase invoice picker with the keyboard open',
      );
    },
  );

  testWidgets(
    'salary movement sheet opens the picker without overflow when the keyboard is open',
    (tester) async {
      tester.view.physicalSize = const Size(375, 667);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _host(
          Center(
            child: ElevatedButton(
              onPressed: () => showAddMovementSheet(
                tester.element(find.byType(ElevatedButton)),
                employeeId: 'e1',
                employeeName: 'أحمد بن محمد الشامل',
                month: DateTime(2026, 3),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(ElevatedButton));
      await _pumpSheet(tester);
      expect(tester.takeException(), isNull, reason: 'movement sheet on open');

      // The product field only exists for the "product" movement category.
      await tester.tap(
        find.widgetWithText(DropdownButtonFormField<String>, 'سلفة'),
      );
      await _pumpSheet(tester);
      await tester.tap(find.text('منتج').last);
      await _pumpSheet(tester);
      expect(find.text('اختر منتجاً...'), findsOneWidget);

      await tester.tap(find.text('اختر منتجاً...'));
      await _pumpSheet(tester);
      expect(find.text('اختيار منتج'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'picker while idle');

      tester.view.viewInsets = const FakeViewPadding(bottom: _keyboard);
      await tester.pump();

      expect(
        tester.takeException(),
        isNull,
        reason: 'salary sheet picker with the keyboard open',
      );
    },
  );
}

Widget _host(Widget body) {
  return ProviderScope(
    overrides: [
      authStateProvider.overrideWith((ref) => Stream.value(_user)),
      isOnlineProvider.overrideWithValue(true),
      productRepositoryProvider.overrideWithValue(const _FakeProductRepository()),
      invoiceRepositoryProvider.overrideWithValue(const _FakeInvoiceRepository()),
      customerRepositoryProvider.overrideWithValue(const _FakeCustomerRepository()),
      supplierRepositoryProvider.overrideWithValue(const _FakeSupplierRepository()),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: body),
      ),
    ),
  );
}

class _FakeProductRepository implements ProductRepository {
  const _FakeProductRepository();

  @override
  Future<List<Product>> listAll({String? search}) async => [
    const Product(
      id: 'p1',
      name: 'ماسحورة ليزر ملونة للأشعة',
      unit: 'قطعة',
      unitType: ProductUnitType.count,
      salePrice: 450000,
      purchasePrice: 300000,
      qty: 12,
      reorderLevel: 5,
    ),
  ];

  @override
  Future<Product?> getById(String id) async => null;

  @override
  Future<Product> create(ProductDraft draft) => throw UnimplementedError();

  @override
  Future<void> update({required String id, required ProductDraft draft}) =>
      throw UnimplementedError();

  @override
  Future<void> delete(String id) => throw UnimplementedError();
}

class _FakeInvoiceRepository implements InvoiceRepository {
  const _FakeInvoiceRepository();

  @override
  Future<List<Invoice>> list({
    required String type,
    String? search,
    DateTime? from,
    DateTime? to,
  }) async => const [];

  @override
  Future<List<InvoiceItem>> items(String invoiceId) async => const [];

  /// Prefetch API, stubbed to the same empty answer: an empty batch mirrors no
  /// lines, so this sheet suite never depends on invoice detail.
  @override
  Future<InvoiceItemsBatch> itemsForInvoices(List<String> invoiceIds) async =>
      InvoiceItemsBatch(
        items: {for (final id in invoiceIds) id: const <InvoiceItem>[]},
        failed: const {},
      );
}

class _FakeCustomerRepository implements CustomerRepository {
  const _FakeCustomerRepository();

  @override
  Future<List<Customer>> listAll({String? search}) async => [
    const Customer(id: 'c1', name: 'شركة الأمل التجارية المحدودة'),
  ];

  @override
  Future<Customer?> getById(String id) async => null;

  @override
  Future<Customer> create(CustomerDraft draft) => throw UnimplementedError();

  @override
  Future<void> update({required String id, required CustomerDraft draft}) =>
      throw UnimplementedError();

  @override
  Future<void> delete(String id) => throw UnimplementedError();
}

class _FakeSupplierRepository implements SupplierRepository {
  const _FakeSupplierRepository();

  @override
  Future<List<Supplier>> listAll({String? search}) async => [
    const Supplier(
      id: 's1',
      name: 'مؤسسة النور للتوريدات العامة',
      dealType: SupplierDealType.direct,
    ),
  ];

  @override
  Future<Supplier?> getById(String id) async => null;

  @override
  Future<Supplier> create(SupplierDraft draft) => throw UnimplementedError();

  @override
  Future<void> update({required String id, required SupplierDraft draft}) =>
      throw UnimplementedError();

  @override
  Future<void> delete(String id) => throw UnimplementedError();
}
