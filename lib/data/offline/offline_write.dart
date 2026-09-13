import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../core/error/app_exception.dart';
import '../../domain/accounting/account.dart' as acc;
import '../../domain/accounting/double_entry_engine.dart';
import '../../domain/accounting/invoice_lines.dart';
import '../../domain/accounting/journal_entry.dart'
    as ae
    show JournalEntry, UnbalancedEntryException;
import '../../domain/customers/customer.dart';
import '../../domain/employees/employee.dart';
import '../../domain/invoices/invoice.dart';
import '../../domain/journal/journal_repository.dart' show JournalEntryResult;
import '../../domain/journal/manual_journal_draft.dart';
import '../../domain/payments/payment_repository.dart';
import '../../domain/products/product.dart';
import '../../domain/purchases/purchase_invoice_draft.dart';
import '../../domain/purchases/purchase_repository.dart';
import '../../domain/salaries/salary_repository.dart';
import '../../domain/sales/sale_invoice_draft.dart';
import '../../domain/sales/sale_repository.dart';
import '../../domain/suppliers/supplier.dart';
import 'local_database.dart';
import 'local_store.dart';

/// Runs an offline write: mirror the domain effect locally, enqueue the exact
/// RPC payload for replay, and return the same envelope the online RPC would
/// (marked [pending] for the UI).
///
/// The accounting math comes from [DoubleEntryEngine], which mirrors the
/// shipped RPCs exactly (revenue-only sales, consignment zero-debt receipts,
/// no-journal movements/adjustments, arrears salary payments). Every failure
/// surfaces as an [AppException] so callers never leak raw engine errors.
class OfflineWriteCoordinator {
  OfflineWriteCoordinator(this._store, this._tenantId);

  final LocalStore _store;
  final String _tenantId;
  static final _uuid = Uuid();

  /// Queues a sale invoice mirroring `create_sale_invoice` (revenue-only).
  Future<SaleInvoiceResult> writeSale(SaleInvoiceDraft draft) =>
      _guard(() async {
        final customer = await _customer(draft.customerId);
        final products = await _productsMap();
        final chart = await _chart();
        final suppliers = await _suppliersMap();

        final engineLines = <SaleInvoiceLine>[
          for (final l in draft.lines)
            SaleInvoiceLine(
              productId: l.productId,
              qty: l.qty,
              price: l.price ?? products[l.productId]!.salePrice,
            ),
        ];
        for (final l in engineLines) {
          if (!products.containsKey(l.productId)) {
            throw ValidationException(
              'المنتج غير موجود محلياً: ${l.productId}',
            );
          }
        }

        final requestId = _uuid.v4();
        final result = DoubleEntryEngine.createSaleInvoice(
          requestId: requestId,
          customer: customer,
          lines: engineLines,
          invoiceDate: draft.date ?? DateTime.now(),
          paidAmount: draft.paid,
          paymentMethod: draft.paymentMethod ?? 'cash',
          memo: draft.memo ?? '',
          accounts: chart,
          products: products,
          suppliers: suppliers,
        );

        final total = engineLines.fold<int>(0, (sum, l) => sum + l.lineTotal);
        final remaining = total - draft.paid;
        final status = _statusFor(total, draft.paid);
        final invoiceId = _uuid.v4();
        final no = 'D-${invoiceId.substring(0, 8)}';
        final date = draft.date ?? DateTime.now();

        await _store.upsertInvoice(
          LocalInvoiceRow(
            id: invoiceId,
            tenantId: _tenantId,
            type: 'sale',
            no: no,
            partyId: customer.id,
            partyName: customer.name,
            date: date,
            subtotal: total,
            total: total,
            paid: draft.paid,
            remaining: remaining,
            status: status,
            ownership: 'owned',
            requestId: requestId,
            synced: false,
            createdAt: DateTime.now(),
          ),
        );
        await _store.upsertInvoiceItems([
          for (final l in engineLines)
            LocalInvoiceItemRow(
              id: _uuid.v4(),
              tenantId: _tenantId,
              invoiceId: invoiceId,
              productId: l.productId,
              productName: products[l.productId]!.name,
              productUnit: products[l.productId]!.unit,
              productUnitType: products[l.productId]!.unitType.name,
              qty: l.qty,
              price: l.price,
              total: l.lineTotal,
            ),
        ]);
        await _applyProducts(result.updatedEntities);

        for (final due in result.commissionDues ?? const <CommissionDue>[]) {
          await _store.upsertCommissionDue(
            LocalCommissionDueRow(
              id: due.id,
              tenantId: _tenantId,
              invoiceId: invoiceId,
              productId: due.productId,
              supplierId: due.supplierId,
              dueAmount: due.dueAmount,
              status: due.status,
              createdAt: due.createdAt ?? DateTime.now(),
            ),
          );
        }

        await _mirrorJournal(result.journalEntry, requestId: requestId);
        await _enqueueRpc(
          rpc: 'create_sale_invoice',
          params: draft.toJson(requestId: requestId),
          requestId: requestId,
          entity: 'invoices',
          localId: invoiceId,
        );

        return SaleInvoiceResult(
          invoiceId: invoiceId,
          no: no,
          total: total,
          paid: draft.paid,
          remaining: remaining,
          status: InvoiceStatus.fromDb(status),
          entryNo: 0,
          pending: true,
        );
      });

  /// Queues a purchase invoice mirroring `create_purchase_invoice`.
  Future<PurchaseInvoiceResult> writePurchase(PurchaseInvoiceDraft draft) =>
      _guard(() async {
        final supplier = await _supplier(draft.supplierId);
        final chart = await _chart();

        final products = await _productsMap();
        final brandNewRows = <LocalProductRow>[];
        final engineLines = <PurchaseInvoiceLine>[];

        for (final line in draft.lines) {
          if (line.newProduct != null) {
            final newId = _uuid.v4();
            final np = line.newProduct!;
            final newPrice = line.price ?? np.salePrice;
            final product = Product(
              id: newId,
              name: np.name,
              barcode: null,
              unit: np.unit,
              unitType: np.unitType,
              salePrice: np.salePrice,
              purchasePrice: newPrice,
              qty: 0,
              reorderLevel: 0,
              supplierId: supplier.id,
              commissionRate: np.commissionRate,
            );
            products[newId] = product;
            brandNewRows.add(_localProduct(product, _tenantId));
            engineLines.add(
              PurchaseInvoiceLine(
                productId: newId,
                qty: line.qty,
                price: newPrice,
              ),
            );
          } else {
            final existing = products[line.productId];
            if (existing == null) {
              throw ValidationException(
                'المنتج غير موجود محلياً: ${line.productId}',
              );
            }
            engineLines.add(
              PurchaseInvoiceLine(
                productId: line.productId,
                qty: line.qty,
                price: line.price ?? existing.purchasePrice,
              ),
            );
          }
        }

        final requestId = _uuid.v4();
        final result = DoubleEntryEngine.createPurchaseInvoice(
          requestId: requestId,
          supplier: supplier,
          lines: engineLines,
          invoiceDate: draft.date ?? DateTime.now(),
          paidAmount: draft.paid,
          paymentMethod: draft.paymentMethod ?? 'cash',
          memo: draft.memo ?? '',
          accounts: chart,
          products: products,
        );

        final isConsignment =
            supplier.dealType == SupplierDealType.commission;
        final total = engineLines.fold<int>(0, (sum, l) => sum + l.lineTotal);
        final remaining = isConsignment ? total : total - draft.paid;
        final status = _statusFor(total, isConsignment ? 0 : draft.paid);
        final invoiceId = _uuid.v4();
        final no = 'D-${invoiceId.substring(0, 8)}';
        final date = draft.date ?? DateTime.now();

        await _store.upsertInvoice(
          LocalInvoiceRow(
            id: invoiceId,
            tenantId: _tenantId,
            type: 'purchase',
            no: no,
            partyId: supplier.id,
            partyName: supplier.name,
            date: date,
            subtotal: total,
            total: total,
            paid: isConsignment ? 0 : draft.paid,
            remaining: remaining,
            status: status,
            ownership: isConsignment ? 'consignment' : 'owned',
            requestId: requestId,
            synced: false,
            createdAt: DateTime.now(),
          ),
        );
        await _store.upsertInvoiceItems([
          for (final l in engineLines)
            LocalInvoiceItemRow(
              id: _uuid.v4(),
              tenantId: _tenantId,
              invoiceId: invoiceId,
              productId: l.productId,
              productName: products[l.productId]!.name,
              productUnit: products[l.productId]!.unit,
              productUnitType: products[l.productId]!.unitType.name,
              qty: l.qty,
              price: l.price,
              total: l.lineTotal,
            ),
        ]);

        // Existing products first, then any inline-created products with their
        // received quantity.
        await _applyProducts(result.updatedEntities);
        for (final row in brandNewRows) {
          final qty = result.updatedEntities?['products']?[row.id] as double? ??
              row.qty;
          await _store.upsertProduct(row.copyWith(qty: qty));
        }

        await _mirrorJournal(result.journalEntry, requestId: requestId);
        await _enqueueRpc(
          rpc: 'create_purchase_invoice',
          params: draft.toJson(requestId: requestId),
          requestId: requestId,
          entity: 'invoices',
          localId: invoiceId,
        );

        return PurchaseInvoiceResult(
          invoiceId: invoiceId,
          no: no,
          total: total,
          paid: isConsignment ? 0 : draft.paid,
          remaining: remaining,
          status: InvoiceStatus.fromDb(status),
          ownership: isConsignment
              ? InvoiceOwnership.consignment
              : InvoiceOwnership.owned,
          entryNo: 0,
          pending: true,
        );
      });

  /// Queues a payment mirroring `record_payment` (updates the local invoice).
  Future<PaymentResult> recordPayment(PaymentDraft draft) => _guard(() async {
        final row = await _invoice(draft.invoiceId);
        final invoice = _invoiceFromRow(row);
        final chart = await _chart();

        final requestId = _uuid.v4();
        final date = draft.date ?? DateTime.now();
        final result = DoubleEntryEngine.recordPayment(
          requestId: requestId,
          invoice: invoice,
          amount: draft.amount,
          method: draft.method,
          date: date,
          note: draft.note ?? '',
          accounts: chart,
        );

        final newPaid = row.paid + draft.amount;
        final newRemaining = row.remaining - draft.amount;
        final status = _statusFor(row.total, newPaid);
        final paymentId = _uuid.v4();

        await _store.upsertInvoice(
          row.copyWith(paid: newPaid, remaining: newRemaining, status: status),
        );
        await _store.upsertPayment(
          LocalPaymentRow(
            id: paymentId,
            tenantId: _tenantId,
            invoiceId: row.id,
            partyId: row.partyId,
            partyName: row.partyName,
            amount: draft.amount,
            method: draft.method,
            date: date,
            note: draft.note,
            requestId: requestId,
            synced: false,
            createdAt: DateTime.now(),
          ),
        );

        await _mirrorJournal(result.journalEntry, requestId: requestId);
        await _enqueueRpc(
          rpc: 'record_payment',
          params: draft.toJson(requestId: requestId),
          requestId: requestId,
          entity: 'payments',
          localId: paymentId,
        );

        return PaymentResult(
          duplicate: false,
          paymentId: paymentId,
          invoiceId: row.id,
          no: row.no,
          total: row.total,
          paid: newPaid,
          remaining: newRemaining,
          status: status,
          entryNo: 0,
          pending: true,
        );
      });

  /// Queues a bulk settlement mirroring `settle_supplier` (oldest-first
  /// owned invoices, then commission dues).
  Future<SettlementResult> settleSupplier(SettlementDraft draft) =>
      _guard(() async {
        final supplier = await _supplier(draft.supplierId);
        final chart = await _chart();

        final invoiceRows = await _store.invoices(_tenantId, type: 'purchase');
        final ownedRows = [
          for (final r in invoiceRows)
            if (r.partyId == draft.supplierId && r.remaining > 0)
              ..._ownedInvoiceRows([r]),
        ];
        ownedRows.sort((a, b) {
          final byDate = a.date.compareTo(b.date);
          if (byDate != 0) return byDate;
          return (a.createdAt ?? a.date)
              .compareTo(b.createdAt ?? b.date);
        });
        final ownedInvoices = [for (final r in ownedRows) _invoiceFromRow(r)];

        final dueRows = (await _store.commissionDues(
          _tenantId,
          supplierId: draft.supplierId,
        ))
            .where((r) => r.status == 'pending')
            .toList()
          ..sort((a, b) => (a.createdAt ?? DateTime(2000))
              .compareTo(b.createdAt ?? DateTime(2000)));
        final dues = [
          for (final r in dueRows)
            CommissionDue(
              id: r.id,
              invoiceId: r.invoiceId,
              productId: r.productId,
              supplierId: r.supplierId,
              dueAmount: r.dueAmount,
              status: r.status,
              createdAt: r.createdAt,
            ),
        ];

        final requestId = _uuid.v4();
        final date = draft.date ?? DateTime.now();
        final result = DoubleEntryEngine.settleSupplier(
          requestId: requestId,
          invoices: ownedInvoices,
          dues: dues,
          totalAmount: draft.amount,
          method: draft.method,
          date: date,
          note: draft.note ?? '',
          accounts: chart,
        );

        final allocations = result.allocations ?? const [];
        final invoicesCount =
            allocations.where((a) => a.dueId == null).length;
        final duesCount = allocations.where((a) => a.dueId != null).length;

        // Apply invoice allocations (reduce remaining / paid on each row).
        for (final a in allocations) {
          if (a.dueId != null) continue;
          for (final r in ownedRows) {
            if (r.id == a.invoiceId) {
              final newPaid = r.paid + a.amount;
              final newRemaining = r.remaining - a.amount;
              await _store.upsertInvoice(
                r.copyWith(
                  paid: newPaid,
                  remaining: newRemaining,
                  status: _statusFor(r.total, newPaid),
                ),
              );
              break;
            }
          }
        }
        // Full-coverage commission dues flip to paid.
        for (final a in allocations) {
          if (a.dueId == null) continue;
          final due = dueRows.where((r) => r.id == a.dueId);
          if (due.isNotEmpty && due.first.dueAmount == a.amount) {
            await _store.upsertCommissionDue(
              due.first.copyWith(status: 'paid'),
            );
          }
        }

        await _store.upsertPayment(
          LocalPaymentRow(
            id: _uuid.v4(),
            tenantId: _tenantId,
            invoiceId: null,
            partyId: supplier.id,
            partyName: supplier.name,
            amount: draft.amount,
            method: draft.method,
            date: date,
            note: draft.note,
            requestId: requestId,
            synced: false,
            createdAt: DateTime.now(),
          ),
        );

        await _mirrorJournal(result.journalEntry, requestId: requestId);
        await _enqueueRpc(
          rpc: 'settle_supplier',
          params: draft.toJson(requestId: requestId),
          requestId: requestId,
          entity: 'payments',
          localId: null,
        );

        return SettlementResult(
          duplicate: false,
          total: draft.amount,
          invoicesCount: invoicesCount,
          duesCount: duesCount,
          entryNo: 0,
          allocations: allocations,
          pending: true,
        );
      });

  /// Queues an employee movement mirroring `add_employee_movement`
  /// (movements never journal; product deductions move stock by cost).
  Future<MovementResult> addMovement(MovementDraft draft) => _guard(() async {
        final employee = await _employee(draft.employeeId);
        final chart = await _chart();
        final product = draft.productId == null
            ? null
            : await _product(draft.productId!);

        final requestId = _uuid.v4();
        final date = draft.date ?? DateTime.now();
        final result = DoubleEntryEngine.addEmployeeMovement(
          requestId: requestId,
          employee: employee,
          month: firstOfMonth(draft.month),
          direction: draft.direction,
          category: draft.category,
          amount: draft.amount,
          product: product,
          qty: draft.qty,
          date: date,
          note: draft.description ?? '',
          accounts: chart,
        );

        final movementId = _uuid.v4();
        final month = firstOfMonth(draft.month);
        await _store.upsertEmployeeMovement(
          LocalEmployeeMovementRow(
            id: movementId,
            tenantId: _tenantId,
            employeeId: draft.employeeId,
            month: _monthKey(month),
            direction: draft.direction,
            category: draft.category,
            amount: result.amount ?? 0,
            date: date,
            note: draft.description,
            requestId: requestId,
            synced: false,
            createdAt: DateTime.now(),
          ),
        );

        await _applyProducts(result.updatedEntities);
        await _enqueueRpc(
          rpc: 'add_employee_movement',
          params: draft.toJson(requestId: requestId),
          requestId: requestId,
          entity: 'employee_movements',
          localId: movementId,
        );

        return MovementResult(
          movementId: movementId,
          amount: result.amount ?? 0,
          pending: true,
        );
      });

  /// Queues a salary payment mirroring `pay_salary` (arrears cleared at the
  /// top of the entry). The entitlement is recomputed from the local mirrors.
  Future<SalaryResult> paySalary(SalaryDraft draft) => _guard(() async {
        final employee = await _employee(draft.employeeId);
        final chart = await _chart();

        final targetMonth = firstOfMonth(draft.month);
        final salaries = await _store.salaries(_tenantId,
            employeeId: draft.employeeId);
        final movements = await _store.employeeMovements(_tenantId,
            employeeId: draft.employeeId);

        var arrears = 0;
        var entitlements = 0;
        var deductions = 0;
        for (final s in salaries) {
          final m = _parseMonth(s.month);
          final diff = employee.baseSalary - s.paid;
          if (m.isBefore(targetMonth) && diff > 0) {
            arrears += diff;
          }
        }
        for (final mv in movements) {
          if (mv.month == null) continue;
          final m = _parseMonth(mv.month!);
          if (m != targetMonth) continue;
          final isIn = mv.direction == 'in' || mv.direction == 'entitle';
          if (isIn) {
            entitlements += mv.amount;
          } else {
            deductions += mv.amount;
          }
        }
        final netDue = employee.baseSalary + arrears + entitlements -
            deductions;

        final requestId = _uuid.v4();
        final date = draft.date ?? DateTime.now();
        final result = DoubleEntryEngine.paySalary(
          requestId: requestId,
          employee: employee,
          month: targetMonth,
          paidAmount: draft.paid,
          netDue: netDue,
          arrears: arrears,
          method: draft.method,
          date: date,
          note: draft.note ?? '',
          accounts: chart,
        );

        final salaryId = _uuid.v4();
        await _store.upsertSalary(
          LocalSalaryRow(
            id: salaryId,
            tenantId: _tenantId,
            employeeId: draft.employeeId,
            month: _monthKey(targetMonth),
            paid: draft.paid,
            netDue: netDue,
            requestId: requestId,
            synced: false,
            createdAt: DateTime.now(),
          ),
        );

        await _mirrorJournal(result.journalEntry, requestId: requestId);
        await _enqueueRpc(
          rpc: 'pay_salary',
          params: draft.toJson(requestId: requestId),
          requestId: requestId,
          entity: 'salaries',
          localId: salaryId,
        );

        return SalaryResult(
          salaryId: salaryId,
          month: targetMonth,
          baseSalary: employee.baseSalary,
          arrears: arrears,
          entitlements: entitlements,
          deductions: deductions,
          netDue: netDue,
          paid: draft.paid,
          arrearsCarried: netDue - draft.paid,
          entryNo: 0,
          pending: true,
        );
      });

  /// Queues a manual journal entry mirroring `create_journal_entry`
  /// (balanced-first; idempotent via p_request_id).
  Future<JournalEntryResult> createJournal(ManualJournalDraft draft) =>
      _guard(() async {
        if (!draft.hasAtLeastTwoLines || !draft.isBalanced) {
          throw ValidationException('القيد يجب أن يكون متوازناً وله سطران على الأقل');
        }
        final chart = await _chart();
        final requestId = _uuid.v4();
        final entryId = _uuid.v4();

        final lineMaps = <Map<String, dynamic>>[
          for (final l in draft.lines)
            () {
              acc.Account? account;
              for (final a in chart.values) {
                if (a.id == l.accountId) {
                  account = a;
                  break;
                }
              }
              return {
                'account_id': l.accountId,
                'account_code': account?.code ?? '',
                'account_name': account?.name ?? '',
                'account_type': account?.type.name ?? 'asset',
                'debit': l.debit,
                'credit': l.credit,
              };
            }(),
        ];

        await _store.insertJournalEntry(
          LocalJournalEntryRow(
            id: entryId,
            tenantId: _tenantId,
            date: draft.date,
            memo: draft.memo,
            lines: jsonEncode(lineMaps),
            sourceType: 'manual',
            sourceId: null,
            requestId: requestId,
            synced: false,
            createdAt: DateTime.now(),
          ),
        );

        await _enqueueRpc(
          rpc: 'create_journal_entry',
          params: draft.toJson(requestId: requestId),
          requestId: requestId,
          entity: 'journal_entries',
          localId: entryId,
        );

        return JournalEntryResult(
          entryId: entryId,
          entryNo: 0,
          total: draft.debitTotal,
          pending: true,
        );
      });

  // -------------------------------------------------------------------------
  // helpers
  // -------------------------------------------------------------------------

  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on AppException {
      rethrow;
    } on ae.UnbalancedEntryException catch (e) {
      throw UnknownException(e.message);
    } on StateError catch (e) {
      throw ValidationException(e.message);
    } on ArgumentError catch (e) {
      throw ValidationException(e.toString());
    }
  }

  Future<void> _enqueueRpc({
    required String rpc,
    required Map<String, dynamic> params,
    String? requestId,
    String? entity,
    String? localId,
  }) async {
    await _store.enqueue(
      SyncQueueRow(
        id: _uuid.v4(),
        tenantId: _tenantId,
        rpc: rpc,
        params: jsonEncode(params),
        requestId: requestId,
        entity: entity,
        localId: localId,
        status: 'pending',
        attempts: 0,
        lastError: null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<void> _mirrorJournal(
    ae.JournalEntry entry, {
    required String requestId,
  }) async {
    if (entry.lines.isEmpty) return;
    await _store.insertJournalEntry(
      LocalJournalEntryRow(
        id: entry.id,
        tenantId: _tenantId,
        date: entry.date,
        memo: entry.memo,
        lines: jsonEncode([
          for (final l in entry.lines)
            {
              'account_id': l.accountId,
              'account_code': l.accountCode,
              'account_name': l.accountName,
              'debit': l.debit,
              'credit': l.credit,
              'description': l.description,
            },
        ]),
        sourceType: entry.sourceType,
        sourceId: entry.sourceId,
        requestId: requestId,
        synced: false,
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> _applyProducts(Map<String, dynamic>? updatedEntities) async {
    final updates = updatedEntities?['products'] as Map<String, double>?;
    if (updates == null) return;
    for (final entry in updates.entries) {
      final row = await _productRow(entry.key);
      if (row != null) {
        await _store.upsertProduct(row.copyWith(qty: entry.value));
      }
    }
  }

  Future<Map<String, acc.Account>> _chart() async {
    final rows = await _store.accounts(_tenantId);
    if (rows.isEmpty) {
      throw ValidationException('دليل الحسابات غير متوفر محلياً');
    }
    return {
      for (final r in rows)
        r.code: acc.Account(
          id: r.id,
          code: r.code,
          name: r.name,
          type: _accType(r.type),
          parentCode: r.parentCode,
        ),
    };
  }

  Future<Map<String, Product>> _productsMap() async {
    final rows = await _store.products(_tenantId);
    return {for (final r in rows) r.id: _productFromRow(r)};
  }

  Future<Map<String, Supplier>> _suppliersMap() async {
    final rows = await _store.suppliers(_tenantId);
    return {
      for (final r in rows)
        r.id: Supplier(
          id: r.id,
          name: r.name,
          phone: r.phone,
          notes: r.notes,
          dealType: SupplierDealType.fromDb(r.dealType),
          commissionRate: r.commissionRate,
          createdAt: r.createdAt,
        ),
    };
  }

  Future<LocalProductRow?> _productRow(String id) async {
    for (final r in await _store.products(_tenantId)) {
      if (r.id == id) return r;
    }
    return null;
  }

  Future<Product> _product(String id) async {
    final row = await _productRow(id);
    if (row == null) {
      throw ValidationException('المنتج غير موجود محلياً');
    }
    return _productFromRow(row);
  }

  Future<Customer> _customer(String id) async {
    for (final r in await _store.customers(_tenantId)) {
      if (r.id == id) {
        return Customer(
          id: r.id,
          name: r.name,
          phone: r.phone,
          notes: r.notes,
          createdAt: r.createdAt,
        );
      }
    }
    throw ValidationException('العميل غير موجود محلياً');
  }

  Future<Supplier> _supplier(String id) async {
    for (final r in await _store.suppliers(_tenantId)) {
      if (r.id == id) {
        return Supplier(
          id: r.id,
          name: r.name,
          phone: r.phone,
          notes: r.notes,
          dealType: SupplierDealType.fromDb(r.dealType),
          commissionRate: r.commissionRate,
          createdAt: r.createdAt,
        );
      }
    }
    throw ValidationException('المورد غير موجود محلياً');
  }

  Future<Employee> _employee(String id) async {
    for (final r in await _store.employees(_tenantId)) {
      if (r.id == id) {
        return Employee(
          id: r.id,
          name: r.name,
          jobTitle: r.jobTitle,
          phone: r.phone,
          baseSalary: r.baseSalary,
          createdAt: r.createdAt,
        );
      }
    }
    throw ValidationException('الموظف غير موجود محلياً');
  }

  Future<LocalInvoiceRow> _invoice(String id) async {
    for (final r in await _store.invoices(_tenantId)) {
      if (r.id == id) return r;
    }
    throw ValidationException('الفاتورة غير موجودة محلياً');
  }

  static List<LocalInvoiceRow> _ownedInvoiceRows(List<LocalInvoiceRow> rows) =>
      [
        for (final r in rows)
          if (r.type == 'purchase' &&
              r.ownership == 'owned' &&
              r.remaining > 0)
            r,
      ];

  static Invoice _invoiceFromRow(LocalInvoiceRow r) => Invoice(
        id: r.id,
        type: r.type,
        no: r.no,
        partyId: r.partyId,
        partyName: r.partyName,
        date: r.date,
        subtotal: r.subtotal,
        total: r.total,
        paid: r.paid,
        remaining: r.remaining,
        status: InvoiceStatus.fromDb(r.status),
        ownership: r.ownership == 'consignment'
            ? InvoiceOwnership.consignment
            : InvoiceOwnership.owned,
      );

  static Product _productFromRow(LocalProductRow r) => Product(
        id: r.id,
        name: r.name,
        barcode: r.barcode,
        unit: r.unit,
        unitType: ProductUnitType.fromDb(r.unitType),
        salePrice: r.salePrice,
        purchasePrice: r.purchasePrice,
        qty: r.qty,
        reorderLevel: r.reorderLevel,
        supplierId: r.supplierId,
        commissionRate: r.commissionRate,
      );

  static LocalProductRow _localProduct(Product p, String tenantId) =>
        LocalProductRow(
          id: p.id,
          tenantId: tenantId,
          name: p.name,
          barcode: p.barcode,
          unit: p.unit,
          unitType: p.unitType.dbValue,
          salePrice: p.salePrice,
          purchasePrice: p.purchasePrice,
          qty: p.qty,
          reorderLevel: p.reorderLevel,
          supplierId: p.supplierId,
          commissionRate: p.commissionRate,
          createdAt: null,
        );

  static acc.AccountType _accType(String name) => acc.AccountType.values
      .firstWhere((t) => t.name == name, orElse: () => acc.AccountType.asset);

  /// Mirrors the RPC status rule: paid when fully settled, partial when any
  /// payment exists, unpaid otherwise.
  static String _statusFor(int total, int paid) {
    if (total > 0 && paid >= total) return 'paid';
    if (paid > 0) return 'partial';
    return 'unpaid';
  }

  static String _monthKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}';

  static DateTime _parseMonth(String yyyyMm) {
    final parts = yyyyMm.split('-');
    return DateTime(int.parse(parts[0]), int.parse(parts[1]), 1);
  }
}