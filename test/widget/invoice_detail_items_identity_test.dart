import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasad_erp/core/widgets/app_progress.dart';
import 'package:hasad_erp/data/offline/local_database.dart';
import 'package:hasad_erp/data/offline/offline_invoice_repository.dart';
import 'package:hasad_erp/data/offline/offline_sync.dart';
import 'package:hasad_erp/data/offline/offline_write.dart';
import 'package:hasad_erp/domain/invoices/invoice.dart';
import 'package:hasad_erp/domain/purchases/purchase_invoice_draft.dart';
import 'package:hasad_erp/domain/sales/sale_invoice_draft.dart';
import 'package:hasad_erp/presentation/providers/purchases_providers.dart';
import 'package:hasad_erp/presentation/providers/sales_providers.dart';
import 'package:hasad_erp/presentation/widgets/invoice_list.dart';

import '../tool/offline_invoice_harness.dart';

/// Some invoices list fine and then open with **no products** — the header,
/// money and status are all correct, and the body is simply empty.
///
/// ## The lifecycle this pins
///
/// ```
/// L  = local uuid minted by the offline create
/// S  = server id issued by the replay RPC
///
/// offline create   -> local_invoices.id = L, local_invoice_items.invoiceId = L,
///                     sync_queue.localId = L, entity = 'invoices'
/// replay succeeds  -> id_map (localId: L, serverId: S); local_invoices.id is
///                     STILL L (markReplaySynced only writes `no` + `synced`);
///                     local_invoice_items.invoiceId is STILL L
/// list read        -> the synced, unmarked row drops out of _localOverrides, so
///                     the list serves the SERVER row and exposes S
/// detail sheet     -> opened earlier, while the invoice was still a draft, so it
///                     captured L
/// ```
///
/// The sheet then reads its lines under **L** while the list has moved to **S**.
/// `items()` cannot map that (the row is keyed `localId = L`, and `localIdFor`
/// resolves a **server** id, so `L` has no mapping), so it looks up the header
/// under L, finds it now `synced`, skips the draft short-circuit, and asks the
/// server for invoice L. The server never issued L, so the read succeeds with
/// **zero** rows — and `items()` mirrors the final value, and
/// `mirrorInvoiceItems` deletes before it checks for emptiness. The durable lines
/// are destroyed and the invoice is permanently empty.
///
/// Both halves are pinned separately, on purpose, because a one-token fix to
/// either would leave the other latent:
///  * R1/R2 here — the sheet must read the LIVE identity (fix #1).
///  * R6 in `offline_invoice_items_empty_mirror_test.dart` — an empty answer must
///    not delete durable rows (fix #2), proven with no sheet involved at all.
///
/// Real: the sheet, the coordinator that mints L, the queue leg, a real
/// `SyncFlusher` over `markReplaySynced`, `id_map`, the real offline repository,
/// real drift. Faked only at the network edge.
void main() {
  late OfflineInvoiceHarness h;

  setUp(() async {
    h = await OfflineInvoiceHarness.create();
    await h.store.upsertProduct(LocalProductRow(
      id: secondProductId,
      tenantId: harnessTenant,
      name: secondProductName,
      barcode: null,
      unit: seedUnit,
      unitType: 'count',
      salePrice: 50000,
      purchasePrice: 30000,
      qty: 40,
      reorderLevel: 5,
      supplierId: seedSupplierId,
      commissionRate: null,
      createdAt: DateTime.utc(2026, 1, 1),
      synced: false,
    ));
  });

  tearDown(() => h.close());

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(Scaffold)));

  /// `MaterialApp` caps a modal sheet at 9/16 of the screen and the detail body
  /// is a `Column(mainAxisSize: min)`, so at 800x600 the line rows are clipped
  /// away and every "the lines are missing" assertion would pass vacuously.
  void useTallViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(600, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  /// The line rows currently painted, by product name. Probing the NAME and not a
  /// bare amount: two lines priced differently would make an amount probe
  /// ambiguous, and a probe that cannot fail is worse than none.
  void expectLineVisible(String productName) {
    expect(
      find.textContaining(productName),
      findsWidgets,
      reason: 'the detail body must still list "$productName"',
    );
  }

  void expectNoLines() {
    expect(
      find.byType(AppProgress),
      findsNothing,
      reason: 'the read finished; a spinner here means the suite never settled '
          'and its "no lines" result would be vacuous',
    );
  }

  /// Creates the invoice through the REAL coordinator, so L is minted by
  /// production code and the durable rows are written by production code. The
  /// form is not driven: nothing about a form is under test here, and skipping
  /// it removes a whole class of harness coupling.
  Future<String> writeLocalInvoice(String type) async {
    final coordinator =
        OfflineWriteCoordinator(h.store, harnessTenant, () async => []);
    if (type == 'sale') {
      final result = await coordinator.writeSale(SaleInvoiceDraft(
        customerId: seedCustomerId,
        lines: const [
          SaleLineDraft(productId: seedProductId, qty: 2, price: 100000),
          SaleLineDraft(productId: secondProductId, qty: 1, price: 50000),
        ],
      ));
      return result.invoiceId;
    }
    final result = await coordinator.writePurchase(PurchaseInvoiceDraft(
      supplierId: seedSupplierId,
      lines: const [
        PurchaseLineDraft(productId: seedProductId, qty: 2, price: 60000),
        PurchaseLineDraft(productId: secondProductId, qty: 1, price: 30000),
      ],
    ));
    return result.invoiceId;
  }

  /// Drains the real queue through the real flusher, then hands the list the
  /// server's row so the merged list exposes S — exactly what a reconnect does.
  Future<void> replayAndRepublish(
      WidgetTester tester, String serverId, String type, String partyName,
      int total) async {
    h.target.nextServerId = serverId;
    h.target.nextServerNo = 'SERVER-9001';
    final summary = await tester.runAsync(
      () => SyncFlusher(h.store, harnessTenant, h.target).flush(),
    );
    expect(summary!.synced, greaterThan(0),
        reason: 'precondition: the create leg really replayed, otherwise this '
            'suite observes nothing and every assertion below is vacuous');

    // The server row is typed with the SAME type the case is exercising. A
    // `sale`-typed row published for the purchase case would be filtered out of
    // the purchase list, and the case would then fail on a precondition instead
    // of on the defect.
    h.network.serverInvoices = [
      h.serverInvoice(
        type: type,
        id: serverId,
        no: 'SERVER-9001',
        partyName: partyName,
        total: total,
        date: DateTime(2026, 3, 1),
      ),
    ];
  }

  const cases = [
    (type: 'sale', id: 'srv-sale-1', party: seedCustomerName),
    (type: 'purchase', id: 'srv-pur-1', party: seedSupplierName),
  ];

  for (final c in cases) {
    testWidgets(
        'R${c.type == 'sale' ? 1 : 2} — a mounted ${c.type} detail sheet keeps '
        'its lines after the invoice replays under a server id', (tester) async {
      useTallViewport(tester);

      final localId = await writeLocalInvoice(c.type);
      final caseTotal = c.type == 'sale' ? 250000 : 150000;

      // Precondition: the durable rows exist, under the LOCAL id, exactly as a
      // real offline create leaves them.
      final before = await h.store.invoiceItems(harnessTenant, localId);
      expect(before, hasLength(2),
          reason: 'precondition: the offline create wrote both lines under L');

      // The server holds the replayed invoice's lines under S — and has never
      // heard of L. A detail read that asks for L must therefore get [].
      h.network.itemsById = {
        c.id: [
          for (final r in before)
            InvoiceItem(
              productId: r.productId ?? '',
              productName: r.productName,
              productUnit: r.productUnit,
              qty: r.qty,
              price: r.price,
              total: r.total,
            ),
        ],
      };

      final repo = _RecordingInvoices(h.network, store: h.store, tenantId: harnessTenant);
      await tester.pumpWidget(
          harnessHost(DetailLauncher(type: c.type), h,
              invoiceRepository: repo));
      final container = containerOf(tester);
      await settleOfflineWriteGraph(tester, container);
      await settleInvoiceReads(tester);
      await pumpSheet(tester);

      // --- the sheet is mounted, opened while the invoice was still a DRAFT --
      expect(find.byType(InvoiceDetailSheet), findsOneWidget);
      expectLineVisible(seedProductName);
      expectLineVisible(secondProductName);
      expect(repo.detailIds.last, localId,
          reason: 'precondition: while the invoice is a pending draft the list '
              'exposes L, so the sheet captured L. If this fails, the rest of '
              'the case is not exercising the L→S transition at all.');

      // --- the replay: L is kept as the row key, S is recorded in id_map ----
      await replayAndRepublish(tester, c.id, c.type, c.party, caseTotal);
      final mapped = await h.store.serverIdFor(
          harnessTenant, 'invoices', localId);
      expect(mapped, c.id, reason: 'precondition: id_map must now carry L→S');
      final header = (await h.store.invoices(harnessTenant))
          .firstWhere((r) => r.id == localId);
      expect(header.synced, isTrue,
          reason: 'precondition: the header is now synced while STILL keyed L');

      // The reconnect makes the list serve the server row.
      container.invalidate(c.type == 'sale'
          ? saleInvoicesListProvider
          : purchaseInvoicesListProvider);
      await settleInvoiceReads(tester);

      // --- and the list genuinely now exposes S ----------------------------
      final listProvider = c.type == 'sale'
          ? saleInvoicesListProvider
          : purchaseInvoicesListProvider;
      final listed = container
          .read(listProvider)
          .maybeWhen(data: (v) => v, orElse: () => const <Invoice>[]);
      expect(listed.map((i) => i.id), contains(c.id),
          reason: 'precondition: the merged list must now expose the SERVER id, '
              'or the sheet has no reason to move off L and this case proves '
              'nothing');

      // --- the SAME mounted sheet must still show both lines ---------------
      expect(find.byType(InvoiceDetailSheet), findsOneWidget,
          reason: 'the sheet was never closed and reopened; doing that would '
              'hide the defect instead of pinning it');
      expectNoLines();
      expectLineVisible(seedProductName);
      expectLineVisible(secondProductName);

      // --- and the durable rows must not have been destroyed --------------
      final after = await h.store.invoiceItems(harnessTenant, localId);
      expect(after, hasLength(2),
          reason: 'a successful read of an id the server never issued must not '
              'delete the invoice\'s only durable copy of its lines');
    });

    testWidgets(
        'R5 — the ${c.type} detail item read follows the live identity, not the '
        'captured one', (tester) async {
      useTallViewport(tester);
      final localId = await writeLocalInvoice(c.type);
      h.network.itemsById = const {};

      final repo = _RecordingInvoices(h.network, store: h.store, tenantId: harnessTenant);
      await tester.pumpWidget(
          harnessHost(DetailLauncher(type: c.type), h,
              invoiceRepository: repo));
      final container = containerOf(tester);
      await settleOfflineWriteGraph(tester, container);
      await settleInvoiceReads(tester);
      await pumpSheet(tester);
      expect(repo.detailIds.last, localId);

      await replayAndRepublish(
          tester, c.id, c.type, c.party, c.type == 'sale' ? 250000 : 150000);
      container.invalidate(c.type == 'sale'
          ? saleInvoicesListProvider
          : purchaseInvoicesListProvider);
      await settleInvoiceReads(tester);

      // The invariant is about what reached the SERVER, not about which
      // argument the sheet passed. Both matter, but only one is the defect: the
      // repository is entitled to accept either id space and normalize through
      // `id_map`, so pinning its argument would pin an implementation choice.
      // What must never happen is asking the server about an id it never issued:
      // that is the unanswerable read whose empty answer started all of this.
      expect(h.network.itemsCalls, isNot(contains(localId)),
          reason: 'the sheet still holds the captured LOCAL uuid after the '
              'replay, and if that reaches the server it asks about an invoice '
              'that does not exist. The answer is an empty list, and a '
              'successful empty list is what destroys the durable lines.');
      expect(h.network.itemsCalls, contains(c.id),
          reason: 'the detail read must therefore reach the server under the id '
              'the server actually issued');
    });
  }
}

/// Records the ids the DETAIL read was asked for.
///
/// The recording is at the repository boundary, not the network, and that is not
/// a detail: `items()` short-circuits a pending draft straight to
/// `_localItems` and never touches the network, so a network-level probe reads
/// "never called" for a sheet that is plainly on screen. It is used only for the
/// PRE-replay precondition — what reached the network is asserted separately, on
/// `FakeNetworkInvoices.itemsCalls`.
class _RecordingInvoices extends OfflineInvoiceRepository {
  _RecordingInvoices(
    super.inner, {
    required super.store,
    required super.tenantId,
  });

  final List<String> detailIds = [];

  @override
  Future<List<InvoiceItem>> items(String invoiceId) {
    detailIds.add(invoiceId);
    return super.items(invoiceId);
  }
}

/// A list row handed to the sheet the way `sale_invoices_screen.dart:209` and
/// `purchase_invoices_screen.dart:145` hand it: a snapshot of the row as the
/// list held it at tap time. Stateful and one-shot, so the drain's rebuild
/// cannot stack a second sheet on top of the first.
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