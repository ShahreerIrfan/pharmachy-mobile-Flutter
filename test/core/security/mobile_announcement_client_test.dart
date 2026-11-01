import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/security/mobile_announcement_client.dart';

void main() {
  group('ADR-0076: Flutter Mobile System Announcements Client Tests', () {
    test('Role RBAC: Only SuperAdmin and Platform Operator can manage platform announcements', () {
      expect(MobileAnnouncementClient.canRoleManageAnnouncements('SUPERADMIN'), isTrue);
      expect(MobileAnnouncementClient.canRoleManageAnnouncements('SUPER_ADMIN'), isTrue);
      expect(MobileAnnouncementClient.canRoleManageAnnouncements('PLATFORM_OPERATOR'), isTrue);

      expect(MobileAnnouncementClient.canRoleManageAnnouncements('PHARMACY_OWNER'), isFalse);
      expect(MobileAnnouncementClient.canRoleManageAnnouncements('BRANCH_MANAGER'), isFalse);
      expect(MobileAnnouncementClient.canRoleManageAnnouncements('CASHIER'), isFalse);
      expect(MobileAnnouncementClient.canRoleManageAnnouncements(null), isFalse);
    });

    test('Role RBAC: Authenticated store staff can acknowledge announcements', () {
      expect(MobileAnnouncementClient.canRoleAcknowledge('PHARMACY_OWNER'), isTrue);
      expect(MobileAnnouncementClient.canRoleAcknowledge('BRANCH_MANAGER'), isTrue);
      expect(MobileAnnouncementClient.canRoleAcknowledge('CASHIER'), isTrue);
      expect(MobileAnnouncementClient.canRoleAcknowledge('STAFF_PHARMACIST'), isTrue);

      expect(MobileAnnouncementClient.canRoleAcknowledge(null), isFalse);
      expect(MobileAnnouncementClient.canRoleAcknowledge('   '), isFalse);
    });

    test('Announcement ID syntax: Must match ann- prefix and 8-64 alphanumeric chars', () {
      expect(MobileAnnouncementClient.isValidAnnouncementId('ann-a1b2c3d4e5f6'), isTrue);
      expect(MobileAnnouncementClient.isValidAnnouncementId('ann-scheduled-maint-01'), isTrue);

      expect(MobileAnnouncementClient.isValidAnnouncementId('invalid-prefix-12345'), isFalse);
      expect(MobileAnnouncementClient.isValidAnnouncementId('ann-short'), isFalse);
      expect(MobileAnnouncementClient.isValidAnnouncementId(null), isFalse);
    });

    test('Priority and Target Type validation', () {
      expect(MobileAnnouncementClient.isValidPriority('INFO'), isTrue);
      expect(MobileAnnouncementClient.isValidPriority('WARNING'), isTrue);
      expect(MobileAnnouncementClient.isValidPriority('CRITICAL'), isTrue);
      expect(MobileAnnouncementClient.isValidPriority('MAINTENANCE'), isTrue);
      expect(MobileAnnouncementClient.isValidPriority('UNKNOWN'), isFalse);

      expect(MobileAnnouncementClient.isValidTargetType('ALL'), isTrue);
      expect(MobileAnnouncementClient.isValidTargetType('TENANT_LIST'), isTrue);
      expect(MobileAnnouncementClient.isValidTargetType('ROLE_LIST'), isTrue);
      expect(MobileAnnouncementClient.isValidTargetType('BRANCH_LIST'), isTrue);
      expect(MobileAnnouncementClient.isValidTargetType('DEVICE_LIST'), isFalse);
    });

    test('Lifecycle State Machine: Strict transitions for announcements', () {
      expect(MobileAnnouncementClient.isValidStateTransition('DRAFT', 'PUBLISHED'), isTrue);
      expect(MobileAnnouncementClient.isValidStateTransition('DRAFT', 'ARCHIVED'), isTrue);
      expect(MobileAnnouncementClient.isValidStateTransition('PUBLISHED', 'ARCHIVED'), isTrue);

      expect(MobileAnnouncementClient.isValidStateTransition('ARCHIVED', 'PUBLISHED'), isFalse);
      expect(MobileAnnouncementClient.isValidStateTransition('ARCHIVED', 'DRAFT'), isFalse);
    });

    test('URL Builders: Platform and Tenant URLs accurately formatted', () {
      final listUrl = MobileAnnouncementClient.buildPlatformAnnouncementsUrl('https://api.pharmacy.bd');
      expect(listUrl, equals('https://api.pharmacy.bd/api/v2/platform/announcements/'));

      final detailUrl = MobileAnnouncementClient.buildPlatformAnnouncementsUrl('https://api.pharmacy.bd', 'ann-a1b2c3d4e5f6');
      expect(detailUrl, equals('https://api.pharmacy.bd/api/v2/platform/announcements/ann-a1b2c3d4e5f6/'));

      final tenantFeed = MobileAnnouncementClient.buildTenantAnnouncementsUrl('https://api.pharmacy.bd');
      expect(tenantFeed, equals('https://api.pharmacy.bd/api/v2/tenants/announcements/'));

      final ackUrl = MobileAnnouncementClient.buildAcknowledgeUrl('https://api.pharmacy.bd', 'ann-a1b2c3d4e5f6');
      expect(ackUrl, equals('https://api.pharmacy.bd/api/v2/tenants/announcements/ann-a1b2c3d4e5f6/acknowledge/'));
    });
  });
}
