import 'package:flutter/foundation.dart';

/// MobileTopicalEditorClient
/// Architecture Decision: ADR-0148 (P148).
/// Phase 08: Milestone M04 / M05 - Specialized Dosage-Form Editors.
///
/// Flutter mobile client for managing Creams, Ointments, Gels, and Lotions,
/// net fill weights in grams, topical routes, and ophthalmic sterility governance.
enum TopicalUiStatus {
  loading,
  success,
  empty,
  error,
  permissionDenied,
  offline,
}

@immutable
class MobileTopicalRecord {
  final String configId;
  final String productId;
  final String? tenantId;
  final String formulationType; // CREAM, OINTMENT, GEL, LOTION, PASTE
  final String administrationRoute; // TOPICAL_CUTANEOUS, TOPICAL_OPHTHALMIC, TOPICAL_RECTAL, TOPICAL_VAGINAL
  final String containerType; // TUBE_ALUMINUM, TUBE_PLASTIC, JAR_POT, BOTTLE_PUMP, SACHET
  final double netWeightGrams;
  final double concentrationValue;
  final String concentrationUnit;
  final bool isSterile;
  final bool applicatorIncluded;
  final int openedShelfLifeDays;
  final String storageCondition;
  final String patientInstructionsEn;
  final String patientInstructionsBn;
  final bool isActive;

  const MobileTopicalRecord({
    required this.configId,
    required this.productId,
    this.tenantId,
    required this.formulationType,
    required this.administrationRoute,
    required this.containerType,
    required this.netWeightGrams,
    required this.concentrationValue,
    required this.concentrationUnit,
    this.isSterile = false,
    this.applicatorIncluded = false,
    this.openedShelfLifeDays = 28,
    required this.storageCondition,
    required this.patientInstructionsEn,
    required this.patientInstructionsBn,
    this.isActive = true,
  });

  factory MobileTopicalRecord.fromJson(Map<String, dynamic> json) {
    return MobileTopicalRecord(
      configId: json['config_id'] as String,
      productId: json['product_id'] as String,
      tenantId: json['tenant_id'] as String?,
      formulationType: json['formulation_type'] as String? ?? 'CREAM',
      administrationRoute: json['administration_route'] as String? ?? 'TOPICAL_CUTANEOUS',
      containerType: json['container_type'] as String? ?? 'TUBE_ALUMINUM',
      netWeightGrams: double.tryParse(json['net_weight_grams'].toString()) ?? 15.0,
      concentrationValue: double.tryParse(json['concentration_value'].toString()) ?? 1.0,
      concentrationUnit: json['concentration_unit'] as String? ?? 'PERCENT_W_W',
      isSterile: json['is_sterile'] as bool? ?? false,
      applicatorIncluded: json['applicator_included'] as bool? ?? false,
      openedShelfLifeDays: json['opened_shelf_life_days'] as int? ?? 28,
      storageCondition: json['storage_condition'] as String? ?? 'ROOM_15_25',
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
      'formulation_type': formulationType,
      'administration_route': administrationRoute,
      'container_type': containerType,
      'net_weight_grams': netWeightGrams.toStringAsFixed(2),
      'concentration_value': concentrationValue.toStringAsFixed(4),
      'concentration_unit': concentrationUnit,
      'is_sterile': isSterile,
      'applicator_included': applicatorIncluded,
      'opened_shelf_life_days': openedShelfLifeDays,
      'storage_condition': storageCondition,
      'patient_instructions_en': patientInstructionsEn,
      'patient_instructions_bn': patientInstructionsBn,
      'is_active': isActive,
    };
  }
}

class MobileTopicalValidationResult {
  final bool isValid;
  final String? errorCode;
  final String messageEn;
  final String messageBn;

  const MobileTopicalValidationResult({
    required this.isValid,
    this.errorCode,
    required this.messageEn,
    required this.messageBn,
  });

  factory MobileTopicalValidationResult.valid() {
    return const MobileTopicalValidationResult(
      isValid: true,
      messageEn: 'Validation passed successfully.',
      messageBn: 'যাচাই সফল হয়েছে।',
    );
  }

  factory MobileTopicalValidationResult.error(String code, String msgEn, String msgBn) {
    return MobileTopicalValidationResult(
      isValid: false,
      errorCode: code,
      messageEn: msgEn,
      messageBn: msgBn,
    );
  }
}

class MobileTopicalEditorClient {
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

  static const List<String> allowedFormulations = [
    'CREAM',
    'OINTMENT',
    'GEL',
    'LOTION',
    'PASTE',
  ];

  static const List<String> allowedRoutes = [
    'TOPICAL_CUTANEOUS',
    'TOPICAL_OPHTHALMIC',
    'TOPICAL_RECTAL',
    'TOPICAL_VAGINAL',
  ];

  static const List<String> allowedContainers = [
    'TUBE_ALUMINUM',
    'TUBE_PLASTIC',
    'JAR_POT',
    'BOTTLE_PUMP',
    'SACHET',
  ];

  static MobileTopicalValidationResult validateDraftPayload(Map<String, dynamic> payload) {
    if (payload.isEmpty) {
      return MobileTopicalValidationResult.error(
        'ERR_EMPTY_PAYLOAD',
        'Payload cannot be empty.',
        'পে-লোড খালি হতে পারে না।',
      );
    }

    for (final field in forbiddenSolidFields) {
      if (payload.containsKey(field) && payload[field] != null) {
        return MobileTopicalValidationResult.error(
          'ERR_HIDDEN_FIELD_VALUE_REJECTED',
          "Field '$field' is illegal for topical dosage form.",
          "টপিকাল ডোজ ফর্মের জন্য '$field' ফিল্ডটি নিষিদ্ধ।",
        );
      }
    }

    final formulation = payload['formulation_type'] as String?;
    if (formulation == null || !allowedFormulations.contains(formulation)) {
      return MobileTopicalValidationResult.error(
        'ERR_INVALID_FORMULATION_TYPE',
        'Invalid formulation type.',
        'অবৈধ ফর্মুলেশন টাইপ।',
      );
    }

    final route = payload['administration_route'] as String?;
    if (route == null || !allowedRoutes.contains(route)) {
      return MobileTopicalValidationResult.error(
        'ERR_INVALID_TOPICAL_ROUTE',
        'Route must be a recognized topical route.',
        'অবৈধ টপিকাল রুট।',
      );
    }

    final container = payload['container_type'] as String?;
    if (container == null || !allowedContainers.contains(container)) {
      return MobileTopicalValidationResult.error(
        'ERR_INVALID_CONTAINER_TYPE',
        'Invalid container type.',
        'অবৈধ কন্টেইনার টাইপ।',
      );
    }

    final rawWeight = payload['net_weight_grams'];
    final weight = rawWeight is num ? rawWeight.toDouble() : double.tryParse(rawWeight?.toString() ?? '');
    if (weight == null || weight <= 0) {
      return MobileTopicalValidationResult.error(
        'ERR_INVALID_NET_WEIGHT',
        'net_weight_grams must be greater than 0.',
        'ওজন শূন্যের চেয়ে বড় হতে হবে।',
      );
    }

    final rawConc = payload['concentration_value'];
    final conc = rawConc is num ? rawConc.toDouble() : double.tryParse(rawConc?.toString() ?? '');
    if (conc == null || conc <= 0) {
      return MobileTopicalValidationResult.error(
        'ERR_INVALID_CONCENTRATION',
        'concentration_value must be greater than 0.',
        'ঘনমাত্রা শূন্যের চেয়ে বড় হতে হবে।',
      );
    }

    final isSterile = payload['is_sterile'] == true;
    if (route == 'TOPICAL_OPHTHALMIC' && !isSterile) {
      return MobileTopicalValidationResult.error(
        'ERR_OPHTHALMIC_STERILITY_MANDATORY',
        'Ophthalmic eye ointments must be certified sterile.',
        'চোখের মলম অবশ্যই জীবাণুমুক্ত হতে হবে।',
      );
    }

    final rawBud = payload['opened_shelf_life_days'];
    final bud = rawBud is int ? rawBud : int.tryParse(rawBud?.toString() ?? '28') ?? 28;
    if (route == 'TOPICAL_OPHTHALMIC' && bud > 28) {
      return MobileTopicalValidationResult.error(
        'ERR_INVALID_OPENED_SHELF_LIFE',
        'Ophthalmic opened shelf life cannot exceed 28 days.',
        'চোখের মলম খোলার মেয়াদ সর্বোচ্চ ২৮ দিন।',
      );
    }
    if (bud < 7 || bud > 180) {
      return MobileTopicalValidationResult.error(
        'ERR_INVALID_OPENED_SHELF_LIFE',
        'opened_shelf_life_days must be between 7 and 180 days.',
        'মেয়াদ ৭ থেকে ১৮০ দিন হতে হবে।',
      );
    }

    return MobileTopicalValidationResult.valid();
  }
}

