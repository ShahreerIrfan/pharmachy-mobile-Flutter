/// mobile_tenant_lifecycle_end_to_end_client.dart
///
/// Architecture Decision: ADR-0080
/// Mobile Manager Platform Tenant Lifecycle End-to-End Client & Guard.
/// Provides:
///   - POS checkout eligibility evaluation (TRIAL, ACTIVE vs SUSPENDED, ARCHIVED)
///   - Commercial plan quota and Decimal BDT pricing mappings
///   - FSM state transition validation
///   - Platform Super Admin RBAC checks
library mobile_tenant_lifecycle_end_to_end_client;

class MobileTenantLifecycleEndToEndClient {
  static const Set<String> _authorizedRoles = {
    'SUPERADMIN',
    'SUPER_ADMIN',
    'PLATFORM_OPERATOR',
  };

  static const Set<String> _checkoutAllowedStatuses = {
    'TRIAL',
    'ACTIVE',
  };

  /// Checks if POS counter sales transactions are permitted under current status.
  static bool isCheckoutAllowed(String? tenantStatus) {
    if (tenantStatus == null) return false;
    return _checkoutAllowedStatuses.contains(tenantStatus.toUpperCase().trim());
  }

  /// Verifies if user holds platform administrative authority over tenant lifecycles.
  static bool isPlatformLifecycleAdmin(String? role) {
    if (role == null) return false;
    return _authorizedRoles.contains(role.toUpperCase().trim());
  }

  /// Resolves plan tier quotas and pricing in BDT.
  static Map<String, dynamic> getPlanQuotas(String? planTier) {
    final clean = planTier?.toUpperCase().trim() ?? 'BASIC';
    switch (clean) {
      case 'PRO':
        return {
          'branches': 25,
          'devices': 50,
          'monthlyAmountBdt': '15000.00',
        };
      case 'STANDARD':
        return {
          'branches': 5,
          'devices': 10,
          'monthlyAmountBdt': '6500.00',
        };
      case 'BASIC':
      default:
        return {
          'branches': 1,
          'devices': 2,
          'monthlyAmountBdt': '2500.00',
        };
    }
  }

  /// Validates finite state machine transition rules.
  static bool isValidTransition(String? fromStatus, String? toStatus) {
    if (fromStatus == null || toStatus == null) return false;
    final from = fromStatus.toUpperCase().trim();
    final to = toStatus.toUpperCase().trim();
    if (from == to) return true;

    switch (from) {
      case 'PROVISIONING':
        return to == 'TRIAL' || to == 'ACTIVE';
      case 'TRIAL':
        return to == 'ACTIVE' || to == 'SUSPENDED' || to == 'ARCHIVED';
      case 'ACTIVE':
        return to == 'SUSPENDED' || to == 'PAST_DUE' || to == 'ARCHIVED';
      case 'PAST_DUE':
        return to == 'ACTIVE' || to == 'SUSPENDED' || to == 'ARCHIVED';
      case 'SUSPENDED':
        return to == 'ACTIVE' || to == 'ARCHIVED';
      case 'ARCHIVED':
        return false;
      default:
        return false;
    }
  }

  /// Resolves platform API endpoint for lifecycle operations.
  static String resolveEndpoint(String action, String tenantId) {
    final cleanId = tenantId.trim();
    if (cleanId.isEmpty) {
      throw ArgumentError('tenantId cannot be empty.');
    }
    final cleanAction = action.toLowerCase().trim();

    switch (cleanAction) {
      case 'activate-subscription':
        return '/api/v2/tenants/$cleanId/activate-subscription/';
      case 'change-plan':
        return '/api/v2/tenants/$cleanId/change-plan/';
      case 'suspend':
        return '/api/v2/tenants/$cleanId/suspend/';
      case 'restore':
        return '/api/v2/tenants/$cleanId/restore/';
      case 'timeline':
        return '/api/v2/tenants/$cleanId/lifecycle-timeline/';
      default:
        return '/api/v2/tenants/$cleanId/';
    }
  }
}
