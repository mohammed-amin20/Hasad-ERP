import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasad_erp/core/error/app_exception.dart';
import 'package:hasad_erp/data/offline/local_database.dart';
import 'package:hasad_erp/data/offline/local_store.dart';
import 'package:hasad_erp/data/offline/offline_write.dart';
import 'package:hasad_erp/domain/accounts/account.dart' as ch;
import 'package:hasad_erp/domain/customers/customer_draft.dart';
import 'package:hasad_erp/domain/employees/employee_draft.dart';
import 'package:hasad_erp/domain/invoices/invoice.dart';
import 'package:hasad_erp/domain/journal/manual_journal_draft.dart';
import 'package:hasad_erp/domain/payments/payment_repository.dart';
import 'package:hasad_erp/domain/products/product.dart';
import 'package:hasad_erp/domain/products/product_draft.dart';
import 'package:hasad_erp/domain/purchases/purchase_invoice_draft.dart';
import 'package:hasad_erp/domain/salaries/salary_repository.dart';
import 'package:hasad_erp/domain/sales/sale_invoice_draft.dart';
import 'package:hasad_erp/domain/suppliers/supplier.dart';
import 'package:hasad_erp/domain/suppliers/supplier_draft.dart';

import 'delegating_local_store.dart';

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

  Future<void> seed([DriftLocalStore? target]) async {
    final s = target ?? store;
    Future<void> upsertAccount(
        String id, String code, String name, String type) async {
      await s.upsertAccount(LocalAccountRow(
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

    await s.upsertCustomer(LocalCustomerRow(
      id: 'c1', tenantId: tenant, name: 'عميل', phone: '0599111222',
      notes: null, createdAt: DateTime(2026, 1, 1), synced: false,
    ));

    await s.upsertSupplier(LocalSupplierRow(
      id: 's1', tenantId: tenant, name: 'مورد مباشر', phone: null, notes: null,
      dealType: 'direct', commissionRate: null, createdAt: DateTime(2026, 1, 1),
      synced: false,
    ));
    await s.upsertSupplier(LocalSupplierRow(
      id: 's2', tenantId: tenant, name: 'مورد أمانة', phone: null, notes: null,
      dealType: 'commission', commissionRate: 20,
      createdAt: DateTime(2026, 1, 1), synced: false,
    ));

    await s.upsertProduct(LocalProductRow(
      id: 'p1', tenantId: tenant, name: 'سلعة مباشرة', barcode: null,
      unit: 'قطعة', unitType: 'count', salePrice: 10000, purchasePrice: 6000,
      qty: 100, reorderLevel: 10, supplierId: 's1', commissionRate: null,
      createdAt: DateTime(2026, 1, 1), synced: false,
    ));
    await s.upsertProduct(LocalProductRow(
      id: 'p2', tenantId: tenant, name: 'سلعة أمانة', barcode: null,
      unit: 'قطعة', unitType: 'count', salePrice: 15000, purchasePrice: 8000,
      qty: 50, reorderLevel: 5, supplierId: 's2', commissionRate: 20,
      createdAt: DateTime(2026, 1, 1), synced: false,
    ));

    await s.upsertEmployee(LocalEmployeeRow(
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

    test(
        'inline new product queues a table:products leg and the purchase leg'
        ' refers to it by product_id', () async {
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
      final product = products.firstWhere((r) => r.name == 'سلعة المستوردة');
      expect(product.qty, 15);
      expect(product.purchasePrice, 7000);
      expect(product.supplierId, 's1');

      final items = await store.invoiceItems(result.invoiceId);
      expect(items.single.productId, product.id);

      // TWO legs: the inline product's `table:products` leg and the purchase
      // RPC that names that same product id instead of `new_product`.
      final legs = await store.pendingSync(tenant);
      expect(legs, hasLength(2));

      final productLeg = legs.firstWhere((l) => l.rpc == 'table:products');
      expect(productLeg.op, 'table_crud');
      expect(productLeg.entity, 'products');
      // The server mirrors this uuid via tableUpsert's `onConflict: 'id'`, so
      // the server row id == local mirror id — no duplicate after a refresh.
      expect(productLeg.localId, product.id);
      final pParams = jsonDecode(productLeg.params) as Map<String, dynamic>;
      expect(pParams['name'], 'سلعة المستوردة');
      expect(pParams['purchase_price'], 7000);
      expect(pParams['qty'], 0);
      expect(pParams['supplier_id'], 's1');
      expect(pParams['commission_rate'], isNull);

      final rpcLeg =
          legs.firstWhere((l) => l.rpc == 'create_purchase_invoice');
      expect(jsonDecode(rpcLeg.dependsOn!), [productLeg.id]);
      final params = jsonDecode(rpcLeg.params) as Map<String, dynamic>;
      final item = (params['p_items'] as List).single as Map<String, dynamic>;
      expect(item['product_id'], product.id);
      expect(item.containsKey('new_product'), isFalse);
    });

    test('owned purchase paid by bank posts Dr stock, Cr bank + Cr AP',
        () async {
      await seed();

      final result = await writer.writePurchase(PurchaseInvoiceDraft(
        supplierId: 's1',
        lines: [PurchaseLineDraft(productId: 'p1', qty: 10, price: 6000)],
        paid: 20000,
        paymentMethod: 'bank',
      ));

      expect(result.pending, isTrue);
      expect(result.total, 60000);
      expect(result.remaining, 40000);

      final invoice = (await store.invoices(tenant, type: 'purchase')).single;
      expect(invoice.paid, 20000);
      expect(invoice.remaining, 40000);
      expect(invoice.status, 'partial');

      final qty =
          (await store.products(tenant)).firstWhere((r) => r.id == 'p1');
      expect(qty.qty, 110);

      final entry = (await store.journalEntries(tenant)).single;
      final lines = jsonDecode(entry.lines) as List;
      expect(lines, hasLength(3));
      final byCode = {
        for (final l in lines) l['account_code'] as String: l as Map,
      };
      expect(byCode['1030']!['debit'], 60000);
      expect(byCode['1015']!['credit'], 20000);
      expect(byCode['2010']!['credit'], 40000);
      final debitSum =
          lines.fold<int>(0, (sum, l) => sum + (l['debit'] as int));
      final creditSum =
          lines.fold<int>(0, (sum, l) => sum + (l['credit'] as int));
      expect(debitSum, creditSum);
    });

    test('the purchase leg depends on pending supplier and product legs',
        () async {
      await seed();
      // The supplier and the product were created offline earlier, so their
      // table_crud legs are still pending; the invoice must replay after them
      // or the server would reject a missing supplier/product.
      await store.enqueue(SyncQueueRow(
        id: 'q-supplier', tenantId: tenant, rpc: 'table:suppliers',
        op: 'table_crud', params: '{}', requestId: 'req-sup',
        entity: 'suppliers', localId: 's1', status: 'pending', attempts: 0,
        lastError: null, createdAt: DateTime.utc(2026, 1, 1, 0, 0),
        updatedAt: DateTime.utc(2026, 1, 1, 0, 0),
      ));
      await store.enqueue(SyncQueueRow(
        id: 'q-product', tenantId: tenant, rpc: 'table:products',
        op: 'table_crud', params: '{}', requestId: 'req-prod',
        entity: 'products', localId: 'p1', status: 'pending', attempts: 0,
        lastError: null, createdAt: DateTime.utc(2026, 1, 1, 0, 1),
        updatedAt: DateTime.utc(2026, 1, 1, 0, 1),
      ));

      final result = await writer.writePurchase(PurchaseInvoiceDraft(
        supplierId: 's1',
        lines: [PurchaseLineDraft(productId: 'p1', qty: 1, price: 6000)],
      ));

      final legs = await store.pendingSync(tenant);
      final rpcLeg =
          legs.firstWhere((l) => l.rpc == 'create_purchase_invoice');
      expect(rpcLeg.localId, result.invoiceId);
      final deps = jsonDecode(rpcLeg.dependsOn!) as List;
      expect(deps, containsAll(['q-supplier', 'q-product']));
    });

    test('inline new product rollback leaves nothing behind', () async {
      await seed();

      // The FIRST enqueue is a table:products leg, so a store that throws on
      // enqueue proves none of the transaction — invoice, stock, journal or
      // the new product mirror row — survives.
      final poisoning = OfflineWriteCoordinator(
        _ThrowOnEnqueueStore(store),
        tenant,
      );
      await expectLater(
        poisoning.writePurchase(PurchaseInvoiceDraft(
          supplierId: 's1',
          lines: [
            PurchaseLineDraft(
              newProduct: NewProductDraft(
                name: 'منتج محلي',
                unit: 'قطعة',
                salePrice: 12000,
              ),
              qty: 2,
              price: 7000,
            ),
          ],
        )),
        throwsA(isA<AppException>()),
      );

      expect(await store.invoices(tenant, type: 'purchase'), isEmpty);
      expect(
        (await store.products(tenant)).where((r) => r.name == 'منتج محلي'),
        isEmpty,
      );
      expect(await store.journalEntries(tenant), isEmpty);
      expect(await store.pendingSync(tenant), isEmpty);
    });

    test('an offline purchase survives a restart (file-backed)', () async {
      final dir = await Directory.systemTemp.createTemp('purchase_offline');
      final file = File('${dir.path}/test.db');

      final db1 = AppDatabase(NativeDatabase(file));
      final s1 = DriftLocalStore(db1);
      final w1 = OfflineWriteCoordinator(s1, tenant);
      await seed(s1);

      final result = await w1.writePurchase(PurchaseInvoiceDraft(
        supplierId: 's1',
        lines: [PurchaseLineDraft(productId: 'p1', qty: 10, price: 6000)],
      ));
      await db1.close();

      // Reopen the same file as a fresh database: everything the offline write
      // staged must be durable across the restart.
      final db2 = AppDatabase(NativeDatabase(file));
      addTearDown(() async {
        await db2.close();
        await dir.delete(recursive: true);
      });
      final s2 = DriftLocalStore(db2);

      final invoices = await s2.invoices(tenant, type: 'purchase');
      expect(invoices.single.id, result.invoiceId);
      expect(invoices.single.synced, isFalse);
      expect(invoices.single.requestId, isNotNull);

      final items = await s2.invoiceItems(result.invoiceId);
      expect(items.single.qty, 10);

      final qty =
          (await s2.products(tenant)).firstWhere((r) => r.id == 'p1');
      expect(qty.qty, 110);

      expect((await s2.journalEntries(tenant)).single.sourceType, 'purchase');

      final legs = await s2.pendingSync(tenant);
      expect(legs.single.rpc, 'create_purchase_invoice');
      expect(legs.single.localId, result.invoiceId);
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

    test('no dependsOn when the invoice is already on the server', () async {
      await seed();
      await store.upsertInvoice(LocalInvoiceRow(
        id: 'inv-1', tenantId: tenant, type: 'sale', no: 'SAL-001',
        partyId: 'c1', partyName: 'عميل', date: DateTime(2026, 9, 1),
        subtotal: 50000, total: 50000, paid: 0, remaining: 50000,
        status: 'unpaid', ownership: 'owned', requestId: 'r0', synced: true,
        createdAt: null,
      ));

      await writer.recordPayment(PaymentDraft(
        invoiceId: 'inv-1',
        amount: 20000,
        method: 'bank',
      ));

      final leg = (await store.pendingSync(tenant)).single;
      expect(leg.dependsOn, isNull,
          reason: 'a synced invoice has no queue leg, so there is no '
              'prerequisite to defer on');
    });

    test('payment leg depends on the invoice leg when the invoice is pending',
        () async {
      // An offline sale leaves its invoice leg pending; a payment paying that
      // invoice must replay only after the parent reaches the server, or the
      // RPC rejects the payment for a missing invoice.
      await seed();
      await store.upsertInvoice(LocalInvoiceRow(
        id: 'inv-1', tenantId: tenant, type: 'sale', no: 'D-ABC123',
        partyId: 'c1', partyName: 'عميل', date: DateTime(2026, 9, 1),
        subtotal: 50000, total: 50000, paid: 0, remaining: 50000,
        status: 'unpaid', ownership: 'owned', requestId: 'r0', synced: false,
        createdAt: null,
      ));
      await store.enqueue(SyncQueueRow(
        id: 'q-inv', tenantId: tenant, rpc: 'create_sale_invoice',
        op: 'rpc', params: '{}', requestId: 'r0', entity: 'invoices',
        localId: 'inv-1', status: 'pending', attempts: 0, lastError: null,
        createdAt: DateTime.utc(2026, 9, 1),
        updatedAt: DateTime.utc(2026, 9, 1),
      ));

      await writer.recordPayment(PaymentDraft(
        invoiceId: 'inv-1',
        amount: 20000,
        method: 'cash',
      ));

      final legs = await store.pendingSync(tenant)
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      final leg = legs.last;
      expect(leg.rpc, 'record_payment');
      expect(leg.dependsOn, jsonEncode(['q-inv']));
    });

    test('recordPayment rolls back everything when the enqueue throws',
        () async {
      // Atomicity pin: the coordinator's FINAL step is the queue `enqueue`. A
      // store that throws there has already staged the invoice change, the
      // payment row and the journal inside the transaction — none of it may
      // survive a transaction that aborts.
      await seed();
      await store.upsertInvoice(LocalInvoiceRow(
        id: 'inv-1', tenantId: tenant, type: 'sale', no: 'SAL-001',
        partyId: 'c1', partyName: 'عميل', date: DateTime(2026, 9, 1),
        subtotal: 50000, total: 50000, paid: 0, remaining: 50000,
        status: 'unpaid', ownership: 'owned', requestId: 'r0', synced: true,
        createdAt: null,
      ));

      final poisoning = OfflineWriteCoordinator(
        _ThrowOnEnqueueStore(store),
        tenant,
      );
      await expectLater(
        poisoning.recordPayment(PaymentDraft(
          invoiceId: 'inv-1',
          amount: 20000,
          method: 'cash',
        )),
        throwsA(isA<AppException>()),
      );

      final invoice = (await store.invoices(tenant)).single;
      expect(invoice.paid, 0, reason: 'the payment must not outlive the leg');
      expect(invoice.remaining, 50000);
      expect(await store.payments(tenant), isEmpty);
      expect(await store.journalEntries(tenant), isEmpty);
      expect(await store.pendingSync(tenant), isEmpty);
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

    test('settlement leg depends on pending parent legs it allocates',
        () async {
      // Two offline writes feed this settlement: a purchase invoice that is
      // still a pending leg, and a commission due whose SALE invoice (the sale
      // that created the commission) is also still pending. Both parents must
      // reach the server before the settlement replays, or the money would
      // mis-allocate against rows the server has never seen.
      await seed();
      await store.upsertInvoice(LocalInvoiceRow(
        id: 'pi-1', tenantId: tenant, type: 'purchase', no: 'PUR-001',
        partyId: 's1', partyName: 'مورد مباشر', date: DateTime(2026, 8, 1),
        subtotal: 40000, total: 40000, paid: 0, remaining: 40000,
        status: 'unpaid', ownership: 'owned', requestId: 'r1', synced: false,
        createdAt: DateTime(2026, 8, 1),
      ));
      await store.enqueue(SyncQueueRow(
        id: 'q-pi', tenantId: tenant, rpc: 'create_purchase_invoice',
        op: 'rpc', params: '{}', requestId: 'r1', entity: 'invoices',
        localId: 'pi-1', status: 'pending', attempts: 0, lastError: null,
        createdAt: DateTime.utc(2026, 8, 1),
        updatedAt: DateTime.utc(2026, 8, 1),
      ));
      // The due was created by a sale leg that is also still pending.
      await store.upsertCommissionDue(LocalCommissionDueRow(
        id: 'due-1', tenantId: tenant, invoiceId: 'sale-1', productId: 'p2',
        supplierId: 's1', dueAmount: 15000, status: 'pending',
        createdAt: DateTime.utc(2026, 8, 10),
      ));
      await store.enqueue(SyncQueueRow(
        id: 'q-sale', tenantId: tenant, rpc: 'create_sale_invoice',
        op: 'rpc', params: '{}', requestId: 'r2', entity: 'invoices',
        localId: 'sale-1', status: 'pending', attempts: 0, lastError: null,
        createdAt: DateTime.utc(2026, 8, 10),
        updatedAt: DateTime.utc(2026, 8, 10),
      ));

      await writer.settleSupplier(SettlementDraft(
        supplierId: 's1',
        amount: 50000, // covers the invoice (40000) + part of the due (10000)
        method: 'bank',
      ));

      final legs = await store.pendingSync(tenant)
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      final leg = legs.last;
      expect(leg.rpc, 'settle_supplier');
      final deps = (jsonDecode(leg.dependsOn!) as List).cast<String>();
      expect(deps, containsAll(<String>['q-pi', 'q-sale']));
    });

    test('no dependsOn when every parent is already on the server', () async {
      await seed();
      await store.upsertInvoice(LocalInvoiceRow(
        id: 'pi-1', tenantId: tenant, type: 'purchase', no: 'PUR-001',
        partyId: 's1', partyName: 'مورد مباشر', date: DateTime(2026, 8, 1),
        subtotal: 40000, total: 40000, paid: 0, remaining: 40000,
        status: 'unpaid', ownership: 'owned', requestId: 'r1', synced: true,
        createdAt: DateTime(2026, 8, 1),
      ));

      await writer.settleSupplier(SettlementDraft(
        supplierId: 's1',
        amount: 40000,
        method: 'cash',
      ));

      final leg = (await store.pendingSync(tenant)).single;
      expect(leg.rpc, 'settle_supplier');
      expect(leg.dependsOn, isNull);
    });

    test('settleSupplier rolls back everything when the enqueue throws',
        () async {
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

      final poisoning = OfflineWriteCoordinator(
        _ThrowOnEnqueueStore(store),
        tenant,
      );
      await expectLater(
        poisoning.settleSupplier(SettlementDraft(
          supplierId: 's1',
          amount: 50000,
          method: 'bank',
        )),
        throwsA(isA<AppException>()),
      );

      final invoice = (await store.invoices(tenant)).single;
      expect(invoice.remaining, 40000, reason: 'allocation must not survive');
      expect(invoice.status, 'unpaid');
      final due = (await store.commissionDues(tenant, supplierId: 's1')).single;
      expect(due.status, 'pending');
      expect(await store.payments(tenant), isEmpty);
      expect(await store.journalEntries(tenant), isEmpty);
      expect(await store.pendingSync(tenant), isEmpty);
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

    test('paySalary rejects a second payment for the same employee+month locally',
        () async {
      await seed();
      await writer.paySalary(SalaryDraft(
        employeeId: 'e1',
        month: DateTime(2026, 9, 1),
        paid: 400000,
        method: 'cash',
      ));
      await expectLater(
        writer.paySalary(SalaryDraft(
          employeeId: 'e1',
          month: DateTime(2026, 9, 1),
          paid: 500000,
          method: 'bank',
        )),
        throwsA(isA<ValidationException>().having(
          (e) => e.message,
          'message',
          'تم صرف راتب هذا الشهر مسبقاً',
        )),
      );
      expect((await store.pendingSync(tenant)).single.rpc, 'pay_salary');
      expect(await store.salaries(tenant, employeeId: 'e1'), hasLength(1));
    });

    test('addMovement rejects a missing employee locally', () async {
      await seed();
      await expectLater(
        writer.addMovement(MovementDraft(
          employeeId: 'nope',
          month: DateTime(2026, 9, 1),
          direction: 'out',
          category: 'advance',
          amount: 1000,
        )),
        throwsA(isA<ValidationException>().having(
          (e) => e.message,
          'message',
          'الموظف غير موجود محلياً',
        )),
      );
      expect(await store.pendingSync(tenant), isEmpty);
      expect(await store.employeeMovements(tenant), isEmpty);
    });

    test('paySalary rejects a missing employee locally', () async {
      await seed();
      await expectLater(
        writer.paySalary(SalaryDraft(
          employeeId: 'nope',
          month: DateTime(2026, 9, 1),
          paid: 400000,
          method: 'cash',
        )),
        throwsA(isA<ValidationException>().having(
          (e) => e.message,
          'message',
          'الموظف غير موجود محلياً',
        )),
      );
      expect(await store.pendingSync(tenant), isEmpty);
    });

    test('paySalary rejects a missing chart code with an Arabic error',
        () async {
      final db2 = AppDatabase(NativeDatabase.memory());
      addTearDown(() => db2.close());
      final store2 = DriftLocalStore(db2);
      Future<void> account(String id, String code, String type) =>
          store2.upsertAccount(LocalAccountRow(
            id: id, tenantId: tenant, code: code, name: code, type: type,
            parentCode: null,
          ));
      await account('a1', '1010', 'asset');
      await account('a2', '1015', 'asset');
      await account('a8', '5030', 'expense');
      // 2030 deliberately missing.
      await store2.upsertEmployee(LocalEmployeeRow(
        id: 'e1', tenantId: tenant, name: 'موظف', jobTitle: 'sales',
        phone: null, baseSalary: 500000, createdAt: DateTime(2026, 1, 1),
        synced: false,
      ));
      final w2 = OfflineWriteCoordinator(store2, tenant);

      await expectLater(
        w2.paySalary(SalaryDraft(
          employeeId: 'e1',
          month: DateTime(2026, 9, 1),
          paid: 400000,
          method: 'cash',
        )),
        throwsA(isA<ValidationException>().having(
          (e) => e.message,
          'message',
          'الحساب غير موجود في دليل الحسابات: 2030',
        )),
      );
      expect(await store2.pendingSync(tenant), isEmpty);
      expect(await store2.salaries(tenant), isEmpty);
      expect(await store2.journalEntries(tenant), isEmpty);
    });

    test('paySalary rejects a missing payment-method code with an Arabic error',
        () async {
      final db2 = AppDatabase(NativeDatabase.memory());
      addTearDown(() => db2.close());
      final store2 = DriftLocalStore(db2);
      Future<void> account(String id, String code, String type) =>
          store2.upsertAccount(LocalAccountRow(
            id: id, tenantId: tenant, code: code, name: code, type: type,
            parentCode: null,
          ));
      await account('a1', '1010', 'asset');
      await account('a6', '2030', 'liability');
      await account('a8', '5030', 'expense');
      // 1015 (bank) deliberately missing.
      await store2.upsertEmployee(LocalEmployeeRow(
        id: 'e1', tenantId: tenant, name: 'موظف', jobTitle: 'sales',
        phone: null, baseSalary: 500000, createdAt: DateTime(2026, 1, 1),
        synced: false,
      ));
      final w2 = OfflineWriteCoordinator(store2, tenant);

      await expectLater(
        w2.paySalary(SalaryDraft(
          employeeId: 'e1',
          month: DateTime(2026, 9, 1),
          paid: 400000,
          method: 'bank',
        )),
        throwsA(isA<ValidationException>().having(
          (e) => e.message,
          'message',
          'الحساب غير موجود في دليل الحسابات: 1015',
        )),
      );
      expect(await store2.pendingSync(tenant), isEmpty);
    });

    test('addMovement rolls back everything when the enqueue throws',
        () async {
      await seed();
      final poisoning = OfflineWriteCoordinator(
        _ThrowOnEnqueueStore(store),
        tenant,
      );
      await expectLater(
        poisoning.addMovement(MovementDraft(
          employeeId: 'e1',
          month: DateTime(2026, 9, 1),
          direction: 'out',
          category: 'product',
          productId: 'p1',
          qty: 5,
        )),
        throwsA(isA<AppException>()),
      );
      expect(await store.employeeMovements(tenant), isEmpty);
      final qty = (await store.products(tenant)).firstWhere((r) => r.id == 'p1');
      expect(qty.qty, 100, reason: 'stock move must roll back with the leg');
      expect(await store.pendingSync(tenant), isEmpty);
    });

    test('paySalary rolls back everything when the enqueue throws',
        () async {
      await seed();
      final poisoning = OfflineWriteCoordinator(
        _ThrowOnEnqueueStore(store),
        tenant,
      );
      await expectLater(
        poisoning.paySalary(SalaryDraft(
          employeeId: 'e1',
          month: DateTime(2026, 9, 1),
          paid: 400000,
          method: 'cash',
        )),
        throwsA(isA<AppException>()),
      );
      expect(await store.salaries(tenant), isEmpty);
      expect(await store.journalEntries(tenant), isEmpty);
      expect(await store.pendingSync(tenant), isEmpty);
    });

    test('the movement leg depends on pending employee and product legs',
        () async {
      await seed();
      await store.enqueue(SyncQueueRow(
        id: 'q-empl', tenantId: tenant, rpc: 'table:employees',
        op: 'table_crud', params: '{}', requestId: 'req-e',
        entity: 'employees', localId: 'e1', status: 'pending', attempts: 0,
        lastError: null, createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      ));
      await store.enqueue(SyncQueueRow(
        id: 'q-prod', tenantId: tenant, rpc: 'table:products',
        op: 'table_crud', params: '{}', requestId: 'req-p',
        entity: 'products', localId: 'p1', status: 'pending', attempts: 0,
        lastError: null, createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      ));

      final result = await writer.addMovement(MovementDraft(
        employeeId: 'e1',
        month: DateTime(2026, 9, 1),
        direction: 'out',
        category: 'product',
        productId: 'p1',
        qty: 1,
      ));

      final leg = (await store.pendingSync(tenant))
          .firstWhere((l) => l.rpc == 'add_employee_movement');
      expect(leg.localId, result.movementId);
      final deps = jsonDecode(leg.dependsOn!) as List;
      expect(deps, containsAll(['q-empl', 'q-prod']));
    });

    test('the salary leg depends on the pending employee leg', () async {
      await seed();
      await store.enqueue(SyncQueueRow(
        id: 'q-empl', tenantId: tenant, rpc: 'table:employees',
        op: 'table_crud', params: '{}', requestId: 'req-e',
        entity: 'employees', localId: 'e1', status: 'pending', attempts: 0,
        lastError: null, createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      ));

      await writer.paySalary(SalaryDraft(
        employeeId: 'e1',
        month: DateTime(2026, 9, 1),
        paid: 400000,
        method: 'cash',
      ));

      final leg =
          (await store.pendingSync(tenant)).firstWhere((l) => l.rpc == 'pay_salary');
      expect(leg.dependsOn, jsonEncode(['q-empl']));
    });

    test('no dependsOn when the employee is already on the server', () async {
      await seed();
      await writer.addMovement(MovementDraft(
        employeeId: 'e1',
        month: DateTime(2026, 9, 1),
        direction: 'out',
        category: 'advance',
        amount: 1000,
      ));
      expect((await store.pendingSync(tenant)).single.dependsOn, isNull);
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
      // no accounts leg is pending, so no dependency is recorded
      expect(queued.dependsOn, isNull);
    });

    test('an account missing from the local chart is rejected', () async {
      await seed();
      await expectLater(
        writer.createJournal(ManualJournalDraft(
          date: DateTime(2026, 9, 9),
          memo: 'قيد',
          lines: [
            ManualJournalLineDraft(accountId: 'a1', debit: 1000),
            ManualJournalLineDraft(accountId: 'ghost', credit: 1000),
          ],
        )),
        throwsA(isA<ValidationException>().having(
          (e) => e.message,
          'message',
          contains('أحد حسابات القيد غير موجود في دليل الحسابات (ghost)'),
        )),
      );
      // nothing may be mirrored or queued for a rejected entry
      expect(await store.journalEntries(tenant), isEmpty);
      expect(await store.pendingSync(tenant), isEmpty);
    });

    test('a journal on a locally-created account depends on its pending leg',
        () async {
      await seed();
      // The account was created offline: mirrored unsynced, its table_crud
      // leg still pending. The journal must replay after it or the server
      // would reject a missing account.
      await store.upsertAccount(LocalAccountRow(
        id: 'acc-offline', tenantId: tenant, code: '9999',
        name: 'حساب محلي', type: 'asset', parentCode: null,
      ));
      await store.enqueue(SyncQueueRow(
        id: 'q-account', tenantId: tenant, rpc: 'table:accounts',
        op: 'table_crud', params: '{}', requestId: 'req-acc',
        entity: 'accounts', localId: 'acc-offline', status: 'pending',
        attempts: 0, lastError: null,
        createdAt: DateTime.utc(2026, 1, 1, 0, 0),
        updatedAt: DateTime.utc(2026, 1, 1, 0, 0),
      ));

      final entry = await writer.createJournal(ManualJournalDraft(
        date: DateTime(2026, 9, 9),
        memo: 'قيد على حساب محلي',
        lines: [
          ManualJournalLineDraft(accountId: 'a1', debit: 1000),
          ManualJournalLineDraft(accountId: 'a5', credit: 500),
          ManualJournalLineDraft(accountId: 'acc-offline', credit: 500),
        ],
      ));

      final legs = await store.pendingSync(tenant);
      final leg = legs.singleWhere((r) => r.rpc == 'create_journal_entry');
      expect(leg.localId, entry.entryId);
      expect(jsonDecode(leg.dependsOn!), ['q-account']);
    });

    test('a failed queue leg rolls the entry back with its mirror', () async {
      await seed();
      final poisoning =
          OfflineWriteCoordinator(_ThrowOnEnqueueStore(store), tenant);
      await expectLater(
        poisoning.createJournal(ManualJournalDraft(
          date: DateTime(2026, 9, 9),
          memo: 'قيد',
          lines: [
            ManualJournalLineDraft(accountId: 'a1', debit: 1500),
            ManualJournalLineDraft(accountId: 'a5', credit: 1500),
          ],
        )),
        throwsA(isA<ValidationException>()),
      );
      // neither the mirror row nor any leg may outlive the failed transaction
      expect(await store.journalEntries(tenant), isEmpty);
      expect(await store.pendingSync(tenant), isEmpty);
    });

    test('manual entries survive a restart with the queue intact', () async {
      final dir =
          await Directory.systemTemp.createTemp('journal_offline_restart');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/journal.sqlite');

      final first = AppDatabase(NativeDatabase(file));
      final firstStore = DriftLocalStore(first);
      final firstWriter = OfflineWriteCoordinator(firstStore, tenant);
      await seed(firstStore);
      final result = await firstWriter.createJournal(ManualJournalDraft(
        date: DateTime(2026, 9, 9),
        memo: 'قيد يعيش عبر إعادة التشغيل',
        lines: [
          ManualJournalLineDraft(accountId: 'a1', debit: 2000),
          ManualJournalLineDraft(accountId: 'a5', credit: 2000),
        ],
      ));
      await first.close(); // drop the db and the in-memory object graph

      final second = AppDatabase(NativeDatabase(file));
      addTearDown(second.close);
      final secondStore = DriftLocalStore(second);
      final rows = await secondStore.journalEntries(tenant);
      expect(rows, hasLength(1));
      expect(rows.single.synced, isFalse);
      expect(rows.single.sourceType, 'manual');
      expect(rows.single.requestId, isNotNull);
      expect(rows.single.memo, 'قيد يعيش عبر إعادة التشغيل');

      final queued = await secondStore.pendingSync(tenant);
      expect(queued, hasLength(1));
      expect(queued.single.rpc, 'create_journal_entry');
      expect(queued.single.localId, result.entryId);
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

  group('writeSale on empty chart mirror seeds via _chart', () {
    test('fresh device sale leg succeeds after one-off chart seed', () async {
      await store.upsertCustomer(LocalCustomerRow(
        id: 'c1', tenantId: tenant, name: 'عميل', phone: '0599111222',
        notes: null, createdAt: DateTime(2026, 1, 1), synced: false,
      ));
      await store.upsertProduct(LocalProductRow(
        id: 'p1', tenantId: tenant, name: 'قمح للاختبار', barcode: null,
        unit: 'كيلوجرام', unitType: 'count', salePrice: 10000, purchasePrice: 6000,
        qty: 100, reorderLevel: 10, supplierId: 's1', commissionRate: null,
        createdAt: DateTime(2026, 1, 1), synced: false,
      ));

      final coordinator = OfflineWriteCoordinator(store, tenant, () async => [
        ch.Account(
          id: 'a1', code: '1010', name: 'النقدية',
          type: ch.AccountType.asset, balance: 0,
        ),
        ch.Account(
          id: 'a2', code: '1015', name: 'البنك',
          type: ch.AccountType.asset, balance: 0,
        ),
        ch.Account(
          id: 'a3', code: '1020', name: 'الذمم المدينة',
          type: ch.AccountType.asset, balance: 0,
        ),
        ch.Account(
          id: 'a4', code: '1030', name: 'المخزون',
          type: ch.AccountType.asset, balance: 0,
        ),
        ch.Account(
          id: 'a5', code: '2010', name: 'الذمم الدائنة',
          type: ch.AccountType.liability, balance: 0,
        ),
        ch.Account(
          id: 'a6', code: '2030', name: 'رواتب مستحقة',
          type: ch.AccountType.liability, balance: 0,
        ),
        ch.Account(
          id: 'a7', code: '4010', name: 'إيرادات المبيعات',
          type: ch.AccountType.revenue, balance: 0,
        ),
        ch.Account(
          id: 'a8', code: '5030', name: 'الأجور والرواتب',
          type: ch.AccountType.expense, balance: 0,
        ),
      ]);

      final result = await coordinator.writeSale(SaleInvoiceDraft(
        customerId: 'c1',
        lines: [SaleLineDraft(productId: 'p1', qty: 2, price: 10000)],
        date: DateTime(2026, 9, 9),
        paid: 20000,
        paymentMethod: 'cash',
        memo: 'فاتورة اختبار',
      ));

      expect(result.pending, isTrue);
      expect(result.total, 20000);
      expect(result.remaining, 0);

      final accounts = await store.accounts(tenant);
      expect(accounts, isNotEmpty);
      expect(accounts.firstWhere((a) => a.code == '1010').code, '1010');
    });
  });

  group('writeSale with no chart and no seed closure (never-online device)',
      () {
    // This is the reported production defect: a device that has never reached
    // the server had an empty local chart, the seed closure could not resolve
    // anything offline, and the leg died with
    // "دليل الحسابات غير متوفر محليا" / "Required account not found in chart
    // of accounts". The embedded 14-account baseline must make it succeed.
    late OfflineWriteCoordinator offlineOnly;

    setUp(() async {
      offlineOnly = OfflineWriteCoordinator(store, tenant);
      await store.upsertCustomer(LocalCustomerRow(
        id: 'c1', tenantId: tenant, name: 'عميل', phone: '0599111222',
        notes: null, createdAt: DateTime(2026, 1, 1), synced: false,
      ));
      await store.upsertProduct(LocalProductRow(
        id: 'p1', tenantId: tenant, name: 'منتج', barcode: null,
        unit: 'قطعة', unitType: 'count', salePrice: 10000, purchasePrice: 6000,
        qty: 100, reorderLevel: 10, supplierId: 's1', commissionRate: null,
        createdAt: DateTime(2026, 1, 1), synced: false,
      ));
    });

    test('succeeds and posts a balanced journal via the embedded baseline',
        () async {
      // No chart has ever been mirrored, and there is no seed closure at all.
      expect(await store.accounts(tenant), isEmpty);

      final result = await offlineOnly.writeSale(SaleInvoiceDraft(
        customerId: 'c1',
        lines: [SaleLineDraft(productId: 'p1', qty: 2, price: 10000)],
        date: DateTime(2026, 9, 9),
        paid: 20000,
        paymentMethod: 'cash',
        memo: 'فاتورة',
      ));

      expect(result.pending, isTrue);
      expect(result.total, 20000);
      expect(result.remaining, 0);

      // The baseline provisioned all 14 defaults, not just the 3-4 the sale
      // leg touched, so later accounting features find their accounts too.
      final accounts = await store.accounts(tenant);
      expect(accounts, hasLength(14));
      expect(
        accounts.map((a) => a.code).toSet(),
        containsAll(<String>{
          '1010', '1015', '1020', '1030', '1040',
          '2010', '2030',
          '3010', '3020',
          '4010', '4020',
          '5010', '5020', '5030',
        }),
      );
    });

    test('a balanced journal entry was written locally', () async {
      await offlineOnly.writeSale(SaleInvoiceDraft(
        customerId: 'c1',
        lines: [SaleLineDraft(productId: 'p1', qty: 2, price: 10000)],
        date: DateTime(2026, 9, 9),
        paid: 20000,
        paymentMethod: 'cash',
        memo: 'فاتورة',
      ));

      final journals = await store.journalEntries(tenant);
      expect(journals, isNotEmpty);
      final lines = jsonDecode(journals.single.lines) as List;
      // Dr cash (1010) 20000 / Cr revenue (4010) 20000 — the revenue-only
      // sale posting the server RPC also performs. The account ids are the
      // baseline placeholders, which is the honest representation for a
      // never-online device.
      expect(
        lines,
        contains(
          allOf(
            containsPair('account_code', '1010'),
            containsPair('debit', 20000),
          ),
        ),
      );
      expect(
        lines,
        contains(
          allOf(
            containsPair('account_code', '4010'),
            containsPair('credit', 20000),
          ),
        ),
      );
    });

    test('baseline is not re-seeded over an existing real chart', () async {
      // A real (server) chart already present must be left completely alone —
      // the baseline must not be layered on top of it.
      await store.upsertAccount(LocalAccountRow(
        id: 'server-1', tenantId: tenant, code: '1010', name: 'النقدية',
        type: 'asset', parentCode: null, parentId: null,
      ));
      await store.upsertAccount(LocalAccountRow(
        id: 'server-2', tenantId: tenant, code: '4010', name: 'إيرادات المبيعات',
        type: 'revenue', parentCode: null, parentId: null,
      ));

      await offlineOnly.writeSale(SaleInvoiceDraft(
        customerId: 'c1',
        lines: [SaleLineDraft(productId: 'p1', qty: 2, price: 10000)],
        date: DateTime(2026, 9, 9),
        paid: 20000,
        paymentMethod: 'cash',
        memo: 'فاتورة',
      ));

      final accounts = await store.accounts(tenant);
      // Exactly the two real rows: the baseline was not injected.
      expect(accounts, hasLength(2));
      expect(accounts.map((a) => a.id), everyElement(startsWith('server-')));
    });
  });

  group('customers master writes (table_crud)', () {
    test('writeCustomer mirrors synced:false and enqueues one table_crud leg',
        () async {
      final customer = await writer.writeCustomer(
        const CustomerDraft(name: 'عميل جديد', phone: '0599000111'),
      );

      final rows = await store.customers(tenant);
      expect(rows, hasLength(1));
      expect(rows.single.id, customer.id);
      expect(rows.single.synced, isFalse);
      expect(rows.single.name, 'عميل جديد');
      expect(rows.single.phone, '0599000111');
      expect(rows.single.createdAt, isNotNull);
      expect(customer.name, 'عميل جديد');
      expect(customer.createdAt, isNotNull);

      final legs = await store.pendingSync(tenant);
      expect(legs, hasLength(1));
      final leg = legs.single;
      expect(leg.op, 'table_crud');
      expect(leg.rpc, 'table:customers');
      expect(leg.entity, 'customers');
      expect(leg.localId, customer.id);
      expect(leg.dependsOn, isNull);
      final params = jsonDecode(leg.params) as Map<String, dynamic>;
      expect(params, containsPair('name', 'عميل جديد'));
      expect(params, containsPair('phone', '0599000111'));
    });

    test('updateCustomer preserves createdAt and enqueues an update leg',
        () async {
      final created = await writer.writeCustomer(
        const CustomerDraft(name: 'عميل', phone: '0599111222'),
      );
      final createdAt = (await store.customers(tenant)).single.createdAt;

      await writer.updateCustomer(
        created.id,
        const CustomerDraft(name: 'عميل محدث', notes: 'ملاحظة'),
      );

      final rows = await store.customers(tenant);
      expect(rows, hasLength(1));
      final row = rows.single;
      expect(row.name, 'عميل محدث');
      expect(row.notes, 'ملاحظة');
      expect(row.phone, isNull, reason: 'the update replaces the whole shape');
      expect(row.createdAt, createdAt,
          reason: 'an update must never re-stamp createdAt');
      expect(row.synced, isFalse);

      final legs = await store.pendingSync(tenant);
      expect(legs, hasLength(2));
      final update = legs.last;
      final params = jsonDecode(update.params) as Map<String, dynamic>;
      expect(params, containsPair('id', created.id));
      expect(params['row'], containsPair('name', 'عميل محدث'));
      expect(params['row'], containsPair('notes', 'ملاحظة'));
    });

    test('deleteCustomer hides the mirror and enqueues a delete leg', () async {
      final created = await writer.writeCustomer(
        const CustomerDraft(name: 'عميل', phone: '0599111222'),
      );

      await writer.deleteCustomer(created.id);

      // The mirror row survives (flipped unsynced) so a refresh can never
      // resurrect a server row the delete has not drained yet...
      final rows = await store.customers(tenant);
      expect(rows, hasLength(1));
      expect(rows.single.synced, isFalse);
      // ...but pendingDeleteIds hides it from local reads meanwhile.
      expect(await store.pendingDeleteIds(tenant, 'customers'), {created.id});

      final legs = await store.pendingSync(tenant);
      expect(legs, hasLength(2));
      final del = legs.last;
      expect(del.op, 'table_crud');
      expect(del.rpc, 'table:customers');
      expect(del.localId, created.id);
      expect(jsonDecode(del.params), containsPair('id', created.id));
      // The delete replays only after the pending create on the same customer.
      expect(jsonDecode(del.dependsOn!), [legs.first.id]);
    });

    test('deleteCustomer rejects an unknown local customer', () async {
      await expectLater(
        writer.deleteCustomer('ghost'),
        throwsA(isA<ValidationException>()),
      );
    });

    test('writeCustomer rolls back the mirror when the enqueue throws',
        () async {
      final poisoned = OfflineWriteCoordinator(
        _ThrowOnEnqueueStore(store),
        tenant,
      );
      await expectLater(
        poisoned.writeCustomer(const CustomerDraft(name: 'عميل')),
        throwsA(isA<ValidationException>()),
      );
      expect(await store.customers(tenant), isEmpty);
      expect(await store.pendingSync(tenant), isEmpty);
    });

    test('deleteCustomer rolls back the mirror flip when the enqueue throws',
        () async {
      await writer.writeCustomer(const CustomerDraft(name: 'عميل'));
      final before = (await store.customers(tenant)).single.synced;

      final poisoned = OfflineWriteCoordinator(
        _ThrowOnEnqueueStore(store),
        tenant,
      );
      await expectLater(
        poisoned.deleteCustomer((await store.customers(tenant)).single.id),
        throwsA(isA<ValidationException>()),
      );
      // Neither a delete leg nor a synced flip survives the failed tx.
      expect((await store.customers(tenant)).single.synced, before);
      expect(await store.pendingSync(tenant), hasLength(1),
          reason: 'only the original create leg remains');
    });

    test('an offline customer create survives a restart (file-backed)',
        () async {
      final dir = await Directory.systemTemp.createTemp('customer_offline');
      final file = File('${dir.path}/test.db');

      final db1 = AppDatabase(NativeDatabase(file));
      final s1 = DriftLocalStore(db1);
      final c1 = OfflineWriteCoordinator(s1, tenant);

      final created = await c1.writeCustomer(
        const CustomerDraft(name: 'عميل', phone: '0599111222'),
      );
      await c1.updateCustomer(
        created.id,
        const CustomerDraft(name: 'عميل محدث'),
      );
      await c1.deleteCustomer(created.id);
      await db1.close();

      final db2 = AppDatabase(NativeDatabase(file));
      final s2 = DriftLocalStore(db2);
      try {
        final rows = await s2.customers(tenant);
        expect(rows, hasLength(1));
        expect(rows.single.id, created.id);
        expect(rows.single.name, 'عميل محدث');
        expect(rows.single.synced, isFalse);
        expect(await s2.pendingDeleteIds(tenant, 'customers'), {created.id});
        expect(await s2.pendingSync(tenant), hasLength(3));
      } finally {
        await db2.close();
      }
    });
  });

  group('suppliers master writes (table_crud)', () {
    test('writeSupplier mirrors synced:false and enqueues one table_crud leg',
        () async {
      final supplier = await writer.writeSupplier(const SupplierDraft(
        name: 'مورد جديد',
        phone: '0599000111',
        dealType: SupplierDealType.commission,
        commissionRate: 20,
      ));

      final rows = await store.suppliers(tenant);
      expect(rows, hasLength(1));
      expect(rows.single.id, supplier.id);
      expect(rows.single.synced, isFalse);
      expect(rows.single.name, 'مورد جديد');
      expect(rows.single.phone, '0599000111');
      expect(rows.single.commissionRate, 20,
          reason: 'the mirror must keep the commission rate');
      expect(rows.single.createdAt, isNotNull);
      expect(supplier.name, 'مورد جديد');
      expect(supplier.commissionRate, 20,
          reason: 'the returned supplier must keep the commission rate');
      expect(supplier.createdAt, isNotNull);

      final legs = await store.pendingSync(tenant);
      expect(legs, hasLength(1));
      final leg = legs.single;
      expect(leg.op, 'table_crud');
      expect(leg.rpc, 'table:suppliers');
      expect(leg.entity, 'suppliers');
      expect(leg.localId, supplier.id);
      expect(leg.dependsOn, isNull);
      final params = jsonDecode(leg.params) as Map<String, dynamic>;
      expect(params, containsPair('name', 'مورد جديد'));
      expect(params, containsPair('phone', '0599000111'));
      expect(params, containsPair('commission_rate', 20));
    });

    test('updateSupplier preserves createdAt and enqueues an update leg',
        () async {
      final created = await writer
          .writeSupplier(const SupplierDraft(name: 'مورد', phone: '0599111222', dealType: SupplierDealType.direct));
      final createdAt = (await store.suppliers(tenant)).single.createdAt;

      await writer.updateSupplier(
        created.id,
        const SupplierDraft(name: 'مورد محدث', notes: 'ملاحظة', dealType: SupplierDealType.direct),
      );

      final rows = await store.suppliers(tenant);
      expect(rows, hasLength(1));
      final row = rows.single;
      expect(row.name, 'مورد محدث');
      expect(row.notes, 'ملاحظة');
      expect(row.phone, isNull, reason: 'the update replaces the whole shape');
      expect(row.createdAt, createdAt,
          reason: 'an update must never re-stamp createdAt');
      expect(row.synced, isFalse);

      final legs = await store.pendingSync(tenant);
      expect(legs, hasLength(2));
      final update = legs.last;
      final params = jsonDecode(update.params) as Map<String, dynamic>;
      expect(params, containsPair('id', created.id));
      expect(params['row'], containsPair('name', 'مورد محدث'));
      expect(params['row'], containsPair('notes', 'ملاحظة'));
      expect(jsonDecode(update.dependsOn!), [legs.first.id],
          reason: 'the update must wait for the pending create leg');
    });

    test('deleteSupplier hides the mirror and enqueues a delete leg', () async {
      final created = await writer
          .writeSupplier(const SupplierDraft(name: 'مورد', phone: '0599111222', dealType: SupplierDealType.direct));

      await writer.deleteSupplier(created.id);

      // The mirror row survives (flipped unsynced) so a refresh can never
      // resurrect a server row the delete has not drained yet...
      final rows = await store.suppliers(tenant);
      expect(rows, hasLength(1));
      expect(rows.single.synced, isFalse);
      // ...but pendingDeleteIds hides it from local reads meanwhile.
      expect(await store.pendingDeleteIds(tenant, 'suppliers'), {created.id});

      final legs = await store.pendingSync(tenant);
      expect(legs, hasLength(2));
      final del = legs.last;
      expect(del.op, 'table_crud');
      expect(del.rpc, 'table:suppliers');
      expect(del.localId, created.id);
      expect(jsonDecode(del.params), containsPair('id', created.id));
      // The delete replays only after the pending create on the same supplier.
      expect(jsonDecode(del.dependsOn!), [legs.first.id]);
    });

    test('deleteSupplier rejects an unknown local supplier', () async {
      await expectLater(
        writer.deleteSupplier('ghost'),
        throwsA(isA<ValidationException>()),
      );
    });

    test('deleteSupplier rejects a supplier referenced by a local product',
        () async {
      final created = await writer
          .writeSupplier(const SupplierDraft(name: 'مورد', phone: '0599111222', dealType: SupplierDealType.direct));
      await store.upsertProduct(LocalProductRow(
        id: 'p-x',
        tenantId: tenant,
        name: 'منتج',
        barcode: null,
        unit: 'قطعة',
        unitType: 'count',
        salePrice: 10000,
        purchasePrice: 6000,
        qty: 1,
        reorderLevel: 0,
        supplierId: created.id,
        commissionRate: null,
        createdAt: DateTime(2026, 1, 1),
        synced: false,
      ));

      await expectLater(
        writer.deleteSupplier(created.id),
        throwsA(isA<ValidationException>()),
      );
      expect(await store.pendingDeleteIds(tenant, 'suppliers'), isEmpty,
          reason: 'no delete leg is queued for a referenced supplier');
    });

    test('deleteSupplier rejects a supplier referenced by a local commission due',
        () async {
      final created = await writer
          .writeSupplier(const SupplierDraft(name: 'مورد', phone: '0599111222', dealType: SupplierDealType.direct));
      await store.upsertCommissionDue(LocalCommissionDueRow(
        id: 'due-1',
        tenantId: tenant,
        invoiceId: 'pi-1',
        productId: 'p1',
        supplierId: created.id,
        dueAmount: 15000,
        status: 'pending',
        createdAt: DateTime(2026, 8, 10),
      ));

      await expectLater(
        writer.deleteSupplier(created.id),
        throwsA(isA<ValidationException>()),
      );
      expect(await store.pendingDeleteIds(tenant, 'suppliers'), isEmpty,
          reason: 'no delete leg is queued for a referenced supplier');
    });

    test('writeSupplier rolls back the mirror when the enqueue throws',
        () async {
      final poisoned = OfflineWriteCoordinator(
        _ThrowOnEnqueueStore(store),
        tenant,
      );
      await expectLater(
        poisoned.writeSupplier(const SupplierDraft(name: 'مورد', dealType: SupplierDealType.direct)),
        throwsA(isA<ValidationException>()),
      );
      expect(await store.suppliers(tenant), isEmpty);
      expect(await store.pendingSync(tenant), isEmpty);
    });

    test('deleteSupplier rolls back the mirror flip when the enqueue throws',
        () async {
      await writer.writeSupplier(const SupplierDraft(name: 'مورد', dealType: SupplierDealType.direct));
      final before = (await store.suppliers(tenant)).single.synced;

      final poisoned = OfflineWriteCoordinator(
        _ThrowOnEnqueueStore(store),
        tenant,
      );
      await expectLater(
        poisoned.deleteSupplier((await store.suppliers(tenant)).single.id),
        throwsA(isA<ValidationException>()),
      );
      // Neither a delete leg nor a synced flip survives the failed tx.
      expect((await store.suppliers(tenant)).single.synced, before);
      expect(await store.pendingSync(tenant), hasLength(1),
          reason: 'only the original create leg remains');
    });

    test('an offline supplier create survives a restart (file-backed)',
        () async {
      final dir = await Directory.systemTemp.createTemp('supplier_offline');
      final file = File('${dir.path}/test.db');

      final db1 = AppDatabase(NativeDatabase(file));
      final s1 = DriftLocalStore(db1);
      final c1 = OfflineWriteCoordinator(s1, tenant);

      final created = await c1
          .writeSupplier(const SupplierDraft(name: 'مورد', phone: '0599111222', dealType: SupplierDealType.direct));
      await c1.updateSupplier(
        created.id,
        const SupplierDraft(name: 'مورد محدث', dealType: SupplierDealType.direct),
      );
      await c1.deleteSupplier(created.id);
      await db1.close();

      final db2 = AppDatabase(NativeDatabase(file));
      final s2 = DriftLocalStore(db2);
      try {
        final rows = await s2.suppliers(tenant);
        expect(rows, hasLength(1));
        expect(rows.single.id, created.id);
        expect(rows.single.name, 'مورد محدث');
        expect(rows.single.synced, isFalse);
        expect(await s2.pendingDeleteIds(tenant, 'suppliers'), {created.id});
        expect(await s2.pendingSync(tenant), hasLength(3));
      } finally {
        await db2.close();
      }
    });
  });
}

/// Throws on the coordinator's final `enqueue` inside the write, after every
/// other statement in the transaction has already been staged.
class _ThrowOnEnqueueStore extends DelegatingLocalStore {
  _ThrowOnEnqueueStore(super.inner);

  @override
  Future<void> enqueue(SyncQueueRow row) =>
      throw StateError('queue write failed after the write was staged');
}
