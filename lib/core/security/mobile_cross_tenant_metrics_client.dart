/// ADR-0075: Flutter Mobile Cross-Tenant Metrics & Benchmark Client.
/// Governs privacy-preserving aggregate telemetry, k-anonymity validation,
/// and tenant-isolated comparative benchmarking for pharmacy owners.
library mobile_cross_tenant_metrics_client;

class MobileCrossTenantMetricsClient {
  static final RegExp _snapshotIdPattern = RegExp(r'^ctm-[a-z0-9_-]{8,64}$');
  static const int defaultMinCohortThreshold = 3;

  static const Set<String> _platformAdminRoles = {
    'SUPERADMIN',
    'SUPER_ADMIN',
    'PLATFORM_OPERATOR',
  };

  static const Set<String> _benchmarkAuthorizedRoles = {
    'SUPERADMIN',
    'SUPER_ADMIN',
    'PLATFORM_OPERATOR',
    'PHARMACY_OWNER',
    'OWNER',
    'BRANCH_MANAGER',
    'STORE_MANAGER',
    'ADMIN',
  };

  static const Set<String> _forbiddenPhiFields = {
    'patient_name',
    'patient_phone',
    'patient_mobile',
    'nid',
    'doctor_name',
    'doctor_license',
    'prescription_image',
  };

  /// RBAC: Only platform super administrators can manage macro-telemetry.
  static bool canRoleManagePlatformMetrics(String? role) {
    if (role == null) return false;
    return _platformAdminRoles.contains(role.toUpperCase().trim());
  }

  /// RBAC: Owners, Managers, and Platform Admins can view safe benchmarks.
  /// Cashiers and Staff Pharmacists are strictly forbidden.
  static bool canRoleViewBenchmarks(String? role) {
    if (role == null) return false;
    return _benchmarkAuthorizedRoles.contains(role.toUpperCase().trim());
  }

  /// Validates snapshot ID syntax according to ADR-0075 contract.
  static bool isValidSnapshotId(String? snapshotId) {
    if (snapshotId == null) return false;
    return _snapshotIdPattern.hasMatch(snapshotId.trim().toLowerCase());
  }

  /// k-Anonymity Guardrail: Returns true if cohort size is below minimum threshold and must be suppressed.
  static bool isCohortSuppressed(int contributingTenants, int minThreshold) {
    final effectiveThreshold = minThreshold < 2 ? 2 : minThreshold;
    return contributingTenants < effectiveThreshold;
  }

  /// Verifies that the JSON string contains zero patient health information (PHI) fields.
  static bool validateZeroPhiGuaranteed(String? jsonPayload) {
    if (jsonPayload == null || jsonPayload.trim().isEmpty) {
      return true;
    }
    final lower = jsonPayload.toLowerCase();
    for (final phiField in _forbiddenPhiFields) {
      if (lower.contains('"$phiField"') || lower.contains('$phiField:')) {
        return false;
      }
    }
    return true;
  }

  /// State machine validator for CrossTenantMetricsSnapshot lifecycle.
  static bool isValidStateTransition(String? fromStatus, String? toStatus) {
    if (fromStatus == null || toStatus == null) return false;
    final from = fromStatus.toUpperCase().trim();
    final to = toStatus.toUpperCase().trim();

    if (from == to) return true;

    switch (from) {
      case 'DRAFT':
        return to == 'PUBLISHED' || to == 'ARCHIVED' || to == 'SUPPRESSED';
      case 'PUBLISHED':
        return to == 'ARCHIVED' || to == 'SUPPRESSED';
      case 'SUPPRESSED':
        return to == 'ARCHIVED' || to == 'PUBLISHED';
      default:
        return false; // ARCHIVED is terminal
    }
  }

  /// Builds platform cross-tenant metrics REST URL.
  static String buildPlatformMetricsUrl(String? baseUrl, [String? snapshotId]) {
    final cleanBase = (baseUrl ?? '').replaceAll(RegExp(r'/+$'), '');
    if (snapshotId == null || snapshotId.trim().isEmpty) {
      return '$cleanBase/api/v2/platform/cross-tenant-metrics/';
    }
    if (!isValidSnapshotId(snapshotId)) {
      throw ArgumentError('Invalid snapshotId: $snapshotId');
    }
    return '$cleanBase/api/v2/platform/cross-tenant-metrics/${snapshotId.trim()}/';
  }

  /// Builds tenant comparative benchmarks REST URL.
  static String buildTenantBenchmarkUrl(String? baseUrl, [String? tenantId]) {
    final cleanBase = (baseUrl ?? '').replaceAll(RegExp(r'/+$'), '');
    if (tenantId == null || tenantId.trim().isEmpty) {
      return '$cleanBase/api/v2/analytics/platform-benchmarks/';
    }
    return '$cleanBase/api/v2/analytics/platform-benchmarks/?tenant_id=${tenantId.trim()}';
  }

  /// Localized suppression explanation for UI display when cohort < k.
  static String getLocalizedSuppressionMessage(bool isBangla) {
    return isBangla
        ? 'গোপনীয়তা রক্ষা: অংশগ্রহণকারী ফার্মেসির সংখ্যা নূন্যতম সীমার নিচে হওয়ায় ডেটা গোপন রাখা হয়েছে।'
        : 'Privacy Guardrail: Data suppressed as the reporting cohort is below the minimum k-anonymity threshold.';
  }
}
