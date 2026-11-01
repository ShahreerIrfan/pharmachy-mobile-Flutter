import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/security/mobile_tenant_deletion_client.dart';

void main() {
  group('ADR-0074: Flutter Mobile Tenant Deletion Client Tests', () {
    test('Role RBAC: Pharmacy Owner and SuperAdmin can request deletion; Cashier blocked', () {
      expect(MobileTenantDeletionClient.canRoleRequestDeletion('PHARMACY_OWNER'), isTrue);
      expect(MobileTenantDeletionClient.canRoleRequestDeletion('OWNER'), isTrue);
      expect(MobileTenantDeletionClient.canRoleRequestDeletion('SUPERADMIN'), isTrue);
      expect(MobileTenantDeletionClient.canRoleRequestDeletion('PLATFORM_OPERATOR'), isTrue);

      expect(MobileTenantDeletionClient.canRoleRequestDeletion('BRANCH_MANAGER'), isFalse);
      expect(MobileTenantDeletionClient.canRoleRequestDeletion('STAFF_PHARMACIST'), isFalse);
      expect(MobileTenantDeletionClient.canRoleRequestDeletion('CASHIER'), isFalse);
      expect(MobileTenantDeletionClient.canRoleRequestDeletion(null), isFalse);
    });

    test('Role RBAC: Only SuperAdmin and Platform Operator can assess holds and execute purges', () {
      expect(MobileTenantDeletionClient.canRoleAssessOrPurge('SUPERADMIN'), isTrue);
      expect(MobileTenantDeletionClient.canRoleAssessOrPurge('SUPER_ADMIN'), isTrue);
      expect(MobileTenantDeletionClient.canRoleAssessOrPurge('PLATFORM_OPERATOR'), isTrue);

      expect(MobileTenantDeletionClient.canRoleAssessOrPurge('PHARMACY_OWNER'), isFalse);
      expect(MobileTenantDeletionClient.canRoleAssessOrPurge('BRANCH_MANAGER'), isFalse);
      expect(MobileTenantDeletionClient.canRoleAssessOrPurge('CASHIER'), isFalse);
      expect(MobileTenantDeletionClient.canRoleAssessOrPurge(null), isFalse);
    });

    test('Request ID validation: Must match tdr- prefix and 8-64 alphanumeric chars', () {
      expect(MobileTenantDeletionClient.isValidRequestId('tdr-a1b2c3d4e5f6'), isTrue);
      expect(MobileTenantDeletionClient.isValidRequestId('tdr-tenant_close_2026'), isTrue);

      expect(MobileTenantDeletionClient.isValidRequestId('no-prefix-id'), isFalse);
      expect(MobileTenantDeletionClient.isValidRequestId('tdr-short'), isFalse);
      expect(MobileTenantDeletionClient.isValidRequestId('tdr-invalid with spaces'), isFalse);
      expect(MobileTenantDeletionClient.isValidRequestId(null), isFalse);
    });

    test('Guardrail: Physical purge is strictly blocked if active holds exist', () {
      expect(MobileTenantDeletionClient.isPhysicalPurgeBlocked(true), isTrue);
      expect(MobileTenantDeletionClient.isPhysicalPurgeBlocked(false), isFalse);
    });

    test('Confirmation text validation: Must equal CONFIRM_PERMANENT_DELETION', () {
      expect(MobileTenantDeletionClient.isConfirmationTextValid('CONFIRM_PERMANENT_DELETION'), isTrue);
      expect(MobileTenantDeletionClient.isConfirmationTextValid('confirm_permanent_deletion'), isTrue);
      expect(MobileTenantDeletionClient.isConfirmationTextValid('  CONFIRM_PERMANENT_DELETION  '), isTrue);

      expect(MobileTenantDeletionClient.isConfirmationTextValid('YES_DELETE'), isFalse);
      expect(MobileTenantDeletionClient.isConfirmationTextValid(''), isFalse);
      expect(MobileTenantDeletionClient.isConfirmationTextValid(null), isFalse);
    });

    test('Lifecycle state machine transitions', () {
      expect(MobileTenantDeletionClient.canTransition('SUBMITTED', 'HOLD_ACTIVE'), isTrue);
      expect(MobileTenantDeletionClient.canTransition('SUBMITTED', 'ELIGIBLE_FOR_PURGE'), isTrue);
      expect(MobileTenantDeletionClient.canTransition('SUBMITTED', 'CANCELLED'), isTrue);
      expect(MobileTenantDeletionClient.canTransition('HOLD_ACTIVE', 'REJECTED'), isTrue);
      expect(MobileTenantDeletionClient.canTransition('ELIGIBLE_FOR_PURGE', 'CONFIRMED'), isTrue);
      expect(MobileTenantDeletionClient.canTransition('CONFIRMED', 'PURGED'), isTrue);

      expect(MobileTenantDeletionClient.canTransition('HOLD_ACTIVE', 'CONFIRMED'), isFalse);
      expect(MobileTenantDeletionClient.canTransition('SUBMITTED', 'PURGED'), isFalse);
      expect(MobileTenantDeletionClient.canTransition('PURGED', 'SUBMITTED'), isFalse);
      expect(MobileTenantDeletionClient.canTransition(null, 'HOLD_ACTIVE'), isFalse);
    });

    test('Builds endpoint URLs correctly with validation', () {
      expect(MobileTenantDeletionClient.buildTenantDeletionListUrl(), equals('/api/v2/tenants/deletion-requests/'));
      expect(
        MobileTenantDeletionClient.buildTenantDeletionDetailUrl('tdr-12345678'),
        equals('/api/v2/tenants/deletion-requests/tdr-12345678/'),
      );
      expect(
        MobileTenantDeletionClient.buildTenantCancelUrl('tdr-12345678'),
        equals('/api/v2/tenants/deletion-requests/tdr-12345678/cancel/'),
      );

      expect(
        MobileTenantDeletionClient.buildPlatformAssessmentListUrl(),
        equals('/api/v2/platform/deletion-assessments/'),
      );
      expect(
        MobileTenantDeletionClient.buildPlatformAssessUrl('tdr-12345678'),
        equals('/api/v2/platform/deletion-assessments/tdr-12345678/assess/'),
      );
      expect(
        MobileTenantDeletionClient.buildPlatformRejectUrl('tdr-12345678'),
        equals('/api/v2/platform/deletion-assessments/tdr-12345678/reject/'),
      );
      expect(
        MobileTenantDeletionClient.buildPlatformPurgeUrl('tdr-12345678'),
        equals('/api/v2/platform/deletion-assessments/tdr-12345678/purge/'),
      );

      expect(() => MobileTenantDeletionClient.buildTenantDeletionDetailUrl('invalid-id'), throwsArgumentError);
    });
  });
}
