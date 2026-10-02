import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasad_erp/domain/invoices/invoice.dart';
import 'package:hasad_erp/presentation/providers/sales_providers.dart';
import 'package:hasad_erp/presentation/widgets/payment_sheets.dart';
import 'package:hasad_erp/presentation/widgets/sheet_error_banner.dart';

import '../tool/offline_invoice_harness.dart';

/// Issue 3 (device), at the real submit boundary: the invoice the user taps in
/// the list came from the SERVER, and paying it must work with no network.
///
/// This is the data-layer defect exercised through production code only: the
/// real `OfflineInvoiceRepository.list()` performs the read that populates the
/// mirror, the real `_RecordPaymentSheet` collects the input, and the real
/// `PaymentActions.record` → `OfflineAwarePaymentRepository` →
/// `OfflineWriteCoordinator.recordPayment` performs the write. Nothing on that
/// path is overridden — only the "server" read and the debt providers that
/// `_refresh` invalidates.
void main() {
  late OfflineInvoiceHarness h;
  late ProviderContainer container;

  setUp(() async {
    h = await OfflineInvoiceHarness.create();
  });

  tearDown(() => h.close());

  /// The harness scope's own container — the one carrying the overrides. A
  /// separate `ProviderContainer()` would rebuild the real repositories and hit
  /// `Supabase.instance`, which is uninitialised in a test isolate.
  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(Scaffold)));

  /// Runs [body] in a real-timer zone: a real drift read and a real `cacheLast`
  /// cannot complete inside the fake-async zone, and rethrowing the original
  /// error (rather than leaving a `late` unset) keeps the failure readable.
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
  /// the payment can resolve afterwards is exactly what the read left behind.
  Future<List<Invoice>> readSaleList(WidgetTester tester) => real(
        tester,
        () => container.read(invoiceRepositoryProvider).list(type: 'sale'),
      );

  setUp(() {
    h.network.serverInvoices = [
      h.serverInvoice(
        type: 'sale',
        id: 'inv-srv-9001',
        no: 'SALE-9001',
        partyName: seedCustomerName,
        total: 100000,
        date: DateTime(2026, 3, 1),
      ),
    ];
  });

  testWidgets(
      'an offline payment on an invoice that came from the server is recorded '
      'locally, not rejected as "not local"', (tester) async {
    await tester.pumpWidget(harnessHost(const SizedBox(), h));
    await tester.pumpAndSettle();
    container = containerOf(tester);

    // --- the read the user actually performed --------------------------
    final listed = await readSaleList(tester);
    expect(listed.map((i) => i.id), contains('inv-srv-9001'));
    // The fix in one line: the read the user just performed left a resolvable
    // row in the local mirror the payment path resolves against. This
    // assertion used to read `isEmpty` — it encoded the DEFECT, and a green
    // suite was evidence the assertion was wrong, not that the code was right.
    final mirrored = await real(tester, () => h.store.invoices(harnessTenant));
    expect(mirrored.map((r) => r.id), contains('inv-srv-9001'));
    final header = mirrored.firstWhere((r) => r.id == 'inv-srv-9001');
    expect(header.synced, isTrue, reason: 'a server row is server-owned');
    expect(header.no, 'SALE-9001', reason: 'the official number, verbatim');
    expect(header.pendingMoneyLeg, isNull);
    expect(header.requestId, isNull, reason: 'no local write produced this row');
    expect(header.createdAt, isNull);

    // --- connectivity drops, then the user pays that invoice -----------
    h.network.offline = true;
    final invoice = listed.firstWhere((i) => i.id == 'inv-srv-9001');

    await tester.pumpWidget(harnessHost(_PaymentLauncher(invoice: invoice), h));
    await pumpSheet(tester);
    // Pumping the launcher mounted a FRESH `ProviderScope`, so this is a new
    // container and the auth stream is undelivered again. Settle it here, not
    // before the launcher: otherwise the write silently resolves
    // `paymentRepository` to its Supabase branch and the failure looks like the
    // product defect. See `settleOfflineWriteGraph`.
    container = containerOf(tester);
    await settleOfflineWriteGraph(tester, container);
    expect(find.text('تسجيل دفعة'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, '40');
    await pumpSheet(tester);
    await tester.tap(find.text('حفظ الدفعة'));
    await settleInvoiceReads(tester);

    // --- the failure the device reported must NOT be what we see -------
    // Probed by WIDGET TYPE, not by the Arabic string: the message is a
    // production literal with diacritics, and retyping it into a test is how a
    // suite ends up asserting nothing. `SheetErrorBanner` only exists while the
    // submit failed and the sheet stayed open.
    expect(find.byType(SheetErrorBanner), findsNothing,
        reason: 'an invoice the list is showing must be payable offline');

    // --- durable state is the real proof -------------------------------
    final row = (await real(tester, () => h.store.invoices(harnessTenant)))
        .firstWhere((r) => r.id == 'inv-srv-9001');
    expect(row.paid, 4000, reason: '40 entered as 4000 agorot');
    expect(row.remaining, 96000);
    expect(row.status, 'partial');
    expect(row.pendingMoneyLeg, isNotNull,
        reason: 'a local money mutation now owns this row');

    final legs = await real(tester, () => h.store.queueLegsFor(harnessTenant));
    expect(legs.where((l) => l.rpc == 'record_payment'), hasLength(1));
  });

  testWidgets(
      'the sheet reports success and the corrected figures survive the next '
      'read, so the mirror did not disturb the merge', (tester) async {
    await tester.pumpWidget(harnessHost(const SizedBox(), h));
    await tester.pumpAndSettle();
    container = containerOf(tester);

    final listed = await readSaleList(tester);
    final invoice = listed.firstWhere((i) => i.id == 'inv-srv-9001');

    h.network.offline = true;
    await tester.pumpWidget(harnessHost(_PaymentLauncher(invoice: invoice), h));
    await pumpSheet(tester);
    container = containerOf(tester);
    await settleOfflineWriteGraph(tester, container);
    // The amount defaults to the full remaining, so this pays the invoice off.
    await tester.tap(find.text('حفظ الدفعة'));
    await settleInvoiceReads(tester);

    // The sheet popped on success (it only pops after the write returns), and
    // the corrected figures are durable. The banner is also asserted here so a
    // failure that pops anyway cannot pass this case.
    expect(find.byType(SheetErrorBanner), findsNothing);
    expect(find.text('تسجيل دفعة'), findsNothing);

    // Re-read with the network still down: the base list can only come from the
    // cache, which holds the PRE-payment figures. The marked local row is the
    // only thing that can correct them, which is the P1 rule under test.
    final after = await readSaleList(tester);
    final row = after.firstWhere((i) => i.id == 'inv-srv-9001');
    expect(row.paid, 100000);
    expect(row.remaining, 0);
    // The domain model carries an enum; the DRIFT row carries the db string.
    // Asserting the enum here keeps the test from quietly comparing a String to
    // an enum (which fails for a reason unrelated to the payment).
    expect(row.status, InvoiceStatus.paid);
    expect(row.no, 'SALE-9001',
        reason: 'the official number, never a local placeholder');
  });
}

/// Opens the real sheet on mount, the way `invoice_list.dart:231` does when the
/// user taps the payment action on a row.
///
/// Opens EXACTLY ONCE, and that is load-bearing. A plain post-frame callback
/// runs on every build, and a successful payment invalidates the list provider
/// — so a stateless launcher rebuilds, re-posts the frame callback, and a
/// SECOND sheet opens on top of the one the first submit just popped. The
/// suite then reads the fresh sheet as "the submit never popped" and reports a
/// production bug that does not exist. Stateful + a one-shot guard, so the
/// assertion is about the submit and nothing else.
class _PaymentLauncher extends ConsumerStatefulWidget {
  const _PaymentLauncher({required this.invoice});

  final Invoice invoice;

  @override
  ConsumerState<_PaymentLauncher> createState() => _PaymentLauncherState();
}

class _PaymentLauncherState extends ConsumerState<_PaymentLauncher> {
  bool _opened = false;

  @override
  Widget build(BuildContext context) {
    if (!_opened) {
      _opened = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          showRecordPaymentSheet(context, invoice: widget.invoice);
        }
      });
    }
    return const SizedBox.shrink();
  }
}
