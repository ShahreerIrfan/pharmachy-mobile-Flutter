// lib/core/billing/mobile_dunning_notification_client.dart
// Architecture Decision: ADR-0099
// Phase 05: Basic/Standard/Pro Subscription & Billing (P099)
// Requirement Trace: FR-044, FR-066, FR-068, FR-070

enum MobileDunningUiStatus {
  loading,
  success,
  empty,
  offline,
  error,
  permissionDenied,
}

class MobileDunningAlert {
  final String notificationId;
  final String tenantId;
  final String? invoiceId;
  final String stage;
  final String channel;
  final String deliveryStatus;
  final String dedupKey;
  final String titleEn;
  final String titleBn;
  final String bodyEn;
  final String bodyBn;
  final String amountDueBdt;
  final bool isAcknowledged;
  final String? acknowledgedAt;
  final int retryCount;
  final int maxRetries;
  final String createdAt;

  const MobileDunningAlert({
    required this.notificationId,
    required this.tenantId,
    this.invoiceId,
    required this.stage,
    required this.channel,
    required this.deliveryStatus,
    required this.dedupKey,
    required this.titleEn,
    required this.titleBn,
    required this.bodyEn,
    required this.bodyBn,
    required this.amountDueBdt,
    required this.isAcknowledged,
    this.acknowledgedAt,
    required this.retryCount,
    required this.maxRetries,
    required this.createdAt,
  });

  factory MobileDunningAlert.fromJson(Map<String, dynamic> json) {
    return MobileDunningAlert(
      notificationId: json['notification_id'] as String? ?? '',
      tenantId: json['tenant_id'] as String? ?? '',
      invoiceId: json['invoice_id'] as String?,
      stage: json['stage'] as String? ?? 'UPCOMING_RENEWAL',
      channel: json['channel'] as String? ?? 'IN_APP',
      deliveryStatus: json['delivery_status'] as String? ?? 'DELIVERED',
      dedupKey: json['dedup_key'] as String? ?? '',
      titleEn: json['title_en'] as String? ?? '',
      titleBn: json['title_bn'] as String? ?? '',
      bodyEn: json['body_en'] as String? ?? '',
      bodyBn: json['body_bn'] as String? ?? '',
      amountDueBdt: json['amount_due_bdt'] as String? ?? '0.00',
      isAcknowledged: json['is_acknowledged'] as bool? ?? false,
      acknowledgedAt: json['acknowledged_at'] as String?,
      retryCount: json['retry_count'] as int? ?? 0,
      maxRetries: json['max_retries'] as int? ?? 3,
      createdAt: json['created_at'] as String? ?? '',
    );
  }

  bool get isUrgent =>
      stage == 'PAYMENT_FAILED' ||
      stage == 'GRACE_PERIOD_ACTIVE' ||
      stage == 'SUBSCRIPTION_EXPIRED' ||
      stage == 'ACCOUNT_SUSPENDED';

  bool get isSuppressed => deliveryStatus.toUpperCase() == 'SUPPRESSED';

  bool get isRecovered => stage == 'PAYMENT_RECOVERED';
}

class MobileDunningState {
  final MobileDunningUiStatus status;
  final List<MobileDunningAlert> alerts;
  final int unacknowledgedCount;
  final String errorMessageEn;
  final String errorMessageBn;

  const MobileDunningState({
    required this.status,
    this.alerts = const [],
    this.unacknowledgedCount = 0,
    this.errorMessageEn = '',
    this.errorMessageBn = '',
  });

  static MobileDunningState permissionDenied(String role) {
    return MobileDunningState(
      status: MobileDunningUiStatus.permissionDenied,
      errorMessageEn: "Access denied for role '$role'. Only pharmacy owners and administrators can view dunning notifications.",
      errorMessageBn: "আপনার রোলে ('$role') ডানিং নোটিফিকেশন দেখার অনুমতি নেই। শুধুমাত্র মালিক ও অ্যাডমিনদের প্রবেশাধিকার আছে।",
    );
  }

  static MobileDunningState offline() {
    return const MobileDunningState(
      status: MobileDunningUiStatus.offline,
      errorMessageEn: 'Device is offline. Dunning notifications require cloud server connection.',
      errorMessageBn: 'ডিভাইসটি অফলাইনে আছে। ডানিং নোটিফিকেশন দেখতে ক্লাউড সার্ভারের সাথে সক্রিয় ইন্টারনেট সংযোগ প্রয়োজন।',
    );
  }
}
