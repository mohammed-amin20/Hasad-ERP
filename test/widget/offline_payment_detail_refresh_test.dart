import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasad_erp/core/utils/money.dart';
import 'package:hasad_erp/data/offline/local_database.dart';
import 'package:hasad_erp/domain/invoices/invoice.dart';
import 'package:hasad_erp/presentation/providers/purchases_providers.dart';
import 'package:hasad_erp/presentation/providers/sales_providers.dart';
import 'package:hasad_erp/presentation/widgets/invoice_list.dart';
import 'package:hasad_erp/presentation/widgets/sheet_error_banner.dart';

import '../tool/offline_invoice_harness.dart';

/// An invoice's money is stale on screen the instant after a payment is recorded
/// offline: the write succeeds, the SnackBar quotes the new remaining, and the
/// open detail sheet still shows the old figures.
///
/// ## Why this is NOT a persistence or invalidation defect
///
/// `PaymentActions._refresh()` already invalidates `saleInvoicesListProvider` /
/// `purchaseInvoicesListProvider` after a successful write, and the offline
/// repository's `pendingMoneyLeg` merge already makes the local figures
/// authoritative. Both were proven by earlier suites; this one asserts the
/// durable row and the re-read list agree with the screen at every step, so a
/// failure here cannot be a data-layer one.
///
/// The defect is one level up: `InvoiceDetailSheet` took the row as an immutable
/// constructor argument (`builder: (_) => InvoiceDetailSheet(invoice: invoice)`
/// in both invoice screens) and watched nothing. The modal route above the list
/// is therefore never rebuilt by the invalidation the write performed, and it
/// keeps rendering the frozen `paid` / `remaining` / `status`.
///
/// So this suite drives the real boundary and proves the **same mounted sheet**
/// updates: no reopening, no manual `ref.invalidate`, no provider-container
/// recreation, no `Future.delayed`, and no fake post-payment invoice.
void main() {
  late OfflineInvoiceHarness h;

  setUp(() async {
    h = await OfflineInvoiceHarness.create();
  });

  tearDown(() => h.close());

  /// The harness scope's own container — the one carrying the overrides. A
  /// separate `ProviderContainer()` would rebuild the real repositories and hit
  /// `Supabase.instance`, which is uninitialised in a test isolate.
  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(Scaffold)));

  /// The value of a `_TotalRow`, located as a **label + value pair**.
  ///
  /// Never a bare `find.text(Money.format(x))`: once the invoice is paid off,
  /// `المدفوع` and `الإجمالي` render the same amount, so a bare-amount finder
  /// matches two widgets — and against some shapes of this bug it would match
  /// none, which is how a probe ends up asserting nothing. This is the same trap
  /// the income-statement salary probe hit.
  String shownTotal(String label) {
    final value = find
        .descendant(
          of: find
              .ancestor(of: find.text(label), matching: find.byType(Row))
              .first,
          matching: find.byType(Text),
        )
        .last;
    expect(value, findsOneWidget,
        reason: 'the "$label" row did not render exactly one value');
    // `element.widget`, never the element: `Text` extends `StatelessWidget`, so
    // its element is a `StatelessElement` and casting the element fails.
    return (value.evaluate().single.widget as Text).data!;
  }

  /// `MaterialApp` caps a modal bottom sheet at 9/16 of the screen, and the
  /// detail sheet is a `Column(mainAxisSize: min)` — at the default 800x600 its
  /// own rows are clipped. A tall viewport mounts all of them.
  void useTallViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(600, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  /// A successful write raises a SnackBar that sits over the bottom of the
  /// screen for 4s — exactly where the detail sheet's own `تسجيل دفعة` button is.
  /// Left alone it swallows the second tap, and the failure then reads as "the
  /// button is gone" instead of "the figure did not change". `pumpAndSettle`
  /// does not advance the dismissal timer, so the clock is moved explicitly.
  Future<void> letSnackBarClear(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  }

  /// The mirror row for [id], read inside a real-timer zone (a real drift read
  /// cannot complete in the fake-async one). Every assertion in this suite is
  /// also checked against this durable state, so a UI that never paints still
  /// fails.
  Future<LocalInvoiceRow> mirrorRow(WidgetTester tester, String id) async {
    final rows = await tester.runAsync(() => h.store.invoices(harnessTenant));
    return rows!.firstWhere((r) => r.id == id);
  }

  /// Records [amountText] (major units) through the real payment sheet, then
  /// waits for the write, its `_refresh()` and the re-read that triggers.
  Future<void> payThrough(WidgetTester tester, String amountText) async {
    await tester.enterText(find.byType(TextFormField).first, amountText);
    await pumpSheet(tester);
    await tester.tap(find.text('حفظ الدفعة'));
    await settleInvoiceReads(tester);
    expect(find.byType(SheetErrorBanner), findsNothing,
        reason: 'the sheet stayed open, so the write did not succeed');
  }

  // Both invoice screens share one detail component, so both providers are
  // pinned. Sale is the reported device path; purchase is the twin.
  const cases = [
    (type: 'sale', party: seedCustomerName, id: 'inv-srv-pay-1', no: 'SALE-9001'),
    (
      type: 'purchase',
      party: seedSupplierName,
      id: 'inv-srv-pay-2',
      no: 'PUR-9001',
    ),
  ];

  for (final c in cases) {
    testWidgets(
        'after an offline payment the mounted ${c.type} detail sheet shows the '
        'new paid, remaining and status', (tester) async {
      useTallViewport(tester);
      h.network.serverInvoices = [
        h.serverInvoice(
          type: c.type,
          id: c.id,
          no: c.no,
          partyName: c.party,
          total: 100000,
          date: DateTime(2026, 3, 1),
        ),
      ];

      await tester.pumpWidget(harnessHost(DetailLauncher(type: c.type), h));
      final container = containerOf(tester);
      // BEFORE the list resolves and the sheet opens: `_canPay` reads
      // `authStateProvider` at build time, so a sheet built before the auth
      // stream delivers renders without the payment button and never rebuilds.
      // The app cannot hit this (it gates its first frame on `localStoreProvider`
      // and the shell watches auth long before a row is reachable); a test that
      // drives providers directly must deliver auth itself.
      await settleOfflineWriteGraph(tester, container);
      await settleInvoiceReads(tester);
      await pumpSheet(tester);

      // The list read the user performed online is what mirrored this header.
      // Prove it exists, so a later "the figures are stale" failure cannot be
      // mistaken for "the header was never on the device".
      final mirrored = await mirrorRow(tester, c.id);
      expect(mirrored.synced, isTrue);
      expect(mirrored.pendingMoneyLeg, isNull);

      // --- the sheet is mounted, showing the PRE-payment money -------------
      expect(find.byType(InvoiceDetailSheet), findsOneWidget);
      expect(shownTotal('المدفوع'), Money.format(0));
      expect(shownTotal('المتبقي'), Money.format(100000));
      expect(find.text('غير مدفوعة'), findsOneWidget);
      expect(find.text('تسجيل دفعة'), findsOneWidget,
          reason: 'the harness user is an admin, so the button\'s absence later '
              'is about `remaining` and never about roles');

      // --- connectivity drops, then the user pays part of it --------------
      h.network.offline = true;
      final listCallsBefore = h.network.listCalls;

      await tester.tap(find.text('تسجيل دفعة'));
      await pumpSheet(tester);
      await settleInvoiceReads(tester);
      await payThrough(tester, '400');
      await letSnackBarClear(tester);

      expect(h.network.listCalls, greaterThan(listCallsBefore),
          reason: 'the post-write refresh must re-run the list, or this suite is '
              'observing a first read rather than the invalidation it exists to '
              'pin');

      // --- the SAME mounted sheet must now show the corrected money --------
      expect(find.byType(InvoiceDetailSheet), findsOneWidget,
          reason: 'the sheet was never closed and reopened; doing that would '
              'hide the defect instead of pinning it');
      expect(shownTotal('المدفوع'), Money.format(40000),
          reason: 'a payment recorded offline restates the mirror row, and an '
              'already-open sheet must show it with no manual refresh');
      expect(shownTotal('المتبقي'), Money.format(60000));
      expect(find.text('جزئية'), findsOneWidget);
      expect(find.text('تسجيل دفعة'), findsOneWidget,
          reason: 'a part-paid invoice is still payable');

      // --- paying the rest must settle it without leaving the sheet --------
      await tester.tap(find.text('تسجيل دفعة'));
      await pumpSheet(tester);
      await settleInvoiceReads(tester);
      await payThrough(tester, '600');
      await letSnackBarClear(tester);

      expect(shownTotal('المدفوع'), Money.format(100000));
      expect(shownTotal('المتبقي'), Money.format(0));
      expect(find.text('مدفوعة'), findsOneWidget);
      expect(find.text('تسجيل دفعة'), findsNothing,
          reason: 'a settled invoice offers nothing to pay; the payment sheet '
              'shares this title, which is why this runs only after it popped');

      // --- and the screen agrees with the durable authority ---------------
      final row = await mirrorRow(tester, c.id);
      expect(row.paid, 100000);
      expect(row.remaining, 0);
      expect(row.status, 'paid');
    });
  }
}

/// A list row the user tapped, handed to the sheet the way
/// `sale_invoices_screen.dart:209` and `purchase_invoices_screen.dart:145` hand
/// it: a snapshot of the row as the list currently holds it.
///
/// Opens the **detail** sheet — not the payment sheet — so the money under test
/// is the header's. Stateful and one-shot on purpose: the payment this suite
/// performs invalidates the list provider, so a stateless launcher would rebuild,
/// re-post the frame callback, and stack a second sheet on top of the one the
/// submit just popped — the failure mode `offline_payment_sheet_test.dart`
/// documents for its own launcher.
class DetailLauncher extends ConsumerStatefulWidget {
  const DetailLauncher({super.key, required this.type});

  final String type;

  @override
  ConsumerState<DetailLauncher> createState() => _DetailLauncherState();
}

class _DetailLauncherState extends ConsumerState<DetailLauncher> {
  bool _opened = false;

  @override
  Widget build(BuildContext context) {
    final invoices = ref
        .watch(widget.type == 'sale'
            ? saleInvoicesListProvider
            : purchaseInvoicesListProvider)
        .maybeWhen(data: (v) => v, orElse: () => const <Invoice>[]);
    if (!_opened && invoices.isNotEmpty) {
      _opened = true;
      final invoice = invoices.first;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          showModalBottomSheet<void>(
            context: context,
            builder: (_) => InvoiceDetailSheet(invoice: invoice),
          );
        }
      });
    }
    return const SizedBox.shrink();
  }
}