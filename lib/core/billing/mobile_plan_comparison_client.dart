/// mobile_plan_comparison_client.dart
///
/// Architecture Decision: ADR-0015, ADR-0081 & ADR-0083
/// Phase 05: Basic/Standard/Pro Subscription & Billing (P083)
///
/// Mobile Manager Plan Comparison, Annual Savings & Checkout Client:
///   - Side-by-side plan comparisons with BDT pricing and annual discount math.
///   - Invariant INV-SAFETY-01: Clinical safety controls are guaranteed non-gated across all tiers.
///   - Quota boundaries (branch, device, staff limits) and downgrade violation checks.
///   - Offline-first fallback comparison matrix with bilingual EN/BN support.
library mobile_plan_comparison_client;

class ClinicalSafetyGuarantee {
  final String key;
  final String nameEn;
  final String nameBn;
  final String descriptionEn;
  final String descriptionBn;
  final bool guaranteed;

  const ClinicalSafetyGuarantee({
    required this.key,
    required this.nameEn,
    required this.nameBn,
    required this.descriptionEn,
    required this.descriptionBn,
    this.guaranteed = true,
  });
}

class BillingCycleOption {
  final String cycle;
  final int durationDays;
  final String labelEn;
  final String labelBn;
  final String savingsLabelEn;
  final String savingsLabelBn;

  const BillingCycleOption({
    required this.cycle,
    required this.durationDays,
    required this.labelEn,
    required this.labelBn,
    required this.savingsLabelEn,
    required this.savingsLabelBn,
  });
}

class PlanComparisonCard {
  final String planCode;
  final String tier;
  final String name;
  final String descriptionEn;
  final String descriptionBn;
  final double monthlyPriceBdt;
  final double annualPriceBdt;
  final double effectiveMonthlyBdt;
  final double annualSavingsBdt;
  final String savingsPercentage;
  final int maxBranches;
  final int maxDevicesPerBranch;
  final int maxTotalDevices;
  final int maxStaffUsers;
  final Map<String, bool> features;
  final String badgeEn;
  final String badgeBn;

  PlanComparisonCard({
    required this.planCode,
    required this.tier,
    required this.name,
    required this.descriptionEn,
    required this.descriptionBn,
    required this.monthlyPriceBdt,
    required this.annualPriceBdt,
    required this.maxBranches,
    required this.maxDevicesPerBranch,
    required this.maxTotalDevices,
    required this.maxStaffUsers,
    required this.features,
    required this.badgeEn,
    required this.badgeBn,
  })  : annualSavingsBdt = (monthlyPriceBdt * 12) - annualPriceBdt,
        savingsPercentage = ((monthlyPriceBdt * 12) > 0)
            ? '${((((monthlyPriceBdt * 12) - annualPriceBdt) / (monthlyPriceBdt * 12)) * 100).toStringAsFixed(2)}%'
            : '0.00%',
        effectiveMonthlyBdt = double.parse((annualPriceBdt / 12).toStringAsFixed(2));
}

class PlanQuote {
  final String tenantId;
  final String planCode;
  final String planTier;
  final String billingCycle;
  final String currency;
  final double subtotalBdt;
  final double discountBdt;
  final double totalBdt;
  final double effectiveMonthlyBdt;
  final String savingsPercentage;
  final int renewalPeriodDays;
  final String projectedRenewalDate;
  final bool safetyFeaturesGuaranteed;
  final bool isCompliant;
  final List<String> violations;

  const PlanQuote({
    required this.tenantId,
    required this.planCode,
    required this.planTier,
    required this.billingCycle,
    required this.currency,
    required this.subtotalBdt,
    required this.discountBdt,
    required this.totalBdt,
    required this.effectiveMonthlyBdt,
    required this.savingsPercentage,
    required this.renewalPeriodDays,
    required this.projectedRenewalDate,
    required this.safetyFeaturesGuaranteed,
    required this.isCompliant,
    required this.violations,
  });
}

class MobilePlanComparisonClient {
  static const Set<String> clinicalSafetyFeatures = {
    'ANTIBIOTIC_REGISTER',
    'BATCH_EXPIRY_BLOCK',
    'RECALL_QUARANTINE',
    'BANNED_DRUG_RESTRICTION',
    'RX_VERIFICATION',
  };

  static const Set<String> validBillingCycles = {
    'MONTHLY',
    'ANNUAL',
  };

  static const Set<String> validPlanCodes = {
    'PLAN_BASIC',
    'PLAN_STANDARD',
    'PLAN_PRO',
  };

  /// Invariant INV-SAFETY-01: Verifies whether a given feature is guaranteed across all plans.
  static bool isClinicallyGuaranteed(String? featureKey) {
    if (featureKey == null || featureKey.trim().isEmpty) return false;
    return clinicalSafetyFeatures.contains(featureKey.toUpperCase().trim());
  }

  /// Validates quote request parameters prior to sending to the API.
  static void validateQuoteRequest({
    required String tenantId,
    required String planCode,
    required String billingCycle,
  }) {
    if (tenantId.trim().isEmpty) {
      throw ArgumentError('Tenant ID is required for plan quote calculation.');
    }
    if (!validPlanCodes.contains(planCode.toUpperCase().trim())) {
      throw ArgumentError('Invalid plan code: $planCode. Allowed: $validPlanCodes');
    }
    if (!validBillingCycles.contains(billingCycle.toUpperCase().trim())) {
      throw ArgumentError('Invalid billing cycle: $billingCycle. Allowed: $validBillingCycles');
    }
  }

  /// Deterministic client-side quote calculation for instant UI rendering and offline mode.
  static PlanQuote calculateQuote({
    required String tenantId,
    required String planCode,
    required String billingCycle,
    int activeBranches = 1,
    int activeStaff = 1,
  }) {
    validateQuoteRequest(tenantId: tenantId, planCode: planCode, billingCycle: billingCycle);

    final cleanCode = planCode.toUpperCase().trim();
    final cleanCycle = billingCycle.toUpperCase().trim();

    final card = getComparisonCard(cleanCode);
    final monthlyPrice = card.monthlyPriceBdt;
    final annualPrice = card.annualPriceBdt;

    final double subtotal;
    final double discount;
    final double total;
    final double effectiveMonthly;
    final String savingsPct;
    final int durationDays;

    if (cleanCycle == 'ANNUAL') {
      subtotal = monthlyPrice * 12;
      discount = subtotal - annualPrice;
      total = annualPrice;
      effectiveMonthly = double.parse((annualPrice / 12).toStringAsFixed(2));
      savingsPct = card.savingsPercentage;
      durationDays = 365;
    } else {
      subtotal = monthlyPrice;
      discount = 0.0;
      total = monthlyPrice;
      effectiveMonthly = monthlyPrice;
      savingsPct = '0.00%';
      durationDays = 30;
    }

    final renewalDate = DateTime.now().add(Duration(days: durationDays));
    final renewalDateStr =
        '${renewalDate.year}-${renewalDate.month.toString().padLeft(2, '0')}-${renewalDate.day.toString().padLeft(2, '0')}';

    final violations = <String>[];
    if (activeBranches > card.maxBranches) {
      violations.add('Active branches ($activeBranches) exceed plan limit (${card.maxBranches})');
    }
    if (activeStaff > card.maxStaffUsers) {
      violations.add('Active staff ($activeStaff) exceed plan limit (${card.maxStaffUsers})');
    }

    return PlanQuote(
      tenantId: tenantId,
      planCode: cleanCode,
      planTier: card.tier,
      billingCycle: cleanCycle,
      currency: 'BDT',
      subtotalBdt: double.parse(subtotal.toStringAsFixed(2)),
      discountBdt: double.parse(discount.toStringAsFixed(2)),
      totalBdt: double.parse(total.toStringAsFixed(2)),
      effectiveMonthlyBdt: effectiveMonthly,
      savingsPercentage: savingsPct,
      renewalPeriodDays: durationDays,
      projectedRenewalDate: renewalDateStr,
      safetyFeaturesGuaranteed: true,
      isCompliant: violations.isEmpty,
      violations: violations,
    );
  }

  static PlanComparisonCard getComparisonCard(String planCode) {
    for (final card in getCanonicalComparisonPlans()) {
      if (card.planCode.toUpperCase() == planCode.toUpperCase()) {
        return card;
      }
    }
    throw ArgumentError('Unknown plan code: $planCode');
  }

  static List<PlanComparisonCard> getCanonicalComparisonPlans() {
    return [
      PlanComparisonCard(
        planCode: 'PLAN_BASIC',
        tier: 'BASIC',
        name: 'Basic Pharmacy',
        descriptionEn: 'Essential single-branch pharmacy POS with regulatory compliance and offline sync.',
        descriptionBn: 'নিয়ন্ত্রক কমপ্লায়েন্স ও অফলাইন সিঙ্ক সহ একক শাখার জন্য বেসিক ফার্মেসি সমাধান।',
        monthlyPriceBdt: 1500.0,
        annualPriceBdt: 15000.0,
        maxBranches: 1,
        maxDevicesPerBranch: 1,
        maxTotalDevices: 1,
        maxStaffUsers: 3,
        features: const {
          'ANTIBIOTIC_REGISTER': true,
          'BATCH_EXPIRY_BLOCK': true,
          'RECALL_QUARANTINE': true,
          'BANNED_DRUG_RESTRICTION': true,
          'RX_VERIFICATION': true,
          'OFFLINE_SYNC': true,
          'THERMAL_RECEIPT_PRINT': true,
          'MEDICINE_CATALOG': true,
          'BASIC_INVENTORY': true,
          'PURCHASE_ORDERS': false,
          'SUPPLIER_DUES': false,
          'CUSTOMER_LEDGER': false,
          'FLUTTER_OWNER_APP': false,
          'CONSOLIDATED_REPORTING': false,
        },
        badgeEn: 'Starter Pharmacy',
        badgeBn: 'স্টার্টার ফার্মেসি',
      ),
      PlanComparisonCard(
        planCode: 'PLAN_STANDARD',
        tier: 'STANDARD',
        name: 'Standard Pharmacy',
        descriptionEn: 'Growing pharmacy with multi-branch management, supplier dues, and mobile owner app.',
        descriptionBn: 'বহু-শাখা ব্যবস্থাপনা, সরবরাহকারী বাকি ও মোবাইল অ্যাপ সহ স্ট্যান্ডার্ড ফার্মেসি সমাধান।',
        monthlyPriceBdt: 3500.0,
        annualPriceBdt: 35000.0,
        maxBranches: 3,
        maxDevicesPerBranch: 5,
        maxTotalDevices: 15,
        maxStaffUsers: 10,
        features: const {
          'ANTIBIOTIC_REGISTER': true,
          'BATCH_EXPIRY_BLOCK': true,
          'RECALL_QUARANTINE': true,
          'BANNED_DRUG_RESTRICTION': true,
          'RX_VERIFICATION': true,
          'OFFLINE_SYNC': true,
          'THERMAL_RECEIPT_PRINT': true,
          'MEDICINE_CATALOG': true,
          'BASIC_INVENTORY': true,
          'PURCHASE_ORDERS': true,
          'SUPPLIER_DUES': true,
          'CUSTOMER_LEDGER': true,
          'FLUTTER_OWNER_APP': true,
          'DAILY_BACKUP': true,
        },
        badgeEn: 'Most Popular',
        badgeBn: 'জনপ্রিয় পছন্দ',
      ),
      PlanComparisonCard(
        planCode: 'PLAN_PRO',
        tier: 'PRO',
        name: 'Pro Enterprise Pharmacy',
        descriptionEn: 'Enterprise multi-chain pharmacy with consolidated GL, API webhooks, and unlimited scale.',
        descriptionBn: 'বৃহৎ ফার্মেসি চেইনের জন্য সমন্বিত অডিট লেজার, এপিআই ওয়েবহুক ও উচ্চ ক্ষমতা সম্পন্ন সমাধান।',
        monthlyPriceBdt: 7500.0,
        annualPriceBdt: 75000.0,
        maxBranches: 50,
        maxDevicesPerBranch: 20,
        maxTotalDevices: 250,
        maxStaffUsers: 100,
        features: const {
          'ANTIBIOTIC_REGISTER': true,
          'BATCH_EXPIRY_BLOCK': true,
          'RECALL_QUARANTINE': true,
          'BANNED_DRUG_RESTRICTION': true,
          'RX_VERIFICATION': true,
          'OFFLINE_SYNC': true,
          'THERMAL_RECEIPT_PRINT': true,
          'MEDICINE_CATALOG': true,
          'BASIC_INVENTORY': true,
          'PURCHASE_ORDERS': true,
          'SUPPLIER_DUES': true,
          'CUSTOMER_LEDGER': true,
          'FLUTTER_OWNER_APP': true,
          'DAILY_BACKUP': true,
          'CONSOLIDATED_REPORTING': true,
          'MULTI_BRANCH_TRANSFER': true,
          'WEBHOOKS_AND_API': true,
          'HOURLY_RPO_BACKUP': true,
        },
        badgeEn: 'Enterprise Multi-Chain',
        badgeBn: 'এন্টারপ্রাইজ মাল্টি-চেইন',
      ),
    ];
  }

  static List<ClinicalSafetyGuarantee> getClinicalSafetyGuarantees() {
    return const [
      ClinicalSafetyGuarantee(
        key: 'ANTIBIOTIC_REGISTER',
        nameEn: 'Antibiotic Dispensing Register',
        nameBn: 'অ্যান্টিবায়োটিক বিতরণ রেজিস্টার',
        descriptionEn: 'Mandatory red-flagged antibiotic tracking and doctor prescription capture.',
        descriptionBn: 'বাধ্যতামূলক অ্যান্টিবায়োটিক ট্র্যাকিং ও প্রেসক্রিপশন সংরক্ষণ।',
      ),
      ClinicalSafetyGuarantee(
        key: 'BATCH_EXPIRY_BLOCK',
        nameEn: 'Batch Expiry POS Blocking',
        nameBn: 'মেয়াদোত্তীর্ণ ওষুধ বিক্রয় রোধ',
        descriptionEn: 'Automatic point-of-sale blocking for expired batches with FEFO enforcement.',
        descriptionBn: 'মেয়াদোত্তীর্ণ ওষুধ পয়েন্ট-অব-সেলে বিক্রয় স্বয়ংক্রিয়ভাবে বন্ধ এবং FEFO নীতি প্রয়োগ।',
      ),
      ClinicalSafetyGuarantee(
        key: 'RECALL_QUARANTINE',
        nameEn: 'DGDA Drug Recall Quarantine',
        nameBn: 'ডিজিডিএ ওষুধ প্রত্যাহার কোয়ারেন্টাইন',
        descriptionEn: 'Instant quarantine of manufacturer recalled batches preventing sale.',
        descriptionBn: 'প্রত্যাহারকৃত ব্যাচ অবিলম্বে কোয়ারেন্টাইনে স্থানান্তর ও বিক্রয় রোধ।',
      ),
      ClinicalSafetyGuarantee(
        key: 'BANNED_DRUG_RESTRICTION',
        nameEn: 'Banned Drug Dispensing Prevention',
        nameBn: 'নিষিদ্ধ ওষুধ বিক্রয় নিয়ন্ত্রণ',
        descriptionEn: 'Central restriction database blocking sale of regulatory banned medicines.',
        descriptionBn: 'নিয়ন্ত্রক সংস্থা কর্তৃক নিষিদ্ধ ওষুধের বিক্রয় প্রতিরোধ।',
      ),
      ClinicalSafetyGuarantee(
        key: 'RX_VERIFICATION',
        nameEn: 'Prescription Only (POM) Verification',
        nameBn: 'প্রেসক্রিপশন নির্ভর ওষুধ যাচাইকরণ',
        descriptionEn: 'Mandatory registered doctor verification for schedule G/H medicines.',
        descriptionBn: 'তফসিলি প্রেসক্রিপশন ওষুধের জন্য নিবন্ধিত চিকিৎসকের তথ্য যাচাই।',
      ),
    ];
  }

  static List<BillingCycleOption> getBillingCycleOptions() {
    return const [
      BillingCycleOption(
        cycle: 'MONTHLY',
        durationDays: 30,
        labelEn: 'Monthly',
        labelBn: 'মাসিক',
        savingsLabelEn: 'Standard monthly pricing',
        savingsLabelBn: 'সাধারণ মাসিক মূল্য',
      ),
      BillingCycleOption(
        cycle: 'ANNUAL',
        durationDays: 365,
        labelEn: 'Annual',
        labelBn: 'বার্ষিক',
        savingsLabelEn: 'Save 16.67% (2 Months Free)',
        savingsLabelBn: '১৬.৬৭% সাশ্রয় (২ মাস ফ্রি)',
      ),
    ];
  }
}
