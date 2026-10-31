import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/security/mobile_tenant_lifecycle_service.dart';

void main() {
  group('ADR-0061: Mobile Tenant Lifecycle Service Tests', () {
    test('ACTIVE and TRIAL tenants allow operations', () {
      final active = MobileTenantLifecycleService.evaluateTenantStatus('ACTIVE');
      expect(active.isCheckoutPermitted, isTrue);
      expect(active.isGracePeriodWarning, isFalse);

      final trial = MobileTenantLifecycleService.evaluateTenantStatus('TRIAL');
      expect(trial.isCheckoutPermitted, isTrue);
      expect(trial.isGracePeriodWarning, isFalse);
    });

    test('PAST_DUE tenant triggers grace period warning', () {
      final pastDue = MobileTenantLifecycleService.evaluateTenantStatus('PAST_DUE');
      expect(pastDue.isCheckoutPermitted, isTrue);
      expect(pastDue.isGracePeriodWarning, isTrue);
      expect(pastDue.messageBn.contains('গ্রেস পিরিয়ড'), isTrue);
    });

    test('SUSPENDED and ARCHIVED tenants disallow checkout', () {
      final suspended = MobileTenantLifecycleService.evaluateTenantStatus('SUSPENDED');
      expect(suspended.isCheckoutPermitted, isFalse);

      final archived = MobileTenantLifecycleService.evaluateTenantStatus('ARCHIVED');
      expect(archived.isCheckoutPermitted, isFalse);
    });

    test('Canonical setting validates allow_negative_stock invariant', () {
      expect(
        MobileTenantLifecycleService.isCanonicalSettingValid({'allow_negative_stock': false}),
        isTrue,
      );
      expect(
        MobileTenantLifecycleService.isCanonicalSettingValid({'allow_negative_stock': true}),
        isFalse,
      );
    });
  });
}
