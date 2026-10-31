import 'package:pharmacy_mobile_manager/core/contracts/mobile_api_response_envelope.dart';

/// Flutter Mobile Manager Tenant Context & Signed Claims Security Service.
/// Architecture Decision: ADR-0049 (Trusted Tenant Context Resolution Middleware).
/// Resolves tenant and active branch from trusted signed claims; never trusts client-supplied tenant IDs alone.
class MobileTenantContext {
  final String tenantId;
  final String tenantName;
  final String subdomain;
  final String planTier;
  final String? branchId;
  final String? branchName;
  final String? userId;
  final String? userRole;
  final String resolutionSource;
  final bool isActive;

  const MobileTenantContext({
    required this.tenantId,
    required this.tenantName,
    required this.subdomain,
    required this.planTier,
    this.branchId,
    this.branchName,
    this.userId,
    this.userRole,
    this.resolutionSource = 'JWT_SIGNED_CLAIMS',
    this.isActive = true,
  });

  factory MobileTenantContext.fromJson(Map<String, dynamic> json) {
    return MobileTenantContext(
      tenantId: json['tenant_id'] as String? ?? '',
      tenantName: json['tenant_name'] as String? ?? 'Unknown Pharmacy',
      subdomain: json['subdomain'] as String? ?? 'unknown',
      planTier: json['plan_tier'] as String? ?? 'STANDARD',
      branchId: json['branch_id'] as String?,
      branchName: json['branch_name'] as String?,
      userId: json['user_id'] as String?,
      userRole: json['user_role'] as String? ?? 'PHARMACY_OWNER',
      resolutionSource:
          json['resolution_source'] as String? ?? 'JWT_SIGNED_CLAIMS',
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'tenant_id': tenantId,
        'tenant_name': tenantName,
        'subdomain': subdomain,
        'plan_tier': planTier,
        'branch_id': branchId,
        'branch_name': branchName,
        'user_id': userId,
        'user_role': userRole,
        'resolution_source': resolutionSource,
        'is_active': isActive,
      };
}

class MobileTenantContextService {
  static MobileTenantContext? _activeContext;

  static void setActiveContext(MobileTenantContext? context) {
    _activeContext = context;
  }

  static MobileTenantContext? getActiveContext() => _activeContext;

  static void clear() {
    _activeContext = null;
  }

  /// Verifies tenant integrity against active session claims.
  static bool validateTenantIntegrity({
    required MobileTenantContext context,
    required String requestedTenantId,
  }) {
    return context.tenantId.trim().toLowerCase() ==
        requestedTenantId.trim().toLowerCase();
  }

  /// Verifies branch integrity against active session claims.
  static bool validateBranchIntegrity({
    required MobileTenantContext context,
    required String requestedBranchId,
  }) {
    if (context.branchId == null) return true;
    return context.branchId!.trim().toLowerCase() ==
        requestedBranchId.trim().toLowerCase();
  }

  /// Returns bilingual error messages conforming to ADR-0049.
  static Map<String, String> getBilingualErrorMessage(String errorCode) {
    switch (errorCode.toUpperCase()) {
      case 'ERR_CROSS_TENANT_VIOLATION':
        return {
          'en':
              'Cross-tenant access violation: Access to another pharmacy\'s data is strictly forbidden.',
          'bn':
              'অন্য ফার্মেসির তথ্যে প্রবেশাধিকার কঠোরভাবে নিষিদ্ধ। ক্লায়েন্ট প্রদত্ত টেন্যান্ট আইডি মেলেনি।',
        };
      case 'ERR_TENANT_INACTIVE':
        return {
          'en':
              'This pharmacy tenant account is inactive or suspended. Please contact platform support.',
          'bn':
              'এই ফার্মেসি অ্যাকাউন্টটি নিষ্ক্রিয় বা স্থগিত রয়েছে। প্ল্যাটফর্ম সাপোর্টের সাথে যোগাযোগ করুন।',
        };
      case 'ERR_BRANCH_NOT_FOUND':
      case 'ERR_BRANCH_INACTIVE':
        return {
          'en':
              'Dispensary branch is inactive or does not belong to your active pharmacy tenant.',
          'bn':
              'শাখাটি নিষ্ক্রিয় অথবা এটি আপনার অনুমোদিত ফার্মেসির অন্তর্ভুক্ত নয়।',
        };
      default:
        return {
          'en': 'Tenant authorization failed. Please contact your manager.',
          'bn':
              'টেন্যান্ট অনুমোদনে ব্যর্থ হয়েছে। অনুগ্রহ করে ম্যানেজারের সাথে যোগাযোগ করুন।',
        };
    }
  }

  /// Resolves Mobile UI State based on tenant context error codes.
  static MobileUiState resolveUiState(String errorCode) {
    final code = errorCode.toUpperCase();
    if (code == 'ERR_CROSS_TENANT_VIOLATION' ||
        code == 'ERR_TENANT_INACTIVE' ||
        code == 'ERR_BRANCH_NOT_FOUND') {
      return MobileUiState.permissionDenied;
    }
    return MobileUiState.error;
  }
}
