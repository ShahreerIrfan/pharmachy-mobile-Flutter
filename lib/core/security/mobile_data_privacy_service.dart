import 'package:pharmacy_mobile_manager/core/contracts/mobile_api_response_envelope.dart';

/// Flutter Mobile Manager Data Privacy Request Model.
/// Architecture Decision: ADR-0052 (Data Privacy Operations & Statutory Retention Schedule).
class MobilePrivacyRequest {
  final String requestId;
  final String tenantId;
  final String? branchId;
  final String subjectType;
  final String subjectIdentifier;
  final String requestType;
  final String status;
  final String reason;
  final bool retentionConflictDetected;
  final int retentionHorizonDays;
  final String? exportArtifactUrl;
  final String? assessedByEmail;
  final String? assessedAt;
  final String createdAt;

  const MobilePrivacyRequest({
    required this.requestId,
    required this.tenantId,
    this.branchId,
    this.subjectType = 'PATIENT',
    required this.subjectIdentifier,
    required this.requestType,
    this.status = 'PENDING_ASSESSMENT',
    this.reason = '',
    this.retentionConflictDetected = false,
    this.retentionHorizonDays = 730,
    this.exportArtifactUrl,
    this.assessedByEmail,
    this.assessedAt,
    required this.createdAt,
  });

  bool get hasRetentionHold => retentionConflictDetected;

  factory MobilePrivacyRequest.fromJson(Map<String, dynamic> json) {
    return MobilePrivacyRequest(
      requestId: json['request_id'] as String? ?? '',
      tenantId: json['tenant_id'] as String? ?? '',
      branchId: json['branch_id'] as String?,
      subjectType: json['subject_type'] as String? ?? 'PATIENT',
      subjectIdentifier: json['subject_identifier'] as String? ?? '',
      requestType: json['request_type'] as String? ?? '',
      status: json['status'] as String? ?? 'PENDING_ASSESSMENT',
      reason: json['reason'] as String? ?? '',
      retentionConflictDetected:
          json['retention_conflict_detected'] as bool? ?? false,
      retentionHorizonDays: json['retention_horizon_days'] as int? ?? 730,
      exportArtifactUrl: json['export_artifact_url'] as String?,
      assessedByEmail: json['assessed_by_email'] as String?,
      assessedAt: json['assessed_at'] as String?,
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}

/// Flutter Mobile Manager Data Privacy Service.
class MobileDataPrivacyService {
  static const Set<String> validRequestTypes = {
    'DATA_EXPORT',
    'DATA_CORRECTION',
    'DATA_DELETION',
  };

  static const Set<String> allowedAssessmentRoles = {
    'PHARMACY_OWNER',
    'BRANCH_MANAGER',
    'AUDITOR',
    'SUPERADMIN',
  };

  /// Validates DSR input fields before sending network request.
  static bool validateRequestInput(
      String subjectIdentifier, String requestType) {
    if (subjectIdentifier.trim().length < 3) return false;
    if (!validRequestTypes.contains(requestType.toUpperCase())) return false;
    return true;
  }

  /// Evaluates role permissions for privacy assessment.
  static bool isAuthorizedForPrivacyOperations(String userRole) {
    return allowedAssessmentRoles.contains(userRole.toUpperCase());
  }

  /// Determines if statutory retention blocks physical erasure.
  static bool hasStatutoryRetentionConflict(
      bool hasPrescriptionRecords, int daysSincePrescription) {
    return hasPrescriptionRecords && daysSincePrescription < 730;
  }

  /// Localized bilingual error message resolution conforming to ADR-0014 & ADR-0052.
  static Map<String, String> getBilingualErrorMessage(String errorCode) {
    final code = errorCode.toUpperCase();
    if (code == 'ERR_PRIVACY_RETENTION_CONFLICT') {
      return const {
        'en':
            'Data deletion cannot be executed: Active DGDA statutory retention is in effect. PII anonymization is required.',
        'bn':
            'তথ্য মুছে ফেলার অনুরোধ কার্যকর করা যাবে না: ডিজিডিএ রিটেনশন মেয়াদ বলবৎ রয়েছে। শুধুমাত্র পরিচয়হীনকরণ সম্ভব।',
      };
    } else if (code == 'ERR_PERMISSION_DENIED') {
      return const {
        'en':
            'Access denied: Data privacy operations require Owner or Manager authority.',
        'bn':
            'প্রবেশাধিকার প্রত্যাখ্যাত: ডেটা প্রাইভেসি কার্যক্রম পরিচালনার জন্য মালিক বা ম্যানেজারের অনুমতি প্রয়োজন।',
      };
    } else if (code == 'ERR_CROSS_TENANT_VIOLATION') {
      return const {
        'en': 'Cross-tenant privacy request inspection is strictly forbidden.',
        'bn': 'অন্য ফার্মেসির প্রাইভেসি আবেদন পরিদর্শন কঠোরভাবে নিষিদ্ধ।',
      };
    }
    return const {
      'en': 'Data privacy operation failed. Please verify connection.',
      'bn': 'ডেটা প্রাইভেসি পরিচালনায় ত্রুটি দেখা দিয়েছে। সংযোগ পরীক্ষা করুন।',
    };
  }

  /// Maps error codes to MobileUiState.
  static MobileUiState resolveUiState(String errorCode) {
    final code = errorCode.toUpperCase();
    if (code == 'ERR_PERMISSION_DENIED' ||
        code == 'ERR_CROSS_TENANT_VIOLATION') {
      return MobileUiState.permissionDenied;
    }
    return MobileUiState.error;
  }
}
