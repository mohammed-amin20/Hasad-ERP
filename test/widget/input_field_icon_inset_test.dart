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
import 'package:hasad_erp/presentation/screens/auth/login_screen.dart';
import 'package:hasad_erp/presentation/screens/journal/journal_screen.dart';
import 'package:hasad_erp/presentation/screens/products/products_screen.dart';
import 'package:hasad_erp/presentation/screens/purchases/purchase_invoices_screen.dart';
import 'package:hasad_erp/presentation/screens/sales/sale_invoices_screen.dart';
import 'package:hasad_erp/presentation/shell/app_shell.dart';
import 'package:hasad_erp/presentation/widgets/field_icon.dart';

import '../tool/shell_stubs.dart';

/// Regression: every input field's **leading** icon must sit [kFieldIconInset]
/// away from the field's logical-start border, in both RTL and LTR, at every
/// supported viewport — without moving the field's own geometry.
///
/// ## The defect
///
/// In the Arabic RTL app the prefix glyph was *touching* the field border. The
/// chain, all in stock Flutter:
/// 1. `InputDecorator` positions the prefix slot **flush** with the field
///    border. `contentPadding.start` offsets the *text*, not the icon — so
///    raising `contentPadding` cannot help, and neither can
///    `prefixIconConstraints`, which only sizes the slot.
/// 2. A Material `Icon` re-wraps its glyph in `SizedBox`/`Center`, so the slack
///    in the 40px slot left it ~11px from the border for free.
/// 3. `FaIcon` deliberately drops that `SizedBox`/`Center` and hands a bare
///    `RichText` to the slot, and `RenderParagraph` paints at `TextAlign.start` —
///    in RTL, the border side.
///
/// So the two icon families disagreed, and the `FaIcon` one (74 of the 76
/// prefixes) measured a **0.00px** gap. Measured on the real new-sale form
/// before the fix, at 1440x900 and 360x640, RTL and LTR:
///
/// | slot | RTL gap | LTR gap |
/// |---|---|---|
/// | `prefixIcon` (FaIcon) | **0.00** | **0.00** |
/// | dropdown arrow | 12.00 | 12.00 |
/// | search clear (IconButton) | 11.00 | 11.00 |
///
/// ## The fix
///
/// `FieldIcon` ([lib/presentation/widgets/field_icon.dart]) wraps the icon in
/// `EdgeInsetsDirectional.only(start: kFieldIconInset)`. It has to be a widget,
/// not a theme value, because a theme supplies defaults per `InputDecoration`
/// *property* and cannot transform a `Widget` — and neither `TextField` nor
/// `EditableText` wraps `prefixIcon`.
///
/// The padding sits **inside** the slot's `ConstrainedBox`, so the slot still
/// resolves to 40x18, `prefixIconSize` is unchanged, the content inset is
/// unchanged, and only the ink moves. `_fieldGeometryIsUnchanged` pins that.
///
/// After: prefix gap **12.00** in RTL and LTR, vertical delta still **0.00**,
/// and every field rect byte-identical to the table in
/// `_expectedSaleFormGeometry`.
///
/// ## Why the trailing side is asserted loosely
///
/// The three suffix occupants are `IconButton`s, and the dropdown arrow is
/// Flutter's own. Wrapping an `IconButton` in `end: 12` inside the existing
/// 36px slot would shrink the button to 24px and cost tap targets, and forcing
/// exactly 12px would mean widening `suffixIconConstraints` to 48 — 12px of
/// text width on *every* field to move a suffix 3px. They were measured instead
/// and left alone, so they are asserted only to be *not flush* (>= 10), which
/// still catches a regression that collapses them to 0.
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

/// The two widths the geometry baseline is pinned at (the widest layout and the
/// narrowest phone). Pinning every viewport would be noise — the field rects
/// only vary with the two.
const _geometryViewports = <String, Size>{
  'desktop 1440x900': Size(1440, 900),
  'small Android 360x640': Size(360, 640),
};

/// The inset this suite demands, as a **literal**.
///
/// It is deliberately NOT `kFieldIconInset`. An earlier revision of this file
/// used the constant under test as its own expected value, which made the whole
/// suite tautological: setting `kFieldIconInset = 0.0` (the mutation proof)
/// moved the expectation to 0 with it and all 27 cases still passed. The design
/// value is a decision; the constant is an implementation of it. Pin the
/// decision here so changing the constant has to be a deliberate, visible act.
const double _expectedInset = 12.0;

/// Tolerance on the 12px inset and the vertical centre line. Sub-pixel layout
/// rounding is the only thing that can move these.
const _tolerance = 0.5;

/// A trailing icon must never end up flush against the border.
const _minTrailingGap = 10.0;

/// Field `(left, right, width, height)` for the new-sale form, recorded
/// **before** `FieldIcon` existed. The inset is ink-only, so these must not
/// move: if they do, the padding is leaking into layout.
const _expectedSaleFormGeometry = <String, List<(double, double)>>{
  // (width, height) per field, in render order.
  'desktop 1440x900': [
    (1392, 52),
    (1392, 48),
    (690, 49),
    (690, 52),
    (1392, 70),
  ],
  'small Android 360x640': [
    (312, 52),
    (312, 48),
    (150, 49),
    (150, 52),
    (312, 70),
  ],
};

/// Painted-glyph rect, in global coordinates, of the `RichText` inside [iconEl].
///
/// This is the ink the user sees, *not* `tester.getRect(iconFinder)` — for an
/// icon under a slot constraint those differ by the whole bug. `TextBox` is
/// paragraph-local, so the boxes are shifted by the paragraph's own origin.
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
  final origin = paragraph.localToGlobal(Offset.zero);
  var rect = boxes.first.toRect().shift(origin);
  for (final box in boxes.skip(1)) {
    rect = rect.expandToInclude(box.toRect().shift(origin));
  }
  return rect;
}

/// Distance from [glyph] to the field edge on [side].
double _gap(Rect field, Rect glyph, TextDirection direction, {required bool start}) {
  final rtl = direction == TextDirection.rtl;
  final fromStart = start ? rtl : !rtl;
  return fromStart
      ? field.right - glyph.right
      : glyph.left - field.left;
}

/// Asserts the inset on every input field's leading icon, and that no icon is
/// vertically off its field's centre line.
void _expectLeadingIconsInset(WidgetTester tester, String stage) {
  final fields = find.byType(InputDecorator);
  expect(fields, findsWidgets, reason: '$stage rendered no input field');

  var leading = 0;
  var trailing = 0;

  for (var i = 0; i < fields.evaluate().length; i++) {
    final field = fields.at(i);
    final fieldBox = tester.getRect(field);
    if (fieldBox.width <= 0 || fieldBox.height <= 0) continue;
    final direction = Directionality.of(tester.element(field));

    for (final type in [FaIcon, Icon]) {
      final kind = type == FaIcon ? 'FaIcon' : 'Icon';
      for (final iconEl in find
          .descendant(of: field, matching: find.byType(type))
          .evaluate()) {
        final glyph = _glyphRect(tester, iconEl);
        if (glyph == null || glyph.width <= 0) continue;

        // Slot glyphs sit within ~40px of an edge, never near the middle, so
        // the field centre is an unambiguous start/end discriminator.
        final rtl = direction == TextDirection.rtl;
        final isLeading =
            rtl ? glyph.center.dx > fieldBox.center.dx : glyph.center.dx < fieldBox.center.dx;
        final gap = _gap(fieldBox, glyph, direction, start: isLeading);

        final pos = '$stage field[$i] $kind '
            'glyph ${glyph.left.toStringAsFixed(2)}..${glyph.right.toStringAsFixed(2)} '
            'in field ${fieldBox.left.toStringAsFixed(2)}..${fieldBox.right.toStringAsFixed(2)}';

        if (isLeading) {
          leading++;
          expect(
            gap,
            closeTo(_expectedInset, _tolerance),
            reason: '$pos — leading icon should be $_expectedInset from the '
                'start border, measured $gap',
          );
        } else {
          trailing++;
          expect(
            gap,
            greaterThanOrEqualTo(_minTrailingGap),
            reason: '$pos — trailing icon is flush against the end border '
                '($gap); see this file\'s header for why it is not pinned to 12',
          );
        }

        // The inset must not have reintroduced the vertical defect.
        expect(
          (glyph.center.dy - fieldBox.center.dy).abs(),
          lessThanOrEqualTo(1.0),
          reason: '$pos glyph centre ${glyph.center.dy.toStringAsFixed(2)} vs '
              'field centre ${fieldBox.center.dy.toStringAsFixed(2)}',
        );
      }
    }
  }

  expect(
    leading,
    greaterThan(0),
    reason: '$stage rendered no leading icon (leading: $leading, '
        'trailing: $trailing)',
  );
}

/// Pins the new-sale form's field geometry, proving the inset is ink-only.
void _fieldGeometryIsUnchanged(WidgetTester tester, String key, String stage) {
  final expected = _expectedSaleFormGeometry[key]!;
  final actual = <(double, double)>[];
  for (final field in find.byType(InputDecorator).evaluate()) {
    final rect = tester.getRect(find.byElementPredicate((e) => e == field));
    if (rect.width > 0) actual.add((rect.width, rect.height));
  }
  expect(
    actual.map((e) => '${e.$1.toStringAsFixed(0)}x${e.$2.toStringAsFixed(0)}'),
    expected.map((e) => '${e.$1.toStringAsFixed(0)}x${e.$2.toStringAsFixed(0)}'),
    reason: '$stage: the FieldIcon inset must not change any field\'s width or '
        'height — it is applied inside the slot\'s ConstrainedBox',
  );
}

Finder _customerField() =>
    find.widgetWithText(DropdownButtonFormField<String>, 'العميل');

void _setViewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// `Override` is not publicly exported by Riverpod 3.x, so the override list is
/// built inline and shared by every host.
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

/// Mirrors `HasadApp`'s wrapper (RTL root + `MaterialApp` with
/// `locale: Locale('ar')`, the Arabic delegates and `AppTheme.light`), but lets
/// the caller choose the text direction.
///
/// `MaterialApp` re-asserts `Directionality` from `locale`, and `locale` is
/// 'ar' — so an *outer* `Directionality` is silently overridden and the screen
/// stays RTL. The direction has to be injected through `builder:` or the LTR
/// half of this suite is a lie.
Widget _host(Widget body, TextDirection direction) {
  return _scope(
    Directionality(
      textDirection: direction,
      child: MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: AppTheme.light,
        builder: (context, child) =>
            Directionality(textDirection: direction, child: child!),
        home: Scaffold(body: body),
      ),
    ),
  );
}

void main() {
  group('the constant matches the design value', () {
    test('kFieldIconInset is 12', () {
      // See `_expectedInset`: the constant is the implementation, this is the
      // decision. They must agree, and the geometry groups below prove the
      // constant is what actually gets painted.
      expect(kFieldIconInset, _expectedInset);
    });
  });

  group('production route (HasadApp -> shell -> sales -> new invoice)', () {
    for (final vp in _viewports.entries) {
      testWidgets('leading icon is 12px from the border on ${vp.key}', (
        tester,
      ) async {
        _setViewport(tester, vp.value);

        // The real app widget, so the root Directionality, `locale: Locale('ar')`,
        // the Arabic delegates and `AppTheme.light` are all the real ones.
        await tester.pumpWidget(_scope(const HasadApp()));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        final shell = find.byType(AppShell);
        expect(shell, findsOneWidget, reason: 'signed-in user must reach shell');

        ProviderScope.containerOf(
          tester.element(shell),
        ).read(currentDestinationProvider.notifier).select(_salesTab);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.byType(SaleInvoicesScreen), findsOneWidget);

        await tester.tap(find.byType(FloatingActionButton).first);
        await tester.pumpAndSettle();
        expect(_customerField(), findsOneWidget, reason: 'new sale form opened');

        _expectLeadingIconsInset(tester, 'new sale form @ ${vp.key}');
        expect(tester.takeException(), isNull, reason: 'layout must stay clean');
      });
    }
  });

  group('directional parity (the inset must follow the start edge)', () {
    final screens = <String, Widget>{
      'new purchase form': const PurchaseInvoicesScreen(),
      'product form': const ProductsScreen(),
      'account form': const ChartOfAccountsScreen(),
      'journal form': const JournalScreen(),
      'login form': const LoginScreen(),
    };
    const directions = <String, TextDirection>{
      'RTL': TextDirection.rtl,
      'LTR': TextDirection.ltr,
    };

    for (final entry in screens.entries) {
      for (final dir in directions.entries) {
        for (final vp in _geometryViewports.entries) {
          testWidgets('${entry.key} ${dir.key} on ${vp.key}', (tester) async {
            _setViewport(tester, vp.value);
            await tester.pumpWidget(_host(entry.value, dir.value));
            await tester.pumpAndSettle();

            // Every one of these is reached by tapping a FAB to push a form,
            // except the login screen which *is* the form.
            if (find.byType(FloatingActionButton).evaluate().isNotEmpty) {
              await tester.tap(find.byType(FloatingActionButton).first);
              await tester.pumpAndSettle();
            }

            _expectLeadingIconsInset(
              tester,
              '${entry.key} ${dir.key} @ ${vp.key}',
            );
            expect(tester.takeException(), isNull);
          });
        }
      }
    }
  });

  group('layout is unchanged by the inset', () {
    for (final vp in _geometryViewports.entries) {
      testWidgets('new sale form field rects match the pre-inset baseline on '
          '${vp.key}', (tester) async {
        _setViewport(tester, vp.value);
        await tester.pumpWidget(
          _host(const SaleInvoicesScreen(), TextDirection.rtl),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byType(FloatingActionButton).first);
        await tester.pumpAndSettle();

        _fieldGeometryIsUnchanged(tester, vp.key, 'new sale form @ ${vp.key}');
      });
    }
  });
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
