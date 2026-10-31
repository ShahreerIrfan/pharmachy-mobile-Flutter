import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/security/mobile_tenant_detail_timeline_client.dart';

void main() {
  group('ADR-0066: Mobile Platform Super Admin Tenant Detail & Timeline Tests', () {
    test('authorizes only Super Admin roles for tenant detail and timeline', () {
      expect(MobileTenantDetailTimelineClient.isTenantDetailAllowed('SUPERADMIN'), isTrue);
      expect(MobileTenantDetailTimelineClient.isTenantDetailAllowed('SUPER_ADMIN'), isTrue);
      expect(MobileTenantDetailTimelineClient.isTenantDetailAllowed('PLATFORM_OPERATOR'), isTrue);

      expect(MobileTenantDetailTimelineClient.isTenantDetailAllowed('TENANT_OWNER'), isFalse);
      expect(MobileTenantDetailTimelineClient.isTenantDetailAllowed('BRANCH_MANAGER'), isFalse);
      expect(MobileTenantDetailTimelineClient.isTenantDetailAllowed('PHARMACIST'), isFalse);
      expect(MobileTenantDetailTimelineClient.isTenantDetailAllowed('CASHIER'), isFalse);
      expect(MobileTenantDetailTimelineClient.isTenantDetailAllowed(null), isFalse);
    });

    test('tenant detail view is never rendered inside mobile manager app', () {
      expect(MobileTenantDetailTimelineClient.shouldDisplayTenantDetailInMobileApp(), isFalse);
    });

    test('detects and forbids patient clinical data from tenant detail payload', () {
      final cleanDetail = {
        'tenant_id': 'tenant-alpha',
        'name': 'Alpha Care Pharmacy',
        'status': 'ACTIVE',
      };
      expect(MobileTenantDetailTimelineClient.containsPatientClinicalData(cleanDetail), isFalse);

      final contaminatedPatient = {
        'tenant_id': 'tenant-alpha',
        'patient_name': 'Jannat Ara',
      };
      expect(MobileTenantDetailTimelineClient.containsPatientClinicalData(contaminatedPatient), isTrue);

      final contaminatedPrescription = {
        'tenant_id': 'tenant-alpha',
        'prescriptions': ['RX-10023'],
      };
      expect(MobileTenantDetailTimelineClient.containsPatientClinicalData(contaminatedPrescription), isTrue);
    });

    test('builds tenant detail URL with validation and role gating', () {
      final url = MobileTenantDetailTimelineClient.buildTenantDetailUrl(
        'SUPERADMIN',
        'tenant-alpha',
      );
      expect(url, '/api/v2/platform/console/tenants/tenant-alpha/detail/');

      expect(
        () => MobileTenantDetailTimelineClient.buildTenantDetailUrl('TENANT_OWNER', 'tenant-alpha'),
        throwsA(isA<PlatformTenantDetailDeniedException>()),
      );
      expect(
        () => MobileTenantDetailTimelineClient.buildTenantDetailUrl('SUPERADMIN', 'ab'),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => MobileTenantDetailTimelineClient.buildTenantDetailUrl('SUPERADMIN', 'invalid tenant!'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('validates timeline entry structure', () {
      final validEntry = {
        'action': 'TENANT_PROVISIONED',
        'status': 'SUCCESS',
        'timestamp': '2026-10-31T12:00:00Z',
      };
      expect(MobileTenantDetailTimelineClient.isValidTimelineEntry(validEntry), isTrue);

      final invalidEntry = {
        'action': 'TENANT_PROVISIONED',
      };
      expect(MobileTenantDetailTimelineClient.isValidTimelineEntry(invalidEntry), isFalse);
    });

    test('resolves timeline status tone correctly', () {
      expect(MobileTenantDetailTimelineClient.resolveTimelineStatusTone('SUCCESS'), 'success');
      expect(MobileTenantDetailTimelineClient.resolveTimelineStatusTone('COMPLETED'), 'success');
      expect(MobileTenantDetailTimelineClient.resolveTimelineStatusTone('WARNING'), 'warning');
      expect(MobileTenantDetailTimelineClient.resolveTimelineStatusTone('FAILED'), 'danger');
      expect(MobileTenantDetailTimelineClient.resolveTimelineStatusTone('UNKNOWN'), 'neutral');
    });
  });
}

