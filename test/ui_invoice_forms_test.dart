import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasad_erp/core/theme/app_theme.dart';
import 'package:hasad_erp/data/invoices/invoice_repository.dart';
import 'package:hasad_erp/domain/auth/app_role.dart';
import 'package:hasad_erp/domain/auth/app_user.dart';
import 'package:hasad_erp/domain/customers/customer.dart';
import 'package:hasad_erp/domain/customers/customer_draft.dart';
import 'package:hasad_erp/domain/customers/customer_repository.dart';
import 'package:hasad_erp/domain/invoices/invoice.dart';
import 'package:hasad_erp/domain/suppliers/supplier.dart';
import 'package:hasad_erp/domain/suppliers/supplier_draft.dart';
import 'package:hasad_erp/domain/suppliers/supplier_repository.dart';
import 'package:hasad_erp/presentation/providers/auth_providers.dart';
import 'package:hasad_erp/presentation/providers/customers_providers.dart';
import 'package:hasad_erp/presentation/providers/sales_providers.dart';
import 'package:hasad_erp/presentation/providers/suppliers_providers.dart';
import 'package:hasad_erp/presentation/screens/purchases/purchase_invoices_screen.dart';
import 'package:hasad_erp/presentation/screens/sales/sale_invoices_screen.dart';

/// Regression guards: the "New Sale/Purchase Invoice" routes are pushed with
/// MaterialPageRoute (fullscreenDialog), which does NOT insert a Material
/// ancestor. The form pages own their Scaffold, so opening them must not throw
/// "No Material widget found" (dropdowns/InkWell/buttons all need it). Both
/// forms render their RouteHeader (title + subtitle) on open.
void main() {
  const user = AppUser(
    id: 'u1',
    email: 'admin@test.local',
    name: 'مدير النظام',
    role: AppRole.admin,
    tenantId: 't1',
  );

  testWidgets('opening the New Sale Invoice form renders without exceptions',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(user)),
          invoiceRepositoryProvider.overrideWithValue(
            _FakeInvoiceRepository(),
          ),
          customerRepositoryProvider.overrideWithValue(
            _FakeCustomerRepository(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: SaleInvoicesScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('لا توجد فواتير بيع'), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('فاتورة بيع جديدة'), findsOneWidget);
    expect(find.text('إدخال فاتورة مبيعات للعميل'), findsOneWidget);
  });

  testWidgets('opening the New Purchase Invoice form renders without exceptions',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(user)),
          invoiceRepositoryProvider.overrideWithValue(
            _FakeInvoiceRepository(),
          ),
          supplierRepositoryProvider.overrideWithValue(
            _FakeSupplierRepository(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: PurchaseInvoicesScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('لا توجد فواتير شراء'), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('فاتورة شراء جديدة'), findsOneWidget);
    expect(find.text('إدخال فاتورة شراء من المورد'), findsOneWidget);
  });

  testWidgets('sales list defaults to ALL sales (no date bounds)', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final invoices = _FakeInvoiceRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(user)),
          invoiceRepositoryProvider.overrideWithValue(invoices),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: SaleInvoicesScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // No date is forced: both range chips read as "الكل" and the underlying
    // query goes out bounds-free.
    expect(find.text('من: الكل'), findsOneWidget);
    expect(find.text('إلى: الكل'), findsOneWidget);
    expect(invoices.lastType, 'sale');
    expect(invoices.lastFrom, isNull);
    expect(invoices.lastTo, isNull);
  });
}

class _FakeInvoiceRepository implements InvoiceRepository {
  String? lastType;
  String? lastSearch;
  DateTime? lastFrom;
  DateTime? lastTo;

  @override
  Future<List<Invoice>> list({
    required String type,
    String? search,
    DateTime? from,
    DateTime? to,
  }) async {
    lastType = type;
    lastSearch = search;
    lastFrom = from;
    lastTo = to;
    return <Invoice>[];
  }

  @override
  Future<List<InvoiceItem>> items(String invoiceId) async {
    return <InvoiceItem>[];
  }
}

class _FakeCustomerRepository implements CustomerRepository {
  @override
  Future<List<Customer>> listAll({String? search}) async {
    return [
      const Customer(id: 'c1', name: 'أحمد محمد', phone: '0599111001'),
    ];
  }

  @override
  Future<Customer?> getById(String id) async => null;

  @override
  Future<Customer> create(CustomerDraft draft) async => const Customer(
    id: 'c1',
    name: 'أحمد محمد',
  );

  @override
  Future<void> update({required String id, required CustomerDraft draft}) async {}

  @override
  Future<void> delete(String id) async {}
}

class _FakeSupplierRepository implements SupplierRepository {
  @override
  Future<List<Supplier>> listAll({String? search}) async {
    return [
      const Supplier(
        id: 's1',
        name: 'مورد الاختبار',
        dealType: SupplierDealType.direct,
      ),
    ];
  }

  @override
  Future<Supplier?> getById(String id) async => null;

  @override
  Future<Supplier> create(SupplierDraft draft) async => const Supplier(
    id: 's1',
    name: 'مورد الاختبار',
    dealType: SupplierDealType.direct,
  );

  @override
  Future<void> update({required String id, required SupplierDraft draft}) async {}

  @override
  Future<void> delete(String id) async {}
}