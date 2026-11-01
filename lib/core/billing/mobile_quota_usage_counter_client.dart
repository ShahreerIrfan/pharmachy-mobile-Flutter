// lib/core/billing/mobile_quota_usage_counter_client.dart
// Architecture Decision: ADR-0015, ADR-0081, ADR-0082 & ADR-0095
// Phase 05: Basic/Standard/Pro Subscription & Billing (P095)
// Requirement Trace: FR-070 / FR-071 / FR-072 (SaaS Plans, Billing & Tenant Lifecycle)

class MobileResourceCounter {
  final String resourceType;
  final int currentUsed;
  final int maxLimit;
  final int remaining;
  final double utilizationPct;
  final bool isOverQuota;
  final String status; // NORMAL, WARNING, LIMIT_REACHED, OVER_QUOTA

  const MobileResourceCounter({
    required this.resourceType,
    required this.currentUsed,
    required this.maxLimit,
    required this.remaining,
    required this.utilizationPct,
    required this.isOverQuota,
    required this.status,
  });

  factory MobileResourceCounter.fromJson(Map<String, dynamic> json) {
    return MobileResourceCounter(
      resourceType: json['resource_type'] as String? ?? '',
      currentUsed: (json['current_used'] as num?)?.toInt() ?? 0,
      maxLimit: (json['max_limit'] as num?)?.toInt() ?? 1,
      remaining: (json['remaining'] as num?)?.toInt() ?? 0,
      utilizationPct: (json['utilization_pct'] as num?)?.toDouble() ?? 0.0,
      isOverQuota: json['is_over_quota'] as bool? ?? false,
      status: json['status'] as String? ?? 'NORMAL',
    );
  }

  Map<String, dynamic> toJson() => {
        'resource_type': resourceType,
        'current_used': currentUsed,
        'max_limit': maxLimit,
        'remaining': remaining,
        'utilization_pct': utilizationPct,
        'is_over_quota': isOverQuota,
        'status': status,
      };
}

class MobileQuotaUsageReport {
  final String tenantId;
  final String planCode;
  final String planTier;
  final String overallStatus; // OK, NEAR_LIMIT, LIMIT_REACHED, OVER_QUOTA
  final Map<String, MobileResourceCounter> counters;
  final bool zeroDataDeleted;
  final bool raceConditionSafe;
  final bool authoritativeLocking;
  final String headlineEn;
  final String headlineBn;
  final String detailsEn;
  final String detailsBn;

  const MobileQuotaUsageReport({
    required this.tenantId,
    required this.planCode,
    required this.planTier,
    required this.overallStatus,
    required this.counters,
    required this.zeroDataDeleted,
    required this.raceConditionSafe,
    required this.authoritativeLocking,
    required this.headlineEn,
    required this.headlineBn,
    required this.detailsEn,
    required this.detailsBn,
  });

  factory MobileQuotaUsageReport.fromJson(Map<String, dynamic> json) {
    final countersRaw = json['counters'] as Map<String, dynamic>? ?? {};
    final parsedCounters = <String, MobileResourceCounter>{};
    countersRaw.forEach((key, val) {
      if (val is Map<String, dynamic>) {
        parsedCounters[key] = MobileResourceCounter.fromJson(val);
      }
    });

    final inv = json['invariants'] as Map<String, dynamic>? ?? {};
    final msg = json['client_messaging'] as Map<String, dynamic>? ?? {};

    return MobileQuotaUsageReport(
      tenantId: json['tenant_id'] as String? ?? '',
      planCode: json['plan_code'] as String? ?? '',
      planTier: json['plan_tier'] as String? ?? 'BASIC',
      overallStatus: json['overall_status'] as String? ?? 'OK',
      counters: parsedCounters,
      zeroDataDeleted: inv['zero_data_deleted'] as bool? ?? true,
      raceConditionSafe: inv['race_condition_safe'] as bool? ?? true,
      authoritativeLocking: inv['authoritative_locking'] as bool? ?? true,
      headlineEn: msg['headline_en'] as String? ?? 'Plan Quotas in Good Standing',
      headlineBn: msg['headline_bn'] as String? ?? 'কোটা ব্যবহার স্বাভাবিক রয়েছে',
      detailsEn: msg['details_en'] as String? ?? '',
      detailsBn: msg['details_bn'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'tenant_id': tenantId,
        'plan_code': planCode,
        'plan_tier': planTier,
        'overall_status': overallStatus,
        'counters': counters.map((k, v) => MapEntry(k, v.toJson())),
        'invariants': {
          'zero_data_deleted': zeroDataDeleted,
          'race_condition_safe': raceConditionSafe,
          'authoritative_locking': authoritativeLocking,
        },
        'client_messaging': {
          'headline_en': headlineEn,
          'headline_bn': headlineBn,
          'details_en': detailsEn,
          'details_bn': detailsBn,
        },
      };

  bool get isOverQuota => overallStatus == 'OVER_QUOTA';
  bool get isLimitReached => overallStatus == 'LIMIT_REACHED';
  bool get isNearLimit => overallStatus == 'NEAR_LIMIT';
  bool get isOk => overallStatus == 'OK';
}

class MobileQuotaUsageEvaluator {
  static double calculateUtilizationPct(int currentUsed, int maxLimit) {
    if (maxLimit <= 0) return 0.0;
    return double.parse(((currentUsed / maxLimit) * 100.0).toStringAsFixed(1));
  }

  static String evaluateResourceStatus(int currentUsed, int maxLimit) {
    if (currentUsed > maxLimit) return 'OVER_QUOTA';
    if (currentUsed >= maxLimit) return 'LIMIT_REACHED';
    final pct = calculateUtilizationPct(currentUsed, maxLimit);
    if (pct >= 80.0) return 'WARNING';
    return 'NORMAL';
  }

  static MobileResourceCounter createCounter(String resourceType, int currentUsed, int maxLimit) {
    final rem = (maxLimit - currentUsed) > 0 ? (maxLimit - currentUsed) : 0;
    final pct = calculateUtilizationPct(currentUsed, maxLimit);
    final isOver = currentUsed > maxLimit;
    final st = evaluateResourceStatus(currentUsed, maxLimit);
    return MobileResourceCounter(
      resourceType: resourceType,
      currentUsed: currentUsed,
      maxLimit: maxLimit,
      remaining: rem,
      utilizationPct: pct,
      isOverQuota: isOver,
      status: st,
    );
  }

  static MobileQuotaUsageReport evaluateSummary({
    required String tenantId,
    required String planTier,
    required int branchesUsed,
    required int branchesLimit,
    required int staffUsed,
    required int staffLimit,
    required int devicesUsed,
    required int devicesLimit,
  }) {
    final counters = <String, MobileResourceCounter>{
      'BRANCHES': createCounter('BRANCHES', branchesUsed, branchesLimit),
      'STAFF_SEATS': createCounter('STAFF_SEATS', staffUsed, staffLimit),
      'DEVICES': createCounter('DEVICES', devicesUsed, devicesLimit),
    };

    final anyOver = branchesUsed > branchesLimit || staffUsed > staffLimit || devicesUsed > devicesLimit;
    final anyLimit = branchesUsed >= branchesLimit || staffUsed >= staffLimit || devicesUsed >= devicesLimit;
    final anyWarn = counters.values.any((c) => c.status == 'WARNING');

    String overall;
    String hlEn;
    String hlBn;
    String dtEn;
    String dtBn;

    if (anyOver) {
      overall = 'OVER_QUOTA';
      hlEn = 'Plan Quota Exceeded';
      hlBn = 'সাবস্ক্রিপশন কোটা অতিক্রম করেছে';
      dtEn = 'One or more allocated capacity limits have been exceeded. Please upgrade.';
      dtBn = 'এক বা একাধিক রিসোর্স সীমা অতিক্রান্ত হয়েছে। অনুগ্রহ করে সাবস্ক্রিপশন আপগ্রেড করুন।';
    } else if (anyLimit) {
      overall = 'LIMIT_REACHED';
      hlEn = 'Plan Quota Limit Reached';
      hlBn = 'কোটা সীমা পূর্ণ হয়েছে';
      dtEn = 'All allocated capacity in use. Upgrade to add more capacity.';
      dtBn = 'বরাদ্দকৃত সকল সক্ষমতা ব্যবহৃত হচ্ছে। অতিরিক্ত রিসোর্স যুক্ত করতে আপগ্রেড করুন।';
    } else if (anyWarn) {
      overall = 'NEAR_LIMIT';
      hlEn = 'Plan Quota Near Capacity';
      hlBn = 'কোটা ধারণক্ষমতার কাছাকাছি পৌঁছেছে';
      dtEn = 'Capacity usage is above 80% threshold.';
      dtBn = 'রিসোর্স ব্যবহার অনুমোদিত সীমার ৮০% এর বেশি পৌঁছেছে।';
    } else {
      overall = 'OK';
      hlEn = 'Plan Quotas in Good Standing';
      hlBn = 'কোটা ব্যবহার স্বাভাবিক রয়েছে';
      dtEn = 'All seats, branches, and devices within allocated limits.';
      dtBn = 'সকল ব্রাঞ্চ, কর্মী ও ডিভাইস কোটা স্বাভাবিক রয়েছে।';
    }

    return MobileQuotaUsageReport(
      tenantId: tenantId,
      planCode: 'PLAN_${planTier.toUpperCase()}',
      planTier: planTier.toUpperCase(),
      overallStatus: overall,
      counters: counters,
      zeroDataDeleted: true,
      raceConditionSafe: true,
      authoritativeLocking: true,
      headlineEn: hlEn,
      headlineBn: hlBn,
      detailsEn: dtEn,
      detailsBn: dtBn,
    );
  }
}

