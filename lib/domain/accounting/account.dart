import 'package:equatable/equatable.dart';

class Account extends Equatable {
  const Account({
    required this.id,
    required this.code,
    required this.name,
    required this.type,
    this.parentCode,
    this.balance = 0,
  });

  final String id;
  final String code;
  final String name;
  final AccountType type;
  final String? parentCode;
  final int balance;

  @override
  List<Object?> get props => [id, code, name, type, parentCode, balance];

  Map<String, dynamic> toJson() => {
    'id': id,
    'code': code,
    'name': name,
    'type': type.name,
    'parent_code': parentCode,
    'balance': balance,
  };

  factory Account.fromJson(Map<String, dynamic> json) => Account(
    id: json['id'] as String,
    code: json['code'] as String,
    name: json['name'] as String,
    type: AccountType.values.byName(json['type'] as String),
    parentCode: json['parent_code'] as String?,
    balance: json['balance'] as int? ?? 0,
  );
}

enum AccountType {
  asset,
  liability,
  equity,
  revenue,
  expense;
}