// lib/core/catalog/mobile_insulin_editor_client.dart
// Architecture Decision: ADR-0145 (P145)
// Phase 08: Specialized Dosage-Form Editors & Multi-Tier Packaging

enum MobileInsulinUiStatus {
  loading,
  success,
  empty,
  error,
  permissionDenied,
  offline,
}

class MobileInsulinConfig {
  final String configId;
  final String productId;
  final String brandName;
  final String genericName;
  final String? tenantId;
  final String actionCategory;
  final String deliveryDevice;
  final int concentrationIuPerMl;
  final double volumeMl;
  final int totalUnits;
  final int inUseShelfLifeDays;
  final double unopenedMinTempCelsius;
  final double unopenedMaxTempCelsius;
  final double inUseMaxTempCelsius;
  final String excursionAction;
  final String patientCounselingEn;
  final String patientCounselingBn;
  final bool isActive;

  MobileInsulinConfig({
    required this.configId,
    required this.productId,
    required this.brandName,
    required this.genericName,
    this.tenantId,
    required this.actionCategory,
    required this.deliveryDevice,
    required this.concentrationIuPerMl,
    required this.volumeMl,
    required this.totalUnits,
    required this.inUseShelfLifeDays,
    required this.unopenedMinTempCelsius,
    required this.unopenedMaxTempCelsius,
    required this.inUseMaxTempCelsius,
    required this.excursionAction,
    required this.patientCounselingEn,
    required this.patientCounselingBn,
    required this.isActive,
  });

  factory MobileInsulinConfig.fromJson(Map<String, dynamic> json) {
    return MobileInsulinConfig(
      configId: json['config_id']?.toString() ?? '',
      productId: json['product_id']?.toString() ?? '',
      brandName: json['brand_name']?.toString() ?? '',
      genericName: json['generic_name']?.toString() ?? '',
      tenantId: json['tenant_id']?.toString(),
      actionCategory: json['action_category']?.toString() ?? 'INTERMEDIATE_NPH',
      deliveryDevice: json['delivery_device']?.toString() ?? 'PEN_DISPOSABLE',
      concentrationIuPerMl: (json['concentration_iu_per_ml'] as num?)?.toInt() ?? 100,
      volumeMl: (json['volume_ml'] is num)
          ? (json['volume_ml'] as num).toDouble()
          : double.tryParse(json['volume_ml']?.toString() ?? '3.0') ?? 3.0,
      totalUnits: (json['total_units'] as num?)?.toInt() ?? 300,
      inUseShelfLifeDays: (json['in_use_shelf_life_days'] as num?)?.toInt() ?? 28,
      unopenedMinTempCelsius: (json['unopened_min_temp_celsius'] is num)
          ? (json['unopened_min_temp_celsius'] as num).toDouble()
          : double.tryParse(json['unopened_min_temp_celsius']?.toString() ?? '2.0') ?? 2.0,
      unopenedMaxTempCelsius: (json['unopened_max_temp_celsius'] is num)
          ? (json['unopened_max_temp_celsius'] as num).toDouble()
          : double.tryParse(json['unopened_max_temp_celsius']?.toString() ?? '8.0') ?? 8.0,
      inUseMaxTempCelsius: (json['in_use_max_temp_celsius'] is num)
          ? (json['in_use_max_temp_celsius'] as num).toDouble()
          : double.tryParse(json['in_use_max_temp_celsius']?.toString() ?? '30.0') ?? 30.0,
      excursionAction: json['excursion_action']?.toString() ?? 'QUARANTINE_FOR_PHARMACIST_ASSESSMENT',
      patientCounselingEn: json['patient_counseling_en']?.toString() ?? '',
      patientCounselingBn: json['patient_counseling_bn']?.toString() ?? '',
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
      'action_category': actionCategory,
      'delivery_device': deliveryDevice,
      'concentration_iu_per_ml': concentrationIuPerMl,
      'volume_ml': volumeMl,
      'total_units': totalUnits,
      'in_use_shelf_life_days': inUseShelfLifeDays,
      'unopened_min_temp_celsius': unopenedMinTempCelsius,
      'unopened_max_temp_celsius': unopenedMaxTempCelsius,
      'in_use_max_temp_celsius': inUseMaxTempCelsius,
      'excursion_action': excursionAction,
      'patient_counseling_en': patientCounselingEn,
      'patient_counseling_bn': patientCounselingBn,
      'is_active': isActive,
    };
  }
}

class MobileInsulinValidationResult {
  final bool isValid;
  final String? errorCode;
  final String messageEn;
  final String messageBn;

  MobileInsulinValidationResult({
    required this.isValid,
    this.errorCode,
    required this.messageEn,
    required this.messageBn,
  });

  factory MobileInsulinValidationResult.valid() {
    return MobileInsulinValidationResult(
      isValid: true,
      messageEn: 'Validation passed.',
      messageBn: 'যাচাইকরণ সফল হয়েছে।',
    );
  }

  factory MobileInsulinValidationResult.error({
    required String errorCode,
    required String messageEn,
    required String messageBn,
  }) {
    return MobileInsulinValidationResult(
      isValid: false,
      errorCode: errorCode,
      messageEn: messageEn,
      messageBn: messageBn,
    );
  }
}

class MobileInsulinEditorClient {
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

  static const Set<int> allowedConcentrations = {100, 200, 300, 500};

  static const Set<String> allowedDeliveryDevices = {
    'PEN_DISPOSABLE',
    'CARTRIDGE_REFILL',
    'VIAL_MULTI_DOSE',
    'PUMP_RESERVOIR',
  };

  static const Set<String> allowedActionCategories = {
    'RAPID_ACTING',
    'SHORT_ACTING_REGULAR',
    'INTERMEDIATE_NPH',
    'LONG_ACTING_ANALOG',
    'PREMIXED_BIPHASIC',
  };

  final Map<String, MobileInsulinConfig> _localCache = {};
  bool isOfflineMode = false;

  bool isFieldHidden(String fieldName) {
    return hiddenFields.contains(fieldName.toLowerCase().trim());
  }

  int calculateTotalUnits(int concentrationIuPerMl, double volumeMl) {
    return (concentrationIuPerMl * volumeMl).round();
  }

  MobileInsulinValidationResult validatePayload(Map<String, dynamic> payload) {
    // 1. Zero-Trust Hidden Field Guard (Reject solid oral tablet/strip fields)
    for (final hidden in hiddenFields) {
      if (payload.containsKey(hidden) && payload[hidden] != null) {
        return MobileInsulinValidationResult.error(
          errorCode: 'ERR_HIDDEN_FIELD_VALUE_REJECTED',
          messageEn: "Field '$hidden' is prohibited for insulin preparations.",
          messageBn: "ইনসুলিনের জন্য '$hidden' ফিল্ড অনুমোদিত নয়।",
        );
      }
    }

    // 2. Required Fields
    const required = [
      'action_category',
      'delivery_device',
      'concentration_iu_per_ml',
      'volume_ml',
      'total_units',
      'in_use_shelf_life_days',
      'excursion_action',
    ];
    for (final req in required) {
      if (!payload.containsKey(req) || payload[req] == null || payload[req].toString().trim().isEmpty) {
        return MobileInsulinValidationResult.error(
          errorCode: 'ERR_REQUIRED_FIELD_MISSING',
          messageEn: "Missing mandatory field '$req'.",
          messageBn: "বাধ্যতামূলক ফিল্ড '$req' অনুপস্থিত।",
        );
      }
    }

    // 3. Action Category Validation
    final action = payload['action_category'].toString().trim().toUpperCase();
    if (!allowedActionCategories.contains(action)) {
      return MobileInsulinValidationResult.error(
        errorCode: 'ERR_INVALID_ACTION_CATEGORY',
        messageEn: "Action category '$action' is invalid.",
        messageBn: "ইনসুলিনের ধরন '$action' অগ্রহণযোগ্য।",
      );
    }

    // 4. Delivery Device Validation
    final device = payload['delivery_device'].toString().trim().toUpperCase();
    if (!allowedDeliveryDevices.contains(device)) {
      return MobileInsulinValidationResult.error(
        errorCode: 'ERR_INVALID_DELIVERY_DEVICE',
        messageEn: "Delivery device '$device' is invalid.",
        messageBn: "ডেলিভারি প্রেজেন্টেশন '$device' অগ্রহণযোগ্য।",
      );
    }

    // 5. Concentration Validation
    final concentration = int.tryParse(payload['concentration_iu_per_ml'].toString()) ?? 0;
    if (!allowedConcentrations.contains(concentration)) {
      return MobileInsulinValidationResult.error(
        errorCode: 'ERR_INVALID_INSULIN_CONCENTRATION',
        messageEn: 'Concentration $concentration IU/mL is invalid. Standard strengths: $allowedConcentrations.',
        messageBn: 'ইনসুলিনের ঘনমাত্রা $concentration আইইউ/মি.লি. অগ্রহণযোগ্য।',
      );
    }

    // 6. Volume Validation
    final volume = double.tryParse(payload['volume_ml'].toString()) ?? 0.0;
    if (volume <= 0.0) {
      return MobileInsulinValidationResult.error(
        errorCode: 'ERR_INVALID_VOLUME',
        messageEn: 'volume_ml must be greater than 0 mL.',
        messageBn: 'ভলিউম ০ এর চেয়ে বেশি হতে হবে।',
      );
    }

    // 7. Total Units & Mathematical Dimension Consistency
    final totalUnits = int.tryParse(payload['total_units'].toString()) ?? 0;
    if (totalUnits <= 0) {
      return MobileInsulinValidationResult.error(
        errorCode: 'ERR_DIMENSION_CONSISTENCY_MISMATCH',
        messageEn: 'total_units must be greater than 0.',
        messageBn: 'মোট ইউনিট ০ এর চেয়ে বেশি হতে হবে।',
      );
    }

    final expectedUnits = calculateTotalUnits(concentration, volume);
    if (totalUnits != expectedUnits) {
      return MobileInsulinValidationResult.error(
        errorCode: 'ERR_DIMENSION_CONSISTENCY_MISMATCH',
        messageEn: 'Dimension consistency mismatch: total_units ($totalUnits IU) does not equal concentration ($concentration IU/mL) * volume ($volume mL) = $expectedUnits IU.',
        messageBn: 'ডাইমেনশন অমিল: মোট ইউনিট ($totalUnits) অবশ্যই ঘনমাত্রা ($concentration) × ভলিউম ($volume) = $expectedUnits ইউনিটের সমান হতে হবে।',
      );
    }

    // 8. In-Use Shelf Life Days (14 - 56 days)
    final shelfLife = int.tryParse(payload['in_use_shelf_life_days'].toString()) ?? 0;
    if (shelfLife < 14 || shelfLife > 56) {
      return MobileInsulinValidationResult.error(
        errorCode: 'ERR_INVALID_IN_USE_SHELF_LIFE',
        messageEn: 'in_use_shelf_life_days must be between 14 and 56 days.',
        messageBn: 'ব্যবহারকালীন রুম টেম্পারেচার মেয়াদ ১৪ থেকে ৫৬ দিনের মধ্যে হতে হবে।',
      );
    }

    return MobileInsulinValidationResult.valid();
  }

  void putCache(String configId, MobileInsulinConfig config) {
    _localCache[configId] = config;
  }

  MobileInsulinConfig? getFromCache(String configId) {
    return _localCache[configId];
  }

  List<MobileInsulinConfig> getAllCached() {
    return _localCache.values.toList();
  }

  void clearCache() {
    _localCache.clear();
  }

  String getLabel(String fieldKey, String lang) {
    final isBn = lang.toLowerCase() == 'bn';
    switch (fieldKey) {
      case 'action_category':
        return isBn ? 'কার্যকারিতার ধরন' : 'Action Profile';
      case 'delivery_device':
        return isBn ? 'ডেলিভারি প্রেজেন্টেশন' : 'Delivery Presentation';
      case 'concentration_iu_per_ml':
        return isBn ? 'ঘনমাত্রা (আইইউ/মি.লি.)' : 'Concentration (IU/mL)';
      case 'volume_ml':
        return isBn ? 'কনটেইনারের আয়তন (মি.লি.)' : 'Container Volume (mL)';
      case 'total_units':
        return isBn ? 'মোট সক্রিয় ইউনিট (আইইউ)' : 'Total Units (IU)';
      case 'in_use_shelf_life_days':
        return isBn ? 'ব্যবহারকালীন মেয়াদ (দিন)' : 'In-Use Shelf Life (Days)';
      case 'excursion_action':
        return isBn ? 'তাপমাত্রা বিচ্যুতিতে করণীয়' : 'Excursion Protocol';
      default:
        return fieldKey;
    }
  }
}
