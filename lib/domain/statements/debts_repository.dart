import '../invoices/invoice.dart';

/// A party's outstanding balances, aggregated from the RLS-protected reads of
/// `invoices` and `commission_dues` (no separate DB object needed).
class PartyBalance {
  const PartyBalance({
    required this.id,
    required this.name,
    required this.amount,
  });

  final String id;
  final String name;
  final int amount;
}

/// Reads outstanding balances: customers (sale invoices remaining) and
/// suppliers (owned purchase remaining + commission_dues remaining).
abstract class DebtsRepository {
  Future<List<PartyBalance>> customerBalances();

  Future<List<PartyBalance>> supplierBalances();

  /// The not-settled amount for a supplier's owned purchase invoices.
  Future<int> supplierInvoiceDebt(String supplierId);

  /// The not-settled commission dues amount for a supplier.
  Future<int> supplierCommissionDebt(String supplierId);

  Future<List<Invoice>> partyInvoices({
    required String type,
    required String partyId,
  });
}
