import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasad_erp/core/theme/app_theme.dart';
import 'package:hasad_erp/domain/auth/app_role.dart';
import 'package:hasad_erp/domain/auth/app_user.dart';
import 'package:hasad_erp/domain/suppliers/supplier.dart';
import 'package:hasad_erp/domain/suppliers/supplier_draft.dart';
import 'package:hasad_erp/presentation/providers/auth_providers.dart';
import 'package:hasad_erp/presentation/providers/suppliers_providers.dart';
import 'package:hasad_erp/presentation/screens/suppliers/suppliers_screen.dart';

const _offlineCreate = 'تم حفظ المورد محليًا وستتم مزامنته عند عودة الاتصال';
const _offlineUpdate =
    'تم حفظ تعديلات المورد محليًا وستتم مزامنتها عند عودة الاتصال';
const _offlineDelete = 'تم حذف المورد محليًا وستتم مزامنته مع الخادم عند عودة الاتصال';
const _onlineCreate = 'تمت إضافة المورد';

const _user = AppUser(
  id: 'u1',
  email: 'admin@test.local',
  name: 'مدير النظام',
  role: AppRole.admin,
  tenantId: 't1',
);

/// Suppliers list stub that never touches the repository chain: it records the
/// write so a test can assert both the call and the resulting message.
class _FakeSuppliersList extends SuppliersList {
  @override
  Future<List<Supplier>> build() async => _rows;

  @override
  Future<Supplier> create(SupplierDraft draft) async {
    final supplier = Supplier(
      id: 's-new',
      name: draft.name,
      phone: draft.phone,
      notes: draft.notes,
      dealType: draft.dealType,
      commissionRate: draft.commissionRate,
      createdAt: DateTime(2026, 1, 1),
    );
    _rows = [..._rows, supplier];
    return supplier;
  }

  @override
  Future<void> updateSupplier({
    required String id,
    required SupplierDraft draft,
  }) async {
    _rows = [
      for (final s in _rows)
        if (s.id == id)
          Supplier(
            id: id,
            name: draft.name,
            phone: draft.phone,
            notes: draft.notes,
            dealType: draft.dealType,
            commissionRate: draft.commissionRate,
            createdAt: s.createdAt,
          )
        else
          s,
    ];
  }

  @override
  Future<void> delete(String id) async {
    _rows = [for (final s in _rows) if (s.id != id) s];
  }
}

List<Supplier> _rows = <Supplier>[
  Supplier(
    id: 's1',
    name: 'مورد',
    phone: '0599111222',
    notes: null,
    dealType: SupplierDealType.direct,
    commissionRate: null,
    createdAt: DateTime(2026, 1, 1),
  ),
];

Future<void> _pumpScreen(
  WidgetTester tester, {
  required bool writesLocalFirst,
}) async {
  _rows = <Supplier>[
    Supplier(
      id: 's1',
      name: 'مورد',
      phone: '0599111222',
      notes: null,
      dealType: SupplierDealType.direct,
      commissionRate: null,
      createdAt: DateTime(2026, 1, 1),
    ),
  ];
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authStateProvider.overrideWith((ref) => Stream.value(_user)),
        suppliersListProvider.overrideWith(_FakeSuppliersList.new),
        supplierWritesLocalFirstProvider
            .overrideWithValue(writesLocalFirst),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: const Scaffold(body: SuppliersScreen()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// A bottom sheet with an autofocused field never settles (cursor blink), so
/// sheet transitions are driven with pump + a fixed delay.
Future<void> _pumpSheet(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  testWidgets('offline-first: create shows the pending-save message',
      (tester) async {
    await _pumpScreen(tester, writesLocalFirst: true);

    await tester.tap(find.byTooltip('إضافة مورد'));
    await _pumpSheet(tester);
    expect(find.text('إضافة مورد جديد'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'مورد جديد');
    await tester.tap(find.widgetWithText(FilledButton, 'إضافة'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text(_offlineCreate), findsOneWidget);
    expect(find.text(_onlineCreate), findsNothing);
  });

  testWidgets('online path keeps the short confirmation message',
      (tester) async {
    await _pumpScreen(tester, writesLocalFirst: false);

    await tester.tap(find.byTooltip('إضافة مورد'));
    await _pumpSheet(tester);

    await tester.enterText(find.byType(TextFormField).at(0), 'مورد جديد');
    await tester.tap(find.widgetWithText(FilledButton, 'إضافة'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text(_onlineCreate), findsOneWidget);
    expect(find.text(_offlineCreate), findsNothing);
  });

  testWidgets('offline-first: update shows the pending-edit message',
      (tester) async {
    await _pumpScreen(tester, writesLocalFirst: true);
    expect(find.text('مورد'), findsOneWidget);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await _pumpSheet(tester);
    await tester.tap(find.text('تعديل'));
    await _pumpSheet(tester);
    expect(find.text('تعديل المورد'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'مورد محدث');
    await tester.tap(find.widgetWithText(FilledButton, 'حفظ التعديلات'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text(_offlineUpdate), findsOneWidget);
  });

  testWidgets('offline-first: delete shows the pending-delete message',
      (tester) async {
    await _pumpScreen(tester, writesLocalFirst: true);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await _pumpSheet(tester);
    await tester.tap(find.text('حذف'));
    await _pumpSheet(tester);
    expect(find.text('حذف المورد'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'حذف'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text(_offlineDelete), findsOneWidget);
  });
}