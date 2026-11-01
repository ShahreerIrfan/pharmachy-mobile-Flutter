import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/billing/mobile_feature_entitlement_engine_client.dart';

void main() {
  group('P082: Mobile Feature Entitlement Engine Client Tests', () {
    test('Endpoint resolution properly formats query parameters', () {
      expect(
        MobileFeatureEntitlementEngineClient.resolveEndpoint('tn-ctg-01'),
        equals('/api/v2/billing/effective-entitlements/tn-ctg-01/'),
      );
      expect(
        MobileFeatureEntitlementEngineClient.resolveEndpoint(
          'tn-ctg-01',
          deviceId: 'dev-tab-01',
        ),
        equals('/api/v2/billing/effective-entitlements/tn-ctg-01/?device_id=dev-tab-01'),
      );
      expect(
        MobileFeatureEntitlementEngineClient.resolveEndpoint(
          'tn-ctg-01',
          deviceId: 'dev-tab-01',
          branchId: 'br-main',
        ),
        equals(
          '/api/v2/billing/effective-entitlements/tn-ctg-01/?device_id=dev-tab-01&branch_id=br-main',
        ),
      );

      expect(
        () => MobileFeatureEntitlementEngineClient.resolveEndpoint(''),
        throwsArgumentError,
      );
    });

    test('Checkout permission evaluates subscription, capability, and unexpired lease', () {
      final now = DateTime.now().toUtc();
      final futureExpiry = now.add(const Duration(hours: 72));
      final pastExpiry = now.subtract(const Duration(minutes: 5));

      // Active
      expect(
        MobileFeatureEntitlementEngineClient.isCheckoutAllowed(
          isCheckoutAllowedBySubscription: true,
          hasCheckoutCapability: true,
          leaseStatus: 'ACTIVE',
          leaseExpiresAt: futureExpiry,
        ),
        isTrue,
      );

      // Disallowed by subscription (e.g. suspended)
      expect(
        MobileFeatureEntitlementEngineClient.isCheckoutAllowed(
          isCheckoutAllowedBySubscription: false,
          hasCheckoutCapability: true,
          leaseStatus: 'ACTIVE',
          leaseExpiresAt: futureExpiry,
        ),
        isFalse,
      );

      // Expired lease
      expect(
        MobileFeatureEntitlementEngineClient.isCheckoutAllowed(
          isCheckoutAllowedBySubscription: true,
          hasCheckoutCapability: true,
          leaseStatus: 'ACTIVE',
          leaseExpiresAt: pastExpiry,
        ),
        isFalse,
      );

      // Suspended lease status
      expect(
        MobileFeatureEntitlementEngineClient.isCheckoutAllowed(
          isCheckoutAllowedBySubscription: true,
          hasCheckoutCapability: true,
          leaseStatus: 'SUSPENDED',
          leaseExpiresAt: futureExpiry,
        ),
        isFalse,
      );
    });

    test('INV-SAFETY-01: Clinical safety protections active across all conditions', () {
      for (final feature in MobileFeatureEntitlementEngineClient.clinicalSafetyControls) {
        expect(
          MobileFeatureEntitlementEngineClient.isClinicalSafetyActive(feature),
          isTrue,
        );
      }
      expect(
        MobileFeatureEntitlementEngineClient.isClinicalSafetyActive('CONSOLIDATED_REPORTING'),
        isFalse,
      );
    });

    test('Quota exceeded detection properly evaluates used vs max', () {
      expect(MobileFeatureEntitlementEngineClient.isQuotaExceeded(1, 1), isFalse);
      expect(MobileFeatureEntitlementEngineClient.isQuotaExceeded(2, 3), isFalse);
      expect(MobileFeatureEntitlementEngineClient.isQuotaExceeded(4, 3), isTrue);
    });
  });
}
