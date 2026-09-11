/// User role in the app (mirrors the `users.role` check constraint).
enum AppRole {
  admin,
  accountant,
  sales,

  /// Signed-in but not linked to any tenant (no `users` row yet).
  unknown;

  static AppRole fromDb(String? value) => switch (value) {
    'admin' => AppRole.admin,
    'accountant' => AppRole.accountant,
    'sales' => AppRole.sales,
    _ => AppRole.unknown,
  };

  String get dbValue => name;

  bool get isKnown => this != unknown;
}
