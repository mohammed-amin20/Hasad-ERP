import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../core/error/app_exception.dart';
import '../../domain/accounts/account.dart' as ch;
import '../../domain/accounting/account.dart' as acc;
import '../../domain/accounting/double_entry_engine.dart';
import '../../domain/accounting/invoice_lines.dart' hide ProductDraft;
import '../../domain/accounting/journal_entry.dart'
    as ae
    show JournalEntry, UnbalancedEntryException;
import '../../domain/customers/customer.dart';
import '../../domain/customers/customer_draft.dart';
import '../../domain/employees/employee.dart';
import '../../domain/employees/employee_draft.dart';
import '../../domain/invoices/invoice.dart';
import '../../domain/journal/journal_repository.dart' show JournalEntryResult;
import '../../domain/journal/manual_journal_draft.dart';
import '../../domain/payments/payment_repository.dart';
import '../../domain/products/product.dart';
import '../../domain/products/product_draft.dart';
import '../../domain/purchases/purchase_invoice_draft.dart';
import '../../domain/purchases/purchase_repository.dart';
import '../../domain/salaries/salary_repository.dart';
import '../../domain/sales/sale_invoice_draft.dart';
import '../../domain/sales/sale_repository.dart';
import '../../domain/suppliers/supplier.dart';
import '../../domain/suppliers/supplier_draft.dart';
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
  OfflineWriteCoordinator(this._store, this._tenantId, [this._seedChart]);

  final LocalStore _store;
  final String _tenantId;

  /// One-time chart seed used when the local mirror is empty and the device
  /// can still reach the chart (through the offline-aware account read seam,
  /// which rehydrates from `report_cache` when offline). Best-effort: a seed
  /// failure never fails the write — it falls through to the honest local-only
  /// error.
  final Future<List<ch.Account>> Function()? _seedChart;

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

        // The invoice names the customer + product rows it was priced from, so
        // any of them that is still queued offline is a server-side
        // prerequisite. Resolved BEFORE the transaction (it is a read) and
        // written into the leg inside it.
        final masterDeps = await _pendingMasterLegIds(
          result.updatedEntities,
          localIds: [customer.id, ...engineLines.map((l) => l.productId)],
        );

        // ATOMIC: the invoice, its lines, the stock/commission effects, the
        // double-entry journal row and the queue leg are ONE commit. Before
        // this, a crash between two of the awaits left a half-written sale
        // (e.g. an invoice with no journal) that nothing would ever repair,
        // because the queue leg — the only thing that replays it — was the
        // last write. Either the whole offline sale exists, or none of it does.
        await _store.transaction((tx) async {
          await tx.upsertInvoice(
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
          await tx.upsertInvoiceItems([
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
          await _applyProducts(result.updatedEntities, tx);

          for (final due
              in result.commissionDues ?? const <CommissionDue>[]) {
            await tx.upsertCommissionDue(
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

          await _mirrorJournal(
            result.journalEntry,
            requestId: requestId,
            store: tx,
          );
          await tx.enqueue(SyncQueueRow(
            id: _uuid.v4(),
            tenantId: _tenantId,
            rpc: 'create_sale_invoice',
            op: 'rpc',
            params: jsonEncode(draft.toJson(requestId: requestId)),
            requestId: requestId,
            entity: 'invoices',
            localId: invoiceId,
            status: 'pending',
            attempts: 0,
            lastError: null,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            // The invoice names the local product/customer rows it was priced
            // from, so a product created offline in the same session is
            // created on the server BEFORE this leg is replayed.
            dependsOn: masterDeps == null ? null : jsonEncode(masterDeps),
          ));
        });

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
  ///
  /// One transaction or nothing (parity with [writeSale] and payments): the
  /// invoice, its lines, the stock effects, the mirrored journal and **all**
  /// queue legs commit together. A throw inside enqueues rolls the invoice back
  /// rather than leaving a receipt that can never reach the server.
  ///
  /// Inline new products become real rows on the server **before** this
  /// invoice: each one enqueues its own `table:products` leg carrying the
  /// client uuid, and the purchase RPC leg depends on all of them and encodes
  /// `product_id` instead of `new_product`. The server therefore creates the
  /// product under the same uuid the local mirror uses — no phantom local
  /// product, no duplicate after a mirror refresh, and the stock/price the RPC
  /// applies land on the identical row. The online repository (which has no
  /// store) keeps sending `new_product` untouched.
  Future<PurchaseInvoiceResult> writePurchase(PurchaseInvoiceDraft draft) =>
      _guard(() async {
        final supplier = await _supplier(draft.supplierId);
        final chart = await _chart();

        final products = await _productsMap();
        final brandNewRows = <LocalProductRow>[];
        final engineLines = <PurchaseInvoiceLine>[];
        final newProductIds = <int, String>{};

        var lineIndex = 0;
        for (final line in draft.lines) {
          if (line.newProduct != null) {
            final newId = _uuid.v4();
            newProductIds[lineIndex] = newId;
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
          lineIndex++;
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

        // The receipt names the supplier and the product rows it priced from
        // (including the inline ones, whose client uuids the engine put in
        // `updatedEntities`), so any of them still queued offline is a server
        // prerequisite. Resolved BEFORE the transaction (it is a read) and
        // written into the leg inside it; the inline product legs enqueued in
        // the same transaction are appended explicitly.
        final masterDeps = await _pendingMasterLegIds(
          result.updatedEntities,
          localIds: [supplier.id, ...engineLines.map((l) => l.productId!)],
        );

        // ATOMIC: invoice + lines + stock + journal + every queue leg commit
        // together. See [writeSale].
        await _store.transaction((tx) async {
          await tx.upsertInvoice(
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
          await tx.upsertInvoiceItems([
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
          await _applyProducts(result.updatedEntities, tx);
          for (final row in brandNewRows) {
            final qty = result.updatedEntities?['products']?[row.id] as double? ??
                row.qty;
            await tx.upsertProduct(row.copyWith(qty: qty));
          }

          await _mirrorJournal(
            result.journalEntry,
            requestId: requestId,
            store: tx,
          );

          // Inline new products become server products FIRST: one table_crud
          // leg per new product (client uuid as id, so the server row inherits
          // it via tableUpsert's `onConflict: 'id'`), and the purchase RPC leg
          // below depends on every one of them.
          final productLegIds = <String>[];
          for (final entry in newProductIds.entries) {
            final legId = _uuid.v4();
            productLegIds.add(legId);
            final np = draft.lines[entry.key].newProduct!;
            final newPrice = draft.lines[entry.key].price ?? np.salePrice;
            await _enqueueWrite(
              rpc: 'table:products',
              id: legId,
              params: ProductDraft(
                name: np.name,
                unit: np.unit,
                unitType: np.unitType,
                salePrice: np.salePrice,
                purchasePrice: newPrice,
                qty: 0,
                reorderLevel: 0,
                supplierId: supplier.id,
                commissionRate: np.commissionRate ?? supplier.commissionRate,
              ).toJson(),
              requestId: _uuid.v4(),
              entity: 'products',
              localId: entry.value,
              op: 'table_crud',
              store: tx,
            );
          }

          await _enqueueRpc(
            rpc: 'create_purchase_invoice',
            params: draft.toJson(
              requestId: requestId,
              lineProductIds: newProductIds,
            ),
            requestId: requestId,
            entity: 'invoices',
            localId: invoiceId,
            dependsOn: [...?masterDeps, ...productLegIds],
            store: tx,
          );
        });

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
  ///
  /// One transaction or nothing (parity with [writeSale]): the invoice's
  /// paid/remaining/status, the payment row, the mirrored journal and the queue
  /// leg commit together. The leg depends on the invoice's own pending leg, so
  /// a replay never pays a parent the server has not seen yet — the RPC would
  /// otherwise reject the payment for a missing invoice and burn its retry
  /// budget on a pure ordering problem.
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

        // Resolved BEFORE the transaction (it is a read, and the leg is written
        // inside it): the payment names the invoice, so that invoice's pending
        // leg is the prerequisite.
        final invoiceLegs = await _pendingLegIdsFor([row.id]);

        await _store.transaction((tx) async {
          await tx.upsertInvoice(
            row.copyWith(
              paid: newPaid,
              remaining: newRemaining,
              status: status,
            ),
          );
          await tx.upsertPayment(
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
          await _mirrorJournal(result.journalEntry,
              requestId: requestId, store: tx);
          await _enqueueRpc(
            rpc: 'record_payment',
            params: draft.toJson(requestId: requestId),
            requestId: requestId,
            entity: 'payments',
            localId: paymentId,
            dependsOn: invoiceLegs,
            store: tx,
          );
        });

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
  ///
  /// One transaction or nothing (parity with [writeSale]): every invoice
  /// allocation, the flipped dues, the payment row, the mirrored journal and
  /// the queue leg commit together.
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

        // The settlement allocates against specific owned invoices and the dues
        // they spawn. Each of those parents may itself still be a pending
        // offline leg, so the settlement replay waits for all of them — paying
        // invoices the server has never seen would silently mis-allocate and
        // burn the settlement in the process.
        final parentIds = <String>{
          for (final a in allocations)
            if (a.dueId != null)
              ...dueRows.where((r) => r.id == a.dueId).map((r) => r.invoiceId)
            else
              a.invoiceId,
        };
        final parentLegs = await _pendingLegIdsFor(parentIds.toList());

        await _store.transaction((tx) async {
          // Apply invoice allocations (reduce remaining / paid on each row).
          for (final a in allocations) {
            if (a.dueId != null) continue;
            for (final r in ownedRows) {
              if (r.id == a.invoiceId) {
                final newPaid = r.paid + a.amount;
                final newRemaining = r.remaining - a.amount;
                await tx.upsertInvoice(
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
              await tx.upsertCommissionDue(
                due.first.copyWith(status: 'paid'),
              );
            }
          }

          await tx.upsertPayment(
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

          await _mirrorJournal(result.journalEntry,
              requestId: requestId, store: tx);
          await _enqueueRpc(
            rpc: 'settle_supplier',
            params: draft.toJson(requestId: requestId),
            requestId: requestId,
            entity: 'payments',
            localId: null,
            dependsOn: parentLegs,
            store: tx,
          );
        });

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
  ///
  /// Atomic like [writeSale]: the mirror row, the stock move and the queue leg
  /// commit in ONE [LocalStore.transaction]. The movement names the employee
  /// (and product for product deductions) it was built from, so the leg waits
  /// on any of their still-pending master legs via [dependsOn] — never FIFO.
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

        // Resolved BEFORE the transaction (a read, and the leg is written
        // inside it): a movement on an employee/product created offline waits
        // for their `table_crud` legs to create the rows on the server first.
        final deps = await _pendingLegIdsFor([
          employee.id,
          if (product != null) product.id,
        ]);

        await _store.transaction((tx) async {
          await tx.upsertEmployeeMovement(
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

          await _applyProducts(result.updatedEntities, tx);
          await _enqueueRpc(
            rpc: 'add_employee_movement',
            params: draft.toJson(requestId: requestId),
            requestId: requestId,
            entity: 'employee_movements',
            localId: movementId,
            dependsOn: deps,
            store: tx,
          );
        });

        return MovementResult(
          movementId: movementId,
          amount: result.amount ?? 0,
          pending: true,
        );
      });

  /// Queues a salary payment mirroring `pay_salary` (arrears cleared at the
  /// top of the entry). The entitlement is recomputed from the local mirrors.
  ///
  /// Atomic like [addMovement]: the salary row, the mirrored journal entry and
  /// the queue leg commit in ONE [LocalStore.transaction]. Two guards mirror
  /// `0010` locally so a doomed leg is never queued: one payment per
  /// employee+month (`'تم صرف راتب هذا الشهر مسبقاً'`), and every account the
  /// entry needs (2030 / 5030 / 1010-or-1015) must resolve in the local chart
  /// with a clear Arabic error instead of the engine's English `StateError`.
  Future<SalaryResult> paySalary(SalaryDraft draft) => _guard(() async {
        final employee = await _employee(draft.employeeId);
        final chart = await _chart();

        final targetMonth = firstOfMonth(draft.month);
        final monthKey = _monthKey(targetMonth);
        final salaries = await _store.salaries(_tenantId,
            employeeId: draft.employeeId);
        final movements = await _store.employeeMovements(_tenantId,
            employeeId: draft.employeeId);

        // 0010:280 — one salaries row per employee-month; a second pay for the
        // same month is rejected server-side, so reject it before queueing.
        if (salaries.any((s) => s.month == monthKey)) {
          throw ValidationException('تم صرف راتب هذا الشهر مسبقاً');
        }

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

        // 0010:312-318 — required chart codes. Pre-validated here so the user
        // gets the Arabic message; `DoubleEntryEngine._getAccount` would throw
        // `StateError` in English otherwise.
        for (final code in [
          '2030',
          '5030',
          draft.method == 'cash' ? '1010' : '1015',
        ]) {
          if (!chart.containsKey(code)) {
            throw ValidationException(
              'الحساب غير موجود في دليل الحسابات: $code',
            );
          }
        }

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

        // The salary names the employee row it was built from; a pending
        // `table_crud` leg for that employee is a server-side prerequisite.
        // Resolved BEFORE the transaction (a read).
        final deps = await _pendingLegIdsFor([employee.id]);

        await _store.transaction((tx) async {
          await tx.upsertSalary(
            LocalSalaryRow(
              id: salaryId,
              tenantId: _tenantId,
              employeeId: draft.employeeId,
              month: monthKey,
              paid: draft.paid,
              netDue: netDue,
              requestId: requestId,
              synced: false,
              createdAt: DateTime.now(),
            ),
          );

          await _mirrorJournal(result.journalEntry,
              requestId: requestId, store: tx);
          await _enqueueRpc(
            rpc: 'pay_salary',
            params: draft.toJson(requestId: requestId),
            requestId: requestId,
            entity: 'salaries',
            localId: salaryId,
            dependsOn: deps,
            store: tx,
          );
        });

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
  ///
  /// Local-first like [recordPayment]: the entry and its queue leg commit in
  /// one transaction, the leg replays after any pending `accounts` leg the
  /// entry's lines reference (via [dependsOn]), and every account must resolve
  /// against the local chart — a missing account is rejected here instead of
  /// being silently emptied or hardcoded.
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
              if (account == null) {
                throw ValidationException(
                  'أحد حسابات القيد غير موجود في دليل الحسابات (${l.accountId})',
                );
              }
              return {
                'account_id': l.accountId,
                'account_code': account.code,
                'account_name': account.name,
                'account_type': account.type.name,
                'debit': l.debit,
                'credit': l.credit,
              };
            }(),
        ];

        // Resolved BEFORE the transaction (a read, and the leg is written
        // inside it): a journal drawn on a locally-created account waits for
        // that account's pending `table_crud` leg.
        final accountLegs = await _pendingLegIdsFor([
          for (final l in draft.lines) l.accountId,
        ]);

        await _store.transaction((tx) async {
          await tx.insertJournalEntry(
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
            dependsOn: accountLegs,
            store: tx,
          );
        });

        return JournalEntryResult(
          entryId: entryId,
          entryNo: 0,
          total: draft.debitTotal,
          pending: true,
        );
      });

  // -------------------------------------------------------------------------
  // master write legs (op: table_crud — replayed against `.from(<entity>)` by
  // OfflineFlushService; masters are domain-Direct so the leg returns the
  // domain entity, unlike the RPC legs that return transaction envelopes)
  // -------------------------------------------------------------------------

  /// Mirrors a customer create locally (synced:false) and enqueues a
  /// `table_crud` upsert for replay. Returns the customer directly.
  Future<Customer> writeCustomer(CustomerDraft draft) => _guard(() async {
        final requestId = _uuid.v4();
        final customer = Customer(
          id: requestId,
          name: draft.name,
          phone: draft.phone,
          notes: draft.notes,
          createdAt: DateTime.now(),
        );
        await _store.upsertCustomer(
          LocalCustomerRow(
            id: customer.id,
            tenantId: _tenantId,
            name: customer.name,
            phone: customer.phone,
            notes: customer.notes,
            synced: false,
            createdAt: customer.createdAt!,
          ),
        );
        await _enqueueWrite(
          rpc: 'table:customers',
          params: customer.toJson(),
          requestId: requestId,
          entity: 'customers',
          localId: requestId,
          op: 'table_crud',
        );
        return customer;
      });

  /// Rewires customer update through the coordinator: mirrors the updated row
  /// (synced:false) and enqueues a `table_crud` update for replay.
  Future<void> updateCustomer(
    String id,
    CustomerDraft draft,
  ) =>
      _guard(() async {
        await _store.upsertCustomer(
          LocalCustomerRow(
            id: id,
            tenantId: _tenantId,
            name: draft.name,
            phone: draft.phone,
            notes: draft.notes,
            synced: false,
            createdAt: DateTime.now(),
          ),
        );
        await _enqueueWrite(
          rpc: 'table:customers',
          params: {'id': id, 'row': draft.toJson()},
          requestId: _uuid.v4(),
          entity: 'customers',
          localId: id,
          op: 'table_crud',
        );
      });

  /// Rewires customer delete through the coordinator: mirrors removal and
  /// enqueues a `table_crud` delete for replay.
  Future<void> deleteCustomer(String id) => _guard(() async {
        await _enqueueWrite(
          rpc: 'table:customers',
          params: {'id': id},
          requestId: _uuid.v4(),
          entity: 'customers',
          localId: id,
          op: 'table_crud',
        );
      });

  /// Mirrors a supplier create locally (synced:false) and enqueues a
  /// `table_crud` upsert for replay. Returns the supplier directly.
  Future<Supplier> writeSupplier(SupplierDraft draft) => _guard(() async {
        final requestId = _uuid.v4();
        final supplier = Supplier(
          id: requestId,
          name: draft.name,
          dealType: draft.dealType,
          phone: draft.phone,
          notes: draft.notes,
          createdAt: DateTime.now(),
        );
        await _store.upsertSupplier(
          LocalSupplierRow(
            id: supplier.id,
            tenantId: _tenantId,
            name: supplier.name,
            dealType: supplier.dealType.dbValue,
            phone: supplier.phone,
            notes: supplier.notes,
            synced: false,
            createdAt: supplier.createdAt!,
          ),
        );
        await _enqueueWrite(
          rpc: 'table:suppliers',
          params: draft.toJson(),
          requestId: requestId,
          entity: 'suppliers',
          localId: requestId,
          op: 'table_crud',
        );
        return supplier;
      });

  /// Rewires supplier update through the coordinator.
  Future<void> updateSupplier(String id, SupplierDraft draft) =>
      _guard(() async {
        await _store.upsertSupplier(
          LocalSupplierRow(
            id: id,
            tenantId: _tenantId,
            name: draft.name,
            dealType: draft.dealType.dbValue,
            phone: draft.phone,
            notes: draft.notes,
            synced: false,
            createdAt: DateTime.now(),
          ),
        );
        await _enqueueWrite(
          rpc: 'table:suppliers',
          params: {'id': id, 'row': draft.toJson()},
          requestId: _uuid.v4(),
          entity: 'suppliers',
          localId: id,
          op: 'table_crud',
        );
      });

  /// Rewires supplier delete through the coordinator.
  Future<void> deleteSupplier(String id) => _guard(() async {
        await _enqueueWrite(
          rpc: 'table:suppliers',
          params: {'id': id},
          requestId: _uuid.v4(),
          entity: 'suppliers',
          localId: id,
          op: 'table_crud',
        );
      });

  /// Mirrors a product create locally (synced:false) and enqueues a
  /// `table_crud` upsert for replay. Returns the product directly.
  Future<Product> writeProduct(ProductDraft draft) => _guard(() async {
        final requestId = _uuid.v4();
        final product = Product(
          id: requestId,
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
        await _store.upsertProduct(
          LocalProductRow(
            id: product.id,
            tenantId: _tenantId,
            name: product.name,
            barcode: product.barcode,
            unit: product.unit,
            unitType: product.unitType.dbValue,
            salePrice: product.salePrice,
            purchasePrice: product.purchasePrice,
            qty: product.qty,
            reorderLevel: product.reorderLevel,
            supplierId: product.supplierId,
            commissionRate: product.commissionRate,
            synced: false,
            createdAt: DateTime.now(),
          ),
        );
        await _enqueueWrite(
          rpc: 'table:products',
          params: draft.toJson(),
          requestId: requestId,
          entity: 'products',
          localId: requestId,
          op: 'table_crud',
        );
        return product;
      });

  /// Rewires product update through the coordinator.
  Future<void> updateProduct(String id, ProductDraft draft) =>
      _guard(() async {
        await _store.upsertProduct(
          LocalProductRow(
            id: id,
            tenantId: _tenantId,
            name: draft.name,
            barcode: draft.barcode,
            unit: draft.unit,
            unitType: draft.unitType.dbValue,
            salePrice: draft.salePrice,
            purchasePrice: draft.purchasePrice,
            qty: draft.qty,
            reorderLevel: draft.reorderLevel,
            supplierId: draft.supplierId,
            commissionRate: draft.commissionRate,
            synced: false,
            createdAt: DateTime.now(),
          ),
        );
        await _enqueueWrite(
          rpc: 'table:products',
          params: {'id': id, 'row': draft.toJson()},
          requestId: _uuid.v4(),
          entity: 'products',
          localId: id,
          op: 'table_crud',
        );
      });

  /// Rewires product delete through the coordinator.
  Future<void> deleteProduct(String id) => _guard(() async {
        await _enqueueWrite(
          rpc: 'table:products',
          params: {'id': id},
          requestId: _uuid.v4(),
          entity: 'products',
          localId: id,
          op: 'table_crud',
        );
      });

  /// Mirrors an employee create locally (synced:false) and enqueues a
  /// `table_crud` upsert for replay. Returns the employee directly.
  Future<Employee> writeEmployee(EmployeeDraft draft) => _guard(() async {
        final requestId = _uuid.v4();
        final employee = Employee(
          id: requestId,
          name: draft.name,
          jobTitle: draft.jobTitle,
          phone: draft.phone,
          baseSalary: draft.baseSalary,
          createdAt: DateTime.now(),
        );
        await _store.upsertEmployee(
          LocalEmployeeRow(
            id: employee.id,
            tenantId: _tenantId,
            name: employee.name,
            jobTitle: employee.jobTitle,
            phone: employee.phone,
            baseSalary: employee.baseSalary,
            synced: false,
            createdAt: employee.createdAt,
          ),
        );
        await _enqueueWrite(
          rpc: 'table:employees',
          params: draft.toJson(),
          requestId: requestId,
          entity: 'employees',
          localId: requestId,
          op: 'table_crud',
        );
        return employee;
      });

  /// Rewires employee update through the coordinator.
  Future<void> updateEmployee(String id, EmployeeDraft draft) =>
      _guard(() async {
        await _store.upsertEmployee(
          LocalEmployeeRow(
            id: id,
            tenantId: _tenantId,
            name: draft.name,
            jobTitle: draft.jobTitle,
            phone: draft.phone,
            baseSalary: draft.baseSalary,
            synced: false,
            createdAt: DateTime.now(),
          ),
        );
        await _enqueueWrite(
          rpc: 'table:employees',
          params: {'id': id, 'row': draft.toJson()},
          requestId: _uuid.v4(),
          entity: 'employees',
          localId: id,
          op: 'table_crud',
        );
      });

  /// Rewires employee delete through the coordinator.
  Future<void> deleteEmployee(String id) => _guard(() async {
        await _enqueueWrite(
          rpc: 'table:employees',
          params: {'id': id},
          requestId: _uuid.v4(),
          entity: 'employees',
          localId: id,
          op: 'table_crud',
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
    List<String>? dependsOn,
    LocalStore? store,
  }) async {
    await (store ?? _store).enqueue(
      SyncQueueRow(
        id: _uuid.v4(),
        tenantId: _tenantId,
        rpc: rpc,
        op: 'rpc',
        params: jsonEncode(params),
        requestId: requestId,
        entity: entity,
        localId: localId,
        status: 'pending',
        attempts: 0,
        lastError: null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        dependsOn: dependsOn == null || dependsOn.isEmpty
            ? null
            : jsonEncode(dependsOn),
      ),
    );
  }

  /// Queues a master-table write for replay against `.from(<entity>)` with
  /// `op: 'table_crud'` (mirrors `_enqueueRpc` but tags the row as table_crud
  /// so the flush service replays it as a direct table upsert). [store] is the
  /// transaction-bound store when enqueued inside an atomic write.
  Future<void> _enqueueWrite({
    required String rpc,
    required Map<String, dynamic> params,
    String? id,
    String? requestId,
    String? entity,
    String? localId,
    required String op,
    LocalStore? store,
  }) async {
    await (store ?? _store).enqueue(
      SyncQueueRow(
        id: id ?? _uuid.v4(),
        tenantId: _tenantId,
        rpc: rpc,
        op: op,
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
    LocalStore? store,
  }) async {
    if (entry.lines.isEmpty) return;
    await (store ?? _store).insertJournalEntry(
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

  /// Applies the engine's product stock deltas. [store] is the transaction-bound
  /// store when called from inside an atomic write, so the stock move commits
  /// with the invoice that caused it.
  Future<void> _applyProducts(
    Map<String, dynamic>? updatedEntities, [
    LocalStore? store,
  ]) async {
    final target = store ?? _store;
    final updates = updatedEntities?['products'] as Map<String, double>?;
    if (updates == null) return;
    for (final entry in updates.entries) {
      final row = await _productRow(entry.key);
      if (row != null) {
        await target.upsertProduct(row.copyWith(qty: entry.value));
      }
    }
  }

  /// Queue ids of the master-data legs this sale depends on, so the flusher
  /// creates them on the server first.
  ///
  /// A sale priced from a product that was itself created offline would be
  /// rejected server-side on a missing product, and the invoice would burn its
  /// retry budget for a purely local ordering reason. The invoice names the
  /// product/customer rows it was priced from, and their `table_crud` legs
  /// carry `localId`, so the prerequisite queue ids can be resolved.
  Future<List<String>?> _pendingMasterLegIds(
    Map<String, dynamic>? updatedEntities, {
    List<String> localIds = const [],
  }) async {
    final stockUpdates = updatedEntities?['products'];
    final wanted = <String>{
      ...localIds,
      if (stockUpdates is Map) ...stockUpdates.keys.cast<String>(),
    };
    if (wanted.isEmpty) return null;

    final pending = await _store.pendingSync(_tenantId);
    final ids = <String>{
      for (final leg in pending)
        // Only queue legs that are still pending and match the exact local rows
        // this sale referenced. A leg that is already `synced` is on the server,
        // so it is not a prerequisite.
        if (leg.status == 'pending' &&
            leg.localId != null &&
            wanted.contains(leg.localId))
          leg.id,
    };
    return ids.isEmpty ? null : ids.toList();
  }

  /// Queue ids of the pending legs whose `local_id` is one of [localIds], so a
  /// financial follow-up (payment against an offline invoice, settlement of
  /// offline invoices/dues) replays only after the parent server rows exist.
  ///
  /// A `create_sale_invoice`/`create_purchase_invoice` leg carries `localId =
  /// invoiceId`, and a commission due carries `invoiceId` pointing at the sale
  /// that created it, so resolving by invoice ids covers both invoice and due
  /// prerequisites without a second `pendingSync` shape.
  Future<List<String>?> _pendingLegIdsFor(List<String> localIds) async {
    final wanted = localIds.toSet();
    if (wanted.isEmpty) return null;
    final pending = await _store.pendingSync(_tenantId);
    final ids = <String>{
      for (final leg in pending)
        // Only queue legs that are still pending and match the exact local rows
        // this financial write references. A leg that is already `synced` is on
        // the server, so it is not a prerequisite.
        if (leg.status == 'pending' &&
            leg.localId != null &&
            wanted.contains(leg.localId))
          leg.id,
    };
    return ids.isEmpty ? null : ids.toList();
  }

  Future<Map<String, acc.Account>> _chart() async {
    var rows = await _store.accounts(_tenantId);
    if (rows.isEmpty) {
      // 1) Prefer the real chart: a live read, or the last successful RPC
      //    payload from `report_cache` (the closure swallows a
      //    NetworkException internally and returns whatever it has).
      if (_seedChart != null) {
        try {
          final seed = await _seedChart();
          if (seed.isNotEmpty) {
            await _store.mirrorAccounts(
              _tenantId,
              [
                for (final a in seed)
                  LocalAccountRow(
                    id: a.id,
                    tenantId: _tenantId,
                    code: a.code,
                    name: a.name,
                    type: a.type.apiValue,
                    parentCode: a.parentCode,
                    parentId: a.parentId,
                  ),
              ],
            );
          }
        } on Object {
          // Best-effort seed: a seed failure must never fail the leg — it just
          // falls through to the embedded baseline below.
        }
        rows = await _store.accounts(_tenantId);
      }
      // 2) Still nothing (a device that has never been online, or an empty
      //    cache): fall back to the 14 default accounts embedded in the
      //    schema. This is what makes an offline sale invoice on a fresh device
      //    post a balanced journal instead of failing with
      //    "دليل الحسابات غير متوفر محليا" / "Required account not found".
      if (rows.isEmpty) {
        rows = await _store.ensureBaselineChart(_tenantId);
      }
    }
    if (rows.isEmpty) {
      throw ValidationException('دليل الحسابات غير متوفر محليا');
    }
    return {
      for (final r in rows)
        r.code: acc.Account(
          id: r.id,
          code: r.code,
          name: r.name,
          type: _accType(r.type),
          parentCode: r.parentCode,
          parentId: r.parentId,
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
        synced: false,
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