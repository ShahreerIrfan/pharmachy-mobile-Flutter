/// ADR-0078: Flutter Mobile Platform Audit Search Client & Sanitization Guard.
library mobile_platform_audit_search_client;

class PlatformAuditSecurityException implements Exception {
  final String message;
  const PlatformAuditSecurityException(this.message);

  @override
  String toString() => 'PlatformAuditSecurityException: $message';
}

class MobilePlatformAuditSearchClient {
  static const Set<String> _authorizedRoles = {
    'SUPERADMIN',
    'SUPER_ADMIN',
    'PLATFORM_OPERATOR',
    'PLATFORM_AUDITOR',
  };

  static const Set<String> _forbiddenKeys = {
    'password',
    'secret',
    'token',
    'authorization',
    'access_token',
    'refresh_token',
    'secret_key',
    'otp',
    'pin',
    'cvv',
    'card_number',
    'diagnosis',
    'clinical_notes',
    'prescription_image',
  };

  static final RegExp _entryIdPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  /// Invariant: Platform audit search controls are NEVER visible in tenant mobile app.
  static bool isAuditSearchVisibleInMobile() => false;

  /// Validates whether a user role is permitted to search platform audits.
  static bool canSearchPlatformAudit(String? role) {
    if (role == null) return false;
    return _authorizedRoles.contains(role.toUpperCase().trim());
  }

  /// Identifies if a key is a forbidden credential or PHI field.
  static bool isForbiddenPayloadKey(String? key) {
    if (key == null) return false;
    final lower = key.toLowerCase().trim();
    for (final f in _forbiddenKeys) {
      if (lower.contains(f)) return true;
    }
    return false;
  }

  /// Validates date range constraints.
  static bool validateDateRange(String? dateFrom, String? dateTo) {
    if (dateFrom == null || dateTo == null) return true;
    try {
      final from = DateTime.parse(dateFrom.trim());
      final to = DateTime.parse(dateTo.trim());
      return !to.isBefore(from);
    } catch (_) {
      return false;
    }
  }

  /// Sanitizes payload maps by redacting forbidden keys.
  static Map<String, dynamic> sanitizePayload(Map<String, dynamic>? input) {
    if (input == null) return const {};
    final sanitized = <String, dynamic>{};
    for (final entry in input.entries) {
      if (isForbiddenPayloadKey(entry.key)) {
        sanitized[entry.key] = '[REDACTED]';
      } else if (entry.value is Map<String, dynamic>) {
        sanitized[entry.key] = sanitizePayload(entry.value as Map<String, dynamic>);
      } else {
        sanitized[entry.key] = entry.value;
      }
    }
    return Map.unmodifiable(sanitized);
  }

  static bool isValidEntryId(String? entryId) {
    if (entryId == null) return false;
    return _entryIdPattern.hasMatch(entryId.trim());
  }

  static String getSearchUrl() => '/api/v2/platform/audit-search/';

  static String getDetailUrl(String entryId) {
    if (!isValidEntryId(entryId)) {
      throw ArgumentError('Invalid audit entry ID format: $entryId');
    }
    return '/api/v2/platform/audit-search/${entryId.trim()}/';
  }

  static String getExportUrl() => '/api/v2/platform/audit-search/export/';
}
