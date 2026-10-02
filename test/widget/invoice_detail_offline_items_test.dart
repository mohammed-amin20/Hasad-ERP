/// Phase P1.E, widget leg — the shared `InvoiceDetailSheet` must render a
/// purchase invoice's line items offline.
///
/// ## Why this case exists at all
///
/// `InvoiceDetailSheet` (`lib/presentation/widgets/invoice_list.dart:146`) is
/// the ONE widget behind both the Sales and the Purchases invoice list, and it
/// reads `ref.read(invoiceRepositoryProvider).items(invoice.id)` from `build`.
/// A data-layer fix that only ever ran for one type would still look correct in
/// a repository test, so this drives a **purchase** invoice through the real
/// widget, over a repository wired to a real drift store and an unreachable
/// server.
///
/// The sheet has no `hasError` branch, so a read that fails renders an empty
/// body indistinguishable from "this invoice has no products" — which is the
/// device report this phase fixes. Asserting on the rendered product lines is
/// therefore the only probe with teeth: an empty body fails here.
///
/// ## Probe discipline
///
/// The product line renders as `'${productName} × ${formatQty(qty, type)}'` plus
/// the unit, and the money cell is `Money.format(total)`. The probe uses that
/// exact combined label, never a bare name or a bare amount: a name appears in
/// the header area and an amount appears again in the totals, so a looser
/// finder would match with no line row painted at all (the trap P2 hit with the
/// truncated invoice number).
library;

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasad_erp/core/error/app_exception.dart';
import 'package:hasad_erp/core/theme/app_theme.dart';
import 'package:hasad_erp/data/invoices/invoice_repository.dart';
import 'package:hasad_erp/data/offline/local_database.dart';
import 'package:hasad_erp/data/offline/local_store.dart';
import 'package:hasad_erp/data/offline/offline_invoice_repository.dart';
import 'package:hasad_erp/domain/auth/app_role.dart';
import 'package:hasad_erp/domain/auth/app_user.dart';
import 'package:hasad_erp/domain/invoices/invoice.dart';
import 'package:hasad_erp/domain/products/product.dart';
import 'package:hasad_erp/presentation/providers/auth_providers.dart';
import 'package:hasad_erp/presentation/providers/sales_providers.dart';
import 'package:hasad_erp/presentation/widgets/invoice_list.dart';

/// A sales-role user, so the sheet's money action stays off screen. See `_host`.
const _salesUser = AppUser(
  id: 'u1',
  email: 'sales@test.local',
  name: 'بائع',
  role: AppRole.sales,
  tenantId: 'tenant-a',
);

void main() {
  const tenantA = 'tenant-a';

  late AppDatabase db;
  late DriftLocalStore store;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = DriftLocalStore(db);
  });

  tearDown(() => db.close());

  Invoice sheetInvoice({
    String id = 'inv-p',
    String type = 'purchase',
    String no = 'PUR-1001',
  }) =>
      Invoice(
        id: id,
        type: type,
        no: no,
        partyId: 's1',
        partyName: 'مورد',
        date: DateTime(2026, 3, 1),
        subtotal: 300,
        total: 300,
        paid: 0,
        remaining: 300,
        status: InvoiceStatus.unpaid,
        ownership: InvoiceOwnership.owned,
      );

  testWidgets('a purchase invoice paints a server line set AND makes it durable',
      (tester) async {
    // The device has the header but has NEVER opened this detail: the server
    // holds the lines, and nothing local does. This is the actual reported
    // defect — online the sheet renders from the network, and every later
    // offline open was empty because only the `report_cache` blob held them.
    await store.upsertInvoice(LocalInvoiceRow(
      id: 'inv-p',
      tenantId: tenantA,
      type: 'purchase',
      no: 'PUR-1001',
      partyId: 's1',
      partyName: 'مورد',
      date: DateTime(2026, 3, 1),
      subtotal: 300,
      total: 300,
      paid: 0,
      remaining: 300,
      status: 'unpaid',
      ownership: 'owned',
      requestId: null,
      synced: true,
      createdAt: null,
    ));
    expect(
      await (db.select(db.localInvoiceItems)
            ..where((r) => r.invoiceId.equals('inv-p')))
          .get(),
      isEmpty,
      reason: 'precondition: no lines have ever been mirrored for this invoice',
    );

    final repository = OfflineInvoiceRepository(
      _UnreachableInvoices(
        onItems: () => [
          const InvoiceItem(
            productId: 'p1',
            productName: 'ورق',
            productUnit: 'كرتون',
            productUnitType: ProductUnitType.count,
            qty: 3,
            price: 100,
            total: 300,
          ),
        ],
      ),
      store: store,
      tenantId: tenantA,
    );

    await tester.pumpWidget(_host(repository, sheetInvoice()));
    await tester.pumpAndSettle();

    expect(
      find.text('ورق × 3 كرتون'),
      findsOneWidget,
      reason: 'the sheet must paint the line it was handed; an empty body is '
          'indistinguishable from "no products" because the sheet has no '
          'error branch',
    );

    // The second open, with the server now gone. This is the assertion with
    // teeth: "the sheet painted lines" would ALSO pass against the pre-fix
    // code, because the pre-fix read painted them straight off the network. What
    // the pre-fix code could not do is serve them again offline — only the
    // table can show that. Read through drift, not `store.invoiceItems`, so a
    // store-side filter cannot satisfy it.
    final durable = await (db.select(db.localInvoiceItems)
          ..where((r) =>
              r.tenantId.equals(tenantA) & r.invoiceId.equals('inv-p'))
          ..orderBy([(r) => OrderingTerm.asc(r.id)]))
        .get();
    expect(durable, hasLength(1),
        reason: 'a detail the user was shown must be durable, or the next '
            'offline open is empty');
    expect(durable.single.id, 'inv-p:0000',
        reason: 'the mirror mints the positional id, so ORDER BY id is the '
            'invoice\'s line order and a restart paints the same sequence');
  });

  testWidgets('a pending purchase draft renders its lines with no server call',
      (tester) async {
    await store.upsertInvoice(LocalInvoiceRow(
      id: 'D-1',
      tenantId: tenantA,
      type: 'purchase',
      no: 'D-1',
      partyId: 's1',
      partyName: 'مورد',
      date: DateTime(2026, 3, 1),
      subtotal: 500,
      total: 500,
      paid: 0,
      remaining: 500,
      status: 'unpaid',
      ownership: 'owned',
      requestId: 'rq-1',
      synced: false,
      createdAt: DateTime(2026, 3, 1),
    ));
    await store.upsertInvoiceItems([
      const LocalInvoiceItemRow(
        id: 'D-1:0000',
        tenantId: tenantA,
        invoiceId: 'D-1',
        productId: 'p9',
        productName: 'مواد أولية',
        productUnit: 'كيلو',
        productUnitType: 'weight',
        qty: 2.5,
        price: 200,
        total: 500,
      ),
    ]);

    var serverCalls = 0;
    final repository = OfflineInvoiceRepository(
      _CountingInvoices(onItems: () => serverCalls++),
      store: store,
      tenantId: tenantA,
    );

    await tester.pumpWidget(_host(repository, sheetInvoice(id: 'D-1', no: 'D-1')));
    await tester.pumpAndSettle();

    expect(find.text('مواد أولية × 2.500 كيلو'), findsOneWidget,
        reason: 'formatQty gives weight three decimals — the probe is the '
            'sheet\'s own label, not a number that happens to be on screen');
    expect(serverCalls, 0,
        reason: 'an unsynced draft must not be read from the server at all');
  });
}

/// Mirrors `HasadApp`'s own wrapper (rtl + `ar` locale + the global delegates),
/// because `MaterialApp` re-asserts direction from the locale — an outer
/// `Directionality` on its own is silently overridden.
Widget _host(InvoiceRepository repository, Invoice invoice) => ProviderScope(
      overrides: [
        // `overrideWithValue`, the shape the codegen'd functional provider
        // exposes for a value that is already built.
        invoiceRepositoryProvider.overrideWithValue(repository),
        // The sheet calls `_canPay(ref)` to decide whether to draw the payment
        // button, which reads `authStateProvider` → `authRepositoryProvider` →
        // `supabaseClientProvider`. That last one asserts `_isInitialized` and
        // throws in a test isolate, and the resulting `ProviderException` is
        // raised inside the provider's own zone where `tester.takeException()`
        // cannot drain it. A **sales** user also keeps the payment button off
        // screen, so this override serves the probe rather than papering over a
        // crash — the two cases assert the line rows, nothing about money.
        authStateProvider.overrideWith((ref) => Stream.value(_salesUser)),
      ],
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(body: InvoiceDetailSheet(invoice: invoice)),
        ),
      ),
    );

/// The server as an offline device sees it: not there.
///
/// [onItems] exists so a case can hand the read a line set that never had a
/// local source, then assert the mirror captured it. With the default (no
/// callback) it is a plain unreachable server, which is what the offline cases
/// need.
class _UnreachableInvoices implements InvoiceRepository {
  _UnreachableInvoices({this.onItems});

  /// When non-null, the read SUCCEEDS with this set instead of throwing — i.e.
  /// the device is online for this read only.
  final List<InvoiceItem> Function()? onItems;

  @override
  Future<List<Invoice>> list({
    required String type,
    String? search,
    DateTime? from,
    DateTime? to,
  }) async =>
      throw const NetworkException();

  @override
  Future<List<InvoiceItem>> items(String invoiceId) async {
    final answer = onItems;
    if (answer != null) return answer();
    throw const NetworkException();
  }

  /// Throws unless a case supplied [onItems], mirroring `items()`. The detail
  /// sheet reads one invoice at a time, so the batch API is never the path under
  /// test here — it must simply fail the way an unreachable server does rather
  /// than returning a fabricated empty answer.
  @override
  Future<InvoiceItemsBatch> itemsForInvoices(List<String> invoiceIds) async {
    final answer = onItems;
    if (answer != null) {
      return InvoiceItemsBatch(
        items: {for (final id in invoiceIds) id: answer()},
        failed: const {},
      );
    }
    throw const NetworkException();
  }
}

/// Counts detail calls, so "the draft never touched the server" is observable
/// rather than assumed.
class _CountingInvoices implements InvoiceRepository {
  _CountingInvoices({required this.onItems});

  final void Function() onItems;

  @override
  Future<List<Invoice>> list({
    required String type,
    String? search,
    DateTime? from,
    DateTime? to,
  }) async =>
      throw const NetworkException();

  @override
  Future<List<InvoiceItem>> items(String invoiceId) async {
    onItems();
    throw const NetworkException();
  }

  /// Counts the SAME way `items()` does — the counter is the point of this fake,
  /// and a batch call that skipped the callback would make "the draft never
  /// touched the server" true for the wrong reason.
  @override
  Future<InvoiceItemsBatch> itemsForInvoices(List<String> invoiceIds) async {
    onItems();
    throw const NetworkException();
  }
}
