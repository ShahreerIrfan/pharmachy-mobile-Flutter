// lib/core/billing/mobile_offline_plan_lapse_client.dart
// Architecture Decision: ADR-0007, ADR-0082, ADR-0092 & ADR-0094
// Phase 05: Basic/Standard/Pro Subscription & Billing (P094)
// Requirement Trace: FR-072 (Do not silently discard valid pending events if plan lapses)

enum MobileHoldQueueStatus {
  heldPendingReconciliation,
  reconciled,
  rejected,
  unknown,
}

class MobileLapsedHoldRecord {
  final String holdId;
  final String tenantId;
  final String branchId;
  final String deviceId;
  final String offlineEventId;
  final String eventType;
  final DateTime occurredAt;
  final String financialTotalBdt;
  final String subscriptionStatusAtIntake;
  final MobileHoldQueueStatus holdStatus;
  final DateTime? reconciledAt;
  final String? reconciledBy;
  final String? reconciliationTargetId;
  final String headlineEn;
  final String headlineBn;
  final String detailsEn;
  final String detailsBn;

  const MobileLapsedHoldRecord({
    required this.holdId,
    required this.tenantId,
    required this.branchId,
    required this.deviceId,
    required this.offlineEventId,
    required this.eventType,
    required this.occurredAt,
    required this.financialTotalBdt,
    required this.subscriptionStatusAtIntake,
    required this.holdStatus,
    this.reconciledAt,
    this.reconciledBy,
    this.reconciliationTargetId,
    required this.headlineEn,
    required this.headlineBn,
    required this.detailsEn,
    required this.detailsBn,
  });

  factory MobileLapsedHoldRecord.fromJson(Map<String, dynamic> json) {
    final statusStr = (json['hold_status'] as String? ?? '').toUpperCase().trim();
    MobileHoldQueueStatus status;
    switch (statusStr) {
      case 'HELD_PENDING_RECONCILIATION':
        status = MobileHoldQueueStatus.heldPendingReconciliation;
        break;
      case 'RECONCILED':
        status = MobileHoldQueueStatus.reconciled;
        break;
      case 'REJECTED':
        status = MobileHoldQueueStatus.rejected;
        break;
      default:
        status = MobileHoldQueueStatus.unknown;
    }

    final msg = json['client_messaging'] as Map<String, dynamic>? ?? {};

    return MobileLapsedHoldRecord(
      holdId: json['hold_id'] as String? ?? '',
      tenantId: json['tenant_id'] as String? ?? '',
      branchId: json['branch_id'] as String? ?? '',
      deviceId: json['device_id'] as String? ?? '',
      offlineEventId: json['offline_event_id'] as String? ?? '',
      eventType: json['event_type'] as String? ?? 'OFFLINE_SALE',
      occurredAt: DateTime.tryParse(json['occurred_at'] as String? ?? '') ?? DateTime.now(),
      financialTotalBdt: json['financial_total_bdt'] as String? ?? '0.00',
      subscriptionStatusAtIntake: json['subscription_status_at_intake'] as String? ?? 'EXPIRED',
      holdStatus: status,
      reconciledAt: json['reconciled_at'] != null ? DateTime.tryParse(json['reconciled_at'] as String) : null,
      reconciledBy: json['reconciled_by'] as String?,
      reconciliationTargetId: json['reconciliation_target_id'] as String?,
      headlineEn: msg['headline_en'] as String? ?? 'Held Pending Reconciliation',
      headlineBn: msg['headline_bn'] as String? ?? 'রিকনসিলিয়েশনের অপেক্ষায় জমা',
      detailsEn: msg['details_en'] as String? ?? '',
      detailsBn: msg['details_bn'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'hold_id': holdId,
        'tenant_id': tenantId,
        'branch_id': branchId,
        'device_id': deviceId,
        'offline_event_id': offlineEventId,
        'event_type': eventType,
        'occurred_at': occurredAt.toIso8601String(),
        'financial_total_bdt': financialTotalBdt,
        'subscription_status_at_intake': subscriptionStatusAtIntake,
        'hold_status': holdStatus.name.toUpperCase(),
        'reconciled_at': reconciledAt?.toIso8601String(),
        'reconciled_by': reconciledBy,
        'reconciliation_target_id': reconciliationTargetId,
        'client_messaging': {
          'headline_en': headlineEn,
          'headline_bn': headlineBn,
          'details_en': detailsEn,
          'details_bn': detailsBn,
        },
      };

  bool get isReconciled => holdStatus == MobileHoldQueueStatus.reconciled;
}

class MobileHoldQueueSummary {
  final String tenantId;
  final int pendingCount;
  final String totalPendingAmountBdt;
  final int reconciledCount;
  final String headlineEn;
  final String headlineBn;
  final String detailsEn;
  final String detailsBn;

  const MobileHoldQueueSummary({
    required this.tenantId,
    required this.pendingCount,
    required this.totalPendingAmountBdt,
    required this.reconciledCount,
    required this.headlineEn,
    required this.headlineBn,
    required this.detailsEn,
    required this.detailsBn,
  });

  factory MobileHoldQueueSummary.fromJson(Map<String, dynamic> json) {
    final msg = json['client_messaging'] as Map<String, dynamic>? ?? {};

    return MobileHoldQueueSummary(
      tenantId: json['tenant_id'] as String? ?? '',
      pendingCount: (json['pending_count'] as num?)?.toInt() ?? 0,
      totalPendingAmountBdt: json['total_pending_amount_bdt'] as String? ?? '0.00',
      reconciledCount: (json['reconciled_count'] as num?)?.toInt() ?? 0,
      headlineEn: msg['headline_en'] as String? ?? '',
      headlineBn: msg['headline_bn'] as String? ?? '',
      detailsEn: msg['details_en'] as String? ?? '',
      detailsBn: msg['details_bn'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'tenant_id': tenantId,
        'pending_count': pendingCount,
        'total_pending_amount_bdt': totalPendingAmountBdt,
        'reconciled_count': reconciledCount,
        'client_messaging': {
          'headline_en': headlineEn,
          'headline_bn': headlineBn,
          'details_en': detailsEn,
          'details_bn': detailsBn,
        },
      };

  bool get hasPendingItems => pendingCount > 0;
}

