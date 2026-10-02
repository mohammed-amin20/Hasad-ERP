import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasad_erp/core/theme/app_theme.dart';
import 'package:hasad_erp/domain/auth/app_role.dart';
import 'package:hasad_erp/domain/auth/app_user.dart';
import 'package:hasad_erp/domain/products/product.dart';
import 'package:hasad_erp/domain/products/product_draft.dart';
import 'package:hasad_erp/domain/suppliers/supplier.dart';
import 'package:hasad_erp/domain/suppliers/supplier_draft.dart';
import 'package:hasad_erp/domain/suppliers/supplier_repository.dart';
import 'package:hasad_erp/presentation/providers/auth_providers.dart';
import 'package:hasad_erp/presentation/providers/products_providers.dart';
import 'package:hasad_erp/presentation/providers/suppliers_providers.dart';
import 'package:hasad_erp/presentation/screens/products/products_screen.dart';

const _offlineCreate = 'تم حفظ المنتج محليًا وستتم مزامنته عند عودة الاتصال';
const _offlineUpdate =
    'تم حفظ تعديلات المنتج محليًا وستتم مزامنتها عند عودة الاتصال';
const _offlineDelete =
    'تم حذف المنتج محليًا وستتم مزامنته مع الخادم عند عودة الاتصال';
const _onlineCreate = 'تمت إضافة المنتج';

const _user = AppUser(
  id: 'u1',
  email: 'admin@test.local',
  name: 'مدير النظام',
  role: AppRole.admin,
  tenantId: 't1',
);

/// Products list stub that never touches the repository chain: it records the
/// write so a test can assert both the call and the resulting message.
class _FakeProductsList extends ProductsList {
  @override
  Future<List<Product>> build() async => _rows;

  @override
  Future<Product> create(ProductDraft draft) async {
    final product = Product(
      id: 'p-new',
      name: draft.name,
      barcode: draft.barcode,
      unit: draft.unit,
      unitType: draft.unitType,
      salePrice: draft.salePrice,
      purchasePrice: draft.purchasePrice,
      qty: draft.qty,
      reorderLevel: draft.reorderLevel,
      supplierId: draft.supplierId,
      commissionRate: draft.commissionRate,
    );
    _rows = [..._rows, product];
    return product;
  }

  @override
  Future<void> updateProduct({
    required String id,
    required ProductDraft draft,
  }) async {
    _rows = [
      for (final p in _rows)
        if (p.id == id)
          Product(
            id: id,
            name: draft.name,
            barcode: draft.barcode,
            unit: draft.unit,
            unitType: draft.unitType,
            salePrice: draft.salePrice,
            purchasePrice: draft.purchasePrice,
            qty: draft.qty,
            reorderLevel: draft.reorderLevel,
            supplierId: draft.supplierId,
            commissionRate: draft.commissionRate,
          )
        else
          p,
    ];
  }

  @override
  Future<void> delete(String id) async {
    _rows = [for (final p in _rows) if (p.id != id) p];
  }
}

class _FakeSupplierRepository implements SupplierRepository {
  @override
  Future<List<Supplier>> listAll({String? search}) async => const [];

  @override
  Future<Supplier?> getById(String id) async => null;

  @override
  Future<Supplier> create(SupplierDraft draft) async =>
      throw UnimplementedError();

  @override
  Future<void> update({
    required String id,
    required SupplierDraft draft,
  }) async {}

  @override
  Future<void> delete(String id) async {}
}

List<Product> _rows = <Product>[_product()];

Product _product() => const Product(
      id: 'p1',
      name: 'منتج',
      barcode: '123',
      unit: 'قطعة',
      unitType: ProductUnitType.count,
      salePrice: 100,
      purchasePrice: 60,
      qty: 10,
      reorderLevel: 2,
    );

Future<void> _pumpScreen(
  WidgetTester tester, {
  required bool writesLocalFirst,
}) async {
  _rows = <Product>[_product()];
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authStateProvider.overrideWith((ref) => Stream.value(_user)),
        productsListProvider.overrideWith(_FakeProductsList.new),
        supplierRepositoryProvider.overrideWith(
          (ref) => _FakeSupplierRepository(),
        ),
        productWritesLocalFirstProvider.overrideWithValue(writesLocalFirst),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: const Scaffold(body: ProductsScreen()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// A bottom sheet with an autofocused field never settles (cursor blink), so
/// sheet transitions are driven with pump + a fixed delay.
Future<void> _pumpSheet(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  testWidgets('offline-first: create shows the pending-save message',
      (tester) async {
    await _pumpScreen(tester, writesLocalFirst: true);

    await tester.tap(find.byTooltip('إضافة منتج'));
    await _pumpSheet(tester);
    expect(find.text('إضافة منتج جديد'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'منتج جديد');
    await tester.enterText(find.byType(TextFormField).at(2), 'قطعة');
    await tester.enterText(find.byType(TextFormField).at(5), '100');
    await tester.enterText(find.byType(TextFormField).at(6), '60');
    await tester.tap(find.widgetWithText(FilledButton, 'إضافة'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text(_offlineCreate), findsOneWidget);
    expect(find.text(_onlineCreate), findsNothing);
  });

  testWidgets('online path keeps the short confirmation message',
      (tester) async {
    await _pumpScreen(tester, writesLocalFirst: false);

    await tester.tap(find.byTooltip('إضافة منتج'));
    await _pumpSheet(tester);

    await tester.enterText(find.byType(TextFormField).at(0), 'منتج جديد');
    await tester.enterText(find.byType(TextFormField).at(2), 'قطعة');
    await tester.enterText(find.byType(TextFormField).at(5), '100');
    await tester.enterText(find.byType(TextFormField).at(6), '60');
    await tester.tap(find.widgetWithText(FilledButton, 'إضافة'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text(_onlineCreate), findsOneWidget);
    expect(find.text(_offlineCreate), findsNothing);
  });

  testWidgets('offline-first: update shows the pending-edit message',
      (tester) async {
    await _pumpScreen(tester, writesLocalFirst: true);
    expect(find.text('منتج'), findsOneWidget);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await _pumpSheet(tester);
    await tester.tap(find.text('تعديل'));
    await _pumpSheet(tester);
    expect(find.text('تعديل المنتج'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'منتج محدث');
    await tester.tap(find.widgetWithText(FilledButton, 'حفظ التعديلات'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text(_offlineUpdate), findsOneWidget);
  });

  testWidgets('offline-first: delete shows the pending-delete message',
      (tester) async {
    await _pumpScreen(tester, writesLocalFirst: true);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await _pumpSheet(tester);
    await tester.tap(find.text('حذف'));
    await _pumpSheet(tester);
    expect(find.text('حذف المنتج'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'حذف'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text(_offlineDelete), findsOneWidget);
  });
}
