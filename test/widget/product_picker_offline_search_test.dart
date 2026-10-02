/// **FAILURE B — offline product search in the invoice product picker, plus the
/// duplicate-selection behaviour that must NOT change.**
///
/// ## The defect (B1): the picker's search box is inert
///
/// `product_picker_sheet.dart` watched `allProductsProvider`, which is
/// documented as "Full unfiltered product list (for pickers/dropdowns), never
/// search-filtered" and calls `listAll()` with **no** `search:` argument. The
/// `TextField`'s `onChanged` writes `productSearchProvider` — which nothing in
/// the picker's build path read. `productsListProvider` was the only provider
/// that watches the search term.
///
/// So the sheet showed the same unfiltered list whatever the user typed, online
/// and offline alike. B1 pins that the typed term must actually filter.
///
/// **The fix is the one-line swap to `productsListProvider`**, and that is the
/// entire change: `allProductsProvider` has exactly one consumer (this picker),
/// `products_screen.dart` already used `productsListProvider`, and the sheet
/// already owned the `productSearchProvider` write and its own
/// `TextEditingController`. The restore-safe fact this relies on — that the
/// search term does not survive a close/reopen — is NOT assumed: B1.3 pins it,
/// because `productSearchProvider` is auto-dispose and the picker's own field is
/// rebuilt empty on every open.
///
/// ## Why the existing fake could never catch it
///
/// `test/widget/product_picker_sheet_test.dart`'s `_FakeProductRepository`
/// returns a fixed one-element list and ignores `search`, so both providers
/// answer the same thing and the picker looks correct. The fake here records the
/// `search` arguments it receives, which is what makes the wiring difference
/// observable.
///
/// ## B2/B3 are CHARACTERIZATION, not defects
///
/// Selecting the same product twice on one draft currently appends two
/// independent lines (Sale pre-fills `salePrice`, Purchase pre-fills
/// `purchasePrice`). That is the shipped behaviour and it is pinned here so a
/// future fix for B1 cannot quietly change it into a merge or an exclusion.
/// **No `excludeIds` is asserted in either direction** — the product sheet's
/// only contract is "return the selected `Product`".
///
/// ## B4 is the honest part of the answer to CASE 2
///
/// A product that exists in `local_products` **is** searchable offline, and
/// `writeSale` can reference it. A product that appears only as a historical
/// `InvoiceItem` is **not** a selectable product and must not become one:
/// `InvoiceItem` has no barcode, no separate sale/purchase price, no
/// `reorderLevel`, no `supplierId`, no `commissionRate`, and its `qty` is the
/// transaction quantity rather than stock. Rebuilding `Product` rows from those
/// would invent a purchase price and could silently drop consignment
/// attribution, so the picker must report insufficiency instead.
library;

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
import 'package:hasad_erp/presentation/widgets/invoice_input_fields.dart';

const _user = AppUser(
  id: 'u1',
  email: 'admin@test.local',
  name: 'مدير النظام',
  role: AppRole.admin,
  tenantId: 't1',
);

const _apple = Product(
  id: 'p-apple',
  name: 'تفاح أحمر',
  unit: 'كرتونة',
  unitType: ProductUnitType.count,
  salePrice: 25000,
  purchasePrice: 18000,
  qty: 40,
  reorderLevel: 5,
);

const _banana = Product(
  id: 'p-banana',
  name: 'موز',
  unit: 'كرتونة',
  unitType: ProductUnitType.count,
  salePrice: 30000,
  purchasePrice: 22000,
  qty: 25,
  reorderLevel: 5,
);

/// `pumpAndSettle` cannot be used once the sheet's autofocused field is open —
/// the `EditableText` cursor blink reschedules frames forever.
Future<void> _pumpSheet(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

/// Records every `search:` the picker actually asks for, which is the only way
/// to see WHICH provider the sheet reads.
class _RecordingProducts implements ProductRepository {
  final List<String?> searchCalls = <String?>[];
  final List<Product> catalog;

  _RecordingProducts(this.catalog);

  @override
  Future<List<Product>> listAll({String? search}) async {
    searchCalls.add(search);
    final term = (search ?? '').trim();
    if (term.isEmpty) return catalog;
    return [
      for (final p in catalog)
        if (p.name.contains(term) || p.barcode == term) p,
    ];
  }

  @override
  Future<Product?> getById(String id) async {
    for (final p in catalog) {
      if (p.id == id) return p;
    }
    return null;
  }

  @override
  Future<Product> create(ProductDraft draft) => throw UnimplementedError();

  @override
  Future<void> update({required String id, required ProductDraft draft}) =>
      throw UnimplementedError();

  @override
  Future<void> delete(String id) => throw UnimplementedError();
}

void main() {
  group('B1. the picker search box must actually filter', () {
    testWidgets('typing a term narrows the picker list to that product', (
      tester,
    ) async {
      final products = _RecordingProducts(const [_apple, _banana]);

      await tester.pumpWidget(_host(products, const SaleInvoicesScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('إضافة صنف'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('إضافة صنف'));
      await _pumpSheet(tester);
      expect(find.text('اختيار منتج'), findsOneWidget);

      // Both products are listed before any search.
      expect(find.text('تفاح أحمر'), findsOneWidget);
      expect(find.text('موز'), findsOneWidget);

      await tester.enterText(find.byType(TextField).last, 'موز');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(
        find.text('موز'),
        findsWidgets,
        reason: 'the typed term must still match its own product',
      );
      expect(
        find.text('تفاح أحمر'),
        findsNothing,
        reason:
            'B1: the typed term must reach the repository the picker actually '
            'reads — the sheet watches the filtered list, not the unfiltered '
            'allProductsProvider, so the full list cannot stay on screen',
      );
      expect(
        products.searchCalls.where((s) => s != null),
        isNotEmpty,
        reason:
            'the picker must actually ask the repository for a filtered '
            'list — an in-widget filter would also satisfy the two assertions '
            'above, so the read is pinned too',
      );
    });

    testWidgets('the same search must work with no network at all', (
      tester,
    ) async {
      // Same repository, but connectivity is offline and the repository
      // answers only from its local mirror — the real offline shape.
      final products = _RecordingProducts(const [_apple, _banana]);

      await tester.pumpWidget(
        _host(products, const SaleInvoicesScreen(), online: false),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('إضافة صنف'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('إضافة صنف'));
      await _pumpSheet(tester);

      await tester.enterText(find.byType(TextField).last, 'تفاح');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('تفاح أحمر'), findsOneWidget);
      expect(
        find.text('موز'),
        findsNothing,
        reason:
            'offline search is the reported failure; the online case above '
            'proves the wiring is broken in both states, not just offline',
      );
    });

    testWidgets(
      'B1.3: closing and reopening the picker does NOT carry the last term '
      'over — the search provider is auto-dispose',
      (tester) async {
        tester.view.physicalSize = const Size(600, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final products = _RecordingProducts(const [_apple, _banana]);
        await tester.pumpWidget(_host(products, const SaleInvoicesScreen()));
        await tester.pumpAndSettle();

        // Reaches the sale form from the list, once.
        await tester.tap(find.byType(FloatingActionButton));
        await tester.pumpAndSettle();

        Future<void> openPicker() async {
          // The form route stays pushed under the sheet, so the picker is
          // re-entered from the form — the FAB belongs to the list beneath it
          // and is not tappable while the route is up.
          await tester.ensureVisible(find.text('إضافة صنف'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('إضافة صنف'));
          await _pumpSheet(tester);
        }

        await openPicker();

        // Narrow to one product.
        await tester.enterText(find.byType(TextField).last, 'تفاح');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        expect(find.text('موز'), findsNothing);

        // Close without clearing the term (no backspace, no clear button).
        await tester.tapAt(const Offset(10, 10));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        expect(find.text('اختيار منتج'), findsNothing, reason: 'sheet closed');

        await openPicker();
        expect(
          find.text('تفاح أحمر'),
          findsOneWidget,
          reason: 'the full catalog is available again on a fresh open',
        );
        expect(
          find.text('موز'),
          findsOneWidget,
          reason:
              'THE POINT: a stale search term would still be hiding موز. '
              '`productSearchProvider` is auto-dispose, so closing the sheet '
              'releases the last listener and the term is dropped on the next '
              'open — proven here, not assumed, because a picker that kept the '
              'term would look like a broken catalog',
        );
        expect(
          products.searchCalls.last?.trim(),
          anyOf(isNull, isEmpty),
          reason:
              'and the repository was asked for the UNFILTERED list, which is '
              'the read-level half of the same claim',
        );
      },
    );
  });

  group('B2/B3. duplicate selection is shipped behaviour (characterization)', () {
    testWidgets('Sale: picking the same product twice yields two independent '
        'lines, each pre-filled with salePrice', (tester) async {
      tester.view.physicalSize = const Size(600, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final products = _RecordingProducts(const [_apple, _banana]);
      await tester.pumpWidget(_host(products, const SaleInvoicesScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      for (var i = 0; i < 2; i++) {
        await tester.ensureVisible(find.text('إضافة صنف'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('إضافة صنف'));
        await _pumpSheet(tester);
        // Scoped to the sheet's own ListView: after the first pick the draft
        // behind the sheet already shows a row with the same product name, so a
        // bare `find.text` would be ambiguous and `tap()` would throw.
        await tester.tap(
          find.descendant(
            of: find.byType(ListView).last,
            matching: find.text('تفاح أحمر'),
          ),
        );
        await tester.pumpAndSettle();
      }

      expect(
        find.text('تفاح أحمر'),
        findsNWidgets(2),
        reason:
            'B2: _addLine appends unconditionally — there is no '
            'excludeIds and no merge-on-reselect, so the draft shows two rows',
      );

      // `_editableAmount(25000 agorot)` renders as '250'.
      final prices = tester
          .widgetList<PriceField>(find.byType(PriceField))
          .map((w) => w.controller.text)
          .toList();
      expect(
        prices,
        ['250', '250'],
        reason:
            'each line carries its own PriceField controller pre-filled '
            'from product.salePrice — a shared controller, or a pre-fill from '
            'purchasePrice, fails here',
      );

      // Independent editing: change the first line's quantity only.
      final qty = tester
          .widgetList<ProductQuantityField>(find.byType(ProductQuantityField))
          .toList();
      await tester.enterText(
        find.descendant(
          of: find.byType(ProductQuantityField).first,
          matching: find.byType(TextFormField),
        ),
        '7',
      );
      await tester.pumpAndSettle();

      expect(qty.first.controller.text, '7');
      expect(
        qty.last.controller.text,
        isEmpty,
        reason:
            'the second line keeps its own empty quantity — sharing one '
            'controller would have set both',
      );
      expect(
        tester
            .widgetList<PriceField>(find.byType(PriceField))
            .map((w) => w.controller.text)
            .toList(),
        ['250', '250'],
        reason: 'editing a quantity must not disturb either price',
      );
    });

    testWidgets('Purchase: two "منتج موجود" picks of the same product yield '
        'two lines pre-filled with purchasePrice', (tester) async {
      tester.view.physicalSize = const Size(600, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final products = _RecordingProducts(const [_apple, _banana]);
      await tester.pumpWidget(_host(products, const PurchaseInvoicesScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      for (var i = 0; i < 2; i++) {
        await tester.ensureVisible(find.text('إضافة صنف'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('إضافة صنف'));
        await _pumpSheet(tester);
        // The purchase form asks existing-vs-new before the picker.
        await tester.tap(find.text('منتج موجود'));
        await _pumpSheet(tester);
        await tester.tap(
          find.descendant(
            of: find.byType(ListView).last,
            matching: find.text('موز'),
          ),
        );
        await tester.pumpAndSettle();
      }

      expect(
        find.text('موز'),
        findsNWidgets(2),
        reason:
            'B3: the existing-product branch appends unconditionally, the '
            'same as Sale — the two paths must be pinned separately because '
            'only one of them goes through the extra sheet',
      );

      // `_editableAmount(22000 agorot)` renders as '220' — purchasePrice, NOT
      // the sale price. A Sale-only characterization would pass against a
      // 250/250 regression here, which is why both cases exist.
      expect(
        tester
            .widgetList<PriceField>(find.byType(PriceField))
            .map((w) => w.controller.text)
            .toList(),
        ['220', '220'],
        reason: 'Purchase must pre-fill purchasePrice',
      );
    });
  });
}

Widget _host(ProductRepository products, Widget body, {bool online = true}) {
  return ProviderScope(
    overrides: [
      authStateProvider.overrideWith((ref) => Stream.value(_user)),
      isOnlineProvider.overrideWithValue(online),
      productRepositoryProvider.overrideWithValue(products),
      invoiceRepositoryProvider.overrideWithValue(
        const _FakeInvoiceRepository(),
      ),
      customerRepositoryProvider.overrideWithValue(
        const _FakeCustomerRepository(),
      ),
      supplierRepositoryProvider.overrideWithValue(
        const _FakeSupplierRepository(),
      ),
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

  /// This suite exercises the PRODUCT picker, so invoices are incidental. The
  /// batch answer is empty rather than absent: an empty list mirrors no lines
  /// and keeps the invoice resolvable, whereas a `failed` id would leave the
  /// mirror untouched and drag the prefetch's other branches into a product
  /// search test that has no reason to cover them.
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
  Future<List<Customer>> listAll({String? search}) async => const [
    Customer(id: 'c1', name: 'شركة الأمل التجارية المحدودة'),
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
  Future<List<Supplier>> listAll({String? search}) async => const [
    Supplier(
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

/// B4 lives in `test/data/offline/offline_product_catalog_search_test.dart`.
///
/// It needs a real `DriftLocalStore` over a real file to be meaningful — the
/// question is what the *local catalog mirror* can answer with no network, and
/// a widget-level fake would answer whatever it was told to. Its library header
/// records why an `InvoiceItem`-only reference cannot be turned into a
/// selectable `Product`.
