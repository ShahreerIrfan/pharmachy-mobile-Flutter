/// mobile_feature_entitlement_engine_client.dart
///
/// Architecture Decision: ADR-0015, ADR-0080 & ADR-0082
/// Phase 05: Basic/Standard/Pro Subscription & Billing (P082)
///
/// Mobile Manager Client for Feature Entitlement Engine:
///   - Evaluates effective capabilities, limits, quotas, and bounded offline lease
///   - Clinical safety invariant (INV-SAFETY-01): Clinical controls are NEVER gated
///   - POS counter sales dispensing lockout when tenant is suspended
///   - Over-quota detection and degradation warnings
library mobile_feature_entitlement_engine_client;

class MobileFeatureEntitlementEngineClient {
  static const int defaultOfflineLeaseHours = 72;

  static const Set<String> clinicalSafetyControls = {
    'ANTIBIOTIC_REGISTER',
    'BATCH_EXPIRY_BLOCK',
    'RECALL_QUARANTINE',
    'BANNED_DRUG_RESTRICTION',
    'RX_VERIFICATION',
  };

  /// Constructs the effective entitlement retrieval endpoint.
  static String resolveEndpoint(String tenantId, {String? deviceId, String? branchId}) {
    final cleanTenant = tenantId.trim();
    if (cleanTenant.isEmpty) {
      throw ArgumentError('Tenant ID cannot be empty');
    }
    final buffer = StringBuffer('/api/v2/billing/effective-entitlements/$cleanTenant/');

    final queryParams = <String>[];
    if (deviceId != null && deviceId.trim().isNotEmpty) {
      queryParams.add('device_id=${deviceId.trim()}');
    }
    if (branchId != null && branchId.trim().isNotEmpty) {
      queryParams.add('branch_id=${branchId.trim()}');
    }

    if (queryParams.isNotEmpty) {
      buffer.write('?${queryParams.join('&')}');
    }
    return buffer.toString();
  }

  /// Evaluates whether POS dispensing checkout is allowed.
  static bool isCheckoutAllowed({
    required bool isCheckoutAllowedBySubscription,
    required bool hasCheckoutCapability,
    required String? leaseStatus,
    DateTime? leaseExpiresAt,
  }) {
    if (!isCheckoutAllowedBySubscription || !hasCheckoutCapability) {
      return false;
    }
    if (leaseStatus == null || leaseStatus.toUpperCase() != 'ACTIVE') {
      return false;
    }
    if (leaseExpiresAt != null && DateTime.now().toUtc().isAfter(leaseExpiresAt.toUtc())) {
      return false;
    }
    return true;
  }

  /// Invariant INV-SAFETY-01: Clinical safety protections active across all conditions.
  static bool isClinicalSafetyActive(String featureKey) {
    return clinicalSafetyControls.contains(featureKey.toUpperCase().trim());
  }

  /// Evaluates quota breach for any dimension.
  static bool isQuotaExceeded(int used, int max) {
    return used > max;
  }
}
