import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hasad_erp/core/network/connectivity_providers.dart';
import 'package:hasad_erp/core/theme/app_theme.dart';
import 'package:hasad_erp/domain/accounts/account.dart';
import 'package:hasad_erp/domain/accounts/account_draft.dart';
import 'package:hasad_erp/domain/accounts/account_repository.dart';
import 'package:hasad_erp/domain/auth/app_role.dart';
import 'package:hasad_erp/domain/auth/app_user.dart';
import 'package:hasad_erp/domain/customers/customer.dart';
import 'package:hasad_erp/domain/customers/customer_draft.dart';
import 'package:hasad_erp/domain/customers/customer_repository.dart';
import 'package:hasad_erp/domain/dashboard/dashboard.dart';
import 'package:hasad_erp/domain/journal/journal.dart';
import 'package:hasad_erp/domain/journal/journal_repository.dart';
import 'package:hasad_erp/domain/journal/manual_journal_draft.dart';
import 'package:hasad_erp/domain/reminders/reminder_log_entry.dart';
import 'package:hasad_erp/domain/reminders/reminder_repository.dart';
import 'package:hasad_erp/domain/reminders/reminder_settings.dart';
import 'package:hasad_erp/domain/reports/balance_sheet.dart';
import 'package:hasad_erp/domain/reports/income_statement.dart';
import 'package:hasad_erp/domain/reports/ledger.dart';
import 'package:hasad_erp/domain/reports/report_repository.dart';
import 'package:hasad_erp/domain/reports/trial_balance.dart';
import 'package:hasad_erp/presentation/providers/accounts_providers.dart';
import 'package:hasad_erp/presentation/providers/auth_providers.dart';
import 'package:hasad_erp/presentation/providers/customers_providers.dart';
import 'package:hasad_erp/presentation/providers/dashboard_providers.dart';
import 'package:hasad_erp/presentation/providers/journal_providers.dart';
import 'package:hasad_erp/presentation/providers/reminders_providers.dart';
import 'package:hasad_erp/presentation/providers/report_providers.dart'
    hide LedgerStatement, IncomeStatement, BalanceSheet;
import 'package:hasad_erp/presentation/shell/app_shell.dart';
import 'package:hasad_erp/presentation/shell/side_navigation.dart';

/// Guards the redesign shell (sidebar + live dashboard) against runtime layout
/// exceptions without a Supabase connection.
void main() {
  testWidgets('shell and dashboard render without layout exceptions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    const user = AppUser(
      id: 'u1',
      email: 'admin@test.local',
      name: 'مدير النظام',
      role: AppRole.admin,
      tenantId: 't1',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(user)),
          dashboardRepositoryProvider.overrideWithValue(
            _FakeDashboardRepository(),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const AppShell()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('لوحة التحكم'), findsWidgets);
    expect(find.text('المبيعات والعملاء'), findsOneWidget);
    expect(find.text('المحاسبة الأساسية'), findsOneWidget);

    final navList = find.descendant(
      of: find.byType(SideNavigation),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.text('المالية والإدارة'),
      80,
      scrollable: navList,
    );
    expect(find.text('المالية والإدارة'), findsOneWidget);

    expect(find.text('مبيعات اليوم'), findsOneWidget);
    expect(find.text('ديون الموردين'), findsOneWidget);
    expect(find.text('99'), findsOneWidget);
    expect(find.text('77'), findsOneWidget);
    expect(find.byType(LineChart), findsOneWidget);
    expect(find.text('عميل تجريبي'), findsOneWidget);
    expect(find.text('منتج تجريبي'), findsOneWidget);
    expect(find.text('5 / حد 10'), findsOneWidget);
    expect(find.text('مدير النظام'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    final skipLink = find.text('الانتقال للمحتوى الرئيسي');
    expect(skipLink, findsOneWidget);
    final skipOpacity = tester.widget<Opacity>(
      find.ancestor(of: skipLink, matching: find.byType(Opacity)).first,
    );
    expect(
      skipOpacity.opacity,
      1,
      reason: 'first Tab should reveal the skip link in the shell',
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('shell and dashboard render on a narrow phone viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    const user = AppUser(
      id: 'u1',
      email: 'admin@test.local',
      name: 'مدير النظام',
      role: AppRole.admin,
      tenantId: 't1',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(user)),
          dashboardRepositoryProvider.overrideWithValue(
            _FakeDashboardRepository(),
          ),
          isOnlineProvider.overrideWithValue(true),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const AppShell()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('مبيعات اليوم'), findsOneWidget);
    expect(find.text('99'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'chart of accounts and journal render, and a manual entry is posted',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      const user = AppUser(
        id: 'u1',
        email: 'admin@test.local',
        name: 'مدير النظام',
        role: AppRole.admin,
        tenantId: 't1',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith((ref) => Stream.value(user)),
            dashboardRepositoryProvider.overrideWithValue(
              _FakeDashboardRepository(),
            ),
            accountRepositoryProvider.overrideWithValue(
              _FakeAccountRepository(),
            ),
            journalRepositoryProvider.overrideWithValue(
              _FakeJournalRepository(),
            ),
          ],
          child: MaterialApp(theme: AppTheme.light, home: const AppShell()),
        ),
      );
      await tester.pumpAndSettle();

      final navList = find.descendant(
        of: find.byType(SideNavigation),
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(
        find.text('دليل الحسابات'),
        100,
        scrollable: navList,
      );
      await tester.tap(find.text('دليل الحسابات'));
      await tester.pumpAndSettle();

      expect(find.text('النقدية'), findsOneWidget);
      expect(find.text('إيرادات المبيعات'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('قيد اليومية'));
      await tester.pumpAndSettle();

      expect(find.textContaining('قيد افتتاحي'), findsOneWidget);
      expect(find.textContaining('قيد رقم 1042'), findsWidgets);

      await tester.tap(find.textContaining('قيد افتتاحي'));
      await tester.pumpAndSettle();
      expect(find.text('5301 — الإيجار'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byTooltip('قيد يدوي جديد'));
      await tester.pumpAndSettle();
      expect(find.text('قيد يدوي جديد'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'مدين').at(0),
        '100',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'دائن').at(1),
        '100',
      );

      await tester.tap(find.byType(DropdownButtonFormField<String>).at(0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('1101 — النقدية').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('4101 — إيرادات المبيعات').last);
      await tester.pumpAndSettle();

      expect(find.text('القيد متوازن'), findsOneWidget);

      await tester.tap(find.text('ترحيل القيد'));
      await tester.pumpAndSettle();

      expect(find.textContaining('تم إضافة القيد رقم 2001'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'ledger, trial balance and financial statements render and toggle',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      const user = AppUser(
        id: 'u1',
        email: 'admin@test.local',
        name: 'مدير النظام',
        role: AppRole.admin,
        tenantId: 't1',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith((ref) => Stream.value(user)),
            dashboardRepositoryProvider.overrideWithValue(
              _FakeDashboardRepository(),
            ),
            accountRepositoryProvider.overrideWithValue(
              _FakeAccountRepository(),
            ),
            journalRepositoryProvider.overrideWithValue(
              _FakeJournalRepository(),
            ),
            reportRepositoryProvider.overrideWithValue(_FakeReportRepository()),
          ],
          child: MaterialApp(theme: AppTheme.light, home: const AppShell()),
        ),
      );
      await tester.pumpAndSettle();

      final navList = find.descendant(
        of: find.byType(SideNavigation),
        matching: find.byType(Scrollable),
      );

      await tester.scrollUntilVisible(
        find.text('الأستاذ العام'),
        100,
        scrollable: navList,
      );
      await tester.tap(find.text('الأستاذ العام'));
      await tester.pumpAndSettle();

      expect(find.text('اختر حساباً لعرض حركاته'), findsOneWidget);

      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('1101 — النقدية').last);
      await tester.pumpAndSettle();

      expect(find.text('فاتورة 1'), findsOneWidget);
      expect(find.text('رصيد افتتاحي'), findsOneWidget);
      expect(find.text('الرصيد الختامي'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('ميزان المراجعة'));
      await tester.pumpAndSettle();

      expect(find.text('الميزان متوازن'), findsOneWidget);
      expect(find.textContaining('كالتاريخ'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.scrollUntilVisible(
        find.text('القوائم المالية'),
        100,
        scrollable: navList,
      );
      await tester.tap(find.text('القوائم المالية'));
      await tester.pumpAndSettle();

      expect(find.text('صافي الربح (الخسارة)'), findsOneWidget);
      expect(find.text('إيرادات المبيعات'), findsOneWidget);
      expect(find.text('الإيجار'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('الميزانية العمومية'));
      await tester.pumpAndSettle();

      expect(find.text('الميزانية متوازنة'), findsOneWidget);
      expect(find.text('حقوق الملكية'), findsOneWidget);
      expect(find.text('صافي الدخل حتى اليوم'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('reminders settings save, send-to-all and log feed render', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    const user = AppUser(
      id: 'u1',
      email: 'admin@test.local',
      name: 'مدير النظام',
      role: AppRole.admin,
      tenantId: 't1',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(user)),
          dashboardRepositoryProvider.overrideWithValue(
            _FakeDashboardRepository(),
          ),
          reminderRepositoryProvider.overrideWithValue(
            _FakeReminderRepository(),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const AppShell()),
      ),
    );
    await tester.pumpAndSettle();

    final navList = find.descendant(
      of: find.byType(SideNavigation),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.text('الإعدادات'),
      100,
      scrollable: navList,
    );
    await tester.tap(find.text('الإعدادات'));
    await tester.pumpAndSettle();

    expect(find.text('إعدادات التذكيرات'), findsOneWidget);
    expect(find.text('سجل الرسائل'), findsOneWidget);
    expect(find.text('عميل تجريبي'), findsWidgets);
    expect(find.text('فشل'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'رابط Webhook (n8n)'),
      'https://n8n.example.invalid/webhook/test',
    );
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('بعد أسبوع').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('حفظ الإعدادات'));
    await tester.pumpAndSettle();
    expect(find.text('تم حفظ الإعدادات'), findsOneWidget);

    await tester.tap(find.text('إرسال للجميع الآن'));
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    expect(find.text('تم إرسال تذكير لـ 2 عميل'), findsOneWidget);
    expect(find.text('55'), findsOneWidget);
    expect(find.text('120'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('customers remind action is admin-only and sends a reminder', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    const user = AppUser(
      id: 'u1',
      email: 'admin@test.local',
      name: 'مدير النظام',
      role: AppRole.admin,
      tenantId: 't1',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(user)),
          dashboardRepositoryProvider.overrideWithValue(
            _FakeDashboardRepository(),
          ),
          customerRepositoryProvider.overrideWithValue(
            _FakeCustomerRepository(),
          ),
          reminderRepositoryProvider.overrideWithValue(
            _FakeReminderRepository(),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const AppShell()),
      ),
    );
    await tester.pumpAndSettle();

    final navList = find.descendant(
      of: find.byType(SideNavigation),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.text('العملاء'),
      100,
      scrollable: navList,
    );
    await tester.tap(find.text('العملاء'));
    await tester.pumpAndSettle();

    expect(find.text('عميل تجريبي'), findsOneWidget);
    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    expect(find.text('إرسال تذكير'), findsOneWidget);

    await tester.tap(find.text('إرسال تذكير'));
    await tester.pumpAndSettle();
    expect(find.text('تم إرسال تذكير إلى "عميل تجريبي"'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('customers remind action is hidden for the sales role', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    const user = AppUser(
      id: 'u2',
      email: 'sales@test.local',
      name: 'موظف مبيعات',
      role: AppRole.sales,
      tenantId: 't1',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(user)),
          dashboardRepositoryProvider.overrideWithValue(
            _FakeDashboardRepository(),
          ),
          customerRepositoryProvider.overrideWithValue(
            _FakeCustomerRepository(),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const AppShell()),
      ),
    );
    await tester.pumpAndSettle();

    final navList = find.descendant(
      of: find.byType(SideNavigation),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.text('العملاء'),
      100,
      scrollable: navList,
    );
    await tester.tap(find.text('العملاء'));
    await tester.pumpAndSettle();

    expect(find.text('عميل تجريبي'), findsOneWidget);
    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    expect(find.text('إرسال تذكير'), findsNothing);
    expect(find.text('تعديل'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakeDashboardRepository implements DashboardRepository {
  @override
  Future<DashboardSummary> summary() async {
    return DashboardSummary(
      todaySales: 9900,
      todayPurchases: 4400,
      customerDebts: 7700,
      supplierDebts: 6600,
      monthExpenses: 5500,
      monthSalaries: 3300,
      netProfitMonth: 2200,
      last7Days: List.generate(
        7,
        (i) => DailySalesPurchases(
          date: DateTime(2026, 9, i + 1),
          sales: 1000 * (i + 1),
          purchases: 500 * (i + 1),
        ),
      ),
      topDebtors: const [
        DebtorSummary(customerId: 'c1', name: 'عميل تجريبي', balance: 5500),
      ],
      lowStock: const [
        LowStockItem(
          productId: 'p1',
          name: 'منتج تجريبي',
          qty: 5,
          reorderLevel: 10,
        ),
      ],
    );
  }
}

class _FakeAccountRepository implements AccountRepository {
  static const accounts = [
    Account(
      id: 'a-1101',
      code: '1101',
      name: 'النقدية',
      type: AccountType.asset,
      balance: 50000,
    ),
    Account(
      id: 'a-4101',
      code: '4101',
      name: 'إيرادات المبيعات',
      type: AccountType.revenue,
      balance: 0,
    ),
    Account(
      id: 'a-5301',
      code: '5301',
      name: 'الإيجار',
      type: AccountType.expense,
      balance: 0,
    ),
  ];

  @override
  Future<List<Account>> chart() async => accounts;

  @override
  Future<Account> create(AccountDraft draft) async => Account(
    id: 'a-new',
    code: draft.code,
    name: draft.name,
    type: draft.type,
    balance: 0,
  );
}

class _FakeJournalRepository implements JournalRepository {
  @override
  Future<List<JournalEntry>> entries({
    required DateTime from,
    required DateTime to,
  }) async {
    return [
      JournalEntry.fromJson({
        'entry_id': 'e1',
        'entry_no': 1042,
        'date': '2026-09-09',
        'memo': 'قيد افتتاحي',
        'source_type': 'manual',
        'total': 5000,
        'lines': [
          {
            'account_code': '5301',
            'account_name': 'الإيجار',
            'debit': 5000,
            'credit': 0,
          },
          {
            'account_code': '1101',
            'account_name': 'النقدية',
            'debit': 0,
            'credit': 5000,
          },
        ],
      }),
      JournalEntry.fromJson({
        'entry_id': 'e2',
        'entry_no': 1041,
        'date': '2026-09-08',
        'memo': '',
        'source_type': 'invoice',
        'total': 2400,
        'lines': [],
      }),
    ];
  }

  @override
  Future<JournalEntryResult> createManual(ManualJournalDraft draft) async {
    return const JournalEntryResult(entryId: 'e3', entryNo: 2001, total: 10000);
  }
}

class _FakeReportRepository implements ReportRepository {
  @override
  Future<LedgerStatement> ledger({
    required String accountId,
    required DateTime from,
    required DateTime to,
  }) async {
    return LedgerStatement.fromJson({
      'account_id': accountId,
      'code': '1101',
      'name': 'النقدية',
      'type': 'asset',
      'from': '2026-09-01',
      'to': '2026-09-30',
      'opening': 5000,
      'closing': 6000,
      'lines': [
        {
          'date': '2026-09-01',
          'entry_no': 1040,
          'memo': 'فاتورة 1',
          'debit': 2000,
          'credit': 0,
          'balance': 7000,
        },
        {
          'date': '2026-09-02',
          'entry_no': 1041,
          'memo': 'دفعة',
          'debit': 0,
          'credit': 1000,
          'balance': 6000,
        },
      ],
    });
  }

  @override
  Future<TrialBalanceReport> trialBalance(DateTime asOf) async {
    return TrialBalanceReport.fromJson({
      'as_of': '2026-09-30',
      'accounts': [
        {
          'account_id': 'a-1101',
          'code': '1101',
          'name': 'النقدية',
          'type': 'asset',
          'debit': 50000,
          'credit': 0,
          'balance': 50000,
        },
        {
          'account_id': 'a-2101',
          'code': '2101',
          'name': 'الموردون',
          'type': 'liability',
          'debit': 0,
          'credit': 20000,
          'balance': -20000,
        },
        {
          'account_id': 'a-4101',
          'code': '4101',
          'name': 'إيرادات المبيعات',
          'type': 'revenue',
          'debit': 0,
          'credit': 30000,
          'balance': -30000,
        },
      ],
      'totals': {'debit': 50000, 'credit': 50000},
    });
  }

  @override
  Future<IncomeStatement> incomeStatement({
    required DateTime from,
    required DateTime to,
  }) async {
    return IncomeStatement.fromJson({
      'from': '2026-09-01',
      'to': '2026-09-30',
      'revenues': [
        {
          'account_id': 'a-4101',
          'code': '4101',
          'name': 'إيرادات المبيعات',
          'amount': 10000,
        },
      ],
      'expenses': [
        {
          'account_id': 'a-5301',
          'code': '5301',
          'name': 'الإيجار',
          'amount': 3000,
        },
      ],
      'revenue_total': 10000,
      'expense_total': 3000,
      'net': 7000,
    });
  }

  @override
  Future<BalanceSheet> balanceSheet(DateTime asOf) async {
    return BalanceSheet.fromJson({
      'as_of': '2026-09-30',
      'assets': [
        {
          'account_id': 'a-1101',
          'code': '1101',
          'name': 'النقدية',
          'amount': 60000,
        },
        {
          'account_id': 'a-1201',
          'code': '1201',
          'name': 'البنك',
          'amount': 34000,
        },
      ],
      'liabilities': [
        {
          'account_id': 'a-2101',
          'code': '2101',
          'name': 'الموردون',
          'amount': 17000,
        },
      ],
      'equity': [
        {
          'account_id': 'a-3101',
          'code': '3101',
          'name': 'رأس المال',
          'amount': 70000,
        },
      ],
      'assets_total': 94000,
      'liabilities_total': 17000,
      'equity_total': 77000,
      'net_income_ytd': 7000,
      'check': 0,
    });
  }
}

/// Guards the redesigned reminders settings screen against runtime layout
/// exceptions, and proves the save / send-all / log feed flows end to end.
class _FakeReminderRepository implements ReminderRepository {
  @override
  Future<ReminderSettings> loadSettings() async =>
      const ReminderSettings(tenantId: 't1');

  @override
  Future<void> updateSettings(ReminderSettings settings) async {}

  @override
  Future<int> sendToAll() async => 2;

  @override
  Future<void> sendReminderNow(String customerId) async {}

  @override
  Future<List<ReminderLogEntry>> reminderLog({int limit = 50}) async => [
    ReminderLogEntry.fromJson({
      'id': 'r1',
      'customer_id': 'c1',
      'customers': {'name': 'عميل تجريبي'},
      'amount': 5500,
      'phone': '0599111222',
      'message': 'عميل تجريبي يرجى سداد 55 شيكل',
      'status': 'sent',
      'created_at': '2026-09-09T09:00:00+00:00',
    }),
    ReminderLogEntry.fromJson({
      'id': 'r2',
      'customer_id': 'c2',
      'customers': {'name': 'عميل ثان'},
      'amount': 12000,
      'phone': '0599122333',
      'message': 'عميل ثان يرجى سداد 120 شيكل',
      'status': 'failed',
      'created_at': '2026-09-08T09:00:00+00:00',
    }),
  ];
}

class _FakeCustomerRepository implements CustomerRepository {
  @override
  Future<List<Customer>> listAll({String? search}) async => const [
    Customer(id: 'c1', name: 'عميل تجريبي', phone: '0599111222'),
  ];

  @override
  Future<Customer?> getById(String id) async => null;

  @override
  Future<Customer> create(CustomerDraft draft) async =>
      Customer(id: 'new-c', name: draft.name, phone: draft.phone);

  @override
  Future<void> update({
    required String id,
    required CustomerDraft draft,
  }) async {}

  @override
  Future<void> delete(String id) async {}
}
