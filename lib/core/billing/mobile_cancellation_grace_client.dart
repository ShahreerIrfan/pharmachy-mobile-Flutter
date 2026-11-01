// lib/core/billing/mobile_cancellation_grace_client.dart
// Architecture Decision: ADR-0007, ADR-0015, ADR-0073, ADR-0084 & ADR-0092
// Phase 05: Basic/Standard/Pro Subscription & Billing (P092)

enum MobileSubscriptionLifecycleStatus {
  pending,
  trial,
  active,
  pastDue,
  gracePeriod,
  suspended,
  cancelled,
  expired,
  unknown,
}

class MobileLifecycleDetails {
  final DateTime renewalDate;
  final bool inGracePeriod;
  final int? gracePeriodDaysRemaining;
  final DateTime? gracePeriodEndDate;
  final bool isAutoRenew;
  final bool cancelAtPeriodEnd;
  final String? cancellationReason;

  const MobileLifecycleDetails({
    required this.renewalDate,
    required this.inGracePeriod,
    this.gracePeriodDaysRemaining,
    this.gracePeriodEndDate,
    required this.isAutoRenew,
    required this.cancelAtPeriodEnd,
    this.cancellationReason,
  });

  factory MobileLifecycleDetails.fromJson(Map<String, dynamic> json) {
    return MobileLifecycleDetails(
      renewalDate: DateTime.tryParse(json['renewal_date'] as String? ?? '') ?? DateTime.now(),
      inGracePeriod: json['in_grace_period'] as bool? ?? false,
      gracePeriodDaysRemaining: (json['grace_period_days_remaining'] as num?)?.toInt(),
      gracePeriodEndDate: json['grace_period_end_date'] != null
          ? DateTime.tryParse(json['grace_period_end_date'] as String)
          : null,
      isAutoRenew: json['is_auto_renew'] as bool? ?? true,
      cancelAtPeriodEnd: json['cancel_at_period_end'] as bool? ?? false,
      cancellationReason: json['cancellation_reason'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'renewal_date': renewalDate.toIso8601String(),
        'in_grace_period': inGracePeriod,
        'grace_period_days_remaining': gracePeriodDaysRemaining,
        'grace_period_end_date': gracePeriodEndDate?.toIso8601String(),
        'is_auto_renew': isAutoRenew,
        'cancel_at_period_end': cancelAtPeriodEnd,
        'cancellation_reason': cancellationReason,
      };
}

class MobileOwnerMessaging {
  final String headlineEn;
  final String headlineBn;
  final String detailsEn;
  final String detailsBn;
  final String actionRequired;

  const MobileOwnerMessaging({
    required this.headlineEn,
    required this.headlineBn,
    required this.detailsEn,
    required this.detailsBn,
    required this.actionRequired,
  });

  factory MobileOwnerMessaging.fromJson(Map<String, dynamic> json) {
    return MobileOwnerMessaging(
      headlineEn: json['headline_en'] as String? ?? '',
      headlineBn: json['headline_bn'] as String? ?? '',
      detailsEn: json['details_en'] as String? ?? '',
      detailsBn: json['details_bn'] as String? ?? '',
      actionRequired: json['action_required'] as String? ?? 'NONE',
    );
  }

  Map<String, dynamic> toJson() => {
        'headline_en': headlineEn,
        'headline_bn': headlineBn,
        'details_en': detailsEn,
        'details_bn': detailsBn,
        'action_required': actionRequired,
      };
}

class MobileLifecyclePermissions {
  final bool canDispenseSales;
  final bool canReadHistoricalData;
  final bool canExportTenantData;
  final bool zeroDataDeleted;

  const MobileLifecyclePermissions({
    required this.canDispenseSales,
    this.canReadHistoricalData = true,
    this.canExportTenantData = true,
    this.zeroDataDeleted = true,
  });

  factory MobileLifecyclePermissions.fromJson(Map<String, dynamic> json) {
    return MobileLifecyclePermissions(
      canDispenseSales: json['can_dispense_sales'] as bool? ?? false,
      canReadHistoricalData: json['can_read_historical_data'] as bool? ?? true,
      canExportTenantData: json['can_export_tenant_data'] as bool? ?? true,
      zeroDataDeleted: json['zero_data_deleted'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'can_dispense_sales': canDispenseSales,
        'can_read_historical_data': canReadHistoricalData,
        'can_export_tenant_data': canExportTenantData,
        'zero_data_deleted': zeroDataDeleted,
      };
}

class MobileSubscriptionLifecycleModel {
  final String tenantId;
  final String subscriptionId;
  final String planTier;
  final MobileSubscriptionLifecycleStatus status;
  final MobileLifecycleDetails lifecycleDetails;
  final MobileOwnerMessaging ownerMessaging;
  final MobileLifecyclePermissions permissions;

  const MobileSubscriptionLifecycleModel({
    required this.tenantId,
    required this.subscriptionId,
    required this.planTier,
    required this.status,
    required this.lifecycleDetails,
    required this.ownerMessaging,
    required this.permissions,
  });

  bool get canDispense => permissions.canDispenseSales;
  bool get inGracePeriod => lifecycleDetails.inGracePeriod;
  bool get isExpired =>
      status == MobileSubscriptionLifecycleStatus.expired ||
      status == MobileSubscriptionLifecycleStatus.suspended;
  bool get isCancelled => status == MobileSubscriptionLifecycleStatus.cancelled;

  static MobileSubscriptionLifecycleStatus parseStatus(String raw) {
    switch (raw.toUpperCase().trim()) {
      case 'PENDING':
        return MobileSubscriptionLifecycleStatus.pending;
      case 'TRIAL':
        return MobileSubscriptionLifecycleStatus.trial;
      case 'ACTIVE':
        return MobileSubscriptionLifecycleStatus.active;
      case 'PAST_DUE':
        return MobileSubscriptionLifecycleStatus.pastDue;
      case 'GRACE_PERIOD':
        return MobileSubscriptionLifecycleStatus.gracePeriod;
      case 'SUSPENDED':
        return MobileSubscriptionLifecycleStatus.suspended;
      case 'CANCELLED':
        return MobileSubscriptionLifecycleStatus.cancelled;
      case 'EXPIRED':
        return MobileSubscriptionLifecycleStatus.expired;
      default:
        return MobileSubscriptionLifecycleStatus.unknown;
    }
  }

  factory MobileSubscriptionLifecycleModel.fromJson(Map<String, dynamic> json) {
    return MobileSubscriptionLifecycleModel(
      tenantId: json['tenant_id'] as String? ?? '',
      subscriptionId: json['subscription_id'] as String? ?? '',
      planTier: json['plan_tier'] as String? ?? 'BASIC',
      status: parseStatus(json['status'] as String? ?? 'ACTIVE'),
      lifecycleDetails: MobileLifecycleDetails.fromJson(
        json['lifecycle_details'] as Map<String, dynamic>? ?? {},
      ),
      ownerMessaging: MobileOwnerMessaging.fromJson(
        json['owner_messaging'] as Map<String, dynamic>? ?? {},
      ),
      permissions: MobileLifecyclePermissions.fromJson(
        json['permissions'] as Map<String, dynamic>? ?? {},
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'tenant_id': tenantId,
        'subscription_id': subscriptionId,
        'plan_tier': planTier,
        'status': status.name.toUpperCase(),
        'lifecycle_details': lifecycleDetails.toJson(),
        'owner_messaging': ownerMessaging.toJson(),
        'permissions': permissions.toJson(),
      };
}
