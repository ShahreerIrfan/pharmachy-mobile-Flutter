// mobile_conflict_classification_client.dart
// Architecture Decision: ADR-0313 (P313).
// Phase 16: JavaFX SQLite Offline Store & Reliable Cloud Sync.

enum MobileConflictUiState { idle, loading, loaded, empty, offlineCache, permissionDenied, error }

class MobileConflictTicketDto {
  final String conflictId;
  final String tenantId;
  final String branchId;
  final String branchName;
  final String deviceId;
  final String commandId;
  final String idempotencyKey;
  final int clientSequence;
  final String conflictCategory;
  final String errorCode;
  final String disputedMonetaryBdt;
  final String resolutionStatus;
  final String resolutionNotes;
  final String resolutionReferenceId;
  final String createdAt;

  MobileConflictTicketDto({
    required this.conflictId,
    required this.tenantId,
    required this.branchId,
    required this.branchName,
    required this.deviceId,
    required this.commandId,
    required this.idempotencyKey,
    required this.clientSequence,
    required this.conflictCategory,
    required this.errorCode,
    required this.disputedMonetaryBdt,
    required this.resolutionStatus,
    required this.resolutionNotes,
    required this.resolutionReferenceId,
    required this.createdAt,
  });

  factory MobileConflictTicketDto.fromJson(Map<String, dynamic> json) {
    return MobileConflictTicketDto(
      conflictId: json['conflict_id']?.toString() ?? '',
      tenantId: json['tenant_id']?.toString() ?? '',
      branchId: json['branch_id']?.toString() ?? '',
      branchName: json['branch_name']?.toString() ?? '',
      deviceId: json['device_id']?.toString() ?? '',
      commandId: json['command_id']?.toString() ?? '',
      idempotencyKey: json['idempotency_key']?.toString() ?? '',
      clientSequence: (json['client_sequence'] as num?)?.toInt() ?? 1,
      conflictCategory: json['conflict_category']?.toString() ?? 'STALE_STOCK',
      errorCode: json['error_code']?.toString() ?? 'CONFLICT_STALE_STOCK',
      disputedMonetaryBdt: json['disputed_monetary_bdt']?.toString() ?? '0.00',
      resolutionStatus: json['resolution_status']?.toString() ?? 'OPEN',
      resolutionNotes: json['resolution_notes']?.toString() ?? '',
      resolutionReferenceId: json['resolution_reference_id']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
    );
  }

  Map<String, String> localizedCategoryBadge() {
    switch (conflictCategory.toUpperCase()) {
      case 'STALE_STOCK':
        return {'en': 'Stale Stock / Depleted Batch', 'bn': 'স্টক শেষ / অপর্যাপ্ত ব্যাচ'};
      case 'STALE_PRICE':
        return {'en': 'Stale Price / MRP Variance', 'bn': 'পুরনো মূল্য / এমআরপি অমিল'};
      case 'REVOKED_PERMISSION':
        return {'en': 'Revoked Permission / Inactive User', 'bn': 'বাতিলকৃত অনুমতি / নিষ্ক্রিয় স্টাফ'};
      case 'EXPIRED_SUBSCRIPTION':
        return {'en': 'Expired Subscription / Inactive Lease', 'bn': 'মেয়াদোত্তীর্ণ সাবস্ক্রিপশন / লিজ'};
      case 'UNVERIFIED_PRESCRIPTION':
        return {'en': 'Unverified / Revoked Prescription', 'bn': 'অসত্যায়িত / বাতিল প্রেসক্রিপশন'};
      case 'DUPLICATE_COMMAND_TAMPERED':
        return {'en': 'Tampered Duplicate Command', 'bn': 'ডুপ্লিকেট তথ্যে বিকৃতি / অমিল'};
      default:
        return {'en': conflictCategory, 'bn': conflictCategory};
    }
  }

  Map<String, String> localizedStatusBadge() {
    switch (resolutionStatus.toUpperCase()) {
      case 'OPEN':
        return {'en': 'Needs Manager Review', 'bn': 'ম্যানেজার পর্যালোচনা প্রয়োজন'};
      case 'RESOLVED_KEEP_SERVER':
        return {'en': 'Resolved (Server Maintained)', 'bn': 'সমাধানকৃত (সার্ভার অক্ষুণ্ণ)'};
      case 'RESOLVED_ADJUSTED':
        return {'en': 'Resolved with Adjustment', 'bn': 'সমন্বয় সহ সমাধানকৃত'};
      case 'ESCALATED':
        return {'en': 'Escalated to Owner', 'bn': 'মালিকের নিকট প্রেরিত'};
      case 'REJECTED':
        return {'en': 'Rejected', 'bn': 'প্রত্যাখ্যাত'};
      default:
        return {'en': resolutionStatus, 'bn': resolutionStatus};
    }
  }
}

class MobileConflictSummaryDto {
  final int totalConflicts;
  final int openConflicts;
  final String totalDisputedBdt;
  final Map<String, int> categoryBreakdown;

  MobileConflictSummaryDto({
    required this.totalConflicts,
    required this.openConflicts,
    required this.totalDisputedBdt,
    required this.categoryBreakdown,
  });

  factory MobileConflictSummaryDto.fromJson(Map<String, dynamic> json) {
    final rawMap = json['category_breakdown'] as Map<String, dynamic>? ?? {};
    final breakdown = <String, int>{};
    rawMap.forEach((k, v) {
      breakdown[k] = (v as num).toInt();
    });

    return MobileConflictSummaryDto(
      totalConflicts: (json['total_conflicts'] as num?)?.toInt() ?? 0,
      openConflicts: (json['open_conflicts'] as num?)?.toInt() ?? 0,
      totalDisputedBdt: json['total_disputed_bdt']?.toString() ?? '0.00',
      categoryBreakdown: breakdown,
    );
  }
}

class MobileConflictClassificationClient {
  MobileConflictUiState uiState = MobileConflictUiState.idle;
  List<MobileConflictTicketDto> _cachedTickets = [];
  String lastErrorEn = '';
  String lastErrorBn = '';

  List<MobileConflictTicketDto> parseListResponse(Map<String, dynamic> json) {
    final raw = (json['results'] as List<dynamic>? ?? []);
    final items = raw.map((e) => MobileConflictTicketDto.fromJson(e as Map<String, dynamic>)).toList();
    _cachedTickets = items;
    uiState = items.isEmpty ? MobileConflictUiState.empty : MobileConflictUiState.loaded;
    return items;
  }

  void handleHttpError(int statusCode) {
    if (statusCode == 401 || statusCode == 403) {
      uiState = MobileConflictUiState.permissionDenied;
      lastErrorEn = 'Pharmacy Owner or Branch Manager role required.';
      lastErrorBn = 'ফার্মেসি মালিক বা ব্রাঞ্চ ম্যানেজারের অনুমতি প্রয়োজন।';
    } else {
      uiState = MobileConflictUiState.error;
      lastErrorEn = 'Failed to load sync conflicts (HTTP $statusCode).';
      lastErrorBn = 'সিঙ্ক কনফ্লিক্ট লোড ব্যর্থ হয়েছে (HTTP $statusCode)।';
    }
  }

  List<MobileConflictTicketDto> loadOfflineFallback() {
    uiState = _cachedTickets.isEmpty ? MobileConflictUiState.empty : MobileConflictUiState.offlineCache;
    return List.unmodifiable(_cachedTickets);
  }

  List<MobileConflictTicketDto> filterByCategory(String category) {
    return _cachedTickets.where((t) => t.conflictCategory.toUpperCase() == category.toUpperCase()).toList();
  }

  List<MobileConflictTicketDto> filterByStatus(String status) {
    return _cachedTickets.where((t) => t.resolutionStatus.toUpperCase() == status.toUpperCase()).toList();
  }
}
