import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/security/mobile_tenant_search_filter_client.dart';

void main() {
  group('ADR-0065: Mobile Platform Super Admin Tenant Search & Filter Tests', () {
    test('authorizes only Super Admin roles for platform tenant search', () {
      expect(MobileTenantSearchFilterClient.isTenantSearchAllowed('SUPERADMIN'), isTrue);
      expect(MobileTenantSearchFilterClient.isTenantSearchAllowed('SUPER_ADMIN'), isTrue);
      expect(MobileTenantSearchFilterClient.isTenantSearchAllowed('PLATFORM_OPERATOR'), isTrue);

      expect(MobileTenantSearchFilterClient.isTenantSearchAllowed('TENANT_OWNER'), isFalse);
      expect(MobileTenantSearchFilterClient.isTenantSearchAllowed('BRANCH_MANAGER'), isFalse);
      expect(MobileTenantSearchFilterClient.isTenantSearchAllowed('CASHIER'), isFalse);
      expect(MobileTenantSearchFilterClient.isTenantSearchAllowed(null), isFalse);
    });

    test('tenant search is never rendered inside mobile manager app', () {
      expect(MobileTenantSearchFilterClient.shouldDisplayTenantSearchInMobileApp(), isFalse);
    });

    test('guarantees patient clinical data is detected and prohibited', () {
      final cleanTenant = {
        'tenant_id': 'tenant-demo',
        'name': 'Demo Pharma',
        'status': 'ACTIVE',
      };
      expect(MobileTenantSearchFilterClient.hasPatientData(cleanTenant), isFalse);

      final contaminatedTenant = {
        'tenant_id': 'tenant-demo',
        'patient_name': 'Rahim Uddin',
      };
      expect(MobileTenantSearchFilterClient.hasPatientData(contaminatedTenant), isTrue);
    });

    test('maps lifecycle status to badge color tones accurately', () {
      expect(MobileTenantSearchFilterClient.resolveStatusBadgeTone('ACTIVE'), 'success');
      expect(MobileTenantSearchFilterClient.resolveStatusBadgeTone('TRIAL'), 'warning');
      expect(MobileTenantSearchFilterClient.resolveStatusBadgeTone('SUSPENDED'), 'danger');
      expect(MobileTenantSearchFilterClient.resolveStatusBadgeTone('ARCHIVED'), 'neutral');
    });

    test('builds search query URL with validation and bounds checks', () {
      final url = MobileTenantSearchFilterClient.buildSearchQuery(
        'SUPERADMIN',
        search: 'central',
        status: 'ACTIVE',
        planTier: 'PRO',
        page: 2,
        pageSize: 15,
      );
      expect(
        url,
        '/api/v2/platform/console/tenants/?page=2&page_size=15&search=central&status=ACTIVE&plan_tier=PRO',
      );

      expect(
        () => MobileTenantSearchFilterClient.buildSearchQuery('TENANT_OWNER'),
        throwsA(isA<PlatformTenantSearchDeniedException>()),
      );
      expect(
        () => MobileTenantSearchFilterClient.buildSearchQuery('SUPERADMIN', page: 0),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => MobileTenantSearchFilterClient.buildSearchQuery('SUPERADMIN', pageSize: 120),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => MobileTenantSearchFilterClient.buildSearchQuery('SUPERADMIN', status: 'UNKNOWN_STATUS'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
