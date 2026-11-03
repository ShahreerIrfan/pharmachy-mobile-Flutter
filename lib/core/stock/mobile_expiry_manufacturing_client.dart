import 'package:flutter/foundation.dart';

/// MobileExpiryManufacturingClient
/// Architecture Decision: ADR-0154 (P154).
/// Phase 08: Milestone M04 / M05 - Regulated Expiry and Manufacturing Date Controls.
///
/// Flutter mobile client for regulated stock entry intake.
/// Coordinates manufacturing date, expiration date, manufacturer lot numbers,
/// automatic quarantine flags, and bilingual storage condition directives.

enum StockUiStatus {
  loading,
  success,
  empty,
  error,
  permissionDenied,
  offline,
}

@immutable
class StockValidationResult {
  final bool isValid;
  final String? errorCode;
  final String? errorMessage;
  final int shelfLifeDays;
  final bool isAutoQuarantined;

  const StockValidationResult({
    required this.isValid,
    this.errorCode,
    this.errorMessage,
    this.shelfLifeDays = 0,
    this.isAutoQuarantined = false,
  });

  factory StockValidationResult.success({
    required int shelfLifeDays,
    required bool isAutoQuarantined,
  }) {
    return StockValidationResult(
      isValid: true,
      shelfLifeDays: shelfLifeDays,
      isAutoQuarantined: isAutoQuarantined,
    );
  }

  factory StockValidationResult.failure({
    required String errorCode,
    required String errorMessage,
  }) {
    return StockValidationResult(
      isValid: false,
      errorCode: errorCode,
      errorMessage: errorMessage,
    );
  }
}

class MobileExpiryManufacturingClient {
  static final RegExp lotPattern = RegExp(r'^[A-Za-z0-9\-_./]+$');

  static const Map<String, Map<String, String>> storageTranslations = {
    'ROOM_TEMPERATURE_15_25C': {
      'en': 'Room Temperature (15°C - 25°C)',
      'bn': 'স্বাভাবিক তাপমাত্রা (১৫°সে - ২৫°সে)',
    },
    'COOL_8_15C': {
      'en': 'Cool Storage (8°C - 15°C)',
      'bn': 'শীতল তাপমাত্রা (৮°সে - ১৫°সে)',
    },
    'COLD_CHAIN_2_8C': {
      'en': 'Cold Chain (2°C - 8°C)',
      'bn': 'কোল্ড চেইন রেফ্রিজারেশন (২°সে - ৮°সে)',
    },
    'FREEZER_MINUS_20C': {
      'en': 'Freezer (-20°C)',
      'bn': 'ডিপ ফ্রিজার (-২০°সে)',
    },
    'DO_NOT_FREEZE': {
      'en': 'Do Not Freeze',
      'bn': 'ফ্রিজ করবেন না',
    },
    'PROTECT_FROM_LIGHT': {
      'en': 'Protect From Direct Light',
      'bn': 'সরাসরি আলো থেকে সুরক্ষিত রাখুন',
    },
  };

  /// Validates stock entry dates, lot number and quarantine constraints.
  StockValidationResult validateStockIntake({
    required String lotReference,
    required DateTime manufacturingDate,
    required DateTime expiryDate,
    DateTime? currentDate,
    int quarantineLeadDays = 30,
    bool isQuarantined = false,
  }) {
    final now = currentDate ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final mfg = DateTime(
      manufacturingDate.year,
      manufacturingDate.month,
      manufacturingDate.day,
    );
    final exp = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);

    final trimmedLot = lotReference.trim();
    if (trimmedLot.isEmpty) {
      return StockValidationResult.failure(
        errorCode: 'ERR_MISSING_LOT_REFERENCE',
        errorMessage: 'Lot reference is required.',
      );
    }

    if (trimmedLot.length < 2 || trimmedLot.length > 64) {
      return StockValidationResult.failure(
        errorCode: 'ERR_INVALID_LOT_LENGTH',
        errorMessage: 'Lot reference must be 2 to 64 characters.',
      );
    }

    if (!lotPattern.hasMatch(trimmedLot)) {
      return StockValidationResult.failure(
        errorCode: 'ERR_INVALID_LOT_FORMAT',
        errorMessage: 'Lot reference contains invalid characters.',
      );
    }

    if (mfg.isAfter(today)) {
      return StockValidationResult.failure(
        errorCode: 'ERR_FUTURE_MANUFACTURING_DATE',
        errorMessage: 'Manufacturing date cannot be in the future.',
      );
    }

    if (!exp.isAfter(mfg)) {
      return StockValidationResult.failure(
        errorCode: 'ERR_EXPIRY_BEFORE_MANUFACTURING',
        errorMessage: 'Expiration date must be strictly after manufacturing date.',
      );
    }

    final daysUntilExpiry = exp.difference(today).inDays;
    if (daysUntilExpiry <= 0 && !isQuarantined) {
      return StockValidationResult.failure(
        errorCode: 'ERR_STOCK_ALREADY_EXPIRED',
        errorMessage:
            'Expired stock cannot be received into active dispensing inventory.',
      );
    }

    bool autoQuarantined = isQuarantined;
    if (daysUntilExpiry <= quarantineLeadDays && !autoQuarantined) {
      autoQuarantined = true;
    }

    final totalShelfLife = exp.difference(mfg).inDays;

    return StockValidationResult.success(
      shelfLifeDays: totalShelfLife,
      isAutoQuarantined: autoQuarantined,
    );
  }

  /// Verifies if user role can mutate stock intake. Cashier is read-only.
  bool canMutateStock(String? role) {
    if (role == null) return false;
    final normalized = role.toUpperCase().trim();
    return normalized != 'CASHIER';
  }

  /// Resolves localized string for storage condition.
  String getStorageConditionDisplay(String code, {String locale = 'en'}) {
    final entry = storageTranslations[code.toUpperCase().trim()];
    if (entry != null) {
      return entry[locale] ?? entry['en'] ?? code;
    }
    return code;
  }

  /// Builds canonical payload for DRF stock entry intake.
  Map<String, dynamic> buildStockEntryPayload({
    required String productId,
    required String lotReference,
    required DateTime manufacturingDate,
    required DateTime expiryDate,
    required int quantityReceived,
    required double unitCostBdt,
    String storageCondition = 'ROOM_TEMPERATURE_15_25C',
    int quarantineLeadDays = 30,
    bool isQuarantined = false,
    int? reconstitutionShelfLifeDays,
    String supplierReference = '',
    String entryNotes = '',
  }) {
    final validation = validateStockIntake(
      lotReference: lotReference,
      manufacturingDate: manufacturingDate,
      expiryDate: expiryDate,
      quarantineLeadDays: quarantineLeadDays,
      isQuarantined: isQuarantined,
    );

    return {
      'product_id': productId,
      'lot_reference': lotReference.trim(),
      'manufacturing_date':
          "${manufacturingDate.year.toString().padLeft(4, '0')}-${manufacturingDate.month.toString().padLeft(2, '0')}-${manufacturingDate.day.toString().padLeft(2, '0')}",
      'expiry_date':
          "${expiryDate.year.toString().padLeft(4, '0')}-${expiryDate.month.toString().padLeft(2, '0')}-${expiryDate.day.toString().padLeft(2, '0')}",
      'quantity_received': quantityReceived,
      'unit_cost_bdt': unitCostBdt,
      'storage_condition': storageCondition,
      'quarantine_lead_days': quarantineLeadDays,
      'is_quarantined': validation.isAutoQuarantined,
      'reconstitution_shelf_life_days': reconstitutionShelfLifeDays,
      'supplier_reference': supplierReference,
      'entry_notes': entryNotes,
    };
  }
}

