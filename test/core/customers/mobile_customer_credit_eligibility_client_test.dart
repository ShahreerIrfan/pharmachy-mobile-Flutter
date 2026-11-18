import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/customers/mobile_customer_credit_eligibility_client.dart';

void main() {
  group('P264: MobileCustomerCreditEligibilityClient Tests', () {
    test('Identifies policy configuration admin roles', () {
      expect(MobileCustomerCreditEligibilityClient.canConfigurePolicy('PHARMACY_OWNER'), isTrue);
      expect(MobileCustomerCreditEligibilityClient.canConfigurePolicy('BRANCH_MANAGER'), isTrue);
      expect(MobileCustomerCreditEligibilityClient.canConfigurePolicy('FINANCE_OFFICER'), isTrue);
      expect(MobileCustomerCreditEligibilityClient.canConfigurePolicy('CASHIER'), isFalse);
      expect(MobileCustomerCreditEligibilityClient.canConfigurePolicy('STAFF_PHARMACIST'), isFalse);
    });

    test('Validates approved customer credit status strictly', () {
      expect(
        MobileCustomerCreditEligibilityClient.isCustomerCreditApproved(
          creditStatus: 'APPROVED',
          isCreditApproved: true,
        ),
        isTrue,
      );
      expect(
        MobileCustomerCreditEligibilityClient.isCustomerCreditApproved(
          creditStatus: 'SUSPENDED',
          isCreditApproved: true,
        ),
        isFalse,
      );
      expect(
        MobileCustomerCreditEligibilityClient.isCustomerCreditApproved(
          creditStatus: 'APPROVED',
          isCreditApproved: false,
        ),
        isFalse,
      );
    });

    test('Evaluates eligibility correctly for valid customer within limits', () {
      final res = MobileCustomerCreditEligibilityClient.evaluateEligibility(
        isApproved: true,
        creditStatus: 'APPROVED',
        currentDue: 500.0,
        additionalDue: 200.0,
        creditLimit: 2000.0,
        branchExposure: 10000.0,
        branchCeiling: 50000.0,
        hasOverdueDues: false,
      );

      expect(res['is_eligible'], isTrue);
      expect((res['rejections'] as List).isEmpty, isTrue);
      expect(res['projected_due'], equals(700.0));
    });

    test('Enforces hard controls for overdue dues, limit exceed and narcotics', () {
      final resOverdue = MobileCustomerCreditEligibilityClient.evaluateEligibility(
        isApproved: true,
        creditStatus: 'APPROVED',
        currentDue: 500.0,
        additionalDue: 200.0,
        creditLimit: 2000.0,
        branchExposure: 10000.0,
        branchCeiling: 50000.0,
        hasOverdueDues: true,
      );
      expect(resOverdue['is_eligible'], isFalse);
      expect(resOverdue['rejections'], contains('ERR_CUSTOMER_HAS_OVERDUE_DUES'));

      final resNarcotics = MobileCustomerCreditEligibilityClient.evaluateEligibility(
        isApproved: true,
        creditStatus: 'APPROVED',
        currentDue: 500.0,
        additionalDue: 200.0,
        creditLimit: 2000.0,
        branchExposure: 10000.0,
        branchCeiling: 50000.0,
        hasOverdueDues: false,
        hasNarcotics: true,
        allowNarcoticsCredit: false,
      );
      expect(resNarcotics['is_eligible'], isFalse);
      expect(resNarcotics['rejections'], contains('ERR_RESTRICTED_MEDICINE_CREDIT_FORBIDDEN'));
    });
  });
}
