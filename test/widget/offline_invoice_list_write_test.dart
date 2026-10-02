import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasad_erp/core/network/connectivity_providers.dart';
import 'package:hasad_erp/core/utils/money.dart';
import 'package:hasad_erp/data/offline/local_store.dart';
import 'package:hasad_erp/data/offline/offline_sync.dart';
import 'package:hasad_erp/domain/invoices/invoice_sync.dart';
import 'package:hasad_erp/presentation/app.dart';
import 'package:hasad_erp/presentation/providers/auth_providers.dart';
import 'package:hasad_erp/presentation/providers/dashboard_providers.dart';
import 'package:hasad_erp/presentation/providers/navigation_providers.dart';
import 'package:hasad_erp/presentation/providers/offline_sync_providers.dart';
import 'package:hasad_erp/presentation/providers/sales_providers.dart';
import 'package:hasad_erp/presentation/screens/purchases/purchase_invoices_screen.dart';
import 'package:hasad_erp/presentation/screens/sales/sale_invoices_screen.dart';
import 'package:hasad_erp/presentation/shell/app_shell.dart';

import '../tool/offline_invoice_harness.dart';
import '../tool/shell_stubs.dart';

/// Phase 2 P2 — an invoice written offline through the **real** form must be
/// visible, badged and counted the instant the user returns to the list, and
/// must turn into exactly one official row once the queue drains.
///
/// The defect being closed: the screens refreshed only their own list provider,
/// so the row appeared at once but the two providers that read the *queue* were
/// never invalidated. The new invoice therefore rendered as already-synced —
/// the exact thing Phase 1A.1's badge exists to prevent — and the pending count
/// stayed at 0 while the user's own invoice sat unsent. `refreshAfterLocalInvoiceWrite`
/// is the write-time counterpart of `_refreshAfterDrain`.
void main() {
  group('an offline invoice is reflected the moment the form returns', () {
    testWidgets('sale: row, pending badge, pending count and pending message',
        (tester) async {
      useTallInvoiceViewport(tester);
      final h = await OfflineInvoiceHarness.create();
      addTearDown(h.close);

      await tester.pumpWidget(harnessHost(const SaleInvoicesScreen(), h));
      await tester.pumpAndSettle();

      // The list loaded while the network was up (and was empty).
      expect(find.text('لا توجد فواتير بيع'), findsOneWidget);
      final callsBefore = h.network.listCalls;
      expect(callsBefore, greaterThan(0));

      final container = _containerOf(tester, SaleInvoicesScreen);
      // Built AND held open before the write, so re-reading them afterwards is
      // a real staleness probe; see `holdQueueProviders`.
      for (final sub in holdQueueProviders(tester, container)) {
        addTearDown(sub.close);
      }
      expect(await _syncStates(tester, container), isEmpty);
      expect(await _pendingCount(tester, container), 0);

      // Connectivity is lost, then the user fills the real form.
      h.network.offline = true;
      await _saveOfflineSale(tester);

      // Back on the list with no restart, pull-to-refresh, reconnect or flusher.
      expect(tester.takeException(), isNull);
      // The post-save refresh really did re-run the list read.
      expect(h.network.listCalls, greaterThan(callsBefore));

      // The write really did queue the invoice, so every assertion below is
      // checked against durable state rather than a UI that forgot to paint.
      final legs = await h.store.queueLegsFor(harnessTenant, entity: 'invoices');
      expect(legs, hasLength(1));
      expect(legs.single.status, 'pending');
      final draft = (await h.store.invoices(harnessTenant)).single;
      // No official number exists yet, so the row carries the local placeholder.
      expect(draft.no, startsWith('D-'));
      expect(draft.synced, isFalse);

      // The unsynced draft made it through the real merge, exactly once, under
      // the right party and the right figures.
      //
      // The number is probed through the row's number chip, which shows only the
      // last three characters (`_shortNo`). Asserting the full `D-…` string would
      // be a false positive: the *SnackBar* quotes the number, so that finder
      // passes even when no row was ever painted.
      expect(find.text(_shortNo(draft.no)), findsOneWidget);
      expect(find.textContaining(seedCustomerName), findsOneWidget);
      expect(find.text(Money.format(draft.total)), findsOneWidget);

      // The queue-derived providers recomputed at write time, not at drain time.
      expect(await _pendingCount(tester, container), 1);
      expect(
        (await _syncStates(tester, container)).keys,
        legs.map((l) => l.localId),
      );

      // And the row says so, immediately.
      expect(find.text('بانتظار المزامنة'), findsOneWidget);
      expect(
        find.text('تم حفظ فاتورة البيع محليًا وستتم مزامنتها عند عودة الاتصال'),
        findsOneWidget,
      );
    });

    testWidgets(
        'purchase with an inline new product: row, badge, count and the '
        'product leg still gates the invoice leg', (tester) async {
      useTallInvoiceViewport(tester);
      final h = await OfflineInvoiceHarness.create();
      addTearDown(h.close);

      await tester.pumpWidget(harnessHost(const PurchaseInvoicesScreen(), h));
      await tester.pumpAndSettle();
      expect(find.text('لا توجد فواتير شراء'), findsOneWidget);
      final container = _containerOf(tester, PurchaseInvoicesScreen);
      // Held open across the write; see `holdQueueProviders` for why reading
      // them only afterwards would prove nothing.
      for (final sub in holdQueueProviders(tester, container)) {
        addTearDown(sub.close);
      }
      expect(await _pendingCount(tester, container), 0);
      expect(await _syncStates(tester, container), isEmpty);

      h.network.offline = true;
      await _saveOfflinePurchaseWithNewProduct(tester);

      expect(tester.takeException(), isNull);

      // The purchase mirrors the invoice AND the inline product, and the invoice
      // leg is still gated on the product leg — the Phase 1B phantom-uuid guard
      // must not regress just because the badge now refreshes.
      final legs = await h.store.queueLegsFor(harnessTenant);
      expect(legs, hasLength(2));
      final productLeg =
          legs.firstWhere((l) => l.entity == 'products' && l.op == 'table_crud');
      final invoiceLeg =
          legs.firstWhere((l) => l.entity == 'invoices' && l.op == 'rpc');
      expect(invoiceLeg.dependsOn, contains(productLeg.id));
      expect(productLeg.status, 'pending');
      expect(invoiceLeg.status, 'pending');

      final draft = (await h.store.invoices(harnessTenant)).single;
      expect(draft.type, 'purchase');
      expect(draft.no, startsWith('D-'));
      expect(draft.synced, isFalse);

      expect(find.text(_shortNo(draft.no)), findsOneWidget);
      expect(find.textContaining(seedSupplierName), findsOneWidget);
      expect(find.text('بانتظار المزامنة'), findsOneWidget);
      expect(
        find.text('تم حفظ فاتورة الشراء محليًا وستتم مزامنتها عند عودة الاتصال'),
        findsOneWidget,
      );

      // The pending count counts QUEUE work, so the product leg counts too.
      expect(await _pendingCount(tester, container), 2);
      expect(
        (await _syncStates(tester, container)).keys,
        [invoiceLeg.localId],
      );
    });
  });

  group('the offline result survives everything short of a drain', () {
    testWidgets('a full provider teardown still shows the row, badge and count',
        (tester) async {
      useTallInvoiceViewport(tester);
      final h = await OfflineInvoiceHarness.create();
      addTearDown(h.close);

      await tester.pumpWidget(harnessHost(const SaleInvoicesScreen(), h));
      await tester.pumpAndSettle();
      h.network.offline = true;
      await _saveOfflineSale(tester);
      final draft = (await h.store.invoices(harnessTenant)).single;

      // Re-mounting the screen builds an entirely NEW ProviderScope, so every
      // provider is torn down and rebuilt from scratch — the strong form of
      // "navigate away and come back", and still no reconnect.
      await tester.pumpWidget(harnessHost(const SaleInvoicesScreen(), h));
      await tester.pumpAndSettle();
      final container = _containerOf(tester, SaleInvoicesScreen);
      await settleInvoiceReads(tester);

      expect(tester.takeException(), isNull);
      expect(find.text(_shortNo(draft.no)), findsOneWidget);
      expect(find.textContaining(seedCustomerName), findsOneWidget);
      expect(find.text('بانتظار المزامنة'), findsOneWidget);
      expect(await _pendingCount(tester, container), 1);
    });

    testWidgets('the active date range still decides whether the row shows',
        (tester) async {
      useTallInvoiceViewport(tester);
      final h = await OfflineInvoiceHarness.create();
      addTearDown(h.close);

      await tester.pumpWidget(harnessHost(const SaleInvoicesScreen(), h));
      await tester.pumpAndSettle();
      h.network.offline = true;
      await _saveOfflineSale(tester);
      final draft = (await h.store.invoices(harnessTenant)).single;
      final container = _containerOf(tester, SaleInvoicesScreen);

      // A range that cannot contain the invoice's date hides it — the merge is
      // filter-aware, so an unsynced draft is not exempt from the user's filter.
      final day = DateTime(draft.date.year, draft.date.month, draft.date.day);
      final after = day.add(const Duration(days: 1));
      container.read(saleFromProvider.notifier).update(_iso(after));
      container.read(saleToProvider.notifier).update(_iso(after));
      await settleInvoiceReads(tester);

      expect(h.network.lastFrom, isNotNull);
      expect(find.textContaining(seedCustomerName), findsNothing);
      expect(find.text('بانتظار المزامنة'), findsNothing);

      // Widening it back brings the same row back — one invoice, not two.
      container.read(saleFromProvider.notifier).update(_iso(day));
      container.read(saleToProvider.notifier).update(_iso(after));
      await settleInvoiceReads(tester);

      expect(find.text(_shortNo(draft.no)), findsOneWidget);
      expect(find.textContaining(seedCustomerName), findsOneWidget);
      expect(find.text('بانتظار المزامنة'), findsOneWidget);
    });
  });

  testWidgets('a reconnect drain adopts the official number, exactly once',
      (tester) async {
    useTallInvoiceViewport(tester);
    final h = await OfflineInvoiceHarness.create();
    addTearDown(h.close);

    await tester.pumpWidget(harnessHost(const SaleInvoicesScreen(), h));
    await tester.pumpAndSettle();
    h.network.offline = true;
    await _saveOfflineSale(tester);
    final draft = (await h.store.invoices(harnessTenant)).single;
    final container = _containerOf(tester, SaleInvoicesScreen);

    // The connection is back, and the server now holds this invoice under its
    // own id and an official number.
    h.network.offline = false;
    h.target.nextServerId = 'srv-invoice-1';
    h.target.nextServerNo = 'SALE-1001';
    h.network.serverInvoices = [
      h.serverInvoice(
        type: 'sale',
        id: 'srv-invoice-1',
        no: 'SALE-1001',
        partyName: seedCustomerName,
        total: draft.total,
        date: draft.date,
      ),
    ];

    final summary = await _drain(tester, container);
    expect(summary.synced, 1);
    expect(summary.failed, 0);
    await settleInvoiceReads(tester);

    // The leg really drained and the mirror adopted the server's identity.
    final legs = await h.store.queueLegsFor(harnessTenant, entity: 'invoices');
    expect(legs.single.status, 'synced');
    final after = (await h.store.invoices(harnessTenant)).single;
    expect(after.synced, isTrue);
    expect(after.no, 'SALE-1001');

    // Exactly one row, now under the OFFICIAL number. A second row is what a
    // merge that kept serving the draft would produce.
    expect(find.textContaining(seedCustomerName), findsOneWidget);
    expect(find.text(_shortNo('SALE-1001')), findsOneWidget);
    expect(find.text(_shortNo(draft.no)), findsNothing);
    expect(find.text(Money.format(draft.total)), findsOneWidget);

    // The badge and the count clear with no navigation.
    expect(find.text('بانتظار المزامنة'), findsNothing);
    expect(await _pendingCount(tester, container), 0);
    // The map is NOT emptied by a drain — `queueLegsFor` returns every leg and
    // the drained one maps to `synced`, which is exactly what makes the row
    // render unbadged. So the requirement is "nothing is left pending/failed",
    // not "the map is empty".
    expect(
      (await _syncStates(tester, container)).values,
      everyElement(InvoiceSyncState.synced),
    );
  });

  testWidgets('the shell still routes to sales, so the fix is reachable',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final h = await OfflineInvoiceHarness.create();
    addTearDown(h.close);

    // `Override` is not publicly exported by Riverpod 3.x, so this list has to
    // be built inline rather than in a helper.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // The app gates its first frame on the local store, and
          // `path_provider` has no plugin in a test isolate.
          localStoreProvider.overrideWith((ref) async => const NullLocalStore()),
          // The only two paths to `supabaseClientProvider`; see shell_stubs.dart.
          dashboardRepositoryProvider
              .overrideWithValue(ShellFakeDashboardRepository()),
          syncFlusherProvider.overrideWith(
            (ref) async =>
                SyncFlusher(const NullLocalStore(), '', ShellNoopSyncTarget()),
          ),
          authStateProvider.overrideWith((ref) => Stream.value(harnessUser)),
          isOnlineProvider.overrideWithValue(true),
          invoiceRepositoryProvider.overrideWithValue(h.network),
        ],
        child: const HasadApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(AppShell), findsOneWidget,
        reason: 'a signed-in user must reach the shell');
    expect(tester.takeException(), isNull);

    // Selected through the shell's own provider, the way the sidebar does.
    ProviderScope.containerOf(tester.element(find.byType(AppShell)))
        .read(currentDestinationProvider.notifier)
        .select(1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(SaleInvoicesScreen), findsOneWidget);
    expect(find.text('لا توجد فواتير بيع'), findsOneWidget);
  });
}

/// `ProviderScope.containerOf` needs an element under the widget under test.
ProviderContainer _containerOf(WidgetTester tester, Type widgetType) =>
    ProviderScope.containerOf(tester.element(find.byType(widgetType)));

/// Each of these reads a real async provider inside `runAsync` (drift work
/// cannot complete in the fake-async zone) and hands back the settled value, so
/// the assertions below read as plain values instead of open futures.
Future<int> _pendingCount(
  WidgetTester tester,
  ProviderContainer container,
) async =>
    (await tester.runAsync(() => container.read(pendingSyncCountProvider.future)))!;

Future<Map<String, InvoiceSyncState>> _syncStates(
  WidgetTester tester,
  ProviderContainer container,
) async =>
    (await tester
        .runAsync(() => container.read(invoiceSyncStatesProvider.future)))!;

Future<SyncFlushSummary> _drain(
  WidgetTester tester,
  ProviderContainer container,
) async =>
    (await tester.runAsync(() => container.read(manualSyncNowProvider.future)))!;

/// The row's number chip shows only the last three characters
/// (`InvoiceListView._shortNo`). Mirrors it so the tests can probe the number
/// the user actually sees.
String _shortNo(String no) => no.length > 3 ? no.substring(no.length - 3) : no;

String _iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Drives the real sale form: FAB → customer → product → qty → save.
Future<void> _saveOfflineSale(WidgetTester tester) async {
  await tester.tap(find.byType(FloatingActionButton));
  await tester.pumpAndSettle();
  expect(find.text('فاتورة بيع جديدة'), findsOneWidget);

  await tester.tap(find.widgetWithText(DropdownButtonFormField<String>, 'العميل'));
  await tester.pumpAndSettle();
  // The dropdown item renders as "name — phone", so match on the name.
  await tester.tap(find.textContaining(seedCustomerName).last);
  await tester.pumpAndSettle();

  await tester.ensureVisible(find.text('إضافة صنف'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('إضافة صنف'));
  await pumpSheet(tester);
  expect(find.text('اختيار منتج'), findsOneWidget);
  await tester.tap(find.text(seedProductName).last);
  await pumpSheet(tester);

  await tester.enterText(find.widgetWithText(TextFormField, 'الكمية'), '1');
  await tester.pump();

  await tester.ensureVisible(find.text('حفظ الفاتورة'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('حفظ الفاتورة'));
  await tester.pump();
  await settleInvoiceReads(tester);
}

/// Drives the real purchase form with an INLINE NEW product: FAB → supplier →
/// add item → "منتج جديد" → name → qty + purchase price → save.
Future<void> _saveOfflinePurchaseWithNewProduct(WidgetTester tester) async {
  await tester.tap(find.byType(FloatingActionButton));
  await tester.pumpAndSettle();
  expect(find.text('فاتورة شراء جديدة'), findsOneWidget);

  await tester.tap(find.widgetWithText(DropdownButtonFormField<String>, 'المورد'));
  await tester.pumpAndSettle();
  await tester.tap(find.textContaining(seedSupplierName).last);
  await tester.pumpAndSettle();

  await tester.ensureVisible(find.text('إضافة صنف'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('إضافة صنف'));
  await pumpSheet(tester);
  // The purchase form asks which kind of line this is before the picker.
  expect(find.text('منتج جديد'), findsOneWidget);
  await tester.tap(find.text('منتج جديد'));
  await pumpSheet(tester);
  await tester.enterText(
    find.widgetWithText(TextFormField, 'اسم المنتج'),
    'ورق تصوير A4',
  );
  await tester.pump();
  await tester.tap(find.text('إضافة المنتج'));
  await pumpSheet(tester);

  // A new line arrives with both fields empty.
  await tester.enterText(find.widgetWithText(TextFormField, 'الكمية'), '2');
  await tester.enterText(
    find.widgetWithText(TextFormField, 'سعر الشراء'),
    '600',
  );
  await tester.pump();

  await tester.ensureVisible(find.text('حفظ الفاتورة'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('حفظ الفاتورة'));
  await tester.pump();
  await settleInvoiceReads(tester);
}
