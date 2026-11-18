// mobile_accounting_export_client.dart
// Architecture Decision: ADR-0298 (P298).
// Phase 15: General Ledger, Operating Expenses & Profitability.

class AccountingExportPermissionException implements Exception {
  final String errorCode;
  final String messageEn;
  final String messageBn;

  AccountingExportPermissionException({
    required this.errorCode,
    required this.messageEn,
    required this.messageBn,
  });
}

enum ExportUiState { idle, loading, loaded, empty, offlineCache, permissionDenied, error }

class AccountingSnapshotDto {
  final String snapshotId;
  final String reportType;
  final String title;
  final String? branchId;
  final String branchName;
  final bool isBookBalanced;
  final String totalDebitsBdt;
  final String totalCreditsBdt;
  final int rowCount;
  final String sha256Digest;
  final String status;

  AccountingSnapshotDto({
    required this.snapshotId,
    required this.reportType,
    required this.title,
    this.branchId,
    required this.branchName,
    required this.isBookBalanced,
    required this.totalDebitsBdt,
    required this.totalCreditsBdt,
    required this.rowCount,
    required this.sha256Digest,
    required this.status,
  });

  factory AccountingSnapshotDto.fromJson(Map<String, dynamic> json) {
    return AccountingSnapshotDto(
      snapshotId: json['snapshot_id']?.toString() ?? '',
      reportType: json['report_type']?.toString() ?? 'TRIAL_BALANCE',
      title: json['title']?.toString() ?? '',
      branchId: json['branch_id']?.toString(),
      branchName: json['branch_name']?.toString() ?? 'All Branches (Consolidated)',
      isBookBalanced: json['is_book_balanced'] as bool? ?? true,
      totalDebitsBdt: json['total_debits_bdt']?.toString() ?? '0.00',
      totalCreditsBdt: json['total_credits_bdt']?.toString() ?? '0.00',
      rowCount: (json['row_count'] as num?)?.toInt() ?? 0,
      sha256Digest: json['sha256_digest']?.toString() ?? '',
      status: json['status']?.toString() ?? 'FINALIZED',
    );
  }

  Map<String, String> localizedBalanceBadge() {
    return isBookBalanced
        ? {'en': 'Balanced Books', 'bn': 'হিসাব সমতায় আছে'}
        : {'en': 'Imbalance Detected', 'bn': 'হিসাবে অসামঞ্জস্য পাওয়া গেছে'};
  }
}

class MobileAccountingExportClient {
  static const Set<String> _viewRoles = {
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

  ExportUiState uiState = ExportUiState.idle;
  List<AccountingSnapshotDto> _offlineSnapshots = [];

  MobileAccountingExportClient({
    required this.tenantId,
    required this.branchId,
    required String userRole,
  }) : userRole = userRole.toUpperCase();

  bool canAccessScope({String? targetBranchId}) {
    if (!_viewRoles.contains(userRole)) return false;
    if (userRole == 'BRANCH_MANAGER') {
      return targetBranchId != null && targetBranchId == branchId;
    }
    return true;
  }

  List<AccountingSnapshotDto> parseSnapshotsResponse(Map<String, dynamic> json, {String? targetBranchId}) {
    if (!canAccessScope(targetBranchId: targetBranchId)) {
      uiState = ExportUiState.permissionDenied;
      throw AccountingExportPermissionException(
        errorCode: 'ERR_EXPORT_SCOPE_DENIED',
        messageEn: 'You do not have permission to view accounting exports for this scope.',
        messageBn: 'এই শাখার অ্যাকাউন্টিং এক্সপোর্ট দেখার অনুমতি আপনার নেই।',
      );
    }
    final raw = (json['snapshots'] as List<dynamic>? ?? []);
    final items = raw.map((e) => AccountingSnapshotDto.fromJson(e as Map<String, dynamic>)).toList();
    _offlineSnapshots = items;
    uiState = items.isEmpty ? ExportUiState.empty : ExportUiState.loaded;
    return items;
  }

  List<AccountingSnapshotDto> loadOfflineFallback() {
    if (_offlineSnapshots.isEmpty) {
      uiState = ExportUiState.empty;
      return const [];
    }
    uiState = ExportUiState.offlineCache;
    return List.unmodifiable(_offlineSnapshots);
  }
}
