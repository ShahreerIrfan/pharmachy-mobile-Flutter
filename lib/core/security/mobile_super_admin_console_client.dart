/// ADR-0063: Mobile Platform Super Admin Console Client & Boundary Guard.
/// Ensures platform management controls are never rendered inside tenant mobile app.
library mobile_super_admin_console_client;

class PlatformAccessDeniedException implements Exception {
  final String message;
  const PlatformAccessDeniedException(this.message);

  @override
  String toString() => 'PlatformAccessDeniedException: $message';
}

class MobileSuperAdminConsoleClient {
  static const Set<String> _authorizedRoles = {
    'SUPERADMIN',
    'SUPER_ADMIN',
    'PLATFORM_OPERATOR',
  };

  static const Set<String> _allowedActions = {
    'BROADCAST_ANNOUNCEMENT',
    'SET_MAINTENANCE_MODE',
    'TRIGGER_SYSTEM_HEALTH_CHECK',
  };

  /// Invariant: Platform administrative controls are NEVER visible in tenant mobile app.
  static bool shouldShowPlatformControlsInOwnerUI() => false;

  /// Verifies if user role has platform console privileges.
  static bool isPlatformConsoleAllowed(String? role) {
    if (role == null) return false;
    return _authorizedRoles.contains(role.toUpperCase().trim());
  }

  /// Resolves platform console URLs with strict privilege checks.
  static String resolvePlatformEndpoint(
    String role,
    String endpointType, {
    String? tenantId,
  }) {
    if (!isPlatformConsoleAllowed(role)) {
      throw PlatformAccessDeniedException(
        'Access denied: Role \'$role\' cannot access platform console endpoint \'$endpointType\'.',
      );
    }

    switch (endpointType.toLowerCase().trim()) {
      case 'metrics':
        return '/api/v2/platform/console/metrics/';
      case 'tenants':
        return '/api/v2/platform/console/tenants/';
      case 'inspect':
        if (tenantId == null || tenantId.trim().isEmpty) {
          throw ArgumentError('tenantId is required for tenant inspection.');
        }
        return '/api/v2/platform/console/tenants/${tenantId.trim()}/';
      case 'actions':
        return '/api/v2/platform/console/actions/';
      default:
        throw ArgumentError('Unknown platform endpoint type: $endpointType');
    }
  }

  /// Validates platform action payload before dispatch.
  static bool validateActionRequest(
    String role,
    String actionType,
    String reason,
  ) {
    if (!isPlatformConsoleAllowed(role)) {
      throw PlatformAccessDeniedException(
        'Role \'$role\' is not authorized to execute platform actions.',
      );
    }
    final cleanAction = actionType.toUpperCase().trim();
    if (!_allowedActions.contains(cleanAction)) {
      throw ArgumentError('Unsupported platform action: $actionType');
    }
    if (reason.trim().length < 5) {
      throw ArgumentError('Reason must be at least 5 characters for compliance.');
    }
    return true;
  }
}

