import 'account.dart';

/// Input payload for `create_account`.
class AccountDraft {
  const AccountDraft({
    required this.code,
    required this.name,
    required this.type,
    this.parentCode,
  });

  final String code;
  final String name;
  final AccountType type;
  final String? parentCode;

  Map<String, dynamic> toJson() => {
        'p_code': code,
        'p_name': name,
        'p_type': type.apiValue,
        if (parentCode != null && parentCode!.isNotEmpty)
          'p_parent_code': parentCode,
      };
}