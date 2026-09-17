import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasad_erp/core/error/app_exception.dart';
import 'package:hasad_erp/data/offline/local_database.dart';
import 'package:hasad_erp/data/offline/local_store.dart';
import 'package:hasad_erp/data/offline/offline_write.dart';
import 'package:hasad_erp/domain/employees/employee_draft.dart';
import 'package:hasad_erp/domain/invoices/invoice.dart';
import 'package:hasad_erp/domain/journal/manual_journal_draft.dart';
import 'package:hasad_erp/domain/payments/payment_repository.dart';
import 'package:hasad_erp/domain/products/product.dart';
import 'package:hasad_erp/domain/products/product_draft.dart';
import 'package:hasad_erp/domain/purchases/purchase_invoice_draft.dart';
import 'package:hasad_erp/domain/salaries/salary_repository.dart';
import 'package:hasad_erp/domain/sales/sale_invoice_draft.dart';

void main() {
  late AppDatabase db;
  late DriftLocalStore store;
  late OfflineWriteCoordinator writer;

  const tenant = 'tenant-a';

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = DriftLocalStore(db);
    writer = OfflineWriteCoordinator(store, tenant);
  });

  tearDown(() => db.close());

  Future<void> seed() async {
    Future<void> upsertAccount(
        String id, String code, String name, String type) async {
      await store.upsertAccount(LocalAccountRow(
        id: id, tenantId: tenant, code: code, name: name, type: type,
        parentCode: null,
      ));
    }

    await upsertAccount('a1', '1010', 'نقدية', 'asset');
    await upsertAccount('a2', '1015', 'بنك', 'asset');
    await upsertAccount('a3', '1020', 'ذمم مدينة', 'asset');
    await upsertAccount('a4', '1030', 'مخزون', 'asset');
    await upsertAccount('a5', '2010', 'ذمم دائنة', 'liability');
    await upsertAccount('a6', '2030', 'مستحقات موظفين', 'liability');
    await upsertAccount('a7', '4010', 'إيرادات مبيعات', 'revenue');
    await upsertAccount('a8', '5030', 'أجور', 'expense');

    await store.upsertCustomer(LocalCustomerRow(
      id: 'c1', tenantId: tenant, name: 'عميل', phone: '0599111222',
      notes: null, createdAt: DateTime(2026, 1, 1), synced: false,
    ));

    await store.upsertSupplier(LocalSupplierRow(
      id: 's1', tenantId: tenant, name: 'مورد مباشر', phone: null, notes: null,
      dealType: 'direct', commissionRate: null, createdAt: DateTime(2026, 1, 1),
      synced: false,
    ));
    await store.upsertSupplier(LocalSupplierRow(
      id: 's2', tenantId: tenant, name: 'مورد أمانة', phone: null, notes: null,
      dealType: 'commission', commissionRate: 20,
      createdAt: DateTime(2026, 1, 1), synced: false,
    ));

    await store.upsertProduct(LocalProductRow(
      id: 'p1', tenantId: tenant, name: 'سلعة مباشرة', barcode: null,
      unit: 'قطعة', unitType: 'count', salePrice: 10000, purchasePrice: 6000,
      qty: 100, reorderLevel: 10, supplierId: 's1', commissionRate: null,
      createdAt: DateTime(2026, 1, 1), synced: false,
    ));
    await store.upsertProduct(LocalProductRow(
      id: 'p2', tenantId: tenant, name: 'سلعة أمانة', barcode: null,
      unit: 'قطعة', unitType: 'count', salePrice: 15000, purchasePrice: 8000,
      qty: 50, reorderLevel: 5, supplierId: 's2', commissionRate: 20,
      createdAt: DateTime(2026, 1, 1), synced: false,
    ));

    await store.upsertEmployee(LocalEmployeeRow(
      id: 'e1', tenantId: tenant, name: 'موظف', jobTitle: 'sales',
      phone: null, baseSalary: 500000, createdAt: DateTime(2026, 1, 1),
      synced: false,
    ));
  }

  group('writeSale', () {
    test('cash sale mirrors invoice, drops stock, queues RPC, pending', () async {
      await seed();

      final result = await writer.writeSale(SaleInvoiceDraft(
        customerId: 'c1',
        lines: [SaleLineDraft(productId: 'p1', qty: 2, price: 10000)],
        date: DateTime(2026, 9, 9),
        paid: 20000,
        paymentMethod: 'cash',
        memo: 'نقدي',
      ));

      expect(result.pending, isTrue);
      expect(result.total, 20000);
      expect(result.remaining, 0);
      expect(result.status, InvoiceStatus.paid);
      expect(result.no, startsWith('D-'));

      final invoiceRows = await store.invoices(tenant, type: 'sale');
      expect(invoiceRows, hasLength(1));
      expect(invoiceRows.single.synced, isFalse);
      expect(invoiceRows.single.requestId, isNotNull);
      expect(invoiceRows.single.status, 'paid');

      final items = await store.invoiceItems(result.invoiceId);
      expect(items.single.qty, 2);
      expect(items.single.total, 20000);

      final qty =
          (await store.products(tenant)).firstWhere((r) => r.id == 'p1');
      expect(qty.qty, 98);

      final entries = await store.journalEntries(tenant);
      expect(entries, hasLength(1));
      expect(entries.single.sourceType, 'sale');

      final queued = (await store.pendingSync(tenant)).single;
      expect(queued.rpc, 'create_sale_invoice');
      expect(queued.requestId, invoiceRows.single.requestId);
      final params = jsonDecode(queued.params) as Map<String, dynamic>;
      expect(params['p_request_id'], queued.requestId);
      expect(params['p_customer_id'], 'c1');
    });

    test('commission product sale creates a commission due', () async {
      await seed();

      final result = await writer.writeSale(SaleInvoiceDraft(
        customerId: 'c1',
        lines: [SaleLineDraft(productId: 'p2', qty: 2, price: 15000)],
        date: DateTime(2026, 9, 9),
        paid: 0,
      ));

      expect(result.status, InvoiceStatus.unpaid);
      final dues = await store.commissionDues(tenant, supplierId: 's2');
      expect(dues, hasLength(1));
      expect(dues.single.dueAmount, 24000); // 30000 - 20% commission
      expect(dues.single.status, 'pending');
      expect(dues.single.invoiceId, result.invoiceId);
    });

    test('missing customer surfaces ValidationException', () async {
      await seed();
      await expectLater(
        writer.writeSale(SaleInvoiceDraft(
          customerId: 'nope',
          lines: [SaleLineDraft(productId: 'p1', qty: 1)],
        )),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  group('writePurchase', () {
    test('owned purchase mirrors invoice + stock increase', () async {
      await seed();

      final result = await writer.writePurchase(PurchaseInvoiceDraft(
        supplierId: 's1',
        lines: [PurchaseLineDraft(productId: 'p1', qty: 10, price: 6000)],
        date: DateTime(2026, 9, 9),
        memo: 'مشتريات',
      ));

      expect(result.pending, isTrue);
      expect(result.ownership, InvoiceOwnership.owned);
      expect(result.total, 60000);
      expect(result.remaining, 60000);

      final invoices = await store.invoices(tenant, type: 'purchase');
      expect(invoices.single.synced, isFalse);
      expect(invoices.single.remaining, 60000);

      final qty =
          (await store.products(tenant)).firstWhere((r) => r.id == 'p1');
      expect(qty.qty, 110);

      final entries = await store.journalEntries(tenant);
      expect(entries.single.sourceType, 'purchase');
      final lines = jsonDecode(entries.single.lines) as List;
      expect(lines, hasLength(2)); // Dr 1030 + Cr 2010

      expect(
        (await store.pendingSync(tenant)).single.rpc,
        'create_purchase_invoice',
      );
    });

    test('consignment receipt posts NO journal but adds stock', () async {
      await seed();

      final result = await writer.writePurchase(PurchaseInvoiceDraft(
        supplierId: 's2',
        lines: [PurchaseLineDraft(productId: 'p2', qty: 20, price: 8000)],
        date: DateTime(2026, 9, 9),
      ));

      expect(result.ownership, InvoiceOwnership.consignment);
      expect(result.remaining, result.total);
      expect(result.status, InvoiceStatus.unpaid);

      final invoices = await store.invoices(tenant, type: 'purchase');
      expect(invoices.single.ownership, 'consignment');
      expect(invoices.single.paid, 0);

      final qty =
          (await store.products(tenant)).firstWhere((r) => r.id == 'p2');
      expect(qty.qty, 70);

      expect(await store.journalEntries(tenant), isEmpty);
    });

    test('inline new product lands in the mirror with received qty', () async {
      await seed();

      final result = await writer.writePurchase(PurchaseInvoiceDraft(
        supplierId: 's1',
        lines: [
          PurchaseLineDraft(
            newProduct: NewProductDraft(
              name: 'سلعة المستوردة',
              unit: 'قطعة',
              salePrice: 12000,
            ),
            qty: 15,
            price: 7000,
          ),
        ],
      ));

      final products = await store.products(tenant);
      final product =
          products.firstWhere((r) => r.name == 'سلعة المستوردة');
      expect(product.qty, 15);
      expect(product.purchasePrice, 7000);
      expect(product.supplierId, 's1');

      final items = await store.invoiceItems(result.invoiceId);
      expect(items.single.productId, product.id);
    });
  });

  group('recordPayment', () {
    test('payment reduces local invoice and queues record_payment', () async {
      await seed();
      await store.upsertInvoice(LocalInvoiceRow(
        id: 'inv-1', tenantId: tenant, type: 'sale', no: 'SAL-001',
        partyId: 'c1', partyName: 'عميل', date: DateTime(2026, 9, 1),
        subtotal: 50000, total: 50000, paid: 0, remaining: 50000,
        status: 'unpaid', ownership: 'owned', requestId: 'r0', synced: true,
        createdAt: null,
      ));

      final result = await writer.recordPayment(PaymentDraft(
        invoiceId: 'inv-1',
        amount: 20000,
        method: 'bank',
        date: DateTime(2026, 9, 9),
      ));

      expect(result.pending, isTrue);
      expect(result.paid, 20000);
      expect(result.remaining, 30000);
      expect(result.status, 'partial');

      final invoice = (await store.invoices(tenant)).single;
      expect(invoice.paid, 20000);
      expect(invoice.remaining, 30000);
      expect(invoice.status, 'partial');
      expect(invoice.synced, isTrue); // server-mirrored row keeps its flag

      final payments = await store.payments(tenant);
      expect(payments.single.synced, isFalse);
      expect(payments.single.requestId, isNotNull);

      expect(
        (await store.pendingSync(tenant)).single.rpc,
        'record_payment',
      );
    });

    test('overpayment is rejected as ValidationException', () async {
      await seed();
      await store.upsertInvoice(LocalInvoiceRow(
        id: 'inv-1', tenantId: tenant, type: 'sale', no: 'SAL-001',
        partyId: 'c1', partyName: 'عميل', date: DateTime(2026, 9, 1),
        subtotal: 50000, total: 50000, paid: 0, remaining: 50000,
        status: 'unpaid', ownership: 'owned', requestId: 'r0', synced: true,
        createdAt: null,
      ));

      await expectLater(
        writer.recordPayment(PaymentDraft(
          invoiceId: 'inv-1',
          amount: 99999,
          method: 'cash',
        )),
        throwsA(isA<ValidationException>()),
      );
      expect(await store.pendingSync(tenant), isEmpty);
    });
  });

  group('settleSupplier', () {
    test('oldest-first across owned invoice then dues', () async {
      await seed();
      await store.upsertInvoice(LocalInvoiceRow(
        id: 'pi-1', tenantId: tenant, type: 'purchase', no: 'PUR-001',
        partyId: 's1', partyName: 'مورد مباشر', date: DateTime(2026, 8, 1),
        subtotal: 40000, total: 40000, paid: 0, remaining: 40000,
        status: 'unpaid', ownership: 'owned', requestId: 'r1', synced: true,
        createdAt: DateTime(2026, 8, 1),
      ));
      await store.upsertCommissionDue(LocalCommissionDueRow(
        id: 'due-1', tenantId: tenant, invoiceId: 'pi-1', productId: 'p2',
        supplierId: 's1', dueAmount: 15000, status: 'pending',
        createdAt: DateTime(2026, 8, 10),
      ));

      final result = await writer.settleSupplier(SettlementDraft(
        supplierId: 's1',
        amount: 50000,
        method: 'bank',
        date: DateTime(2026, 9, 9),
      ));

      expect(result.pending, isTrue);
      expect(result.total, 50000);
      expect(result.invoicesCount, 1);
      expect(result.duesCount, 1);
      expect(result.allocations.first.invoiceId, 'pi-1');
      expect(result.allocations.first.amount, 40000);
      expect(result.allocations[1].dueId, 'due-1');
      expect(result.allocations[1].amount, 10000);

      final invoice = (await store.invoices(tenant)).single;
      expect(invoice.remaining, 0);
      expect(invoice.status, 'paid');

      final due = (await store.commissionDues(tenant, supplierId: 's1')).single;
      expect(due.status, 'pending'); // not fully covered -> stays pending

      final payRows = await store.payments(tenant);
      expect(payRows.single.invoiceId, isNull);
      expect((await store.pendingSync(tenant)).single.rpc, 'settle_supplier');
    });

    test('full-coverage due flips to paid', () async {
      await seed();
      await store.upsertInvoice(LocalInvoiceRow(
        id: 'pi-1', tenantId: tenant, type: 'purchase', no: 'PUR-001',
        partyId: 's1', partyName: 'مورد مباشر', date: DateTime(2026, 8, 1),
        subtotal: 40000, total: 40000, paid: 0, remaining: 40000,
        status: 'unpaid', ownership: 'owned', requestId: 'r1', synced: true,
        createdAt: DateTime(2026, 8, 1),
      ));
      await store.upsertCommissionDue(LocalCommissionDueRow(
        id: 'due-1', tenantId: tenant, invoiceId: 'pi-1', productId: 'p2',
        supplierId: 's1', dueAmount: 15000, status: 'pending',
        createdAt: DateTime(2026, 8, 10),
      ));

      await writer.settleSupplier(SettlementDraft(
        supplierId: 's1',
        amount: 55000,
        method: 'cash',
      ));

      final due = (await store.commissionDues(tenant, supplierId: 's1')).single;
      expect(due.status, 'paid');
    });
  });

  group('movements & salary', () {
    test('advance movement queues without journal and returns value', () async {
      await seed();

      final result = await writer.addMovement(MovementDraft(
        employeeId: 'e1',
        month: DateTime(2026, 9, 1),
        direction: 'out',
        category: 'advance',
        amount: 50000,
        description: 'سلفة',
      ));

      expect(result.pending, isTrue);
      expect(result.amount, 50000);

      final movements = await store.employeeMovements(tenant,
          employeeId: 'e1');
      expect(movements.single.synced, isFalse);
      expect(movements.single.direction, 'out');
      expect(movements.single.amount, 50000);
      expect(movements.single.month, '2026-09');

      expect(await store.journalEntries(tenant), isEmpty);
      expect(
        (await store.pendingSync(tenant)).single.rpc,
        'add_employee_movement',
      );
    });

    test('product deduction moves stock by cost', () async {
      await seed();

      final result = await writer.addMovement(MovementDraft(
        employeeId: 'e1',
        month: DateTime(2026, 9, 1),
        direction: 'out',
        category: 'product',
        productId: 'p1',
        qty: 5,
        description: 'صرف أصناف',
      ));

      // 5 x 6000 (cost) = 30000, stock 100 -> 95.
      expect(result.amount, 30000);
      final qty =
          (await store.products(tenant)).firstWhere((r) => r.id == 'p1');
      expect(qty.qty, 95);
      final movements = await store.employeeMovements(tenant,
          employeeId: 'e1');
      expect(movements.single.amount, 30000);
    });

    test('paySalary clears arrears and books wage expense', () async {
      await seed();
      // Prior month: base 500000, paid 400000 -> arrears 100000.
      await store.upsertSalary(LocalSalaryRow(
        id: 'sal-old', tenantId: tenant, employeeId: 'e1', month: '2026-08',
        paid: 400000, netDue: 500000, requestId: 'ro', synced: true,
        createdAt: DateTime(2026, 8, 25),
      ));
      // This month's advance deduction reduces net due.
      await store.upsertEmployeeMovement(LocalEmployeeMovementRow(
        id: 'mov-1', tenantId: tenant, employeeId: 'e1', month: '2026-09',
        direction: 'out', category: 'advance', amount: 50000,
        date: DateTime(2026, 9, 5), note: null, requestId: 'rm',
        synced: true, createdAt: DateTime(2026, 9, 5),
      ));

      final result = await writer.paySalary(SalaryDraft(
        employeeId: 'e1',
        month: DateTime(2026, 9, 1),
        paid: 400000,
        method: 'bank',
        date: DateTime(2026, 9, 25),
      ));

      expect(result.pending, isTrue);
      expect(result.netDue, 550000); // 500000 + 100000 - 50000
      expect(result.arrears, 100000);
      expect(result.arrearsCarried, 150000);

      final salaries = await store.salaries(tenant, employeeId: 'e1');
      expect(salaries, hasLength(2));
      expect(salaries.last.synced, isFalse);
      expect(salaries.last.paid, 400000);

      final entry = (await store.journalEntries(tenant)).single;
      final lines = jsonDecode(entry.lines) as List;
      int legs(String code, String side) => lines
          .where((l) => l['account_code'] == code && (l[side] as int) > 0)
          .length;
      expect(legs('2030', 'debit'), 1); // arrears cleared
      expect(legs('5030', 'debit'), 1); // wage expense
      expect(legs('1015', 'credit'), 1); // bank outflow
      expect(legs('2030', 'credit'), 1); // carry-forward arrears

      expect((await store.pendingSync(tenant)).single.rpc, 'pay_salary');
    });
  });

  group('createJournal', () {
    test('unbalanced entry is rejected before queueing', () async {
      await seed();
      await expectLater(
        writer.createJournal(ManualJournalDraft(
          date: DateTime(2026, 9, 9),
          memo: 'قيد',
          lines: [
            ManualJournalLineDraft(accountId: 'a1', debit: 1000),
          ],
        )),
        throwsA(isA<ValidationException>()),
      );
      expect(await store.pendingSync(tenant), isEmpty);
    });

    test('balanced entry lands in mirrors and queue', () async {
      await seed();

      final result = await writer.createJournal(ManualJournalDraft(
        date: DateTime(2026, 9, 9),
        memo: 'قيد يدوي',
        lines: [
          ManualJournalLineDraft(accountId: 'a1', debit: 1500),
          ManualJournalLineDraft(accountId: 'a5', credit: 1500),
        ],
      ));

      expect(result.pending, isTrue);
      expect(result.total, 1500);

      final entry = (await store.journalEntries(tenant)).single;
      expect(entry.sourceType, 'manual');
      final lines = jsonDecode(entry.lines) as List;
      expect(lines, hasLength(2));
      expect(lines.first['account_code'], '1010');

      final queued = (await store.pendingSync(tenant)).single;
      expect(queued.rpc, 'create_journal_entry');
      expect(queued.localId, result.entryId);
    });
  });

  group('master writes (product/employee table_crud)', () {
    test('writeProduct mirrors synced:false and enqueues a table_crud upsert',
        () async {
      final product = await writer.writeProduct(const ProductDraft(
        name: 'سلعة جديدة',
        barcode: 'BAR-1',
        unit: 'كيلو',
        unitType: ProductUnitType.weight,
        salePrice: 25000,
        purchasePrice: 15000,
        qty: 12,
        reorderLevel: 3,
        supplierId: 's1',
        commissionRate: 10,
      ));

      final row = (await store.products(tenant)).single;
      expect(row.synced, isFalse);
      expect(row.name, 'سلعة جديدة');
      expect(row.unitType, 'weight');
      expect(row.qty, 12);
      expect(product.id, row.id);
      expect(product.salePrice, 25000);
      expect(product.purchasePrice, 15000);

      final queued = (await store.pendingSync(tenant)).single;
      expect(queued.rpc, 'table:products');
      expect(queued.op, 'table_crud');
      expect(queued.entity, 'products');
      expect(queued.localId, product.id);
      final params = jsonDecode(queued.params) as Map<String, dynamic>;
      expect(params['name'], 'سلعة جديدة');
      expect(params['unit_type'], 'weight');
      expect(params['supplier_id'], 's1');
    });

    test('updateProduct rewires the mirror and enqueues a table_crud update',
        () async {
      await seed();
      await writer.updateProduct(
        'p1',
        const ProductDraft(
          name: 'سلعة محدثة',
          unit: 'قطعة',
          unitType: ProductUnitType.count,
          salePrice: 22000,
          purchasePrice: 12000,
          qty: 5,
          reorderLevel: 2,
        ),
      );

      final row =
          (await store.products(tenant)).firstWhere((r) => r.id == 'p1');
      expect(row.synced, isFalse);
      expect(row.name, 'سلعة محدثة');
      expect(row.salePrice, 22000);

      final queued = (await store.pendingSync(tenant)).single;
      expect(queued.rpc, 'table:products');
      expect(queued.op, 'table_crud');
      expect(queued.localId, 'p1');
      final params = jsonDecode(queued.params) as Map<String, dynamic>;
      expect(params['id'], 'p1');
      expect((params['row'] as Map<String, dynamic>)['name'], 'سلعة محدثة');
    });

    test('deleteProduct enqueues a table_crud delete without a store delete',
        () async {
      await seed();
      await writer.deleteProduct('p1');

      // No soft-delete exists on LocalStore; the mirror row stays put until
      // the queue is flushed and the server delete is replayed.
      expect(
        (await store.products(tenant)).any((r) => r.id == 'p1'),
        isTrue,
      );
      final queued = (await store.pendingSync(tenant)).single;
      expect(queued.rpc, 'table:products');
      expect(queued.op, 'table_crud');
      expect(queued.entity, 'products');
      expect(queued.localId, 'p1');
      expect(jsonDecode(queued.params), {'id': 'p1'});
    });

    test('writeEmployee mirrors synced:false and enqueues a table_crud upsert',
        () async {
      final employee = await writer.writeEmployee(const EmployeeDraft(
        name: 'موظف جديد',
        jobTitle: 'محاسب',
        phone: '0599222333',
        baseSalary: 800000,
      ));

      final row = (await store.employees(tenant)).single;
      expect(row.synced, isFalse);
      expect(row.name, 'موظف جديد');
      expect(row.jobTitle, 'محاسب');
      expect(row.baseSalary, 800000);
      expect(employee.id, row.id);

      final queued = (await store.pendingSync(tenant)).single;
      expect(queued.rpc, 'table:employees');
      expect(queued.op, 'table_crud');
      expect(queued.entity, 'employees');
      expect(queued.localId, employee.id);
      final params = jsonDecode(queued.params) as Map<String, dynamic>;
      expect(params['base_salary'], 800000);
      expect(params['job_title'], 'محاسب');
    });

    test('updateEmployee rewires the mirror and enqueues a table_crud update',
        () async {
      await seed();
      await writer.updateEmployee(
        'e1',
        const EmployeeDraft(
          name: 'موظف محدث',
          jobTitle: 'sales',
          phone: '0599000111',
          baseSalary: 900000,
        ),
      );

      final row = (await store.employees(tenant)).single;
      expect(row.synced, isFalse);
      expect(row.name, 'موظف محدث');
      expect(row.baseSalary, 900000);

      final queued = (await store.pendingSync(tenant)).single;
      expect(queued.rpc, 'table:employees');
      expect(queued.op, 'table_crud');
      expect(queued.localId, 'e1');
      final params = jsonDecode(queued.params) as Map<String, dynamic>;
      expect(params['id'], 'e1');
      expect((params['row'] as Map<String, dynamic>)['name'], 'موظف محدث');
    });

    test('deleteEmployee enqueues a table_crud delete without a store delete',
        () async {
      await seed();
      await writer.deleteEmployee('e1');

      expect(
        (await store.employees(tenant)).any((r) => r.id == 'e1'),
        isTrue,
      );
      final queued = (await store.pendingSync(tenant)).single;
      expect(queued.rpc, 'table:employees');
      expect(queued.op, 'table_crud');
      expect(queued.localId, 'e1');
      expect(jsonDecode(queued.params), {'id': 'e1'});
    });
  });
}