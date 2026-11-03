// lib/core/catalog/mobile_suspension_reconstitution_client.dart
// Architecture Decision: ADR-0143 (P143)
// Phase 08: Specialized Dosage-Form Editors & Multi-Tier Packaging

enum MobileSuspensionUiStatus {
  loading,
  success,
  empty,
  error,
  permissionDenied,
  offline,
}

class MobileSuspensionReconstitutionConfig {
  final String configId;
  final String productId;
  final String brandName;
  final String genericName;
  final String? tenantId;
  final String dosageForm;
  final String reconstitutionDiluent;
  final double waterVolumeMl;
  final double finalVolumeMl;
  final int shelfLifeDays;
  final String? openingDate;
  final String? beyondUseDate;
  final String storagePolicy;
  final String instructionsEn;
  final String instructionsBn;
  final String handlingGuidanceEn;
  final String handlingGuidanceBn;
  final bool isPharmacistReviewed;
  final String? reviewedById;
  final String? reviewedByName;
  final String? reviewerNotes;
  final bool isActive;

  MobileSuspensionReconstitutionConfig({
    required this.configId,
    required this.productId,
    required this.brandName,
    required this.genericName,
    this.tenantId,
    required this.dosageForm,
    required this.reconstitutionDiluent,
    required this.waterVolumeMl,
    required this.finalVolumeMl,
    required this.shelfLifeDays,
    this.openingDate,
    this.beyondUseDate,
    required this.storagePolicy,
    required this.instructionsEn,
    required this.instructionsBn,
    required this.handlingGuidanceEn,
    required this.handlingGuidanceBn,
    required this.isPharmacistReviewed,
    this.reviewedById,
    this.reviewedByName,
    this.reviewerNotes,
    required this.isActive,
  });

  factory MobileSuspensionReconstitutionConfig.fromJson(Map<String, dynamic> json) {
    return MobileSuspensionReconstitutionConfig(
      configId: json['config_id']?.toString() ?? '',
      productId: json['product_id']?.toString() ?? '',
      brandName: json['brand_name']?.toString() ?? '',
      genericName: json['generic_name']?.toString() ?? '',
      tenantId: json['tenant_id']?.toString(),
      dosageForm: json['dosage_form']?.toString() ?? 'DRY_SYRUP_RECONSTITUTED',
      reconstitutionDiluent: json['reconstitution_diluent']?.toString() ?? 'BOILED_COOLED_WATER',
      waterVolumeMl: (json['water_volume_ml'] is num)
          ? (json['water_volume_ml'] as num).toDouble()
          : double.tryParse(json['water_volume_ml']?.toString() ?? '0.0') ?? 35.0,
      finalVolumeMl: (json['final_volume_ml'] is num)
          ? (json['final_volume_ml'] as num).toDouble()
          : double.tryParse(json['final_volume_ml']?.toString() ?? '0.0') ?? 50.0,
      shelfLifeDays: (json['shelf_life_days'] as num?)?.toInt() ?? 7,
      openingDate: json['opening_date']?.toString(),
      beyondUseDate: json['beyond_use_date']?.toString(),
      storagePolicy: json['storage_policy']?.toString() ?? 'REFRIGERATE_2_8C_AFTER_RECONSTITUTION',
      instructionsEn: json['instructions_en']?.toString() ?? '',
      instructionsBn: json['instructions_bn']?.toString() ?? '',
      handlingGuidanceEn: json['handling_guidance_en']?.toString() ?? '',
      handlingGuidanceBn: json['handling_guidance_bn']?.toString() ?? '',
      isPharmacistReviewed: json['is_pharmacist_reviewed'] == true,
      reviewedById: json['reviewed_by_id']?.toString(),
      reviewedByName: json['reviewed_by_name']?.toString(),
      reviewerNotes: json['reviewer_notes']?.toString(),
      isActive: json['is_active'] != false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'config_id': configId,
      'product_id': productId,
      'brand_name': brandName,
      'generic_name': genericName,
      'tenant_id': tenantId,
      'dosage_form': dosageForm,
      'reconstitution_diluent': reconstitutionDiluent,
      'water_volume_ml': waterVolumeMl,
      'final_volume_ml': finalVolumeMl,
      'shelf_life_days': shelfLifeDays,
      'opening_date': openingDate,
      'beyond_use_date': beyondUseDate,
      'storage_policy': storagePolicy,
      'instructions_en': instructionsEn,
      'instructions_bn': instructionsBn,
      'handling_guidance_en': handlingGuidanceEn,
      'handling_guidance_bn': handlingGuidanceBn,
      'is_pharmacist_reviewed': isPharmacistReviewed,
      'reviewed_by_id': reviewedById,
      'reviewed_by_name': reviewedByName,
      'reviewer_notes': reviewerNotes,
      'is_active': isActive,
    };
  }
}

class MobileSuspensionValidationResult {
  final bool isValid;
  final String? errorCode;
  final String messageEn;
  final String messageBn;

  MobileSuspensionValidationResult({
    required this.isValid,
    this.errorCode,
    required this.messageEn,
    required this.messageBn,
  });

  factory MobileSuspensionValidationResult.valid() {
    return MobileSuspensionValidationResult(
      isValid: true,
      messageEn: 'Validation passed.',
      messageBn: 'যাচাইকরণ সফল হয়েছে।',
    );
  }

  factory MobileSuspensionValidationResult.error({
    required String errorCode,
    required String messageEn,
    required String messageBn,
  }) {
    return MobileSuspensionValidationResult(
      isValid: false,
      errorCode: errorCode,
      messageEn: messageEn,
      messageBn: messageBn,
    );
  }
}

class MobileSuspensionReconstitutionClient {
  static const Set<String> hiddenFields = {
    'strips_per_box',
    'tablets_per_strip',
    'units_per_strip',
    'box_size',
    'loose_sale_eligible',
    'is_scored',
    'coating_type',
    'needle_gauge',
  };

  static const Set<String> authorizedRoles = {
    'STAFF_PHARMACIST',
    'PHARMACY_OWNER',
    'SUPERADMIN',
    'PLATFORM_OPERATOR',
    'PLATFORM_SUPER_ADMIN',
  };

  final Map<String, MobileSuspensionReconstitutionConfig> _localCache = {};
  bool isOfflineMode = false;

  bool isFieldHidden(String fieldName) {
    return hiddenFields.contains(fieldName.toLowerCase().trim());
  }

  DateTime calculateBeyondUseDate(DateTime openingDate, int shelfLifeDays) {
    return openingDate.add(Duration(days: shelfLifeDays));
  }

  MobileSuspensionValidationResult validatePayload(
    Map<String, dynamic> payload, {
    String? userRole,
  }) {
    // 1. Zero-Trust Hidden Field Guard (Reject solid oral tablet/strip fields)
    for (final hidden in hiddenFields) {
      if (payload.containsKey(hidden) && payload[hidden] != null) {
        return MobileSuspensionValidationResult.error(
          errorCode: 'ERR_HIDDEN_FIELD_VALUE_REJECTED',
          messageEn: "Field '$hidden' is prohibited for suspension reconstitution forms.",
          messageBn: "সাসপেনশন প্রস্তুতকরণের জন্য '$hidden' ফিল্ড অনুমোদিত নয়।",
        );
      }
    }

    // 2. Required Fields
    const required = [
      'dosage_form',
      'reconstitution_diluent',
      'water_volume_ml',
      'final_volume_ml',
      'shelf_life_days',
      'instructions_en',
      'storage_policy',
    ];
    for (final req in required) {
      if (!payload.containsKey(req) || payload[req] == null || payload[req].toString().trim().isEmpty) {
        return MobileSuspensionValidationResult.error(
          errorCode: 'ERR_REQUIRED_FIELD_MISSING',
          messageEn: "Missing mandatory field '$req'.",
          messageBn: "বাধ্যতামূলক ফিল্ড '$req' অনুপস্থিত।",
        );
      }
    }

    // 3. Volumes & Dimension Consistency
    final waterVolume = double.tryParse(payload['water_volume_ml'].toString()) ?? 0.0;
    if (waterVolume <= 0.0) {
      return MobileSuspensionValidationResult.error(
        errorCode: 'ERR_INVALID_WATER_VOLUME',
        messageEn: 'water_volume_ml must be greater than 0 mL.',
        messageBn: 'পানির পরিমাণ ০ এর চেয়ে বেশি হতে হবে।',
      );
    }

    final finalVolume = double.tryParse(payload['final_volume_ml'].toString()) ?? 0.0;
    if (finalVolume <= 0.0) {
      return MobileSuspensionValidationResult.error(
        errorCode: 'ERR_INVALID_FINAL_VOLUME',
        messageEn: 'final_volume_ml must be greater than 0 mL.',
        messageBn: 'মোট আয়তন ০ এর চেয়ে বেশি হতে হবে।',
      );
    }

    if (finalVolume < waterVolume) {
      return MobileSuspensionValidationResult.error(
        errorCode: 'ERR_DIMENSION_CONSISTENCY_MISMATCH',
        messageEn: 'Reconstituted final volume ($finalVolume mL) cannot be less than diluent water volume ($waterVolume mL).',
        messageBn: 'প্রস্তুতকৃত মোট আয়তন ($finalVolume মি.লি.) পানির পরিমাণ ($waterVolume মি.লি.) থেকে কম হতে পারে না।',
      );
    }

    // 4. Shelf Life Days
    final shelfLifeDays = int.tryParse(payload['shelf_life_days'].toString()) ?? 0;
    if (shelfLifeDays < 1 || shelfLifeDays > 60) {
      return MobileSuspensionValidationResult.error(
        errorCode: 'ERR_INVALID_SHELF_LIFE',
        messageEn: 'shelf_life_days must be between 1 and 60 days.',
        messageBn: 'স্থায়িত্বকাল ১ থেকে ৬০ দিনের মধ্যে হতে হবে।',
      );
    }

    // 5. Opening Date and BUD Validation
    DateTime? openDate;
    if (payload.containsKey('opening_date') &&
        payload['opening_date'] != null &&
        payload['opening_date'].toString().trim().isNotEmpty) {
      try {
        openDate = DateTime.parse(payload['opening_date'].toString().trim());
      } catch (_) {
        return MobileSuspensionValidationResult.error(
          errorCode: 'ERR_INVALID_OPENING_DATE',
          messageEn: 'opening_date must be in ISO YYYY-MM-DD format.',
          messageBn: 'তারিখ YYYY-MM-DD ফরম্যাটে হতে হবে।',
        );
      }
    }

    if (openDate != null &&
        payload.containsKey('beyond_use_date') &&
        payload['beyond_use_date'] != null &&
        payload['beyond_use_date'].toString().trim().isNotEmpty) {
      DateTime? bud;
      try {
        bud = DateTime.parse(payload['beyond_use_date'].toString().trim());
      } catch (_) {
        return MobileSuspensionValidationResult.error(
          errorCode: 'ERR_INVALID_BEYOND_USE_DATE',
          messageEn: 'beyond_use_date must be in ISO YYYY-MM-DD format.',
          messageBn: 'বিইউডি YYYY-MM-DD ফরম্যাটে হতে হবে।',
        );
      }

      final maxBud = openDate.add(Duration(days: shelfLifeDays));
      if (bud.isBefore(openDate)) {
        return MobileSuspensionValidationResult.error(
          errorCode: 'ERR_INVALID_BEYOND_USE_DATE',
          messageEn: 'Beyond-use date cannot precede opening date.',
          messageBn: 'ব্যবহারের শেষ তারিখ প্রস্তুতের তারিখের পূর্বে হতে পারবে না।',
        );
      }
      if (bud.isAfter(maxBud)) {
        return MobileSuspensionValidationResult.error(
          errorCode: 'ERR_INVALID_BEYOND_USE_DATE',
          messageEn: 'Beyond-use date exceeds maximum shelf life.',
          messageBn: 'ব্যবহারের শেষ তারিখ সর্বোচ্চ স্থায়িত্বকাল অতিক্রম করেছে।',
        );
      }
    }

    // 6. Pharmacist Review Authorization
    final isPharmacistReviewed = payload['is_pharmacist_reviewed'] == true;
    if (isPharmacistReviewed) {
      if (userRole == null || !authorizedRoles.contains(userRole.trim().toUpperCase())) {
        return MobileSuspensionValidationResult.error(
          errorCode: 'ERR_PHARMACIST_REVIEW_REQUIRED',
          messageEn: 'Reconstitution handling guidance approval requires licensed pharmacist or owner credentials.',
          messageBn: 'সাসপেনশন প্রস্তুতকরণ নির্দেশনা অনুমোদনের জন্য রেজিস্টার্ড ফার্মাসিস্ট বা মালিকের অনুমতি আবশ্যক।',
        );
      }
    }

    return MobileSuspensionValidationResult.valid();
  }

  void putCache(String configId, MobileSuspensionReconstitutionConfig config) {
    _localCache[configId] = config;
  }

  MobileSuspensionReconstitutionConfig? getFromCache(String configId) {
    return _localCache[configId];
  }

  List<MobileSuspensionReconstitutionConfig> getAllCached() {
    return _localCache.values.toList();
  }

  void clearCache() {
    _localCache.clear();
  }

  String getLabel(String fieldKey, String lang) {
    final isBn = lang.toLowerCase() == 'bn';
    switch (fieldKey) {
      case 'reconstitution_diluent':
        return isBn ? 'প্রস্তুতকারক পানি / দ্রাবক' : 'Reconstitution Diluent';
      case 'water_volume_ml':
        return isBn ? 'যোগ করার পানির পরিমাণ (মি.লি.)' : 'Diluent Water Volume (mL)';
      case 'final_volume_ml':
        return isBn ? 'প্রস্তুতকৃত মোট আয়তন (মি.লি.)' : 'Final Reconstituted Volume (mL)';
      case 'shelf_life_days':
        return isBn ? 'স্থায়িত্বকাল (দিন)' : 'Reconstituted Shelf Life (Days)';
      case 'beyond_use_date':
        return isBn ? 'ব্যবহারের শেষ তারিখ (বিইউডি)' : 'Beyond-Use Date (BUD)';
      case 'storage_policy':
        return isBn ? 'সংরক্ষণ পদ্ধতি' : 'Storage Policy';
      case 'is_pharmacist_reviewed':
        return isBn ? 'ফার্মাসিস্ট দ্বারা অনুমোদিত' : 'Pharmacist Reviewed & Approved';
      default:
        return fieldKey;
    }
  }
}
