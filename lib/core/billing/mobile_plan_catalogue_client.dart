/// mobile_plan_catalogue_client.dart
///
/// Architecture Decision: ADR-0015 & ADR-0081
/// Phase 05: Basic/Standard/Pro Subscription & Billing (P081)
///
/// Mobile Manager Plan Catalogue & Applied Entitlement Client:
///   - Localized plan catalog specifications (Basic, Standard, Pro) with BDT pricing
///   - Cardinal safety invariant: Clinical features are NEVER gated behind paid tiers (INV-SAFETY-01)
///   - Quota boundaries (branch, device, staff limits)
///   - Endpoint resolution and validation for plan applications
library mobile_plan_catalogue_client;

class MobilePlanCatalogueClient {
  static const Set<String> clinicalSafetyFeatures = {
    'ANTIBIOTIC_REGISTER',
    'BATCH_EXPIRY_BLOCK',
    'RECALL_QUARANTINE',
    'BANNED_DRUG_RESTRICTION',
    'RX_VERIFICATION',
  };

  static const Set<String> validBillingCycles = {
    'MONTHLY',
    'ANNUAL',
  };

  static const Set<String> validPlanCodes = {
    'PLAN_BASIC',
    'PLAN_STANDARD',
    'PLAN_PRO',
  };

  /// Invariant INV-SAFETY-01: Clinical safety features are never gated across all plans.
  static bool isFeatureEntitled(String? planTier, String? featureKey) {
    if (featureKey == null || featureKey.trim().isEmpty) return false;
    final cleanFeature = featureKey.toUpperCase().trim();
    if (clinicalSafetyFeatures.contains(cleanFeature)) {
      return true;
    }

    if (planTier == null) return false;
    final cleanTier = planTier.toUpperCase().trim();

    switch (cleanTier) {
      case 'PRO':
        return true;
      case 'STANDARD':
        return const {
          'OFFLINE_SYNC',
          'THERMAL_RECEIPT_PRINT',
          'MEDICINE_CATALOG',
          'BASIC_INVENTORY',
          'PURCHASE_ORDERS',
          'SUPPLIER_DUES',
          'CUSTOMER_LEDGER',
          'FLUTTER_OWNER_APP',
          'DAILY_BACKUP',
        }.contains(cleanFeature);
      case 'BASIC':
        return const {
          'OFFLINE_SYNC',
          'THERMAL_RECEIPT_PRINT',
          'MEDICINE_CATALOG',
          'BASIC_INVENTORY',
        }.contains(cleanFeature);
      default:
        return false;
    }
  }

  /// Resolves plan tier specifications, pricing in BDT, and quotas.
  static Map<String, dynamic> getPlanSpecifications(String? planTier) {
    final cleanTier = planTier?.toUpperCase().trim() ?? 'BASIC';
    switch (cleanTier) {
      case 'PRO':
        return {
          'tier': 'PRO',
          'nameEn': 'Pro Enterprise Pharmacy',
          'nameBn': 'প্রো এন্টারপ্রাইজ ফার্মেসি',
          'monthlyPriceBdt': '7500.00',
          'annualPriceBdt': '75000.00',
          'maxBranches': 50,
          'maxDevices': 250,
          'maxStaff': 100,
        };
      case 'STANDARD':
        return {
          'tier': 'STANDARD',
          'nameEn': 'Standard Pharmacy',
          'nameBn': 'স্ট্যান্ডার্ড ফার্মেসি',
          'monthlyPriceBdt': '3500.00',
          'annualPriceBdt': '35000.00',
          'maxBranches': 3,
          'maxDevices': 15,
          'maxStaff': 10,
        };
      case 'BASIC':
      default:
        return {
          'tier': 'BASIC',
          'nameEn': 'Basic Pharmacy',
          'nameBn': 'বেসিক ফার্মেসি',
          'monthlyPriceBdt': '1500.00',
          'annualPriceBdt': '15000.00',
          'maxBranches': 1,
          'maxDevices': 1,
          'maxStaff': 3,
        };
    }
  }

  /// Resolves API endpoints for catalogue and entitlement operations.
  static String resolveEndpoint(String action, [String? identifier]) {
    final cleanAction = action.toLowerCase().trim();
    switch (cleanAction) {
      case 'list':
        return '/api/v2/billing/plans/';
      case 'retrieve':
        if (identifier == null || identifier.trim().isEmpty) {
          throw ArgumentError('Plan code required for retrieve action');
        }
        return '/api/v2/billing/plans/${identifier.trim()}/';
      case 'entitlement':
        if (identifier == null || identifier.trim().isEmpty) {
          throw ArgumentError('Tenant ID required for entitlement action');
        }
        return '/api/v2/billing/entitlements/${identifier.trim()}/';
      case 'apply':
        if (identifier == null || identifier.trim().isEmpty) {
          throw ArgumentError('Tenant ID required for apply action');
        }
        return '/api/v2/billing/entitlements/${identifier.trim()}/apply/';
      case 'verify_feature':
        if (identifier == null || identifier.trim().isEmpty) {
          throw ArgumentError('Tenant ID required for verify_feature action');
        }
        return '/api/v2/billing/entitlements/${identifier.trim()}/verify-feature/';
      default:
        throw ArgumentError('Unknown plan catalogue action: $action');
    }
  }

  /// Validates plan application payload inputs.
  static void validateApplyRequest(String? planCode, String? billingCycle) {
    if (planCode == null || planCode.trim().isEmpty) {
      throw ArgumentError('Plan code is required');
    }
    if (!validPlanCodes.contains(planCode.toUpperCase().trim())) {
      throw ArgumentError('Unsupported plan code: $planCode');
    }
    if (billingCycle == null || billingCycle.trim().isEmpty) {
      throw ArgumentError('Billing cycle is required');
    }
    if (!validBillingCycles.contains(billingCycle.toUpperCase().trim())) {
      throw ArgumentError('Unsupported billing cycle: $billingCycle');
    }
  }
}
