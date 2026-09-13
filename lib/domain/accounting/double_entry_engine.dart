import 'package:uuid/uuid.dart';

import 'journal_entry.dart';
import 'account.dart';
import 'invoice_lines.dart';
import '../customers/customer.dart';
import '../products/product.dart';
import '../suppliers/supplier.dart';
import '../employees/employee.dart';
import '../invoices/invoice.dart';
import '../payments/payment_repository.dart' show SettlementAllocation;

/// Result of a double-entry operation.
///
/// [journalEntry] is always present; operations that the server RPCs do NOT
/// journal (consignment receipts, employee movements, inventory adjustments)
/// produce an empty-lines entry (balanced trivially) and the offline writer
/// simply skips persisting it.
class DoubleEntryResult {
  const DoubleEntryResult({
    required this.journalEntry,
    this.invoice,
    this.commissionDues,
    this.updatedEntities,
    this.amount,
    this.allocations,
  });

  final JournalEntry journalEntry;
  final Invoice? invoice;
  final List<CommissionDue>? commissionDues;
  final Map<String, dynamic>? updatedEntities;

  /// Movement value in agorot (e.g. a product deduction computed as
  /// qty x cost by the RPC); null for every other operation.
  final int? amount;

  /// Per-line allocation of a supplier settlement, mirroring the RPC's
  /// oldest-first invoice-then-commission passes.
  final List<SettlementAllocation>? allocations;
}

/// Commission due record (mirroring the commission_dues row the server
/// creates when a consignment product is sold).
class CommissionDue {
  CommissionDue({
    required this.id,
    required this.invoiceId,
    required this.productId,
    required this.supplierId,
    required this.dueAmount,
    required this.status,
    this.rate,
    this.commissionAmount,
    this.remaining,
    this.date,
    this.createdAt,
  });

  final String id;
  final String invoiceId;
  final String productId;
  final String supplierId;

  /// Supplier due = sale total minus the commission amount
  /// (what the server tracks as `commission_dues.supplier_due`/`remaining`).
  final int dueAmount;
  final String status; // 'pending', 'paid'

  /// Commission rate in percent (0-100) and the absolute commission amount.
  final double? rate;
  final int? commissionAmount;

  /// Outstanding remainder for settlement allocation; defaults to [dueAmount].
  final int? remaining;
  final DateTime? date;
  final DateTime? createdAt;
}

/// Pure Dart mirror of the shipped Supabase RPCs (migrations 0007-0010/0014)
/// so offline writes reproduce the server's double entry exactly.
///
/// Accounting decisions that deliberately match the RPCs (and any
/// documentation that says otherwise is stale):
///   * sales book REVENUE ONLY — Dr cash/bank + AR, Cr 4010 (no COGS, no
///     inventory credit; 5010/1030 only move via manual journals);
///   * consignment purchase receipts post NO journal and NO debt;
///   * employee movements do NOT journal (expense is recognized at pay);
///   * adjust_inventory does NOT journal (stock_moves only);
///   * pay_salary uses arrears: Dr 2030 (cleared) + Dr 5030 (net-cleared),
///     Cr cash/bank (paid) + Cr 2030 (carried).
class DoubleEntryEngine {
  /// Mirrors `create_sale_invoice` (revenue-only, idempotent).
  static DoubleEntryResult createSaleInvoice({
    required String requestId,
    required Customer customer,
    required List<SaleInvoiceLine> lines,
    required DateTime invoiceDate,
    required int paidAmount,
    required String paymentMethod, // 'cash' | 'bank'
    required String memo,
    required Map<String, Account> accounts,
    required Map<String, Product> products,
    Map<String, Supplier> suppliers = const {},
  }) {
    if (lines.isEmpty) throw StateError('لا توجد أصناف في الفاتورة');
    if (paidAmount < 0 ||
        (paidAmount > 0 &&
            (paymentMethod != 'cash' && paymentMethod != 'bank'))) {
      throw StateError('طريقة دفع غير صحيحة');
    }

    // Validate inventory availability.
    for (final line in lines) {
      final product = products[line.productId];
      if (product == null) {
        throw StateError('المنتج غير موجود: ${line.productId}');
      }
      if (product.qty - line.qty < 0) {
        throw StateError(
          'الكمية غير متوفرة للمنتج: ${product.name} — المتاح ${product.qty}, المطلوب ${line.qty}',
        );
      }
    }

    final totalAmount = lines.fold<int>(0, (sum, l) => sum + l.lineTotal);
    if (paidAmount > totalAmount) {
      throw StateError('المدفوع أكبر من إجمالي الفاتورة');
    }
    final remaining = totalAmount - paidAmount;

    final journalLines = <JournalLine>[];
    final commissionDues = <CommissionDue>[];
    final updatedProducts = <String, double>{};

    // 1. Debit: Cash/Bank for the paid amount.
    if (paidAmount > 0) {
      final cashAccount = _getAccount(
        accounts,
        paymentMethod == 'cash' ? '1010' : '1015',
      );
      journalLines.add(
        JournalLine(
          accountId: cashAccount.id,
          accountCode: cashAccount.code,
          accountName: cashAccount.name,
          debit: paidAmount,
          credit: 0,
          description: 'مقبوضات نقدية/بنكية - فاتورة مبيعات',
        ),
      );
    }

    // 2. Debit: Accounts Receivable (1020) for the remainder.
    if (remaining > 0) {
      final arAccount = _getAccount(accounts, '1020');
      journalLines.add(
        JournalLine(
          accountId: arAccount.id,
          accountCode: arAccount.code,
          accountName: arAccount.name,
          debit: remaining,
          credit: 0,
          description: 'ذمم مدينة - فاتورة مبيعات',
        ),
      );
    }

    // 3. Credit: Sales Revenue (4010). No COGS, no inventory — this matches
    //    the shipped RPC (revenue-only sales; 5010/1030 move via journals).
    final revenueAccount = _getAccount(accounts, '4010');
    for (final line in lines) {
      final product = products[line.productId]!;
      journalLines.add(
        JournalLine(
          accountId: revenueAccount.id,
          accountCode: revenueAccount.code,
          accountName: revenueAccount.name,
          debit: 0,
          credit: line.lineTotal,
          description: 'إيرادات مبيعات - ${product.name}',
        ),
      );

      // Commission dues only for products linked to a commission supplier.
      final supplier = product.supplierId == null
          ? null
          : suppliers[product.supplierId];
      if (supplier != null && supplier.dealType == SupplierDealType.commission) {
        final rate =
            product.commissionRate ?? supplier.commissionRate ?? 0.0;
        if (rate > 0) {
          final commissionAmount = (line.lineTotal * (rate / 100)).round();
          final supplierDue = line.lineTotal - commissionAmount;
          commissionDues.add(
            CommissionDue(
              id: const Uuid().v4(),
              invoiceId: '',
              productId: product.id,
              supplierId: product.supplierId!,
              dueAmount: supplierDue,
              status: 'pending',
              rate: rate,
              commissionAmount: commissionAmount,
              date: invoiceDate,
              createdAt: DateTime.now(),
            ),
          );
        }
      }

      updatedProducts[product.id] = product.qty - line.qty;
    }

    // Create journal entry.
    final journalEntry = JournalEntry.create(
      date: invoiceDate,
      memo: memo.isEmpty
          ? 'فاتورة بيع ${invoiceDate.toIso8601String().split('T').first}'
          : memo,
      lines: journalLines,
      sourceType: 'sale',
    );

    // Validate balance.
    if (!journalEntry.isBalanced) {
      throw UnbalancedEntryException(
        journalEntry,
        'Sale invoice journal entry is not balanced',
      );
    }

    return DoubleEntryResult(
      journalEntry: journalEntry,
      commissionDues: commissionDues.isEmpty ? null : commissionDues,
      updatedEntities: {'products': updatedProducts},
    );
  }

  /// Mirrors `create_purchase_invoice` (direct vs consignment).
  /// Consignment receipts post NO journal entry.
  static DoubleEntryResult createPurchaseInvoice({
    required String requestId,
    required Supplier supplier,
    required List<PurchaseInvoiceLine> lines,
    required DateTime invoiceDate,
    required int paidAmount,
    required String paymentMethod,
    required String memo,
    required Map<String, Account> accounts,
    required Map<String, Product> products,
  }) {
    if (lines.isEmpty) throw StateError('لا توجد أصناف في الفاتورة');
    final isConsignment = supplier.dealType == SupplierDealType.commission;

    if (paidAmount < 0 ||
        (paidAmount > 0 &&
            (paymentMethod != 'cash' && paymentMethod != 'bank'))) {
      throw StateError('طريقة دفع غير صحيحة');
    }
    if (isConsignment && paidAmount > 0) {
      throw StateError('لا يمكن دفع فاتورة استلام بالعمولة');
    }

    final totalAmount = lines.fold<int>(0, (sum, l) => sum + l.lineTotal);
    if (paidAmount > totalAmount) {
      throw StateError('المدفوع أكبر من إجمالي الفاتورة');
    }
    final remaining = totalAmount - paidAmount;

    final journalLines = <JournalLine>[];
    final updatedProducts = <String, double>{};

    // 1. Debit: Inventory (1030) for all lines — ONLY for owned purchases.
    //    Consignment receipts post NO journal at all (stock moves via the
    //    updated-products mirror), exactly like the shipped RPC.
    if (!isConsignment) {
      for (final line in lines) {
        final product =
            products[line.productId] ?? _productFromDraft(line.newProduct!);
        if (line.qty <= 0) throw StateError('الكمية غير صحيحة');

        final inventoryAccount = _getAccount(accounts, '1030');
        journalLines.add(
          JournalLine(
            accountId: inventoryAccount.id,
            accountCode: inventoryAccount.code,
            accountName: inventoryAccount.name,
            debit: line.lineTotal,
            credit: 0,
            description: 'مخزون - شراء ${product.name}',
          ),
        );

        updatedProducts[product.id] = product.qty + line.qty;
      }
    } else {
      for (final line in lines) {
        final product =
            products[line.productId] ?? _productFromDraft(line.newProduct!);
        if (line.qty <= 0) throw StateError('الكمية غير صحيحة');
        updatedProducts[product.id] = product.qty + line.qty;
      }
    }

    // 2. Credit lines ONLY for owned purchases (real debt). Consignment keeps
    //    a stock-receipt-only entry with zero debt, exactly like the RPC.
    if (!isConsignment) {
      if (paidAmount > 0) {
        final cashAccount = _getAccount(
          accounts,
          paymentMethod == 'cash' ? '1010' : '1015',
        );
        journalLines.add(
          JournalLine(
            accountId: cashAccount.id,
            accountCode: cashAccount.code,
            accountName: cashAccount.name,
            debit: 0,
            credit: paidAmount,
            description: 'مدفوعات نقدية/بنكية - فاتورة مشتريات',
          ),
        );
      }

      if (remaining > 0) {
        final apAccount = _getAccount(accounts, '2010');
        journalLines.add(
          JournalLine(
            accountId: apAccount.id,
            accountCode: apAccount.code,
            accountName: apAccount.name,
            debit: 0,
            credit: remaining,
            description: 'ذمم دائنة - فاتورة مشتريات',
          ),
        );
      }
    }

    final journalEntry = JournalEntry.create(
      date: invoiceDate,
      memo: memo.isEmpty
          ? 'فاتورة شراء '
              '${isConsignment ? '(بضاعة أمانة)' : ''}'
          : memo,
      lines: journalLines,
      sourceType: 'purchase',
    );

    if (!journalEntry.isBalanced) {
      throw UnbalancedEntryException(
        journalEntry,
        'Purchase invoice journal entry is not balanced',
      );
    }

    return DoubleEntryResult(
      journalEntry: journalEntry,
      updatedEntities: {'products': updatedProducts},
    );
  }

  /// Mirrors `record_payment` (invoice-scoped, cash or bank).
  static DoubleEntryResult recordPayment({
    required String requestId,
    required Invoice invoice,
    required int amount,
    required String method, // 'cash' | 'bank'
    required DateTime date,
    required String note,
    required Map<String, Account> accounts,
  }) {
    if (amount <= 0) throw StateError('مبلغ الدفع غير صحيح');
    if (method != 'cash' && method != 'bank') {
      throw StateError('طريقة دفع غير صحيحة');
    }
    if (invoice.ownership == InvoiceOwnership.consignment) {
      throw StateError('لا يمكن سداد فاتورة بالعمولة');
    }
    if (amount > invoice.remaining) {
      throw StateError('المبلغ أكبر من المتبقي على الفاتورة');
    }

    final journalLines = <JournalLine>[];
    final isSale = invoice.type == 'sale';

    // Debit: Cash/Bank.
    final cashAccount = _getAccount(
      accounts,
      method == 'cash' ? '1010' : '1015',
    );
    journalLines.add(
      JournalLine(
        accountId: cashAccount.id,
        accountCode: cashAccount.code,
        accountName: cashAccount.name,
        debit: amount,
        credit: 0,
        description: isSale ? 'تحصيل من عميل' : 'دفع لمورد',
      ),
    );

    // Credit: AR (sale) or AP (purchase).
    final arApAccount = _getAccount(accounts, isSale ? '1020' : '2010');
    journalLines.add(
      JournalLine(
        accountId: arApAccount.id,
        accountCode: arApAccount.code,
        accountName: arApAccount.name,
        debit: 0,
        credit: amount,
        description: isSale ? 'ذمم مدينة - تحصيل' : 'ذمم دائنة - دفع',
      ),
    );

    final journalEntry = JournalEntry.create(
      date: date,
      memo: note.isEmpty
          ? (isSale ? 'سداد فاتورة بيع' : 'سداد فاتورة شراء')
          : note,
      lines: journalLines,
      sourceType: 'payment',
      sourceId: invoice.id,
    );

    if (!journalEntry.isBalanced) {
      throw UnbalancedEntryException(
        journalEntry,
        'Payment journal entry is not balanced',
      );
    }

    return DoubleEntryResult(journalEntry: journalEntry);
  }

  /// Mirrors `settle_supplier`: two oldest-first passes (owned purchase
  /// invoices, then commission dues) — same allocation the RPC performs —
  /// journaling ONE balanced entry (Dr cash/bank, Cr 2010).
  ///
  /// [invoices] must be the supplier's owned purchase invoices with
  /// `remaining > 0`, oldest first (by date, then created_at).
  /// [dues] must be their commission dues with `remaining > 0`, oldest first.
  static DoubleEntryResult settleSupplier({
    required String requestId,
    required List<Invoice> invoices,
    required List<CommissionDue> dues,
    required int totalAmount,
    required String method,
    required DateTime date,
    required String note,
    required Map<String, Account> accounts,
  }) {
    if (totalAmount <= 0) throw StateError('مبلغ التسوية غير صحيح');
    if (method != 'cash' && method != 'bank') {
      throw StateError('طريقة دفع غير صحيحة');
    }

    final allocations = <SettlementAllocation>[];
    var amount = totalAmount;

    // Pass 1: owned purchase invoices, oldest first.
    for (final invoice in invoices) {
      if (amount <= 0) break;
      final take = amount < invoice.remaining ? amount : invoice.remaining;
      if (take > 0) {
        allocations.add(
          SettlementAllocation(
            invoiceId: invoice.id,
            no: invoice.no,
            amount: take,
          ),
        );
        amount -= take;
      }
    }

    // Pass 2: commission dues, oldest first.
    for (final due in dues) {
      if (amount <= 0) break;
      final remaining = due.remaining ?? due.dueAmount;
      final take = amount < remaining ? amount : remaining;
      if (take > 0) {
        allocations.add(
          SettlementAllocation(
            invoiceId: due.invoiceId,
            dueId: due.id,
            amount: take,
          ),
        );
        amount -= take;
      }
    }

    if (amount > 0) {
      throw StateError('المبلغ المطلوب تسويته أكبر من ديون المورد');
    }
    if (allocations.isEmpty) {
      throw StateError('لا توجد ديون مستحقة لهذا المورد');
    }

    final allocated = allocations.fold<int>(0, (sum, a) => sum + a.amount);
    final journalLines = <JournalLine>[];

    // Debit: Cash/Bank.
    final cashAccount = _getAccount(
      accounts,
      method == 'cash' ? '1010' : '1015',
    );
    journalLines.add(
      JournalLine(
        accountId: cashAccount.id,
        accountCode: cashAccount.code,
        accountName: cashAccount.name,
        debit: allocated,
        credit: 0,
        description: 'تسوية مورد',
      ),
    );

    // Credit: AP (2010) for the whole allocation.
    final apAccount = _getAccount(accounts, '2010');
    journalLines.add(
      JournalLine(
        accountId: apAccount.id,
        accountCode: apAccount.code,
        accountName: apAccount.name,
        debit: 0,
        credit: allocated,
        description: 'تسوية مورد',
      ),
    );

    final journalEntry = JournalEntry.create(
      date: date,
      memo: note.isEmpty ? 'تسوية مورد' : note,
      lines: journalLines,
      sourceType: 'payment',
    );

    if (!journalEntry.isBalanced) {
      throw UnbalancedEntryException(
        journalEntry,
        'Supplier settlement journal entry is not balanced',
      );
    }

    return DoubleEntryResult(
      journalEntry: journalEntry,
      allocations: allocations,
    );
  }

  /// Mirrors `add_employee_movement` — the RPC does NOT journal movements;
  /// it inserts the movement row (and, for product deductions, moves
  /// inventory) and returns the value in agorot. The empty-lines journal is
  /// returned for API symmetry and is never persisted by the offline writer.
  static DoubleEntryResult addEmployeeMovement({
    required String requestId,
    required Employee employee,
    required DateTime month,
    required String direction, // 'in' | 'out'
    required String category, // 'bonus' | 'allowance' | 'advance' | 'product' | 'other'
    int? amount,
    Product? product, // required for category == 'product'
    double? qty, // required for category == 'product'
    required DateTime date,
    required String note,
    required Map<String, Account> accounts,
  }) {
    if (direction != 'in' && direction != 'out') {
      throw StateError('اتجاه الحركة غير صحيح');
    }
    if (direction == 'in' &&
        category != 'bonus' &&
        category != 'allowance') {
      throw StateError('الإضافات تكون مكافأة أو بدل فقط');
    }
    if (direction == 'out' &&
        category != 'advance' &&
        category != 'product' &&
        category != 'other') {
      throw StateError('الخصومات تكون سلفة أو منتج أو أخرى فقط');
    }

    var value = amount ?? 0;
    Map<String, double>? productUpdates;

    if (category == 'product') {
      if (product == null || qty == null || qty <= 0) {
        throw StateError('خصم المنتج يتطلب المنتج والكمية');
      }
      if (product.qty - qty < 0) {
        throw StateError(
          'الكمية غير متوفرة في المخزون — المتاح ${product.qty}, المطلوب $qty',
        );
      }
      value = (qty * product.purchasePrice).round();
      productUpdates = {product.id: product.qty - qty};
    } else {
      if (amount == null || amount <= 0) {
        throw StateError('المبلغ غير صحيح');
      }
    }

    final journalEntry = JournalEntry.create(
      date: date,
      memo: note.isEmpty ? 'حركة موظف: $category' : note,
      lines: const [],
      sourceType: 'salary',
      sourceId: employee.id,
    );

    return DoubleEntryResult(
      journalEntry: journalEntry,
      amount: value,
      updatedEntities: productUpdates == null
          ? null
          : {'products': productUpdates},
    );
  }

  /// Mirrors `pay_salary` — clears prior arrears and books the month's wage
  /// expense with a balanced entry.
  static DoubleEntryResult paySalary({
    required String requestId,
    required Employee employee,
    required DateTime month,
    required int paidAmount,
    required int netDue,
    required int arrears,
    required String method,
    required DateTime date,
    required String note,
    required Map<String, Account> accounts,
  }) {
    if (paidAmount < 0) throw StateError('مبلغ الصرف غير صحيح');
    if (method != 'cash' && method != 'bank') {
      throw StateError('طريقة دفع غير صحيحة');
    }
    if (netDue <= 0) throw StateError('لا توجد مستحقات للصرف لهذا الشهر');
    if (paidAmount > netDue) {
      throw StateError('المبلغ المصروف أكبر من المستحقات');
    }

    final clear = arrears < paidAmount ? arrears : paidAmount;
    final carry = netDue - paidAmount;
    final journalLines = <JournalLine>[];

    final payableAccount = _getAccount(accounts, '2030');
    final wagesAccount = _getAccount(accounts, '5030');

    // DR: prior arrears cleared.
    if (clear > 0) {
      journalLines.add(
        JournalLine(
          accountId: payableAccount.id,
          accountCode: payableAccount.code,
          accountName: payableAccount.name,
          debit: clear,
          credit: 0,
          description: 'تسوية متأخرات - ${employee.name}',
        ),
      );
    }

    // DR: this month's net wage expense.
    if (netDue - clear > 0) {
      journalLines.add(
        JournalLine(
          accountId: wagesAccount.id,
          accountCode: wagesAccount.code,
          accountName: wagesAccount.name,
          debit: netDue - clear,
          credit: 0,
          description: 'أجور شهر - ${employee.name}',
        ),
      );
    }

    // CR: cash/bank paid.
    final cashAccount = _getAccount(
      accounts,
      method == 'cash' ? '1010' : '1015',
    );
    journalLines.add(
      JournalLine(
        accountId: cashAccount.id,
        accountCode: cashAccount.code,
        accountName: cashAccount.name,
        debit: 0,
        credit: paidAmount,
        description: 'صرف راتب - ${employee.name}',
      ),
    );

    // CR: arrears carried forward.
    if (carry > 0) {
      journalLines.add(
        JournalLine(
          accountId: payableAccount.id,
          accountCode: payableAccount.code,
          accountName: payableAccount.name,
          debit: 0,
          credit: carry,
          description: 'متأخرات شهر - ${employee.name}',
        ),
      );
    }

    final journalEntry = JournalEntry.create(
      date: date,
      memo: note.isEmpty ? 'دفع راتب موظف' : note,
      lines: journalLines,
      sourceType: 'salary',
      sourceId: employee.id,
    );

    if (!journalEntry.isBalanced) {
      throw UnbalancedEntryException(
        journalEntry,
        'Salary payment journal entry is not balanced',
      );
    }

    return DoubleEntryResult(journalEntry: journalEntry);
  }

  /// Mirrors `adjust_inventory` — the RPC does NOT journal counts; it moves
  /// stock only and updates the product quantity. The empty-lines journal is
  /// never persisted.
  static DoubleEntryResult adjustInventory({
    required String requestId,
    required Product product,
    required double countedQty,
    required String reason,
    required DateTime date,
    required Map<String, Account> accounts,
  }) {
    if (countedQty < 0) throw StateError('الكمية المقروءة غير صحيحة');
    final delta = countedQty - product.qty;
    if (delta == 0) {
      throw StateError('No adjustment needed: counted qty equals current qty');
    }

    final journalEntry = JournalEntry.create(
      date: date,
      memo: 'تعديل جرد: $reason',
      lines: const [],
      sourceType: 'inventory',
      sourceId: product.id,
    );

    return DoubleEntryResult(
      journalEntry: journalEntry,
      updatedEntities: {
        'products': {product.id: countedQty},
      },
    );
  }

  static Product _productFromDraft(ProductDraft draft) {
    return Product(
      id: const Uuid().v4(),
      name: draft.name,
      barcode: null,
      unit: draft.unit,
      unitType: draft.unitType == 'weight'
          ? ProductUnitType.weight
          : ProductUnitType.count,
      salePrice: draft.salePrice,
      purchasePrice: draft.costPrice,
      qty: draft.qtyOnHand.toDouble(),
      reorderLevel: draft.reorderLevel.toDouble(),
      supplierId: draft.supplierId,
      commissionRate: draft.commissionRate,
    );
  }

  static Account _getAccount(Map<String, Account> accounts, String code) {
    final account = accounts[code];
    if (account == null) {
      throw StateError(
        'Required account not found in chart of accounts: $code',
      );
    }
    return account;
  }
}