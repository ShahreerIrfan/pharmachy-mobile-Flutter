import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/security/mobile_support_access_governance_client.dart';

void main() {
  group('ADR-0068: Mobile Support Access Governance & Impersonation Prevention Tests', () {
    test('direct user impersonation is strictly barred by architecture', () {
      expect(MobileSupportAccessGovernanceClient.isDirectUserImpersonationPermitted(), isFalse);
    });

    test('clinical dispensing is completely forbidden for all support scopes', () {
      expect(MobileSupportAccessGovernanceClient.isClinicalDispensingPermitted('DIAGNOSTIC_READ'), isFalse);
      expect(MobileSupportAccessGovernanceClient.isClinicalDispensingPermitted('BILLING_READ'), isFalse);
      expect(MobileSupportAccessGovernanceClient.isClinicalDispensingPermitted('BREAK_GLASS_REPAIR'), isFalse);
      expect(MobileSupportAccessGovernanceClient.isClinicalDispensingPermitted(null), isFalse);
    });

    test('authorizes only pharmacy owner and superadmin to approve requests', () {
      expect(MobileSupportAccessGovernanceClient.canApproveSupportRequests('PHARMACY_OWNER'), isTrue);
      expect(MobileSupportAccessGovernanceClient.canApproveSupportRequests('SUPERADMIN'), isTrue);
      expect(MobileSupportAccessGovernanceClient.canApproveSupportRequests('SUPER_ADMIN'), isTrue);

      expect(MobileSupportAccessGovernanceClient.canApproveSupportRequests('BRANCH_MANAGER'), isFalse);
      expect(MobileSupportAccessGovernanceClient.canApproveSupportRequests('STAFF_PHARMACIST'), isFalse);
      expect(MobileSupportAccessGovernanceClient.canApproveSupportRequests('CASHIER'), isFalse);
      expect(MobileSupportAccessGovernanceClient.canApproveSupportRequests(null), isFalse);
    });

    test('validates authorized support scopes accurately', () {
      expect(MobileSupportAccessGovernanceClient.isValidScope('DIAGNOSTIC_READ'), isTrue);
      expect(MobileSupportAccessGovernanceClient.isValidScope('BILLING_READ'), isTrue);
      expect(MobileSupportAccessGovernanceClient.isValidScope('BREAK_GLASS_REPAIR'), isTrue);
      expect(MobileSupportAccessGovernanceClient.isValidScope('FULL_ADMIN'), isFalse);
      expect(MobileSupportAccessGovernanceClient.isValidScope(null), isFalse);
    });

    test('builds active notice, approve, reject and revoke URLs with validation', () {
      expect(
        MobileSupportAccessGovernanceClient.buildActiveNoticeUrl('tenant-alpha'),
        '/api/v2/tenants/support-access/tenant-alpha/active/',
      );
      expect(
        MobileSupportAccessGovernanceClient.buildApproveUrl('tenant-alpha', 'sup-1001'),
        '/api/v2/tenants/support-access/tenant-alpha/sup-1001/approve/',
      );
      expect(
        MobileSupportAccessGovernanceClient.buildRejectUrl('tenant-alpha', 'sup-1001'),
        '/api/v2/tenants/support-access/tenant-alpha/sup-1001/reject/',
      );
      expect(
        MobileSupportAccessGovernanceClient.buildRevokeUrl('tenant-alpha', 'sup-1001'),
        '/api/v2/tenants/support-access/tenant-alpha/sup-1001/revoke/',
      );

      expect(
        () => MobileSupportAccessGovernanceClient.buildActiveNoticeUrl('bad id!'),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => MobileSupportAccessGovernanceClient.buildApproveUrl('tenant-alpha', 'bad id!'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('resolves notice banner tone and formats duration correctly', () {
      expect(MobileSupportAccessGovernanceClient.resolveBannerTone('warning'), 'warning');
      expect(MobileSupportAccessGovernanceClient.resolveBannerTone('danger'), 'danger');
      expect(MobileSupportAccessGovernanceClient.resolveBannerTone('unknown'), 'neutral');
      expect(MobileSupportAccessGovernanceClient.resolveBannerTone(null), 'neutral');

      expect(MobileSupportAccessGovernanceClient.formatRemainingDuration(1500), '25m');
      expect(MobileSupportAccessGovernanceClient.formatRemainingDuration(4500), '1h 15m');
      expect(MobileSupportAccessGovernanceClient.formatRemainingDuration(7200), '2h');
      expect(MobileSupportAccessGovernanceClient.formatRemainingDuration(0), '0m');
    });
  });
}
