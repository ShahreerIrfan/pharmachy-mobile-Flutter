/// ADR-0066: Mobile Platform Super Admin Tenant Detail and Audit Timeline Client.
/// Manages authorization, URL construction, patient clinical data sanitization audits,
/// and chronological timeline validation for platform diagnostics.
library mobile_tenant_detail_timeline_client;

class PlatformTenantDetailDeniedException implements Exception {
  final String message;
  const PlatformTenantDetailDeniedException(this.message);

  @override
  String toString() => 'PlatformTenantDetailDeniedException: $message';
}

class MobileTenantDetailTimelineClient {
  static const Set<String> _authorizedRoles = {
    'SUPERADMIN',
    'SUPER_ADMIN',
    'PLATFORM_OPERATOR',
  };

  static final RegExp _tenantIdPattern = RegExp(r'^[a-z0-9_-]{3,64}$');

  static const Set<String> _forbiddenPatientKeys = {
    'patient_name',
    'patient_phone',
    'patient_address',
    'prescriptions',
    'dispensing_records',
    'dispensing_history',
    'clinical_notes',
  };

  /// Architectural invariant: Platform tenant detail view is strictly omitted from store mobile UI.
  static bool shouldDisplayTenantDetailInMobileApp() => false;

  /// Verifies if user role is authorized to view platform tenant detail and audit timeline.
  static bool isTenantDetailAllowed(String? role) {
    if (role == null) return false;
    return _authorizedRoles.contains(role.toUpperCase().trim());
  }

  /// Audits a tenant detail payload to guarantee patient-level clinical records are absent.
  static bool containsPatientClinicalData(Map<String, dynamic>? payload) {
    if (payload == null) return false;
    for (final key in _forbiddenPatientKeys) {
      if (payload.containsKey(key)) return true;
    }
    return false;
  }

  /// Builds the tenant detail & timeline endpoint URL with validation.
  static String buildTenantDetailUrl(String role, String tenantId) {
    if (!isTenantDetailAllowed(role)) {
      throw PlatformTenantDetailDeniedException(
        'Access denied: Role \'$role\' cannot access tenant detail and timeline.',
      );
    }
    final trimmedId = tenantId.trim();
    if (!_tenantIdPattern.hasMatch(trimmedId)) {
      throw ArgumentError('Invalid tenant identifier: \'$tenantId\'');
    }
    return '/api/v2/platform/console/tenants/$trimmedId/detail/';
  }

  /// Verifies that the audit timeline contains the required event attributes.
  static bool isValidTimelineEntry(Map<String, dynamic>? entry) {
    if (entry == null) return false;
    return entry.containsKey('action') &&
        entry.containsKey('status') &&
        entry.containsKey('timestamp');
  }

  /// Resolves timeline event status to restrained UI tone.
  static String resolveTimelineStatusTone(String? status) {
    if (status == null) return 'neutral';
    switch (status.toUpperCase().trim()) {
      case 'SUCCESS':
      case 'COMPLETED':
        return 'success';
      case 'WARNING':
      case 'PENDING':
        return 'warning';
      case 'FAILED':
      case 'ERROR':
        return 'danger';
      default:
        return 'neutral';
    }
  }
}

