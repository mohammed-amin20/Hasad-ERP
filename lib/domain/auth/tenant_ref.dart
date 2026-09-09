import 'app_role.dart';

/// Reference to a tenant the user has access to.
class TenantRef {
  const TenantRef({
    required this.id,
    required this.name,
    required this.role,
  });

  final String id;
  final String name;
  final AppRole role;

  factory TenantRef.fromJson(Map<String, dynamic> json) => TenantRef(
        id: json['id'] as String,
        name: json['name'] as String,
        role: AppRole.fromDb(json['role'] as String?),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'role': role.dbValue,
      };
}