// lib/core/catalog/mobile_syrup_liquid_editor_client.dart
// Architecture Decision: ADR-0142 (P142)
// Phase 08: Syrup Liquid Editor & Oral Liquid Dispensing Units

enum MobileLiquidEditorUiStatus {
  loading,
  success,
  empty,
  error,
  permissionDenied,
  offline,
}

class MobileSyrupLiquidConfig {
  final String configId;
  final String productId;
  final String brandName;
  final String genericName;
  final String? tenantId;
  final String dosageForm;
  final double concentrationValue;
  final String concentrationUnit;
  final double bottleVolumeMl;
  final String saleUnit;
  final String route;
  final String storagePolicy;
  final String measuringDevice;
  final bool isReconstitutionRequired;
  final double? reconstitutionWaterMl;
  final int? shelfLifeDaysAfterReconstitution;
  final String flavor;
  final bool isActive;

  MobileSyrupLiquidConfig({
    required this.configId,
    required this.productId,
    required this.brandName,
    required this.genericName,
    this.tenantId,
    required this.dosageForm,
    required this.concentrationValue,
    required this.concentrationUnit,
    required this.bottleVolumeMl,
    required this.saleUnit,
    required this.route,
    required this.storagePolicy,
    required this.measuringDevice,
    required this.isReconstitutionRequired,
    this.reconstitutionWaterMl,
    this.shelfLifeDaysAfterReconstitution,
    required this.flavor,
    required this.isActive,
  });

  factory MobileSyrupLiquidConfig.fromJson(Map<String, dynamic> json) {
    return MobileSyrupLiquidConfig(
      configId: json['config_id']?.toString() ?? '',
      productId: json['product_id']?.toString() ?? '',
      brandName: json['brand_name']?.toString() ?? '',
      genericName: json['generic_name']?.toString() ?? '',
      tenantId: json['tenant_id']?.toString(),
      dosageForm: json['dosage_form']?.toString() ?? 'SYRUP',
      concentrationValue: (json['concentration_value'] is num)
          ? (json['concentration_value'] as num).toDouble()
          : double.tryParse(json['concentration_value']?.toString() ?? '0.0') ?? 0.0,
      concentrationUnit: json['concentration_unit']?.toString() ?? 'mg/5ml',
      bottleVolumeMl: (json['bottle_volume_ml'] is num)
          ? (json['bottle_volume_ml'] as num).toDouble()
          : double.tryParse(json['bottle_volume_ml']?.toString() ?? '0.0') ?? 100.0,
      saleUnit: json['sale_unit']?.toString() ?? 'Bottle',
      route: json['route']?.toString() ?? 'Oral',
      storagePolicy: json['storage_policy']?.toString() ?? 'ROOM_TEMPERATURE_BELOW_30C',
      measuringDevice: json['measuring_device']?.toString() ?? 'MEASURING_CUP',
      isReconstitutionRequired: json['is_reconstitution_required'] == true,
      reconstitutionWaterMl: (json['reconstitution_water_ml'] is num)
          ? (json['reconstitution_water_ml'] as num).toDouble()
          : double.tryParse(json['reconstitution_water_ml']?.toString() ?? ''),
      shelfLifeDaysAfterReconstitution: (json['shelf_life_days_after_reconstitution'] as num?)?.toInt(),
      flavor: json['flavor']?.toString() ?? '',
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
      'concentration_value': concentrationValue,
      'concentration_unit': concentrationUnit,
      'bottle_volume_ml': bottleVolumeMl,
      'sale_unit': saleUnit,
      'route': route,
      'storage_policy': storagePolicy,
      'measuring_device': measuringDevice,
      'is_reconstitution_required': isReconstitutionRequired,
      'reconstitution_water_ml': reconstitutionWaterMl,
      'shelf_life_days_after_reconstitution': shelfLifeDaysAfterReconstitution,
      'flavor': flavor,
      'is_active': isActive,
    };
  }
}

class MobileSyrupLiquidValidationResult {
  final bool isValid;
  final String? errorCode;
  final String messageEn;
  final String messageBn;

  MobileSyrupLiquidValidationResult({
    required this.isValid,
    this.errorCode,
    required this.messageEn,
    required this.messageBn,
  });

  factory MobileSyrupLiquidValidationResult.valid() {
    return MobileSyrupLiquidValidationResult(
      isValid: true,
      messageEn: 'Validation passed.',
      messageBn: 'যাচাইকরণ সফল হয়েছে।',
    );
  }

  factory MobileSyrupLiquidValidationResult.error({
    required String errorCode,
    required String messageEn,
    required String messageBn,
  }) {
    return MobileSyrupLiquidValidationResult(
      isValid: false,
      errorCode: errorCode,
      messageEn: messageEn,
      messageBn: messageBn,
    );
  }
}

class MobileSyrupLiquidEditorClient {
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

  static const Set<String> allowedUnits = {
    'mg/5ml',
    'mg/ml',
    '%',
    'g/100ml',
    'mcg/5ml',
    'iu/5ml',
    'mg/10ml',
  };

  final Map<String, MobileSyrupLiquidConfig> _localCache = {};
  bool isOfflineMode = false;

  bool isFieldHidden(String fieldName) {
    return hiddenFields.contains(fieldName.toLowerCase().trim());
  }

  bool isStrengthDimensionValid(String unit) {
    return allowedUnits.contains(unit.toLowerCase().trim());
  }

  MobileSyrupLiquidValidationResult validatePayload(Map<String, dynamic> payload) {
    // 1. Zero-Trust Hidden Field Guard (Reject solid oral tablet/strip fields)
    for (final hidden in hiddenFields) {
      if (payload.containsKey(hidden) && payload[hidden] != null) {
        return MobileSyrupLiquidValidationResult.error(
          errorCode: 'ERR_HIDDEN_FIELD_VALUE_REJECTED',
          messageEn: "Field '$hidden' is prohibited for oral liquid and syrup forms.",
          messageBn: "সিরাপ বা তরল ওষুধের জন্য '$hidden' ফিল্ড অনুমোদিত নয়।",
        );
      }
    }

    // 2. Required Fields
    const required = [
      'dosage_form',
      'concentration_value',
      'concentration_unit',
      'bottle_volume_ml',
      'sale_unit',
      'route',
      'storage_policy',
    ];
    for (final req in required) {
      if (!payload.containsKey(req) || payload[req] == null || payload[req].toString().trim().isEmpty) {
        return MobileSyrupLiquidValidationResult.error(
          errorCode: 'ERR_REQUIRED_FIELD_MISSING',
          messageEn: "Missing mandatory field '$req'.",
          messageBn: "বাধ্যতামূলক ফিল্ড '$req' অনুপস্থিত।",
        );
      }
    }

    // 3. Concentration Unit & Dimension Validation
    final unit = payload['concentration_unit'].toString().toLowerCase().trim();
    if (!isStrengthDimensionValid(unit)) {
      return MobileSyrupLiquidValidationResult.error(
        errorCode: 'ERR_INVALID_STRENGTH_DIMENSION_FOR_LIQUID',
        messageEn: "Concentration unit '$unit' lacks liquid volumetric denominator (allowed: mg/5ml, mg/ml, %, etc.).",
        messageBn: "তরল ওষুধের জন্য '$unit' ঘনমাত্রার একক গ্রহণযোগ্য নয় (অনুমোদিত: mg/5ml, mg/ml, % ইত্যাদি)।",
      );
    }

    // 4. Bottle Volume Validation
    final volume = double.tryParse(payload['bottle_volume_ml'].toString()) ?? 0.0;
    if (volume <= 0.0) {
      return MobileSyrupLiquidValidationResult.error(
        errorCode: 'ERR_INVALID_BOTTLE_VOLUME',
        messageEn: 'bottle_volume_ml must be greater than 0.',
        messageBn: 'বোতলের আয়তন অবশ্যই ০-এর বেশি হতে হবে।',
      );
    }

    // 5. Sale Unit Validation
    final saleUnit = payload['sale_unit'].toString().trim();
    if (!const {'Bottle', 'Pack', 'Phial'}.contains(saleUnit)) {
      return MobileSyrupLiquidValidationResult.error(
        errorCode: 'ERR_INVALID_SALE_UNIT_FOR_LIQUID',
        messageEn: "Sale unit '$saleUnit' is invalid for oral liquids.",
        messageBn: "তরল ওষুধের জন্য '$saleUnit' বিক্রয় একক সঠিক নয়।",
      );
    }

    // 6. Oral Route Validation
    final route = payload['route'].toString().trim();
    if (!const {'Oral', 'Oral Gavage', 'Sublingual Drops'}.contains(route)) {
      return MobileSyrupLiquidValidationResult.error(
        errorCode: 'ERR_INVALID_ROUTE_FOR_DOSAGE_FORM',
        messageEn: "Route '$route' is invalid for oral liquid forms.",
        messageBn: "সিরাপ বা তরল ওষুধের জন্য '$route' সেবনের মাধ্যমটি গ্রহণযোগ্য নয়।",
      );
    }

    // 7. Reconstitution Water Volume Validation
    bool isRecon = payload['is_reconstitution_required'] == true || payload['is_reconstitution_required']?.toString().toLowerCase() == 'true';
    final form = payload['dosage_form'].toString().toUpperCase();
    if (form == 'DRY_SYRUP_RECONSTITUTED') {
      isRecon = true;
    }

    if (isRecon) {
      final waterObj = payload['reconstitution_water_ml'];
      if (waterObj == null || waterObj.toString().trim().isEmpty) {
        return MobileSyrupLiquidValidationResult.error(
          errorCode: 'ERR_RECONSTITUTION_WATER_REQUIRED',
          messageEn: 'reconstitution_water_ml is mandatory when reconstitution is required.',
          messageBn: 'ড্রাই সিরাপ বা সাসপেনশনের জন্য মিশ্রণযোগ্য পানির পরিমাণ (মি.লি.) উল্লেখ করা আবশ্যক।',
        );
      }
      final water = double.tryParse(waterObj.toString()) ?? 0.0;
      if (water <= 0.0) {
        return MobileSyrupLiquidValidationResult.error(
          errorCode: 'ERR_RECONSTITUTION_WATER_REQUIRED',
          messageEn: 'reconstitution_water_ml must be greater than 0 mL.',
          messageBn: 'মিশ্রণযোগ্য পানির পরিমাণ অবশ্যই ০ মি.লি.-এর বেশি হতে হবে।',
        );
      }
    }

    return MobileSyrupLiquidValidationResult.valid();
  }

  void cacheConfig(MobileSyrupLiquidConfig config) {
    _localCache[config.productId] = config;
  }

  MobileSyrupLiquidConfig? getCachedConfig(String productId) {
    return _localCache[productId];
  }

  List<MobileSyrupLiquidConfig> getLocalConfigs() {
    return _localCache.values.toList();
  }

  String getLabel(String key, String lang) {
    final isBn = lang.toLowerCase() == 'bn';
    switch (key) {
      case 'concentration_value':
        return isBn ? 'ঘনমাত্রার মান' : 'Concentration Value';
      case 'concentration_unit':
        return isBn ? 'ঘনমাত্রার একক' : 'Concentration Unit';
      case 'bottle_volume_ml':
        return isBn ? 'বোতলের আয়তন (মি.লি.)' : 'Bottle Volume (mL)';
      case 'sale_unit':
        return isBn ? 'বিক্রয় একক' : 'Sale Unit';
      case 'route':
        return isBn ? 'সেবনের মাধ্যম' : 'Route';
      case 'storage_policy':
        return isBn ? 'সংরক্ষণ নীতি' : 'Storage Policy';
      case 'reconstitution_water_ml':
        return isBn ? 'মিশ্রণযোগ্য পানির পরিমাণ (মি.লি.)' : 'Reconstitution Water (mL)';
      default:
        return key;
    }
  }
}
