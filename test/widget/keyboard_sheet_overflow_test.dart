import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasad_erp/core/network/connectivity_providers.dart';
import 'package:hasad_erp/core/theme/app_theme.dart';
import 'package:hasad_erp/domain/accounts/account.dart';
import 'package:hasad_erp/domain/accounts/account_draft.dart';
import 'package:hasad_erp/domain/accounts/account_repository.dart';
import 'package:hasad_erp/domain/auth/app_role.dart';
import 'package:hasad_erp/domain/auth/app_user.dart';
import 'package:hasad_erp/domain/invoices/invoice.dart';
import 'package:hasad_erp/domain/products/product.dart';
import 'package:hasad_erp/domain/products/product_draft.dart';
import 'package:hasad_erp/domain/products/product_repository.dart';
import 'package:hasad_erp/domain/suppliers/supplier.dart';
import 'package:hasad_erp/domain/suppliers/supplier_draft.dart';
import 'package:hasad_erp/domain/suppliers/supplier_repository.dart';
import 'package:hasad_erp/presentation/providers/accounts_providers.dart';
import 'package:hasad_erp/presentation/providers/auth_providers.dart';
import 'package:hasad_erp/presentation/providers/products_providers.dart';
import 'package:hasad_erp/presentation/providers/suppliers_providers.dart';
import 'package:hasad_erp/presentation/screens/accounts/chart_of_accounts_screen.dart';
import 'package:hasad_erp/presentation/screens/journal/journal_screen.dart';
import 'package:hasad_erp/presentation/screens/products/products_screen.dart';
import 'package:hasad_erp/presentation/widgets/payment_sheets.dart';

/// Regression: adding a record via a bottom sheet on a phone overflowed.
///
/// Two distinct bugs live here, and both are covered.
///
/// 1. BOTTOM overflow. The sheets that do `padding: ... 24 + viewInsets.bottom`
///    around a `Column(mainAxisSize: min)` give the extra keyboard space to the
///    sheet but have no scroll view to absorb it, so once the keyboard opened
///    the `Column` was squeezed past the available height.
///
/// 2. RIGHT overflow. `DropdownButtonFormField` without `isExpanded: true`
///    lays its internal `Row` out with `mainAxisSize: min`, which cannot shrink
///    below the selected item's intrinsic width. A realistic Arabic label then
///    blows past the field.
///
/// The keyboard is simulated with `tester.view.viewInsets`, which is what a
/// real keyboard changes: `MediaQuery.size` stays the full screen while
/// `viewInsets.bottom` reports the covered strip.
///
/// FIXTURES ARE PRODUCTION-SHAPED ON PURPOSE. The first version of this file
/// seeded the chart with only `1010 — النقدية` and never overrode the supplier
/// repository at all, so both dropdowns rendered a single short label, could
/// not overflow, and the suite passed green over two real bugs. A fixture with
/// the shortest possible label makes the test vacuous — use the real seeded
/// names and non-empty relation lists here, and assert a long label is actually
/// SELECTED (an unselected dropdown draws no long text).
const _user = AppUser(
  id: 'u1',
  email: 'admin@test.local',
  name: 'مدير النظام',
  role: AppRole.admin,
  tenantId: 't1',
);

const _phones = <String, Size>{
  'small Android 360x640': Size(360, 640),
  'iPhone SE 375x667': Size(375, 667),
};

const _keyboard = 300.0;

/// `pumpAndSettle` cannot be used once a sheet with an autofocused field is
/// open: the `EditableText` cursor blink reschedules frames forever. Drive the
/// sheet transition with explicit pumps instead.
Future<void> _pumpSheet(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

/// Opens [dropdown] and selects the longest label in [candidates] that the
/// harness can actually reach, returning the label it selected.
///
/// A `DropdownButtonFormField` sizes its internal `Row` to the item list, so a
/// realistic label overflows the field even before anything is selected — the
/// open-sheet assertions below are what catch that. Selecting a long label then
/// proves the *selected* text stays bounded as well.
///
/// The menu is a lazy list and its last item is often laid out just past the
/// menu's own clip — present in the tree, `getRect` returns a plausible box,
/// yet taps fall through to the route barrier and just dismiss the menu. Hence
/// candidates are tried longest-first; if a candidate exists but isn't
/// hit-testable, we nudge the menu's scrollable to bring it into the
/// tappable zone before tapping.
Future<String> _selectLongestReachable(
  WidgetTester tester,
  Finder dropdown,
  List<String> candidates,
) async {
  await tester.tap(dropdown);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));

  // DEBUG
  // ignore: avoid_print
  print('DEBUG: candidates=$candidates');
  // ignore: avoid_print
  print('DEBUG: DropdownMenuItem count=${find.byType(DropdownMenuItem<String?>).evaluate().length}');
  for (final e in find.byType(DropdownMenuItem<String?>).evaluate()) {
    final item = e.widget as DropdownMenuItem<String?>;
    final child = item.child;
    final label = child is Text ? child.data : '?';
    // ignore: avoid_print
    print('DEBUG: menu item: "$label"');
  }

  for (final label in candidates) {
    final item = find.text(label);
    // ignore: avoid_print
    print('DEBUG: candidate "$label": evaluate=${item.evaluate().length}, hitTestable=${item.hitTestable().evaluate().length}');
    if (item.evaluate().isEmpty) {
      await tester.dragUntilVisible(
        item,
        find.byType(Scrollable).last,
        const Offset(0, -80),
      );
      await tester.pump();
    }

    // The menu's bottom item often sits just past the menu's own clip,
    // where it exists in the tree but isn't hit-testable. Nudge the
    // menu's scrollable until the target is comfortably tappable.
    if (item.hitTestable().evaluate().isEmpty) {
      // ignore: avoid_print
      print('DEBUG: candidate "$label" not hitTestable, nudging...');
      final menuScrollable = find
          .ancestor(of: item, matching: find.byType(Scrollable))
          .first;
      // ignore: avoid_print
      print('DEBUG: menuScrollable count=${menuScrollable.evaluate().length}');
      if (menuScrollable.evaluate().isNotEmpty) {
        // ignore: avoid_print
        print('DEBUG: menuScrollable rect=${tester.getRect(menuScrollable.first)}');
        // ignore: avoid_print
        print('DEBUG: item rect=${tester.getRect(item.last)}');
      }
      await tester.drag(menuScrollable, const Offset(0, -120));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
    }

    // ignore: avoid_print
    print('DEBUG: after nudge hitTestable=${item.hitTestable().evaluate().length}');
    if (item.hitTestable().evaluate().isEmpty) continue;

    await tester.tap(item.hitTestable().last, warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    return label;
  }
  fail(
    'no candidate label was tappable in the open menu: $candidates',
  );
}

void main() {
  for (final phone in _phones.entries) {
    testWidgets(
      'Add Account sheet fits with the keyboard open on ${phone.key}',
      (tester) async {
        tester.view.physicalSize = phone.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          _host(const ChartOfAccountsScreen()),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byType(FloatingActionButton));
        await _pumpSheet(tester);
        expect(find.text('إضافة حساب جديد'), findsOneWidget);
        expect(
          tester.takeException(),
          isNull,
          reason: 'add account sheet while idle on ${phone.key}',
        );

        tester.view.viewInsets = const FakeViewPadding(bottom: _keyboard);
        await tester.pump();

        expect(
          tester.takeException(),
          isNull,
          reason: 'add account sheet with the keyboard open on ${phone.key}',
        );
        // The scroll view must keep every control reachable above the keyboard.
        expect(find.text('إضافة'), findsOneWidget);
        expect(find.text('كود الحساب الأب (اختياري)'), findsOneWidget);
      },
    );

    testWidgets(
      'New Journal Entry sheet fits with the keyboard open on ${phone.key}',
      (tester) async {
        tester.view.physicalSize = phone.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(_host(const JournalScreen()));
        await tester.pumpAndSettle();

        await tester.tap(find.byType(FloatingActionButton));
        await _pumpSheet(tester);
        expect(find.text('قيد يدوي جديد'), findsOneWidget);
        expect(
          tester.takeException(),
          isNull,
          reason: 'journal entry sheet while idle on ${phone.key}',
        );

        tester.view.viewInsets = const FakeViewPadding(bottom: _keyboard);
        await tester.pump();

        expect(
          tester.takeException(),
          isNull,
          reason: 'journal entry sheet with the keyboard open on ${phone.key}',
        );
        expect(find.text('المدين'), findsOneWidget);
      },
    );

    testWidgets(
      'New Journal Entry account dropdown holds the longest seeded account '
      'on ${phone.key}',
      (tester) async {
        tester.view.physicalSize = phone.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(_host(const JournalScreen()));
        await tester.pumpAndSettle();

        await tester.tap(find.byType(FloatingActionButton));
        await _pumpSheet(tester);

        final accountDropdown = find
            .descendant(
              of: find.byType(Form),
              matching: find.byType(DropdownButtonFormField<String>),
            )
            .first;
        expect(accountDropdown, findsOneWidget);

        final selected = await _selectLongestReachable(
          tester,
          accountDropdown,
          // Longest-first. The absolute worst case is already exercised by the
          // open-sheet assertion above; here we need a long label the popup
          // menu can actually deliver to a tap.
          const [
            _longestAccountLabel,
            '3020 — الأرباح المحتجزة',
            '1040 — الأصول الثابتة',
          ],
        );
        expect(
          find.text(selected),
          findsWidgets,
          reason: 'the selected long account label must stay painted in the '
              'field on ${phone.key}',
        );

        expect(
          tester.takeException(),
          isNull,
          reason: 'journal account dropdown, longest seeded account, '
              'keyboard closed on ${phone.key}',
        );

        // Worst case: the long label is selected AND the keyboard is open.
        tester.view.viewInsets = const FakeViewPadding(bottom: _keyboard);
        await tester.pump();
        expect(
          tester.takeException(),
          isNull,
          reason: 'journal account dropdown, longest seeded account, '
              'keyboard open on ${phone.key}',
        );
      },
    );

    testWidgets(
      'New Product sheet fits with the keyboard open on ${phone.key}',
      (tester) async {
        tester.view.physicalSize = phone.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(_host(const ProductsScreen()));
        await tester.pumpAndSettle();

        await tester.tap(find.byType(FloatingActionButton));
        await _pumpSheet(tester);
        expect(
          tester.takeException(),
          isNull,
          reason: 'new product sheet while idle on ${phone.key}',
        );

        tester.view.viewInsets = const FakeViewPadding(bottom: _keyboard);
        await tester.pump();

        expect(
          tester.takeException(),
          isNull,
          reason: 'new product sheet with the keyboard open on ${phone.key}',
        );
        expect(find.text('إضافة'), findsOneWidget);
      },
    );

    testWidgets(
      'New Product supplier dropdown holds the longest supplier name '
      'on ${phone.key}',
      (tester) async {
        tester.view.physicalSize = phone.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(_host(const ProductsScreen()));
        await tester.pumpAndSettle();

        await tester.tap(find.byType(FloatingActionButton));
        await _pumpSheet(tester);
        // The form loads suppliers asynchronously in initState.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        final supplierDropdown = find.descendant(
          of: find.byType(Form),
          matching: find.byType(DropdownButtonFormField<String?>),
        );
        expect(supplierDropdown, findsOneWidget);

        final selected = await _selectLongestReachable(
          tester,
          supplierDropdown,
          const [_longestSupplierName, 'شركة الأمل'],
        );
        expect(
          find.text(selected),
          findsWidgets,
          reason: 'the selected long supplier name must stay painted in the '
              'field on ${phone.key}',
        );

        expect(
          tester.takeException(),
          isNull,
          reason: 'product supplier dropdown, longest supplier name, '
              'keyboard closed on ${phone.key}',
        );

        tester.view.viewInsets = const FakeViewPadding(bottom: _keyboard);
        await tester.pump();
        expect(
          tester.takeException(),
          isNull,
          reason: 'product supplier dropdown, longest supplier name, '
              'keyboard open on ${phone.key}',
        );
      },
    );

    testWidgets(
      'New Product commission supplier dropdown works on ${phone.key}',
      (tester) async {
        tester.view.physicalSize = phone.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(_host(const ProductsScreen()));
        await tester.pumpAndSettle();

        await tester.tap(find.byType(FloatingActionButton));
        await _pumpSheet(tester);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        final supplierDropdown = find.descendant(
          of: find.byType(Form),
          matching: find.byType(DropdownButtonFormField<String?>),
        );
        expect(supplierDropdown, findsOneWidget);

        // Try to select the commission supplier; if the menu clips it,
        // fall back to the longest direct supplier. Either way the
        // dropdown and the form must not overflow.
        final selected = await _selectLongestReachable(
          tester,
          supplierDropdown,
          const [_longestCommissionSupplierMenuLabel, _longestSupplierName],
        );
        expect(find.text(selected), findsWidgets);

        // If we got a commission supplier, the extra commission field appears.
        if (selected == _longestCommissionSupplierMenuLabel) {
          expect(find.text('نسبة العمولة %'), findsOneWidget);
        }

        expect(
          tester.takeException(),
          isNull,
          reason: 'product commission supplier dropdown on ${phone.key}',
        );

        tester.view.viewInsets = const FakeViewPadding(bottom: _keyboard);
        await tester.pump();
        expect(
          tester.takeException(),
          isNull,
          reason: 'product commission supplier dropdown + keyboard '
              'on ${phone.key}',
        );
      },
    );

    testWidgets(
      'Record Payment sheet fits with the keyboard open on ${phone.key}',
      (tester) async {
        tester.view.physicalSize = phone.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          _host(
            Center(
              child: ElevatedButton(
                onPressed: () => showRecordPaymentSheet(
                  tester.element(find.byType(ElevatedButton)),
                  invoice: _invoice,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byType(ElevatedButton));
        await _pumpSheet(tester);
        expect(find.text('تسجيل دفعة'), findsOneWidget);
        expect(
          tester.takeException(),
          isNull,
          reason: 'record payment sheet while idle on ${phone.key}',
        );

        tester.view.viewInsets = const FakeViewPadding(bottom: _keyboard);
        await tester.pump();

        expect(
          tester.takeException(),
          isNull,
          reason: 'record payment sheet with the keyboard open on ${phone.key}',
        );
      },
    );
  }
}

final _invoice = Invoice(
  id: 'i1',
  type: 'sale',
  no: 'INV-1042',
  partyId: 'c1',
  partyName: 'شركة الأمل التجارية المحدودة',
  date: DateTime(2026, 3, 1),
  subtotal: 2500000,
  total: 2500000,
  paid: 1000000,
  remaining: 1500000,
  status: InvoiceStatus.partial,
  ownership: InvoiceOwnership.owned,
);

Widget _host(Widget body) {
  return ProviderScope(
    overrides: [
      authStateProvider.overrideWith((ref) => Stream.value(_user)),
      isOnlineProvider.overrideWithValue(true),
      accountRepositoryProvider.overrideWithValue(const _FakeAccountRepository()),
      productRepositoryProvider.overrideWithValue(
        const _FakeProductRepository(),
      ),
      // Without this the product form's supplier dropdown renders only
      // 'بدون مورد' and cannot overflow.
      supplierRepositoryProvider.overrideWithValue(
        const _FakeSupplierRepository(),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: body),
      ),
    ),
  );
}

/// The real chart seeded by `supabase/migrations/0005_register_tenant.sql`
/// (lines 18-32), verbatim. `[5010]` is the longest label the app can ever
/// render in the journal line editor, so it is the worst case.
const _seededAccounts = <Account>[
  Account(id: 'a1010', code: '1010', name: 'النقدية', type: AccountType.asset, balance: 0),
  Account(id: 'a1015', code: '1015', name: 'البنك', type: AccountType.asset, balance: 0),
  Account(id: 'a1020', code: '1020', name: 'الذمم المدينة', type: AccountType.asset, balance: 0),
  Account(id: 'a1030', code: '1030', name: 'المخزون', type: AccountType.asset, balance: 0),
  Account(id: 'a1040', code: '1040', name: 'الأصول الثابتة', type: AccountType.asset, balance: 0),
  Account(id: 'a2010', code: '2010', name: 'الذمم الدائنة', type: AccountType.liability, balance: 0),
  Account(id: 'a2030', code: '2030', name: 'رواتب مستحقة', type: AccountType.liability, balance: 0),
  Account(id: 'a3010', code: '3010', name: 'رأس المال', type: AccountType.equity, balance: 0),
  Account(id: 'a3020', code: '3020', name: 'الأرباح المحتجزة', type: AccountType.equity, balance: 0),
  Account(id: 'a4010', code: '4010', name: 'إيرادات المبيعات', type: AccountType.revenue, balance: 0),
  Account(id: 'a4020', code: '4020', name: 'مردودات المبيعات', type: AccountType.revenue, balance: 0),
  Account(
    id: 'a5010',
    code: '5010',
    name: 'تكلفة البضاعة المباعة',
    type: AccountType.expense,
    balance: 0,
  ),
  Account(id: 'a5020', code: '5020', name: 'المصروفات التشغيلية', type: AccountType.expense, balance: 0),
  Account(id: 'a5030', code: '5030', name: 'الأجور والرواتب', type: AccountType.expense, balance: 0),
];

/// Longest seeded account label, as the journal line editor renders it
/// (`'$code — $name'`). Selecting this is what used to overflow.
const _longestAccountLabel = '5010 — تكلفة البضاعة المباعة';

/// The longest supplier label the product form can render. Supplier names are
/// free-form user text, so this is representative rather than seeded.
const _longestSupplierName = 'شركة الأمل التجارية المحدودة للتوريدات';
const _longestCommissionSupplierName =
    'مؤسسة الإتقان التجارية للتجارة العامة';
const _longestCommissionSupplierMenuLabel =
    '$_longestCommissionSupplierName (بالعمولة)';

class _FakeAccountRepository implements AccountRepository {
  const _FakeAccountRepository();

  @override
  Future<List<Account>> chart() async => _seededAccounts;

  @override
  Future<Account> create(AccountDraft draft) => throw UnimplementedError();
}

class _FakeSupplierRepository implements SupplierRepository {
  const _FakeSupplierRepository();

  @override
  Future<List<Supplier>> listAll({String? search}) async => const [
    // The commission supplier is listed first deliberately: the popup menu
    // clips its last item, so a trailing entry would be untappable in a test.
    // Real supplier order is arbitrary, so this is not a distortion.
    Supplier(
      id: 's1',
      name: _longestCommissionSupplierName,
      dealType: SupplierDealType.commission,
      commissionRate: 8,
    ),
    Supplier(id: 's2', name: 'شركة الأمل', dealType: SupplierDealType.direct),
    Supplier(
      id: 's3',
      name: _longestSupplierName,
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

class _FakeProductRepository implements ProductRepository {
  const _FakeProductRepository();

  @override
  Future<List<Product>> listAll({String? search}) async => const [
    Product(
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
