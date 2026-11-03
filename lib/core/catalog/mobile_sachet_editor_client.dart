import 'package:flutter/foundation.dart';

/// MobileSachetEditorClient
/// Architecture Decision: ADR-0149 (P149).
/// Phase 08: Milestone M04 / M05 - Specialized Dosage-Form Editors.
///
/// Flutter mobile client for managing Sachets, Powders, and Granules,
/// grams per sachet, multi-tier pack counts, break-bulk loose sachet eligibility,
/// and fluid mixing/dissolution instructions.
enum SachetUiStatus {
  loading,
  success,
  empty,
  error,
  permissionDenied,
  offline,
}

@immutable
class MobileSachetRecord {
  final String configId;
  final String productId;
  final String? tenantId;
  final String powderCategory; // ORAL_REHYDRATION_SALTS, EFFERVESCENT_POWDER, BULK_LAXATIVE_HUSK, etc.
  final String administrationRoute; // ORAL, TOPICAL
  final double gramsPerSachet;
  final int sachetsPerPack;
  final double? totalPackWeightGrams;
  final bool looseSachetSaleEligible;
  final bool requiresDissolution;
  final String diluentType;
  final double? diluentVolumeMl;
  final int reconstitutedStabilityHours;
  final String storageCondition;
  final String patientInstructionsEn;
  final String patientInstructionsBn;
  final bool isActive;

  const MobileSachetRecord({
    required this.configId,
    required this.productId,
    this.tenantId,
    required this.powderCategory,
    required this.administrationRoute,
    required this.gramsPerSachet,
    required this.sachetsPerPack,
    this.totalPackWeightGrams,
    this.looseSachetSaleEligible = true,
    this.requiresDissolution = true,
    this.diluentType = 'POTABLE_WATER',
    this.diluentVolumeMl = 500.0,
    this.reconstitutedStabilityHours = 24,
    required this.storageCondition,
    required this.patientInstructionsEn,
    required this.patientInstructionsBn,
    this.isActive = true,
  });

  factory MobileSachetRecord.fromJson(Map<String, dynamic> json) {
    return MobileSachetRecord(
      configId: json['config_id'] as String,
      productId: json['product_id'] as String,
      tenantId: json['tenant_id'] as String?,
      powderCategory: json['powder_category'] as String? ?? 'ORAL_REHYDRATION_SALTS',
      administrationRoute: json['administration_route'] as String? ?? 'ORAL',
      gramsPerSachet: double.tryParse(json['grams_per_sachet'].toString()) ?? 10.25,
      sachetsPerPack: json['sachets_per_pack'] as int? ?? 25,
      totalPackWeightGrams: json['total_pack_weight_grams'] != null
          ? double.tryParse(json['total_pack_weight_grams'].toString())
          : null,
      looseSachetSaleEligible: json['loose_sachet_sale_eligible'] as bool? ?? true,
      requiresDissolution: json['requires_dissolution'] as bool? ?? true,
      diluentType: json['diluent_type'] as String? ?? 'POTABLE_WATER',
      diluentVolumeMl: json['diluent_volume_ml'] != null
          ? double.tryParse(json['diluent_volume_ml'].toString())
          : null,
      reconstitutedStabilityHours: json['reconstituted_stability_hours'] as int? ?? 24,
      storageCondition: json['storage_condition'] as String? ?? 'COOL_DRY_BELOW_30',
      patientInstructionsEn: json['patient_instructions_en'] as String? ?? '',
      patientInstructionsBn: json['patient_instructions_bn'] as String? ?? '',
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'config_id': configId,
      'product_id': productId,
      'tenant_id': tenantId,
      'powder_category': powderCategory,
      'administration_route': administrationRoute,
      'grams_per_sachet': gramsPerSachet.toStringAsFixed(2),
      'sachets_per_pack': sachetsPerPack,
      'total_pack_weight_grams': totalPackWeightGrams?.toStringAsFixed(2),
      'loose_sachet_sale_eligible': looseSachetSaleEligible,
      'requires_dissolution': requiresDissolution,
      'diluent_type': diluentType,
      'diluent_volume_ml': diluentVolumeMl?.toStringAsFixed(2),
      'reconstituted_stability_hours': reconstitutedStabilityHours,
      'storage_condition': storageCondition,
      'patient_instructions_en': patientInstructionsEn,
      'patient_instructions_bn': patientInstructionsBn,
      'is_active': isActive,
    };
  }
}

class MobileSachetValidationResult {
  final bool isValid;
  final String? errorCode;
  final String messageEn;
  final String messageBn;

  const MobileSachetValidationResult({
    required this.isValid,
    this.errorCode,
    required this.messageEn,
    required this.messageBn,
  });

  factory MobileSachetValidationResult.valid() {
    return const MobileSachetValidationResult(
      isValid: true,
      messageEn: 'Validation passed successfully.',
      messageBn: 'যাচাই সফল হয়েছে।',
    );
  }

  factory MobileSachetValidationResult.error(String code, String msgEn, String msgBn) {
    return MobileSachetValidationResult(
      isValid: false,
      errorCode: code,
      messageEn: msgEn,
      messageBn: msgBn,
    );
  }
}

class MobileSachetEditorClient {
  static const List<String> forbiddenSolidFields = [
    'strips_per_box',
    'tablets_per_strip',
    'units_per_strip',
    'is_scored',
    'coating_type',
    'needle_gauge',
  ];

  static const List<String> allowedCategories = [
    'ORAL_REHYDRATION_SALTS',
    'EFFERVESCENT_POWDER',
    'BULK_LAXATIVE_HUSK',
    'SUSPENSION_GRANULES',
    'TOPICAL_DUSTING_POWDER',
  ];

  static const List<String> allowedRoutes = [
    'ORAL',
    'TOPICAL',
  ];

  static MobileSachetValidationResult validateDraftPayload(Map<String, dynamic> payload) {
    if (payload.isEmpty) {
      return MobileSachetValidationResult.error(
        'ERR_EMPTY_PAYLOAD',
        'Payload cannot be empty.',
        'পে-লোড খালি হতে পারে না।',
      );
    }

    for (final field in forbiddenSolidFields) {
      if (payload.containsKey(field) && payload[field] != null) {
        return MobileSachetValidationResult.error(
          'ERR_HIDDEN_FIELD_VALUE_REJECTED',
          "Field '$field' is illegal for sachet/powder dosage form.",
          "স্যাশে/পাউডার ডোজ ফর্মের জন্য '$field' ফিল্ডটি নিষিদ্ধ।",
        );
      }
    }

    final category = payload['powder_category'] as String?;
    if (category == null || !allowedCategories.contains(category)) {
      return MobileSachetValidationResult.error(
        'ERR_INVALID_POWDER_CATEGORY',
        'Invalid powder category.',
        'অবৈধ পাউডার ক্যাটাগরি।',
      );
    }

    final route = payload['administration_route'] as String?;
    if (route == null || !allowedRoutes.contains(route)) {
      return MobileSachetValidationResult.error(
        'ERR_INVALID_ADMINISTRATION_ROUTE',
        'Route must be ORAL or TOPICAL.',
        'অবৈধ প্রয়োগ রুট।',
      );
    }

    final rawGrams = payload['grams_per_sachet'];
    final grams = rawGrams is num ? rawGrams.toDouble() : double.tryParse(rawGrams?.toString() ?? '');
    if (grams == null || grams <= 0) {
      return MobileSachetValidationResult.error(
        'ERR_INVALID_GRAMS_PER_SACHET',
        'grams_per_sachet must be greater than 0.',
        'স্যাশের ওজন শূন্যের চেয়ে বড় হতে হবে।',
      );
    }

    final rawCount = payload['sachets_per_pack'];
    final count = rawCount is int ? rawCount : int.tryParse(rawCount?.toString() ?? '');
    if (count == null || count < 1 || count > 500) {
      return MobileSachetValidationResult.error(
        'ERR_INVALID_SACHETS_PER_PACK',
        'sachets_per_pack must be between 1 and 500.',
        'প্যাকে স্যাশে সংখ্যা ১ থেকে ৫০০ এর মধ্যে হতে হবে।',
      );
    }

    final rawPackWeight = payload['total_pack_weight_grams'];
    if (rawPackWeight != null && rawPackWeight.toString().trim().isNotEmpty) {
      final packWeight = rawPackWeight is num
          ? rawPackWeight.toDouble()
          : double.tryParse(rawPackWeight.toString());
      if (packWeight != null) {
        final expected = grams * count;
        if ((packWeight - expected).abs() > 0.05) {
          return MobileSachetValidationResult.error(
            'ERR_DIMENSION_CONSISTENCY_MISMATCH',
            'total_pack_weight_grams ($packWeight) does not equal grams * sachets ($expected).',
            'প্যাকের মোট ওজন ও স্যাশের ওজনের হিসাবের গরমিল।',
          );
        }
      }
    }

    final requiresDissolution = payload['requires_dissolution'] == true;
    if (requiresDissolution) {
      final rawVol = payload['diluent_volume_ml'];
      final vol = rawVol is num ? rawVol.toDouble() : double.tryParse(rawVol?.toString() ?? '');
      if (vol == null || vol <= 0) {
        return MobileSachetValidationResult.error(
          'ERR_MISSING_DILUENT_VOLUME',
          'diluent_volume_ml is required when dissolution is required.',
          'পানির পরিমাণ আবশ্যক।',
        );
      }
    }

    return MobileSachetValidationResult.valid();
  }
}

