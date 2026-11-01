// lib/core/billing/mobile_trial_policy_client.dart
// Architecture Decision: ADR-0007, ADR-0024, ADR-0085 & ADR-0086
// Phase 05: Basic/Standard/Pro Subscription & Billing (P086)

enum MobileTrialState {
  activeTrial,
  expiringSoon,
  expired,
  nonTrial,
}

class MobileTrialPolicyModel {
  final String tenantId;
  final bool isTrial;
  final MobileTrialState trialState;
  final int daysRemaining;
  final bool isExpired;
  final bool isWritePermitted;
  final String noticeEn;
  final String noticeBn;
  final int maxBranches;
  final int maxDevices;
  final int offlineLeaseHours;
  final bool nonDestructiveGuarantee;

  const MobileTrialPolicyModel({
    required this.tenantId,
    required this.isTrial,
    required this.trialState,
    required this.daysRemaining,
    required this.isExpired,
    required this.isWritePermitted,
    required this.noticeEn,
    required this.noticeBn,
    required this.maxBranches,
    required this.maxDevices,
    required this.offlineLeaseHours,
    required this.nonDestructiveGuarantee,
  });

  factory MobileTrialPolicyModel.fromJson(Map<String, dynamic> json) {
    final stateStr = (json['trial_status'] ?? '').toString();
    MobileTrialState state;
    switch (stateStr) {
      case 'ACTIVE_TRIAL':
        state = MobileTrialState.activeTrial;
        break;
      case 'EXPIRING_SOON':
        state = MobileTrialState.expiringSoon;
        break;
      case 'EXPIRED':
        state = MobileTrialState.expired;
        break;
      default:
        state = MobileTrialState.nonTrial;
    }

    final quotas = json['quotas'] as Map<String, dynamic>? ?? {};

    return MobileTrialPolicyModel(
      tenantId: json['tenant_id'] ?? '',
      isTrial: json['is_trial'] ?? false,
      trialState: state,
      daysRemaining: json['days_remaining'] ?? 0,
      isExpired: json['is_expired'] ?? false,
      isWritePermitted: json['is_write_permitted'] ?? true,
      noticeEn: json['notice_en'] ?? '',
      noticeBn: json['notice_bn'] ?? '',
      maxBranches: quotas['max_branches'] ?? 1,
      maxDevices: quotas['max_devices'] ?? 2,
      offlineLeaseHours: quotas['offline_lease_hours'] ?? 24,
      nonDestructiveGuarantee: json['non_destructive_guarantee'] ?? true,
    );
  }

  static MobileTrialPolicyModel evaluate({
    required String tenantId,
    required bool isTrial,
    DateTime? trialEndsAt,
    DateTime? now,
  }) {
    final currentTime = now ?? DateTime.now();

    if (!isTrial || trialEndsAt == null) {
      return MobileTrialPolicyModel(
        tenantId: tenantId,
        isTrial: false,
        trialState: MobileTrialState.nonTrial,
        daysRemaining: 0,
        isExpired: false,
        isWritePermitted: true,
        noticeEn: 'Commercial plan active.',
        noticeBn: 'বাণিজ্যিক প্ল্যান সক্রিয়।',
        maxBranches: 5,
        maxDevices: 10,
        offlineLeaseHours: 72,
        nonDestructiveGuarantee: true,
      );
    }

    final diff = trialEndsAt.difference(currentTime);
    final daysRemaining = diff.inDays > 0 ? diff.inDays : 0;
    final isExpired = currentTime.isAfter(trialEndsAt) || currentTime.isAtSameMomentAs(trialEndsAt);

    if (isExpired) {
      return MobileTrialPolicyModel(
        tenantId: tenantId,
        isTrial: true,
        trialState: MobileTrialState.expired,
        daysRemaining: 0,
        isExpired: true,
        isWritePermitted: false,
        noticeEn: 'Trial has expired. Mutations locked. Data preserved.',
        noticeBn: 'ট্রায়ালের মেয়াদ শেষ হয়েছে। নতুন এন্ট্রি স্থগিত, তথ্য নিরাপদ।',
        maxBranches: 1,
        maxDevices: 2,
        offlineLeaseHours: 24,
        nonDestructiveGuarantee: true,
      );
    } else if (daysRemaining <= 3) {
      return MobileTrialPolicyModel(
        tenantId: tenantId,
        isTrial: true,
        trialState: MobileTrialState.expiringSoon,
        daysRemaining: daysRemaining,
        isExpired: false,
        isWritePermitted: true,
        noticeEn: 'Urgent: Trial expires in $daysRemaining day(s).',
        noticeBn: 'জরুরি: ট্রায়ালের মেয়াদ বাকি $daysRemaining দিন।',
        maxBranches: 1,
        maxDevices: 2,
        offlineLeaseHours: 24,
        nonDestructiveGuarantee: true,
      );
    } else {
      return MobileTrialPolicyModel(
        tenantId: tenantId,
        isTrial: true,
        trialState: MobileTrialState.activeTrial,
        daysRemaining: daysRemaining,
        isExpired: false,
        isWritePermitted: true,
        noticeEn: 'Trial active with $daysRemaining days remaining.',
        noticeBn: 'ট্রায়াল সক্রিয় রয়েছে, বাকি $daysRemaining দিন।',
        maxBranches: 1,
        maxDevices: 2,
        offlineLeaseHours: 24,
        nonDestructiveGuarantee: true,
      );
    }
  }
}
