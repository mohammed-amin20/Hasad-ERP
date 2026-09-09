import 'package:flutter_test/flutter_test.dart';
import 'package:hasad_erp/domain/accounts/account.dart';
import 'package:hasad_erp/domain/reports/balance_sheet.dart';
import 'package:hasad_erp/domain/reports/income_statement.dart';
import 'package:hasad_erp/domain/reports/ledger.dart';
import 'package:hasad_erp/domain/reports/trial_balance.dart';

void main() {
  const cashId = '11111111-1111-4111-8111-111111111111';
  const revenueId = '22222222-2222-4222-8222-222222222222';
  const rentId = '33333333-3333-4333-8333-333333333333';

  group('LedgerStatement', () {
    test('fromJson parses envelope with lines and running balances', () {
      final statement = LedgerStatement.fromJson({
        'account_id': cashId,
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

      expect(statement.accountId, cashId);
      expect(statement.code, '1101');
      expect(statement.type, AccountType.asset);
      expect(statement.opening, 5000);
      expect(statement.closing, 6000);
      expect(statement.lines.length, 2);
      expect(statement.lines.first.memo, 'فاتورة 1');
      expect(statement.lines.first.balance, 7000);
      expect(statement.totalDebit, 2000);
      expect(statement.totalCredit, 1000);
    });

    test('fromJson tolerates an empty lines array and zero totals', () {
      final statement = LedgerStatement.fromJson({
        'account_id': cashId,
        'code': '1201',
        'name': 'البنك',
        'type': 'asset',
        'from': '2026-09-01',
        'to': '2026-09-30',
        'opening': 0,
        'lines': [],
        'closing': 0,
      });

      expect(statement.lines, isEmpty);
      expect(statement.totalDebit, 0);
    });
  });

  group('TrialBalanceReport', () {
    test('fromJson parses rows, totals and balanced flag', () {
      final report = TrialBalanceReport.fromJson({
        'as_of': '2026-09-30',
        'accounts': [
          {
            'account_id': cashId,
            'code': '1101',
            'name': 'النقدية',
            'type': 'asset',
            'debit': 50000,
            'credit': 0,
            'balance': 50000,
          },
          {
            'account_id': revenueId,
            'code': '4101',
            'name': 'إيرادات المبيعات',
            'type': 'revenue',
            'debit': 0,
            'credit': 50000,
            'balance': -50000,
          },
        ],
        'totals': {'debit': 50000, 'credit': 50000},
      });

      expect(report.asOf, DateTime(2026, 9, 30));
      expect(report.rows.length, 2);
      expect(report.rows.last.name, 'إيرادات المبيعات');
      expect(report.rows.last.balance, -50000);
      expect(report.totalDebit, 50000);
      expect(report.totalCredit, 50000);
      expect(report.balanced, isTrue);
    });

    test('balanced is false when totals differ', () {
      final report = TrialBalanceReport.fromJson({
        'as_of': '2026-09-30',
        'accounts': [],
        'totals': {'debit': 100, 'credit': 90},
      });
      expect(report.balanced, isFalse);
    });
  });

  group('IncomeStatement', () {
    test('fromJson parses revenue/expense sides and net', () {
      final statement = IncomeStatement.fromJson({
        'from': '2026-09-01',
        'to': '2026-09-30',
        'revenues': [
          {'account_id': revenueId, 'code': '4101', 'name': 'إيرادات المبيعات', 'amount': 10000},
        ],
        'expenses': [
          {'account_id': rentId, 'code': '5301', 'name': 'الإيجار', 'amount': 3000},
        ],
        'revenue_total': 10000,
        'expense_total': 3000,
        'net': 7000,
      });

      expect(statement.revenues.first.name, 'إيرادات المبيعات');
      expect(statement.expenses.first.amount, 3000);
      expect(statement.net, 7000);
    });
  });

  group('BalanceSheet', () {
    test('fromJson parses sections and balanced check', () {
      final sheet = BalanceSheet.fromJson({
        'as_of': '2026-09-30',
        'assets': [
          {'account_id': cashId, 'code': '1101', 'name': 'النقدية', 'amount': 60000},
          {'account_id': cashId, 'code': '1201', 'name': 'البنك', 'amount': 34000},
        ],
        'liabilities': [
          {'account_id': cashId, 'code': '2101', 'name': 'الموردون', 'amount': 17000},
        ],
        'equity': [
          {'account_id': cashId, 'code': '3101', 'name': 'رأس المال', 'amount': 70000},
        ],
        'assets_total': 94000,
        'liabilities_total': 17000,
        'equity_total': 77000,
        'net_income_ytd': 7000,
        'check': 0,
      });

      expect(sheet.assets.length, 2);
      expect(sheet.equityTotal, 77000);
      expect(sheet.netIncomeYtd, 7000);
      expect(sheet.check, 0);
      expect(sheet.balanced, isTrue);
    });
  });
}