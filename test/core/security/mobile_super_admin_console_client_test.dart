import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/security/mobile_super_admin_console_client.dart';

void main() {
  group('ADR-0063: Mobile Platform Super Admin Console Client Tests', () {
    test('authorizes only Super Admin roles for platform console', () {
      expect(MobileSuperAdminConsoleClient.isPlatformConsoleAllowed('SUPERADMIN'), isTrue);
      expect(MobileSuperAdminConsoleClient.isPlatformConsoleAllowed('SUPER_ADMIN'), isTrue);
      expect(MobileSuperAdminConsoleClient.isPlatformConsoleAllowed('PLATFORM_OPERATOR'), isTrue);

      expect(MobileSuperAdminConsoleClient.isPlatformConsoleAllowed('TENANT_OWNER'), isFalse);
      expect(MobileSuperAdminConsoleClient.isPlatformConsoleAllowed('BRANCH_MANAGER'), isFalse);
      expect(MobileSuperAdminConsoleClient.isPlatformConsoleAllowed('CASHIER'), isFalse);
      expect(MobileSuperAdminConsoleClient.isPlatformConsoleAllowed(null), isFalse);
    });

    test('platform controls are never visible in tenant owner mobile UI', () {
      expect(MobileSuperAdminConsoleClient.shouldShowPlatformControlsInOwnerUI(), isFalse);
    });

    test('resolves platform endpoints for Super Admin and throws for Tenant Owner', () {
      expect(
        MobileSuperAdminConsoleClient.resolvePlatformEndpoint('SUPERADMIN', 'metrics'),
        '/api/v2/platform/console/metrics/',
      );
      expect(
        MobileSuperAdminConsoleClient.resolvePlatformEndpoint('SUPERADMIN', 'tenants'),
        '/api/v2/platform/console/tenants/',
      );
      expect(
        MobileSuperAdminConsoleClient.resolvePlatformEndpoint('SUPERADMIN', 'inspect', tenantId: 'tenant-demo'),
        '/api/v2/platform/console/tenants/tenant-demo/',
      );

      expect(
        () => MobileSuperAdminConsoleClient.resolvePlatformEndpoint('TENANT_OWNER', 'metrics'),
        throwsA(isA<PlatformAccessDeniedException>()),
      );
    });

    test('validates action requests and rejects invalid actions or short reasons', () {
      expect(
        MobileSuperAdminConsoleClient.validateActionRequest(
          'SUPERADMIN',
          'BROADCAST_ANNOUNCEMENT',
          'Emergency update scheduled',
        ),
        isTrue,
      );

      expect(
        () => MobileSuperAdminConsoleClient.validateActionRequest(
          'SUPERADMIN',
          'INVALID_ACTION',
          'Some valid reason',
        ),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => MobileSuperAdminConsoleClient.validateActionRequest(
          'SUPERADMIN',
          'SET_MAINTENANCE_MODE',
          'tiny',
        ),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => MobileSuperAdminConsoleClient.validateActionRequest(
          'CASHIER',
          'BROADCAST_ANNOUNCEMENT',
          'Valid reason text',
        ),
        throwsA(isA<PlatformAccessDeniedException>()),
      );
    });
  });
}

