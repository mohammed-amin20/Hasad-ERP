import 'app_role.dart';
import 'tenant_ref.dart';

/// Pure decision logic for the pre-0023 legacy fallback: given a `users`
/// row's tenant stamp fields, decide whether a usable [TenantRef] can be
/// synthesized (so an orphaned account is usable until migration 0024
/// backfills `user_tenants`).
///
/// Pure on purpose — unit-testable without a live Supabase client.
/// The tenant display *name* is filled in by the caller (needs a DB read).
TenantRef? tenantRefFromStamp({
  required String? currentTenantId,
  required String? legacyTenantId,
  required String? roleDbValue,
}) {
  final tenantId = currentTenantId ?? legacyTenantId;
  if (tenantId == null) return null;
  final role = AppRole.fromDb(roleDbValue);
  if (!role.isKnown) return null;
  return TenantRef(id: tenantId, name: '', role: role);
}