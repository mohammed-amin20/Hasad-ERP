import 'app_role.dart';

/// Authenticated session user as seen by the UI (never imports Supabase).
class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.role,
    this.tenantId,
    this.name,
  });

  final String id;
  final String email;

  /// Tenant the user belongs to (`users.tenant_id`). Null when not onboarded.
  final String? tenantId;
  final String? name;
  final AppRole role;

  bool get hasTenant => tenantId != null && role.isKnown;
  bool get isAdmin => role == AppRole.admin;
  bool get isAccountant => role == AppRole.accountant;
  bool get isSales => role == AppRole.sales;
}