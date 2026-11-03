import 'package:flutter/foundation.dart';

/// MobileStorageConditionalClient
/// Architecture Decision: ADR-0155 (P155).
/// Phase 08: Milestone M04 / M05 - Specialized Item & Consumable Editors.
///
/// Flutter mobile client for conditional storage and cold-chain governance.
/// Enforces conditional exposure of cold-chain requirements, safe temperature ranges,
/// refrigerator shelf placement, and excursion tolerance protocols.

enum StorageUiStatus {
  loading,
  success,
  empty,
  error,
  permissionDenied,
  offline,
}

@immutable
class StorageValidationResult {
  final bool isValid;
  final String? errorCode;
  final String? errorMessage;
  final bool isColdChainRequired;
  final double temperatureDeltaCelsius;

  const StorageValidationResult({
    required this.isValid,
    this.errorCode,
    this.errorMessage,
    this.isColdChainRequired = false,
    this.temperatureDeltaCelsius = 0.0,
  });

  factory StorageValidationResult.success({
    required bool isColdChain,
    required double delta,
  }) {
    return StorageValidationResult(
      isValid: true,
      isColdChainRequired: isColdChain,
      temperatureDeltaCelsius: delta,
    );
  }

  factory StorageValidationResult.failure({
    required String errorCode,
    required String errorMessage,
  }) {
    return StorageValidationResult(
      isValid: false,
      errorCode: errorCode,
      errorMessage: errorMessage,
    );
  }
}

class MobileStorageConditionalClient {
  static const Map<String, Map<String, String>> placementTranslations = {
    'SHELF_MIDDLE': {
      'en': 'Middle Shelf (Uniform Temperature)',
      'bn': 'মাঝের তাক (স্থির তাপমাত্রা)',
    },
    'SHELF_TOP': {
      'en': 'Top Shelf',
      'bn': 'উপরের তাক',
    },
    'SHELF_BOTTOM': {
      'en': 'Bottom Shelf (Above Crisper)',
      'bn': 'নিচের তাক (ক্রিসপারের উপরে)',
    },
    'CHILLER_TRAY': {
      'en': 'Chiller Tray (2°C - 4°C)',
      'bn': 'চিলার ট্রে (২°সে - ৪°সে)',
    },
    'DOOR_NOT_PERMITTED': {
      'en': 'Door Placement Prohibited',
      'bn': 'দরজায় রাখা কঠোরভাবে নিষিদ্ধ',
    },
  };

  static const Map<String, Map<String, String>> actionTranslations = {
    'QUARANTINE_IMMEDIATELY': {
      'en': 'Quarantine Immediately for Assessment',
      'bn': 'তাত্ক্ষণিক কোয়ারেন্টাইন করুন',
    },
    'RETURN_TO_SUPPLIER': {
      'en': 'Return to Cold-Chain Supplier',
      'bn': 'কোল্ড-চেইন সরবরাহকারীকে ফেরত পাঠান',
    },
    'DISPOSE_BIOHAZARD': {
      'en': 'Biohazard Safe Disposal',
      'bn': 'নিরাপদ বায়োহ্যাজার্ড বিনষ্টকরণ',
    },
    'NOTIFY_SUPERVISOR': {
      'en': 'Notify Chief Pharmacist',
      'bn': 'প্রধান ফার্মাসিস্টকে অবহিত করুন',
    },
  };

  /// Validates storage parameters. For non-cold-chain items, fields remain inactive.
  StorageValidationResult validateStorageConditions({
    required bool isColdChainRequired,
    double? minTempCelsius,
    double? maxTempCelsius,
    String? refrigeratorPlacement,
    int maxExcursionHours = 24,
    String excursionHandlingAction = 'QUARANTINE_IMMEDIATELY',
  }) {
    if (!isColdChainRequired) {
      return StorageValidationResult.success(isColdChain: false, delta: 0.0);
    }

    if (minTempCelsius == null || maxTempCelsius == null) {
      return StorageValidationResult.failure(
        errorCode: 'ERR_MISSING_TEMPERATURE_RANGE',
        errorMessage:
            'Minimum and maximum temperatures are mandatory for cold-chain items.',
      );
    }

    if (minTempCelsius >= maxTempCelsius) {
      return StorageValidationResult.failure(
        errorCode: 'ERR_INVALID_TEMPERATURE_RANGE',
        errorMessage:
            'Minimum temperature ($minTempCelsius°C) must be less than maximum temperature ($maxTempCelsius°C).',
      );
    }

    if (refrigeratorPlacement == null || refrigeratorPlacement.trim().isEmpty) {
      return StorageValidationResult.failure(
        errorCode: 'ERR_MISSING_PLACEMENT_ZONE',
        errorMessage: 'Refrigerator placement zone is required.',
      );
    }

    final normalized = refrigeratorPlacement.trim().toUpperCase();
    if (normalized == 'DOOR_NOT_PERMITTED') {
      return StorageValidationResult.failure(
        errorCode: 'ERR_PROHIBITED_DOOR_PLACEMENT',
        errorMessage:
            'Medicines and biologicals cannot be placed on refrigerator doors.',
      );
    }

    if (maxExcursionHours < 0 || maxExcursionHours > 72) {
      return StorageValidationResult.failure(
        errorCode: 'ERR_INVALID_EXCURSION_HOURS',
        errorMessage: 'Maximum excursion hours must be between 0 and 72.',
      );
    }

    final delta = double.parse((maxTempCelsius - minTempCelsius).toStringAsFixed(2));
    return StorageValidationResult.success(isColdChain: true, delta: delta);
  }

  /// Verifies if user role can mutate storage configurations. Cashier is read-only.
  bool canMutateStorage(String? role) {
    if (role == null) return false;
    final normalized = role.toUpperCase().trim();
    return normalized != 'CASHIER';
  }

  /// Resolves localized string for refrigerator shelf placement.
  String getPlacementDisplay(String code, {String locale = 'en'}) {
    final entry = placementTranslations[code.toUpperCase().trim()];
    if (entry != null) {
      return entry[locale] ?? entry['en'] ?? code;
    }
    return code;
  }

  /// Resolves localized string for excursion handling action.
  String getActionDisplay(String code, {String locale = 'en'}) {
    final entry = actionTranslations[code.toUpperCase().trim()];
    if (entry != null) {
      return entry[locale] ?? entry['en'] ?? code;
    }
    return code;
  }

  /// Builds canonical payload for DRF API POST / PATCH.
  Map<String, dynamic> buildStoragePayload({
    required String productId,
    required bool isColdChainRequired,
    double? minTempCelsius,
    double? maxTempCelsius,
    String refrigeratorPlacement = 'SHELF_MIDDLE',
    int maxExcursionHours = 24,
    String excursionHandlingAction = 'QUARANTINE_IMMEDIATELY',
    bool requiresIcePackTransport = true,
    bool protectFromFreezing = true,
    String handlingAlertNotes = '',
  }) {
    final validation = validateStorageConditions(
      isColdChainRequired: isColdChainRequired,
      minTempCelsius: minTempCelsius,
      maxTempCelsius: maxTempCelsius,
      refrigeratorPlacement: refrigeratorPlacement,
      maxExcursionHours: maxExcursionHours,
      excursionHandlingAction: excursionHandlingAction,
    );

    if (!validation.isValid) {
      throw ArgumentError(validation.errorMessage);
    }

    if (!isColdChainRequired) {
      return {
        'product_id': productId,
        'is_cold_chain_required': false,
        'handling_alert_notes': handlingAlertNotes,
      };
    }

    return {
      'product_id': productId,
      'is_cold_chain_required': true,
      'min_temperature_celsius': minTempCelsius ?? 2.0,
      'max_temperature_celsius': maxTempCelsius ?? 8.0,
      'refrigerator_placement': refrigeratorPlacement,
      'max_excursion_hours': maxExcursionHours,
      'excursion_handling_action': excursionHandlingAction,
      'requires_ice_pack_transport': requiresIcePackTransport,
      'protect_from_freezing': protectFromFreezing,
      'handling_alert_notes': handlingAlertNotes,
    };
  }
}
