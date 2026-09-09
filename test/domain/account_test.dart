import 'package:flutter_test/flutter_test.dart';
import 'package:hasad_erp/domain/accounts/account.dart';
import 'package:hasad_erp/domain/accounts/account_draft.dart';

void main() {
  const accountId = '11111111-1111-4111-8111-111111111111';

  group('AccountType', () {
    test('maps API values and labels', () {
      expect(AccountType.from('asset'), AccountType.asset);
      expect(AccountType.from('liability'), AccountType.liability);
      expect(AccountType.from('equity'), AccountType.equity);
      expect(AccountType.from('revenue'), AccountType.revenue);
      expect(AccountType.from('expense'), AccountType.expense);
      expect(AccountType.from('whatever'), AccountType.asset);

      expect(AccountType.expense.label, 'مصاريف');
      expect(AccountType.revenue.label, 'إيرادات');
      expect(AccountType.expense.apiValue, 'expense');
    });
  });

  group('Account', () {
    test('fromJson parses a full account row', () {
      final account = Account.fromJson({
        'account_id': accountId,
        'code': '5228',
        'name': 'مصاريف عامة',
        'type': 'expense',
        'parent_id': null,
        'parent_code': null,
        'balance': -7200,
      });

      expect(account.id, accountId);
      expect(account.code, '5228');
      expect(account.name, 'مصاريف عامة');
      expect(account.type, AccountType.expense);
      expect(account.parentCode, isNull);
      expect(account.balance, -7200);
    });

    test('fromJson parses parent + missing balance as zero', () {
      final account = Account.fromJson({
        'account_id': accountId,
        'code': '1101',
        'name': 'الصندوق',
        'type': 'asset',
        'parent_id': null,
        'parent_code': '1100',
      });

      expect(account.parentCode, '1100');
      expect(account.balance, 0);
    });
  });

  group('AccountDraft', () {
    test('toJson maps to create_account params', () {
      final json = const AccountDraft(
        code: '5301',
        name: 'إيجار',
        type: AccountType.expense,
        parentCode: '5300',
      ).toJson();

      expect(json['p_code'], '5301');
      expect(json['p_name'], 'إيجار');
      expect(json['p_type'], 'expense');
      expect(json['p_parent_code'], '5300');
    });

    test('toJson omits parent when empty', () {
      final json = const AccountDraft(
        code: '5301',
        name: 'إيجار',
        type: AccountType.expense,
      ).toJson();

      expect(json.containsKey('p_parent_code'), isFalse);
    });
  });
}