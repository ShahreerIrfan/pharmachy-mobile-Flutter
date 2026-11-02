// lib/core/catalog/mobile_dynamic_condition_evaluator.dart
// Architecture Decision: ADR-0125
// Phase 07: Milestone M04 - Shared Medicine Catalog & Dynamic Packaging Units (P125)

enum MobileEvaluationUiStatus {
  success,
  error,
  permissionDenied,
  offline,
}

class MobileEvaluationResult {
  final MobileEvaluationUiStatus uiStatus;
  final bool isValid;
  final String schemaVersion;
  final List<String> activeFields;
  final List<String> hiddenFields;
  final List<String> prunedHiddenFields;
  final Map<String, dynamic> sanitizedPayload;
  final String? errorCode;
  final String messageEn;
  final String messageBn;

  const MobileEvaluationResult({
    required this.uiStatus,
    required this.isValid,
    required this.schemaVersion,
    this.activeFields = const [],
    this.hiddenFields = const [],
    this.prunedHiddenFields = const [],
    this.sanitizedPayload = const {},
    this.errorCode,
    required this.messageEn,
    required this.messageBn,
  });

  factory MobileEvaluationResult.success({
    required String version,
    required List<String> activeFields,
    required List<String> hiddenFields,
    required List<String> prunedFields,
    required Map<String, dynamic> sanitized,
  }) {
    return MobileEvaluationResult(
      uiStatus: MobileEvaluationUiStatus.success,
      isValid: true,
      schemaVersion: version,
      activeFields: activeFields,
      hiddenFields: hiddenFields,
      prunedHiddenFields: prunedFields,
      sanitizedPayload: sanitized,
      messageEn: 'Payload passed dynamic condition evaluation and zero-trust hidden field guard.',
      messageBn: 'পেলোডটি শর্তভিত্তিক মূল্যায়ন এবং হিডেন ফিল্ড সুরক্ষা সফলভাবে উত্তীর্ণ হয়েছে।',
    );
  }

  factory MobileEvaluationResult.error({
    required String code,
    required String msgEn,
    required String msgBn,
    List<String> activeFields = const [],
    List<String> hiddenFields = const [],
  }) {
    return MobileEvaluationResult(
      uiStatus: MobileEvaluationUiStatus.error,
      isValid: false,
      schemaVersion: 'v1.0',
      activeFields: activeFields,
      hiddenFields: hiddenFields,
      errorCode: code,
      messageEn: msgEn,
      messageBn: msgBn,
    );
  }
}

class MobileDynamicConditionEvaluator {
  static const Set<String> allowedDosageForms = {
    'TABLET',
    'CAPSULE',
    'SYRUP',
    'SUSPENSION',
    'INJECTION',
    'EYE_DROPS',
    'OINTMENT',
    'INHALER',
    'SUPPOSITORY',
  };

  MobileEvaluationResult evaluateAndValidate(
    Map<String, dynamic> payload, {
    bool strictHiddenCheck = true,
  }) {
    final dosageForm = (payload['dosage_form'] ?? '').toString().toUpperCase();
    final isColdChain = payload['is_cold_chain'] == true;

    final active = <String>[
      'brand_name',
      'generic_name',
      'dosage_form',
      'manufacturer',
      'strength',
      'strength_numeric',
      'strength_unit',
      'is_strip_applicable',
      'is_cold_chain',
      'is_prescription_required',
      'is_antibiotic',
      'is_narcotic',
    ];
    final hidden = <String>[];

    // Packaging conditions
    if (dosageForm == 'TABLET' || dosageForm == 'CAPSULE') {
      active.addAll(['strips_per_box', 'units_per_strip']);
      hidden.add('volume_ml');
    } else if (dosageForm == 'SYRUP' || dosageForm == 'SUSPENSION' || dosageForm == 'SOLUTION' || dosageForm == 'DROPS') {
      active.add('volume_ml');
      hidden.addAll(['strips_per_box', 'units_per_strip']);
    } else {
      hidden.addAll(['strips_per_box', 'units_per_strip', 'volume_ml']);
    }

    // Cold chain conditions
    if (isColdChain) {
      active.addAll(['min_temperature_celsius', 'max_temperature_celsius']);
    } else {
      hidden.addAll(['min_temperature_celsius', 'max_temperature_celsius']);
    }

    final sanitized = <String, dynamic>{};
    final pruned = <String>[];

    // ZERO-TRUST HIDDEN FIELD GUARD
    for (final hField in hidden) {
      if (payload.containsKey(hField)) {
        final val = payload[hField];
        if (val != null && val.toString().trim().isNotEmpty && val != false) {
          if (strictHiddenCheck) {
            return MobileEvaluationResult.error(
              code: 'ERR_HIDDEN_FIELD_VALUE_REJECTED',
              msgEn: "Field '$hField' is inactive/hidden under $dosageForm conditions and must not contain data.",
              msgBn: "বর্তমান শর্তানুসারে '$hField' ফিল্ডটি প্রযোজ্য নয় এবং এতে কোনো তথ্য রাখা নিষিদ্ধ।",
              activeFields: active,
              hiddenFields: hidden,
            );
          } else {
            pruned.add(hField);
          }
        }
      }
      sanitized[hField] = null;
    }

    // Copy and validate active fields
    for (final aField in active) {
      if (payload.containsKey(aField)) {
        final val = payload[aField];

        // Type safety checks
        if (aField == 'dosage_form') {
          final df = val.toString().toUpperCase();
          if (!allowedDosageForms.contains(df)) {
            return MobileEvaluationResult.error(
              code: 'ERR_INVALID_SELECT_OPTION',
              msgEn: "Dosage form '$df' is not in allowed taxonomy.",
              msgBn: "ডোসেজ ফর্ম '$df' অনুমোদিত নয়।",
              activeFields: active,
              hiddenFields: hidden,
            );
          }
          sanitized[aField] = df;
        } else if (aField == 'strips_per_box' || aField == 'units_per_strip') {
          if (val == null || (val is num && val <= 0)) {
            return MobileEvaluationResult.error(
              code: 'ERR_INVALID_NUMBER_RANGE',
              msgEn: "Field '$aField' must be a positive integer (> 0).",
              msgBn: "'$aField' ফিল্ডটি অবশ্যই ধনাত্মক পূর্ণসংখ্যা হতে হবে।",
              activeFields: active,
              hiddenFields: hidden,
            );
          }
          sanitized[aField] = (val as num).toInt();
        } else if (aField == 'volume_ml') {
          if (val == null || (val is num && val <= 0)) {
            return MobileEvaluationResult.error(
              code: 'ERR_INVALID_DECIMAL',
              msgEn: "Field 'volume_ml' must be a positive decimal (> 0).",
              msgBn: "'volume_ml' ফিল্ডটি অবশ্যই ধনাত্মক দশমিক সংখ্যা হতে হবে।",
              activeFields: active,
              hiddenFields: hidden,
            );
          }
          sanitized[aField] = (val as num).toDouble();
        } else {
          sanitized[aField] = val;
        }
      }
    }

    // Check required base fields
    const requiredBase = ['brand_name', 'generic_name', 'dosage_form', 'manufacturer', 'strength'];
    for (final req in requiredBase) {
      final v = sanitized[req];
      if (v == null || v.toString().trim().isEmpty) {
        return MobileEvaluationResult.error(
          code: 'ERR_CONDITIONAL_FIELD_REQUIRED',
          msgEn: 'Required field missing: $req',
          msgBn: 'আবশ্যক ফিল্ড অনুপস্থিত: $req',
          activeFields: active,
          hiddenFields: hidden,
        );
      }
    }

    // Cold chain range check
    if (sanitized['is_cold_chain'] == true) {
      final minT = sanitized['min_temperature_celsius'];
      final maxT = sanitized['max_temperature_celsius'];
      if (minT == null || maxT == null || minT is! num || maxT is! num) {
        return MobileEvaluationResult.error(
          code: 'ERR_CONDITIONAL_FIELD_REQUIRED',
          msgEn: 'Cold chain storage requires min and max temperature thresholds.',
          msgBn: 'কোল্ড চেইন ঔষধের জন্য সর্বনিম্ন এবং সর্বোচ্চ তাপমাত্রা নির্ধারণ আবশ্যক।',
          activeFields: active,
          hiddenFields: hidden,
        );
      }
      if (minT >= maxT) {
        return MobileEvaluationResult.error(
          code: 'ERR_INVALID_TEMPERATURE_RANGE',
          msgEn: 'Min temperature (${minT}°C) must be strictly less than max temperature (${maxT}°C).',
          msgBn: 'সর্বনিম্ন তাপমাত্রা সর্বোচ্চ তাপমাত্রা অপেক্ষা কম হতে হবে।',
          activeFields: active,
          hiddenFields: hidden,
        );
      }
    }

    // Antibiotic Rx rule
    if (sanitized['is_antibiotic'] == true) {
      sanitized['is_prescription_required'] = true;
    }

    return MobileEvaluationResult.success(
      version: 'v1.0',
      activeFields: active,
      hiddenFields: hidden,
      prunedFields: pruned,
      sanitized: sanitized,
    );
  }
}
