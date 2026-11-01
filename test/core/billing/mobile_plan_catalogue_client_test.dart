import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/billing/mobile_plan_catalogue_client.dart';

void main() {
  group('P081 - Mobile Plan Catalogue Client Tests', () {
    test('INV-SAFETY-01: Clinical safety features are never gated across any plan', () {
      final plans = ['BASIC', 'STANDARD', 'PRO', null, 'UNKNOWN'];
      final clinicalFeatures = [
        'ANTIBIOTIC_REGISTER',
        'BATCH_EXPIRY_BLOCK',
        'RECALL_QUARANTINE',
        'BANNED_DRUG_RESTRICTION',
        'RX_VERIFICATION',
      ];

      for (final plan in plans) {
        for (final feature in clinicalFeatures) {
          expect(
            MobilePlanCatalogueClient.isFeatureEntitled(plan, feature),
            isTrue,
            reason: 'Feature $feature must be enabled on plan $plan',
          );
        }
      }
    });

    test('Commercial features properly gated between Standard and Pro', () {
      expect(MobilePlanCatalogueClient.isFeatureEntitled('BASIC', 'CONSOLIDATED_REPORTING'), isFalse);
      expect(MobilePlanCatalogueClient.isFeatureEntitled('STANDARD', 'CONSOLIDATED_REPORTING'), isFalse);
      expect(MobilePlanCatalogueClient.isFeatureEntitled('PRO', 'CONSOLIDATED_REPORTING'), isTrue);

      expect(MobilePlanCatalogueClient.isFeatureEntitled('BASIC', 'PURCHASE_ORDERS'), isFalse);
      expect(MobilePlanCatalogueClient.isFeatureEntitled('STANDARD', 'PURCHASE_ORDERS'), isTrue);
      expect(MobilePlanCatalogueClient.isFeatureEntitled('PRO', 'PURCHASE_ORDERS'), isTrue);
    });

    test('Plan specifications and pricing adhere to ADR-0015 & ADR-0081', () {
      final basic = MobilePlanCatalogueClient.getPlanSpecifications('BASIC');
      expect(basic['monthlyPriceBdt'], equals('1500.00'));
      expect(basic['annualPriceBdt'], equals('15000.00'));
      expect(basic['maxBranches'], equals(1));

      final standard = MobilePlanCatalogueClient.getPlanSpecifications('STANDARD');
      expect(standard['monthlyPriceBdt'], equals('3500.00'));
      expect(standard['annualPriceBdt'], equals('35000.00'));
      expect(standard['maxBranches'], equals(3));

      final pro = MobilePlanCatalogueClient.getPlanSpecifications('PRO');
      expect(pro['monthlyPriceBdt'], equals('7500.00'));
      expect(pro['annualPriceBdt'], equals('75000.00'));
      expect(pro['maxBranches'], equals(50));
    });

    test('Endpoint resolution properly constructs catalogue routes', () {
      expect(MobilePlanCatalogueClient.resolveEndpoint('list'), equals('/api/v2/billing/plans/'));
      expect(
        MobilePlanCatalogueClient.resolveEndpoint('retrieve', 'PLAN_BASIC'),
        equals('/api/v2/billing/plans/PLAN_BASIC/'),
      );
      expect(
        MobilePlanCatalogueClient.resolveEndpoint('entitlement', 'tn-dhaka-1'),
        equals('/api/v2/billing/entitlements/tn-dhaka-1/'),
      );
      expect(
        MobilePlanCatalogueClient.resolveEndpoint('apply', 'tn-dhaka-1'),
        equals('/api/v2/billing/entitlements/tn-dhaka-1/apply/'),
      );
    });

    test('Validation rejects unsupported plan codes or billing cycles', () {
      expect(
        () => MobilePlanCatalogueClient.validateApplyRequest('PLAN_STANDARD', 'MONTHLY'),
        returnsNormally,
      );
      expect(
        () => MobilePlanCatalogueClient.validateApplyRequest('PLAN_PRO', 'ANNUAL'),
        returnsNormally,
      );

      expect(
        () => MobilePlanCatalogueClient.validateApplyRequest('PLAN_INVALID', 'MONTHLY'),
        throwsArgumentError,
      );
      expect(
        () => MobilePlanCatalogueClient.validateApplyRequest('PLAN_BASIC', 'BI_ANNUAL'),
        throwsArgumentError,
      );
      expect(
        () => MobilePlanCatalogueClient.validateApplyRequest(null, 'MONTHLY'),
        throwsArgumentError,
      );
    });
  });
}
