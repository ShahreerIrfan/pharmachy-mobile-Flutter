/// mobile_flexible_medicine_payload_client.dart
/// Architecture Decision: ADR-0159 (P159).
/// Phase 08: Specialized Item & Multi-Tier Packaging Formulation Editors.
///
/// Mobile client validating typed, versioned dynamic medicine payloads for Flutter.
/// Rejects unknown or incompatible fields with field-level error codes.
library;

class PayloadFieldError {
  final String field;
  final String errorCode;
  final String messageEn;
  final String messageBn;

  PayloadFieldError({
    required this.field,
    required this.errorCode,
    required this.messageEn,
    required this.messageBn,
  });

  Map<String, dynamic> toJson() => {
        'field': field,
        'error_code': errorCode,
        'message_en': messageEn,
        'message_bn': messageBn,
      };
}

class MobilePayloadValidationReport {
  final String schemaVersion;
  final String dosageFormFamily;
  final bool isValid;
  final int errorCount;
  final List<PayloadFieldError> errors;

  MobilePayloadValidationReport({
    required this.schemaVersion,
    required this.dosageFormFamily,
    required this.isValid,
    required this.errors,
  }) : errorCount = errors.length;
}

class MobileFlexibleMedicinePayloadClient {
  static const Set<String> supportedSchemaVersions = {'2026.01', 'v2'};

  static const Set<String> commonAttributes = {
    'brand_name',
    'brand_name_bn',
    'generic_name',
    'generic_name_bn',
    'manufacturer',
    'dar_number',
    'cost_unit',
    'mrp_unit',
    'vat_percentage',
    'is_prescription_only',
    'is_antibiotic',
    'is_narcotic',
    'requires_cold_chain',
    'storage_condition',
    'storage_temperature_celsius_min',
    'storage_temperature_celsius_max',
  };

  static const Set<String> mandatoryCommon = {
    'brand_name',
    'generic_name',
    'dar_number',
    'cost_unit',
    'mrp_unit',
  };

  static const Map<String, Set<String>> formSpecificAttributes = {
    'TABLET_CAPSULE': {
      'pieces_per_strip',
      'strips_per_pack',
      'total_pieces_per_pack',
      'capsule_shell_type',
      'is_delayed_release',
    },
    'INHALER': {
      'dose_per_actuation',
      'actuations_per_device',
      'canister_type',
    },
    'DROPS': {
      'volume_ml',
      'drop_category',
      'is_preservative_free',
    },
    'TOPICAL_CREAM': {
      'tube_size_grams',
      'application_site',
      'vehicle_base',
    },
    'SACHET_POWDER': {
      'grams_per_sachet',
      'sachets_per_pack',
      'reconstitution_guidance',
    },
    'SUPPOSITORY': {
      'piece_count',
      'suppository_base_type',
      'administration_route',
    },
    'DEVICE_CONSUMABLE': {
      'device_type',
      'is_sterile',
      'gauge_size',
    },
    'SYRUP_SUSPENSION': {
      'bottle_size_ml',
      'is_dry_powder',
      'reconstituted_expiry_days',
    },
    'INJECTION_INFUSION': {
      'vial_volume_ml',
      'is_lyophilized',
      'diluent_required',
    },
  };

  static const Map<String, Set<String>> mandatoryFormSpecific = {
    'INHALER': {'dose_per_actuation', 'actuations_per_device'},
    'DROPS': {'volume_ml', 'drop_category'},
    'TOPICAL_CREAM': {'tube_size_grams', 'application_site'},
    'SACHET_POWDER': {'grams_per_sachet', 'sachets_per_pack'},
    'SUPPOSITORY': {'piece_count', 'administration_route'},
    'DEVICE_CONSUMABLE': {'device_type'},
  };

  static final Set<String> allRecognizedFormAttributes =
      formSpecificAttributes.values.expand((element) => element).toSet();

  bool canMutate(String? userRole) {
    if (userRole == null || userRole.trim().isEmpty) return false;
    return userRole.trim().toUpperCase() != 'CASHIER';
  }

  MobilePayloadValidationReport validatePayload({
    required String schemaVersion,
    required String dosageFormFamily,
    required Map<String, dynamic> attributes,
  }) {
    final List<PayloadFieldError> errors = [];

    // 1. Version validation
    if (!supportedSchemaVersions.contains(schemaVersion.trim())) {
      errors.add(PayloadFieldError(
        field: 'schema_version',
        errorCode: 'ERR_PAYLOAD_VERSION_UNSUPPORTED',
        messageEn: "Schema version '$schemaVersion' is unsupported.",
        messageBn: "স্কিমা ভার্সন '$schemaVersion' সমর্থিত নয়।",
      ));
      return MobilePayloadValidationReport(
        schemaVersion: schemaVersion,
        dosageFormFamily: dosageFormFamily,
        isValid: false,
        errors: errors,
      );
    }

    final form = dosageFormFamily.trim().toUpperCase();
    final allowedSpecific = formSpecificAttributes[form] ?? {};

    // 2. Incompatible and Unknown fields check
    for (final key in attributes.keys) {
      if (commonAttributes.contains(key)) continue;
      if (allowedSpecific.contains(key)) continue;

      if (allRecognizedFormAttributes.contains(key)) {
        errors.add(PayloadFieldError(
          field: key,
          errorCode: 'ERR_INCOMPATIBLE_FIELD',
          messageEn: "Field '$key' is incompatible with dosage form family '$form'.",
          messageBn: "'$key' ফিল্ডটি '$form' ডোজ ফর্মের সাথে অসঙ্গতিপূর্ণ।",
        ));
      } else {
        errors.add(PayloadFieldError(
          field: key,
          errorCode: 'ERR_UNKNOWN_FIELD',
          messageEn: "Unknown field '$key' is not permitted in medicine payload schema.",
          messageBn: "অজানা ফিল্ড '$key' অনুমোদিত নয়।",
        ));
      }
    }

    // 3. Mandatory Common Attributes
    for (final mField in mandatoryCommon) {
      final val = attributes[mField];
      if (val == null || val.toString().trim().isEmpty) {
        errors.add(PayloadFieldError(
          field: mField,
          errorCode: 'ERR_MANDATORY_FIELD_MISSING',
          messageEn: "Mandatory attribute '$mField' is missing.",
          messageBn: "বাধ্যতামূলক ফিল্ড '$mField' অনুপস্থিত।",
        ));
      }
    }

    // 4. Mandatory Form Specific Attributes
    final reqSpecific = mandatoryFormSpecific[form] ?? {};
    for (final reqField in reqSpecific) {
      final val = attributes[reqField];
      if (val == null || val.toString().trim().isEmpty) {
        errors.add(PayloadFieldError(
          field: reqField,
          errorCode: 'ERR_MANDATORY_FIELD_MISSING',
          messageEn: "Attribute '$reqField' is mandatory for '$form'.",
          messageBn: "'$form' এর জন্য '$reqField' ফিল্ডটি আবশ্যক।",
        ));
      }
    }

    // 5. Pricing Rules
    final costVal = attributes['cost_unit'];
    final mrpVal = attributes['mrp_unit'];
    num? cost;
    num? mrp;

    if (costVal != null) {
      try {
        cost = num.parse(costVal.toString());
        if (cost < 0) {
          errors.add(PayloadFieldError(
            field: 'cost_unit',
            errorCode: 'ERR_NEGATIVE_COST',
            messageEn: 'Unit cost price cannot be negative.',
            messageBn: 'ক্রয়মূল্য ঋণাত্মক হতে পারে না।',
          ));
        }
      } catch (_) {}
    }

    if (mrpVal != null) {
      try {
        mrp = num.parse(mrpVal.toString());
        if (mrp <= 0) {
          errors.add(PayloadFieldError(
            field: 'mrp_unit',
            errorCode: 'ERR_INVALID_MRP',
            messageEn: 'MRP must be strictly positive.',
            messageBn: 'খুচরা মূল্য অবশ্যই শূন্যের বেশি হতে হবে।',
          ));
        } else if (cost != null && mrp < cost) {
          errors.add(PayloadFieldError(
            field: 'mrp_unit',
            errorCode: 'ERR_MRP_BELOW_COST',
            messageEn: 'MRP ($mrp) cannot be less than purchase cost ($cost).',
            messageBn: 'খুচরা মূল্য ক্রয়মূল্যের চেয়ে কম হতে পারে না।',
          ));
        }
      } catch (_) {}
    }

    // 6. Packaging Math Invariant
    final pObj = attributes['pieces_per_strip'];
    final sObj = attributes['strips_per_pack'];
    final tObj = attributes['total_pieces_per_pack'];
    if (pObj != null && sObj != null && tObj != null) {
      try {
        final p = int.parse(pObj.toString());
        final s = int.parse(sObj.toString());
        final t = int.parse(tObj.toString());
        if (p > 0 && s > 0 && t != (p * s)) {
          errors.add(PayloadFieldError(
            field: 'total_pieces_per_pack',
            errorCode: 'ERR_DIMENSION_MISMATCH',
            messageEn: 'Total pieces ($t) does not equal pieces ($p) * strips ($s) = ${p * s}.',
            messageBn: 'প্যাকের মোট পিস ও স্ট্রিপের হিসাবের গরমিল।',
          ));
        }
      } catch (_) {}
    }

    // 7. Storage Temperature Invariant
    final minTObj = attributes['storage_temperature_celsius_min'];
    final maxTObj = attributes['storage_temperature_celsius_max'];
    if (minTObj != null && maxTObj != null) {
      try {
        final minT = double.parse(minTObj.toString());
        final maxT = double.parse(maxTObj.toString());
        if (minT > maxT) {
          errors.add(PayloadFieldError(
            field: 'storage_temperature_celsius_min',
            errorCode: 'ERR_INVALID_TEMPERATURE_RANGE',
            messageEn: 'Minimum storage temperature cannot exceed maximum storage temperature.',
            messageBn: 'সর্বনিম্ন তাপমাত্রা সর্বোচ্চ তাপমাত্রার চেয়ে বেশি হতে পারে না।',
          ));
        }
      } catch (_) {}
    }

    return MobilePayloadValidationReport(
      schemaVersion: schemaVersion,
      dosageFormFamily: form,
      isValid: errors.isEmpty,
      errors: errors,
    );
  }
}

