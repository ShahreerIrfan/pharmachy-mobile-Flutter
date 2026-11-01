import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/security/mobile_tenant_data_export_client.dart';

void main() {
  group('ADR-0073: Flutter Mobile Tenant Data Export Client Tests', () {
    test(
        'Role RBAC: Pharmacy Owner and SuperAdmin can request; Cashier blocked',
        () {
      expect(
          MobileTenantDataExportClient.canRoleRequestExport('PHARMACY_OWNER'),
          isTrue);
      expect(
          MobileTenantDataExportClient.canRoleRequestExport('OWNER'), isTrue);
      expect(MobileTenantDataExportClient.canRoleRequestExport('SUPERADMIN'),
          isTrue);
      expect(
          MobileTenantDataExportClient.canRoleRequestExport(
              'PLATFORM_OPERATOR'),
          isTrue);

      expect(
          MobileTenantDataExportClient.canRoleRequestExport('BRANCH_MANAGER'),
          isFalse);
      expect(
          MobileTenantDataExportClient.canRoleRequestExport('STAFF_PHARMACIST'),
          isFalse);
      expect(MobileTenantDataExportClient.canRoleRequestExport('CASHIER'),
          isFalse);
      expect(MobileTenantDataExportClient.canRoleRequestExport(null), isFalse);
    });

    test(
        'Role RBAC: Only SuperAdmin and Platform Operator can approve/reject exports',
        () {
      expect(MobileTenantDataExportClient.canRoleApproveExport('SUPERADMIN'),
          isTrue);
      expect(MobileTenantDataExportClient.canRoleApproveExport('SUPER_ADMIN'),
          isTrue);
      expect(
          MobileTenantDataExportClient.canRoleApproveExport(
              'PLATFORM_OPERATOR'),
          isTrue);

      expect(
          MobileTenantDataExportClient.canRoleApproveExport('PHARMACY_OWNER'),
          isFalse);
      expect(
          MobileTenantDataExportClient.canRoleApproveExport('BRANCH_MANAGER'),
          isFalse);
      expect(MobileTenantDataExportClient.canRoleApproveExport('CASHIER'),
          isFalse);
      expect(MobileTenantDataExportClient.canRoleApproveExport(null), isFalse);
    });

    test(
        'Export ID validation: Must match tde- prefix and 8-64 alphanumeric chars',
        () {
      expect(MobileTenantDataExportClient.isValidExportId('tde-a1b2c3d4e5f6'),
          isTrue);
      expect(
          MobileTenantDataExportClient.isValidExportId(
              'tde-tenant_archive_2026'),
          isTrue);

      expect(MobileTenantDataExportClient.isValidExportId('no-prefix-id'),
          isFalse);
      expect(
          MobileTenantDataExportClient.isValidExportId('tde-short'), isFalse);
      expect(
          MobileTenantDataExportClient.isValidExportId(
              'tde-invalid with spaces'),
          isFalse);
      expect(MobileTenantDataExportClient.isValidExportId(null), isFalse);
    });

    test('Format validation: Only JSON and CSV supported', () {
      expect(MobileTenantDataExportClient.isValidFormat('JSON'), isTrue);
      expect(MobileTenantDataExportClient.isValidFormat('json'), isTrue);
      expect(MobileTenantDataExportClient.isValidFormat('CSV'), isTrue);

      expect(MobileTenantDataExportClient.isValidFormat('XML'), isFalse);
      expect(MobileTenantDataExportClient.isValidFormat(null), isFalse);
    });

    test('Lifecycle state machine transitions', () {
      expect(
          MobileTenantDataExportClient.canTransition('REQUESTED', 'APPROVED'),
          isTrue);
      expect(
          MobileTenantDataExportClient.canTransition('REQUESTED', 'REJECTED'),
          isTrue);
      expect(
          MobileTenantDataExportClient.canTransition('APPROVED', 'PROCESSING'),
          isTrue);
      expect(
          MobileTenantDataExportClient.canTransition('PROCESSING', 'COMPLETED'),
          isTrue);
      expect(MobileTenantDataExportClient.canTransition('COMPLETED', 'EXPIRED'),
          isTrue);

      expect(
          MobileTenantDataExportClient.canTransition('REQUESTED', 'COMPLETED'),
          isFalse);
      expect(MobileTenantDataExportClient.canTransition('REJECTED', 'APPROVED'),
          isFalse);
      expect(MobileTenantDataExportClient.canTransition('EXPIRED', 'REQUESTED'),
          isFalse);
      expect(MobileTenantDataExportClient.canTransition(null, 'APPROVED'),
          isFalse);
    });

    test('Builds endpoint URLs correctly with validation', () {
      expect(MobileTenantDataExportClient.buildTenantExportListUrl(),
          equals('/api/v2/tenants/data-exports/'));
      expect(
        MobileTenantDataExportClient.buildTenantExportDetailUrl('tde-12345678'),
        equals('/api/v2/tenants/data-exports/tde-12345678/'),
      );
      expect(
        MobileTenantDataExportClient.buildDownloadUrl(
            'tde-12345678', 'sec-tok-123'),
        equals(
            '/api/v2/tenants/data-exports/tde-12345678/download/?token=sec-tok-123'),
      );

      expect(MobileTenantDataExportClient.buildPlatformExportListUrl(),
          equals('/api/v2/platform/data-exports/'));
      expect(
        MobileTenantDataExportClient.buildPlatformApproveUrl('tde-12345678'),
        equals('/api/v2/platform/data-exports/tde-12345678/approve/'),
      );
      expect(
        MobileTenantDataExportClient.buildPlatformRejectUrl('tde-12345678'),
        equals('/api/v2/platform/data-exports/tde-12345678/reject/'),
      );
      expect(
        MobileTenantDataExportClient.buildPlatformRevokeUrl('tde-12345678'),
        equals('/api/v2/platform/data-exports/tde-12345678/revoke/'),
      );

      expect(
          () => MobileTenantDataExportClient.buildTenantExportDetailUrl(
              'invalid-id'),
          throwsArgumentError);
      expect(
          () =>
              MobileTenantDataExportClient.buildDownloadUrl('tde-12345678', ''),
          throwsArgumentError);
    });
  });
}
