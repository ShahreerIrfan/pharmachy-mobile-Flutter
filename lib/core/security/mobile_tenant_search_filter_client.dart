/// ADR-0065: Mobile Platform Super Admin Tenant Search & Filter Client.
/// Enforces privilege isolation, maps status badge tones, and guarantees
/// patient clinical records are strictly excluded from tenant discovery.
library mobile_tenant_search_filter_client;

class PlatformTenantSearchDeniedException implements Exception {
  final String message;
  const PlatformTenantSearchDeniedException(this.message);

  @override
  String toString() => 'PlatformTenantSearchDeniedException: $message';
}

class MobileTenantSearchFilterClient {
  static const Set<String> _authorizedRoles = {
    'SUPERADMIN',
    'SUPER_ADMIN',
    'PLATFORM_OPERATOR',
  };

  static const Set<String> _allowedStatuses = {
    'ACTIVE',
    'TRIAL',
    'SUSPENDED',
    'ARCHIVED',
    'GRACE_PERIOD',
  };

  static const Set<String> _allowedPlanTiers = {'BASIC', 'STANDARD', 'PRO'};

  static const Set<String> _forbiddenPatientKeys = {
    'patient_name',
    'patient_phone',
    'prescriptions',
    'dispensing_history',
    'clinical_notes',
  };

  /// Invariant: Cross-tenant directory search is NEVER rendered in tenant mobile manager app.
  static bool shouldDisplayTenantSearchInMobileApp() => false;

  /// Verifies if user role is authorized to perform platform tenant searches.
  static bool isTenantSearchAllowed(String? role) {
    if (role == null) return false;
    return _authorizedRoles.contains(role.toUpperCase().trim());
  }

  /// Verifies that patient-level clinical records are absent from the payload.
  static bool hasPatientData(Map<String, dynamic>? item) {
    if (item == null) return false;
    for (final key in _forbiddenPatientKeys) {
      if (item.containsKey(key)) return true;
    }
    return false;
  }

  /// Maps lifecycle status to UI badge color tone conforming to Apple-inspired restraint.
  static String resolveStatusBadgeTone(String? status) {
    if (status == null) return 'neutral';
    switch (status.toUpperCase().trim()) {
      case 'ACTIVE':
        return 'success';
      case 'TRIAL':
      case 'GRACE_PERIOD':
        return 'warning';
      case 'SUSPENDED':
        return 'danger';
      case 'ARCHIVED':
      default:
        return 'neutral';
    }
  }

  /// Builds platform tenant search query URL with validation.
  static String buildSearchQuery(
    String role, {
    String? search,
    String? status,
    String? planTier,
    int page = 1,
    int pageSize = 20,
  }) {
    if (!isTenantSearchAllowed(role)) {
      throw PlatformTenantSearchDeniedException(
        'Access denied: Role \'$role\' is not authorized to search platform tenants.',
      );
    }
    if (page < 1) {
      throw ArgumentError('Page must be >= 1');
    }
    if (pageSize < 1 || pageSize > 100) {
      throw ArgumentError('Page size must be between 1 and 100');
    }

    final buffer = StringBuffer('/api/v2/platform/console/tenants/?page=$page&page_size=$pageSize');

    if (search != null && search.trim().isNotEmpty) {
      buffer.write('&search=${Uri.encodeQueryComponent(search.trim())}');
    }
    if (status != null && status.trim().isNotEmpty) {
      final cleanStatus = status.toUpperCase().trim();
      if (!_allowedStatuses.contains(cleanStatus)) {
        throw ArgumentError('Invalid status filter: $status');
      }
      buffer.write('&status=$cleanStatus');
    }
    if (planTier != null && planTier.trim().isNotEmpty) {
      final cleanPlan = planTier.toUpperCase().trim();
      if (!_allowedPlanTiers.contains(cleanPlan)) {
        throw ArgumentError('Invalid plan tier filter: $planTier');
      }
      buffer.write('&plan_tier=$cleanPlan');
    }

    return buffer.toString();
  }
}
