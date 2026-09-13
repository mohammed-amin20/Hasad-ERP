import 'package:flutter_test/flutter_test.dart';
import 'package:hasad_erp/domain/accounting/account.dart';
import 'package:hasad_erp/domain/accounting/double_entry_engine.dart';
import 'package:hasad_erp/domain/accounting/invoice_lines.dart';
import 'package:hasad_erp/domain/accounting/journal_entry.dart';
import 'package:hasad_erp/domain/customers/customer.dart';
import 'package:hasad_erp/domain/products/product.dart';
import 'package:hasad_erp/domain/suppliers/supplier.dart';
import 'package:hasad_erp/domain/employees/employee.dart';
import 'package:hasad_erp/domain/invoices/invoice.dart';

void main() {
  group('DoubleEntryEngine', () {
    late Map<String, Account> accounts;
    late Customer testCustomer;
    late Supplier testSupplier;
    late Supplier commissionSupplier;
    late Product testProduct;
    late Employee testEmployee;

    setUp(() {
      // Build chart of accounts
      accounts = {
        '1010': Account(id: 'a1', code: '1010', name: 'النقدية', type: AccountType.asset),
        '1015': Account(id: 'a2', code: '1015', name: 'البنك', type: AccountType.asset),
        '1020': Account(id: 'a3', code: '1020', name: 'ذمم مدينة', type: AccountType.asset),
        '1030': Account(id: 'a4', code: '1030', name: 'المخزون', type: AccountType.asset),
        '2010': Account(id: 'a5', code: '2010', name: 'ذمم دائنة', type: AccountType.liability),
        '2015': Account(id: 'a5b', code: '2015', name: 'ذمم أمانة', type: AccountType.liability),
        '2030': Account(id: 'a6', code: '2030', name: 'مستحقات موظفين', type: AccountType.liability),
        '3010': Account(id: 'a7', code: '3010', name: 'حقوق الملكية', type: AccountType.equity),
        '4010': Account(id: 'a8', code: '4010', name: 'إيرادات المبيعات', type: AccountType.revenue),
        '4020': Account(id: 'a9', code: '4020', name: 'إيرادات الجرد', type: AccountType.revenue),
        '5010': Account(id: 'a10', code: '5010', name: 'تكلفة البضاعة المباعة', type: AccountType.expense),
        '5020': Account(id: 'a11', code: '5020', name: 'مصاريف التشغيل', type: AccountType.expense),
        '5030': Account(id: 'a12', code: '5030', name: 'الأجور والرواتب', type: AccountType.expense),
      };

      testCustomer = Customer(
        id: 'c1',
        name: 'عميل تجريبي',
        phone: '0599111222',
        createdAt: DateTime.now(),
      );

      testSupplier = Supplier(
        id: 's1',
        name: 'مورد تجريبي',
        phone: '0599222333',
        dealType: SupplierDealType.direct,
        createdAt: DateTime.now(),
      );

      commissionSupplier = Supplier(
        id: 's1',
        name: 'مورد أمانة',
        phone: '0599444555',
        dealType: SupplierDealType.commission,
        commissionRate: 20,
        createdAt: DateTime.now(),
      );

      testProduct = Product(
        id: 'p1',
        name: 'منتج تجريبي',
        barcode: null,
        unit: 'قطعة',
        unitType: ProductUnitType.count,
        salePrice: 10000,
        purchasePrice: 6000,
        qty: 100.0,
        reorderLevel: 10.0,
      );

      testEmployee = Employee(
        id: 'e1',
        name: 'موظف تجريبي',
        jobTitle: 'sales',
        phone: '0599333444',
        baseSalary: 500000,
        createdAt: DateTime.now(),
      );
    });

    group('createSaleInvoice', () {
      test('creates balanced revenue-only entry for simple cash sale (no COGS, no inventory)', () {
        final result = DoubleEntryEngine.createSaleInvoice(
          requestId: 'req-1',
          customer: testCustomer,
          lines: [
            SaleInvoiceLine(productId: 'p1', qty: 2, price: 10000),
          ],
          invoiceDate: DateTime(2026, 9, 9),
          paidAmount: 20000,
          paymentMethod: 'cash',
          memo: 'فاتورة نقدية',
          accounts: accounts,
          products: {'p1': testProduct},
        );

        expect(result.journalEntry.isBalanced, isTrue);
        // Sale 2 @ 10000 = 20000 revenue only (matches the shipped RPC).
        // Cash Dr 20000, Revenue Cr 20000 — no COGS / inventory lines.
        expect(result.journalEntry.totalDebit, equals(20000));
        expect(result.journalEntry.totalCredit, equals(20000));

        final cashLine = result.journalEntry.lines.firstWhere((l) => l.accountCode == '1010');
        expect(cashLine.debit, equals(20000));

        final revenueLine = result.journalEntry.lines.firstWhere((l) => l.accountCode == '4010');
        expect(revenueLine.credit, equals(20000));

        expect(result.journalEntry.lines.where((l) => l.accountCode == '5010'), isEmpty);
        expect(result.journalEntry.lines.where((l) => l.accountCode == '1030'), isEmpty);
      });

      test('creates balanced entry for credit sale (partial payment)', () {
        final result = DoubleEntryEngine.createSaleInvoice(
          requestId: 'req-2',
          customer: testCustomer,
          lines: [
            SaleInvoiceLine(productId: 'p1', qty: 3, price: 10000),
          ],
          invoiceDate: DateTime(2026, 9, 9),
          paidAmount: 10000, // Partial
          paymentMethod: 'cash',
          memo: 'فاتورة آجلة جزئياً',
          accounts: accounts,
          products: {'p1': testProduct},
        );

        expect(result.journalEntry.isBalanced, isTrue);
        // Total = 30000, Paid = 10000, Remaining = 20000
        // Cash 10000 Dr, AR 20000 Dr, Revenue 30000 Cr
        expect(result.journalEntry.totalDebit, equals(30000));
        expect(result.journalEntry.totalCredit, equals(30000));

        final arLine = result.journalEntry.lines.firstWhere((l) => l.accountCode == '1020');
        expect(arLine.debit, equals(20000));
      });

      test('creates commission due for consignment product (percent rate)', () {
        final consignmentProduct = Product(
          id: 'p2',
          name: 'منتج أمانة',
          barcode: null,
          unit: 'قطعة',
          unitType: ProductUnitType.count,
          salePrice: 15000,
          purchasePrice: 8000,
          qty: 50.0,
          reorderLevel: 5.0,
          supplierId: 's1',
          commissionRate: 20, // percent (server stores 20, not 0.20)
        );

        final result = DoubleEntryEngine.createSaleInvoice(
          requestId: 'req-3',
          customer: testCustomer,
          lines: [
            SaleInvoiceLine(productId: 'p2', qty: 2, price: 15000),
          ],
          invoiceDate: DateTime(2026, 9, 9),
          paidAmount: 0,
          paymentMethod: 'cash',
          memo: 'فاتورة أمانة',
          accounts: accounts,
          products: {'p2': consignmentProduct},
          suppliers: {'s1': commissionSupplier},
        );

        expect(result.commissionDues, isNotNull);
        expect(result.commissionDues!.length, equals(1));
        // Line = 30000, commission = round(30000 * 20 / 100) = 6000,
        // supplier due = 30000 - 6000 = 24000.
        expect(result.commissionDues!.first.dueAmount, equals(24000));
        expect(result.commissionDues!.first.commissionAmount, equals(6000));
        expect(result.commissionDues!.first.rate, equals(20));
        expect(result.commissionDues!.first.status, equals('pending'));
      });

      test('creates no commission due for a direct supplier product', () {
        final directProduct = Product(
          id: 'p2',
          name: 'منتج مباشر',
          barcode: null,
          unit: 'قطعة',
          unitType: ProductUnitType.count,
          salePrice: 15000,
          purchasePrice: 8000,
          qty: 50.0,
          reorderLevel: 5.0,
          supplierId: 's1',
        );

        final result = DoubleEntryEngine.createSaleInvoice(
          requestId: 'req-3b',
          customer: testCustomer,
          lines: [SaleInvoiceLine(productId: 'p2', qty: 1, price: 15000)],
          invoiceDate: DateTime(2026, 9, 9),
          paidAmount: 0,
          paymentMethod: 'cash',
          memo: '',
          accounts: accounts,
          products: {'p2': directProduct},
          suppliers: {'s1': testSupplier},
        );

        expect(result.commissionDues, isNull);
      });

      test('throws on insufficient inventory', () {
        final lowStockProduct = Product(
          id: 'p3',
          name: 'منخفض المخزون',
          barcode: null,
          unit: 'قطعة',
          unitType: ProductUnitType.count,
          salePrice: 5000,
          purchasePrice: 3000,
          qty: 5.0,
          reorderLevel: 10.0,
        );

        expect(
          () => DoubleEntryEngine.createSaleInvoice(
            requestId: 'req-4',
            customer: testCustomer,
            lines: [SaleInvoiceLine(productId: 'p3', qty: 10, price: 5000)],
            invoiceDate: DateTime.now(),
            paidAmount: 0,
            paymentMethod: 'cash',
            memo: '',
            accounts: accounts,
            products: {'p3': lowStockProduct},
          ),
          throwsA(isA<StateError>()),
        );
      });

      test('updates product quantities in result', () {
        final result = DoubleEntryEngine.createSaleInvoice(
          requestId: 'req-5',
          customer: testCustomer,
          lines: [SaleInvoiceLine(productId: 'p1', qty: 5, price: 10000)],
          invoiceDate: DateTime.now(),
          paidAmount: 50000,
          paymentMethod: 'cash',
          memo: '',
          accounts: accounts,
          products: {'p1': testProduct},
        );

        expect(result.updatedEntities!['products']['p1'], equals(95.0));
      });
    });

    group('createPurchaseInvoice', () {
      test('creates balanced entry for direct purchase', () {
        final result = DoubleEntryEngine.createPurchaseInvoice(
          requestId: 'req-10',
          supplier: testSupplier,
          lines: [
            PurchaseInvoiceLine(productId: 'p1', qty: 10, price: 6000),
          ],
          invoiceDate: DateTime(2026, 9, 9),
          paidAmount: 0,
          paymentMethod: 'cash',
          memo: 'فاتورة مشتريات مباشرة',
          accounts: accounts,
          products: {'p1': testProduct},
        );

        expect(result.journalEntry.isBalanced, isTrue);
        // Inventory Dr 60000, AP Cr 60000
        final invLine = result.journalEntry.lines.firstWhere((l) => l.accountCode == '1030');
        expect(invLine.debit, equals(60000));

        final apLine = result.journalEntry.lines.firstWhere((l) => l.accountCode == '2010');
        expect(apLine.credit, equals(60000));
      });

      test('consignment receipt posts NO journal entry (zero debt)', () {
        final result = DoubleEntryEngine.createPurchaseInvoice(
          requestId: 'req-11',
          supplier: commissionSupplier,
          lines: [
            PurchaseInvoiceLine(productId: 'p1', qty: 20, price: 6000),
          ],
          invoiceDate: DateTime(2026, 9, 9),
          paidAmount: 0,
          paymentMethod: 'cash',
          memo: 'استلام أمانة',
          accounts: accounts,
          products: {'p1': testProduct},
        );

        // The RPC posts no journal and no AP for consignment receipts.
        expect(result.journalEntry.isBalanced, isTrue);
        expect(result.journalEntry.lines, isEmpty);
        expect(result.journalEntry.lines.where((l) => l.accountCode == '2015'), isEmpty);
        expect(result.journalEntry.lines.where((l) => l.accountCode == '2010'), isEmpty);

        // Stock still increases in the mirror.
        expect(result.updatedEntities!['products']['p1'], equals(120.0));
      });

      test('rejects paying a consignment receipt', () {
        expect(
          () => DoubleEntryEngine.createPurchaseInvoice(
            requestId: 'req-11b',
            supplier: commissionSupplier,
            lines: [PurchaseInvoiceLine(productId: 'p1', qty: 1, price: 6000)],
            invoiceDate: DateTime(2026, 9, 9),
            paidAmount: 6000,
            paymentMethod: 'cash',
            memo: '',
            accounts: accounts,
            products: {'p1': testProduct},
          ),
          throwsA(isA<StateError>()),
        );
      });

      test('handles inline new product creation', () {
        final newProduct = ProductDraft(
          name: 'منتج جديد',
          unitType: 'count',
          unit: 'قطعة',
          salePrice: 12000,
          costPrice: 7000,
          qtyOnHand: 0,
          reorderLevel: 5,
        );

        final result = DoubleEntryEngine.createPurchaseInvoice(
          requestId: 'req-12',
          supplier: testSupplier,
          lines: [
            PurchaseInvoiceLine(newProduct: newProduct, qty: 15, price: 7000),
          ],
          invoiceDate: DateTime(2026, 9, 9),
          paidAmount: 0,
          paymentMethod: 'cash',
          memo: 'منتج جديد داخل الفاتورة',
          accounts: accounts,
          products: {}, // Empty - new product inline
        );

        expect(result.journalEntry.isBalanced, isTrue);
        // Should have inventory debit for the new product
        final invLine = result.journalEntry.lines.firstWhere((l) => l.accountCode == '1030');
        expect(invLine.debit, equals(105000)); // 15 * 7000
      });
    });

    group('recordPayment', () {
      test('creates balanced payment entry for sale invoice', () {
        final invoice = Invoice(
          id: 'inv-1',
          type: 'sale',
          no: 'SAL-001',
          partyId: 'c1',
          partyName: 'عميل',
          date: DateTime(2026, 9, 1),
          subtotal: 50000,
          total: 50000,
          paid: 0,
          remaining: 50000,
          status: InvoiceStatus.unpaid,
          ownership: InvoiceOwnership.owned,
        );

        final result = DoubleEntryEngine.recordPayment(
          requestId: 'req-20',
          invoice: invoice,
          amount: 20000,
          method: 'cash',
          date: DateTime(2026, 9, 9),
          note: 'تحصيل جزئي',
          accounts: accounts,
        );

        expect(result.journalEntry.isBalanced, isTrue);
        expect(result.journalEntry.sourceType, equals('payment'));
        expect(result.journalEntry.sourceId, equals('inv-1'));

        // Cash Dr 20000, AR Cr 20000
        final cashLine = result.journalEntry.lines.firstWhere((l) => l.accountCode == '1010');
        expect(cashLine.debit, equals(20000));

        final arLine = result.journalEntry.lines.firstWhere((l) => l.accountCode == '1020');
        expect(arLine.credit, equals(20000));
      });

      test('creates balanced payment entry for purchase invoice', () {
        final invoice = Invoice(
          id: 'inv-2',
          type: 'purchase',
          no: 'PUR-001',
          partyId: 's1',
          partyName: 'مورد',
          date: DateTime(2026, 9, 1),
          subtotal: 30000,
          total: 30000,
          paid: 0,
          remaining: 30000,
          status: InvoiceStatus.unpaid,
          ownership: InvoiceOwnership.owned,
        );

        final result = DoubleEntryEngine.recordPayment(
          requestId: 'req-21',
          invoice: invoice,
          amount: 15000,
          method: 'bank',
          date: DateTime(2026, 9, 9),
          note: 'دفع جزئي للمورد',
          accounts: accounts,
        );

        expect(result.journalEntry.isBalanced, isTrue);
        // Bank Dr 15000, AP Cr 15000
        final bankLine = result.journalEntry.lines.firstWhere((l) => l.accountCode == '1015');
        expect(bankLine.debit, equals(15000));

        final apLine = result.journalEntry.lines.firstWhere((l) => l.accountCode == '2010');
        expect(apLine.credit, equals(15000));
      });

      test('rejects overpaying and consignment invoices', () {
        final invoice = Invoice(
          id: 'inv-1',
          type: 'sale',
          no: 'SAL-001',
          partyId: 'c1',
          partyName: 'عميل',
          date: DateTime(2026, 9, 1),
          subtotal: 50000,
          total: 50000,
          paid: 0,
          remaining: 50000,
          status: InvoiceStatus.unpaid,
          ownership: InvoiceOwnership.owned,
        );

        expect(
          () => DoubleEntryEngine.recordPayment(
            requestId: 'req-22',
            invoice: invoice,
            amount: 60000,
            method: 'cash',
            date: DateTime(2026, 9, 9),
            note: '',
            accounts: accounts,
          ),
          throwsA(isA<StateError>()),
        );

        final consignmentInvoice = Invoice(
          id: 'inv-3',
          type: 'purchase',
          no: 'PUR-002',
          partyId: 's1',
          partyName: 'مورد',
          date: DateTime(2026, 9, 1),
          subtotal: 30000,
          total: 30000,
          paid: 0,
          remaining: 30000,
          status: InvoiceStatus.unpaid,
          ownership: InvoiceOwnership.consignment,
        );

        expect(
          () => DoubleEntryEngine.recordPayment(
            requestId: 'req-23',
            invoice: consignmentInvoice,
            amount: 1000,
            method: 'cash',
            date: DateTime(2026, 9, 9),
            note: '',
            accounts: accounts,
          ),
          throwsA(isA<StateError>()),
        );
      });
    });

    group('settleSupplier', () {
      test('allocates oldest-first across invoices then dues, single journal', () {
        final inv1 = Invoice(
          id: 'inv-1',
          type: 'purchase',
          no: 'PUR-001',
          partyId: 's1',
          partyName: 'مورد',
          date: DateTime(2026, 8, 1),
          subtotal: 40000,
          total: 40000,
          paid: 0,
          remaining: 40000,
          status: InvoiceStatus.unpaid,
          ownership: InvoiceOwnership.owned,
        );
        final inv2 = Invoice(
          id: 'inv-2',
          type: 'purchase',
          no: 'PUR-002',
          partyId: 's1',
          partyName: 'مورد',
          date: DateTime(2026, 8, 15),
          subtotal: 20000,
          total: 20000,
          paid: 0,
          remaining: 20000,
          status: InvoiceStatus.unpaid,
          ownership: InvoiceOwnership.owned,
        );
        final due = CommissionDue(
          id: 'due-1',
          invoiceId: 'inv-3',
          productId: 'p2',
          supplierId: 's1',
          dueAmount: 15000,
          status: 'pending',
          createdAt: DateTime(2026, 8, 20),
        );

        final result = DoubleEntryEngine.settleSupplier(
          requestId: 'req-25',
          invoices: [inv1, inv2],
          dues: [due],
          totalAmount: 50000,
          method: 'bank',
          date: DateTime(2026, 9, 9),
          note: 'تسوية مورد',
          accounts: accounts,
        );

        // Pass 1 fully clears inv1 (40000), then 10000 of inv2.
        // Pass 2 has nothing left for the due (15000 untouched).
        final allocations = result.allocations!;
        expect(allocations.length, equals(2));
        expect(allocations[0].invoiceId, equals('inv-1'));
        expect(allocations[0].amount, equals(40000));
        expect(allocations[1].invoiceId, equals('inv-2'));
        expect(allocations[1].amount, equals(10000));

        // One balanced entry: Bank Dr 50000, AP Cr 50000.
        expect(result.journalEntry.isBalanced, isTrue);
        expect(result.journalEntry.totalDebit, equals(50000));
        expect(result.journalEntry.totalCredit, equals(50000));
        final bankLine = result.journalEntry.lines.firstWhere((l) => l.accountCode == '1015');
        expect(bankLine.debit, equals(50000));
        final apLine = result.journalEntry.lines.firstWhere((l) => l.accountCode == '2010');
        expect(apLine.credit, equals(50000));
      });

      test('allocates into commission dues after invoices are exhausted', () {
        final inv1 = Invoice(
          id: 'inv-1',
          type: 'purchase',
          no: 'PUR-001',
          partyId: 's1',
          partyName: 'مورد',
          date: DateTime(2026, 8, 1),
          subtotal: 40000,
          total: 40000,
          paid: 0,
          remaining: 40000,
          status: InvoiceStatus.unpaid,
          ownership: InvoiceOwnership.owned,
        );
        final due = CommissionDue(
          id: 'due-1',
          invoiceId: 'inv-3',
          productId: 'p2',
          supplierId: 's1',
          dueAmount: 15000,
          status: 'pending',
          createdAt: DateTime(2026, 8, 20),
        );

        final result = DoubleEntryEngine.settleSupplier(
          requestId: 'req-26',
          invoices: [inv1],
          dues: [due],
          totalAmount: 50000,
          method: 'cash',
          date: DateTime(2026, 9, 9),
          note: '',
          accounts: accounts,
        );

        final allocations = result.allocations!;
        expect(allocations.length, equals(2));
        expect(allocations[0].invoiceId, equals('inv-1'));
        expect(allocations[0].amount, equals(40000));
        expect(allocations[0].no, equals('PUR-001'));
        expect(allocations[1].dueId, equals('due-1'));
        expect(allocations[1].amount, equals(10000));

        expect(result.journalEntry.isBalanced, isTrue);
        expect(result.journalEntry.totalDebit, equals(50000));
      });

      test('rejects settlement larger than total debts', () {
        final inv1 = Invoice(
          id: 'inv-1',
          type: 'purchase',
          no: 'PUR-001',
          partyId: 's1',
          partyName: 'مورد',
          date: DateTime(2026, 8, 1),
          subtotal: 40000,
          total: 40000,
          paid: 0,
          remaining: 40000,
          status: InvoiceStatus.unpaid,
          ownership: InvoiceOwnership.owned,
        );

        expect(
          () => DoubleEntryEngine.settleSupplier(
            requestId: 'req-27',
            invoices: [inv1],
            dues: const [],
            totalAmount: 99999,
            method: 'cash',
            date: DateTime(2026, 9, 9),
            note: '',
            accounts: accounts,
          ),
          throwsA(isA<StateError>()),
        );
      });
    });

    group('addEmployeeMovement', () {
      test('advance deduction returns value and NO journal (RPC semantics)', () {
        final result = DoubleEntryEngine.addEmployeeMovement(
          requestId: 'req-30',
          employee: testEmployee,
          month: DateTime(2026, 9, 1),
          direction: 'out',
          category: 'advance',
          amount: 50000,
          date: DateTime(2026, 9, 9),
          note: 'سلفة نقدية',
          accounts: accounts,
        );

        expect(result.journalEntry.isBalanced, isTrue);
        expect(result.journalEntry.sourceType, equals('salary'));
        // The RPC does not journal movements.
        expect(result.journalEntry.lines, isEmpty);
        expect(result.amount, equals(50000));
        expect(result.updatedEntities, isNull);
      });

      test('product deduction moves inventory by cost and returns value, no journal', () {
        final result = DoubleEntryEngine.addEmployeeMovement(
          requestId: 'req-31',
          employee: testEmployee,
          month: DateTime(2026, 9, 1),
          direction: 'out',
          category: 'product',
          qty: 5,
          date: DateTime(2026, 9, 9),
          note: 'صرف أصناف',
          accounts: accounts,
          product: testProduct,
        );

        expect(result.journalEntry.lines, isEmpty);
        // Value = 5 * 6000 (cost), stock drops to 95.
        expect(result.amount, equals(30000));
        expect(result.updatedEntities!['products']['p1'], equals(95.0));
      });

      test('bonus entitlement returns value and NO journal', () {
        final result = DoubleEntryEngine.addEmployeeMovement(
          requestId: 'req-32',
          employee: testEmployee,
          month: DateTime(2026, 9, 1),
          direction: 'in',
          category: 'bonus',
          amount: 20000,
          date: DateTime(2026, 9, 9),
          note: 'مكافأة أداء',
          accounts: accounts,
        );

        expect(result.journalEntry.lines, isEmpty);
        expect(result.amount, equals(20000));
      });

      test('rejects invalid direction/category and cashless product deduction', () {
        expect(
          () => DoubleEntryEngine.addEmployeeMovement(
            requestId: 'req-33',
            employee: testEmployee,
            month: DateTime(2026, 9, 1),
            direction: 'out',
            category: 'bonus',
            amount: 5000,
            date: DateTime(2026, 9, 9),
            note: '',
            accounts: accounts,
          ),
          throwsA(isA<StateError>()),
        );

        expect(
          () => DoubleEntryEngine.addEmployeeMovement(
            requestId: 'req-34',
            employee: testEmployee,
            month: DateTime(2026, 9, 1),
            direction: 'in',
            category: 'advance',
            amount: 5000,
            date: DateTime(2026, 9, 9),
            note: '',
            accounts: accounts,
          ),
          throwsA(isA<StateError>()),
        );

        expect(
          () => DoubleEntryEngine.addEmployeeMovement(
            requestId: 'req-35',
            employee: testEmployee,
            month: DateTime(2026, 9, 1),
            direction: 'out',
            category: 'product',
            date: DateTime(2026, 9, 9),
            note: '',
            accounts: accounts,
          ),
          throwsA(isA<StateError>()),
        );
      });
    });

    group('paySalary', () {
      test('creates balanced wage entry with no arrears (Dr 5030, Cr 1015)', () {
        final result = DoubleEntryEngine.paySalary(
          requestId: 'req-40',
          employee: testEmployee,
          month: DateTime(2026, 9, 1),
          paidAmount: 450000,
          netDue: 450000,
          arrears: 0,
          method: 'bank',
          date: DateTime(2026, 9, 25),
          note: 'راتب سبتمبر',
          accounts: accounts,
        );

        expect(result.journalEntry.isBalanced, isTrue);
        expect(result.journalEntry.sourceType, equals('salary'));
        // No arrears: Dr Wages (5030) 450000, Cr Bank (1015) 450000.
        expect(result.journalEntry.totalDebit, equals(450000));
        final wagesLine = result.journalEntry.lines.firstWhere((l) => l.accountCode == '5030');
        expect(wagesLine.debit, equals(450000));

        final bankLine = result.journalEntry.lines.firstWhere((l) => l.accountCode == '1015');
        expect(bankLine.credit, equals(450000));

        expect(result.journalEntry.lines.where((l) => l.accountCode == '2030'), isEmpty);
      });

      test('clears prior arrears Dr 2030, books the rest as expense', () {
        final result = DoubleEntryEngine.paySalary(
          requestId: 'req-41',
          employee: testEmployee,
          month: DateTime(2026, 10, 1),
          paidAmount: 450000,
          netDue: 450000,
          arrears: 50000,
          method: 'bank',
          date: DateTime(2026, 10, 25),
          note: 'راتب أكتوبر',
          accounts: accounts,
        );

        expect(result.journalEntry.isBalanced, isTrue);
        // DR 2030 50000 (cleared arrears) + DR 5030 400000 = 450000
        // CR 1015 450000
        final payable = result.journalEntry.lines.firstWhere((l) => l.accountCode == '2030');
        expect(payable.debit, equals(50000));
        final wages = result.journalEntry.lines.firstWhere((l) => l.accountCode == '5030');
        expect(wages.debit, equals(400000));
        expect(result.journalEntry.totalCredit, equals(450000));
      });

      test('partial payment carries the remainder as 2030 arrears', () {
        final result = DoubleEntryEngine.paySalary(
          requestId: 'req-42',
          employee: testEmployee,
          month: DateTime(2026, 11, 1),
          paidAmount: 300000,
          netDue: 450000,
          arrears: 50000,
          method: 'bank',
          date: DateTime(2026, 11, 25),
          note: 'راتب جزئي',
          accounts: accounts,
        );

        expect(result.journalEntry.isBalanced, isTrue);
        // DR 2030 50000 + DR 5030 400000 = 450000
        // CR 1015 300000 + CR 2030 150000 = 450000
        final payable = result.journalEntry.lines.firstWhere((l) => l.accountCode == '2030');
        expect(payable.debit, equals(50000));
        expect(payable.credit, equals(0));

        final carry = result.journalEntry.lines
            .where((l) => l.accountCode == '2030' && l.credit > 0)
            .first;
        expect(carry.credit, equals(150000));
        expect(result.journalEntry.totalDebit, equals(450000));
        expect(result.journalEntry.totalCredit, equals(450000));
      });

      test('rejects paying more than net due', () {
        expect(
          () => DoubleEntryEngine.paySalary(
            requestId: 'req-43',
            employee: testEmployee,
            month: DateTime(2026, 9, 1),
            paidAmount: 500000,
            netDue: 450000,
            arrears: 0,
            method: 'bank',
            date: DateTime(2026, 9, 25),
            note: '',
            accounts: accounts,
          ),
          throwsA(isA<StateError>()),
        );
      });
    });

    group('adjustInventory', () {
      test('adjustment returns new qty and NO journal entry', () {
        final product = Product(
          id: 'p1',
          name: 'منتج تجريبي',
          barcode: null,
          unit: 'قطعة',
          unitType: ProductUnitType.count,
          salePrice: 10000,
          purchasePrice: 6000,
          qty: 100.0,
          reorderLevel: 10.0,
        );

        final result = DoubleEntryEngine.adjustInventory(
          requestId: 'req-50',
          product: product,
          countedQty: 105.0, // +5
          reason: 'فائض جرد',
          date: DateTime(2026, 9, 9),
          accounts: accounts,
        );

        expect(result.journalEntry.isBalanced, isTrue);
        expect(result.journalEntry.lines, isEmpty);
        expect(result.updatedEntities!['products']['p1'], equals(105.0));
      });

      test('adjustment decrease returns new qty and NO journal entry', () {
        final product = Product(
          id: 'p1',
          name: 'منتج تجريبي',
          barcode: null,
          unit: 'قطعة',
          unitType: ProductUnitType.count,
          salePrice: 10000,
          purchasePrice: 6000,
          qty: 100.0,
          reorderLevel: 10.0,
        );

        final result = DoubleEntryEngine.adjustInventory(
          requestId: 'req-51',
          product: product,
          countedQty: 95.0, // -5
          reason: 'نقص جرد',
          date: DateTime(2026, 9, 9),
          accounts: accounts,
        );

        expect(result.journalEntry.isBalanced, isTrue);
        expect(result.journalEntry.lines, isEmpty);
        expect(result.updatedEntities!['products']['p1'], equals(95.0));
      });

      test('throws when no adjustment needed', () {
        final product = Product(
          id: 'p1',
          name: 'منتج',
          barcode: null,
          unit: 'قطعة',
          unitType: ProductUnitType.count,
          salePrice: 10000,
          purchasePrice: 6000,
          qty: 100.0,
          reorderLevel: 10.0,
        );

        expect(
          () => DoubleEntryEngine.adjustInventory(
            requestId: 'req-52',
            product: product,
            countedQty: 100.0, // Same
            reason: 'لا تغيير',
            date: DateTime.now(),
            accounts: accounts,
          ),
          throwsA(isA<StateError>()),
        );
      });
    });

    group('JournalEntry validation', () {
      test('JournalEntry.isBalanced detects imbalance', () {
        final entry = JournalEntry.create(
          date: DateTime.now(),
          memo: 'Test',
          lines: [
            JournalLine(accountId: '1', accountCode: '1010', accountName: 'Cash', debit: 1000, credit: 0),
            JournalLine(accountId: '2', accountCode: '4010', accountName: 'Revenue', debit: 0, credit: 500),
          ],
        );

        expect(entry.isBalanced, isFalse);
        expect(entry.imbalance, equals(500));
      });

      test('UnbalancedEntryException contains entry details', () {
        final entry = JournalEntry.create(
          date: DateTime.now(),
          memo: 'Test',
          lines: [
            JournalLine(accountId: '1', accountCode: '1010', accountName: 'Cash', debit: 1000, credit: 0),
            JournalLine(accountId: '2', accountCode: '4010', accountName: 'Revenue', debit: 0, credit: 500),
          ],
        );

        final exception = UnbalancedEntryException(entry, 'Test imbalance');
        expect(exception.entry.totalDebit, equals(1000));
        expect(exception.entry.totalCredit, equals(500));
        expect(exception.toString(), contains('debit: 1000'));
        expect(exception.toString(), contains('credit: 500'));
      });
    });
  });
}