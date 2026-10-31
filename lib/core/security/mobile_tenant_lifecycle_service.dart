/// mobile_tenant_lifecycle_service.dart
///
/// Architecture Decision: ADR-0061
/// Mobile Manager App Tenant Lifecycle & Status Evaluation Service.
/// Evaluates tenant status for mobile manager displays:
///   - Allows operational flows during ACTIVE and TRIAL states
///   - Displays urgent renewal alert during PAST_DUE grace period
///   - Surfaces read-only lock notices when SUSPENDED or ARCHIVED
library mobile_tenant_lifecycle_service;

class MobileTenantStatusEvaluation {
  final String status;
  final bool isCheckoutPermitted;
  final bool isGracePeriodWarning;
  final String messageEn;
  final String messageBn;

  const MobileTenantStatusEvaluation({
    required this.status,
    required this.isCheckoutPermitted,
    required this.isGracePeriodWarning,
    required this.messageEn,
    required this.messageBn,
  });

  Map<String, dynamic> toJson() => {
        'status': status,
        'is_checkout_permitted': isCheckoutPermitted,
        'is_grace_period_warning': isGracePeriodWarning,
        'message_en': messageEn,
        'message_bn': messageBn,
      };
}

class MobileTenantLifecycleService {
  static MobileTenantStatusEvaluation evaluateTenantStatus(String? rawStatus) {
    final status = rawStatus != null ? rawStatus.toUpperCase().trim() : 'UNKNOWN';

    switch (status) {
      case 'ACTIVE':
        return const MobileTenantStatusEvaluation(
          status: 'ACTIVE',
          isCheckoutPermitted: true,
          isGracePeriodWarning: false,
          messageEn: 'Tenant account is active and in good standing.',
          messageBn: 'টেন্যান্ট অ্যাকাউন্ট সক্রিয় ও নিয়মিত।',
        );
      case 'TRIAL':
        return const MobileTenantStatusEvaluation(
          status: 'TRIAL',
          isCheckoutPermitted: true,
          isGracePeriodWarning: false,
          messageEn: 'Active evaluation trial subscription.',
          messageBn: 'ট্রায়াল সাবস্ক্রিপশন সক্রিয়।',
        );
      case 'PAST_DUE':
        return const MobileTenantStatusEvaluation(
          status: 'PAST_DUE',
          isCheckoutPermitted: true,
          isGracePeriodWarning: true,
          messageEn: 'Subscription is past due. Grace period active. Please renew.',
          messageBn: 'সাবস্ক্রিপশন বিল বকেয়া পড়েছে। গ্রেস পিরিয়ড চলছে। অনুগ্রহ করে বিল পরিশোধ করুন।',
        );
      case 'SUSPENDED':
        return const MobileTenantStatusEvaluation(
          status: 'SUSPENDED',
          isCheckoutPermitted: false,
          isGracePeriodWarning: false,
          messageEn: 'Tenant account is suspended. Read-only historical access.',
          messageBn: 'টেন্যান্ট অ্যাকাউন্ট স্থগিত রয়েছে। শুধুমাত্র দেখার অনুমতি আছে।',
        );
      case 'ARCHIVED':
        return const MobileTenantStatusEvaluation(
          status: 'ARCHIVED',
          isCheckoutPermitted: false,
          isGracePeriodWarning: false,
          messageEn: 'Tenant account is decommissioned and archived.',
          messageBn: 'টেন্যান্ট অ্যাকাউন্টটি বাতিল ও আর্কাইভ করা হয়েছে।',
        );
      default:
        return MobileTenantStatusEvaluation(
          status: status,
          isCheckoutPermitted: false,
          isGracePeriodWarning: false,
          messageEn: 'Invalid tenant status: $status',
          messageBn: 'অবৈধ টেন্যান্ট স্ট্যাটাস: $status',
        );
    }
  }

  static bool isCanonicalSettingValid(Map<String, dynamic>? settings) {
    if (settings == null) return true;
    if (settings['allow_negative_stock'] == true) {
      return false; // Violates clinical safety invariant
    }
    return true;
  }
}
