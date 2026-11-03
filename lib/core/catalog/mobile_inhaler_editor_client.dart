import 'package:flutter/foundation.dart';

/// MobileInhalerEditorClient
/// Architecture Decision: ADR-0146 (P146).
/// Phase 08: Milestone M04 / M05 - Specialized Dosage-Form Editors.
///
/// Flutter mobile client for managing Inhaler (MDI, DPI, SMI) formulations,
/// actuation dosing, dose counters, spacers, and dimension consistency.
enum InhalerUiStatus {
  loading,
  success,
  empty,
  error,
  permissionDenied,
  offline,
}

@immutable
class MobileInhalerRecord {
  final String configId;
  final String productId;
  final String? tenantId;
  final String deviceType; // MDI_PRESSURIZED, DPI_DRY_POWDER, SMI_SOFT_MIST, BREATH_ACTUATED_MDI, NEBULIZER_AMPOULE
  final String administrationRoute; // ORAL_INHALATION, NASAL_INHALATION
  final double dosePerActuation;
  final String doseUnit;
  final int totalActuations;
  final double? totalActiveContent;
  final bool hasDoseCounter;
  final bool hasSpacerIncluded;
  final String storageCondition;
  final bool primingRequired;
  final int primingPuffs;
  final bool canisterPressureWarning;
  final String patientInstructionsEn;
  final String patientInstructionsBn;
  final bool isActive;

  const MobileInhalerRecord({
    required this.configId,
    required this.productId,
    this.tenantId,
    required this.deviceType,
    required this.administrationRoute,
    required this.dosePerActuation,
    required this.doseUnit,
    required this.totalActuations,
    this.totalActiveContent,
    this.hasDoseCounter = true,
    this.hasSpacerIncluded = false,
    required this.storageCondition,
    this.primingRequired = true,
    this.primingPuffs = 2,
    this.canisterPressureWarning = true,
    required this.patientInstructionsEn,
    required this.patientInstructionsBn,
    this.isActive = true,
  });

  factory MobileInhalerRecord.fromJson(Map<String, dynamic> json) {
    return MobileInhalerRecord(
      configId: json['config_id'] as String,
      productId: json['product_id'] as String,
      tenantId: json['tenant_id'] as String?,
      deviceType: json['device_type'] as String? ?? 'MDI_PRESSURIZED',
      administrationRoute: json['administration_route'] as String? ?? 'ORAL_INHALATION',
      dosePerActuation: double.tryParse(json['dose_per_actuation'].toString()) ?? 100.0,
      doseUnit: json['dose_unit'] as String? ?? 'MCG',
      totalActuations: json['total_actuations'] as int? ?? 200,
      totalActiveContent: json['total_active_content'] != null
          ? double.tryParse(json['total_active_content'].toString())
          : null,
      hasDoseCounter: json['has_dose_counter'] as bool? ?? true,
      hasSpacerIncluded: json['has_spacer_included'] as bool? ?? false,
      storageCondition: json['storage_condition'] as String? ?? 'ROOM_15_25',
      primingRequired: json['priming_required'] as bool? ?? true,
      primingPuffs: json['priming_puffs'] as int? ?? 2,
      canisterPressureWarning: json['canister_pressure_warning'] as bool? ?? true,
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
      'device_type': deviceType,
      'administration_route': administrationRoute,
      'dose_per_actuation': dosePerActuation.toStringAsFixed(4),
      'dose_unit': doseUnit,
      'total_actuations': totalActuations,
      'total_active_content': totalActiveContent?.toStringAsFixed(4),
      'has_dose_counter': hasDoseCounter,
      'has_spacer_included': hasSpacerIncluded,
      'storage_condition': storageCondition,
      'priming_required': primingRequired,
      'priming_puffs': primingPuffs,
      'canister_pressure_warning': canisterPressureWarning,
      'patient_instructions_en': patientInstructionsEn,
      'patient_instructions_bn': patientInstructionsBn,
      'is_active': isActive,
    };
  }
}

class MobileInhalerValidationResult {
  final bool isValid;
  final String? errorCode;
  final String messageEn;
  final String messageBn;

  const MobileInhalerValidationResult({
    required this.isValid,
    this.errorCode,
    required this.messageEn,
    required this.messageBn,
  });

  factory MobileInhalerValidationResult.valid() {
    return const MobileInhalerValidationResult(
      isValid: true,
      messageEn: 'Validation passed successfully.',
      messageBn: 'যাচাই সফল হয়েছে।',
    );
  }

  factory MobileInhalerValidationResult.error(String code, String msgEn, String msgBn) {
    return MobileInhalerValidationResult(
      isValid: false,
      errorCode: code,
      messageEn: msgEn,
      messageBn: msgBn,
    );
  }
}

class MobileInhalerEditorClient {
  static const List<String> forbiddenSolidFields = [
    'strips_per_box',
    'tablets_per_strip',
    'units_per_strip',
    'box_size',
    'loose_sale_eligible',
    'is_scored',
    'coating_type',
    'needle_gauge',
  ];

  static const List<String> allowedDeviceTypes = [
    'MDI_PRESSURIZED',
    'DPI_DRY_POWDER',
    'SMI_SOFT_MIST',
    'BREATH_ACTUATED_MDI',
    'NEBULIZER_AMPOULE',
  ];

  static const List<String> allowedRoutes = [
    'ORAL_INHALATION',
    'NASAL_INHALATION',
  ];

  static MobileInhalerValidationResult validateDraftPayload(Map<String, dynamic> payload) {
    if (payload.isEmpty) {
      return MobileInhalerValidationResult.error(
        'ERR_EMPTY_PAYLOAD',
        'Payload cannot be empty.',
        'পে-লোড খালি হতে পারে না।',
      );
    }

    for (final field in forbiddenSolidFields) {
      if (payload.containsKey(field) && payload[field] != null) {
        return MobileInhalerValidationResult.error(
          'ERR_HIDDEN_FIELD_VALUE_REJECTED',
          "Field '$field' is illegal for inhaler dosage form.",
          "ইনহেলার ডোজ ফর্মের জন্য '$field' ফিল্ডটি নিষিদ্ধ।",
        );
      }
    }

    final deviceType = payload['device_type'] as String?;
    if (deviceType == null || !allowedDeviceTypes.contains(deviceType)) {
      return MobileInhalerValidationResult.error(
        'ERR_INVALID_DEVICE_TYPE',
        'Invalid device type.',
        'অবৈধ ইনহেলার ডিভাইস টাইপ।',
      );
    }

    final route = payload['administration_route'] as String?;
    if (route == null || !allowedRoutes.contains(route)) {
      return MobileInhalerValidationResult.error(
        'ERR_INVALID_ADMINISTRATION_ROUTE',
        'Route must be ORAL_INHALATION or NASAL_INHALATION.',
        'অবৈধ ইনহেলার রুট।',
      );
    }

    final rawDose = payload['dose_per_actuation'];
    final dose = rawDose is num ? rawDose.toDouble() : double.tryParse(rawDose?.toString() ?? '');
    if (dose == null || dose <= 0) {
      return MobileInhalerValidationResult.error(
        'ERR_INVALID_DOSE_PER_ACTUATION',
        'dose_per_actuation must be greater than 0.',
        'ডোজ শূন্যের চেয়ে বড় হতে হবে।',
      );
    }

    final rawActuations = payload['total_actuations'];
    final actuations = rawActuations is int ? rawActuations : int.tryParse(rawActuations?.toString() ?? '');
    if (actuations == null || actuations < 10 || actuations > 1000) {
      return MobileInhalerValidationResult.error(
        'ERR_INVALID_ACTUATIONS_COUNT',
        'total_actuations must be between 10 and 1000.',
        'পাফ সংখ্যা ১০ থেকে ১০০০ এর মধ্যে হতে হবে।',
      );
    }

    final rawTotalContent = payload['total_active_content'];
    if (rawTotalContent != null && rawTotalContent.toString().trim().isNotEmpty) {
      final totalContent = rawTotalContent is num
          ? rawTotalContent.toDouble()
          : double.tryParse(rawTotalContent.toString());
      if (totalContent != null) {
        final expected = dose * actuations;
        if ((totalContent - expected).abs() > 0.001) {
          return MobileInhalerValidationResult.error(
            'ERR_DIMENSION_CONSISTENCY_MISMATCH',
            'total_active_content ($totalContent) does not equal dose * actuations ($expected).',
            'মোট ওষুধের পরিমাণ ও পাফের হিসাবের অসঙ্গতি।',
          );
        }
      }
    }

    return MobileInhalerValidationResult.valid();
  }
}

