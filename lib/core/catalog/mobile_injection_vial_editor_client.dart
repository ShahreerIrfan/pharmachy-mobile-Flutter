// lib/core/catalog/mobile_injection_vial_editor_client.dart
// Architecture Decision: ADR-0144 (P144)
// Phase 08: Specialized Dosage-Form Editors & Multi-Tier Packaging

enum MobileInjectionUiStatus {
  loading,
  success,
  empty,
  error,
  permissionDenied,
  offline,
}

class MobileInjectionVialConfig {
  final String configId;
  final String productId;
  final String brandName;
  final String genericName;
  final String? tenantId;
  final String dosageForm;
  final String containerType;
  final double strengthValue;
  final String strengthUnit;
  final double fillVolumeMl;
  final String sterileRoute;
  final bool isColdChainRequired;
  final double? minStorageTempCelsius;
  final double? maxStorageTempCelsius;
  final bool hasPreservative;
  final bool requiresDiluent;
  final String diluentType;
  final double? diluentVolumeMl;
  final bool isActive;

  MobileInjectionVialConfig({
    required this.configId,
    required this.productId,
    required this.brandName,
    required this.genericName,
    this.tenantId,
    required this.dosageForm,
    required this.containerType,
    required this.strengthValue,
    required this.strengthUnit,
    required this.fillVolumeMl,
    required this.sterileRoute,
    required this.isColdChainRequired,
    this.minStorageTempCelsius,
    this.maxStorageTempCelsius,
    required this.hasPreservative,
    required this.requiresDiluent,
    required this.diluentType,
    this.diluentVolumeMl,
    required this.isActive,
  });

  factory MobileInjectionVialConfig.fromJson(Map<String, dynamic> json) {
    return MobileInjectionVialConfig(
      configId: json['config_id']?.toString() ?? '',
      productId: json['product_id']?.toString() ?? '',
      brandName: json['brand_name']?.toString() ?? '',
      genericName: json['generic_name']?.toString() ?? '',
      tenantId: json['tenant_id']?.toString(),
      dosageForm: json['dosage_form']?.toString() ?? 'INJECTION_SOLUTION',
      containerType: json['container_type']?.toString() ?? 'VIAL_SINGLE_DOSE',
      strengthValue: (json['strength_value'] is num)
          ? (json['strength_value'] as num).toDouble()
          : double.tryParse(json['strength_value']?.toString() ?? '0.0') ?? 0.0,
      strengthUnit: json['strength_unit']?.toString() ?? 'mg/ml',
      fillVolumeMl: (json['fill_volume_ml'] is num)
          ? (json['fill_volume_ml'] as num).toDouble()
          : double.tryParse(json['fill_volume_ml']?.toString() ?? '0.0') ?? 1.0,
      sterileRoute: json['sterile_route']?.toString() ?? 'IV',
      isColdChainRequired: json['is_cold_chain_required'] == true,
      minStorageTempCelsius: (json['min_storage_temp_celsius'] is num)
          ? (json['min_storage_temp_celsius'] as num).toDouble()
          : double.tryParse(json['min_storage_temp_celsius']?.toString() ?? ''),
      maxStorageTempCelsius: (json['max_storage_temp_celsius'] is num)
          ? (json['max_storage_temp_celsius'] as num).toDouble()
          : double.tryParse(json['max_storage_temp_celsius']?.toString() ?? ''),
      hasPreservative: json['has_preservative'] == true,
      requiresDiluent: json['requires_diluent'] == true,
      diluentType: json['diluent_type']?.toString() ?? 'NONE',
      diluentVolumeMl: (json['diluent_volume_ml'] is num)
          ? (json['diluent_volume_ml'] as num).toDouble()
          : double.tryParse(json['diluent_volume_ml']?.toString() ?? ''),
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
      'container_type': containerType,
      'strength_value': strengthValue,
      'strength_unit': strengthUnit,
      'fill_volume_ml': fillVolumeMl,
      'sterile_route': sterileRoute,
      'is_cold_chain_required': isColdChainRequired,
      'min_storage_temp_celsius': minStorageTempCelsius,
      'max_storage_temp_celsius': maxStorageTempCelsius,
      'has_preservative': hasPreservative,
      'requires_diluent': requiresDiluent,
      'diluent_type': diluentType,
      'diluent_volume_ml': diluentVolumeMl,
      'is_active': isActive,
    };
  }
}

class MobileInjectionValidationResult {
  final bool isValid;
  final String? errorCode;
  final String messageEn;
  final String messageBn;

  MobileInjectionValidationResult({
    required this.isValid,
    this.errorCode,
    required this.messageEn,
    required this.messageBn,
  });

  factory MobileInjectionValidationResult.valid() {
    return MobileInjectionValidationResult(
      isValid: true,
      messageEn: 'Validation passed.',
      messageBn: 'যাচাইকরণ সফল হয়েছে।',
    );
  }

  factory MobileInjectionValidationResult.error({
    required String errorCode,
    required String messageEn,
    required String messageBn,
  }) {
    return MobileInjectionValidationResult(
      isValid: false,
      errorCode: errorCode,
      messageEn: messageEn,
      messageBn: messageBn,
    );
  }
}

class MobileInjectionVialEditorClient {
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

  static const Set<String> allowedRoutes = {
    'IV',
    'IM',
    'SC',
    'ID',
    'INTRAVITREAL',
    'EPIDURAL',
  };

  static const Set<String> allowedStrengthUnits = {
    'mg/ml',
    'mcg/ml',
    'g/ml',
    'iu/ml',
    'mg/vial',
    'g/vial',
    '%',
  };

  final Map<String, MobileInjectionVialConfig> _localCache = {};
  bool isOfflineMode = false;

  bool isFieldHidden(String fieldName) {
    return hiddenFields.contains(fieldName.toLowerCase().trim());
  }

  MobileInjectionValidationResult validatePayload(Map<String, dynamic> payload) {
    // 1. Zero-Trust Hidden Field Guard (Reject solid oral tablet/strip fields)
    for (final hidden in hiddenFields) {
      if (payload.containsKey(hidden) && payload[hidden] != null) {
        return MobileInjectionValidationResult.error(
          errorCode: 'ERR_HIDDEN_FIELD_VALUE_REJECTED',
          messageEn: "Field '$hidden' is prohibited for injection vial forms.",
          messageBn: "ইনজেকশন ওষুধের জন্য '$hidden' ফিল্ড অনুমোদিত নয়।",
        );
      }
    }

    // 2. Required Fields
    const required = [
      'dosage_form',
      'container_type',
      'strength_value',
      'strength_unit',
      'fill_volume_ml',
      'sterile_route',
    ];
    for (final req in required) {
      if (!payload.containsKey(req) || payload[req] == null || payload[req].toString().trim().isEmpty) {
        return MobileInjectionValidationResult.error(
          errorCode: 'ERR_REQUIRED_FIELD_MISSING',
          messageEn: "Missing mandatory field '$req'.",
          messageBn: "বাধ্যতামূলক ফিল্ড '$req' অনুপস্থিত।",
        );
      }
    }

    // 3. Sterile Route Validation
    final route = payload['sterile_route'].toString().trim().toUpperCase();
    if (!allowedRoutes.contains(route)) {
      return MobileInjectionValidationResult.error(
        errorCode: 'ERR_INVALID_STERILE_ROUTE',
        messageEn: "Route '$route' is invalid for injectables. Oral routes are prohibited.",
        messageBn: "ইনজেকশনের জন্য রুট '$route' গ্রহণযোগ্য নয়। ওরাল রুট নিষিদ্ধ।",
      );
    }

    // 4. Strength Unit Validation
    final unit = payload['strength_unit'].toString().trim().toLowerCase();
    if (!allowedStrengthUnits.contains(unit)) {
      return MobileInjectionValidationResult.error(
        errorCode: 'ERR_INVALID_STRENGTH_UNIT',
        messageEn: "Strength unit '$unit' is invalid for injectables.",
        messageBn: "ইনজেকশনের জন্য মাত্রার একক '$unit' গ্রহণযোগ্য নয়।",
      );
    }

    // 5. Strength Value & Fill Volume
    final strengthVal = double.tryParse(payload['strength_value'].toString()) ?? 0.0;
    if (strengthVal <= 0.0) {
      return MobileInjectionValidationResult.error(
        errorCode: 'ERR_INVALID_STRENGTH_VALUE',
        messageEn: 'strength_value must be greater than 0.',
        messageBn: 'উপাদানের মাত্রা ০ এর চেয়ে বেশি হতে হবে।',
      );
    }

    final fillVol = double.tryParse(payload['fill_volume_ml'].toString()) ?? 0.0;
    if (fillVol <= 0.0) {
      return MobileInjectionValidationResult.error(
        errorCode: 'ERR_INVALID_FILL_VOLUME',
        messageEn: 'fill_volume_ml must be greater than 0 mL.',
        messageBn: 'ফিল ভলিউম ০ এর চেয়ে বেশি হতে হবে।',
      );
    }

    // 6. Cold Chain Validation
    final isColdChain = payload['is_cold_chain_required'] == true;
    if (isColdChain) {
      final rawMin = payload['min_storage_temp_celsius'];
      final rawMax = payload['max_storage_temp_celsius'];
      if (rawMin == null || rawMin.toString().trim().isEmpty || rawMax == null || rawMax.toString().trim().isEmpty) {
        return MobileInjectionValidationResult.error(
          errorCode: 'ERR_INVALID_TEMPERATURE_RANGE',
          messageEn: 'Both min and max storage temperatures are required when cold chain is active.',
          messageBn: 'কোল্ড চেইনের ক্ষেত্রে সর্বনিম্ন ও সর্বোচ্চ তাপমাত্রা আবশ্যক।',
        );
      }
      final minTemp = double.tryParse(rawMin.toString()) ?? 0.0;
      final maxTemp = double.tryParse(rawMax.toString()) ?? 0.0;
      if (minTemp >= maxTemp) {
        return MobileInjectionValidationResult.error(
          errorCode: 'ERR_INVALID_TEMPERATURE_RANGE',
          messageEn: 'min_storage_temp_celsius ($minTemp°C) must be strictly less than max_storage_temp_celsius ($maxTemp°C).',
          messageBn: 'সর্বনিম্ন তাপমাত্রা ($minTemp°সে) সর্বোচ্চ তাপমাত্রা ($maxTemp°সে) থেকে কম হতে হবে।',
        );
      }
    }

    // 7. Single-Dose Ampoule Preservative Prohibition
    final containerType = payload['container_type'].toString().trim().toUpperCase();
    final hasPreservative = payload['has_preservative'] == true;
    if (containerType == 'AMPOULE_GLASS' && hasPreservative) {
      return MobileInjectionValidationResult.error(
        errorCode: 'ERR_SINGLE_DOSE_PRESERVATIVE_PROHIBITED',
        messageEn: 'Single-dose glass ampoules cannot contain antimicrobial preservatives.',
        messageBn: 'একক-ডোজ কাঁচের অ্যাম্পুলে প্রিজারভেটিভ ব্যবহার নিষিদ্ধ।',
      );
    }

    // 8. Lyophilized Diluent Requirements
    final dosageForm = payload['dosage_form'].toString().trim().toUpperCase();
    var requiresDiluent = payload['requires_diluent'] == true;
    if (dosageForm == 'INJECTION_POWDER_LYOPHILIZED') {
      requiresDiluent = true;
    }

    if (requiresDiluent) {
      final rawDilVol = payload['diluent_volume_ml'];
      if (rawDilVol == null || rawDilVol.toString().trim().isEmpty) {
        return MobileInjectionValidationResult.error(
          errorCode: 'ERR_DILUENT_REQUIRED',
          messageEn: 'diluent_volume_ml is required for lyophilized powder injections.',
          messageBn: 'পাউডার ইনজেকশনের জন্য ডিলুয়েন্টের পরিমাণ আবশ্যক।',
        );
      }
      final dilVol = double.tryParse(rawDilVol.toString()) ?? 0.0;
      if (dilVol <= 0.0) {
        return MobileInjectionValidationResult.error(
          errorCode: 'ERR_DILUENT_REQUIRED',
          messageEn: 'diluent_volume_ml must be greater than 0 mL.',
          messageBn: 'ডিলুয়েন্টের পরিমাণ ০ এর চেয়ে বেশি হতে হবে।',
        );
      }

      final dilType = payload['diluent_type']?.toString().trim().toUpperCase() ?? 'NONE';
      if (dilType == 'NONE' || dilType.isEmpty) {
        return MobileInjectionValidationResult.error(
          errorCode: 'ERR_DILUENT_REQUIRED',
          messageEn: 'A valid diluent_type is required for lyophilized powder injections.',
          messageBn: 'পাউডার ইনজেকশনের জন্য সঠিক ডিলুয়েন্টের ধরন আবশ্যক।',
        );
      }
    }

    return MobileInjectionValidationResult.valid();
  }

  void putCache(String configId, MobileInjectionVialConfig config) {
    _localCache[configId] = config;
  }

  MobileInjectionVialConfig? getFromCache(String configId) {
    return _localCache[configId];
  }

  List<MobileInjectionVialConfig> getAllCached() {
    return _localCache.values.toList();
  }

  void clearCache() {
    _localCache.clear();
  }

  String getLabel(String fieldKey, String lang) {
    final isBn = lang.toLowerCase() == 'bn';
    switch (fieldKey) {
      case 'container_type':
        return isBn ? 'কনটেইনারের ধরন' : 'Container Type';
      case 'fill_volume_ml':
        return isBn ? 'ফিল ভলিউম (মি.লি.)' : 'Fill Volume (mL)';
      case 'sterile_route':
        return isBn ? 'প্রয়োগের স্টেরাইল রুট' : 'Sterile Route';
      case 'is_cold_chain_required':
        return isBn ? 'কোল্ড চেইন আবশ্যক' : 'Cold-Chain Required';
      case 'min_storage_temp_celsius':
        return isBn ? 'সর্বনিম্ন তাপমাত্রা (°সে)' : 'Min Storage Temp (°C)';
      case 'max_storage_temp_celsius':
        return isBn ? 'সর্বোচ্চ তাপমাত্রা (°সে)' : 'Max Storage Temp (°C)';
      case 'has_preservative':
        return isBn ? 'প্রিজারভেটিভ সংযুক্ত' : 'Contains Preservative';
      case 'diluent_type':
        return isBn ? 'ডিলুয়েন্টের ধরন' : 'Diluent Type';
      default:
        return fieldKey;
    }
  }
}
