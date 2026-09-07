import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/material.dart';

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
  });

  final String title;
  final FaIconData icon;
  final Set<AppRole> roles;

  bool allowedFor(AppUser user) =>
      !user.hasTenant || roles.contains(user.role);
}

const List<AppTab> appTabs = [
  AppTab(
    title: 'لوحة التحكم',
    icon: FontAwesomeIcons.gaugeHigh,
    roles: _all,
  ),
  AppTab(
    title: 'المبيعات',
    icon: FontAwesomeIcons.basketShopping,
    roles: _all,
  ),
  AppTab(
    title: 'المشتريات',
    icon: FontAwesomeIcons.truckFast,
    roles: _adminAccountant,
  ),
  AppTab(
    title: 'العملاء',
    icon: FontAwesomeIcons.users,
    roles: _all,
  ),
  AppTab(
    title: 'الموردون',
    icon: FontAwesomeIcons.warehouse,
    roles: _adminAccountant,
  ),
  AppTab(
    title: 'المنتجات',
    icon: FontAwesomeIcons.box,
    roles: _all,
  ),
  AppTab(
    title: 'المخزون',
    icon: FontAwesomeIcons.boxesStacked,
    roles: _adminAccountant,
  ),
  AppTab(
    title: 'المصاريف',
    icon: FontAwesomeIcons.moneyBillWave,
    roles: _adminAccountant,
  ),
  AppTab(
    title: 'الموظفون',
    icon: FontAwesomeIcons.userTie,
    roles: _admin,
  ),
  AppTab(
    title: 'الرواتب',
    icon: FontAwesomeIcons.handHoldingDollar,
    roles: _admin,
  ),
  AppTab(
    title: 'الذمم والاستحقاقات',
    icon: FontAwesomeIcons.scaleBalanced,
    roles: _adminAccountant,
  ),
  AppTab(
    title: 'دليل الحسابات',
    icon: FontAwesomeIcons.listOl,
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
    icon: FontAwesomeIcons.scaleUnbalanced,
    roles: _adminAccountant,
  ),
  AppTab(
    title: 'القوائم المالية',
    icon: FontAwesomeIcons.chartColumn,
    roles: _adminAccountant,
  ),
  AppTab(
    title: 'الإعدادات',
    icon: FontAwesomeIcons.gear,
    roles: _admin,
  ),
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