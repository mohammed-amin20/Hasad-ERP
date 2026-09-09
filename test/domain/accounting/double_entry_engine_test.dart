import 'package:flutter_test/flutter_test.dart';
import 'package:hasad_erp/domain/accounting/account.dart';
import 'package:hasad_erp/domain/accounting/double_entry_engine.dart';
import 'package:hasad_erp/domain/accounting/invoice_lines.dart';
import 'package:hasad_erp/domain/accounting/journal_entry.dart';
import 'package:hasad_erp/domain/customers/customer.dart';
import 'package:hasad_erp/domain/products/product.dart';
import 'package:hasad_erp/domain/products/product.dart' show ProductUnitType;
import 'package:hasad_erp/domain/suppliers/supplier.dart';
import 'package:hasad_erp/domain/suppliers/supplier.dart' show SupplierDealType;
import 'package:hasad_erp/domain/employees/employee.dart';
import 'package:hasad_erp/domain/invoices/invoice.dart';
import 'package:hasad_erp/domain/invoices/invoice.dart' show InvoiceStatus, InvoiceOwnership;

void main() {
  group('DoubleEntryEngine', () {
    late Map<String, Account> accounts;
    late Customer testCustomer;
    late Supplier testSupplier;
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
      test('creates balanced journal entry for simple cash sale (includes COGS & inventory)', () {
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
        // Sale 2 @ 10000 = 20000 revenue
        // COGS: 2 @ 6000 = 12000
        // Cash Dr 20000, Revenue Cr 20000, COGS Dr 12000, Inventory Cr 12000
        // Total Dr = 32000, Total Cr = 32000
        expect(result.journalEntry.totalDebit, equals(32000));
        expect(result.journalEntry.totalCredit, equals(32000));
        
        final cashLine = result.journalEntry.lines.firstWhere((l) => l.accountCode == '1010');
        expect(cashLine.debit, equals(20000));
        
        final revenueLine = result.journalEntry.lines.firstWhere((l) => l.accountCode == '4010');
        expect(revenueLine.credit, equals(20000));
        
        final cogsLine = result.journalEntry.lines.firstWhere((l) => l.accountCode == '5010');
        expect(cogsLine.debit, equals(12000)); // 2 * 6000
        
        final invLine = result.journalEntry.lines.firstWhere((l) => l.accountCode == '1030');
        expect(invLine.credit, equals(12000));
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
        // Cash 10000 Dr, AR 20000 Dr, Revenue 30000 Cr, COGS 18000 Dr, Inv 18000 Cr
        // Total Dr = 48000, Total Cr = 48000
        expect(result.journalEntry.totalDebit, equals(48000));
        expect(result.journalEntry.totalCredit, equals(48000));
      });

      test('creates commission due for consignment product', () {
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
          commissionRate: 0.20,
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
        );

        expect(result.commissionDues, isNotNull);
        expect(result.commissionDues!.length, equals(1));
        // Due = 30000 * (1 - 0.20) = 24000
        expect(result.commissionDues!.first.dueAmount, equals(24000));
        expect(result.commissionDues!.first.status, equals('pending'));
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

      test('creates balanced entry for consignment purchase (zero debt, uses 2015)', () {
        final commissionSupplier = Supplier(
          id: 's2',
          name: 'مورد أمانة',
          phone: '0599444555',
          dealType: SupplierDealType.commission,
          commissionRate: 0.25,
          createdAt: DateTime.now(),
        );

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

        expect(result.journalEntry.isBalanced, isTrue);
        // Inventory Dr 120000, Consignment Liability (2015) Cr 120000
        final invLine = result.journalEntry.lines.firstWhere((l) => l.accountCode == '1030');
        expect(invLine.debit, equals(120000));
        
        final consignmentLine = result.journalEntry.lines.firstWhere((l) => l.accountCode == '2015');
        expect(consignmentLine.credit, equals(120000));
        
        // No 2010 line should exist
        final apLines = result.journalEntry.lines.where((l) => l.accountCode == '2010');
        expect(apLines, isEmpty);
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
    });

    group('addEmployeeMovement', () {
      test('creates balanced entry for advance deduction (Dr 2030, Cr 1010)', () {
        final result = DoubleEntryEngine.addEmployeeMovement(
          requestId: 'req-30',
          employee: testEmployee,
          month: DateTime(2026, 9, 1),
          direction: 'deduct',
          category: 'advance',
          amount: 50000,
          date: DateTime(2026, 9, 9),
          note: 'سلفة نقدية',
          accounts: accounts,
        );

        expect(result.journalEntry.isBalanced, isTrue);
        expect(result.journalEntry.sourceType, equals('salary'));
        
        // Advance deduction: Dr Payable (2030) 50000, Cr Cash (1010) 50000
        final payLine = result.journalEntry.lines.firstWhere((l) => l.accountCode == '2030');
        expect(payLine.debit, equals(50000));
        
        final cashLine = result.journalEntry.lines.firstWhere((l) => l.accountCode == '1010');
        expect(cashLine.credit, equals(50000));
      });

      test('creates balanced entry for goods deduction with inventory (Dr 2030, Cr 1030)', () {
        final result = DoubleEntryEngine.addEmployeeMovement(
          requestId: 'req-31',
          employee: testEmployee,
          month: DateTime(2026, 9, 1),
          direction: 'deduct',
          category: 'goods',
          amount: 30000,
          date: DateTime(2026, 9, 9),
          note: 'صرف أصناف',
          accounts: accounts,
          product: testProduct,
        );

        expect(result.journalEntry.isBalanced, isTrue);
        
        // Goods deduction: Dr Payable (2030) 30000, Cr Inventory (1030) 30000
        final payLine = result.journalEntry.lines.firstWhere((l) => l.accountCode == '2030');
        expect(payLine.debit, equals(30000));
        
        final invLine = result.journalEntry.lines.firstWhere((l) => l.accountCode == '1030');
        expect(invLine.credit, equals(30000));
      });

      test('creates balanced entry for bonus entitlement (Dr 5030, Cr 2030)', () {
        final result = DoubleEntryEngine.addEmployeeMovement(
          requestId: 'req-32',
          employee: testEmployee,
          month: DateTime(2026, 9, 1),
          direction: 'entitle',
          category: 'bonus',
          amount: 20000,
          date: DateTime(2026, 9, 9),
          note: 'مكافأة أداء',
          accounts: accounts,
        );

        expect(result.journalEntry.isBalanced, isTrue);
        // Entitlement: Dr Wages (5030) 20000, Cr Payable (2030) 20000
        final expLine = result.journalEntry.lines.firstWhere((l) => l.accountCode == '5030');
        expect(expLine.debit, equals(20000));
        
        final payLine = result.journalEntry.lines.firstWhere((l) => l.accountCode == '2030');
        expect(payLine.credit, equals(20000));
      });
    });

    group('paySalary', () {
      test('creates balanced salary payment entry (Dr 2030, Cr 1015)', () {
        final result = DoubleEntryEngine.paySalary(
          requestId: 'req-40',
          employee: testEmployee,
          month: DateTime(2026, 9, 1),
          paidAmount: 450000,
          netDue: 450000,
          method: 'bank',
          date: DateTime(2026, 9, 25),
          note: 'راتب سبتمبر',
          accounts: accounts,
        );

        expect(result.journalEntry.isBalanced, isTrue);
        expect(result.journalEntry.sourceType, equals('salary'));
        
        // Pay salary: Dr Payable (2030) 450000, Cr Bank (1015) 450000
        final payLine = result.journalEntry.lines.firstWhere((l) => l.accountCode == '2030');
        expect(payLine.debit, equals(450000));
        
        final bankLine = result.journalEntry.lines.firstWhere((l) => l.accountCode == '1015');
        expect(bankLine.credit, equals(450000));
      });
    });

    group('adjustInventory', () {
      test('creates balanced entry for inventory increase (gain)', () {
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
        expect(result.updatedEntities!['products']['p1'], equals(105.0));
        
        // Inventory Dr 30000 (5 * 6000), Revenue Cr 30000
        final invLine = result.journalEntry.lines.firstWhere((l) => l.accountCode == '1030');
        expect(invLine.debit, equals(30000));
        
        final revLine = result.journalEntry.lines.firstWhere((l) => l.accountCode == '4020');
        expect(revLine.credit, equals(30000));
      });

      test('creates balanced entry for inventory decrease (loss)', () {
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
        expect(result.updatedEntities!['products']['p1'], equals(95.0));
        
        // Expense Dr 30000, Inventory Cr 30000
        final expLine = result.journalEntry.lines.firstWhere((l) => l.accountCode == '5020');
        expect(expLine.debit, equals(30000));
        
        final invLine = result.journalEntry.lines.firstWhere((l) => l.accountCode == '1030');
        expect(invLine.credit, equals(30000));
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