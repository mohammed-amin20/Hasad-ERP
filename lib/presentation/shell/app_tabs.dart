import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../domain/auth/app_role.dart';
import '../../domain/auth/app_user.dart';
import '../screens/accounts/chart_of_accounts_screen.dart';
import '../screens/customers/customers_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/debts/debts_screen.dart';
import '../screens/employees/employees_screen.dart';
import '../screens/expenses/expenses_screen.dart';
import '../screens/inventory/inventory_screen.dart';
import '../screens/journal/journal_screen.dart';
import '../screens/ledger/ledger_screen.dart';
import '../screens/products/products_screen.dart';
import '../screens/purchases/purchase_invoices_screen.dart';
import '../screens/salaries/salaries_screen.dart';
import '../screens/sales/sale_invoices_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/suppliers/suppliers_screen.dart';
import '../screens/statements/financial_statements_screen.dart';
import '../screens/trial_balance/trial_balance_screen.dart';

const Set<AppRole> _all = {AppRole.admin, AppRole.accountant, AppRole.sales};
const Set<AppRole> _adminAccountant = {AppRole.admin, AppRole.accountant};
const Set<AppRole> _admin = {AppRole.admin};

/// A destination in the app navigation (stable global index = screens index).
class AppTab {
  const AppTab({
    required this.title,
    required this.icon,
    required this.roles,
    this.iconColor,
  });

  final String title;
  final FaIconData icon;

  /// Optional accent color for the nav icon when inactive (e.g. debts).
  final Color? iconColor;
  final Set<AppRole> roles;

  bool allowedFor(AppUser user) =>
      !user.hasTenant || roles.contains(user.role);
}

const List<AppTab> appTabs = [
  AppTab(
    title: 'لوحة التحكم',
    icon: FontAwesomeIcons.chartPie,
    roles: _all,
  ),
  AppTab(
    title: 'المبيعات',
    icon: FontAwesomeIcons.cashRegister,
    roles: _all,
  ),
  AppTab(
    title: 'المشتريات',
    icon: FontAwesomeIcons.truck,
    roles: _adminAccountant,
  ),
  AppTab(
    title: 'العملاء',
    icon: FontAwesomeIcons.userGroup,
    roles: _all,
  ),
  AppTab(
    title: 'الموردون',
    icon: FontAwesomeIcons.warehouse,
    roles: _adminAccountant,
  ),
  AppTab(
    title: 'المنتجات',
    icon: FontAwesomeIcons.boxesStacked,
    roles: _all,
  ),
  AppTab(
    title: 'المخزون',
    icon: FontAwesomeIcons.clipboardList,
    roles: _adminAccountant,
  ),
  AppTab(
    title: 'المصاريف',
    icon: FontAwesomeIcons.receipt,
    roles: _adminAccountant,
  ),
  AppTab(
    title: 'الموظفون',
    icon: FontAwesomeIcons.userTie,
    roles: _adminAccountant,
  ),
  AppTab(
    title: 'الرواتب',
    icon: FontAwesomeIcons.userGear,
    roles: _adminAccountant,
  ),
  AppTab(
    title: 'الذمم والاستحقاقات',
    icon: FontAwesomeIcons.handHoldingDollar,
    iconColor: AppColors.warning,
    roles: _adminAccountant,
  ),
  AppTab(
    title: 'دليل الحسابات',
    icon: FontAwesomeIcons.sitemap,
    roles: _adminAccountant,
  ),
  AppTab(
    title: 'قيد اليومية',
    icon: FontAwesomeIcons.book,
    roles: _adminAccountant,
  ),
  AppTab(
    title: 'الأستاذ العام',
    icon: FontAwesomeIcons.bookOpen,
    roles: _adminAccountant,
  ),
  AppTab(
    title: 'ميزان المراجعة',
    icon: FontAwesomeIcons.scaleBalanced,
    roles: _adminAccountant,
  ),
  AppTab(
    title: 'القوائم المالية',
    icon: FontAwesomeIcons.chartBar,
    roles: _adminAccountant,
  ),
  AppTab(
    title: 'الإعدادات',
    icon: FontAwesomeIcons.gear,
    roles: _admin,
  ),
];

/// Category groups mirroring the HTML sidebar. Each entry is
/// (category title, ordered indices into [appTabs]). Dashboard (index 0) is
/// rendered as a standalone item above the groups, like the reference UI.
const List<({String title, List<int> indices})> sidebarCategories = [
  (title: 'المبيعات والعملاء', indices: [1, 3]),
  (title: 'المشتريات والموردين', indices: [2, 4]),
  (title: 'المخزون والجرد', indices: [5, 6]),
  (title: 'المحاسبة الأساسية', indices: [11, 12, 13, 14]),
  (title: 'المالية والإدارة', indices: [7, 8, 9, 10, 15, 16]),
];

/// Screens for each tab — index order matches [appTabs].
final List<Widget> appScreens = const <Widget>[
  DashboardScreen(),
  SaleInvoicesScreen(),
  PurchaseInvoicesScreen(),
  CustomersScreen(),
  SuppliersScreen(),
  ProductsScreen(),
  InventoryScreen(),
  ExpensesScreen(),
  EmployeesScreen(),
  SalariesScreen(),
  DebtsScreen(),
  ChartOfAccountsScreen(),
  JournalScreen(),
  LedgerScreen(),
  TrialBalanceScreen(),
  FinancialStatementsScreen(),
  SettingsScreen(),
];