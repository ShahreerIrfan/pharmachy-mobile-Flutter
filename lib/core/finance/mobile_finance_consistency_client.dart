// mobile_finance_consistency_client.dart
// Architecture Decision: ADR-0300 (P300).

class FinanceConsistencyPermissionException implements Exception {
  final String errorCode;
  final String messageEn;
  final String messageBn;

  FinanceConsistencyPermissionException({
    required this.errorCode,
    required this.messageEn,
    required this.messageBn,
  });
}

enum AuditUiState { idle, loading, consistent, discrepancyDetected, offlineCache, permissionDenied, error }

class ConsistencyAuditDto {
  final String overallStatus;
  final int passedChecks;
  final int totalChecks;

  ConsistencyAuditDto({
    required this.overallStatus,
    required this.passedChecks,
    required this.totalChecks,
  });

  factory ConsistencyAuditDto.fromJson(Map<String, dynamic> json) {
    return ConsistencyAuditDto(
      overallStatus: json['overall_status']?.toString() ?? 'DISCREPANCY_DETECTED',
      passedChecks: (json['passed_checks'] as num?)?.toInt() ?? 0,
      totalChecks: (json['total_checks'] as num?)?.toInt() ?? 6,
    );
  }

  Map<String, String> localizedSummary() {
    return overallStatus == 'CONSISTENT'
        ? {'en': 'All Books Consistent ($passedChecks/$totalChecks)', 'bn': 'সকল হিসাব সামঞ্জস্যপূর্ণ ($passedChecks/$totalChecks)'}
        : {'en': 'Discrepancy Detected ($passedChecks/$totalChecks)', 'bn': 'হিসাবে অসামঞ্জস্য পাওয়া গেছে ($passedChecks/$totalChecks)'};
  }
}

class MobileFinanceConsistencyClient {
  static const Set<String> _auditRoles = {
    'SUPERADMIN',
    'PHARMACY_OWNER',
    'FINANCE_OFFICER',
    'BRANCH_MANAGER',
    'AUDITOR',
    'OWNER_ADMIN',
    'ADMIN',
  };

  final String tenantId;
  final String branchId;
  final String userRole;
  AuditUiState uiState = AuditUiState.idle;
  ConsistencyAuditDto? _lastCached;

  MobileFinanceConsistencyClient({
    required this.tenantId,
    required this.branchId,
    required String userRole,
  }) : userRole = userRole.toUpperCase();

  bool canAudit({String? targetBranchId}) {
    if (!_auditRoles.contains(userRole)) return false;
    if (userRole == 'BRANCH_MANAGER') {
      return targetBranchId != null && targetBranchId == branchId;
    }
    return true;
  }

  ConsistencyAuditDto parseAuditResponse(Map<String, dynamic> json, {String? targetBranchId}) {
    if (!canAudit(targetBranchId: targetBranchId)) {
      uiState = AuditUiState.permissionDenied;
      throw FinanceConsistencyPermissionException(
        errorCode: 'ERR_AUDIT_SCOPE_DENIED',
        messageEn: 'Not authorized to run finance consistency audit.',
        messageBn: 'ফিন্যান্স কনসিস্টেন্সি অডিট চালানোর অনুমতি আপনার নেই।',
      );
    }
    final dto = ConsistencyAuditDto.fromJson(json);
    _lastCached = dto;
    uiState = dto.overallStatus == 'CONSISTENT' ? AuditUiState.consistent : AuditUiState.discrepancyDetected;
    return dto;
  }

  ConsistencyAuditDto? loadOfflineFallback() {
    if (_lastCached != null) {
      uiState = AuditUiState.offlineCache;
    }
    return _lastCached;
  }
}
