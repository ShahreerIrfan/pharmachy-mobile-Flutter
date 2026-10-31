import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/security/mobile_super_admin_kpi_cards_client.dart';

void main() {
  group('ADR-0064: Mobile Platform Super Admin KPI Cards Client Tests', () {
    test('authorizes only Super Admin roles for platform KPI cards', () {
      expect(MobileSuperAdminKpiCardsClient.isPlatformKpiAllowed('SUPERADMIN'), isTrue);
      expect(MobileSuperAdminKpiCardsClient.isPlatformKpiAllowed('SUPER_ADMIN'), isTrue);
      expect(MobileSuperAdminKpiCardsClient.isPlatformKpiAllowed('PLATFORM_OPERATOR'), isTrue);

      expect(MobileSuperAdminKpiCardsClient.isPlatformKpiAllowed('TENANT_OWNER'), isFalse);
      expect(MobileSuperAdminKpiCardsClient.isPlatformKpiAllowed('BRANCH_MANAGER'), isFalse);
      expect(MobileSuperAdminKpiCardsClient.isPlatformKpiAllowed('CASHIER'), isFalse);
      expect(MobileSuperAdminKpiCardsClient.isPlatformKpiAllowed(null), isFalse);
    });

    test('platform KPI cards are never displayed inside tenant mobile owner app', () {
      expect(MobileSuperAdminKpiCardsClient.shouldDisplayKpiCardsInMobileOwnerApp(), isFalse);
    });

    test('builds KPI endpoint URL for Super Admin and throws for Tenant Owner', () {
      expect(
        MobileSuperAdminKpiCardsClient.buildKpiEndpointUrl('SUPERADMIN'),
        '/api/v2/platform/console/kpis/?currency=BDT&period=current',
      );
      expect(
        MobileSuperAdminKpiCardsClient.buildKpiEndpointUrl('SUPERADMIN', currency: 'bdt', period: '30d'),
        '/api/v2/platform/console/kpis/?currency=BDT&period=30d',
      );

      expect(
        () => MobileSuperAdminKpiCardsClient.buildKpiEndpointUrl('TENANT_OWNER'),
        throwsA(isA<PlatformKpiAccessDeniedException>()),
      );
      expect(
        () => MobileSuperAdminKpiCardsClient.buildKpiEndpointUrl('SUPERADMIN', currency: 'USD'),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => MobileSuperAdminKpiCardsClient.buildKpiEndpointUrl('SUPERADMIN', period: 'invalid_period'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('formats BDT currency correctly and throws on invalid amount', () {
      expect(MobileSuperAdminKpiCardsClient.formatBdt('125000.00'), '৳ 125000.00');
      expect(MobileSuperAdminKpiCardsClient.formatBdt('500.5'), '৳ 500.50');
      expect(MobileSuperAdminKpiCardsClient.formatBdt(null), '৳ 0.00');

      expect(
        () => MobileSuperAdminKpiCardsClient.formatBdt('invalid-number'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
