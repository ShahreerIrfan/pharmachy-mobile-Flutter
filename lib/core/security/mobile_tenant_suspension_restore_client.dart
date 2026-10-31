/// ADR-0067: Mobile Platform Super Admin Tenant Suspension & Restore Client.
/// Manages tenant suspension, restoration, reason codes, client lease status,
/// and offline outbox pending-sync policy reconciliation.
library mobile_tenant_suspension_restore_client;

class PlatformLifecycleDeniedException implements Exception {
  final String message;
  const PlatformLifecycleDeniedException(this.message);

  @override
  String toString() => 'PlatformLifecycleDeniedException: $message';
}

enum MobileClientLeaseStatus {
  active,
  suspended,
  revoked,
  expired,
}

enum MobilePendingSyncPolicy {
  allowSync,
  drainPreSuspension,
  rejectPostSuspension,
}

class MobileTenantSuspensionRestoreClient {
  static const Set<String> _authorizedRoles = {
    'SUPERADMIN',
    'SUPER_ADMIN',
    'PLATFORM_OPERATOR',
  };

  static const Set<String> validSuspensionReasonCodes = {
    'NON_PAYMENT',
    'COMPLIANCE_BREACH',
    'FRAUD_INVESTIGATION',
    'DISPUTE_HOLD',
    'ADMIN_MANUAL',
  };

  /// Invariant: Platform suspension controls are never displayed in regular store app.
  static bool isLifecycleManagementVisibleInStoreApp() => false;

  /// Verifies if user role is authorized to suspend or restore tenants.
  static bool canManageLifecycle(String? role) {
    if (role == null) return false;
    return _authorizedRoles.contains(role.toUpperCase().trim());
  }

  /// Evaluates client lease validity based on tenant lifecycle status.
  static MobileClientLeaseStatus evaluateClientLease(String? tenantStatus) {
    if (tenantStatus == null) return MobileClientLeaseStatus.revoked;
    switch (tenantStatus.toUpperCase().trim()) {
      case 'ACTIVE':
      case 'TRIAL':
      case 'PAST_DUE':
        return MobileClientLeaseStatus.active;
      case 'SUSPENDED':
        return MobileClientLeaseStatus.suspended;
      case 'ARCHIVED':
        return MobileClientLeaseStatus.revoked;
      default:
        return MobileClientLeaseStatus.revoked;
    }
  }

  /// Evaluates pending outbox sync policy against suspension timestamp.
  /// Zero Data Loss Invariant:
  /// - Pre-suspension transaction: DRAIN_PRE_SUSPENSION (recorded in audit settlement)
  /// - Post-suspension transaction: REJECT_POST_SUSPENSION (rejected from live inventory)
  static MobilePendingSyncPolicy evaluatePendingSyncPolicy({
    required String? tenantStatus,
    required DateTime? transactionTime,
    required DateTime? suspendedAt,
  }) {
    if (tenantStatus == null || tenantStatus.toUpperCase().trim() != 'SUSPENDED') {
      return MobilePendingSyncPolicy.allowSync;
    }
    if (transactionTime == null || suspendedAt == null) {
      return MobilePendingSyncPolicy.rejectPostSuspension;
    }

    if (!transactionTime.isAfter(suspendedAt)) {
      return MobilePendingSyncPolicy.drainPreSuspension;
    } else {
      return MobilePendingSyncPolicy.rejectPostSuspension;
    }
  }

  /// Validates suspension request parameters.
  static void validateSuspensionRequest({
    required String tenantId,
    required String reason,
    String reasonCode = 'ADMIN_MANUAL',
  }) {
    if (tenantId.trim().isEmpty) {
      throw ArgumentError('tenantId cannot be empty');
    }
    if (reason.trim().length < 5) {
      throw ArgumentError('reason must be at least 5 characters');
    }
    if (!validSuspensionReasonCodes.contains(reasonCode.toUpperCase().trim())) {
      throw ArgumentError('Invalid reasonCode: $reasonCode');
    }
  }

  /// Validates restoration request parameters.
  static void validateRestorationRequest({
    required String tenantId,
    required String reason,
  }) {
    if (tenantId.trim().isEmpty) {
      throw ArgumentError('tenantId cannot be empty');
    }
    if (reason.trim().length < 5) {
      throw ArgumentError('reason must be at least 5 characters');
    }
  }

  /// Builds platform suspend endpoint path.
  static String buildSuspendUrl(String tenantId) =>
      '/api/v2/platform/console/tenants/${tenantId.trim()}/suspend/';

  /// Builds platform restore endpoint path.
  static String buildRestoreUrl(String tenantId) =>
      '/api/v2/platform/console/tenants/${tenantId.trim()}/restore/';
}
