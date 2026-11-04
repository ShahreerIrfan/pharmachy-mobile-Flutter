/// MobileBatchExpiryClient
/// Architecture Decision: ADR-0172 (P172).
/// Phase 09: Packaging, Unit Conversion, Batches & Cost Lots.
///
/// Flutter mobile manager client for batch expiry alert windows,
/// DGDA statutory expiration blocks, and sale cutoff guards.
library;

enum MobileExpiryTier {
  expired(labelEn: 'Expired (Illegal to Sell)', labelBn: 'মেয়াদোত্তীর্ণ (বিক্রয় নিষিদ্ধ)', severity: 'DANGER', isBlocked: true),
  cutoffBlocked(labelEn: 'Sale Cutoff Reached', labelBn: 'বিক্রয় কাট-অফ উত্তীর্ণ', severity: 'DANGER', isBlocked: true),
  quarantineDisposition(labelEn: 'Urgent Disposition', labelBn: 'জরুরি স্থানান্তর / ফেরত', severity: 'WARNING_HIGH', isBlocked: false),
  nearExpiryCritical(labelEn: 'Near Expiry', labelBn: 'আসন্ন মেয়াদোত্তীর্ণ', severity: 'WARNING_MEDIUM', isBlocked: false),
  earlyWarning(labelEn: 'Early Warning', labelBn: 'প্রাথমিক সতর্কতা', severity: 'INFO', isBlocked: false),
  normalSafe(labelEn: 'Normal Safe', labelBn: 'নিরাপদ মেয়াদকাল', severity: 'SAFE', isBlocked: false);

  final String labelEn;
  final String labelBn;
  final String severity;
  final bool isBlocked;

  const MobileExpiryTier({
    required this.labelEn,
    required this.labelBn,
    required this.severity,
    required this.isBlocked,
  });
}

class MobileExpiryPolicy {
  final int warningLeadDays;
  final int criticalLeadDays;
  final int quarantineLeadDays;
  final int saleCutoffLeadDays;
  final bool autoQuarantineOnCutoff;
  final bool allowManagerOverrideNearExpiry;

  const MobileExpiryPolicy({
    this.warningLeadDays = 90,
    this.criticalLeadDays = 30,
    this.quarantineLeadDays = 15,
    this.saleCutoffLeadDays = 7,
    this.autoQuarantineOnCutoff = true,
    this.allowManagerOverrideNearExpiry = false,
  });

  factory MobileExpiryPolicy.fromJson(Map<String, dynamic> json) {
    return MobileExpiryPolicy(
      warningLeadDays: (json['warning_lead_days'] as num?)?.toInt() ?? 90,
      criticalLeadDays: (json['critical_lead_days'] as num?)?.toInt() ?? 30,
      quarantineLeadDays: (json['quarantine_lead_days'] as num?)?.toInt() ?? 15,
      saleCutoffLeadDays: (json['sale_cutoff_lead_days'] as num?)?.toInt() ?? 7,
      autoQuarantineOnCutoff: json['auto_quarantine_on_cutoff'] as bool? ?? true,
      allowManagerOverrideNearExpiry: json['allow_manager_override_near_expiry'] as bool? ?? false,
    );
  }
}

class MobileBatchExpiryEvaluation {
  final String batchId;
  final String batchNumber;
  final String productName;
  final DateTime expiryDate;
  final int daysRemaining;
  final MobileExpiryTier tier;
  final bool isSaleBlocked;
  final bool requiresManagerOverride;

  const MobileBatchExpiryEvaluation({
    required this.batchId,
    required this.batchNumber,
    required this.productName,
    required this.expiryDate,
    required this.daysRemaining,
    required this.tier,
    required this.isSaleBlocked,
    required this.requiresManagerOverride,
  });
}

class MobileClientResponse<T> {
  final bool success;
  final T? data;
  final String? errorCode;
  final String messageEn;
  final String messageBn;

  MobileClientResponse._({
    required this.success,
    this.data,
    this.errorCode,
    required this.messageEn,
    required this.messageBn,
  });

  factory MobileClientResponse.ok(T data, {String messageEn = 'Success', String messageBn = 'সফল'}) {
    return MobileClientResponse._(
      success: true,
      data: data,
      messageEn: messageEn,
      messageBn: messageBn,
    );
  }

  factory MobileClientResponse.failure(
    String errorCode, {
    String messageEn = 'An error occurred.',
    String messageBn = 'একটি ত্রুটি ঘটেছে।',
  }) {
    return MobileClientResponse._(
      success: false,
      errorCode: errorCode,
      messageEn: messageEn,
      messageBn: messageBn,
    );
  }
}

class MobileBatchExpiryClient {
  final String tenantId;
  final String branchId;
  final String userRole;
  final bool isTenantSuspended;
  MobileExpiryPolicy policy;

  MobileBatchExpiryClient({
    required this.tenantId,
    required this.branchId,
    this.userRole = 'BRANCH_MANAGER',
    this.isTenantSuspended = false,
    this.policy = const MobileExpiryPolicy(),
  });

  bool get _isAuthorized {
    switch (userRole.toUpperCase()) {
      case 'CASHIER':
      case 'STAFF_PHARMACIST':
      case 'BRANCH_MANAGER':
      case 'PHARMACY_OWNER':
      case 'INVENTORY_CLERK':
      case 'AUDITOR':
      case 'SUPERADMIN':
        return true;
      default:
        return false;
    }
  }

  MobileBatchExpiryEvaluation evaluateBatch({
    required String batchId,
    required String batchNumber,
    required String productName,
    required DateTime expiryDate,
    DateTime? asOfDate,
  }) {
    final today = asOfDate ?? DateTime.now();
    final difference = expiryDate.difference(today).inDays;

    MobileExpiryTier tier;
    bool blocked;
    bool reqOverride = false;

    if (difference <= 0) {
      tier = MobileExpiryTier.expired;
      blocked = true;
    } else if (difference <= policy.saleCutoffLeadDays) {
      tier = MobileExpiryTier.cutoffBlocked;
      blocked = true;
      reqOverride = policy.allowManagerOverrideNearExpiry;
    } else if (difference <= policy.quarantineLeadDays) {
      tier = MobileExpiryTier.quarantineDisposition;
      blocked = false;
    } else if (difference <= policy.criticalLeadDays) {
      tier = MobileExpiryTier.nearExpiryCritical;
      blocked = false;
    } else if (difference <= policy.warningLeadDays) {
      tier = MobileExpiryTier.earlyWarning;
      blocked = false;
    } else {
      tier = MobileExpiryTier.normalSafe;
      blocked = false;
    }

    return MobileBatchExpiryEvaluation(
      batchId: batchId,
      batchNumber: batchNumber,
      productName: productName,
      expiryDate: expiryDate,
      daysRemaining: difference,
      tier: tier,
      isSaleBlocked: blocked,
      requiresManagerOverride: reqOverride,
    );
  }

  MobileClientResponse<MobileBatchExpiryEvaluation> verifyBatchForSale({
    required MobileBatchExpiryEvaluation eval,
    bool isManagerAuthorized = false,
  }) {
    if (isTenantSuspended) {
      return MobileClientResponse.failure(
        'ERR_TENANT_SUSPENDED',
        messageEn: 'Tenant subscription is suspended.',
        messageBn: 'গ্রাহক সাবস্ক্রিপশন স্থগিত রয়েছে।',
      );
    }
    if (!_isAuthorized) {
      return MobileClientResponse.failure(
        'ERR_ROLE_UNAUTHORIZED',
        messageEn: 'Role is not authorized to verify batch expiry.',
        messageBn: 'এই রোল ব্যাচ এক্সপায়ারি যাচাই করতে অননুমোদিত।',
      );
    }

    if (eval.tier == MobileExpiryTier.expired) {
      return MobileClientResponse.failure(
        'ERR_BATCH_EXPIRED',
        messageEn: 'Batch has expired. Sale is strictly illegal under DGDA regulations.',
        messageBn: 'ওষুধটির মেয়াদ শেষ হয়ে গেছে। ডিজিডিএ নিয়ম অনুযায়ী এটি বিক্রয় সম্পূর্ণ নিষিদ্ধ।',
      );
    }

    if (eval.tier == MobileExpiryTier.cutoffBlocked) {
      if (policy.allowManagerOverrideNearExpiry && isManagerAuthorized) {
        return MobileClientResponse.ok(
          eval,
          messageEn: 'Sale approved under authorized manager override.',
          messageBn: 'ম্যানেজারের অনুমোদনে বিক্রয় সম্পন্ন করা হয়েছে।',
        );
      }
      return MobileClientResponse.failure(
        'ERR_SALE_CUTOFF_BREACHED',
        messageEn: 'Batch has breached sale cutoff (${policy.saleCutoffLeadDays} days). Dispensing barred.',
        messageBn: 'ওষুধটি বিক্রয় কাট-অফ অতিক্রম করেছে। বিক্রয় বন্ধ করা হয়েছে।',
      );
    }

    return MobileClientResponse.ok(
      eval,
      messageEn: 'Batch verified and approved for sale.',
      messageBn: 'ব্যাচটি বিক্রির জন্য নিরাপদ ও অনুমোদিত।',
    );
  }
}

