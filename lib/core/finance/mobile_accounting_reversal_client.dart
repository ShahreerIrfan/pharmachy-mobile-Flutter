// mobile_accounting_reversal_client.dart
// Architecture Decision: ADR-0299 (P299).

class AccountingReversalPermissionException implements Exception {
  final String errorCode;
  final String messageEn;
  final String messageBn;

  AccountingReversalPermissionException({
    required this.errorCode,
    required this.messageEn,
    required this.messageBn,
  });
}

enum ReversalUiState { idle, loading, loaded, empty, offlineCache, permissionDenied, error }

class ReversalRequestDto {
  final String requestId;
  final String originalJournalNumber;
  final String originalTotalBdt;
  final String errorCategory;
  final String reason;
  final String status;
  final String? reversalJournalId;
  final String? replacementJournalId;

  ReversalRequestDto({
    required this.requestId,
    required this.originalJournalNumber,
    required this.originalTotalBdt,
    required this.errorCategory,
    required this.reason,
    required this.status,
    this.reversalJournalId,
    this.replacementJournalId,
  });

  factory ReversalRequestDto.fromJson(Map<String, dynamic> json) {
    return ReversalRequestDto(
      requestId: json['request_id']?.toString() ?? '',
      originalJournalNumber: json['original_journal_number']?.toString() ?? '',
      originalTotalBdt: json['original_total_bdt']?.toString() ?? '0.00',
      errorCategory: json['error_category']?.toString() ?? 'WRONG_AMOUNT',
      reason: json['reason']?.toString() ?? '',
      status: json['status']?.toString() ?? 'PENDING_APPROVAL',
      reversalJournalId: json['reversal_journal_id']?.toString(),
      replacementJournalId: json['replacement_journal_id']?.toString(),
    );
  }

  Map<String, String> localizedStatusLabel() {
    switch (status.toUpperCase()) {
      case 'APPROVED_EXECUTED':
        return {'en': 'Reversed & Posted', 'bn': 'রিভার্সাল সম্পন্ন'};
      case 'REJECTED':
        return {'en': 'Rejected', 'bn': 'প্রত্যাখ্যাত'};
      case 'CANCELLED':
        return {'en': 'Cancelled', 'bn': 'বাতিল'};
      default:
        return {'en': 'Pending Approval', 'bn': 'অনুমোদনের অপেক্ষায়'};
    }
  }
}

class MobileAccountingReversalClient {
  static const Set<String> _approveRoles = {
    'SUPERADMIN',
    'PHARMACY_OWNER',
    'FINANCE_OFFICER',
    'OWNER_ADMIN',
    'ADMIN',
  };

  final String tenantId;
  final String userRole;
  ReversalUiState uiState = ReversalUiState.idle;
  List<ReversalRequestDto> _cache = [];

  MobileAccountingReversalClient({required this.tenantId, required String userRole})
      : userRole = userRole.toUpperCase();

  bool canApprove() => _approveRoles.contains(userRole);

  void assertApproveAuthorized() {
    if (!canApprove()) {
      uiState = ReversalUiState.permissionDenied;
      throw AccountingReversalPermissionException(
        errorCode: 'ERR_REVERSAL_APPROVE_DENIED',
        messageEn: 'Only Pharmacy Owner or Finance Officer can approve accounting reversals.',
        messageBn: 'শুধুমাত্র ফার্মেসি ওনার বা ফিন্যান্স অফিসার রিভার্সাল অনুমোদন করতে পারেন।',
      );
    }
  }

  List<ReversalRequestDto> parseList(Map<String, dynamic> json) {
    final raw = (json['requests'] as List<dynamic>? ?? []);
    final items = raw.map((e) => ReversalRequestDto.fromJson(e as Map<String, dynamic>)).toList();
    _cache = items;
    uiState = items.isEmpty ? ReversalUiState.empty : ReversalUiState.loaded;
    return items;
  }

  List<ReversalRequestDto> loadOfflineFallback() {
    uiState = _cache.isEmpty ? ReversalUiState.empty : ReversalUiState.offlineCache;
    return List.unmodifiable(_cache);
  }
}
