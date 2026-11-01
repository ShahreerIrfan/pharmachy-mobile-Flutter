/// ADR-0073: Flutter Mobile Tenant Data Export Client.
/// Governs pharmacy owner export requests, status monitoring,
/// and secure tokenized download URL generation with expiring guardrails.
library mobile_tenant_data_export_client;

class MobileTenantDataExportClient {
  static final RegExp _exportIdPattern = RegExp(r'^tde-[a-z0-9_-]{8,64}$');

  static const Set<String> _allowedRequestRoles = {
    'SUPERADMIN',
    'SUPER_ADMIN',
    'PLATFORM_OPERATOR',
    'PHARMACY_OWNER',
    'OWNER',
  };

  static const Set<String> _allowedApprovalRoles = {
    'SUPERADMIN',
    'SUPER_ADMIN',
    'PLATFORM_OPERATOR',
  };

  static const Set<String> _validFormats = {
    'JSON',
    'CSV',
  };

  /// RBAC Invariant: Only Pharmacy Owners and SuperAdmins can initiate export requests.
  static bool canRoleRequestExport(String? role) {
    if (role == null) return false;
    return _allowedRequestRoles.contains(role.toUpperCase().trim());
  }

  /// RBAC Invariant: Only Platform SuperAdmins can approve or reject export requests.
  static bool canRoleApproveExport(String? role) {
    if (role == null) return false;
    return _allowedApprovalRoles.contains(role.toUpperCase().trim());
  }

  /// Validates export format.
  static bool isValidFormat(String? format) {
    if (format == null) return false;
    return _validFormats.contains(format.toUpperCase().trim());
  }

  /// Validates export identifier syntax.
  static bool isValidExportId(String? exportId) {
    if (exportId == null) return false;
    return _exportIdPattern.hasMatch(exportId.trim());
  }

  /// Verifies state transition validity under ADR-0073.
  static bool canTransition(String? currentStatus, String? targetStatus) {
    if (currentStatus == null || targetStatus == null) return false;
    final cur = currentStatus.toUpperCase().trim();
    final tgt = targetStatus.toUpperCase().trim();

    switch (cur) {
      case 'REQUESTED':
        return tgt == 'APPROVED' || tgt == 'REJECTED';
      case 'APPROVED':
        return tgt == 'PROCESSING' || tgt == 'FAILED';
      case 'PROCESSING':
        return tgt == 'COMPLETED' || tgt == 'FAILED';
      case 'COMPLETED':
        return tgt == 'EXPIRED';
      default:
        return false;
    }
  }

  /// Builds tenant-scoped export list endpoint.
  static String buildTenantExportListUrl() {
    return '/api/v2/tenants/data-exports/';
  }

  /// Builds tenant-scoped export detail endpoint.
  static String buildTenantExportDetailUrl(String exportId) {
    final clean = exportId.trim();
    if (!isValidExportId(clean)) {
      throw ArgumentError('Invalid export ID: \'$exportId\'');
    }
    return '/api/v2/tenants/data-exports/$clean/';
  }

  /// Builds token-authenticated download URL.
  static String buildDownloadUrl(String exportId, String token) {
    final cleanId = exportId.trim();
    if (!isValidExportId(cleanId)) {
      throw ArgumentError('Invalid export ID: \'$exportId\'');
    }
    final cleanToken = token.trim();
    if (cleanToken.isEmpty) {
      throw ArgumentError('Download token must not be empty');
    }
    return '/api/v2/tenants/data-exports/$cleanId/download/?token=$cleanToken';
  }

  /// Builds platform-wide export admin list endpoint.
  static String buildPlatformExportListUrl() {
    return '/api/v2/platform/data-exports/';
  }

  /// Builds platform export approval endpoint.
  static String buildPlatformApproveUrl(String exportId) {
    final clean = exportId.trim();
    if (!isValidExportId(clean)) {
      throw ArgumentError('Invalid export ID: \'$exportId\'');
    }
    return '/api/v2/platform/data-exports/$clean/approve/';
  }

  /// Builds platform export rejection endpoint.
  static String buildPlatformRejectUrl(String exportId) {
    final clean = exportId.trim();
    if (!isValidExportId(clean)) {
      throw ArgumentError('Invalid export ID: \'$exportId\'');
    }
    return '/api/v2/platform/data-exports/$clean/reject/';
  }

  /// Builds platform export revocation endpoint.
  static String buildPlatformRevokeUrl(String exportId) {
    final clean = exportId.trim();
    if (!isValidExportId(clean)) {
      throw ArgumentError('Invalid export ID: \'$exportId\'');
    }
    return '/api/v2/platform/data-exports/$clean/revoke/';
  }
}
