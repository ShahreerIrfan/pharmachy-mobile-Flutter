/// mobile/lib/core/customers/mobile_customer_credit_eligibility_client.dart
/// Architecture Decision: ADR-0264 (P264).
/// Phase 14: Customers, Suppliers, Dues & Payments.
///
/// Mobile client helper for Customer Credit Eligibility evaluation & hard controls:
/// - Customer credit status verification.
/// - Overdue aging enforcement.
/// - Branch credit ceiling and customer credit limit checks.
/// - Controlled/narcotics credit restrictions.

class MobileCustomerCreditEligibilityClient {
  static const List<String> policyAdminRoles = [
    'SUPERADMIN',
    'PHARMACY_OWNER',
    'BRANCH_MANAGER',
    'FINANCE_OFFICER',
  ];

  static bool canConfigurePolicy(String? role) {
    if (role == null) return false;
    return policyAdminRoles.contains(role.trim().toUpperCase());
  }

  static bool isCustomerCreditApproved({
    required String? creditStatus,
    required bool isCreditApproved,
  }) {
    if (!isCreditApproved || creditStatus == null) return false;
    return creditStatus.trim().toUpperCase() == 'APPROVED';
  }

  static double calculateProjectedDue(double currentDue, double additionalDue) {
    final sum = currentDue + additionalDue;
    return sum < 0.0 ? 0.0 : sum;
  }

  static bool isWithinCustomerLimit({
    required double currentDue,
    required double additionalDue,
    required double creditLimit,
  }) {
    if (creditLimit <= 0.0) return false;
    return calculateProjectedDue(currentDue, additionalDue) <= creditLimit;
  }

  static bool isWithinBranchCeiling({
    required double branchExposure,
    required double additionalDue,
    required double branchCeiling,
  }) {
    if (branchCeiling <= 0.0) return false;
    return (branchExposure + additionalDue) <= branchCeiling;
  }

  static Map<String, dynamic> evaluateEligibility({
    required bool isApproved,
    required String? creditStatus,
    required double currentDue,
    required double additionalDue,
    required double creditLimit,
    required double branchExposure,
    required double branchCeiling,
    required bool hasOverdueDues,
    bool hasNarcotics = false,
    bool allowNarcoticsCredit = false,
  }) {
    final rejections = <String>[];

    if (!isCustomerCreditApproved(creditStatus: creditStatus, isCreditApproved: isApproved)) {
      rejections.add('ERR_CUSTOMER_CREDIT_NOT_APPROVED');
    }
    if (hasOverdueDues) {
      rejections.add('ERR_CUSTOMER_HAS_OVERDUE_DUES');
    }
    if (!isWithinCustomerLimit(currentDue: currentDue, additionalDue: additionalDue, creditLimit: creditLimit)) {
      rejections.add('ERR_CUSTOMER_CREDIT_LIMIT_EXCEEDED');
    }
    if (!isWithinBranchCeiling(branchExposure: branchExposure, additionalDue: additionalDue, branchCeiling: branchCeiling)) {
      rejections.add('ERR_BRANCH_CREDIT_CEILING_EXCEEDED');
    }
    if (hasNarcotics && !allowNarcoticsCredit) {
      rejections.add('ERR_RESTRICTED_MEDICINE_CREDIT_FORBIDDEN');
    }

    return {
      'is_eligible': rejections.isEmpty,
      'rejections': rejections,
      'projected_due': calculateProjectedDue(currentDue, additionalDue),
    };
  }
}
