import 'package:pharmacy_mobile_manager/core/contracts/mobile_api_response_envelope.dart';

/// Flutter Mobile Manager Audit Event & Immutability Foundation Service.
/// Architecture Decision: ADR-0050 (Audit Event Foundation & Protected Retention).
class MobileAuditEvent {
  final String entryId;
  final String timestamp;
  final String tenantId;
  final String? branchId;
  final String? userId;
  final String? actorEmail;
  final String actorRole;
  final String? deviceId;
  final String action;
  final String resourceType;
  final String? resourceId;
  final String status;
  final Map<String, dynamic> beforeState;
  final Map<String, dynamic> afterState;
  final String? retentionUntil;
  final bool isImmutable;

  const MobileAuditEvent({
    required this.entryId,
    required this.timestamp,
    required this.tenantId,
    this.branchId,
    this.userId,
    this.actorEmail,
    required this.actorRole,
    this.deviceId,
    required this.action,
    required this.resourceType,
    this.resourceId,
    this.status = 'SUCCESS',
    this.beforeState = const {},
    this.afterState = const {},
    this.retentionUntil,
    this.isImmutable = true,
  });

  factory MobileAuditEvent.fromJson(Map<String, dynamic> json) {
    return MobileAuditEvent(
      entryId: json['entry_id'] as String? ?? '',
      timestamp: json['timestamp'] as String? ?? '',
      tenantId: json['tenant_id'] as String? ?? '',
      branchId: json['branch_id'] as String?,
      userId: json['user_id'] as String?,
      actorEmail: json['actor_email'] as String?,
      actorRole: json['actor_role'] as String? ?? 'PHARMACY_OWNER',
      deviceId: json['device_id'] as String?,
      action: json['action'] as String? ?? '',
      resourceType: json['resource_type'] as String? ?? '',
      resourceId: json['resource_id'] as String?,
      status: json['status'] as String? ?? 'SUCCESS',
      beforeState: (json['before_state'] as Map<String, dynamic>?) ?? const {},
      afterState: (json['after_state'] as Map<String, dynamic>?) ?? const {},
      retentionUntil: json['retention_until'] as String?,
      isImmutable: json['is_immutable'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'entry_id': entryId,
        'timestamp': timestamp,
        'tenant_id': tenantId,
        'branch_id': branchId,
        'user_id': userId,
        'actor_email': actorEmail,
        'actor_role': actorRole,
        'device_id': deviceId,
        'action': action,
        'resource_type': resourceType,
        'resource_id': resourceId,
        'status': status,
        'before_state': beforeState,
        'after_state': afterState,
        'retention_until': retentionUntil,
        'is_immutable': isImmutable,
      };
}

class MobileAuditEventService {
  static const Set<String> authorizedAuditorRoles = {
    'PHARMACY_OWNER',
    'BRANCH_MANAGER',
    'AUDITOR',
    'COMPLIANCE_OFFICER',
    'SUPERADMIN',
  };

  /// Checks if the active user role is authorized to inspect regulatory audit logs.
  static bool isAuthorizedAuditor(String role) {
    return authorizedAuditorRoles.contains(role.trim().toUpperCase());
  }

  /// Validates append-only audit event integrity.
  static bool validateEvent(MobileAuditEvent event) {
    if (event.tenantId.trim().isEmpty) return false;
    if (event.action.trim().isEmpty) return false;
    if (event.resourceType.trim().isEmpty) return false;
    return event.isImmutable;
  }

  /// Resolves bilingual error message conforming to ADR-0050.
  static Map<String, String> getBilingualErrorMessage(String errorCode) {
    switch (errorCode.toUpperCase()) {
      case 'ERR_AUDIT_IMMUTABLE':
        return {
          'en':
              'Audit log entries are immutable and append-only. Modification or deletion is forbidden.',
          'bn':
              'অডিট লগ রেকর্ড অপরিবর্তনযোগ্য। পরিবর্তন বা মুছে ফেলা কঠোরভাবে নিষিদ্ধ।',
        };
      case 'ERR_CROSS_TENANT_VIOLATION':
        return {
          'en': 'Cross-tenant audit queries are strictly forbidden.',
          'bn': 'অন্য ফার্মেসির অডিট লগ অনুসন্ধান কঠোরভাবে নিষিদ্ধ।',
        };
      case 'ERR_PERMISSION_DENIED':
        return {
          'en':
              'Access denied: Audit log inspection requires Manager or Owner privileges.',
          'bn':
              'প্রবেশাধিকার প্রত্যাখ্যাত: অডিট লগ দেখার জন্য ম্যানেজার বা মালিকের অনুমতি প্রয়োজন।',
        };
      default:
        return {
          'en': 'Audit logging operation failed. Please check connection.',
          'bn': 'অডিট লগ পরিচালনায় ত্রুটি দেখা দিয়েছে। সংযোগ পরীক্ষা করুন।',
        };
    }
  }

  /// Maps audit exceptions to Mobile UI State.
  static MobileUiState resolveUiState(String errorCode) {
    final code = errorCode.toUpperCase();
    if (code == 'ERR_AUDIT_IMMUTABLE' ||
        code == 'ERR_CROSS_TENANT_VIOLATION' ||
        code == 'ERR_PERMISSION_DENIED') {
      return MobileUiState.permissionDenied;
    }
    return MobileUiState.error;
  }
}
