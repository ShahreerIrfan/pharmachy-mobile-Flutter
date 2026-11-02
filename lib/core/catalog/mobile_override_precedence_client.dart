// lib/core/catalog/mobile_override_precedence_client.dart
// Architecture Decision: ADR-0128
// Phase 07: Milestone M04 - Shared Medicine Catalog & Dynamic Packaging Units (P128)

enum MobilePrecedenceUiStatus {
  success,
  error,
  permissionDenied,
  empty,
  offline,
}

class MobileFieldProvenance {
  final dynamic value;
  final String source; // TENANT_OVERRIDE, GLOBAL_MASTER, REGULATORY_MANDATE
  final String rule;

  const MobileFieldProvenance({
    required this.value,
    required this.source,
    required this.rule,
  });

  factory MobileFieldProvenance.fromJson(Map<String, dynamic> json) {
    return MobileFieldProvenance(
      value: json['value'],
      source: json['source'] ?? 'GLOBAL_MASTER',
      rule: json['rule'] ?? 'MASTER_DEFAULT',
    );
  }
}

class MobileMasterMedicine {
  final String productId;
  final String brandName;
  final String genericName;
  final String dosageForm;
  final String strength;
  final double mrpUnit;
  final double costUnit;
  final bool isPrescriptionOnly;
  final bool isNarcotic;
  final bool isAntibiotic;

  const MobileMasterMedicine({
    required this.productId,
    required this.brandName,
    required this.genericName,
    required this.dosageForm,
    required this.strength,
    required this.mrpUnit,
    required this.costUnit,
    this.isPrescriptionOnly = false,
    this.isNarcotic = false,
    this.isAntibiotic = false,
  });
}

class MobileTenantOverride {
  final String configId;
  final String tenantId;
  final String productId;
  final String localBrandName;
  final String localSku;
  final double? customMrpUnit;
  final double? customCostUnit;
  final bool isVisible;
  final String shelfLocation;
  final int lowStockThreshold;
  final bool? requiresPrescriptionOverride;
  final String moderationStatus; // APPROVED, PENDING_REVIEW, REJECTED
  final String moderationReason;

  const MobileTenantOverride({
    required this.configId,
    required this.tenantId,
    required this.productId,
    this.localBrandName = '',
    this.localSku = '',
    this.customMrpUnit,
    this.customCostUnit,
    this.isVisible = true,
    this.shelfLocation = '',
    this.lowStockThreshold = 10,
    this.requiresPrescriptionOverride,
    this.moderationStatus = 'APPROVED',
    this.moderationReason = '',
  });
}

class MobileResolvedMedicine {
  final String productId;
  final String tenantId;
  final String effectiveBrandName;
  final double effectiveMrpUnit;
  final double effectiveCostUnit;
  final bool effectiveRequiresPrescription;
  final bool effectiveIsVisible;
  final String effectiveShelfLocation;
  final int effectiveLowStockThreshold;
  final bool isOverridden;
  final String moderationStatus;
  final Map<String, MobileFieldProvenance> provenance;

  const MobileResolvedMedicine({
    required this.productId,
    required this.tenantId,
    required this.effectiveBrandName,
    required this.effectiveMrpUnit,
    required this.effectiveCostUnit,
    required this.effectiveRequiresPrescription,
    required this.effectiveIsVisible,
    required this.effectiveShelfLocation,
    required this.effectiveLowStockThreshold,
    required this.isOverridden,
    required this.moderationStatus,
    required this.provenance,
  });
}

class MobilePrecedenceResult<T> {
  final MobilePrecedenceUiStatus status;
  final String? errorCode;
  final String messageEn;
  final String messageBn;
  final T? data;

  const MobilePrecedenceResult({
    required this.status,
    this.errorCode,
    required this.messageEn,
    required this.messageBn,
    this.data,
  });

  static MobilePrecedenceResult<T> success<T>({
    required String messageEn,
    required String messageBn,
    T? data,
  }) {
    return MobilePrecedenceResult<T>(
      status: MobilePrecedenceUiStatus.success,
      messageEn: messageEn,
      messageBn: messageBn,
      data: data,
    );
  }

  static MobilePrecedenceResult<T> error<T>({
    required String code,
    required String messageEn,
    required String messageBn,
  }) {
    return MobilePrecedenceResult<T>(
      status: MobilePrecedenceUiStatus.error,
      errorCode: code,
      messageEn: messageEn,
      messageBn: messageBn,
    );
  }

  static MobilePrecedenceResult<T> permissionDenied<T>({
    required String code,
    required String messageEn,
    required String messageBn,
  }) {
    return MobilePrecedenceResult<T>(
      status: MobilePrecedenceUiStatus.permissionDenied,
      errorCode: code,
      messageEn: messageEn,
      messageBn: messageBn,
    );
  }

  static MobilePrecedenceResult<T> offline<T>({
    required String messageEn,
    required String messageBn,
    T? data,
  }) {
    return MobilePrecedenceResult<T>(
      status: MobilePrecedenceUiStatus.offline,
      errorCode: 'OFFLINE_CACHE',
      messageEn: messageEn,
      messageBn: messageBn,
      data: data,
    );
  }
}

class MobileOverridePrecedenceClient {
  final Map<String, MobileMasterMedicine> _masters = {};
  final Map<String, MobileTenantOverride> _overrides = {};
  final Map<String, MobileResolvedMedicine> _localCache = {};

  void registerMaster(MobileMasterMedicine master) {
    _masters[master.productId] = master;
  }

  void registerOverride(MobileTenantOverride override) {
    final key = '${override.tenantId}:${override.productId}';
    _overrides[key] = override;
  }

  MobilePrecedenceResult<MobileResolvedMedicine> resolvePrecedence({
    required String callerTenantId,
    required String targetTenantId,
    required String productId,
    bool isOnline = true,
  }) {
    if (callerTenantId != targetTenantId) {
      return MobilePrecedenceResult.permissionDenied(
        code: 'ERR_CROSS_TENANT_ACCESS',
        messageEn: 'Cross-tenant access violation: Cannot resolve medicine for foreign tenant.',
        messageBn: 'ভিন্ন ফার্মেসির ওষুধ ওভাররাইড অ্যাক্সেস করা সম্পূর্ণ নিষিদ্ধ।',
      );
    }

    final cacheKey = '$targetTenantId:$productId';
    final master = _masters[productId];

    if (!isOnline) {
      final cached = _localCache[cacheKey];
      if (cached != null) {
        return MobilePrecedenceResult.offline(
          messageEn: 'Resolved from offline cache.',
          messageBn: 'অফলাইন ক্যাশ থেকে ডেটা লোড করা হয়েছে।',
          data: cached,
        );
      }
      return MobilePrecedenceResult.error(
        code: 'ERR_OFFLINE_NO_CACHE',
        messageEn: 'No offline cache available.',
        messageBn: 'কোনো অফলাইন ক্যাশ পাওয়া যায়নি।',
      );
    }

    if (master == null) {
      return MobilePrecedenceResult.error(
        code: 'ERR_MASTER_NOT_FOUND',
        messageEn: 'Global master medicine product does not exist.',
        messageBn: 'মাস্টার ওষুধ পাওয়া যায়নি।',
      );
    }

    final override = _overrides[cacheKey];
    final prov = <String, MobileFieldProvenance>{};

    // 1. Brand Name
    String effectiveBrand;
    if (override != null &&
        override.localBrandName.trim().isNotEmpty &&
        override.moderationStatus == 'APPROVED') {
      effectiveBrand = override.localBrandName.trim();
      prov['brand_name'] = MobileFieldProvenance(
        value: effectiveBrand,
        source: 'TENANT_OVERRIDE',
        rule: 'ACTIVE_TENANT_OVERRIDE',
      );
    } else {
      effectiveBrand = master.brandName;
      prov['brand_name'] = MobileFieldProvenance(
        value: effectiveBrand,
        source: 'GLOBAL_MASTER',
        rule: 'MASTER_DEFAULT',
      );
    }

    // 2. MRP Precedence & Moderation
    double effectiveMrp;
    if (override != null && override.customMrpUnit != null) {
      if (override.moderationStatus == 'APPROVED') {
        effectiveMrp = override.customMrpUnit!;
        prov['mrp_unit'] = MobileFieldProvenance(
          value: effectiveMrp,
          source: 'TENANT_OVERRIDE',
          rule: 'ACTIVE_TENANT_OVERRIDE',
        );
      } else if (override.moderationStatus == 'PENDING_REVIEW') {
        effectiveMrp = master.mrpUnit;
        prov['mrp_unit'] = MobileFieldProvenance(
          value: effectiveMrp,
          source: 'GLOBAL_MASTER',
          rule: 'MODERATION_PENDING_FALLBACK',
        );
      } else {
        effectiveMrp = master.mrpUnit;
        prov['mrp_unit'] = MobileFieldProvenance(
          value: effectiveMrp,
          source: 'GLOBAL_MASTER',
          rule: 'MODERATION_REJECTED_FALLBACK',
        );
      }
    } else {
      effectiveMrp = master.mrpUnit;
      prov['mrp_unit'] = MobileFieldProvenance(
        value: effectiveMrp,
        source: 'GLOBAL_MASTER',
        rule: 'MASTER_DEFAULT',
      );
    }

    // 3. Cost Precedence
    double effectiveCost;
    if (override != null && override.customCostUnit != null && override.moderationStatus == 'APPROVED') {
      effectiveCost = override.customCostUnit!;
      prov['cost_unit'] = MobileFieldProvenance(
        value: effectiveCost,
        source: 'TENANT_OVERRIDE',
        rule: 'ACTIVE_TENANT_OVERRIDE',
      );
    } else {
      effectiveCost = master.costUnit;
      prov['cost_unit'] = MobileFieldProvenance(
        value: effectiveCost,
        source: 'GLOBAL_MASTER',
        rule: 'MASTER_DEFAULT',
      );
    }

    // 4. Regulatory Safety Non-Relaxation
    bool effectiveRx;
    if (master.isPrescriptionOnly) {
      effectiveRx = true;
      prov['is_prescription_required'] = const MobileFieldProvenance(
        value: true,
        source: 'REGULATORY_MANDATE',
        rule: 'DGDA_POM_MANDATE',
      );
    } else if (master.isNarcotic) {
      effectiveRx = true;
      prov['is_prescription_required'] = const MobileFieldProvenance(
        value: true,
        source: 'REGULATORY_MANDATE',
        rule: 'DGDA_NARCOTIC_MANDATE',
      );
    } else if (master.isAntibiotic) {
      effectiveRx = true;
      prov['is_prescription_required'] = const MobileFieldProvenance(
        value: true,
        source: 'REGULATORY_MANDATE',
        rule: 'DGDA_ANTIBIOTIC_MANDATE',
      );
    } else if (override != null &&
        override.requiresPrescriptionOverride == true &&
        override.moderationStatus == 'APPROVED') {
      effectiveRx = true;
      prov['is_prescription_required'] = const MobileFieldProvenance(
        value: true,
        source: 'TENANT_OVERRIDE',
        rule: 'ACTIVE_TENANT_OVERRIDE',
      );
    } else {
      effectiveRx = false;
      prov['is_prescription_required'] = const MobileFieldProvenance(
        value: false,
        source: 'GLOBAL_MASTER',
        rule: 'MASTER_DEFAULT',
      );
    }

    // 5. Visibility
    final effectiveVis = override == null || override.isVisible;
    prov['is_visible'] = MobileFieldProvenance(
      value: effectiveVis,
      source: override != null && !override.isVisible ? 'TENANT_OVERRIDE' : 'GLOBAL_MASTER',
      rule: 'MASTER_DEFAULT',
    );

    // 6. Shelf location
    final shelf = override?.shelfLocation ?? '';
    prov['shelf_location'] = MobileFieldProvenance(
      value: shelf,
      source: override != null && shelf.isNotEmpty ? 'TENANT_OVERRIDE' : 'GLOBAL_MASTER',
      rule: 'MASTER_DEFAULT',
    );

    final threshold = override?.lowStockThreshold ?? 10;
    prov['low_stock_threshold'] = MobileFieldProvenance(
      value: threshold,
      source: override != null ? 'TENANT_OVERRIDE' : 'GLOBAL_MASTER',
      rule: 'MASTER_DEFAULT',
    );

    final result = MobileResolvedMedicine(
      productId: master.productId,
      tenantId: targetTenantId,
      effectiveBrandName: effectiveBrand,
      effectiveMrpUnit: effectiveMrp,
      effectiveCostUnit: effectiveCost,
      effectiveRequiresPrescription: effectiveRx,
      effectiveIsVisible: effectiveVis,
      effectiveShelfLocation: shelf,
      effectiveLowStockThreshold: threshold,
      isOverridden: override != null,
      moderationStatus: override?.moderationStatus ?? 'NOT_APPLICABLE',
      provenance: prov,
    );

    _localCache[cacheKey] = result;
    return MobilePrecedenceResult.success(
      messageEn: 'Precedence resolved.',
      messageBn: 'প্রিসিডেন্স সফলভাবে নির্ণয় করা হয়েছে।',
      data: result,
    );
  }

  MobilePrecedenceResult<MobileResolvedMedicine> proposeOverride({
    required String callerTenantId,
    required String targetTenantId,
    required String userRole,
    required String productId,
    required String localBrandName,
    double? customMrp,
    bool? requiresPrescriptionOverride,
  }) {
    if (userRole.toUpperCase() == 'CASHIER') {
      return MobilePrecedenceResult.permissionDenied(
        code: 'ERR_STAFF_ROLE_DENIED',
        messageEn: 'Cashiers cannot mutate tenant medicine overrides.',
        messageBn: 'ক্যাশিয়াররা ওষুধ ওভাররাইড পরিবর্তন করতে পারবেন না।',
      );
    }

    if (callerTenantId != targetTenantId) {
      return MobilePrecedenceResult.permissionDenied(
        code: 'ERR_CROSS_TENANT_ACCESS',
        messageEn: 'Cross-tenant access violation.',
        messageBn: 'ভিন্ন ফার্মেসির ওষুধ ওভাররাইড অ্যাক্সেস করা সম্পূর্ণ নিষিদ্ধ।',
      );
    }

    final master = _masters[productId];
    if (master == null) {
      return MobilePrecedenceResult.error(
        code: 'ERR_MASTER_NOT_FOUND',
        messageEn: 'Master product not found.',
        messageBn: 'মাস্টার ওষুধ পাওয়া যায়নি।',
      );
    }

    // Regulatory Invariant Check
    if (requiresPrescriptionOverride == false &&
        (master.isPrescriptionOnly || master.isNarcotic || master.isAntibiotic)) {
      return MobilePrecedenceResult.error(
        code: 'ERR_REGULATORY_RELAXATION_FORBIDDEN',
        messageEn: 'Cannot relax DGDA prescription mandate on a regulated drug.',
        messageBn: 'প্রেসক্রিপশন ওষুধের বিধিনিষেধ শিথিল করা আইনত নিষিদ্ধ।',
      );
    }

    // Anti-Gouging Check (+50% ceiling)
    String moderationStatus = 'APPROVED';
    String moderationReason = 'Auto-approved within standard threshold.';
    if (customMrp != null) {
      final maxAllowed = master.mrpUnit * 1.50;
      if (customMrp > maxAllowed) {
        moderationStatus = 'PENDING_REVIEW';
        moderationReason = 'Price exceeds +50% threshold. Awaiting compliance moderation.';
      }
    }

    final key = '$targetTenantId:$productId';
    final override = MobileTenantOverride(
      configId: 'tmc-${DateTime.now().millisecondsSinceEpoch}',
      tenantId: targetTenantId,
      productId: productId,
      localBrandName: localBrandName,
      customMrpUnit: customMrp,
      requiresPrescriptionOverride: requiresPrescriptionOverride,
      moderationStatus: moderationStatus,
      moderationReason: moderationReason,
    );
    _overrides[key] = override;

    return resolvePrecedence(
      callerTenantId: callerTenantId,
      targetTenantId: targetTenantId,
      productId: productId,
      isOnline: true,
    );
  }
}
