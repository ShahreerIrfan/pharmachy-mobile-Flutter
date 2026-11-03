// lib/core/catalog/mobile_tablet_capsule_editor_client.dart
// Architecture Decision: ADR-0141 (P141)
// Phase 08: Tablet/Capsule Editor & Packaging Hierarchy Multipliers

enum MobileTabletEditorUiStatus {
  loading,
  success,
  empty,
  error,
  permissionDenied,
  offline,
}

class MobileTabletCapsuleConfig {
  final String configId;
  final String productId;
  final String brandName;
  final String genericName;
  final String? tenantId;
  final String dosageForm;
  final double doseStrength;
  final String strengthUnit;
  final int tabletsPerStrip;
  final int stripsPerBox;
  final int boxSize;
  final bool looseSaleEligible;
  final String route;
  final String storagePolicy;
  final bool isScored;
  final String coatingType;
  final bool isActive;

  MobileTabletCapsuleConfig({
    required this.configId,
    required this.productId,
    required this.brandName,
    required this.genericName,
    this.tenantId,
    required this.dosageForm,
    required this.doseStrength,
    required this.strengthUnit,
    required this.tabletsPerStrip,
    required this.stripsPerBox,
    required this.boxSize,
    required this.looseSaleEligible,
    required this.route,
    required this.storagePolicy,
    required this.isScored,
    required this.coatingType,
    required this.isActive,
  });

  factory MobileTabletCapsuleConfig.fromJson(Map<String, dynamic> json) {
    return MobileTabletCapsuleConfig(
      configId: json['config_id']?.toString() ?? '',
      productId: json['product_id']?.toString() ?? '',
      brandName: json['brand_name']?.toString() ?? '',
      genericName: json['generic_name']?.toString() ?? '',
      tenantId: json['tenant_id']?.toString(),
      dosageForm: json['dosage_form']?.toString() ?? 'TABLET',
      doseStrength: (json['dose_strength'] is num)
          ? (json['dose_strength'] as num).toDouble()
          : double.tryParse(json['dose_strength']?.toString() ?? '0.0') ?? 0.0,
      strengthUnit: json['strength_unit']?.toString() ?? 'mg',
      tabletsPerStrip: (json['tablets_per_strip'] as num?)?.toInt() ?? 10,
      stripsPerBox: (json['strips_per_box'] as num?)?.toInt() ?? 10,
      boxSize: (json['box_size'] as num?)?.toInt() ?? 100,
      looseSaleEligible: json['loose_sale_eligible'] == true,
      route: json['route']?.toString() ?? 'Oral',
      storagePolicy: json['storage_policy']?.toString() ?? 'ROOM_TEMPERATURE_DRY',
      isScored: json['is_scored'] == true,
      coatingType: json['coating_type']?.toString() ?? 'FILM_COATED',
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
      'dose_strength': doseStrength,
      'strength_unit': strengthUnit,
      'tablets_per_strip': tabletsPerStrip,
      'strips_per_box': stripsPerBox,
      'box_size': boxSize,
      'loose_sale_eligible': looseSaleEligible,
      'route': route,
      'storage_policy': storagePolicy,
      'is_scored': isScored,
      'coating_type': coatingType,
      'is_active': isActive,
    };
  }
}

class MobileTabletCapsuleValidationResult {
  final bool isValid;
  final String? errorCode;
  final String messageEn;
  final String messageBn;
  final int computedBoxSize;

  MobileTabletCapsuleValidationResult({
    required this.isValid,
    this.errorCode,
    required this.messageEn,
    required this.messageBn,
    required this.computedBoxSize,
  });

  factory MobileTabletCapsuleValidationResult.valid(int computedBoxSize) {
    return MobileTabletCapsuleValidationResult(
      isValid: true,
      messageEn: 'Validation passed.',
      messageBn: 'যাচাইকরণ সফল হয়েছে।',
      computedBoxSize: computedBoxSize,
    );
  }

  factory MobileTabletCapsuleValidationResult.error({
    required String errorCode,
    required String messageEn,
    required String messageBn,
  }) {
    return MobileTabletCapsuleValidationResult(
      isValid: false,
      errorCode: errorCode,
      messageEn: messageEn,
      messageBn: messageBn,
      computedBoxSize: 0,
    );
  }
}

class MobileTabletCapsuleEditorClient {
  static const Set<String> hiddenFields = {
    'volume_ml',
    'concentration',
    'reconstitution_water_ml',
    'dropper_volume_ml',
    'needle_gauge',
    'is_reconstitution_required',
  };

  final Map<String, MobileTabletCapsuleConfig> _localCache = {};
  bool isOfflineMode = false;

  int calculateBoxSize(int tabletsPerStrip, int stripsPerBox) {
    if (tabletsPerStrip < 1 || stripsPerBox < 1) return 0;
    return tabletsPerStrip * stripsPerBox;
  }

  bool isLooseSalePermitted(String dosageForm, String storagePolicy) {
    if (dosageForm.toUpperCase() == 'EFFERVESCENT_TABLET') {
      return false;
    }
    if (storagePolicy.toUpperCase() == 'PROTECT_FROM_MOISTURE_LIGHT' &&
        dosageForm.toUpperCase() == 'EFFERVESCENT_TABLET') {
      return false;
    }
    return true;
  }

  bool isFieldHidden(String fieldName) {
    return hiddenFields.contains(fieldName.toLowerCase().trim());
  }

  MobileTabletCapsuleValidationResult validatePayload(Map<String, dynamic> payload) {
    // 1. Zero-Trust Hidden Field Guard
    for (final hidden in hiddenFields) {
      if (payload.containsKey(hidden) && payload[hidden] != null) {
        return MobileTabletCapsuleValidationResult.error(
          errorCode: 'ERR_HIDDEN_FIELD_VALUE_REJECTED',
          messageEn: "Field '$hidden' is prohibited for solid tablet/capsule forms.",
          messageBn: "কঠিন ট্যাবলেট বা ক্যাপসুলের জন্য '$hidden' ফিল্ড অনুমোদিত নয়।",
        );
      }
    }

    // 2. Required Fields
    const required = [
      'dosage_form',
      'dose_strength',
      'strength_unit',
      'tablets_per_strip',
      'strips_per_box',
      'route',
      'storage_policy',
    ];
    for (final req in required) {
      if (!payload.containsKey(req) || payload[req] == null || payload[req].toString().trim().isEmpty) {
        return MobileTabletCapsuleValidationResult.error(
          errorCode: 'ERR_REQUIRED_FIELD_MISSING',
          messageEn: "Missing mandatory field '$req'.",
          messageBn: "বাধ্যতামূলক ফিল্ড '$req' অনুপস্থিত।",
        );
      }
    }

    // 3. Packaging Multipliers & Dimension Consistency
    final tablets = int.tryParse(payload['tablets_per_strip'].toString()) ?? 0;
    final strips = int.tryParse(payload['strips_per_box'].toString()) ?? 0;
    if (tablets < 1 || strips < 1) {
      return MobileTabletCapsuleValidationResult.error(
        errorCode: 'ERR_INVALID_PACKAGING_MULTIPLIER',
        messageEn: 'Packaging multipliers must be integers >= 1.',
        messageBn: 'প্যাকেজিং গুণক অবশ্যই ১ বা তার বেশি পূর্ণসংখ্যা হতে হবে।',
      );
    }

    final expectedBoxSize = tablets * strips;
    if (payload.containsKey('box_size') && payload['box_size'] != null) {
      final providedBoxSize = int.tryParse(payload['box_size'].toString()) ?? 0;
      if (providedBoxSize != expectedBoxSize) {
        return MobileTabletCapsuleValidationResult.error(
          errorCode: 'ERR_DIMENSION_CONSISTENCY_MISMATCH',
          messageEn: 'Dimension mismatch: box_size ($providedBoxSize) must equal strips_per_box * tablets_per_strip ($expectedBoxSize).',
          messageBn: 'মাত্রা অসঙ্গতি: বক্স সাইজ ($providedBoxSize) অবশ্যই স্ট্রিপ x ট্যাবলেট ($expectedBoxSize) এর সমান হতে হবে।',
        );
      }
    }

    // 4. Loose-sale business rule
    final form = payload['dosage_form'].toString().toUpperCase();
    final looseSale = payload['loose_sale_eligible'] == true || payload['loose_sale_eligible']?.toString().toLowerCase() == 'true';
    if (form == 'EFFERVESCENT_TABLET' && looseSale) {
      return MobileTabletCapsuleValidationResult.error(
        errorCode: 'ERR_LOOSE_SALE_NOT_PERMITTED',
        messageEn: 'Loose sale is not permitted for effervescent tablets due to moisture degradation.',
        messageBn: 'আর্দ্রতাজনিত ক্ষতির কারণে এফারভেসেন্ট ট্যাবলেট খুচরা বিক্রি নিষিদ্ধ।',
      );
    }

    // 5. Solid Strength Unit
    final unit = payload['strength_unit'].toString().toLowerCase().trim();
    if (!const {'mg', 'mcg', 'g'}.contains(unit)) {
      return MobileTabletCapsuleValidationResult.error(
        errorCode: 'ERR_INVALID_STRENGTH_UNIT_FOR_SOLID_FORM',
        messageEn: "Strength unit '$unit' is invalid for solid forms (allowed: mg, mcg, g).",
        messageBn: "কঠিন ওষুধের জন্য '$unit' মাত্রা একক গ্রহণযোগ্য নয় (অনুমোদিত: mg, mcg, g)।",
      );
    }

    // 6. Solid Route
    final route = payload['route'].toString().trim();
    if (!const {'Oral', 'Sublingual', 'Buccal', 'Chewable', 'Dispersible', 'Effervescent'}.contains(route)) {
      return MobileTabletCapsuleValidationResult.error(
        errorCode: 'ERR_INVALID_ROUTE_FOR_DOSAGE_FORM',
        messageEn: "Route '$route' is invalid for tablet/capsule dosage forms.",
        messageBn: "ট্যাবলেট বা ক্যাপসুলের জন্য '$route' সেবনের মাধ্যমটি সঠিক নয়।",
      );
    }

    return MobileTabletCapsuleValidationResult.valid(expectedBoxSize);
  }

  void cacheConfig(MobileTabletCapsuleConfig config) {
    _localCache[config.productId] = config;
  }

  MobileTabletCapsuleConfig? getCachedConfig(String productId) {
    return _localCache[productId];
  }

  List<MobileTabletCapsuleConfig> getLocalConfigs() {
    return _localCache.values.toList();
  }

  String getLabel(String key, String lang) {
    final isBn = lang.toLowerCase() == 'bn';
    switch (key) {
      case 'dose_strength':
        return isBn ? 'ডোজের মাত্রা' : 'Dose Strength';
      case 'strength_unit':
        return isBn ? 'মাত্রার একক' : 'Strength Unit';
      case 'tablets_per_strip':
        return isBn ? 'পাতা প্রতি ট্যাবলেট' : 'Tablets Per Strip';
      case 'strips_per_box':
        return isBn ? 'বক্স প্রতি পাতা' : 'Strips Per Box';
      case 'box_size':
        return isBn ? 'বক্সের মোট ট্যাবলেট' : 'Total Box Units';
      case 'loose_sale_eligible':
        return isBn ? 'খুচরা বিক্রয়যোগ্য' : 'Loose Sale Eligible';
      case 'route':
        return isBn ? 'সেবনের মাধ্যম' : 'Route';
      case 'storage_policy':
        return isBn ? 'সংরক্ষণ নীতি' : 'Storage Policy';
      default:
        return key;
    }
  }
}
