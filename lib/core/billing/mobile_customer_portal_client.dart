// lib/core/billing/mobile_customer_portal_client.dart
// Architecture Decision: ADR-0007, ADR-0081, ADR-0087, ADR-0088, ADR-0095 & ADR-0097
// Phase 05: Basic/Standard/Pro Subscription & Billing (P097)
// Requirement Trace: FR-070, FR-071, FR-072 (Subscription Customer Portal)

class MobileActivePackage {
  final String planCode;
  final String planTier;
  final String planName;
  final String billingCycle;
  final String status;
  final String priceBdt;
  final String currency;
  final String periodStart;
  final String periodEnd;
  final bool autoRenew;

  const MobileActivePackage({
    required this.planCode,
    required this.planTier,
    required this.planName,
    required this.billingCycle,
    required this.status,
    required this.priceBdt,
    required this.currency,
    required this.periodStart,
    required this.periodEnd,
    required this.autoRenew,
  });

  factory MobileActivePackage.fromJson(Map<String, dynamic> json) {
    return MobileActivePackage(
      planCode: json['plan_code'] as String? ?? '',
      planTier: json['plan_tier'] as String? ?? 'BASIC',
      planName: json['plan_name'] as String? ?? '',
      billingCycle: json['billing_cycle'] as String? ?? 'MONTHLY',
      status: json['status'] as String? ?? 'ACTIVE',
      priceBdt: json['price_bdt'] as String? ?? '0.00',
      currency: json['currency'] as String? ?? 'BDT',
      periodStart: json['period_start'] as String? ?? '',
      periodEnd: json['period_end'] as String? ?? '',
      autoRenew: json['auto_renew'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'plan_code': planCode,
        'plan_tier': planTier,
        'plan_name': planName,
        'billing_cycle': billingCycle,
        'status': status,
        'price_bdt': priceBdt,
        'currency': currency,
        'period_start': periodStart,
        'period_end': periodEnd,
        'auto_renew': autoRenew,
      };

  bool get isActive => status == 'ACTIVE';
  bool get isTrial => status == 'TRIAL';
  bool get isGracePeriod => status == 'GRACE_PERIOD';
}

class MobileNextRenewal {
  final String renewalDate;
  final int daysRemaining;
  final String projectedAmountBdt;
  final bool autoRenew;

  const MobileNextRenewal({
    required this.renewalDate,
    required this.daysRemaining,
    required this.projectedAmountBdt,
    required this.autoRenew,
  });

  factory MobileNextRenewal.fromJson(Map<String, dynamic> json) {
    return MobileNextRenewal(
      renewalDate: json['renewal_date'] as String? ?? '',
      daysRemaining: (json['days_remaining'] as num?)?.toInt() ?? 0,
      projectedAmountBdt: json['projected_amount_bdt'] as String? ?? '0.00',
      autoRenew: json['auto_renew'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'renewal_date': renewalDate,
        'days_remaining': daysRemaining,
        'projected_amount_bdt': projectedAmountBdt,
        'auto_renew': autoRenew,
      };

  bool get isDueSoon => daysRemaining <= 7;
}

class MobilePortalInvoice {
  final String invoiceNumber;
  final String periodStart;
  final String periodEnd;
  final String subtotalBdt;
  final String taxAmountBdt;
  final String totalBdt;
  final String status;

  const MobilePortalInvoice({
    required this.invoiceNumber,
    required this.periodStart,
    required this.periodEnd,
    required this.subtotalBdt,
    required this.taxAmountBdt,
    required this.totalBdt,
    required this.status,
  });

  factory MobilePortalInvoice.fromJson(Map<String, dynamic> json) {
    return MobilePortalInvoice(
      invoiceNumber: json['invoice_number'] as String? ?? '',
      periodStart: json['period_start'] as String? ?? '',
      periodEnd: json['period_end'] as String? ?? '',
      subtotalBdt: json['subtotal_bdt'] as String? ?? '0.00',
      taxAmountBdt: json['tax_amount_bdt'] as String? ?? '0.00',
      totalBdt: json['total_bdt'] as String? ?? '0.00',
      status: json['status'] as String? ?? 'DRAFT',
    );
  }

  Map<String, dynamic> toJson() => {
        'invoice_number': invoiceNumber,
        'period_start': periodStart,
        'period_end': periodEnd,
        'subtotal_bdt': subtotalBdt,
        'tax_amount_bdt': taxAmountBdt,
        'total_bdt': totalBdt,
        'status': status,
      };

  bool get isPaid => status == 'PAID';
}

class MobilePortalPayment {
  final String reference;
  final String paymentMethod;
  final String amountBdt;
  final String status;
  final String paidAt;

  const MobilePortalPayment({
    required this.reference,
    required this.paymentMethod,
    required this.amountBdt,
    required this.status,
    required this.paidAt,
  });

  factory MobilePortalPayment.fromJson(Map<String, dynamic> json) {
    return MobilePortalPayment(
      reference: json['reference'] as String? ?? '',
      paymentMethod: json['payment_method'] as String? ?? '',
      amountBdt: json['amount_bdt'] as String? ?? '0.00',
      status: json['status'] as String? ?? 'PENDING',
      paidAt: json['paid_at'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'reference': reference,
        'payment_method': paymentMethod,
        'amount_bdt': amountBdt,
        'status': status,
        'paid_at': paidAt,
      };
}

class MobileCustomerPortalResponse {
  final String tenantId;
  final MobileActivePackage activePackage;
  final MobileNextRenewal nextRenewal;
  final List<MobilePortalInvoice> invoices;
  final List<MobilePortalPayment> paymentHistory;
  final String overallQuotaStatus;
  final int upgradeOptionsCount;
  final bool zeroDataDeleted;
  final bool safeExportRetained;
  final bool authoritativeSync;
  final String headlineEn;
  final String headlineBn;
  final String detailsEn;
  final String detailsBn;

  const MobileCustomerPortalResponse({
    required this.tenantId,
    required this.activePackage,
    required this.nextRenewal,
    required this.invoices,
    required this.paymentHistory,
    required this.overallQuotaStatus,
    required this.upgradeOptionsCount,
    required this.zeroDataDeleted,
    required this.safeExportRetained,
    required this.authoritativeSync,
    required this.headlineEn,
    required this.headlineBn,
    required this.detailsEn,
    required this.detailsBn,
  });

  factory MobileCustomerPortalResponse.fromJson(Map<String, dynamic> json) {
    final pkgJson = json['active_package'] as Map<String, dynamic>? ?? {};
    final renJson = json['next_renewal'] as Map<String, dynamic>? ?? {};
    final invList = (json['invoices'] as List<dynamic>? ?? [])
        .map((e) => MobilePortalInvoice.fromJson(e as Map<String, dynamic>))
        .toList();
    final payList = (json['payment_history'] as List<dynamic>? ?? [])
        .map((e) => MobilePortalPayment.fromJson(e as Map<String, dynamic>))
        .toList();
    final quotaJson = json['quota_usage'] as Map<String, dynamic>? ?? {};
    final upgList = json['upgrade_options'] as List<dynamic>? ?? [];
    final invs = json['invariants'] as Map<String, dynamic>? ?? {};
    final msg = json['client_messaging'] as Map<String, dynamic>? ?? {};

    return MobileCustomerPortalResponse(
      tenantId: json['tenant_id'] as String? ?? '',
      activePackage: MobileActivePackage.fromJson(pkgJson),
      nextRenewal: MobileNextRenewal.fromJson(renJson),
      invoices: invList,
      paymentHistory: payList,
      overallQuotaStatus: quotaJson['overall_status'] as String? ?? 'OK',
      upgradeOptionsCount: upgList.length,
      zeroDataDeleted: invs['zero_data_deleted'] as bool? ?? true,
      safeExportRetained: invs['safe_export_retained'] as bool? ?? true,
      authoritativeSync: invs['authoritative_sync'] as bool? ?? true,
      headlineEn: msg['headline_en'] as String? ?? '',
      headlineBn: msg['headline_bn'] as String? ?? '',
      detailsEn: msg['details_en'] as String? ?? '',
      detailsBn: msg['details_bn'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'tenant_id': tenantId,
        'active_package': activePackage.toJson(),
        'next_renewal': nextRenewal.toJson(),
        'invoices': invoices.map((i) => i.toJson()).toList(),
        'payment_history': paymentHistory.map((p) => p.toJson()).toList(),
        'quota_usage': {'overall_status': overallQuotaStatus},
        'upgrade_options_count': upgradeOptionsCount,
        'invariants': {
          'zero_data_deleted': zeroDataDeleted,
          'safe_export_retained': safeExportRetained,
          'authoritative_sync': authoritativeSync,
        },
        'client_messaging': {
          'headline_en': headlineEn,
          'headline_bn': headlineBn,
          'details_en': detailsEn,
          'details_bn': detailsBn,
        },
      };
}

