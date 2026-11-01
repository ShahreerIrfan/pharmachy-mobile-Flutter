/// ADR-0077: Flutter Mobile Manager Client for Platform Access Policies,
/// MFA Enforcement, Least Privilege, and Zero Implicit Tenant Access.
library mobile_platform_access_client;

class PlatformPolicySecurityException implements Exception {
  final String message;
  const PlatformPolicySecurityException(this.message);

  @override
  String toString() => 'PlatformPolicySecurityException: $message';
}

class MobilePlatformAccessClient {
  static const Set<String> _platformRoles = {
    'SUPERADMIN',
    'SUPER_ADMIN',
    'PLATFORM_OPERATOR',
    'PLATFORM_AUDITOR',
  };

  static const Set<String> _mutationRoles = {
    'SUPERADMIN',
    'SUPER_ADMIN',
  };

  static final RegExp _policyIdPattern = RegExp(r'^pol-[a-z0-9_-]{4,64}$');
  static final RegExp _totpPattern = RegExp(r'^\d{6}$');

  /// Invariant: Platform administrative policy controls are NEVER visible in tenant mobile app.
  static bool isPlatformPolicyManagerVisibleInMobile() => false;

  /// Validates if a role is authorized for platform administrative APIs.
  static bool canAccessPlatformApis(String? role) {
    if (role == null) return false;
    return _platformRoles.contains(role.toUpperCase().trim());
  }

  /// Verifies least privilege: only SuperAdmins may create or modify access policies.
  static bool canMutateSecurityPolicies(String? role) {
    if (role == null) return false;
    return _mutationRoles.contains(role.toUpperCase().trim());
  }

  /// Validates policy ID format.
  static bool isValidPolicyId(String? policyId) {
    if (policyId == null) return false;
    return _policyIdPattern.hasMatch(policyId.trim());
  }

  /// Validates 6-digit TOTP format.
  static bool isValidTotpCode(String? code) {
    if (code == null) return false;
    return _totpPattern.hasMatch(code.trim());
  }

  /// Zero Implicit Tenant Access Guardrail.
  static bool enforceZeroImplicitTenantAccess({
    required String role,
    required String targetPath,
    String? supportGrantToken,
  }) {
    final isPlatform = canAccessPlatformApis(role);
    final isTenantPrivate = targetPath.startsWith('/api/v2/tenants/') &&
        !targetPath.contains('/announcements');

    if (isPlatform && isTenantPrivate) {
      if (supportGrantToken == null || supportGrantToken.trim().isEmpty) {
        throw const PlatformPolicySecurityException(
          'Zero Implicit Tenant Access Denied: Delegated support grant token required.',
        );
      }
    }
    return true;
  }

  /// Builds request headers.
  static Map<String, String> buildPlatformHeaders({
    required String role,
    String? mfaSessionToken,
    String? stepUpCode,
    String? supportGrantToken,
  }) {
    if (!canAccessPlatformApis(role)) {
      throw PlatformPolicySecurityException(
        'Role \'$role\' is not authorized for platform administration.',
      );
    }

    final headers = <String, String>{
      'X-Platform-Role': role.toUpperCase().trim(),
    };

    if (mfaSessionToken != null && mfaSessionToken.trim().isNotEmpty) {
      headers['X-MFA-Session-Token'] = mfaSessionToken.trim();
      headers['X-MFA-Verified'] = 'true';
    }

    if (stepUpCode != null && stepUpCode.trim().isNotEmpty) {
      if (!isValidTotpCode(stepUpCode)) {
        throw ArgumentError('Step-up MFA code must be exactly 6 digits.');
      }
      headers['X-MFA-Code'] = stepUpCode.trim();
    }

    if (supportGrantToken != null && supportGrantToken.trim().isNotEmpty) {
      headers['X-Support-Grant-Token'] = supportGrantToken.trim();
    }

    return Map.unmodifiable(headers);
  }

  static String getPoliciesUrl() => '/api/v2/platform/access-policies/';

  static String getPolicyDetailUrl(String policyId) {
    if (!isValidPolicyId(policyId)) {
      throw ArgumentError('Invalid policy ID format: $policyId');
    }
    return '/api/v2/platform/access-policies/${policyId.trim()}/';
  }

  static String getEvaluateUrl() => '/api/v2/platform/access-policies/evaluate/';

  static String getVerifyStepUpUrl() =>
      '/api/v2/platform/access-policies/verify-step-up/';
}
