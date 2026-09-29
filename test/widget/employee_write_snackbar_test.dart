import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasad_erp/core/theme/app_theme.dart';
import 'package:hasad_erp/domain/auth/app_role.dart';
import 'package:hasad_erp/domain/auth/app_user.dart';
import 'package:hasad_erp/domain/employees/employee.dart';
import 'package:hasad_erp/domain/employees/employee_draft.dart';
import 'package:hasad_erp/presentation/providers/auth_providers.dart';
import 'package:hasad_erp/presentation/providers/employees_providers.dart';
import 'package:hasad_erp/presentation/screens/employees/employees_screen.dart';

const _offlineCreate = 'تم حفظ الموظف محليًا وستتم مزامنته عند عودة الاتصال';
const _offlineUpdate =
    'تم حفظ تعديلات الموظف محليًا وستتم مزامنتها عند عودة الاتصال';
const _offlineDelete = 'تم حذف الموظف محليًا وستتم مزامنته مع الخادم عند عودة الاتصال';
const _onlineCreate = 'تمت إضافة الموظف';

const _user = AppUser(
  id: 'u1',
  email: 'admin@test.local',
  name: 'مدير النظام',
  role: AppRole.admin,
  tenantId: 't1',
);

/// Employees list stub that never touches the repository chain: it records the
/// write so a test can assert both the call and the resulting message.
class _FakeEmployeesList extends EmployeesList {
  @override
  Future<List<Employee>> build() async => _rows;

  @override
  Future<Employee> create(EmployeeDraft draft) async {
    final employee = Employee(
      id: 'e-new',
      name: draft.name,
      jobTitle: draft.jobTitle,
      phone: draft.phone,
      baseSalary: draft.baseSalary,
      createdAt: DateTime(2026, 1, 1),
    );
    _rows = [..._rows, employee];
    return employee;
  }

  @override
  Future<void> updateEmployee({
    required String id,
    required EmployeeDraft draft,
  }) async {
    _rows = [
      for (final e in _rows)
        if (e.id == id)
          Employee(
            id: id,
            name: draft.name,
            jobTitle: draft.jobTitle,
            phone: draft.phone,
            baseSalary: draft.baseSalary,
            createdAt: e.createdAt,
          )
        else
          e,
    ];
  }

  @override
  Future<void> delete(String id) async {
    _rows = [for (final e in _rows) if (e.id != id) e];
  }
}

List<Employee> _rows = <Employee>[
  Employee(
    id: 'e1',
    name: 'موظف',
    jobTitle: null,
    phone: '0599111222',
    baseSalary: 500000,
    createdAt: DateTime(2026, 1, 1),
  ),
];

Future<void> _pumpScreen(
  WidgetTester tester, {
  required bool writesLocalFirst,
}) async {
  _rows = <Employee>[
    Employee(
      id: 'e1',
      name: 'موظف',
      jobTitle: null,
      phone: '0599111222',
      baseSalary: 500000,
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
        employeesListProvider.overrideWith(_FakeEmployeesList.new),
        employeeWritesLocalFirstProvider
            .overrideWithValue(writesLocalFirst),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: const Scaffold(body: EmployeesScreen()),
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

    await tester.tap(find.byTooltip('إضافة موظف'));
    await _pumpSheet(tester);
    expect(find.text('إضافة موظف جديد'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'موظف جديد');
    await tester.enterText(find.byType(TextFormField).at(3), '5000');
    await tester.tap(find.widgetWithText(FilledButton, 'إضافة'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text(_offlineCreate), findsOneWidget);
    expect(find.text(_onlineCreate), findsNothing);
  });

  testWidgets('online path keeps the short confirmation message',
      (tester) async {
    await _pumpScreen(tester, writesLocalFirst: false);

    await tester.tap(find.byTooltip('إضافة موظف'));
    await _pumpSheet(tester);

    await tester.enterText(find.byType(TextFormField).at(0), 'موظف جديد');
    await tester.enterText(find.byType(TextFormField).at(3), '5000');
    await tester.tap(find.widgetWithText(FilledButton, 'إضافة'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text(_onlineCreate), findsOneWidget);
    expect(find.text(_offlineCreate), findsNothing);
  });

  testWidgets('offline-first: update shows the pending-edit message',
      (tester) async {
    await _pumpScreen(tester, writesLocalFirst: true);
    expect(find.text('موظف'), findsOneWidget);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await _pumpSheet(tester);
    await tester.tap(find.text('تعديل'));
    await _pumpSheet(tester);
    expect(find.text('تعديل الموظف'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'موظف محدث');
    await tester.enterText(find.byType(TextFormField).at(3), '6000');
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
    expect(find.text('حذف الموظف'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'حذف'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text(_offlineDelete), findsOneWidget);
  });
}