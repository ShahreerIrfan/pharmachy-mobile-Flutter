// lib/core/catalog/mobile_medicine_editor_schema_client.dart
// Architecture Decision: ADR-0124
// Phase 07: Milestone M04 - Shared Medicine Catalog & Dynamic Packaging Units (P124)

enum MobileEditorUiStatus {
  loading,
  success,
  empty,
  offline,
  error,
  permissionDenied,
}

class MobileSchemaField {
  final String fieldId;
  final String labelEn;
  final String labelBn;
  final String fieldType;
  final bool isRequired;
  final dynamic defaultValue;

  const MobileSchemaField({
    required this.fieldId,
    required this.labelEn,
    required this.labelBn,
    required this.fieldType,
    this.isRequired = false,
    this.defaultValue,
  });
}

class MobileSchemaSection {
  final String sectionId;
  final String titleEn;
  final String titleBn;
  final int displayOrder;
  final List<MobileSchemaField> fields;

  const MobileSchemaSection({
    required this.sectionId,
    required this.titleEn,
    required this.titleBn,
    required this.displayOrder,
    this.fields = const [],
  });
}

class MobileMedicineEditorSchema {
  final String schemaId;
  final String schemaVersion;
  final String titleEn;
  final String titleBn;
  final bool isActive;
  final List<MobileSchemaSection> sections;

  const MobileMedicineEditorSchema({
    required this.schemaId,
    required this.schemaVersion,
    required this.titleEn,
    required this.titleBn,
    this.isActive = true,
    this.sections = const [],
  });
}

class MobileValidationResult {
  final MobileEditorUiStatus uiStatus;
  final bool isValid;
  final String schemaVersion;
  final String? errorCode;
  final String messageEn;
  final String messageBn;
  final List<String> missingFields;

  const MobileValidationResult({
    required this.uiStatus,
    required this.isValid,
    required this.schemaVersion,
    this.errorCode,
    required this.messageEn,
    required this.messageBn,
    this.missingFields = const [],
  });

  factory MobileValidationResult.success(String version) {
    return MobileValidationResult(
      uiStatus: MobileEditorUiStatus.success,
      isValid: true,
      schemaVersion: version,
      messageEn: 'Form validation passed.',
      messageBn: 'ফর্মের তথ্য ভ্যালিডেশন সফল হয়েছে।',
    );
  }

  factory MobileValidationResult.error({
    required MobileEditorUiStatus status,
    required String code,
    required String msgEn,
    required String msgBn,
    List<String> missingFields = const [],
  }) {
    return MobileValidationResult(
      uiStatus: status,
      isValid: false,
      schemaVersion: 'v1.0',
      errorCode: code,
      messageEn: msgEn,
      messageBn: msgBn,
      missingFields: missingFields,
    );
  }
}

class MobileMedicineEditorSchemaClient {
  late final MobileMedicineEditorSchema activeSchema;

  MobileMedicineEditorSchemaClient() {
    _initDefaultSchema();
  }

  void _initDefaultSchema() {
    activeSchema = const MobileMedicineEditorSchema(
      schemaId: 'med-schema-v1.0',
      schemaVersion: 'v1.0',
      titleEn: 'Standard Medicine Master Editor',
      titleBn: 'স্ট্যান্ডার্ড ঔষধ বিবরণী ও মাস্টার ফর্ম',
      isActive: true,
      sections: [
        MobileSchemaSection(
          sectionId: 'basic_info',
          titleEn: 'Basic Information',
          titleBn: 'প্রাথমিক তথ্য',
          displayOrder: 1,
          fields: [
            MobileSchemaField(fieldId: 'brand_name', labelEn: 'Brand Name', labelBn: 'ব্র্যান্ড নাম', fieldType: 'text', isRequired: true),
            MobileSchemaField(fieldId: 'generic_name', labelEn: 'Generic Name', labelBn: 'জেনেরিক নাম', fieldType: 'text', isRequired: true),
            MobileSchemaField(fieldId: 'dosage_form', labelEn: 'Dosage Form', labelBn: 'ডোসেজ ফরম', fieldType: 'select', isRequired: true, defaultValue: 'TABLET'),
            MobileSchemaField(fieldId: 'manufacturer', labelEn: 'Manufacturer', labelBn: 'উত্পাদক প্রতিষ্ঠান', fieldType: 'text', isRequired: true),
          ],
        ),
        MobileSchemaSection(
          sectionId: 'strength_spec',
          titleEn: 'Dosage Strength',
          titleBn: 'মাত্রার বিবরণ',
          displayOrder: 2,
          fields: [
            MobileSchemaField(fieldId: 'strength', labelEn: 'Strength String', labelBn: 'মাত্রার সংকেত', fieldType: 'text', isRequired: true),
            MobileSchemaField(fieldId: 'strength_numeric', labelEn: 'Numeric Strength', labelBn: 'সংখ্যার মান', fieldType: 'decimal', isRequired: true, defaultValue: 500.0),
            MobileSchemaField(fieldId: 'strength_unit', labelEn: 'Measurement Unit', labelBn: 'পরিমাপের একক', fieldType: 'select', isRequired: true, defaultValue: 'mg'),
          ],
        ),
        MobileSchemaSection(
          sectionId: 'packaging_config',
          titleEn: 'Packaging & Conversion',
          titleBn: 'প্যাকেজিং ও রূপান্তর',
          displayOrder: 3,
          fields: [
            MobileSchemaField(fieldId: 'is_strip_applicable', labelEn: 'Strip Packaging', labelBn: 'পাতা প্রযোজ্য', fieldType: 'boolean', defaultValue: true),
            MobileSchemaField(fieldId: 'strips_per_box', labelEn: 'Strips Per Box', labelBn: 'প্রতি বাক্সে পাতা', fieldType: 'number', defaultValue: 10),
            MobileSchemaField(fieldId: 'units_per_strip', labelEn: 'Units Per Strip', labelBn: 'প্রতি পাতায় ট্যাবলেট', fieldType: 'number', defaultValue: 10),
            MobileSchemaField(fieldId: 'volume_ml', labelEn: 'Volume (mL)', labelBn: 'আয়তন (মিলি)', fieldType: 'decimal'),
          ],
        ),
        MobileSchemaSection(
          sectionId: 'cold_chain_spec',
          titleEn: 'Cold Chain & Storage',
          titleBn: 'কোল্ড চেইন ও সংরক্ষণ',
          displayOrder: 4,
          fields: [
            MobileSchemaField(fieldId: 'is_cold_chain', labelEn: 'Cold Chain Storage', labelBn: 'কোল্ড চেইন প্রযোজ্য', fieldType: 'boolean', defaultValue: false),
            MobileSchemaField(fieldId: 'min_temperature_celsius', labelEn: 'Min Temp (°C)', labelBn: 'সর্বনিম্ন তাপমাত্রা', fieldType: 'decimal', defaultValue: 2.0),
            MobileSchemaField(fieldId: 'max_temperature_celsius', labelEn: 'Max Temp (°C)', labelBn: 'সর্বোচ্চ তাপমাত্রা', fieldType: 'decimal', defaultValue: 8.0),
          ],
        ),
      ],
    );
  }

  bool isFieldVisible(String fieldId, Map<String, dynamic> formValues) {
    final dosageForm = (formValues['dosage_form'] ?? '').toString().toUpperCase();
    final isColdChain = formValues['is_cold_chain'] == true;

    switch (fieldId) {
      case 'strips_per_box':
      case 'units_per_strip':
        return dosageForm == 'TABLET' || dosageForm == 'CAPSULE';
      case 'volume_ml':
        return dosageForm == 'SYRUP' || dosageForm == 'SUSPENSION' || dosageForm == 'SOLUTION' || dosageForm == 'DROPS';
      case 'min_temperature_celsius':
      case 'max_temperature_celsius':
        return isColdChain;
      default:
        return true;
    }
  }

  bool isFieldRequired(String fieldId, Map<String, dynamic> formValues) {
    final dosageForm = (formValues['dosage_form'] ?? '').toString().toUpperCase();
    final isColdChain = formValues['is_cold_chain'] == true;

    switch (fieldId) {
      case 'brand_name':
      case 'generic_name':
      case 'dosage_form':
      case 'manufacturer':
      case 'strength':
        return true;
      case 'strips_per_box':
      case 'units_per_strip':
        return dosageForm == 'TABLET' || dosageForm == 'CAPSULE';
      case 'volume_ml':
        return dosageForm == 'SYRUP' || dosageForm == 'SUSPENSION' || dosageForm == 'SOLUTION' || dosageForm == 'DROPS';
      case 'min_temperature_celsius':
      case 'max_temperature_celsius':
        return isColdChain;
      default:
        return false;
    }
  }

  MobileValidationResult validateForm(Map<String, dynamic> formValues) {
    final missing = <String>[];
    const baseRequired = ['brand_name', 'generic_name', 'dosage_form', 'manufacturer', 'strength'];

    for (final field in baseRequired) {
      final val = formValues[field];
      if (val == null || val.toString().trim().isEmpty) {
        missing.add(field);
      }
    }

    if (missing.isNotEmpty) {
      return MobileValidationResult.error(
        status: MobileEditorUiStatus.error,
        code: 'ERR_SCHEMA_VALIDATION_FAILED',
        msgEn: 'Required fields missing: ${missing.join(", ")}',
        msgBn: 'আবশ্যকীয় ফিল্ডসমূহ পূরণ করুন।',
        missingFields: missing,
      );
    }

    final dosageForm = (formValues['dosage_form'] ?? '').toString().toUpperCase();

    // Strip packaging validation
    if (dosageForm == 'TABLET' || dosageForm == 'CAPSULE') {
      final strips = formValues['strips_per_box'];
      final units = formValues['units_per_strip'];
      if (strips == null || (strips is num && strips <= 0)) {
        return MobileValidationResult.error(
          status: MobileEditorUiStatus.error,
          code: 'ERR_CONDITIONAL_FIELD_REQUIRED',
          msgEn: 'Strips per box is required for $dosageForm and must be > 0.',
          msgBn: 'প্রতি বাক্সে পাতা/স্ট্রিপ সংখ্যা আবশ্যক।',
          missingFields: ['strips_per_box'],
        );
      }
      if (units == null || (units is num && units <= 0)) {
        return MobileValidationResult.error(
          status: MobileEditorUiStatus.error,
          code: 'ERR_CONDITIONAL_FIELD_REQUIRED',
          msgEn: 'Units per strip is required for $dosageForm and must be > 0.',
          msgBn: 'প্রতি পাতায় ট্যাবলেটের সংখ্যা আবশ্যক।',
          missingFields: ['units_per_strip'],
        );
      }
    }

    // Liquid volume validation
    if (dosageForm == 'SYRUP' || dosageForm == 'SUSPENSION') {
      final vol = formValues['volume_ml'];
      if (vol == null || (vol is num && vol <= 0)) {
        return MobileValidationResult.error(
          status: MobileEditorUiStatus.error,
          code: 'ERR_CONDITIONAL_FIELD_REQUIRED',
          msgEn: 'Volume in mL is required for $dosageForm and must be > 0.',
          msgBn: 'মোট আয়তন (মিলি) প্রদান আবশ্যক।',
          missingFields: ['volume_ml'],
        );
      }
    }

    // Cold chain validation
    if (formValues['is_cold_chain'] == true) {
      final minT = formValues['min_temperature_celsius'];
      final maxT = formValues['max_temperature_celsius'];
      if (minT == null || maxT == null || minT is! num || maxT is! num) {
        return MobileValidationResult.error(
          status: MobileEditorUiStatus.error,
          code: 'ERR_CONDITIONAL_FIELD_REQUIRED',
          msgEn: 'Cold chain storage requires min and max temperature thresholds.',
          msgBn: 'সর্বনিম্ন ও সর্বোচ্চ তাপমাত্রা আবশ্যক।',
          missingFields: ['min_temperature_celsius', 'max_temperature_celsius'],
        );
      }
      if (minT >= maxT) {
        return MobileValidationResult.error(
          status: MobileEditorUiStatus.error,
          code: 'ERR_INVALID_TEMPERATURE_RANGE',
          msgEn: 'Min temperature (${minT}°C) must be strictly less than max temperature (${maxT}°C).',
          msgBn: 'সর্বনিম্ন তাপমাত্রা সর্বোচ্চ তাপমাত্রা অপেক্ষা কম হতে হবে।',
          missingFields: ['min_temperature_celsius', 'max_temperature_celsius'],
        );
      }
    }

    return MobileValidationResult.success(activeSchema.schemaVersion);
  }

  MobileValidationResult attemptPublishSchema({
    required String callerRole,
    required String version,
  }) {
    final role = callerRole.toUpperCase();
    if (role != 'SUPERADMIN' && role != 'PLATFORM_OPERATOR') {
      return MobileValidationResult.error(
        status: MobileEditorUiStatus.permissionDenied,
        code: 'PLATFORM_CATALOG_OWNERSHIP_PROTECTED',
        msgEn: 'Medicine editor schemas are centrally curated by platform administrators.',
        msgBn: 'ঔষধ বিবরণী স্কিমা কেন্দ্রীয়ভাবে প্ল্যাটফর্ম অ্যাডমিনিস্ট্রেটর দ্বারা পরিচালিত।',
      );
    }
    return MobileValidationResult.success(version);
  }
}
