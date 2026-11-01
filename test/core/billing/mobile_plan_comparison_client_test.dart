import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/billing/mobile_plan_comparison_client.dart';

void main() {
  group('P083 - Mobile Plan Comparison Client Tests', () {
    test('Canonical comparison plans define Basic, Standard, and Pro with pricing and annual savings', () {
      final plans = MobilePlanComparisonClient.getCanonicalComparisonPlans();
      expect(plans.length, equals(3));

      final basic = plans[0];
      expect(basic.planCode, equals('PLAN_BASIC'));
      expect(basic.tier, equals('BASIC'));
      expect(basic.monthlyPriceBdt, equals(1500.0));
      expect(basic.annualPriceBdt, equals(15000.0));
      expect(basic.effectiveMonthlyBdt, equals(1250.0));
      expect(basic.annualSavingsBdt, equals(3000.0));
      expect(basic.savingsPercentage, equals('16.67%'));
      expect(basic.maxBranches, equals(1));

      final standard = plans[1];
      expect(standard.planCode, equals('PLAN_STANDARD'));
      expect(standard.tier, equals('STANDARD'));
      expect(standard.monthlyPriceBdt, equals(3500.0));
      expect(standard.annualPriceBdt, equals(35000.0));
      expect(standard.effectiveMonthlyBdt, equals(2916.67));
      expect(standard.annualSavingsBdt, equals(7000.0));
      expect(standard.savingsPercentage, equals('16.67%'));
      expect(standard.maxBranches, equals(3));

      final pro = plans[2];
      expect(pro.planCode, equals('PLAN_PRO'));
      expect(pro.tier, equals('PRO'));
      expect(pro.monthlyPriceBdt, equals(7500.0));
      expect(pro.annualPriceBdt, equals(75000.0));
      expect(pro.effectiveMonthlyBdt, equals(6250.0));
      expect(pro.annualSavingsBdt, equals(15000.0));
      expect(pro.savingsPercentage, equals('16.67%'));
      expect(pro.maxBranches, equals(50));
    });

    test('INV-SAFETY-01: Universal clinical safety guarantees are non-gated across all plans', () {
      final guarantees = MobilePlanComparisonClient.getClinicalSafetyGuarantees();
      expect(guarantees.length, equals(5));

      for (final g in guarantees) {
        expect(g.guaranteed, isTrue);
        expect(MobilePlanComparisonClient.isClinicallyGuaranteed(g.key), isTrue);
      }

      expect(MobilePlanComparisonClient.isClinicallyGuaranteed('CONSOLIDATED_REPORTING'), isFalse);
      expect(MobilePlanComparisonClient.isClinicallyGuaranteed('PURCHASE_ORDERS'), isFalse);
    });

    test('Quote calculation properly discounts annual billing and preserves renewal periods', () {
      const tenantId = 't-mobile-p083';

      // Annual Quote for Standard Plan
      final annualQuote = MobilePlanComparisonClient.calculateQuote(
        tenantId: tenantId,
        planCode: 'PLAN_STANDARD',
        billingCycle: 'ANNUAL',
        activeBranches: 1,
        activeStaff: 3,
      );
      expect(annualQuote.subtotalBdt, equals(42000.0));
      expect(annualQuote.discountBdt, equals(7000.0));
      expect(annualQuote.totalBdt, equals(35000.0));
      expect(annualQuote.effectiveMonthlyBdt, equals(2916.67));
      expect(annualQuote.savingsPercentage, equals('16.67%'));
      expect(annualQuote.renewalPeriodDays, equals(365));
      expect(annualQuote.safetyFeaturesGuaranteed, isTrue);
      expect(annualQuote.isCompliant, isTrue);

      // Monthly Quote for Standard Plan
      final monthlyQuote = MobilePlanComparisonClient.calculateQuote(
        tenantId: tenantId,
        planCode: 'PLAN_STANDARD',
        billingCycle: 'MONTHLY',
        activeBranches: 1,
        activeStaff: 3,
      );
      expect(monthlyQuote.subtotalBdt, equals(3500.0));
      expect(monthlyQuote.discountBdt, equals(0.0));
      expect(monthlyQuote.totalBdt, equals(3500.0));
      expect(monthlyQuote.effectiveMonthlyBdt, equals(3500.0));
      expect(monthlyQuote.savingsPercentage, equals('0.00%'));
      expect(monthlyQuote.renewalPeriodDays, equals(30));
      expect(monthlyQuote.safetyFeaturesGuaranteed, isTrue);
      expect(monthlyQuote.isCompliant, isTrue);
    });

    test('Quote validation checks invalid arguments and quota compliance boundaries', () {
      const tenantId = 't-mobile-p083';

      // Invalid inputs
      expect(
        () => MobilePlanComparisonClient.calculateQuote(
          tenantId: '',
          planCode: 'PLAN_BASIC',
          billingCycle: 'MONTHLY',
        ),
        throwsArgumentError,
      );
      expect(
        () => MobilePlanComparisonClient.calculateQuote(
          tenantId: tenantId,
          planCode: 'INVALID_CODE',
          billingCycle: 'MONTHLY',
        ),
        throwsArgumentError,
      );
      expect(
        () => MobilePlanComparisonClient.calculateQuote(
          tenantId: tenantId,
          planCode: 'PLAN_BASIC',
          billingCycle: 'BIANNUAL',
        ),
        throwsArgumentError,
      );

      // Downgrade to Basic with 2 active branches -> violation
      final overQuotaQuote = MobilePlanComparisonClient.calculateQuote(
        tenantId: tenantId,
        planCode: 'PLAN_BASIC',
        billingCycle: 'MONTHLY',
        activeBranches: 2,
        activeStaff: 2,
      );
      expect(overQuotaQuote.isCompliant, isFalse);
      expect(overQuotaQuote.violations.length, equals(1));
      expect(overQuotaQuote.violations[0], contains('exceed plan limit'));
    });
  });
}
