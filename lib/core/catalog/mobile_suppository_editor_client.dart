import 'package:flutter/foundation.dart';

/// MobileSuppositoryEditorClient
/// Architecture Decision: ADR-0150 (P150).
/// Phase 08: Milestone M04 / M05 - Specialized Dosage-Form Editors.
///
/// Flutter mobile client for managing Suppositories and Pessaries,
/// piece counts, active strength, anatomical routes, and melt-protection storage.
enum SuppositoryUiStatus {
  loading,
  success,
  empty,
  error,
  permissionDenied,
  offline,
}

@immutable
class MobileSuppositoryRecord {
  final String configId;
  final String productId;
  final String? tenantId;
  final String suppositoryBaseType; // FATTY_BASE_COCOA_BUTTER, WATER_SOLUBLE_PEG, GLYCERINATED_GELATIN
  final String administrationRoute; // RECTAL, VAGINAL, URETHRAL
  final double strengthValue;
  final String strengthUnit;
  final int piecesPerStrip;
  final int stripsPerPack;
  final int? totalPiecesPerPack;
  final bool loosePieceSaleEligible;
  final bool requiresRefrigeration;
  final String storageCondition;
  final String patientInstructionsEn;
  final String patientInstructionsBn;
  final bool isActive;

  const MobileSuppositoryRecord({
    required this.configId,
    required this.productId,
    this.tenantId,
    required this.suppositoryBaseType,
    required this.administrationRoute,
    required this.strengthValue,
    required this.strengthUnit,
    required this.piecesPerStrip,
    required this.stripsPerPack,
    this.totalPiecesPerPack,
    this.loosePieceSaleEligible = true,
    this.requiresRefrigeration = false,
    required this.storageCondition,
    required this.patientInstructionsEn,
    required this.patientInstructionsBn,
    this.isActive = true,
  });

  factory MobileSuppositoryRecord.fromJson(Map<String, dynamic> json) {
    return MobileSuppositoryRecord(
      configId: json['config_id'] as String,
      productId: json['product_id'] as String,
      tenantId: json['tenant_id'] as String?,
      suppositoryBaseType: json['suppository_base_type'] as String? ?? 'FATTY_BASE_COCOA_BUTTER',
      administrationRoute: json['administration_route'] as String? ?? 'RECTAL',
      strengthValue: double.tryParse(json['strength_value'].toString()) ?? 250.0,
      strengthUnit: json['strength_unit'] as String? ?? 'MG',
      piecesPerStrip: json['pieces_per_strip'] as int? ?? 5,
      stripsPerPack: json['strips_per_pack'] as int? ?? 2,
      totalPiecesPerPack: json['total_pieces_per_pack'] as int?,
      loosePieceSaleEligible: json['loose_piece_sale_eligible'] as bool? ?? true,
      requiresRefrigeration: json['requires_refrigeration'] as bool? ?? false,
      storageCondition: json['storage_condition'] as String? ?? 'COOL_BELOW_25',
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
      'suppository_base_type': suppositoryBaseType,
      'administration_route': administrationRoute,
      'strength_value': strengthValue.toStringAsFixed(4),
      'strength_unit': strengthUnit,
      'pieces_per_strip': piecesPerStrip,
      'strips_per_pack': stripsPerPack,
      'total_pieces_per_pack': totalPiecesPerPack,
      'loose_piece_sale_eligible': loosePieceSaleEligible,
      'requires_refrigeration': requiresRefrigeration,
      'storage_condition': storageCondition,
      'patient_instructions_en': patientInstructionsEn,
      'patient_instructions_bn': patientInstructionsBn,
      'is_active': isActive,
    };
  }
}

class MobileSuppositoryValidationResult {
  final bool isValid;
  final String? errorCode;
  final String messageEn;
  final String messageBn;

  const MobileSuppositoryValidationResult({
    required this.isValid,
    this.errorCode,
    required this.messageEn,
    required this.messageBn,
  });

  factory MobileSuppositoryValidationResult.valid() {
    return const MobileSuppositoryValidationResult(
      isValid: true,
      messageEn: 'Validation passed successfully.',
      messageBn: 'যাচাই সফল হয়েছে।',
    );
  }

  factory MobileSuppositoryValidationResult.error(String code, String msgEn, String msgBn) {
    return MobileSuppositoryValidationResult(
      isValid: false,
      errorCode: code,
      messageEn: msgEn,
      messageBn: msgBn,
    );
  }
}

class MobileSuppositoryEditorClient {
  static const List<String> forbiddenSolidFields = [
    'tablets_per_strip',
    'units_per_strip',
    'is_scored',
    'coating_type',
    'needle_gauge',
  ];

  static const List<String> allowedBases = [
    'FATTY_BASE_COCOA_BUTTER',
    'WATER_SOLUBLE_PEG',
    'GLYCERINATED_GELATIN',
  ];

  static const List<String> allowedRoutes = [
    'RECTAL',
    'VAGINAL',
    'URETHRAL',
  ];

  static MobileSuppositoryValidationResult validateDraftPayload(Map<String, dynamic> payload) {
    if (payload.isEmpty) {
      return MobileSuppositoryValidationResult.error(
        'ERR_EMPTY_PAYLOAD',
        'Payload cannot be empty.',
        'পে-লোড খালি হতে পারে না।',
      );
    }

    for (final field in forbiddenSolidFields) {
      if (payload.containsKey(field) && payload[field] != null) {
        return MobileSuppositoryValidationResult.error(
          'ERR_HIDDEN_FIELD_VALUE_REJECTED',
          "Field '$field' is illegal for suppository dosage form.",
          "সাপোজিটরি ডোজ ফর্মের জন্য '$field' ফিল্ডটি নিষিদ্ধ।",
        );
      }
    }

    final baseType = payload['suppository_base_type'] as String?;
    if (baseType == null || !allowedBases.contains(baseType)) {
      return MobileSuppositoryValidationResult.error(
        'ERR_INVALID_SUPPOSITORY_BASE',
        'Invalid suppository base.',
        'অবৈধ সাপোজিটরি বেস।',
      );
    }

    final route = payload['administration_route'] as String?;
    if (route == null || !allowedRoutes.contains(route)) {
      return MobileSuppositoryValidationResult.error(
        'ERR_INVALID_SUPPOSITORY_ROUTE',
        'Route must be RECTAL, VAGINAL, or URETHRAL.',
        'অবৈধ প্রয়োগ রুট।',
      );
    }

    final rawStrength = payload['strength_value'];
    final strength = rawStrength is num ? rawStrength.toDouble() : double.tryParse(rawStrength?.toString() ?? '');
    if (strength == null || strength <= 0) {
      return MobileSuppositoryValidationResult.error(
        'ERR_INVALID_STRENGTH',
        'strength_value must be greater than 0.',
        'মাত্রা শূন্যের চেয়ে বড় হতে হবে।',
      );
    }

    final rawPieces = payload['pieces_per_strip'];
    final pieces = rawPieces is int ? rawPieces : int.tryParse(rawPieces?.toString() ?? '');
    if (pieces == null || pieces < 1 || pieces > 50) {
      return MobileSuppositoryValidationResult.error(
        'ERR_INVALID_PIECES_PER_STRIP',
        'pieces_per_strip must be between 1 and 50.',
        'স্ট্রিপে পিস সংখ্যা ১ থেকে ৫০ এর মধ্যে হতে হবে।',
      );
    }

    final rawStrips = payload['strips_per_pack'];
    final strips = rawStrips is int ? rawStrips : int.tryParse(rawStrips?.toString() ?? '');
    if (strips == null || strips < 1 || strips > 100) {
      return MobileSuppositoryValidationResult.error(
        'ERR_INVALID_STRIPS_PER_PACK',
        'strips_per_pack must be between 1 and 100.',
        'প্যাকে স্ট্রিপ সংখ্যা ১ থেকে ১০০ এর মধ্যে হতে হবে।',
      );
    }

    final rawTotalPieces = payload['total_pieces_per_pack'];
    if (rawTotalPieces != null && rawTotalPieces.toString().trim().isNotEmpty) {
      final totalPieces = rawTotalPieces is int ? rawTotalPieces : int.tryParse(rawTotalPieces.toString());
      if (totalPieces != null) {
        final expected = pieces * strips;
        if (totalPieces != expected) {
          return MobileSuppositoryValidationResult.error(
            'ERR_DIMENSION_CONSISTENCY_MISMATCH',
            'total_pieces_per_pack ($totalPieces) does not equal pieces * strips ($expected).',
            'প্যাকের মোট পিস ও স্ট্রিপের হিসাবের গরমিল।',
          );
        }
      }
    }

    final requiresRefrigeration = payload['requires_refrigeration'] == true;
    final storage = payload['storage_condition'] as String?;
    if (requiresRefrigeration && storage != null && storage != 'REFRIGERATED_2_8' && storage != 'COOL_BELOW_25') {
      return MobileSuppositoryValidationResult.error(
        'ERR_MELT_PROTECTION_STORAGE_REQUIRED',
        'Suppositories requiring refrigeration must specify REFRIGERATED_2_8 or COOL_BELOW_25 storage condition.',
        'সাপোজিটরি গলে যাওয়া প্রতিরোধে ঠান্ডা বা ফ্রিজ স্টোরেজ আবশ্যক।',
      );
    }

    return MobileSuppositoryValidationResult.valid();
  }
}
