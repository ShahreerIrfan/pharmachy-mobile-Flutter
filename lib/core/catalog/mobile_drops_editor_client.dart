import 'package:flutter/foundation.dart';

/// MobileDropsEditorClient
/// Architecture Decision: ADR-0147 (P147).
/// Phase 08: Milestone M04 / M05 - Specialized Dosage-Form Editors.
///
/// Flutter mobile client for managing Ophthalmic, Otic, and Nasal drops
/// formulations, opened-container beyond-use dates, and sterility rules.
enum DropsUiStatus {
  loading,
  success,
  empty,
  error,
  permissionDenied,
  offline,
}

@immutable
class MobileDropsRecord {
  final String configId;
  final String productId;
  final String? tenantId;
  final String route; // OPHTHALMIC, OTIC, NASAL
  final String containerType; // DROPPER_BOTTLE, SINGLE_DOSE_MINIM, SPRAY_PUMP
  final double volumeMl;
  final double concentrationValue;
  final String concentrationUnit;
  final bool isPreservativeFree;
  final String preservativeName;
  final int openedShelfLifeDays;
  final String storageTemp;
  final String patientInstructionsEn;
  final String patientInstructionsBn;
  final bool isActive;

  const MobileDropsRecord({
    required this.configId,
    required this.productId,
    this.tenantId,
    required this.route,
    required this.containerType,
    required this.volumeMl,
    required this.concentrationValue,
    required this.concentrationUnit,
    this.isPreservativeFree = false,
    this.preservativeName = '',
    this.openedShelfLifeDays = 28,
    required this.storageTemp,
    required this.patientInstructionsEn,
    required this.patientInstructionsBn,
    this.isActive = true,
  });

  factory MobileDropsRecord.fromJson(Map<String, dynamic> json) {
    return MobileDropsRecord(
      configId: json['config_id'] as String,
      productId: json['product_id'] as String,
      tenantId: json['tenant_id'] as String?,
      route: json['route'] as String? ?? 'OPHTHALMIC',
      containerType: json['container_type'] as String? ?? 'DROPPER_BOTTLE',
      volumeMl: double.tryParse(json['volume_ml'].toString()) ?? 5.0,
      concentrationValue: double.tryParse(json['concentration_value'].toString()) ?? 0.5,
      concentrationUnit: json['concentration_unit'] as String? ?? 'PERCENT_W_V',
      isPreservativeFree: json['is_preservative_free'] as bool? ?? false,
      preservativeName: json['preservative_name'] as String? ?? '',
      openedShelfLifeDays: json['opened_shelf_life_days'] as int? ?? 28,
      storageTemp: json['storage_temp'] as String? ?? 'ROOM_15_25',
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
      'route': route,
      'container_type': containerType,
      'volume_ml': volumeMl.toStringAsFixed(2),
      'concentration_value': concentrationValue.toStringAsFixed(4),
      'concentration_unit': concentrationUnit,
      'is_preservative_free': isPreservativeFree,
      'preservative_name': preservativeName,
      'opened_shelf_life_days': openedShelfLifeDays,
      'storage_temp': storageTemp,
      'patient_instructions_en': patientInstructionsEn,
      'patient_instructions_bn': patientInstructionsBn,
      'is_active': isActive,
    };
  }
}

class MobileDropsValidationResult {
  final bool isValid;
  final String? errorCode;
  final String messageEn;
  final String messageBn;

  const MobileDropsValidationResult({
    required this.isValid,
    this.errorCode,
    required this.messageEn,
    required this.messageBn,
  });

  factory MobileDropsValidationResult.valid() {
    return const MobileDropsValidationResult(
      isValid: true,
      messageEn: 'Validation passed successfully.',
      messageBn: 'যাচাই সফল হয়েছে।',
    );
  }

  factory MobileDropsValidationResult.error(String code, String msgEn, String msgBn) {
    return MobileDropsValidationResult(
      isValid: false,
      errorCode: code,
      messageEn: msgEn,
      messageBn: msgBn,
    );
  }
}

class MobileDropsEditorClient {
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

  static MobileDropsValidationResult validateDraftPayload(Map<String, dynamic> payload) {
    if (payload.isEmpty) {
      return MobileDropsValidationResult.error(
        'ERR_EMPTY_PAYLOAD',
        'Payload cannot be empty.',
        'পে-লোড খালি হতে পারে না।',
      );
    }

    for (final field in forbiddenSolidFields) {
      if (payload.containsKey(field) && payload[field] != null) {
        return MobileDropsValidationResult.error(
          'ERR_HIDDEN_FIELD_VALUE_REJECTED',
          "Field '$field' is illegal for liquid drops dosage form.",
          "ড্রপ ডোজ ফর্মের জন্য '$field' ফিল্ডটি নিষিদ্ধ।",
        );
      }
    }

    final route = payload['route'] as String?;
    if (route == null || (route != 'OPHTHALMIC' && route != 'OTIC' && route != 'NASAL')) {
      return MobileDropsValidationResult.error(
        'ERR_INVALID_DROPS_ROUTE',
        'Route must be OPHTHALMIC, OTIC, or NASAL.',
        'অবৈধ ড্রপ রুট।',
      );
    }

    final containerType = payload['container_type'] as String?;
    if (containerType == null || (containerType != 'DROPPER_BOTTLE' && containerType != 'SINGLE_DOSE_MINIM' && containerType != 'SPRAY_PUMP')) {
      return MobileDropsValidationResult.error(
        'ERR_INVALID_CONTAINER_TYPE',
        'Invalid container type.',
        'অবৈধ কন্টেইনার টাইপ।',
      );
    }

    final rawVol = payload['volume_ml'];
    final vol = rawVol is num ? rawVol.toDouble() : double.tryParse(rawVol?.toString() ?? '');
    if (vol == null || vol <= 0) {
      return MobileDropsValidationResult.error(
        'ERR_INVALID_VOLUME',
        'volume_ml must be greater than 0.',
        'ভলিউম শূন্যের চেয়ে বড় হতে হবে।',
      );
    }

    final rawBud = payload['opened_shelf_life_days'];
    final bud = rawBud is int ? rawBud : int.tryParse(rawBud?.toString() ?? '28') ?? 28;
    if (bud < 1 || bud > 60) {
      return MobileDropsValidationResult.error(
        'ERR_INVALID_OPENED_SHELF_LIFE',
        'opened_shelf_life_days must be between 1 and 60 days.',
        'মেয়াদ ১ থেকে ৬০ দিনের মধ্যে হতে হবে।',
      );
    }

    if (containerType == 'SINGLE_DOSE_MINIM' && bud != 1) {
      return MobileDropsValidationResult.error(
        'ERR_SINGLE_DOSE_MINIM_EXPIRY',
        'Single-dose unit minims must have opened_shelf_life_days = 1.',
        'সিঙ্গেল-ডোজ মিনিমের ব্যবহারের মেয়াদ ১ দিন।',
      );
    }

    return MobileDropsValidationResult.valid();
  }
}

