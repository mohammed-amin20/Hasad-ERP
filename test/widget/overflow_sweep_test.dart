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
import 'package:hasad_erp/domain/employees/employee.dart';
import 'package:hasad_erp/domain/employees/employee_draft.dart';
import 'package:hasad_erp/domain/employees/employee_repository.dart';
import 'package:hasad_erp/domain/inventory/inventory.dart';
import 'package:hasad_erp/domain/inventory/inventory_repository.dart';
import 'package:hasad_erp/domain/invoices/invoice.dart';
import 'package:hasad_erp/domain/products/product.dart';
import 'package:hasad_erp/domain/products/product_draft.dart';
import 'package:hasad_erp/domain/products/product_repository.dart';
import 'package:hasad_erp/domain/salaries/salary_repository.dart';
import 'package:hasad_erp/domain/statements/debts_repository.dart';
import 'package:hasad_erp/domain/statements/statement.dart';
import 'package:hasad_erp/domain/suppliers/supplier.dart';
import 'package:hasad_erp/domain/suppliers/supplier_draft.dart';
import 'package:hasad_erp/domain/suppliers/supplier_repository.dart';
import 'package:hasad_erp/presentation/providers/auth_providers.dart';
import 'package:hasad_erp/presentation/providers/customers_providers.dart';
import 'package:hasad_erp/presentation/providers/employees_providers.dart';
import 'package:hasad_erp/presentation/providers/inventory_providers.dart';
import 'package:hasad_erp/presentation/providers/products_providers.dart';
import 'package:hasad_erp/presentation/providers/salaries_providers.dart';
import 'package:hasad_erp/presentation/providers/sales_providers.dart';
import 'package:hasad_erp/presentation/providers/statements_providers.dart';
import 'package:hasad_erp/presentation/providers/suppliers_providers.dart';
import 'package:hasad_erp/presentation/screens/debts/debts_screen.dart';
import 'package:hasad_erp/presentation/screens/employees/employee_statement_screen.dart';
import 'package:hasad_erp/presentation/screens/employees/employees_screen.dart';
import 'package:hasad_erp/presentation/screens/expenses/expenses_screen.dart';
import 'package:hasad_erp/presentation/screens/inventory/inventory_screen.dart';
import 'package:hasad_erp/presentation/screens/products/products_screen.dart';
import 'package:hasad_erp/presentation/screens/purchases/purchase_invoices_screen.dart';
import 'package:hasad_erp/presentation/screens/salaries/salaries_screen.dart';
import 'package:hasad_erp/presentation/screens/sales/sale_invoices_screen.dart';
import 'package:hasad_erp/presentation/screens/statements/statement_screen.dart';
import 'package:hasad_erp/presentation/screens/suppliers/suppliers_screen.dart';

const _user = AppUser(
  id: 'u1',
  email: 'admin@test.local',
  name: 'مدير النظام',
  role: AppRole.admin,
  tenantId: 't1',
);

final _overrides = [
  authStateProvider.overrideWith((ref) => Stream.value(_user)),
  isOnlineProvider.overrideWithValue(true),
  customerRepositoryProvider.overrideWithValue(const _FakeCustomerRepository()),
  supplierRepositoryProvider.overrideWithValue(const _FakeSupplierRepository()),
  productRepositoryProvider.overrideWithValue(const _FakeProductRepository()),
  inventoryRepositoryProvider.overrideWithValue(
    const _FakeInventoryRepository(),
  ),
  employeeRepositoryProvider.overrideWithValue(const _FakeEmployeeRepository()),
  salaryRepositoryProvider.overrideWithValue(const _FakeSalaryRepository()),
  debtsRepositoryProvider.overrideWithValue(const _FakeDebtsRepository()),
  statementRepositoryProvider.overrideWithValue(
    const _FakeStatementRepository(),
  ),
  invoiceRepositoryProvider.overrideWithValue(const _FakeInvoiceRepository()),
];

final _screens = <String, Widget>{
  'suppliers': const SuppliersScreen(),
  'products': const ProductsScreen(),
  'inventory': const InventoryScreen(),
  'employees': const EmployeesScreen(),
  'employee statement': const EmployeeStatementScreen(
    employeeId: 'e1',
    employeeName: 'أحمد بن محمد الشامل',
  ),
  'salaries': const SalariesScreen(),
  'expenses': const ExpensesScreen(),
  'sales': const SaleInvoicesScreen(),
  'purchases': const PurchaseInvoicesScreen(),
  'debts': const DebtsScreen(),
  'statement': const StatementScreen(
    partyType: 'customer',
    partyId: 'c1',
    partyName: 'شركة الأمل التجارية المحدودة',
  ),
};

const _widths = <double>[375, 768, 1024, 1440];

void main() {
  for (final width in _widths) {
    for (final entry in _screens.entries) {
      testWidgets('${entry.key} lays out without overflow at $width', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          ProviderScope(
            overrides: _overrides,
            child: MaterialApp(
              theme: AppTheme.light,
              home: Directionality(
                textDirection: TextDirection.rtl,
                child: Scaffold(body: entry.value),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          tester.takeException(),
          isNull,
          reason: '${entry.key} at $width',
        );
      });
    }
  }
}

class _FakeCustomerRepository implements CustomerRepository {
  const _FakeCustomerRepository();

  @override
  Future<List<Customer>> listAll({String? search}) async => [
    Customer(
      id: 'c1',
      name: 'شركة الأمل التجارية المحدودة',
      phone: '0912345678',
    ),
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
    Supplier(
      id: 's1',
      name: 'مؤسسة النور للتوريدات العامة',
      phone: '0999888777',
      dealType: SupplierDealType.commission,
      commissionRate: 20,
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

class _FakeInventoryRepository implements InventoryRepository {
  const _FakeInventoryRepository();

  @override
  Future<StockAdjustResult> adjust(StockAdjustDraft draft) =>
      throw UnimplementedError();
}

class _FakeEmployeeRepository implements EmployeeRepository {
  const _FakeEmployeeRepository();

  @override
  Future<List<Employee>> listAll({String? search}) async => [
    Employee(
      id: 'e1',
      name: 'أحمد بن محمد الشامل',
      jobTitle: 'محاسب أول',
      phone: '0933123456',
      baseSalary: 1200000,
    ),
  ];

  @override
  Future<Employee?> getById(String id) async => null;

  @override
  Future<Employee> create(EmployeeDraft draft) => throw UnimplementedError();

  @override
  Future<void> update({required String id, required EmployeeDraft draft}) =>
      throw UnimplementedError();

  @override
  Future<void> delete(String id) => throw UnimplementedError();
}

class _FakeSalaryRepository implements SalaryRepository {
  const _FakeSalaryRepository();

  @override
  Future<List<SalaryRecord>> salaryHistory() async => [
    SalaryRecord(
      employeeId: 'e1',
      month: DateTime(2026, 3),
      baseSalary: 1200000,
      paid: 1200000,
      date: DateTime(2026, 3, 28),
    ),
    SalaryRecord(
      employeeId: 'e1',
      month: DateTime(2026, 2),
      baseSalary: 1200000,
      paid: 900000,
      date: DateTime(2026, 2, 28),
    ),
  ];

  @override
  Future<EmployeeStatement> employeeStatement(
    EmployeeStatementRequest request,
  ) async => EmployeeStatement(
    employeeId: request.employeeId,
    monthFrom: DateTime(request.from.year, request.from.month),
    monthTo: DateTime(request.to.year, request.to.month),
    opening: 0,
    lines: [
      EmployeeMonthLine(
        month: DateTime(2026, 1),
        baseSalary: 1200000,
        arrears: 0,
        entitlements: 0,
        deductions: 0,
        netDue: 1200000,
        paid: 1200000,
        remaining: 0,
      ),
      EmployeeMonthLine(
        month: DateTime(2026, 2),
        baseSalary: 1200000,
        arrears: 0,
        entitlements: 150000,
        deductions: 50000,
        netDue: 1300000,
        paid: 900000,
        remaining: 400000,
      ),
    ],
    closing: 400000,
  );

  @override
  Future<MovementResult> addMovement(MovementDraft draft) =>
      throw UnimplementedError();

  @override
  Future<SalaryResult> pay(SalaryDraft draft) => throw UnimplementedError();

  @override
  Future<EmployeeEntitlement> entitlement({
    required String employeeId,
    required DateTime month,
  }) => throw UnimplementedError();
}

class _FakeDebtsRepository implements DebtsRepository {
  const _FakeDebtsRepository();

  @override
  Future<List<PartyBalance>> customerBalances() async => [
    const PartyBalance(
      id: 'c1',
      name: 'شركة الأمل التجارية المحدودة',
      amount: 4500000,
    ),
  ];

  @override
  Future<List<PartyBalance>> supplierBalances() async => [
    const PartyBalance(
      id: 's1',
      name: 'مؤسسة النور للتوريدات العامة',
      amount: 2300000,
    ),
  ];

  @override
  Future<int> supplierInvoiceDebt(String supplierId) async => 0;

  @override
  Future<int> supplierCommissionDebt(String supplierId) async => 0;

  @override
  Future<List<Invoice>> partyInvoices({
    required String type,
    required String partyId,
  }) async => const [];
}

class _FakeStatementRepository implements StatementRepository {
  const _FakeStatementRepository();

  @override
  Future<PartyStatement> statement(StatementRequest request) async {
    final now = DateTime(2026, 3, 15);
    return PartyStatement(
      partyType: request.partyType,
      partyId: request.partyId,
      from: request.from,
      to: request.to,
      opening: 1200000,
      lines: [
        StatementLine(
          date: DateTime(2026, 2, 1),
          kind: StatementLineKind.invoice,
          ref: 'INV-1042',
          note: 'فاتورة مبيعات',
          debit: 2500000,
          credit: 0,
        ),
        StatementLine(
          date: DateTime(2026, 2, 20),
          kind: StatementLineKind.payment,
          ref: 'PAY-77',
          note: 'دفعة نقدية',
          debit: 0,
          credit: 1000000,
        ),
        StatementLine(
          date: now,
          kind: StatementLineKind.commission,
          ref: 'COM-3',
          note: 'عمولة بيع بالعمولة',
          debit: 300000,
          credit: 0,
        ),
      ],
      closing: 3000000,
    );
  }
}

class _FakeInvoiceRepository implements InvoiceRepository {
  const _FakeInvoiceRepository();

  @override
  Future<List<Invoice>> list({
    required String type,
    String? search,
    DateTime? from,
    DateTime? to,
  }) async => [
    Invoice(
      id: 'i1',
      type: type,
      no: 'INV-1042',
      partyId: type == 'sale' ? 'c1' : 's1',
      partyName: type == 'sale'
          ? 'شركة الأمل التجارية المحدودة'
          : 'مؤسسة النور للتوريدات العامة',
      date: DateTime(2026, 3, 1),
      subtotal: 2500000,
      total: 2500000,
      paid: 1000000,
      remaining: 1500000,
      status: InvoiceStatus.partial,
      ownership: InvoiceOwnership.owned,
    ),
  ];

  @override
  Future<List<InvoiceItem>> items(String invoiceId) async => const [];
}
