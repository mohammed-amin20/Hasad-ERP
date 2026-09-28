import 'app_role.dart';
import 'tenant_ref.dart';

/// Authenticated session user as seen by the UI (never imports Supabase).
class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.role,
    this.tenantId,
    this.name,
    this.tenants = const [],
  });

  final String id;
  final String email;

  /// Tenant the user belongs to (`users.tenant_id`). Null when not onboarded.
  final String? tenantId;
  final String? name;
  final AppRole role;
  final List<TenantRef> tenants;

  bool get hasTenant => tenantId != null && role.isKnown;
  bool get isAdmin => role == AppRole.admin;
  bool get isAccountant => role == AppRole.accountant;
  bool get isSales => role == AppRole.sales;

  /// Current tenant from the tenants list.
  TenantRef? get currentTenant {
    if (tenantId == null) return null;
    try {
      return tenants.firstWhere((t) => t.id == tenantId);
    } catch (_) {
      return null;
    }
  }

  /// Rebuilds a user from its cached JSON form (see [toJson]).
  ///
  /// Every field is read defensively because the payload comes from a local
  /// database that may predate a schema change: a missing or malformed
  /// [role] degrades to [AppRole.unknown] rather than throwing, so a stale
  /// cache can still put the user back into the app (offline cold start)
  /// instead of crashing the boot path.
  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as String? ?? '',
        email: json['email'] as String? ?? '',
        role: AppRole.fromDb(json['role'] as String?),
        tenantId: json['tenant_id'] as String?,
        name: json['name'] as String?,
        tenants: [
          for (final t in (json['tenants'] as List? ?? const []))
            if (t is Map) TenantRef.fromJson(t.cast<String, dynamic>()),
        ],
      );

  /// Serializes for the offline profile cache.
  ///
  /// [role] is stored as [AppRole.dbValue] and [tenants] via [TenantRef.toJson]
  /// so the round-trip is lossless. `null` tenant/name are omitted rather than
  /// written as null, keeping the payload minimal for the un-onboarded case.
  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'role': role.dbValue,
        if (tenantId != null) 'tenant_id': tenantId,
        if (name != null) 'name': name,
        if (tenants.isNotEmpty)
          'tenants': [for (final t in tenants) t.toJson()],
      };
}
