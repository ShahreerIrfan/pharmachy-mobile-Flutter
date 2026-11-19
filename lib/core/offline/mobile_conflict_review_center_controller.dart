// mobile_conflict_review_center_controller.dart
// Architecture Decision: ADR-0314 (P314).
// Phase 16: JavaFX SQLite Offline Store & Reliable Cloud Sync.

enum MobileConflictReviewUiState { idle, loading, loaded, empty, offlineCache, permissionDenied, error }

enum MobileProposedDecisionEnum {
  KEEP_SERVER_DISCARD_LOCAL,
  OVERRIDE_WITH_INVENTORY_ADJUSTMENT,
  SPLIT_BATCH_ALLOCATION,
  ESCALATE_TO_OWNER,
  REJECT_FRAUD
}

class MobileConflictReviewTicketDto {
  final String conflictId;
  final String commandId;
  final String idempotencyKey;
  final int clientSequence;
  final String tenantId;
  final String branchId;
  final String branchName;
  final String conflictCategory;
  final String errorCode;
  final String disputedMonetaryBdt;
  final Map<String, dynamic> localPayload;
  final Map<String, dynamic> serverSnapshot;
  String resolutionStatus;
  String proposedDecision;
  String proposedNotes;
  String approvedBy;
  String approvalNotes;
  Map<String, dynamic> finalCloudOutcome;
  final String createdAt;

  MobileConflictReviewTicketDto({
    required this.conflictId,
    required this.commandId,
    required this.idempotencyKey,
    required this.clientSequence,
    required this.tenantId,
    required this.branchId,
    required this.branchName,
    required this.conflictCategory,
    required this.errorCode,
    required this.disputedMonetaryBdt,
    required this.localPayload,
    required this.serverSnapshot,
    required this.resolutionStatus,
    required this.proposedDecision,
    required this.proposedNotes,
    required this.approvedBy,
    required this.approvalNotes,
    required this.finalCloudOutcome,
    required this.createdAt,
  });

  factory MobileConflictReviewTicketDto.fromJson(Map<String, dynamic> json) {
    return MobileConflictReviewTicketDto(
      conflictId: json['conflict_id']?.toString() ?? '',
      commandId: json['command_id']?.toString() ?? '',
      idempotencyKey: json['idempotency_key']?.toString() ?? '',
      clientSequence: (json['client_sequence'] as num?)?.toInt() ?? 1,
      tenantId: json['tenant_id']?.toString() ?? '',
      branchId: json['branch_id']?.toString() ?? '',
      branchName: json['branch_name']?.toString() ?? '',
      conflictCategory: json['conflict_category']?.toString() ?? 'STALE_STOCK',
      errorCode: json['error_code']?.toString() ?? 'CONFLICT_STALE_STOCK',
      disputedMonetaryBdt: json['disputed_monetary_bdt']?.toString() ?? '0.00',
      localPayload: (json['local_payload_json'] as Map<String, dynamic>?) ?? {},
      serverSnapshot: (json['server_state_snapshot'] as Map<String, dynamic>?) ?? {},
      resolutionStatus: json['resolution_status']?.toString() ?? 'OPEN',
      proposedDecision: json['proposed_decision']?.toString() ?? '',
      proposedNotes: json['proposed_notes']?.toString() ?? '',
      approvedBy: json['approved_by_id']?.toString() ?? '',
      approvalNotes: json['approval_notes']?.toString() ?? '',
      finalCloudOutcome: (json['final_cloud_outcome'] as Map<String, dynamic>?) ?? {},
      createdAt: json['created_at']?.toString() ?? '',
    );
  }

  Map<String, String> localizedStatusBadge() {
    switch (resolutionStatus) {
      case 'DECISION_PROPOSED':
        return {'en': 'Decision Proposed — Awaiting Approval', 'bn': 'সিদ্ধান্ত প্রস্তাবিত — অনুমোদনের অপেক্ষায়'};
      case 'RESOLVED_KEEP_SERVER':
        return {'en': 'Resolved (Cloud Maintained)', 'bn': 'মীমাংসিত (ক্লাউড অক্ষুণ্ণ)'};
      case 'RESOLVED_ADJUSTED':
        return {'en': 'Resolved (Adjustment Posted)', 'bn': 'মীমাংসিত (সমন্বয় দাখিলা)'};
      case 'ESCALATED':
        return {'en': 'Escalated to Owner', 'bn': 'মালিকের নিকট প্রেরিত'};
      case 'REJECTED':
        return {'en': 'Rejected', 'bn': 'প্রত্যাখ্যাত'};
      default:
        return {'en': 'Open Conflict — Needs Review', 'bn': 'উন্মুক্ত বিরোধ — পর্যালোচনা প্রয়োজন'};
    }
  }

  Map<String, String> localizedDecisionBadge() {
    switch (proposedDecision) {
      case 'KEEP_SERVER_DISCARD_LOCAL':
        return {'en': 'Keep Cloud State (Void Local)', 'bn': 'ক্লাউড তথ্য বহাল রাখুন'};
      case 'OVERRIDE_WITH_INVENTORY_ADJUSTMENT':
        return {'en': 'Compensating Inventory Adjustment', 'bn': 'স্টক সমন্বয় দাখিলা'};
      case 'SPLIT_BATCH_ALLOCATION':
        return {'en': 'Split Alternative Batch', 'bn': 'বিকল্প ব্যাচ থেকে পূরণ'};
      case 'ESCALATE_TO_OWNER':
        return {'en': 'Escalate to Owner', 'bn': 'মালিকের নিকট পাঠান'};
      case 'REJECT_FRAUD':
        return {'en': 'Reject Tampered', 'bn': 'বিকৃত হিসেবে বাতিল'};
      default:
        return {'en': proposedDecision, 'bn': proposedDecision};
    }
  }
}

class MobileConflictReviewCenterController {
  MobileConflictReviewUiState uiState = MobileConflictReviewUiState.idle;
  List<MobileConflictReviewTicketDto> _cachedTickets = [];
  String lastErrorEn = '';
  String lastErrorBn = '';

  List<MobileConflictReviewTicketDto> parseTicketsResponse(Map<String, dynamic> json) {
    final raw = (json['results'] as List<dynamic>? ?? []);
    final items = raw.map((e) => MobileConflictReviewTicketDto.fromJson(e as Map<String, dynamic>)).toList();
    _cachedTickets = items;
    uiState = items.isEmpty ? MobileConflictReviewUiState.empty : MobileConflictReviewUiState.loaded;
    return items;
  }

  void handleHttpError(int statusCode) {
    if (statusCode == 401 || statusCode == 403) {
      uiState = MobileConflictReviewUiState.permissionDenied;
      lastErrorEn = 'Pharmacy Owner or Branch Manager role required.';
      lastErrorBn = 'ফার্মেসি মালিক বা ব্রাঞ্চ ম্যানেজারের অনুমতি প্রয়োজন।';
    } else {
      uiState = MobileConflictReviewUiState.error;
      lastErrorEn = 'Failed to load conflict review center (HTTP $statusCode).';
      lastErrorBn = 'বিরোধ পর্যালোচনা কেন্দ্র লোড ব্যর্থ হয়েছে (HTTP $statusCode)।';
    }
  }

  List<MobileConflictReviewTicketDto> loadOfflineFallback() {
    uiState = _cachedTickets.isEmpty ? MobileConflictReviewUiState.empty : MobileConflictReviewUiState.offlineCache;
    return List.unmodifiable(_cachedTickets);
  }

  void applyProposalLocally(String conflictId, MobileProposedDecisionEnum decision, String notes) {
    for (final t in _cachedTickets) {
      if (t.conflictId == conflictId) {
        t.proposedDecision = decision.name;
        t.proposedNotes = notes;
        t.resolutionStatus = 'DECISION_PROPOSED';
        break;
      }
    }
  }

  void applyApprovalLocally(String conflictId, String notes, Map<String, dynamic> cloudOutcome) {
    for (final t in _cachedTickets) {
      if (t.conflictId == conflictId) {
        t.resolutionStatus = 'RESOLVED_ADJUSTED';
        t.approvalNotes = notes;
        t.finalCloudOutcome = cloudOutcome;
        break;
      }
    }
  }

  double computeTotalDisputed() {
    double total = 0.0;
    for (final t in _cachedTickets) {
      if (t.resolutionStatus == 'OPEN' || t.resolutionStatus == 'DECISION_PROPOSED') {
        total += double.tryParse(t.disputedMonetaryBdt) ?? 0.0;
      }
    }
    return total;
  }
}
