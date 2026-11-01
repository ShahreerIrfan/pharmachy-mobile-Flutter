/// ADR-0074: Flutter Mobile Tenant Deletion Assessment & Purge Client.
/// Governs pharmacy owner deletion requests, statutory retention hold evaluations,
/// and irreversible purge confirmation guardrails.
library mobile_tenant_deletion_client;

class MobileTenantDeletionClient {
  static final RegExp _requestIdPattern = RegExp(r'^tdr-[a-z0-9_-]{8,64}$');
  static const String mandatoryConfirmationText = 'CONFIRM_PERMANENT_DELETION';

  static const Set<String> _allowedRequestRoles = {
    'SUPERADMIN',
    'SUPER_ADMIN',
    'PLATFORM_OPERATOR',
    'PHARMACY_OWNER',
    'OWNER',
  };

  static const Set<String> _allowedAssessmentRoles = {
    'SUPERADMIN',
    'SUPER_ADMIN',
    'PLATFORM_OPERATOR',
  };

  /// RBAC Invariant: Only Pharmacy Owners and SuperAdmins can initiate deletion requests.
  static bool canRoleRequestDeletion(String? role) {
    if (role == null) return false;
    return _allowedRequestRoles.contains(role.toUpperCase().trim());
  }

  /// RBAC Invariant: Only Platform SuperAdmins can assess retention holds, reject requests, or execute purges.
  static bool canRoleAssessOrPurge(String? role) {
    if (role == null) return false;
    return _allowedAssessmentRoles.contains(role.toUpperCase().trim());
  }

  /// Validates deletion request identifier syntax.
  static bool isValidRequestId(String? requestId) {
    if (requestId == null) return false;
    return _requestIdPattern.hasMatch(requestId.trim());
  }

  /// Statutory Retention Guardrail: Physical purge is blocked if active clinical or tax holds exist.
  static bool isPhysicalPurgeBlocked(bool hasActiveHolds) {
    return hasActiveHolds;
  }

  /// Validates explicit multi-step confirmation phrase.
  static bool isConfirmationTextValid(String? confirmationText) {
    if (confirmationText == null) return false;
    return confirmationText.trim().toUpperCase() == mandatoryConfirmationText;
  }

  /// Verifies state machine transition validity under ADR-0074.
  static bool canTransition(String? currentStatus, String? targetStatus) {
    if (currentStatus == null || targetStatus == null) return false;
    final cur = currentStatus.toUpperCase().trim();
    final tgt = targetStatus.toUpperCase().trim();

    switch (cur) {
      case 'SUBMITTED':
        return tgt == 'UNDER_REVIEW' || tgt == 'HOLD_ACTIVE' || tgt == 'ELIGIBLE_FOR_PURGE' || tgt == 'CANCELLED';
      case 'UNDER_REVIEW':
        return tgt == 'HOLD_ACTIVE' || tgt == 'ELIGIBLE_FOR_PURGE' || tgt == 'REJECTED' || tgt == 'CANCELLED';
      case 'HOLD_ACTIVE':
        return tgt == 'ELIGIBLE_FOR_PURGE' || tgt == 'REJECTED' || tgt == 'CANCELLED';
      case 'ELIGIBLE_FOR_PURGE':
        return tgt == 'CONFIRMED' || tgt == 'PURGED' || tgt == 'REJECTED' || tgt == 'CANCELLED';
      case 'CONFIRMED':
        return tgt == 'PURGED';
      default:
        return false;
    }
  }

  /// Builds tenant-scoped deletion request list endpoint.
  static String buildTenantDeletionListUrl() {
    return '/api/v2/tenants/deletion-requests/';
  }

  /// Builds tenant-scoped deletion request detail endpoint.
  static String buildTenantDeletionDetailUrl(String requestId) {
    final clean = requestId.trim();
    if (!isValidRequestId(clean)) {
      throw ArgumentError('Invalid request ID: \'$requestId\'');
    }
    return '/api/v2/tenants/deletion-requests/$clean/';
  }

  /// Builds tenant-scoped cancellation endpoint.
  static String buildTenantCancelUrl(String requestId) {
    final clean = requestId.trim();
    if (!isValidRequestId(clean)) {
      throw ArgumentError('Invalid request ID: \'$requestId\'');
    }
    return '/api/v2/tenants/deletion-requests/$clean/cancel/';
  }

  /// Builds platform-wide deletion assessment list endpoint.
  static String buildPlatformAssessmentListUrl() {
    return '/api/v2/platform/deletion-assessments/';
  }

  /// Builds platform retention hold evaluation endpoint.
  static String buildPlatformAssessUrl(String requestId) {
    final clean = requestId.trim();
    if (!isValidRequestId(clean)) {
      throw ArgumentError('Invalid request ID: \'$requestId\'');
    }
    return '/api/v2/platform/deletion-assessments/$clean/assess/';
  }

  /// Builds platform rejection endpoint.
  static String buildPlatformRejectUrl(String requestId) {
    final clean = requestId.trim();
    if (!isValidRequestId(clean)) {
      throw ArgumentError('Invalid request ID: \'$requestId\'');
    }
    return '/api/v2/platform/deletion-assessments/$clean/reject/';
  }

  /// Builds platform irreversible purge execution endpoint.
  static String buildPlatformPurgeUrl(String requestId) {
    final clean = requestId.trim();
    if (!isValidRequestId(clean)) {
      throw ArgumentError('Invalid request ID: \'$requestId\'');
    }
    return '/api/v2/platform/deletion-assessments/$clean/purge/';
  }
}
