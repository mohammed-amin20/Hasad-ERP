import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasad_erp/domain/invoices/invoice.dart';
import 'package:hasad_erp/presentation/providers/sales_providers.dart';
import 'package:hasad_erp/presentation/widgets/payment_sheets.dart';
import 'package:hasad_erp/presentation/widgets/sheet_error_banner.dart';

import '../tool/offline_invoice_harness.dart';

/// Issue 3 (device), at the real submit boundary, for the OTHER half of the
/// defect: a purchase invoice the user sees came from the SERVER, and settling
/// against that supplier must work with no network.
///
/// `settleSupplier` builds its allocation set by enumerating the supplier's open
/// PURCHASE rows in the local mirror. `OfflineInvoiceRepository.list()`
/// cache-lasts a JSON report and never mirrors invoice headers, so a
/// server-created purchase has no local row to allocate against — the device
/// reports a settlement that cannot be applied to the very debt the list shows.
///
/// This is the data-layer defect exercised through production code only: the
/// real `list()` performs the read, the real `_SettleSupplierSheet` collects the
/// input, and the real `PaymentActions.settle` →
/// `OfflineAwarePaymentRepository` → `OfflineWriteCoordinator.settleSupplier`
/// performs the write. Nothing on that path is overridden.
void main() {
  late OfflineInvoiceHarness h;
  late ProviderContainer container;

  setUp(() async {
    h = await OfflineInvoiceHarness.create();
    h.network.serverInvoices = [
      h.serverInvoice(
        type: 'purchase',
        id: 'inv-purchase-9001',
        no: 'PUR-9001',
        partyName: seedSupplierName,
        total: 100000,
        date: DateTime(2026, 3, 1),
      ),
    ];
  });

  tearDown(() => h.close());

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(Scaffold)));

  Future<T> real<T>(WidgetTester tester, Future<T> Function() body) {
    final completer = Completer<T>();
    return tester.runAsync(() async {
      try {
        completer.complete(await body());
      } catch (error, stack) {
        completer.completeError(error, stack);
      }
    }).then((_) => completer.future);
  }

  /// The production read path. No manual seeding of `local_invoices` — whatever
  /// the settlement can allocate against afterwards is exactly what the read
  /// left behind.
  Future<List<Invoice>> readPurchaseList(WidgetTester tester) => real(
        tester,
        () =>
            container.read(invoiceRepositoryProvider).list(type: 'purchase'),
      );

  testWidgets(
      'an offline settlement against a server-created purchase is applied, not '
      'rejected as unpayable debt', (tester) async {
    await tester.pumpWidget(harnessHost(const SizedBox(), h));
    await tester.pumpAndSettle();
    container = containerOf(tester);
    await settleOfflineWriteGraph(tester, container);

    // --- the read the user actually performed --------------------------
    final listed = await readPurchaseList(tester);
    expect(listed.map((i) => i.id), contains('inv-purchase-9001'));
    // The fix in one line: the read left an allocatable row in the local mirror
    // the settlement path resolves against. This used to assert `isEmpty` — it
    // encoded the DEFECT, so the suite was green while the product was broken.
    final mirrored = await real(tester, () => h.store.invoices(harnessTenant));
    expect(mirrored.map((r) => r.id), contains('inv-purchase-9001'));
    expect(
      mirrored.firstWhere((r) => r.id == 'inv-purchase-9001').synced,
      isTrue,
    );

    // --- connectivity drops, then the user settles that supplier ------
    h.network.offline = true;

    await tester.pumpWidget(
        harnessHost(const _SettlementLauncher(), h));
    await pumpSheet(tester);
    // A fresh `ProviderScope` means a fresh container with an undelivered auth
    // stream; without this the settlement resolves `paymentRepository` to its
    // Supabase branch. See `settleOfflineWriteGraph`.
    container = containerOf(tester);
    await settleOfflineWriteGraph(tester, container);
    expect(find.text('تسوية المورد'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, '100');
    await pumpSheet(tester);
    await tester.tap(find.text('تنفيذ التسوية'));
    await settleInvoiceReads(tester);

    // --- the failure the device reported must NOT be what we see -------
    // Probed by WIDGET TYPE, not the Arabic string: the message is a production
    // literal with diacritics, and retyping it is how a suite ends up asserting
    // nothing. `SheetErrorBanner` only exists while the submit failed and the
    // sheet stayed open.
    expect(find.byType(SheetErrorBanner), findsNothing,
        reason: 'a debt the list is showing must be settleable offline');

    // --- durable state is the real proof -------------------------------
    final row = (await real(tester, () => h.store.invoices(harnessTenant)))
        .firstWhere((r) => r.id == 'inv-purchase-9001');
    expect(row.paid, 10000, reason: '100 entered as 10000 agorot');
    expect(row.remaining, 90000, reason: 'the full debt was 100000 agorot');
    expect(row.status, 'partial');
    expect(row.pendingMoneyLeg, isNotNull,
        reason: 'a local money mutation now owns this row');

    final legs = await real(tester, () => h.store.queueLegsFor(harnessTenant));
    expect(legs.where((l) => l.rpc == 'settle_supplier'), hasLength(1));
  });
}

/// Opens the real settlement sheet on mount, the way the supplier-debts row
/// action does.
class _SettlementLauncher extends ConsumerWidget {
  const _SettlementLauncher();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        showSettleSupplierSheet(
          context,
          supplierId: seedSupplierId,
          supplierName: seedSupplierName,
        );
      }
    });
    return const SizedBox.shrink();
  }
}
