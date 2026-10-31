/// ADR-0068: Mobile Support Access Governance and Impersonation Prevention Client.
/// Strictly prohibits unsafe user impersonation, coordinates pharmacy owner consent approvals,
/// formats active notice banners, and provides one-click emergency kill-switch URLs.
library mobile_support_access_governance_client;

class MobileSupportAccessGovernanceClient {
  static final RegExp _idPattern = RegExp(r'^[a-z0-9_-]{3,64}$');

  static const Set<String> _validScopes = {
    'DIAGNOSTIC_READ',
    'BILLING_READ',
    'BREAK_GLASS_REPAIR',
  };

  /// Architectural Invariant: Direct user impersonation ("Login As") is strictly forbidden.
  static bool isDirectUserImpersonationPermitted() => false;

  /// Invariant: Clinical dispensing is strictly prohibited for any support scope.
  static bool isClinicalDispensingPermitted(String? scope) => false;

  /// Determines whether a user role can approve or reject support access requests.
  static bool canApproveSupportRequests(String? role) {
    if (role == null) return false;
    final clean = role.toUpperCase().trim();
    return clean == 'PHARMACY_OWNER' || clean == 'SUPERADMIN' || clean == 'SUPER_ADMIN';
  }

  /// Validates if a scope string conforms to ADR-0068.
  static bool isValidScope(String? scope) {
    if (scope == null) return false;
    return _validScopes.contains(scope.toUpperCase().trim());
  }

  /// Builds tenant active notice query URL.
  static String buildActiveNoticeUrl(String tenantId) {
    final cleanId = tenantId.trim();
    if (!_idPattern.hasMatch(cleanId)) {
      throw ArgumentError('Invalid tenant identifier: \'$tenantId\'');
    }
    return '/api/v2/tenants/support-access/$cleanId/active/';
  }

  /// Builds consent approval endpoint URL.
  static String buildApproveUrl(String tenantId, String grantId) {
    final cleanTenant = tenantId.trim();
    final cleanGrant = grantId.trim();
    if (!_idPattern.hasMatch(cleanTenant)) {
      throw ArgumentError('Invalid tenant identifier: \'$tenantId\'');
    }
    if (!_idPattern.hasMatch(cleanGrant)) {
      throw ArgumentError('Invalid grant identifier: \'$grantId\'');
    }
    return '/api/v2/tenants/support-access/$cleanTenant/$cleanGrant/approve/';
  }

  /// Builds request rejection endpoint URL.
  static String buildRejectUrl(String tenantId, String grantId) {
    final cleanTenant = tenantId.trim();
    final cleanGrant = grantId.trim();
    if (!_idPattern.hasMatch(cleanTenant)) {
      throw ArgumentError('Invalid tenant identifier: \'$tenantId\'');
    }
    if (!_idPattern.hasMatch(cleanGrant)) {
      throw ArgumentError('Invalid grant identifier: \'$grantId\'');
    }
    return '/api/v2/tenants/support-access/$cleanTenant/$cleanGrant/reject/';
  }

  /// Builds emergency revocation URL ("Kill Switch").
  static String buildRevokeUrl(String tenantId, String grantId) {
    final cleanTenant = tenantId.trim();
    final cleanGrant = grantId.trim();
    if (!_idPattern.hasMatch(cleanTenant)) {
      throw ArgumentError('Invalid tenant identifier: \'$tenantId\'');
    }
    if (!_idPattern.hasMatch(cleanGrant)) {
      throw ArgumentError('Invalid grant identifier: \'$grantId\'');
    }
    return '/api/v2/tenants/support-access/$cleanTenant/$cleanGrant/revoke/';
  }

  /// Resolves the notice tone conforming to Apple-inspired restrained design system.
  static String resolveBannerTone(String? tone) {
    if (tone == null) return 'neutral';
    switch (tone.toLowerCase().trim()) {
      case 'danger':
        return 'danger';
      case 'warning':
        return 'warning';
      default:
        return 'neutral';
    }
  }

  /// Formats remaining duration into clean, restrained string (e.g. "25m" or "1h 15m").
  static String formatRemainingDuration(int seconds) {
    if (seconds <= 0) return '0m';
    final minutes = seconds ~/ 60;
    if (minutes < 60) {
      return '${minutes}m';
    }
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    return remainingMinutes > 0 ? '${hours}h ${remainingMinutes}m' : '${hours}h';
  }
}
