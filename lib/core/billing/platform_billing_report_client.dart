// lib/core/billing/platform_billing_report_client.dart
// Architecture Decision: ADR-0098
// Phase 05: Basic/Standard/Pro Subscription & Billing (P098)
// Requirement Trace: FR-044, FR-064, FR-066, FR-067, FR-074

enum MobileBillingUiStatus {
  loading,
  success,
  empty,
  offline,
  error,
  permissionDenied,
}

class MobileMrrSummary {
  final String totalMrrBdt;
  final String totalArrBdt;
  final String arpuBdt;
  final int activeSubscriptionsCount;
  final int payingTenantsCount;
  final String basicMrrBdt;
  final String standardMrrBdt;
  final String proMrrBdt;

  const MobileMrrSummary({
    required this.totalMrrBdt,
    required this.totalArrBdt,
    required this.arpuBdt,
    required this.activeSubscriptionsCount,
    required this.payingTenantsCount,
    required this.basicMrrBdt,
    required this.standardMrrBdt,
    required this.proMrrBdt,
  });

  factory MobileMrrSummary.fromJson(Map<String, dynamic> json) {
    final tiers = (json['tier_breakdown'] as Map<String, dynamic>?) ?? {};
    return MobileMrrSummary(
      totalMrrBdt: json['total_mrr_bdt'] as String? ?? '0.00',
      totalArrBdt: json['total_arr_bdt'] as String? ?? '0.00',
      arpuBdt: json['arpu_bdt'] as String? ?? '0.00',
      activeSubscriptionsCount: json['active_subscriptions_count'] as int? ?? 0,
      payingTenantsCount: json['paying_tenants_count'] as int? ?? 0,
      basicMrrBdt: tiers['BASIC'] as String? ?? '0.00',
      standardMrrBdt: tiers['STANDARD'] as String? ?? '0.00',
      proMrrBdt: tiers['PRO'] as String? ?? '0.00',
    );
  }
}

class MobileChurnSummary {
  final String churnRatePct;
  final int churnedSubscriptionsCount;
  final String lostMrrBdt;
  final Map<String, int> reasonsBreakdown;

  const MobileChurnSummary({
    required this.churnRatePct,
    required this.churnedSubscriptionsCount,
    required this.lostMrrBdt,
    required this.reasonsBreakdown,
  });

  factory MobileChurnSummary.fromJson(Map<String, dynamic> json) {
    final rawReasons = (json['reasons_breakdown'] as Map<String, dynamic>?) ?? {};
    final reasons = rawReasons.map((k, v) => MapEntry(k, v as int? ?? 0));
    return MobileChurnSummary(
      churnRatePct: json['churn_rate_pct'] as String? ?? '0.00',
      churnedSubscriptionsCount: json['churned_subscriptions_count'] as int? ?? 0,
      lostMrrBdt: json['lost_mrr_bdt'] as String? ?? '0.00',
      reasonsBreakdown: reasons,
    );
  }
}

class MobileCollectionsSummary {
  final String totalCollectedBdt;
  final String bkashBdt;
  final String nagadBdt;
  final String bankTransferBdt;
  final String gatewayOnlineBdt;
  final String collectionEfficiencyPct;

  const MobileCollectionsSummary({
    required this.totalCollectedBdt,
    required this.bkashBdt,
    required this.nagadBdt,
    required this.bankTransferBdt,
    required this.gatewayOnlineBdt,
    required this.collectionEfficiencyPct,
  });

  factory MobileCollectionsSummary.fromJson(Map<String, dynamic> json) {
    final byMethod = (json['collections_by_method'] as Map<String, dynamic>?) ?? {};
    return MobileCollectionsSummary(
      totalCollectedBdt: json['total_collected_bdt'] as String? ?? '0.00',
      bkashBdt: byMethod['BKASH'] as String? ?? '0.00',
      nagadBdt: byMethod['NAGAD'] as String? ?? '0.00',
      bankTransferBdt: byMethod['BANK_TRANSFER'] as String? ?? '0.00',
      gatewayOnlineBdt: byMethod['GATEWAY_ONLINE'] as String? ?? '0.00',
      collectionEfficiencyPct: json['collection_efficiency_pct'] as String? ?? '0.00',
    );
  }
}

class MobileOutstandingSummary {
  final String totalOutstandingBdt;
  final int outstandingInvoicesCount;
  final Map<String, dynamic> agingBrackets;
  final int atRiskTenantsCount;

  const MobileOutstandingSummary({
    required this.totalOutstandingBdt,
    required this.outstandingInvoicesCount,
    required this.agingBrackets,
    required this.atRiskTenantsCount,
  });

  factory MobileOutstandingSummary.fromJson(Map<String, dynamic> json) {
    return MobileOutstandingSummary(
      totalOutstandingBdt: json['total_outstanding_bdt'] as String? ?? '0.00',
      outstandingInvoicesCount: json['outstanding_invoices_count'] as int? ?? 0,
      agingBrackets: (json['aging_brackets'] as Map<String, dynamic>?) ?? {},
      atRiskTenantsCount: json['at_risk_tenants_count'] as int? ?? 0,
    );
  }

  bool get hasOverdueRisk => atRiskTenantsCount > 0;
}

class MobileTenantBillingStatement {
  final String tenantId;
  final String lifetimeBilledBdt;
  final String lifetimePaidBdt;
  final String outstandingBalanceBdt;
  final int invoicesCount;
  final int paymentClaimsCount;

  const MobileTenantBillingStatement({
    required this.tenantId,
    required this.lifetimeBilledBdt,
    required this.lifetimePaidBdt,
    required this.outstandingBalanceBdt,
    required this.invoicesCount,
    required this.paymentClaimsCount,
  });

  factory MobileTenantBillingStatement.fromJson(Map<String, dynamic> json) {
    return MobileTenantBillingStatement(
      tenantId: json['tenant_id'] as String? ?? '',
      lifetimeBilledBdt: json['lifetime_billed_bdt'] as String? ?? '0.00',
      lifetimePaidBdt: json['lifetime_paid_bdt'] as String? ?? '0.00',
      outstandingBalanceBdt: json['outstanding_balance_bdt'] as String? ?? '0.00',
      invoicesCount: json['invoices_count'] as int? ?? 0,
      paymentClaimsCount: json['payment_claims_count'] as int? ?? 0,
    );
  }

  bool get hasOutstandingBalance =>
      outstandingBalanceBdt != '0.00' && outstandingBalanceBdt.isNotEmpty;
}

class MobileBillingReportState {
  final MobileBillingUiStatus status;
  final MobileMrrSummary? mrr;
  final MobileChurnSummary? churn;
  final MobileCollectionsSummary? collections;
  final MobileOutstandingSummary? outstanding;
  final MobileTenantBillingStatement? tenantStatement;
  final String errorMessageEn;
  final String errorMessageBn;

  const MobileBillingReportState({
    required this.status,
    this.mrr,
    this.churn,
    this.collections,
    this.outstanding,
    this.tenantStatement,
    this.errorMessageEn = '',
    this.errorMessageBn = '',
  });

  static MobileBillingReportState permissionDenied(String role) {
    return MobileBillingReportState(
      status: MobileBillingUiStatus.permissionDenied,
      errorMessageEn: "Access denied for role '$role'. Only pharmacy owners and administrators can view billing reports.",
      errorMessageBn: "আপনার রোলে ('$role') বিলিং রিপোর্ট দেখার অনুমতি নেই। শুধুমাত্র মালিক ও অ্যাডমিনদের প্রবেশাধিকার আছে।",
    );
  }

  static MobileBillingReportState offline() {
    return const MobileBillingReportState(
      status: MobileBillingUiStatus.offline,
      errorMessageEn: 'Device is offline. Billing reports require connection to cloud servers.',
      errorMessageBn: 'ডিভাইসটি অফলাইনে আছে। বিলিং রিপোর্ট দেখতে ক্লাউড সার্ভার সংযোগ প্রয়োজন।',
    );
  }
}

