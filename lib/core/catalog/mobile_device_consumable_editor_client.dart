import 'package:flutter/foundation.dart';

/// MobileDeviceConsumableEditorClient
/// Architecture Decision: ADR-0151 (P151).
/// Phase 08: Milestone M04 / M05 - Specialized Item & Consumable Editors.
///
/// Flutter mobile client for managing Medical Devices, Needles,
/// Diagnostic Test Strips, and Consumables without medicine-only restrictions.
enum DeviceUiStatus {
  loading,
  success,
  empty,
  error,
  permissionDenied,
  offline,
}

@immutable
class MobileDeviceConsumableRecord {
  final String id;
  final String productId;
  final String? tenantId;
  final String deviceCategory;
  final String brandName;
  final String modelNumber;
  final String needleGauge;
  final double needleLengthMm;
  final String meterCompatibility;
  final int stripCountPerPack;
  final double sampleVolumeMicroliter;
  final int testTimeSeconds;
  final bool isSterile;
  final bool isSingleUse;
  final String regulatoryDeviceClass;
  final double storageTemperatureCelsiusMin;
  final double storageTemperatureCelsiusMax;
  final bool isActive;

  const MobileDeviceConsumableRecord({
    required this.id,
    required this.productId,
    this.tenantId,
    required this.deviceCategory,
    required this.brandName,
    this.modelNumber = '',
    this.needleGauge = 'NA',
    this.needleLengthMm = 0.0,
    this.meterCompatibility = '',
    this.stripCountPerPack = 0,
    this.sampleVolumeMicroliter = 0.0,
    this.testTimeSeconds = 0,
    this.isSterile = false,
    this.isSingleUse = true,
    this.regulatoryDeviceClass = 'CLASS_A_LOW_RISK',
    this.storageTemperatureCelsiusMin = 2.0,
    this.storageTemperatureCelsiusMax = 30.0,
    this.isActive = true,
  });

  factory MobileDeviceConsumableRecord.fromJson(Map<String, dynamic> json) {
    return MobileDeviceConsumableRecord(
      id: json['id'] as String,
      productId: json['product_id'] as String,
      tenantId: json['tenant_id'] as String?,
      deviceCategory: json['device_category'] as String? ?? 'GENERAL_CONSUMABLE',
      brandName: json['brand_name'] as String? ?? '',
      modelNumber: json['model_number'] as String? ?? '',
      needleGauge: json['needle_gauge'] as String? ?? 'NA',
      needleLengthMm: double.tryParse(json['needle_length_mm'].toString()) ?? 0.0,
      meterCompatibility: json['meter_compatibility'] as String? ?? '',
      stripCountPerPack: json['strip_count_per_pack'] as int? ?? 0,
      sampleVolumeMicroliter: double.tryParse(json['sample_volume_microliter'].toString()) ?? 0.0,
      testTimeSeconds: json['test_time_seconds'] as int? ?? 0,
      isSterile: json['is_sterile'] as bool? ?? false,
      isSingleUse: json['is_single_use'] as bool? ?? true,
      regulatoryDeviceClass: json['regulatory_device_class'] as String? ?? 'CLASS_A_LOW_RISK',
      storageTemperatureCelsiusMin: double.tryParse(json['storage_temperature_celsius_min'].toString()) ?? 2.0,
      storageTemperatureCelsiusMax: double.tryParse(json['storage_temperature_celsius_max'].toString()) ?? 30.0,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_id': productId,
      'tenant_id': tenantId,
      'device_category': deviceCategory,
      'brand_name': brandName,
      'model_number': modelNumber,
      'needle_gauge': needleGauge,
      'needle_length_mm': needleLengthMm,
      'meter_compatibility': meterCompatibility,
      'strip_count_per_pack': stripCountPerPack,
      'sample_volume_microliter': sampleVolumeMicroliter,
      'test_time_seconds': testTimeSeconds,
      'is_sterile': isSterile,
      'is_single_use': isSingleUse,
      'regulatory_device_class': regulatoryDeviceClass,
      'storage_temperature_celsius_min': storageTemperatureCelsiusMin,
      'storage_temperature_celsius_max': storageTemperatureCelsiusMax,
      'is_active': isActive,
    };
  }
}

class MobileDeviceValidationResult {
  final bool isValid;
  final String? errorCode;
  final String messageEn;
  final String messageBn;

  const MobileDeviceValidationResult({
    required this.isValid,
    this.errorCode,
    required this.messageEn,
    required this.messageBn,
  });

  factory MobileDeviceValidationResult.valid() {
    return const MobileDeviceValidationResult(
      isValid: true,
      errorCode: null,
      messageEn: 'Validation passed',
      messageBn: 'যাচাই সফল হয়েছে',
    );
  }

  factory MobileDeviceValidationResult.error(String code, String msgEn, String msgBn) {
    return MobileDeviceValidationResult(
      isValid: false,
      errorCode: code,
      messageEn: msgEn,
      messageBn: msgBn,
    );
  }
}

class MobileDeviceConsumableEditorClient {
  static const List<String> forbiddenMedicineFields = [
    'dosage_form',
    'is_antibiotic',
    'pom_required',
    'prescription_required',
    'narcotic_schedule',
    'active_ingredient',
    'active_ingredient_concentration',
  ];

  static const Set<String> allowedCategories = {
    'NEEDLE_OR_SYRINGE',
    'DIAGNOSTIC_TEST_STRIP',
    'MONITORING_DEVICE',
    'SURGICAL_CONSUMABLE',
    'RESPIRATORY_DEVICE',
    'GENERAL_CONSUMABLE',
  };

  static const Set<String> allowedGauges = {
    '18G', '20G', '21G', '22G', '23G', '25G', '26G', '27G', '29G', '30G', '31G', '32G', 'NA',
  };

  MobileDeviceValidationResult validateDraftPayload(Map<String, dynamic>? payload) {
    if (payload == null || payload.isEmpty) {
      return MobileDeviceValidationResult.error(
        'ERR_EMPTY_PAYLOAD',
        'Payload cannot be empty',
        'পে-লোড খালি হতে পারে না',
      );
    }

    // 1. Medicine-only forbidden fields
    for (final field in forbiddenMedicineFields) {
      if (payload.containsKey(field) && payload[field] != null) {
        return MobileDeviceValidationResult.error(
          'ERR_MEDICINE_FIELD_REJECTED',
          "Medicine-only field '$field' is illegal for device & consumable catalog.",
          "মেডিকেল ডিভাইস বা কনজিউমেবলের জন্য ওষুধ-নির্দিষ্ট ফিল্ড '$field' নিষিদ্ধ।",
        );
      }
    }

    // 2. Category validation
    final category = payload['device_category'] as String?;
    if (category == null || !allowedCategories.contains(category)) {
      return MobileDeviceValidationResult.error(
        'ERR_INVALID_DEVICE_CATEGORY',
        'Invalid device category: $category',
        'অবৈধ ডিভাইস ক্যাটাগরি।',
      );
    }

    // 3. Brand name
    final brandName = payload['brand_name'] as String?;
    if (brandName == null || brandName.trim().length < 2) {
      return MobileDeviceValidationResult.error(
        'ERR_INVALID_BRAND_NAME',
        'brand_name is mandatory and must be at least 2 characters.',
        'ব্র্যান্ড নাম আবশ্যক এবং অন্তত ২ অক্ষরের হতে হবে।',
      );
    }

    // 4. Needles validation
    if (category == 'NEEDLE_OR_SYRINGE') {
      final gauge = payload['needle_gauge'] as String?;
      if (gauge == null || gauge == 'NA' || !allowedGauges.contains(gauge)) {
        return MobileDeviceValidationResult.error(
          'ERR_INVALID_NEEDLE_GAUGE',
          'Needles and syringes must specify a valid needle gauge (e.g., 21G, 25G, 31G).',
          'সূঁচ বা সিরিঞ্জের জন্য সঠিক গজ উল্লেখ করা আবশ্যক।',
        );
      }

      final lenVal = payload['needle_length_mm'];
      if (lenVal == null) {
        return MobileDeviceValidationResult.error(
          'ERR_INVALID_NEEDLE_LENGTH',
          'needle_length_mm is required for needles.',
          'সূঁচের দৈর্ঘ্য আবশ্যক।',
        );
      }
      final len = double.tryParse(lenVal.toString()) ?? 0.0;
      if (len <= 0.0) {
        return MobileDeviceValidationResult.error(
          'ERR_INVALID_NEEDLE_LENGTH',
          'needle_length_mm must be greater than 0.',
          'সূঁচের দৈর্ঘ্য শূন্যের চেয়ে বড় হতে হবে।',
        );
      }
    }

    // 5. Diagnostic Test Strip validation
    if (category == 'DIAGNOSTIC_TEST_STRIP') {
      final meter = payload['meter_compatibility'] as String?;
      if (meter == null || meter.trim().isEmpty) {
        return MobileDeviceValidationResult.error(
          'ERR_MISSING_METER_COMPATIBILITY',
          'Diagnostic test strips must specify meter compatibility.',
          'টেস্ট স্ট্রিপের জন্য প্রযোজ্য মিটারের নাম উল্লেখ আবশ্যক।',
        );
      }

      final stripVal = payload['strip_count_per_pack'];
      if (stripVal == null) {
        return MobileDeviceValidationResult.error(
          'ERR_INVALID_STRIP_COUNT',
          'strip_count_per_pack is required.',
          'প্যাক প্রতি স্ট্রিপ সংখ্যা আবশ্যক।',
        );
      }
      final count = int.tryParse(stripVal.toString()) ?? 0;
      if (count < 1) {
        return MobileDeviceValidationResult.error(
          'ERR_INVALID_STRIP_COUNT',
          'strip_count_per_pack must be at least 1.',
          'স্ট্রিপ সংখ্যা অন্তত ১ হতে হবে।',
        );
      }
    }

    // 6. Storage temperature validation
    final minVal = payload['storage_temperature_celsius_min'];
    final maxVal = payload['storage_temperature_celsius_max'];
    if (minVal != null && maxVal != null) {
      final minTemp = double.tryParse(minVal.toString());
      final maxTemp = double.tryParse(maxVal.toString());
      if (minTemp != null && maxTemp != null && minTemp > maxTemp) {
        return MobileDeviceValidationResult.error(
          'ERR_INVALID_TEMPERATURE_RANGE',
          'storage_temperature_celsius_min cannot exceed max.',
          'সর্বনিম্ন তাপমাত্রা সর্বোচ্চ তাপমাত্রার চেয়ে বেশি হতে পারে না।',
        );
      }
    }

    return MobileDeviceValidationResult.valid();
  }
}
