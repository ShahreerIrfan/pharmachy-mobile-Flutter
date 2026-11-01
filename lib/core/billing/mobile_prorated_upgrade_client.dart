// lib/core/billing/mobile_prorated_upgrade_client.dart
// Architecture Decision: ADR-0007, ADR-0015, ADR-0081, ADR-0083 & ADR-0090
// Phase 05: Basic/Standard/Pro Subscription & Billing (P090)

enum MobileUpgradeStatus {
  quoted,
  pendingPayment,
  completed,
  cancelled,
  unknown,
}

class MobileProrationDays {
  final int totalDays;
  final int usedDays;
  final int remainingDays;

  const MobileProrationDays({
    required this.totalDays,
    required this.usedDays,
    required this.remainingDays,
  });

  factory MobileProrationDays.fromJson(Map<String, dynamic> json) {
    return MobileProrationDays(
      totalDays: (json['total_days'] as num?)?.toInt() ?? 30,
      usedDays: (json['used_days'] as num?)?.toInt() ?? 0,
      remainingDays: (json['remaining_days'] as num?)?.toInt() ?? 30,
    );
  }

  Map<String, dynamic> toJson() => {
    'total_days': totalDays,
    'used_days': usedDays,
    'remaining_days': remainingDays,
  };
}

class MobileUpgradeFinancials {
  final double currentPlanAmountBdt;
  final double currentDailyRateBdt;
  final double unusedCreditBdt;
  final double targetPlanAmountBdt;
  final double targetDailyRateBdt;
  final double proratedTargetGrossBdt;
  final double taxAmountBdt;
  final double netPayableBdt;

  const MobileUpgradeFinancials({
    required this.currentPlanAmountBdt,
    required this.currentDailyRateBdt,
    required this.unusedCreditBdt,
    required this.targetPlanAmountBdt,
    required this.targetDailyRateBdt,
    required this.proratedTargetGrossBdt,
    required this.taxAmountBdt,
    required this.netPayableBdt,
  });

  factory MobileUpgradeFinancials.fromJson(Map<String, dynamic> json) {
    return MobileUpgradeFinancials(
      currentPlanAmountBdt: (json['current_plan_amount_bdt'] as num?)?.toDouble() ?? 0.0,
      currentDailyRateBdt: (json['current_daily_rate_bdt'] as num?)?.toDouble() ?? 0.0,
      unusedCreditBdt: (json['unused_credit_bdt'] as num?)?.toDouble() ?? 0.0,
      targetPlanAmountBdt: (json['target_plan_amount_bdt'] as num?)?.toDouble() ?? 0.0,
      targetDailyRateBdt: (json['target_daily_rate_bdt'] as num?)?.toDouble() ?? 0.0,
      proratedTargetGrossBdt: (json['prorated_target_gross_bdt'] as num?)?.toDouble() ?? 0.0,
      taxAmountBdt: (json['tax_amount_bdt'] as num?)?.toDouble() ?? 0.0,
      netPayableBdt: (json['net_payable_bdt'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'current_plan_amount_bdt': currentPlanAmountBdt,
    'current_daily_rate_bdt': currentDailyRateBdt,
    'unused_credit_bdt': unusedCreditBdt,
    'target_plan_amount_bdt': targetPlanAmountBdt,
    'target_daily_rate_bdt': targetDailyRateBdt,
    'prorated_target_gross_bdt': proratedTargetGrossBdt,
    'tax_amount_bdt': taxAmountBdt,
    'net_payable_bdt': netPayableBdt,
  };
}

class MobileProratedUpgradeModel {
  final String upgradeId;
  final String tenantId;
  final String subscriptionId;
  final String fromPlanTier;
  final String fromPlanCode;
  final String fromBillingCycle;
  final String toPlanTier;
  final String toPlanCode;
  final String toBillingCycle;
  final DateTime transitionTimestamp;
  final MobileProrationDays prorationDays;
  final MobileUpgradeFinancials financials;
  final MobileUpgradeStatus status;
  final String? invoiceNumber;
  final String? invoiceId;
  final bool immediateEntitlementGranted;
  final String? appliedEntitlementId;

  const MobileProratedUpgradeModel({
    required this.upgradeId,
    required this.tenantId,
    required this.subscriptionId,
    required this.fromPlanTier,
    required this.fromPlanCode,
    required this.fromBillingCycle,
    required this.toPlanTier,
    required this.toPlanCode,
    required this.toBillingCycle,
    required this.transitionTimestamp,
    required this.prorationDays,
    required this.financials,
    required this.status,
    this.invoiceNumber,
    this.invoiceId,
    required this.immediateEntitlementGranted,
    this.appliedEntitlementId,
  });

  bool get isCompleted => status == MobileUpgradeStatus.completed;
  bool get isQuoted => status == MobileUpgradeStatus.quoted;
  bool get isPendingPayment => status == MobileUpgradeStatus.pendingPayment;

  static MobileUpgradeStatus parseStatus(String raw) {
    switch (raw.toUpperCase().trim()) {
      case 'QUOTED':
        return MobileUpgradeStatus.quoted;
      case 'PENDING_PAYMENT':
        return MobileUpgradeStatus.pendingPayment;
      case 'COMPLETED':
        return MobileUpgradeStatus.completed;
      case 'CANCELLED':
        return MobileUpgradeStatus.cancelled;
      default:
        return MobileUpgradeStatus.unknown;
    }
  }

  static String formatBdt(double amount) {
    return '৳${amount.toStringAsFixed(2)}';
  }

  factory MobileProratedUpgradeModel.fromJson(Map<String, dynamic> json) {
    return MobileProratedUpgradeModel(
      upgradeId: json['upgrade_id'] as String? ?? '',
      tenantId: json['tenant_id'] as String? ?? '',
      subscriptionId: json['subscription_id'] as String? ?? '',
      fromPlanTier: json['from_plan_tier'] as String? ?? 'BASIC',
      fromPlanCode: json['from_plan_code'] as String? ?? '',
      fromBillingCycle: json['from_billing_cycle'] as String? ?? 'MONTHLY',
      toPlanTier: json['to_plan_tier'] as String? ?? 'STANDARD',
      toPlanCode: json['to_plan_code'] as String? ?? '',
      toBillingCycle: json['to_billing_cycle'] as String? ?? 'MONTHLY',
      transitionTimestamp: DateTime.tryParse(json['transition_timestamp'] as String? ?? '') ?? DateTime.now(),
      prorationDays: MobileProrationDays.fromJson(json['proration_days'] as Map<String, dynamic>? ?? {}),
      financials: MobileUpgradeFinancials.fromJson(json['financials'] as Map<String, dynamic>? ?? {}),
      status: parseStatus(json['status'] as String? ?? 'QUOTED'),
      invoiceNumber: json['invoice_number'] as String?,
      invoiceId: json['invoice_id'] as String?,
      immediateEntitlementGranted: json['immediate_entitlement_granted'] as bool? ?? false,
      appliedEntitlementId: json['applied_entitlement_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'upgrade_id': upgradeId,
    'tenant_id': tenantId,
    'subscription_id': subscriptionId,
    'from_plan_tier': fromPlanTier,
    'from_plan_code': fromPlanCode,
    'from_billing_cycle': fromBillingCycle,
    'to_plan_tier': toPlanTier,
    'to_plan_code': toPlanCode,
    'to_billing_cycle': toBillingCycle,
    'transition_timestamp': transitionTimestamp.toIso8601String(),
    'proration_days': prorationDays.toJson(),
    'financials': financials.toJson(),
    'status': status.name.toUpperCase(),
    'invoice_number': invoiceNumber,
    'invoice_id': invoiceId,
    'immediate_entitlement_granted': immediateEntitlementGranted,
    'applied_entitlement_id': appliedEntitlementId,
  };
}
