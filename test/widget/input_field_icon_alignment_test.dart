import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:hasad_erp/core/network/connectivity_providers.dart';
import 'package:hasad_erp/core/theme/app_theme.dart';
import 'package:hasad_erp/data/invoices/invoice_repository.dart';
import 'package:hasad_erp/domain/accounts/account.dart';
import 'package:hasad_erp/domain/accounts/account_draft.dart';
import 'package:hasad_erp/domain/accounts/account_repository.dart';
import 'package:hasad_erp/domain/auth/app_role.dart';
import 'package:hasad_erp/domain/auth/app_user.dart';
import 'package:hasad_erp/domain/customers/customer.dart';
import 'package:hasad_erp/domain/customers/customer_draft.dart';
import 'package:hasad_erp/domain/customers/customer_repository.dart';
import 'package:hasad_erp/domain/invoices/invoice.dart';
import 'package:hasad_erp/domain/products/product.dart';
import 'package:hasad_erp/domain/products/product_draft.dart';
import 'package:hasad_erp/domain/products/product_repository.dart';
import 'package:hasad_erp/domain/suppliers/supplier.dart';
import 'package:hasad_erp/domain/suppliers/supplier_draft.dart';
import 'package:hasad_erp/domain/suppliers/supplier_repository.dart';
import 'package:hasad_erp/data/offline/local_store.dart';
import 'package:hasad_erp/data/offline/offline_sync.dart';
import 'package:hasad_erp/presentation/providers/dashboard_providers.dart';
import 'package:hasad_erp/presentation/providers/offline_sync_providers.dart';
import 'package:hasad_erp/presentation/app.dart';
import 'package:hasad_erp/presentation/providers/accounts_providers.dart';
import 'package:hasad_erp/presentation/providers/auth_providers.dart';
import 'package:hasad_erp/presentation/providers/customers_providers.dart';
import 'package:hasad_erp/presentation/providers/navigation_providers.dart';
import 'package:hasad_erp/presentation/providers/products_providers.dart';
import 'package:hasad_erp/presentation/providers/sales_providers.dart';
import 'package:hasad_erp/presentation/providers/suppliers_providers.dart';
import 'package:hasad_erp/presentation/screens/accounts/chart_of_accounts_screen.dart';
import 'package:hasad_erp/presentation/screens/journal/journal_screen.dart';
import 'package:hasad_erp/presentation/screens/products/products_screen.dart';
import 'package:hasad_erp/presentation/screens/purchases/purchase_invoices_screen.dart';
import 'package:hasad_erp/presentation/screens/sales/sale_invoices_screen.dart';
import 'package:hasad_erp/presentation/shell/app_shell.dart';

import '../tool/shell_stubs.dart';

/// Regression: every `prefixIcon` / `suffixIcon` glyph must sit on its field's
/// vertical centre line, in Arabic RTL, at every supported viewport.
///
/// ## Why this test has to measure ink, not widget boxes
///
/// The reported bug was "the Customer field icon is stuck to the top of the
/// field". An earlier version of this test asserted on
/// `tester.getRect(find.byType(FaIcon))` and always passed — because that rect
/// is the icon *widget's* box, not the painted glyph.
///
/// The chain that made the two differ, all inside stock Flutter:
/// 1. `AppTheme.inputDecorationTheme` sets `isDense: true`, so
///    `InputDecorator` resolves its prefix `IconTheme.size` to
///    `isDense ? 18 : 24` → **18**.
/// 2. `FaIcon` deliberately drops the `SizedBox`/`Center` that make a Material
///    `Icon` self-centring (see its own doc comment), so it hands a bare
///    `RichText` with `height: 1.0` to the slot → intrinsic height **18**.
/// 3. `InputDecorator` wraps the slot in a `ConstrainedBox` built from
///    `prefixIconConstraints`. With the old `minHeight: 40` that box became
///    **40** tall.
/// 4. `RenderParagraph` lays its text out with *width-only* constraints, then
///    does `size = constraints.constrain(textSize)`, and paints the text at its
///    own origin. The 18px glyph therefore paints at the **top** of the 40px
///    box.
/// 5. `InputDecorator` centres the **box** in the field. So the box measured
///    dead-centre (delta 0.00) while the glyph the user actually sees sat
///    **(40 - 18) / 2 = 11px** above the centre.
///
/// A Material `Icon` is immune (its own `SizedBox`/`Center` re-centre the
/// glyph), which is why only `FaIcon` fields ever looked wrong. Asserting on
/// the box therefore validated the one thing that was never broken.
///
/// The fix caps `prefixIconConstraints` at the icon size so the slot hugs the
/// glyph and the decorator's centring is applied to something that contains
/// the ink. Measured before/after on the real route: glyph delta **-11.00 →
/// 0.00**, with every field's height unchanged.
///
/// ## Suffix icons
///
/// `suffixIconConstraints` is deliberately left alone. All three suffix
/// occupants are `IconButton`s (search clear, password toggle); the button
/// sizes and centres its own icon slot, so the 36/40 constraint never reaches
/// the glyph. Measured at glyph delta 0.00 before and after — see the
/// `suffix` coverage in `_expectFieldIconsCentred`.
const _user = AppUser(
  id: 'u1',
  email: 'admin@test.local',
  name: 'مدير النظام',
  role: AppRole.admin,
  tenantId: 't1',
);

/// Index of the المبيعات tab in `appTabs`.
const _salesTab = 1;

const _viewports = <String, Size>{
  'desktop 1440x900': Size(1440, 900),
  'small Android 360x640': Size(360, 640),
  'iPhone SE 375x667': Size(375, 667),
  'iPhone 14 390x844': Size(390, 844),
  'Pixel 7 412x915': Size(412, 915),
};

/// How many logical pixels a glyph centre may sit off the field's centre.
const _tolerance = 1.0;

/// Painted-glyph rect, in global coordinates, of the `RichText` inside [iconEl].
///
/// This is the ink the user sees. It is deliberately *not*
/// `tester.getRect(iconFinder)`: for a `FaIcon` under an icon-slot constraint
/// those two differ by half the slack, which is the entire bug.
Rect? _glyphRect(WidgetTester tester, Element iconEl) {
  final rich = find.descendant(
    of: find.byElementPredicate((e) => e == iconEl),
    matching: find.byType(RichText),
  );
  if (rich.evaluate().isEmpty) return null;
  final paragraph = tester.renderObject<RenderParagraph>(rich.first);
  final boxes = paragraph.getBoxesForSelection(
    const TextSelection(baseOffset: 0, extentOffset: 1),
  );
  if (boxes.isEmpty) return null;
  // `TextBox` is paragraph-local, so shift by the paragraph's own origin.
  final origin = paragraph.localToGlobal(Offset.zero);
  var rect = boxes.first.toRect().shift(origin);
  for (final box in boxes.skip(1)) {
    rect = rect.expandToInclude(box.toRect().shift(origin));
  }
  return rect;
}

/// Asserts every rendered `InputDecorator` on screen has its icon *glyph*
/// centred, for prefix and suffix slots alike.
void _expectFieldIconsCentred(WidgetTester tester, String stage) {
  final fields = find.byType(InputDecorator);
  expect(fields, findsWidgets, reason: '$stage rendered no input field');

  var glyphsChecked = 0;
  var labelsChecked = 0;

  for (var i = 0; i < fields.evaluate().length; i++) {
    final field = fields.at(i);
    final fieldBox = tester.getRect(field);
    if (fieldBox.height <= 0) continue;
    final isMultiline = fieldBox.height > 72;

    for (final type in [FaIcon, Icon]) {
      final kind = type == FaIcon ? 'FaIcon' : 'Icon';
      final icons = find.descendant(of: field, matching: find.byType(type));
      for (final iconEl in icons.evaluate()) {
        final glyph = _glyphRect(tester, iconEl);
        if (glyph == null || glyph.height <= 0) continue;
        glyphsChecked++;
        final box = tester.getRect(
          find.byElementPredicate((e) => e == iconEl),
        );
        expect(
          (glyph.center.dy - fieldBox.center.dy).abs(),
          lessThanOrEqualTo(_tolerance),
          reason:
              '$stage: $kind glyph centre ${glyph.center.dy.toStringAsFixed(2)} '
              'vs field centre ${fieldBox.center.dy.toStringAsFixed(2)} '
              '(field h=${fieldBox.height.toStringAsFixed(1)}, '
              'glyph h=${glyph.height.toStringAsFixed(2)}, '
              'icon box h=${box.height.toStringAsFixed(1)} — a box taller than '
              'the glyph is how this bug presents)',
        );
      }
    }

    // A floated label legitimately sits ABOVE the centre line (a field with a
    // value floats its label onto the top border), so this is one-sided: a
    // label must never sit BELOW `fieldCentre + tolerance`. That drop is the
    // separate `alignLabelWithHint` defect, and it makes a correctly centred
    // icon read as "too high".
    if (isMultiline) continue;
    for (final t in find
        .descendant(of: field, matching: find.byType(RichText))
        .evaluate()) {
      final textBox = tester.getRect(
        find.byElementPredicate((e) => e == t),
      );
      if (textBox.height <= 0) continue;
      labelsChecked++;
      expect(
        textBox.center.dy,
        lessThanOrEqualTo(fieldBox.center.dy + _tolerance),
        reason:
            '$stage: label centre ${textBox.center.dy.toStringAsFixed(2)} sits '
            'below field centre ${fieldBox.center.dy.toStringAsFixed(2)}',
      );
    }
  }

  expect(glyphsChecked, greaterThan(0), reason: '$stage rendered no icon glyph');
  expect(labelsChecked, greaterThan(0), reason: '$stage rendered no label');
}

/// Pins the specific field from the bug report, so a regression names it.
Finder _customerField() => find.widgetWithText(
  DropdownButtonFormField<String>,
  'العميل',
);

void _setViewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// `Override` is not publicly exported by Riverpod 3.x, so the override list is
/// built inline here and shared by both hosts.
Widget _scope(Widget child) {
  return ProviderScope(
    overrides: [
      // M13 Phase 0: the app gates its first frame on the local store, and
      // `path_provider` has no plugin in a test isolate, so the real store
      // provider never resolves here.
      localStoreProvider.overrideWith((ref) async => const NullLocalStore()),
      // The shell's dashboard and sync flusher are the only paths to
      // `supabaseClientProvider`; see `test/tool/shell_stubs.dart`.
      dashboardRepositoryProvider
          .overrideWithValue(ShellFakeDashboardRepository()),
      syncFlusherProvider.overrideWith(
        (ref) async =>
            SyncFlusher(const NullLocalStore(), '', ShellNoopSyncTarget()),
      ),
      authStateProvider.overrideWith((ref) => Stream.value(_user)),
      isOnlineProvider.overrideWithValue(true),
      productRepositoryProvider.overrideWithValue(
        const _FakeProductRepository(),
      ),
      invoiceRepositoryProvider.overrideWithValue(
        const _FakeInvoiceRepository(),
      ),
      customerRepositoryProvider.overrideWithValue(
        const _FakeCustomerRepository(),
      ),
      supplierRepositoryProvider.overrideWithValue(
        const _FakeSupplierRepository(),
      ),
      accountRepositoryProvider.overrideWithValue(
        const _FakeAccountRepository(),
      ),
    ],
    child: child,
  );
}

void main() {
  group('production route (HasadApp -> shell -> sales -> new invoice)', () {
    for (final vp in _viewports.entries) {
      testWidgets('customer + every field glyph is centred on ${vp.key}', (
        tester,
      ) async {
        _setViewport(tester, vp.value);

        // The real app widget, so the root Directionality, `locale: Locale('ar')`,
        // the Arabic localizations delegates and `AppTheme.light` all apply.
        await tester.pumpWidget(_scope(const HasadApp()));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        final shell = find.byType(AppShell);
        expect(shell, findsOneWidget, reason: 'signed-in user must reach shell');

        // Select المبيعات through the shell's own provider, so the screen is
        // reached the way the sidebar reaches it at every breakpoint.
        ProviderScope.containerOf(
          tester.element(shell),
        ).read(currentDestinationProvider.notifier).select(_salesTab);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.byType(SaleInvoicesScreen), findsOneWidget);

        await tester.tap(find.byType(FloatingActionButton).first);
        await tester.pumpAndSettle();
        expect(_customerField(), findsOneWidget, reason: 'new sale form opened');

        _expectFieldIconsCentred(tester, 'new sale form @ ${vp.key}');
      });
    }
  });

  group('form sweep (screen -> FAB -> pushed form)', () {
    final screens = <String, Widget Function()>{
      'new purchase form': () => const PurchaseInvoicesScreen(),
      'product form': () => const ProductsScreen(),
      'account form': () => const ChartOfAccountsScreen(),
      'journal form': () => const JournalScreen(),
    };

    for (final entry in screens.entries) {
      for (final vp in _viewports.entries) {
        testWidgets('${entry.key} glyphs centred on ${vp.key}', (tester) async {
          _setViewport(tester, vp.value);
          await tester.pumpWidget(_host(entry.value()));
          await tester.pumpAndSettle();
          await tester.tap(find.byType(FloatingActionButton).first);
          await tester.pumpAndSettle();
          _expectFieldIconsCentred(tester, '${entry.key} @ ${vp.key}');
        });
      }
    }
  });

  group('search field suffix icon', () {
    for (final vp in _viewports.entries) {
      testWidgets('search clear button glyph is centred on ${vp.key}', (
        tester,
      ) async {
        _setViewport(tester, vp.value);
        await tester.pumpWidget(_host(const SaleInvoicesScreen()));
        await tester.pumpAndSettle();

        // The search field is behind a toolbar toggle; open it by pressing
        // toolbar buttons until a TextField appears (no Arabic tooltip match).
        final buttons = find.byType(IconButton);
        for (var b = 0; b < buttons.evaluate().length; b++) {
          if (find.byType(TextField).evaluate().isNotEmpty) break;
          await tester.tap(buttons.at(b), warnIfMissed: false);
          await tester.pumpAndSettle();
        }
        final search = find.byType(TextField);
        expect(search, findsWidgets, reason: 'search field never opened');

        // The suffix FaIcon only exists once the controller is non-empty.
        await tester.enterText(search.first, 'x');
        await tester.pumpAndSettle();

        _expectFieldIconsCentred(tester, 'sales search @ ${vp.key}');
      });
    }
  });
}

/// Mirrors `HasadApp`'s wrapper (root RTL `Directionality` + `MaterialApp`
/// with `locale: Locale('ar')` and the Arabic delegates + `AppTheme.light`).
Widget _host(Widget body) {
  return _scope(
    Directionality(
      textDirection: TextDirection.rtl,
      child: MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: AppTheme.light,
        home: Scaffold(body: body),
      ),
    ),
  );
}

class _FakeProductRepository implements ProductRepository {
  const _FakeProductRepository();

  @override
  Future<List<Product>> listAll({String? search}) async => [
    const Product(
      id: 'p1',
      name: 'ماسحورة ليزر ملونة للأشعة',
      unit: 'قطعة',
      unitType: ProductUnitType.count,
      salePrice: 450000,
      purchasePrice: 300000,
      qty: 12,
      reorderLevel: 5,
    ),
  ];

  @override
  Future<Product?> getById(String id) async => null;

  @override
  Future<Product> create(ProductDraft draft) => throw UnimplementedError();

  @override
  Future<void> update({required String id, required ProductDraft draft}) =>
      throw UnimplementedError();

  @override
  Future<void> delete(String id) => throw UnimplementedError();
}

class _FakeInvoiceRepository implements InvoiceRepository {
  const _FakeInvoiceRepository();

  @override
  Future<List<Invoice>> list({
    required String type,
    String? search,
    DateTime? from,
    DateTime? to,
  }) async =>
      [
        Invoice(
          id: 'i1',
          type: 'sale',
          no: '1',
          partyId: 'c1',
          partyName: 'شركة الأمل التجارية المحدودة',
          date: DateTime(2026, 1, 1),
          subtotal: 100,
          total: 100,
          paid: 0,
          remaining: 100,
          status: InvoiceStatus.unpaid,
          ownership: InvoiceOwnership.owned,
        ),
      ];

  @override
  Future<List<InvoiceItem>> items(String invoiceId) async => const [];
}

class _FakeCustomerRepository implements CustomerRepository {
  const _FakeCustomerRepository();

  @override
  Future<List<Customer>> listAll({String? search}) async => [
    const Customer(id: 'c1', name: 'شركة الأمل التجارية المحدودة'),
  ];

  @override
  Future<Customer?> getById(String id) async => null;

  @override
  Future<Customer> create(CustomerDraft draft) => throw UnimplementedError();

  @override
  Future<void> update({required String id, required CustomerDraft draft}) =>
      throw UnimplementedError();

  @override
  Future<void> delete(String id) => throw UnimplementedError();
}

class _FakeSupplierRepository implements SupplierRepository {
  const _FakeSupplierRepository();

  @override
  Future<List<Supplier>> listAll({String? search}) async => [
    const Supplier(
      id: 's1',
      name: 'مؤسسة النور للتوريدات العامة',
      dealType: SupplierDealType.direct,
    ),
  ];

  @override
  Future<Supplier?> getById(String id) async => null;

  @override
  Future<Supplier> create(SupplierDraft draft) => throw UnimplementedError();

  @override
  Future<void> update({required String id, required SupplierDraft draft}) =>
      throw UnimplementedError();

  @override
  Future<void> delete(String id) => throw UnimplementedError();
}

class _FakeAccountRepository implements AccountRepository {
  const _FakeAccountRepository();

  @override
  Future<List<Account>> chart() async => const [
    Account(
      id: 'a1',
      code: '1010',
      name: 'النقدية',
      type: AccountType.asset,
      balance: 0,
    ),
    Account(
      id: 'a2',
      code: '5010',
      name: 'تكلفة البضاعة المباعة',
      type: AccountType.expense,
      balance: 0,
    ),
  ];

  @override
  Future<Account> create(AccountDraft draft) => throw UnimplementedError();
}
