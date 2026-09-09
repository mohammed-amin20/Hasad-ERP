import 'package:uuid/uuid.dart';

import 'journal_entry.dart';
import 'account.dart';
import 'invoice_lines.dart';
import '../customers/customer.dart';
import '../products/product.dart';
import '../products/product.dart' show ProductUnitType;
import '../suppliers/supplier.dart' show Supplier, SupplierDealType;
import '../employees/employee.dart' show Employee;
import '../invoices/invoice.dart';
import '../../core/utils/money.dart';

/// Result of a double-entry operation
class DoubleEntryResult {
  const DoubleEntryResult({
    required this.journalEntry,
    this.invoice,
    this.commissionDues,
    this.updatedEntities,
  });

  final JournalEntry journalEntry;
  final Invoice? invoice;
  final List<CommissionDue>? commissionDues;
  final Map<String, dynamic>? updatedEntities;
}

/// Commission due record (mirroring DB)
class CommissionDue {
  const CommissionDue({
    required this.id,
    required this.invoiceId,
    required this.productId,
    required this.supplierId,
    required this.dueAmount,
    required this.status,
    this.createdAt,
  });

  final String id;
  final String invoiceId;
  final String productId;
  final String supplierId;
  final int dueAmount;
  final String status; // 'pending', 'paid'
  final DateTime? createdAt;
}

/// Core double-entry accounting engine
/// Mirrors the Supabase RPC logic in pure Dart for offline use
class DoubleEntryEngine {
  /// Create a balanced journal entry for a sale invoice
  /// Mirrors `create_sale_invoice` RPC logic
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
  }) {
    // Validate inventory availability
    for (final line in lines) {
      final product = products[line.productId];
      if (product == null) {
        throw ArgumentError('Product not found: ${line.productId}');
      }
      if (product.qty < line.qty) {
        throw StateError(
            'Insufficient inventory for ${product.name}: available ${product.qty}, requested ${line.qty}');
      }
    }

    // Calculate totals
    final totalAmount = lines.fold<int>(0, (sum, l) => sum + l.lineTotal);
    final remaining = totalAmount - paidAmount;

    // Build journal lines
    final journalLines = <JournalLine>[];
    final commissionDues = <CommissionDue>[];
    final updatedProducts = <String, double>{};

    // 1. Debit: Cash/Bank for paid amount
    if (paidAmount > 0) {
      final cashAccount = _getAccount(accounts, paymentMethod == 'cash' ? '1010' : '1015');
      journalLines.add(JournalLine(
        accountId: cashAccount.id,
        accountCode: cashAccount.code,
        accountName: cashAccount.name,
        debit: paidAmount,
        credit: 0,
        description: 'مقبوضات نقدية/بنكية - فاتورة مبيعات',
      ));
    }

    // 2. Debit: Accounts Receivable (1020) for remaining
    if (remaining > 0) {
      final arAccount = _getAccount(accounts, '1020');
      journalLines.add(JournalLine(
        accountId: arAccount.id,
        accountCode: arAccount.code,
        accountName: arAccount.name,
        debit: remaining,
        credit: 0,
        description: 'ذمم مدينة - فاتورة مبيعات',
      ));
    }

    // 3. Credit: Sales Revenue (4010) + COGS (5010) + Inventory (1030) for each line
    for (final line in lines) {
      final product = products[line.productId]!;
      final revenueAccount = _getAccount(accounts, '4010');
      journalLines.add(JournalLine(
        accountId: revenueAccount.id,
        accountCode: revenueAccount.code,
        accountName: revenueAccount.name,
        debit: 0,
        credit: line.lineTotal,
        description: 'إيرادات مبيعات - ${product.name}',
      ));

      // COGS
      final cogsAccount = _getAccount(accounts, '5010');
      final cogsAmount = line.qty * product.purchasePrice;
      if (cogsAmount > 0) {
        journalLines.add(JournalLine(
          accountId: cogsAccount.id,
          accountCode: cogsAccount.code,
          accountName: cogsAccount.name,
          debit: cogsAmount,
          credit: 0,
          description: 'تكلفة البضاعة المباعة - ${product.name}',
        ));

        // Inventory credit
        final inventoryAccount = _getAccount(accounts, '1030');
        journalLines.add(JournalLine(
          accountId: inventoryAccount.id,
          accountCode: inventoryAccount.code,
          accountName: inventoryAccount.name,
          debit: 0,
          credit: cogsAmount,
          description: 'مخزون - ${product.name}',
        ));
      }

      // Commission due if product linked to commission supplier
      if (product.supplierId != null && product.commissionRate != null && product.commissionRate! > 0) {
        final dueAmount = (line.lineTotal * (1 - product.commissionRate!)).round();
        commissionDues.add(CommissionDue(
          id: const Uuid().v4(),
          invoiceId: '',
          productId: product.id,
          supplierId: product.supplierId!,
          dueAmount: dueAmount,
          status: 'pending',
          createdAt: DateTime.now(),
        ));
      }

      updatedProducts[product.id] = product.qty - line.qty;
    }

    // Create journal entry
    final journalEntry = JournalEntry.create(
      date: invoiceDate,
      memo: memo.isEmpty ? 'فاتورة مبيعات ${invoiceDate.toIso8601String().split('T').first}' : memo,
      lines: journalLines,
      sourceType: 'sale',
    );

    // Validate balance
    if (!journalEntry.isBalanced) {
      throw UnbalancedEntryException(journalEntry, 'Sale invoice journal entry is not balanced');
    }

    return DoubleEntryResult(
      journalEntry: journalEntry,
      commissionDues: commissionDues.isEmpty ? null : commissionDues,
      updatedEntities: {'products': updatedProducts},
    );
  }

  /// Create a balanced journal entry for a purchase invoice
  /// Mirrors `create_purchase_invoice` RPC logic
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
    final totalAmount = lines.fold<int>(0, (sum, l) => sum + l.lineTotal);
    final remaining = totalAmount - paidAmount;
    final isConsignment = supplier.dealType == SupplierDealType.commission;

    final journalLines = <JournalLine>[];
    final updatedProducts = <String, double>{};

    // 1. Debit: Inventory (1030) for all lines
    for (final line in lines) {
      final product = products[line.productId] ?? _productFromDraft(line.newProduct!);
      final inventoryAccount = _getAccount(accounts, '1030');
      final lineTotal = line.lineTotal;
      
      journalLines.add(JournalLine(
        accountId: inventoryAccount.id,
        accountCode: inventoryAccount.code,
        accountName: inventoryAccount.name,
        debit: lineTotal,
        credit: 0,
        description: 'مخزون - شراء ${product.name}',
      ));

      updatedProducts[product.id] = (product.qty) + line.qty;
    }

    // 2. Credit: Cash/Bank for paid amount (NOT for consignment)
    if (paidAmount > 0 && !isConsignment) {
      final cashAccount = _getAccount(accounts, paymentMethod == 'cash' ? '1010' : '1015');
      journalLines.add(JournalLine(
        accountId: cashAccount.id,
        accountCode: cashAccount.code,
        accountName: cashAccount.name,
        debit: 0,
        credit: paidAmount,
        description: 'مدفوعات نقدية/بنكية - فاتورة مشتريات',
      ));
    }

    // 3. Credit: Accounts Payable (2010) for remaining (NOT for consignment)
    // For consignment: Credit Consignment Liability (2015) instead
    if (remaining > 0 && !isConsignment) {
      final apAccount = _getAccount(accounts, '2010');
      journalLines.add(JournalLine(
        accountId: apAccount.id,
        accountCode: apAccount.code,
        accountName: apAccount.name,
        debit: 0,
        credit: remaining,
        description: 'ذمم دائنة - فاتورة مشتريات',
      ));
    } else if (isConsignment) {
      // Consignment: credit Consignment Liability (2015) for inventory received without debt
      final consignmentAccount = _getAccount(accounts, '2015');
      journalLines.add(JournalLine(
        accountId: consignmentAccount.id,
        accountCode: consignmentAccount.code,
        accountName: consignmentAccount.name,
        debit: 0,
        credit: totalAmount,
        description: 'ذمم أمانة - استلام بضاعة أمانة',
      ));
    }

    final journalEntry = JournalEntry.create(
      date: invoiceDate,
      memo: memo.isEmpty ? 'فاتورة مشتريات ${isConsignment ? '(أمانة)' : ''}' : memo,
      lines: journalLines,
      sourceType: 'purchase',
    );

    if (!journalEntry.isBalanced) {
      throw UnbalancedEntryException(journalEntry, 'Purchase invoice journal entry is not balanced');
    }

    return DoubleEntryResult(
      journalEntry: journalEntry,
      updatedEntities: {'products': updatedProducts},
    );
  }

  /// Create a balanced journal entry for payment/collection
  /// Mirrors `record_payment` RPC logic
  static DoubleEntryResult recordPayment({
    required String requestId,
    required Invoice invoice,
    required int amount,
    required String method, // 'cash' | 'bank'
    required DateTime date,
    required String note,
    required Map<String, Account> accounts,
  }) {
    final journalLines = <JournalLine>[];

    final isSale = invoice.type == 'sale';
    final isPurchase = invoice.type == 'purchase';

    // Debit: Cash/Bank
    final cashAccount = _getAccount(accounts, method == 'cash' ? '1010' : '1015');
    journalLines.add(JournalLine(
      accountId: cashAccount.id,
      accountCode: cashAccount.code,
      accountName: cashAccount.name,
      debit: amount,
      credit: 0,
      description: isSale ? 'تحصيل من عميل' : 'دفع لمورد',
    ));

    // Credit: AR (sale) or AP (purchase)
    final arApAccount = _getAccount(accounts, isSale ? '1020' : '2010');
    journalLines.add(JournalLine(
      accountId: arApAccount.id,
      accountCode: arApAccount.code,
      accountName: arApAccount.name,
      debit: 0,
      credit: amount,
      description: isSale ? 'ذمم مدينة - تحصيل' : 'ذمم دائنة - دفع',
    ));

    final journalEntry = JournalEntry.create(
      date: date,
      memo: note.isEmpty ? (isSale ? 'تحصيل فاتورة مبيعات' : 'دفع فاتورة مشتريات') : note,
      lines: journalLines,
      sourceType: 'payment',
      sourceId: invoice.id,
    );

    if (!journalEntry.isBalanced) {
      throw UnbalancedEntryException(journalEntry, 'Payment journal entry is not balanced');
    }

    return DoubleEntryResult(journalEntry: journalEntry);
  }

  /// Create a balanced journal entry for supplier settlement
  /// Mirrors `settle_supplier` RPC logic
  static DoubleEntryResult settleSupplier({
    required String requestId,
    required List<Invoice> invoices, // Oldest first (including commission dues)
    required int totalAmount,
    required String method,
    required DateTime date,
    required String note,
    required Map<String, Account> accounts,
  }) {
    final journalLines = <JournalLine>[];

    // Debit: Cash/Bank
    final cashAccount = _getAccount(accounts, method == 'cash' ? '1010' : '1015');
    journalLines.add(JournalLine(
      accountId: cashAccount.id,
      accountCode: cashAccount.code,
      accountName: cashAccount.name,
      debit: totalAmount,
      credit: 0,
      description: 'تسوية مورد',
    ));

    // Credit: AP for each invoice (oldest first)
    int remainingToSettle = totalAmount;
    final apAccount = _getAccount(accounts, '2010');
    
    for (final invoice in invoices) {
      if (remainingToSettle <= 0) break;
      final settleAmount = remainingToSettle < invoice.remaining ? remainingToSettle : invoice.remaining;
      if (settleAmount > 0) {
        journalLines.add(JournalLine(
          accountId: apAccount.id,
          accountCode: apAccount.code,
          accountName: apAccount.name,
          debit: 0,
          credit: settleAmount,
          description: 'تسوية فاتورة ${invoice.no}',
        ));
        remainingToSettle -= settleAmount;
      }
    }

    final journalEntry = JournalEntry.create(
      date: date,
      memo: note.isEmpty ? 'تسوية مورد' : note,
      lines: journalLines,
      sourceType: 'payment',
    );

    if (!journalEntry.isBalanced) {
      throw UnbalancedEntryException(journalEntry, 'Supplier settlement journal entry is not balanced');
    }

    return DoubleEntryResult(journalEntry: journalEntry);
  }

  /// Create a balanced journal entry for employee movement
  /// Mirrors `add_employee_movement` RPC logic
  static DoubleEntryResult addEmployeeMovement({
    required String requestId,
    required Employee employee,
    required DateTime month,
    required String direction, // 'deduct' | 'entitle'
    required String category, // 'advance', 'goods', 'bonus', 'allowance', 'other'
    required int amount,
    required DateTime date,
    required String note,
    required Map<String, Account> accounts,
    Product? product, // For 'goods' category
  }) {
    final journalLines = <JournalLine>[];
    final isDeduct = direction == 'deduct';

    if (isDeduct) {
      // Deduction: Dr Salaries Payable (2030), Cr Cash/Inventory
      final payableAccount = _getAccount(accounts, '2030');
      journalLines.add(JournalLine(
        accountId: payableAccount.id,
        accountCode: payableAccount.code,
        accountName: payableAccount.name,
        debit: amount,
        credit: 0,
        description: 'استقطاع موظف: $category - ${employee.name}',
      ));

      if (category == 'advance') {
        // Credit: Cash/Bank (assume cash for advance)
        final cashAccount = _getAccount(accounts, '1010');
        journalLines.add(JournalLine(
          accountId: cashAccount.id,
          accountCode: cashAccount.code,
          accountName: cashAccount.name,
          debit: 0,
          credit: amount,
          description: 'سلفة نقدية - ${employee.name}',
        ));
      } else if (category == 'goods' && product != null) {
        // Credit: Inventory (1030) at cost
        final inventoryAccount = _getAccount(accounts, '1030');
        journalLines.add(JournalLine(
          accountId: inventoryAccount.id,
          accountCode: inventoryAccount.code,
          accountName: inventoryAccount.name,
          debit: 0,
          credit: amount,
          description: 'مخزون - صرف أصناف للموظف ${employee.name}',
        ));
      } else {
        // Other deductions: Credit Cash
        final cashAccount = _getAccount(accounts, '1010');
        journalLines.add(JournalLine(
          accountId: cashAccount.id,
          accountCode: cashAccount.code,
          accountName: cashAccount.name,
          debit: 0,
          credit: amount,
          description: 'استقطاع موظف: $category - ${employee.name}',
        ));
      }
    } else {
      // Entitlement (bonus, allowance): Dr Wages Expense (5030), Cr Salaries Payable (2030)
      final expenseAccount = _getAccount(accounts, '5030');
      journalLines.add(JournalLine(
        accountId: expenseAccount.id,
        accountCode: expenseAccount.code,
        accountName: expenseAccount.name,
        debit: amount,
        credit: 0,
        description: 'استحقاق موظف: $category - ${employee.name}',
      ));

      final payableAccount = _getAccount(accounts, '2030');
      journalLines.add(JournalLine(
        accountId: payableAccount.id,
        accountCode: payableAccount.code,
        accountName: payableAccount.name,
        debit: 0,
        credit: amount,
        description: 'مستحقات موظفين - ${employee.name}',
      ));
    }

    final journalEntry = JournalEntry.create(
      date: date,
      memo: note.isEmpty ? 'حركة موظف: $category' : note,
      lines: journalLines,
      sourceType: 'salary',
      sourceId: employee.id,
    );

    if (!journalEntry.isBalanced) {
      throw UnbalancedEntryException(journalEntry, 'Employee movement journal entry is not balanced');
    }

    return DoubleEntryResult(
      journalEntry: journalEntry,
      updatedEntities: category == 'goods' && product != null 
          ? {'products': {product.id: product.qty - (amount ~/ product.purchasePrice)}} 
          : null,
    );
  }

  /// Create a balanced journal entry for salary payment
  /// Mirrors `pay_salary` RPC logic
  static DoubleEntryResult paySalary({
    required String requestId,
    required Employee employee,
    required DateTime month,
    required int paidAmount,
    required int netDue,
    required String method,
    required DateTime date,
    required String note,
    required Map<String, Account> accounts,
  }) {
    final journalLines = <JournalLine>[];

    // Debit: Salaries Payable (2030) - reduce liability
    final payableAccount = _getAccount(accounts, '2030');
    journalLines.add(JournalLine(
      accountId: payableAccount.id,
      accountCode: payableAccount.code,
      accountName: payableAccount.name,
      debit: paidAmount,
      credit: 0,
      description: 'دفع راتب - ${employee.name}',
    ));

    // Credit: Cash/Bank
    final cashAccount = _getAccount(accounts, method == 'cash' ? '1010' : '1015');
    journalLines.add(JournalLine(
      accountId: cashAccount.id,
      accountCode: cashAccount.code,
      accountName: cashAccount.name,
      debit: 0,
      credit: paidAmount,
      description: 'صرف راتب - ${employee.name}',
    ));

    final journalEntry = JournalEntry.create(
      date: date,
      memo: note.isEmpty ? 'دفع راتب موظف' : note,
      lines: journalLines,
      sourceType: 'salary',
      sourceId: employee.id,
    );

    if (!journalEntry.isBalanced) {
      throw UnbalancedEntryException(journalEntry, 'Salary payment journal entry is not balanced');
    }

    return DoubleEntryResult(journalEntry: journalEntry);
  }

  /// Create a balanced journal entry for inventory adjustment
  /// Mirrors `adjust_inventory` RPC logic
  static DoubleEntryResult adjustInventory({
    required String requestId,
    required Product product,
    required double countedQty,
    required String reason,
    required DateTime date,
    required Map<String, Account> accounts,
  }) {
    final delta = countedQty - product.qty;
    if (delta == 0) {
      throw StateError('No adjustment needed: counted qty equals current qty');
    }

    final journalLines = <JournalLine>[];
    final inventoryAccount = _getAccount(accounts, '1030');
    final adjustmentAccount = _getAccount(accounts, delta > 0 ? '4020' : '5020');

    if (delta > 0) {
      // Gain: Debit Inventory, Credit Revenue
      journalLines.add(JournalLine(
        accountId: inventoryAccount.id,
        accountCode: inventoryAccount.code,
        accountName: inventoryAccount.name,
        debit: (delta * product.purchasePrice).round(),
        credit: 0,
        description: 'جرد: زيادة ${product.name}',
      ));
      journalLines.add(JournalLine(
        accountId: adjustmentAccount.id,
        accountCode: adjustmentAccount.code,
        accountName: adjustmentAccount.name,
        debit: 0,
        credit: (delta * product.purchasePrice).round(),
        description: 'إيرادات جرد - ${product.name}',
      ));
    } else {
      // Loss: Debit Expense, Credit Inventory
      journalLines.add(JournalLine(
        accountId: adjustmentAccount.id,
        accountCode: adjustmentAccount.code,
        accountName: adjustmentAccount.name,
        debit: ((-delta) * product.purchasePrice).round(),
        credit: 0,
        description: 'مصاريف جرد - ${product.name}',
      ));
      journalLines.add(JournalLine(
        accountId: inventoryAccount.id,
        accountCode: inventoryAccount.code,
        accountName: inventoryAccount.name,
        debit: 0,
        credit: ((-delta) * product.purchasePrice).round(),
        description: 'جرد: نقص ${product.name}',
      ));
    }

    final journalEntry = JournalEntry.create(
      date: date,
      memo: 'تعديل جرد: $reason',
      lines: journalLines,
      sourceType: 'inventory',
      sourceId: product.id,
    );

    if (!journalEntry.isBalanced) {
      throw UnbalancedEntryException(journalEntry, 'Inventory adjustment journal entry is not balanced');
    }

    return DoubleEntryResult(
      journalEntry: journalEntry,
      updatedEntities: {'products': {product.id: countedQty}},
    );
  }

  static Product _productFromDraft(ProductDraft draft) {
    return Product(
      id: const Uuid().v4(),
      name: draft.name,
      barcode: null,
      unit: draft.unit,
      unitType: draft.unitType == 'weight' ? ProductUnitType.weight : ProductUnitType.count,
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
      throw StateError('Required account not found in chart of accounts: $code');
    }
    return account;
  }
}