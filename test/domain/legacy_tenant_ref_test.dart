import 'package:flutter_test/flutter_test.dart';
import 'package:hasad_erp/domain/auth/app_role.dart';
import 'package:hasad_erp/domain/auth/legacy_tenant_ref.dart';

void main() {
  group('tenantRefFromStamp', () {
    const tenantId = 'ef95064e-b867-4b7f-bd98-36748066cc8c';

    test('uses current_tenant_id when present', () {
      final ref = tenantRefFromStamp(
        currentTenantId: tenantId,
        legacyTenantId: 'other-guid',
        roleDbValue: 'admin',
      );
      expect(ref, isNotNull);
      expect(ref!.id, tenantId);
      expect(ref.role, AppRole.admin);
      expect(ref.name, isEmpty);
    });

    test('falls back to tenant_id when current_tenant_id is null', () {
      final ref = tenantRefFromStamp(
        currentTenantId: null,
        legacyTenantId: tenantId,
        roleDbValue: 'sales',
      );
      expect(ref, isNotNull);
      expect(ref!.id, tenantId);
      expect(ref.role, AppRole.sales);
    });

    test('returns null when no stamp at all (unonboarded auth signup)', () {
      expect(
        tenantRefFromStamp(
          currentTenantId: null,
          legacyTenantId: null,
          roleDbValue: 'admin',
        ),
        isNull,
      );
    });

    test('returns null when role is unknown', () {
      expect(
        tenantRefFromStamp(
          currentTenantId: tenantId,
          legacyTenantId: tenantId,
          roleDbValue: 'nonsense',
        ),
        isNull,
      );
    });

    test('returns null when role is null (no users row)', () {
      expect(
        tenantRefFromStamp(
          currentTenantId: tenantId,
          legacyTenantId: tenantId,
          roleDbValue: null,
        ),
        isNull,
      );
    });

    test('maps accountant', () {
      final ref = tenantRefFromStamp(
        currentTenantId: tenantId,
        legacyTenantId: null,
        roleDbValue: 'accountant',
      );
      expect(ref, isNotNull);
      expect(ref!.role, AppRole.accountant);
    });
  });
}