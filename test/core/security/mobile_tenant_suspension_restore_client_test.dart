import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/security/mobile_tenant_suspension_restore_client.dart';

void main() {
  group('ADR-0067: Mobile Platform Super Admin Tenant Suspension & Restore Tests', () {
    test('Role privilege separation: Only Super Admin and Platform Operator can manage lifecycle', () {
      expect(MobileTenantSuspensionRestoreClient.canManageLifecycle('SUPERADMIN'), isTrue);
      expect(MobileTenantSuspensionRestoreClient.canManageLifecycle('SUPER_ADMIN'), isTrue);
      expect(MobileTenantSuspensionRestoreClient.canManageLifecycle('PLATFORM_OPERATOR'), isTrue);

      // Store roles must be strictly denied
      expect(MobileTenantSuspensionRestoreClient.canManageLifecycle('PHARMACY_OWNER'), isFalse);
      expect(MobileTenantSuspensionRestoreClient.canManageLifecycle('BRANCH_MANAGER'), isFalse);
      expect(MobileTenantSuspensionRestoreClient.canManageLifecycle('STAFF_PHARMACIST'), isFalse);
      expect(MobileTenantSuspensionRestoreClient.canManageLifecycle('CASHIER'), isFalse);
      expect(MobileTenantSuspensionRestoreClient.canManageLifecycle(null), isFalse);

      // Never visible in store manager app
      expect(MobileTenantSuspensionRestoreClient.isLifecycleManagementVisibleInStoreApp(), isFalse);
    });

    test('Validates suspension request and rejects invalid parameters', () {
      // Valid
      expect(
        () => MobileTenantSuspensionRestoreClient.validateSuspensionRequest(
          tenantId: 'tenant-dhaka-1',
          reason: 'Regulatory compliance investigation by DGDA',
          reasonCode: 'COMPLIANCE_BREACH',
        ),
        returnsNormally,
      );

      // Reason too short
      expect(
        () => MobileTenantSuspensionRestoreClient.validateSuspensionRequest(
          tenantId: 'tenant-dhaka-1',
          reason: 'bad',
          reasonCode: 'NON_PAYMENT',
        ),
        throwsArgumentError,
      );

      // Empty tenant ID
      expect(
        () => MobileTenantSuspensionRestoreClient.validateSuspensionRequest(
          tenantId: '',
          reason: 'Valid reason here',
        ),
        throwsArgumentError,
      );

      // Invalid reason code
      expect(
        () => MobileTenantSuspensionRestoreClient.validateSuspensionRequest(
          tenantId: 'tenant-1',
          reason: 'Valid reason here',
          reasonCode: 'UNKNOWN_CODE',
        ),
        throwsArgumentError,
      );
    });

    test('Validates restoration request and rejects short reason', () {
      expect(
        () => MobileTenantSuspensionRestoreClient.validateRestorationRequest(
          tenantId: 'tenant-dhaka-1',
          reason: 'Audit resolved and payment cleared',
        ),
        returnsNormally,
      );

      expect(
        () => MobileTenantSuspensionRestoreClient.validateRestorationRequest(
          tenantId: 'tenant-dhaka-1',
          reason: 'ok',
        ),
        throwsArgumentError,
      );
    });

    test('Client lease evaluation reflects lifecycle status', () {
      expect(MobileTenantSuspensionRestoreClient.evaluateClientLease('ACTIVE'), MobileClientLeaseStatus.active);
      expect(MobileTenantSuspensionRestoreClient.evaluateClientLease('TRIAL'), MobileClientLeaseStatus.active);
      expect(MobileTenantSuspensionRestoreClient.evaluateClientLease('PAST_DUE'), MobileClientLeaseStatus.active);
      expect(MobileTenantSuspensionRestoreClient.evaluateClientLease('SUSPENDED'), MobileClientLeaseStatus.suspended);
      expect(MobileTenantSuspensionRestoreClient.evaluateClientLease('ARCHIVED'), MobileClientLeaseStatus.revoked);
      expect(MobileTenantSuspensionRestoreClient.evaluateClientLease(null), MobileClientLeaseStatus.revoked);
    });

    test('Pending sync policy: Pre-suspension drained safely, post-suspension rejected', () {
      final now = DateTime.now();
      final preSuspension = now.subtract(const Duration(minutes: 15));
      final postSuspension = now.add(const Duration(minutes: 15));

      // Active tenant allows sync
      expect(
        MobileTenantSuspensionRestoreClient.evaluatePendingSyncPolicy(
          tenantStatus: 'ACTIVE',
          transactionTime: postSuspension,
          suspendedAt: now,
        ),
        MobilePendingSyncPolicy.allowSync,
      );

      // Suspended tenant: Pre-suspension is DRAINED to protect financial integrity (Zero Data Loss)
      expect(
        MobileTenantSuspensionRestoreClient.evaluatePendingSyncPolicy(
          tenantStatus: 'SUSPENDED',
          transactionTime: preSuspension,
          suspendedAt: now,
        ),
        MobilePendingSyncPolicy.drainPreSuspension,
      );

      // Suspended tenant: Post-suspension is REJECTED
      expect(
        MobileTenantSuspensionRestoreClient.evaluatePendingSyncPolicy(
          tenantStatus: 'SUSPENDED',
          transactionTime: postSuspension,
          suspendedAt: now,
        ),
        MobilePendingSyncPolicy.rejectPostSuspension,
      );
    });

    test('Builds correct REST endpoint paths', () {
      expect(
        MobileTenantSuspensionRestoreClient.buildSuspendUrl('t-123'),
        '/api/v2/platform/console/tenants/t-123/suspend/',
      );
      expect(
        MobileTenantSuspensionRestoreClient.buildRestoreUrl('t-123'),
        '/api/v2/platform/console/tenants/t-123/restore/',
      );
    });
  });
}
