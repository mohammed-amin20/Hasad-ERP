import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasad_erp/core/theme/app_theme.dart';
import 'package:hasad_erp/data/invoices/invoice_repository.dart';
import 'package:hasad_erp/domain/invoices/invoice.dart';
import 'package:hasad_erp/domain/products/product.dart';
import 'package:hasad_erp/domain/products/product_draft.dart';
import 'package:hasad_erp/domain/products/product_repository.dart';
import 'package:hasad_erp/domain/purchases/purchase_invoice_draft.dart';
import 'package:hasad_erp/domain/purchases/purchase_repository.dart';
import 'package:hasad_erp/domain/suppliers/supplier.dart';
import 'package:hasad_erp/domain/suppliers/supplier_draft.dart';
import 'package:hasad_erp/domain/suppliers/supplier_repository.dart';
import 'package:hasad_erp/presentation/providers/products_providers.dart';
import 'package:hasad_erp/presentation/providers/purchases_providers.dart';
import 'package:hasad_erp/presentation/providers/sales_providers.dart';
import 'package:hasad_erp/presentation/providers/suppliers_providers.dart';
import 'package:hasad_erp/presentation/screens/purchases/purchase_invoices_screen.dart';

/// Ends with the offline-flavoured result, so the list screen must show the
/// "saved locally, syncs later" message instead of a server invoice number.
class _PendingPurchaseRepository implements PurchaseRepository {
  const _PendingPurchaseRepository();

  @override
  Future<PurchaseInvoiceResult> create(PurchaseInvoiceDraft draft) async =>
      const PurchaseInvoiceResult(
        invoiceId: 'pi-pending',
        no: 'PUR-LOCAL',
        total: 300000,
        paid: 0,
        remaining: 300000,
        status: InvoiceStatus.unpaid,
        ownership: InvoiceOwnership.owned,
        entryNo: 0,
        pending: true,
      );
}

class _FakeInvoiceRepository implements InvoiceRepository {
  const _FakeInvoiceRepository();

  @override
  Future<List<Invoice>> list({
    required String type,
    String? search,
    DateTime? from,
    DateTime? to,
  }) async =>
      const [];

  @override
  Future<List<InvoiceItem>> items(String invoiceId) async => const [];
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

Widget _host(Widget body) {
  return ProviderScope(
    overrides: [
      productRepositoryProvider.overrideWithValue(const _FakeProductRepository()),
      invoiceRepositoryProvider.overrideWithValue(const _FakeInvoiceRepository()),
      supplierRepositoryProvider.overrideWithValue(const _FakeSupplierRepository()),
      purchaseRepositoryProvider
          .overrideWithValue(const _PendingPurchaseRepository()),
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

/// `pumpAndSettle` cannot be used once an autofocused sheet is open: the
/// `EditableText` cursor blink reschedules frames forever.
Future<void> _pumpSheet(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  testWidgets(
      'an offline purchase save pops back and shows the sync-later message',
      (tester) async {
    // Tall viewport so the whole form (including the off-fold submit button)
    // is built; the form is a ListView, so out-of-viewport children don't exist
    // in the element tree and cannot be found.
    tester.view.physicalSize = const Size(600, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host(const PurchaseInvoicesScreen()));
    await tester.pumpAndSettle();

    // Open the new-purchase form.
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('فاتورة شراء جديدة'), findsOneWidget);

    // Choose the supplier.
    await tester.tap(
      find.widgetWithText(DropdownButtonFormField<String>, 'المورد'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('مؤسسة النور للتوريدات العامة').last);
    await tester.pumpAndSettle();

    // Add an existing-product line: 'إضافة صنف' -> 'منتج موجود' -> picker.
    await tester.ensureVisible(find.text('إضافة صنف'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('إضافة صنف'));
    await _pumpSheet(tester);
    await tester.tap(find.text('منتج موجود'));
    await _pumpSheet(tester);
    expect(find.text('اختيار منتج'), findsOneWidget);
    await tester.tap(find.text('ماسحورة ليزر ملونة للأشعة'));
    await _pumpSheet(tester);

    // Quantity (count product; price is pre-filled from purchasePrice).
    await tester.enterText(
      find.widgetWithText(TextFormField, 'الكمية'),
      '1',
    );
    await tester.pump();

    // Save: the fake repository reports a queued (pending) write.
    await tester.ensureVisible(find.text('حفظ الفاتورة'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('حفظ الفاتورة'));
    await tester.pumpAndSettle();

    expect(
      find.text('تم حفظ فاتورة الشراء محليًا وستتم مزامنتها عند عودة الاتصال'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}