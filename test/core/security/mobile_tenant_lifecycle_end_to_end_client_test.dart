import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/security/mobile_tenant_lifecycle_end_to_end_client.dart';

void main() {
  group('MobileTenantLifecycleEndToEndClient Tests (ADR-0080)', () {
    test('Should permit checkout only during TRIAL or ACTIVE states', () {
      expect(MobileTenantLifecycleEndToEndClient.isCheckoutAllowed('TRIAL'), isTrue);
      expect(MobileTenantLifecycleEndToEndClient.isCheckoutAllowed('ACTIVE'), isTrue);

      expect(MobileTenantLifecycleEndToEndClient.isCheckoutAllowed('SUSPENDED'), isFalse);
      expect(MobileTenantLifecycleEndToEndClient.isCheckoutAllowed('PAST_DUE'), isFalse);
      expect(MobileTenantLifecycleEndToEndClient.isCheckoutAllowed('ARCHIVED'), isFalse);
      expect(MobileTenantLifecycleEndToEndClient.isCheckoutAllowed(null), isFalse);
    });

    test('Should authorize Super Admin and Platform Operator roles only', () {
      expect(MobileTenantLifecycleEndToEndClient.isPlatformLifecycleAdmin('SUPERADMIN'), isTrue);
      expect(MobileTenantLifecycleEndToEndClient.isPlatformLifecycleAdmin('SUPER_ADMIN'), isTrue);
      expect(MobileTenantLifecycleEndToEndClient.isPlatformLifecycleAdmin('PLATFORM_OPERATOR'), isTrue);

      expect(MobileTenantLifecycleEndToEndClient.isPlatformLifecycleAdmin('PHARMACY_OWNER'), isFalse);
      expect(MobileTenantLifecycleEndToEndClient.isPlatformLifecycleAdmin('CASHIER'), isFalse);
      expect(MobileTenantLifecycleEndToEndClient.isPlatformLifecycleAdmin(null), isFalse);
    });

    test('Should resolve plan tier quotas and BDT amounts', () {
      final basic = MobileTenantLifecycleEndToEndClient.getPlanQuotas('BASIC');
      expect(basic['branches'], equals(1));
      expect(basic['devices'], equals(2));
      expect(basic['monthlyAmountBdt'], equals('2500.00'));

      final standard = MobileTenantLifecycleEndToEndClient.getPlanQuotas('STANDARD');
      expect(standard['branches'], equals(5));
      expect(standard['devices'], equals(10));
      expect(standard['monthlyAmountBdt'], equals('6500.00'));

      final pro = MobileTenantLifecycleEndToEndClient.getPlanQuotas('PRO');
      expect(pro['branches'], equals(25));
      expect(pro['devices'], equals(50));
      expect(pro['monthlyAmountBdt'], equals('15000.00'));
    });

    test('Should validate deterministic FSM transitions', () {
      expect(MobileTenantLifecycleEndToEndClient.isValidTransition('PROVISIONING', 'TRIAL'), isTrue);
      expect(MobileTenantLifecycleEndToEndClient.isValidTransition('TRIAL', 'ACTIVE'), isTrue);
      expect(MobileTenantLifecycleEndToEndClient.isValidTransition('ACTIVE', 'SUSPENDED'), isTrue);
      expect(MobileTenantLifecycleEndToEndClient.isValidTransition('SUSPENDED', 'ACTIVE'), isTrue);

      expect(MobileTenantLifecycleEndToEndClient.isValidTransition('PROVISIONING', 'ARCHIVED'), isFalse);
      expect(MobileTenantLifecycleEndToEndClient.isValidTransition('ARCHIVED', 'ACTIVE'), isFalse);
    });

    test('Should resolve API endpoints correctly', () {
      expect(
        MobileTenantLifecycleEndToEndClient.resolveEndpoint('activate-subscription', 't-alpha'),
        equals('/api/v2/tenants/t-alpha/activate-subscription/'),
      );
      expect(
        MobileTenantLifecycleEndToEndClient.resolveEndpoint('change-plan', 't-alpha'),
        equals('/api/v2/tenants/t-alpha/change-plan/'),
      );
      expect(
        MobileTenantLifecycleEndToEndClient.resolveEndpoint('timeline', 't-alpha'),
        equals('/api/v2/tenants/t-alpha/lifecycle-timeline/'),
      );
    });
  });
}
