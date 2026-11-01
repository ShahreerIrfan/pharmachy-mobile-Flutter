// lib/core/billing/mobile_subscription_e2e_client.dart
// Architecture Decision: ADR-0100
// Phase 05: Basic/Standard/Pro Subscription & Billing (P100)
// Requirement Trace: FR-044, FR-066, FR-070

enum MobileSubscriptionE2eUiStatus {
  loading,
  success,
  empty,
  offline,
  error,
  permissionDenied,
}

class MobileSupportOverrideRecord {
  final String overrideId;
  final String tenantId;
  final String subscriptionId;
  final String overrideType;
  final String status;
  final int extensionDays;
  final int quotaBonus;
  final String justification;
  final String ticketReference;
  final String grantedByUserId;
  final String grantedAt;
  final String expiresAt;
  final String? revokedAt;
  final String? revokedByUserId;
  final String? revocationReason;

  const MobileSupportOverrideRecord({
    required this.overrideId,
    required this.tenantId,
    required this.subscriptionId,
    required this.overrideType,
    required this.status,
    required this.extensionDays,
    required this.quotaBonus,
    required this.justification,
    required this.ticketReference,
    required this.grantedByUserId,
    required this.grantedAt,
    required this.expiresAt,
    this.revokedAt,
    this.revokedByUserId,
    this.revocationReason,
  });

  factory MobileSupportOverrideRecord.fromJson(Map<String, dynamic> json) {
    return MobileSupportOverrideRecord(
      overrideId: json['override_id'] as String? ?? '',
      tenantId: json['tenant_id'] as String? ?? '',
      subscriptionId: json['subscription_id'] as String? ?? '',
      overrideType: json['override_type'] as String? ?? 'GRACE_EXTENSION',
      status: json['status'] as String? ?? 'ACTIVE',
      extensionDays: json['extension_days'] as int? ?? 0,
      quotaBonus: json['quota_bonus'] as int? ?? 0,
      justification: json['justification'] as String? ?? '',
      ticketReference: json['ticket_reference'] as String? ?? '',
      grantedByUserId: json['granted_by_user_id'] as String? ?? '',
      grantedAt: json['granted_at'] as String? ?? '',
      expiresAt: json['expires_at'] as String? ?? '',
      revokedAt: json['revoked_at'] as String?,
      revokedByUserId: json['revoked_by_user_id'] as String?,
      revocationReason: json['revocation_reason'] as String?,
    );
  }

  bool get isActive => status.toUpperCase() == 'ACTIVE';

  bool get isEmergencyUnblock =>
      isActive && overrideType.toUpperCase() == 'EMERGENCY_UNBLOCK';

  bool get isGraceExtended =>
      isActive && overrideType.toUpperCase() == 'GRACE_EXTENSION';
}

class MobileSubscriptionE2eState {
  final MobileSubscriptionE2eUiStatus status;
  final List<MobileSupportOverrideRecord> overrides;
  final bool hasActiveOverride;
  final String activeBadgeEn;
  final String activeBadgeBn;
  final String errorMessageEn;
  final String errorMessageBn;

  const MobileSubscriptionE2eState({
    required this.status,
    this.overrides = const [],
    this.hasActiveOverride = false,
    this.activeBadgeEn = '',
    this.activeBadgeBn = '',
    this.errorMessageEn = '',
    this.errorMessageBn = '',
  });

  static MobileSubscriptionE2eState success(
      List<MobileSupportOverrideRecord> overrides) {
    if (overrides.isEmpty) {
      return const MobileSubscriptionE2eState(
        status: MobileSubscriptionE2eUiStatus.empty,
        overrides: [],
      );
    }

    MobileSupportOverrideRecord? active;
    for (final ovr in overrides) {
      if (ovr.isActive) {
        active = ovr;
        break;
      }
    }

    if (active == null) {
      return MobileSubscriptionE2eState(
        status: MobileSubscriptionE2eUiStatus.success,
        overrides: overrides,
        hasActiveOverride: false,
      );
    }

    String badgeEn = 'Support Override Active';
    String badgeBn = 'সাপোর্ট ওভাররাইড সক্রিয়';

    switch (active.overrideType.toUpperCase()) {
      case 'EMERGENCY_UNBLOCK':
        badgeEn =
            'Emergency Unblock Active (Ticket: ${active.ticketReference})';
        badgeBn = 'জরুরি আনব্লক সক্রিয় (টিকেট: ${active.ticketReference})';
        break;
      case 'GRACE_EXTENSION':
        badgeEn =
            'Grace Period Extended by ${active.extensionDays} Days (Ticket: ${active.ticketReference})';
        badgeBn =
            'গ্রেস পিরিয়ড ${active.extensionDays} দিন বাড়ানো হয়েছে (টিকেট: ${active.ticketReference})';
        break;
      case 'QUOTA_OVERRIDE':
        badgeEn = 'Quota Override Active (+${active.quotaBonus} items)';
        badgeBn = 'কোটা বৃদ্ধি সক্রিয় (+${active.quotaBonus} আইটেম)';
        break;
      case 'REACTIVATION':
        badgeEn = 'Emergency Reactivation Active';
        badgeBn = 'জরুরি রি-অ্যাক্টিভেশন সক্রিয়';
        break;
    }

    return MobileSubscriptionE2eState(
      status: MobileSubscriptionE2eUiStatus.success,
      overrides: overrides,
      hasActiveOverride: true,
      activeBadgeEn: badgeEn,
      activeBadgeBn: badgeBn,
    );
  }

  static MobileSubscriptionE2eState permissionDenied(String role) {
    return MobileSubscriptionE2eState(
      status: MobileSubscriptionE2eUiStatus.permissionDenied,
      errorMessageEn:
          "Access denied for role '$role'. Only pharmacy owners and administrators can view support overrides.",
      errorMessageBn:
          "আপনার রোলে ('$role') সাপোর্ট ওভাররাইড দেখার অনুমতি নেই। শুধুমাত্র মালিক ও অ্যাডমিনদের প্রবেশাধিকার আছে।",
    );
  }

  static MobileSubscriptionE2eState offline() {
    return const MobileSubscriptionE2eState(
      status: MobileSubscriptionE2eUiStatus.offline,
      errorMessageEn:
          'Device is offline. Verification requires cloud server connection.',
      errorMessageBn:
          'ডিভাইসটি অফলাইনে আছে। যাচাইয়ের জন্য ক্লাউড সার্ভারের সাথে সক্রিয় ইন্টারনেট সংযোগ প্রয়োজন।',
    );
  }
}
