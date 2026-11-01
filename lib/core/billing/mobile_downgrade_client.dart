// lib/core/billing/mobile_downgrade_client.dart
// Architecture Decision: ADR-0007, ADR-0015, ADR-0081, ADR-0083 & ADR-0091
// Phase 05: Basic/Standard/Pro Subscription & Billing (P091)

enum MobileDowngradeStatus {
  scheduled,
  applied,
  cancelled,
  unknown,
}

class MobileQuotaAssessment {
  final int currentActiveBranches;
  final int targetAllowedBranches;
  final bool isOverQuota;
  final List<String> retainedBranchIds;
  final List<String> lockedBranchIds;

  const MobileQuotaAssessment({
    required this.currentActiveBranches,
    required this.targetAllowedBranches,
    required this.isOverQuota,
    required this.retainedBranchIds,
    required this.lockedBranchIds,
  });

  factory MobileQuotaAssessment.fromJson(Map<String, dynamic> json) {
    return MobileQuotaAssessment(
      currentActiveBranches: (json['current_active_branches'] as num?)?.toInt() ?? 0,
      targetAllowedBranches: (json['target_allowed_branches'] as num?)?.toInt() ?? 1,
      isOverQuota: json['is_over_quota'] as bool? ?? false,
      retainedBranchIds: (json['retained_branch_ids'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      lockedBranchIds: (json['locked_branch_ids'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        'current_active_branches': currentActiveBranches,
        'target_allowed_branches': targetAllowedBranches,
        'is_over_quota': isOverQuota,
        'retained_branch_ids': retainedBranchIds,
        'locked_branch_ids': lockedBranchIds,
      };
}

class MobileDataRetentionGuarantee {
  final bool zeroDataDeleted;
  final bool historicalSalesReadable;
  final bool stockLedgerPreserved;

  const MobileDataRetentionGuarantee({
    this.zeroDataDeleted = true,
    this.historicalSalesReadable = true,
    this.stockLedgerPreserved = true,
  });

  factory MobileDataRetentionGuarantee.fromJson(Map<String, dynamic> json) {
    return MobileDataRetentionGuarantee(
      zeroDataDeleted: json['zero_data_deleted'] as bool? ?? true,
      historicalSalesReadable: json['historical_sales_readable'] as bool? ?? true,
      stockLedgerPreserved: json['stock_ledger_preserved'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'zero_data_deleted': zeroDataDeleted,
        'historical_sales_readable': historicalSalesReadable,
        'stock_ledger_preserved': stockLedgerPreserved,
      };
}

class MobileSubscriptionDowngradeModel {
  final String downgradeId;
  final String tenantId;
  final String subscriptionId;
  final String fromPlanTier;
  final String fromPlanCode;
  final String toPlanTier;
  final String toPlanCode;
  final String effectiveMode;
  final MobileQuotaAssessment quotaAssessment;
  final MobileDataRetentionGuarantee dataRetentionGuarantee;
  final MobileDowngradeStatus status;
  final String? appliedEntitlementId;
  final DateTime createdAt;
  final DateTime? executedAt;

  const MobileSubscriptionDowngradeModel({
    required this.downgradeId,
    required this.tenantId,
    required this.subscriptionId,
    required this.fromPlanTier,
    required this.fromPlanCode,
    required this.toPlanTier,
    required this.toPlanCode,
    required this.effectiveMode,
    required this.quotaAssessment,
    required this.dataRetentionGuarantee,
    required this.status,
    this.appliedEntitlementId,
    required this.createdAt,
    this.executedAt,
  });

  bool get isApplied => status == MobileDowngradeStatus.applied;
  bool get isScheduled => status == MobileDowngradeStatus.scheduled;
  bool get isOverQuota => quotaAssessment.isOverQuota;

  static MobileDowngradeStatus parseStatus(String raw) {
    switch (raw.toUpperCase().trim()) {
      case 'SCHEDULED':
        return MobileDowngradeStatus.scheduled;
      case 'APPLIED':
        return MobileDowngradeStatus.applied;
      case 'CANCELLED':
        return MobileDowngradeStatus.cancelled;
      default:
        return MobileDowngradeStatus.unknown;
    }
  }

  factory MobileSubscriptionDowngradeModel.fromJson(Map<String, dynamic> json) {
    return MobileSubscriptionDowngradeModel(
      downgradeId: json['downgrade_id'] as String? ?? '',
      tenantId: json['tenant_id'] as String? ?? '',
      subscriptionId: json['subscription_id'] as String? ?? '',
      fromPlanTier: json['from_plan_tier'] as String? ?? 'PRO',
      fromPlanCode: json['from_plan_code'] as String? ?? '',
      toPlanTier: json['to_plan_tier'] as String? ?? 'BASIC',
      toPlanCode: json['to_plan_code'] as String? ?? '',
      effectiveMode: json['effective_mode'] as String? ?? 'IMMEDIATE',
      quotaAssessment: MobileQuotaAssessment.fromJson(
        json['quota_assessment'] as Map<String, dynamic>? ?? {},
      ),
      dataRetentionGuarantee: MobileDataRetentionGuarantee.fromJson(
        json['data_retention_guarantee'] as Map<String, dynamic>? ?? {},
      ),
      status: parseStatus(json['status'] as String? ?? 'APPLIED'),
      appliedEntitlementId: json['applied_entitlement_id'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      executedAt: json['executed_at'] != null ? DateTime.tryParse(json['executed_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'downgrade_id': downgradeId,
        'tenant_id': tenantId,
        'subscription_id': subscriptionId,
        'from_plan_tier': fromPlanTier,
        'from_plan_code': fromPlanCode,
        'to_plan_tier': toPlanTier,
        'to_plan_code': toPlanCode,
        'effective_mode': effectiveMode,
        'quota_assessment': quotaAssessment.toJson(),
        'data_retention_guarantee': dataRetentionGuarantee.toJson(),
        'status': status.name.toUpperCase(),
        'applied_entitlement_id': appliedEntitlementId,
        'created_at': createdAt.toIso8601String(),
        'executed_at': executedAt?.toIso8601String(),
      };
}
