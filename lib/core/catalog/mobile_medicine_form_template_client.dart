// lib/core/catalog/mobile_medicine_form_template_client.dart
// Architecture Decision: ADR-0131
// Phase 07: Milestone M04 - Shared Medicine Catalog & Dynamic Packaging Units (P131)

import 'dart:convert';
import 'dart:typed_data';

enum MobileFormTemplateUiStatus {
  success,
  error,
  permissionDenied,
  empty,
  offline,
}

class MobileFieldWidgetConfig {
  final String fieldKey;
  final String widgetType;
  final int columnSpan;
  final String labelEn;
  final String labelBn;
  final String placeholderEn;
  final String placeholderBn;
  final bool isRequired;
  final bool isReadOnly;
  final dynamic defaultValue;

  const MobileFieldWidgetConfig({
    required this.fieldKey,
    required this.widgetType,
    required this.columnSpan,
    required this.labelEn,
    required this.labelBn,
    this.placeholderEn = '',
    this.placeholderBn = '',
    this.isRequired = false,
    this.isReadOnly = false,
    this.defaultValue,
  });

  factory MobileFieldWidgetConfig.fromJson(Map<String, dynamic> json) {
    return MobileFieldWidgetConfig(
      fieldKey: (json['field_key'] as String?) ?? '',
      widgetType: (json['widget_type'] as String?) ?? 'text_input',
      columnSpan: (json['column_span'] as num?)?.toInt() ?? 6,
      labelEn: (json['label_en'] as String?) ?? '',
      labelBn: (json['label_bn'] as String?) ?? '',
      placeholderEn: (json['placeholder_en'] as String?) ?? '',
      placeholderBn: (json['placeholder_bn'] as String?) ?? '',
      isRequired: (json['is_required'] as bool?) ?? false,
      isReadOnly: (json['is_read_only'] as bool?) ?? false,
      defaultValue: json['default_value'],
    );
  }
}

class MobileLayoutSection {
  final String sectionId;
  final String titleEn;
  final String titleBn;
  final bool collapsible;
  final bool defaultExpanded;
  final int displayOrder;
  final List<MobileFieldWidgetConfig> fields;

  const MobileLayoutSection({
    required this.sectionId,
    required this.titleEn,
    required this.titleBn,
    this.collapsible = false,
    this.defaultExpanded = true,
    required this.displayOrder,
    this.fields = const [],
  });

  factory MobileLayoutSection.fromJson(Map<String, dynamic> json) {
    final rawFields = (json['fields'] as List<dynamic>?) ?? [];
    return MobileLayoutSection(
      sectionId: (json['section_id'] as String?) ?? '',
      titleEn: (json['title_en'] as String?) ?? '',
      titleBn: (json['title_bn'] as String?) ?? '',
      collapsible: (json['collapsible'] as bool?) ?? false,
      defaultExpanded: (json['default_expanded'] as bool?) ?? true,
      displayOrder: (json['display_order'] as num?)?.toInt() ?? 1,
      fields: rawFields.map((f) => MobileFieldWidgetConfig.fromJson(f as Map<String, dynamic>)).toList(),
    );
  }
}

class MobileLayoutRules {
  final int gridColumns;
  final List<MobileLayoutSection> sections;

  const MobileLayoutRules({
    this.gridColumns = 12,
    this.sections = const [],
  });

  factory MobileLayoutRules.fromJson(Map<String, dynamic> json) {
    final rawSections = (json['sections'] as List<dynamic>?) ?? [];
    return MobileLayoutRules(
      gridColumns: (json['grid_columns'] as num?)?.toInt() ?? 12,
      sections: rawSections.map((s) => MobileLayoutSection.fromJson(s as Map<String, dynamic>)).toList(),
    );
  }
}

class MobileAllowedValues {
  final List<String> strengthUnits;
  final List<String> administrationRoutes;
  final List<String> containerTypes;
  final List<String> storageConditions;
  final List<String> dispensingUnits;

  const MobileAllowedValues({
    this.strengthUnits = const [],
    this.administrationRoutes = const [],
    this.containerTypes = const [],
    this.storageConditions = const [],
    this.dispensingUnits = const [],
  });

  factory MobileAllowedValues.fromJson(Map<String, dynamic> json) {
    return MobileAllowedValues(
      strengthUnits: ((json['strength_units'] as List<dynamic>?) ?? []).map((e) => e.toString()).toList(),
      administrationRoutes: ((json['administration_routes'] as List<dynamic>?) ?? []).map((e) => e.toString()).toList(),
      containerTypes: ((json['container_types'] as List<dynamic>?) ?? []).map((e) => e.toString()).toList(),
      storageConditions: ((json['storage_conditions'] as List<dynamic>?) ?? []).map((e) => e.toString()).toList(),
      dispensingUnits: ((json['dispensing_units'] as List<dynamic>?) ?? []).map((e) => e.toString()).toList(),
    );
  }
}

class MobileMedicineFormTemplate {
  final String templateId;
  final String dosageFormCode;
  final String dosageFormNameEn;
  final String dosageFormNameBn;
  final String templateCode;
  final String templateVersion;
  final String titleEn;
  final String titleBn;
  final String description;
  final bool isActive;
  final bool isDefault;
  final MobileLayoutRules layoutRules;
  final MobileAllowedValues allowedValues;
  final String immutableVersionHash;
  final DateTime createdAt;

  const MobileMedicineFormTemplate({
    required this.templateId,
    required this.dosageFormCode,
    required this.dosageFormNameEn,
    required this.dosageFormNameBn,
    required this.templateCode,
    this.templateVersion = 'v1.0',
    required this.titleEn,
    required this.titleBn,
    this.description = '',
    this.isActive = true,
    this.isDefault = true,
    required this.layoutRules,
    required this.allowedValues,
    required this.immutableVersionHash,
    required this.createdAt,
  });

  factory MobileMedicineFormTemplate.fromJson(Map<String, dynamic> json) {
    return MobileMedicineFormTemplate(
      templateId: (json['template_id'] as String?) ?? '',
      dosageFormCode: (json['dosage_form_code'] as String?) ?? '',
      dosageFormNameEn: (json['dosage_form_name_en'] as String?) ?? '',
      dosageFormNameBn: (json['dosage_form_name_bn'] as String?) ?? '',
      templateCode: (json['template_code'] as String?) ?? '',
      templateVersion: (json['template_version'] as String?) ?? 'v1.0',
      titleEn: (json['title_en'] as String?) ?? '',
      titleBn: (json['title_bn'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      isActive: (json['is_active'] as bool?) ?? true,
      isDefault: (json['is_default'] as bool?) ?? true,
      layoutRules: json['layout_rules'] != null
          ? MobileLayoutRules.fromJson(json['layout_rules'] as Map<String, dynamic>)
          : const MobileLayoutRules(),
      allowedValues: json['allowed_values'] != null
          ? MobileAllowedValues.fromJson(json['allowed_values'] as Map<String, dynamic>)
          : const MobileAllowedValues(),
      immutableVersionHash: (json['immutable_version_hash'] as String?) ?? '',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

class MobileFormTemplateResult<T> {
  final MobileFormTemplateUiStatus status;
  final T? data;
  final String? errorCode;
  final String messageEn;
  final String messageBn;

  const MobileFormTemplateResult({
    required this.status,
    this.data,
    this.errorCode,
    required this.messageEn,
    required this.messageBn,
  });

  static MobileFormTemplateResult<T> success<T>(T data) {
    return MobileFormTemplateResult<T>(
      status: MobileFormTemplateUiStatus.success,
      data: data,
      messageEn: 'Operation completed successfully.',
      messageBn: 'অপারেশন সফলভাবে সম্পন্ন হয়েছে।',
    );
  }

  static MobileFormTemplateResult<T> offline<T>(T data) {
    return MobileFormTemplateResult<T>(
      status: MobileFormTemplateUiStatus.offline,
      data: data,
      errorCode: 'STATUS_OFFLINE_CACHE',
      messageEn: 'Served from local offline template cache.',
      messageBn: 'লোকাল অফলাইন টেমপ্লেট ক্যাশ থেকে পরিবেশিত হচ্ছে।',
    );
  }

  static MobileFormTemplateResult<T> permissionDenied<T>(String code, String en, String bn) {
    return MobileFormTemplateResult<T>(
      status: MobileFormTemplateUiStatus.permissionDenied,
      errorCode: code,
      messageEn: en,
      messageBn: bn,
    );
  }

  static MobileFormTemplateResult<T> error<T>(String code, String en, String bn) {
    return MobileFormTemplateResult<T>(
      status: MobileFormTemplateUiStatus.error,
      errorCode: code,
      messageEn: en,
      messageBn: bn,
    );
  }

  static MobileFormTemplateResult<T> empty<T>(String en, String bn) {
    return MobileFormTemplateResult<T>(
      status: MobileFormTemplateUiStatus.empty,
      errorCode: 'ERR_TEMPLATE_NOT_FOUND',
      messageEn: en,
      messageBn: bn,
    );
  }
}

class MobileSha256 {
  static const List<int> _k = [
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
  ];

  static int _rotr(int x, int n) => ((x >> n) | (x << (32 - n))) & 0xFFFFFFFF;
  static int _shr(int x, int n) => (x >> n) & 0xFFFFFFFF;

  static String hashString(String input) {
    final bytes = utf8.encode(input);
    final bitLength = bytes.length * 8;
    final padLength = (((bytes.length + 8) >> 6) + 1) << 6;
    final buffer = Uint8List(padLength);
    buffer.setRange(0, bytes.length, bytes);
    buffer[bytes.length] = 0x80;

    final bd = ByteData.view(buffer.buffer);
    bd.setUint64(padLength - 8, bitLength, Endian.big);

    int h0 = 0x6a09e667, h1 = 0xbb67ae85, h2 = 0x3c6ef372, h3 = 0xa54ff53a;
    int h4 = 0x510e527f, h5 = 0x9b05688c, h6 = 0x1f83d9ab, h7 = 0x5be0cd19;

    final w = List<int>.filled(64, 0);

    for (int i = 0; i < padLength; i += 64) {
      for (int t = 0; t < 16; t++) {
        w[t] = bd.getUint32(i + (t * 4), Endian.big);
      }
      for (int t = 16; t < 64; t++) {
        final s0 = _rotr(w[t - 15], 7) ^ _rotr(w[t - 15], 18) ^ _shr(w[t - 15], 3);
        final s1 = _rotr(w[t - 2], 17) ^ _rotr(w[t - 2], 19) ^ _shr(w[t - 2], 10);
        w[t] = (w[t - 16] + s0 + w[t - 7] + s1) & 0xFFFFFFFF;
      }

      int a = h0, b = h1, c = h2, d = h3, e = h4, f = h5, g = h6, h = h7;

      for (int t = 0; t < 64; t++) {
        final s1 = _rotr(e, 6) ^ _rotr(e, 11) ^ _rotr(e, 25);
        final ch = (e & f) ^ (~e & g);
        final temp1 = (h + s1 + ch + _k[t] + w[t]) & 0xFFFFFFFF;
        final s0 = _rotr(a, 2) ^ _rotr(a, 13) ^ _rotr(a, 22);
        final maj = (a & b) ^ (a & c) ^ (b & c);
        final temp2 = (s0 + maj) & 0xFFFFFFFF;

        h = g;
        g = f;
        f = e;
        e = (d + temp1) & 0xFFFFFFFF;
        d = c;
        c = b;
        b = a;
        a = (temp1 + temp2) & 0xFFFFFFFF;
      }

      h0 = (h0 + a) & 0xFFFFFFFF;
      h1 = (h1 + b) & 0xFFFFFFFF;
      h2 = (h2 + c) & 0xFFFFFFFF;
      h3 = (h3 + d) & 0xFFFFFFFF;
      h4 = (h4 + e) & 0xFFFFFFFF;
      h5 = (h5 + f) & 0xFFFFFFFF;
      h6 = (h6 + g) & 0xFFFFFFFF;
      h7 = (h7 + h) & 0xFFFFFFFF;
    }

    final out = [h0, h1, h2, h3, h4, h5, h6, h7];
    return out.map((v) => v.toRadixString(16).padLeft(8, '0')).join();
  }
}

class MobileMedicineFormTemplateClient {
  final Map<String, MobileMedicineFormTemplate> _templateRegistry = {};
  final Map<String, MobileMedicineFormTemplate> _offlineCache = {};
  bool _isOffline = false;

  MobileMedicineFormTemplateClient() {
    _seedCanonicalTemplates();
  }

  void setOfflineMode(bool offline) {
    _isOffline = offline;
  }

  bool isOfflineMode() => _isOffline;

  static String computeImmutableHash(
    String dosageFormCode,
    String templateCode,
    String templateVersion,
    int gridColumns,
    List<String> strengthUnits,
  ) {
    final raw = '${dosageFormCode.toUpperCase().trim()}|${templateCode.toUpperCase().trim()}|${templateVersion.trim()}|$gridColumns|${strengthUnits.join(',')}';
    return MobileSha256.hashString(raw);
  }

  void _seedCanonicalTemplates() {
    // 1. Tablet
    const tabLayout = MobileLayoutRules(
      gridColumns: 12,
      sections: [
        MobileLayoutSection(
          sectionId: 'identification',
          titleEn: 'Product Identification',
          titleBn: 'ওষুধের প্রাথমিক পরিচিতি',
          displayOrder: 1,
          fields: [
            MobileFieldWidgetConfig(fieldKey: 'brand_name', widgetType: 'text_input', columnSpan: 6, labelEn: 'Brand Name', labelBn: 'ব্র্যান্ডের নাম', isRequired: true),
            MobileFieldWidgetConfig(fieldKey: 'generic_name', widgetType: 'text_input', columnSpan: 6, labelEn: 'Generic Name', labelBn: 'জেনেরিক নাম', isRequired: true),
          ],
        ),
        MobileLayoutSection(
          sectionId: 'packaging_hierarchy',
          titleEn: 'Packaging Unit Conversion',
          titleBn: 'প্যাকেজিং রূপান্তর স্তরবিন্যাস',
          displayOrder: 2,
          fields: [
            MobileFieldWidgetConfig(fieldKey: 'box_size', widgetType: 'number_stepper', columnSpan: 4, labelEn: 'Box Units', labelBn: 'বক্স প্রতি ট্যাবলেট', isRequired: true, defaultValue: 100),
            MobileFieldWidgetConfig(fieldKey: 'strips_per_box', widgetType: 'number_stepper', columnSpan: 4, labelEn: 'Strips Per Box', labelBn: 'বক্স প্রতি পাতা', isRequired: true, defaultValue: 10),
            MobileFieldWidgetConfig(fieldKey: 'units_per_strip', widgetType: 'number_stepper', columnSpan: 4, labelEn: 'Tablets Per Strip', labelBn: 'পাতা প্রতি ট্যাবলেট', isRequired: true, defaultValue: 10),
          ],
        ),
      ],
    );
    const tabAllowed = MobileAllowedValues(
      strengthUnits: ['mg', 'mcg', 'g'],
      administrationRoutes: ['Oral', 'Sublingual', 'Chewable'],
      containerTypes: ['STRIP', 'BLISTER_PACK', 'ALU_ALU', 'BOTTLE'],
      storageConditions: ['ROOM_TEMPERATURE', 'COOL_DRY_PLACE'],
      dispensingUnits: ['Tablet', 'Piece', 'Pcs'],
    );
    final tabHash = computeImmutableHash('TABLET', 'TABLET_STANDARD', 'v1.0', 12, tabAllowed.strengthUnits);
    final tabTemplate = MobileMedicineFormTemplate(
      templateId: 'tmpl-tablet-v1',
      dosageFormCode: 'TABLET',
      dosageFormNameEn: 'Tablet',
      dosageFormNameBn: 'ট্যাবলেট',
      templateCode: 'TABLET_STANDARD',
      templateVersion: 'v1.0',
      titleEn: 'Standard Solid Oral Tablet Form Template',
      titleBn: 'স্ট্যান্ডার্ড সলিড ট্যাবলেট ফরম টেমপ্লেট',
      layoutRules: tabLayout,
      allowedValues: tabAllowed,
      immutableVersionHash: tabHash,
      createdAt: DateTime.now(),
    );
    registerTemplate(tabTemplate);

    // 2. Syrup
    const syrLayout = MobileLayoutRules(
      gridColumns: 12,
      sections: [
        MobileLayoutSection(
          sectionId: 'liquid_volume_spec',
          titleEn: 'Liquid Volume & Concentration',
          titleBn: 'তরল আয়তন ও ঘনমাত্রা',
          displayOrder: 1,
          fields: [
            MobileFieldWidgetConfig(fieldKey: 'volume_ml', widgetType: 'decimal_input', columnSpan: 4, labelEn: 'Bottle Volume (mL)', labelBn: 'বোতলের আয়তন (মি.লি.)', isRequired: true, defaultValue: 100.0),
            MobileFieldWidgetConfig(fieldKey: 'strength_numeric', widgetType: 'decimal_input', columnSpan: 4, labelEn: 'Concentration Value', labelBn: 'ঘনমাত্রার মান', isRequired: true, defaultValue: 120.0),
            MobileFieldWidgetConfig(fieldKey: 'strength_unit', widgetType: 'dropdown_select', columnSpan: 4, labelEn: 'Concentration Unit', labelBn: 'ঘনমাত্রার একক', isRequired: true, defaultValue: 'mg/5mL'),
          ],
        ),
      ],
    );
    const syrAllowed = MobileAllowedValues(
      strengthUnits: ['mg/5mL', 'mcg/5mL', 'g/100mL', '%'],
      administrationRoutes: ['Oral'],
      containerTypes: ['GLASS_BOTTLE', 'PET_BOTTLE', 'DROPS_BOTTLE'],
      storageConditions: ['ROOM_TEMPERATURE', 'SHAKE_WELL_BEFORE_USE'],
      dispensingUnits: ['Bottle', 'Phial'],
    );
    final syrHash = computeImmutableHash('SYRUP', 'SYRUP_LIQUID', 'v1.0', 12, syrAllowed.strengthUnits);
    final syrTemplate = MobileMedicineFormTemplate(
      templateId: 'tmpl-syrup-v1',
      dosageFormCode: 'SYRUP',
      dosageFormNameEn: 'Syrup',
      dosageFormNameBn: 'সিরাপ',
      templateCode: 'SYRUP_LIQUID',
      templateVersion: 'v1.0',
      titleEn: 'Oral Liquid Syrup / Suspension Form Template',
      titleBn: 'ওরাল লিকুইড সিরাপ ও সাসপেনশন ফরম টেমপ্লেট',
      layoutRules: syrLayout,
      allowedValues: syrAllowed,
      immutableVersionHash: syrHash,
      createdAt: DateTime.now(),
    );
    registerTemplate(syrTemplate);

    // 3. Injection
    const injLayout = MobileLayoutRules(
      gridColumns: 12,
      sections: [
        MobileLayoutSection(
          sectionId: 'cold_chain_spec',
          titleEn: 'Cold Chain & Storage Thresholds',
          titleBn: 'কোল্ড চেইন ও তাপমাত্রা নিয়ন্ত্রণ',
          displayOrder: 1,
          fields: [
            MobileFieldWidgetConfig(fieldKey: 'is_cold_chain', widgetType: 'checkbox_toggle', columnSpan: 4, labelEn: 'Cold Chain Required', labelBn: 'কোল্ড চেইন আবশ্যক', isRequired: true, defaultValue: true),
            MobileFieldWidgetConfig(fieldKey: 'min_temperature_celsius', widgetType: 'decimal_input', columnSpan: 4, labelEn: 'Min Temp (°C)', labelBn: 'সর্বনিম্ন তাপমাত্রা (°সে.)', isRequired: true, defaultValue: 2.0),
            MobileFieldWidgetConfig(fieldKey: 'max_temperature_celsius', widgetType: 'decimal_input', columnSpan: 4, labelEn: 'Max Temp (°C)', labelBn: 'সর্বোচ্চ তাপমাত্রা (°সে.)', isRequired: true, defaultValue: 8.0),
          ],
        ),
      ],
    );
    const injAllowed = MobileAllowedValues(
      strengthUnits: ['mg/mL', 'IU/mL', 'mcg/mL', '%'],
      administrationRoutes: ['Intravenous (IV)', 'Intramuscular (IM)', 'Subcutaneous (SC)'],
      containerTypes: ['VIAL', 'AMPOULE', 'PRE_FILLED_SYRINGE'],
      storageConditions: ['COLD_CHAIN_2_8C', 'DEEP_FREEZE', 'ROOM_TEMPERATURE'],
      dispensingUnits: ['Vial', 'Ampoule'],
    );
    final injHash = computeImmutableHash('INJECTION', 'INJECTION_STERILE', 'v1.0', 12, injAllowed.strengthUnits);
    final injTemplate = MobileMedicineFormTemplate(
      templateId: 'tmpl-injection-v1',
      dosageFormCode: 'INJECTION',
      dosageFormNameEn: 'Injection',
      dosageFormNameBn: 'ইনজেকশন',
      templateCode: 'INJECTION_STERILE',
      templateVersion: 'v1.0',
      titleEn: 'Sterile Parenteral Injection Form Template',
      titleBn: 'স্টেরাইল প্যারেন্টেরাল ইনজেকশন ফরম টেমপ্লেট',
      layoutRules: injLayout,
      allowedValues: injAllowed,
      immutableVersionHash: injHash,
      createdAt: DateTime.now(),
    );
    registerTemplate(injTemplate);
  }

  void registerTemplate(MobileMedicineFormTemplate template) {
    _templateRegistry[template.templateId] = template;
    _templateRegistry[template.dosageFormCode.toUpperCase()] = template;
    _templateRegistry[template.templateCode.toUpperCase()] = template;
    _offlineCache[template.dosageFormCode.toUpperCase()] = template;
  }

  MobileFormTemplateResult<MobileMedicineFormTemplate> getTemplate(String identifier) {
    final clean = identifier.trim().toUpperCase();

    if (_isOffline) {
      final cached = _offlineCache[clean];
      if (cached != null) {
        return MobileFormTemplateResult.offline(cached);
      }
      return MobileFormTemplateResult.empty(
        "No cached template available offline for '$identifier'.",
        "অফলাইনে '$identifier'-এর কোনো ক্যাশ টেমপ্লেট পাওয়া যায়নি।",
      );
    }

    final tmpl = _templateRegistry[clean];
    if (tmpl != null) {
      return MobileFormTemplateResult.success(tmpl);
    }

    return MobileFormTemplateResult.empty(
      "No template found for dosage form or template code '$identifier'.",
      "'$identifier'-এর জন্য কোনো ফর্ম টেমপ্লেট পাওয়া যায়নি।",
    );
  }

  MobileFormTemplateResult<MobileAllowedValues> getAllowedValues(String dosageFormCode) {
    final tmplRes = getTemplate(dosageFormCode);
    if (tmplRes.data != null) {
      return MobileFormTemplateResult.success(tmplRes.data!.allowedValues);
    }
    return MobileFormTemplateResult.empty(
      "No allowed values found for dosage form '$dosageFormCode'.",
      "ডোজ-ফর্ম '$dosageFormCode'-এর জন্য কোনো অনুমোদিত মান পাওয়া যায়নি।",
    );
  }

  MobileFormTemplateResult<MobileMedicineFormTemplate> createTemplate({
    required String actorRole,
    required String dosageFormCode,
    required String templateCode,
    String templateVersion = 'v1.0',
    required String titleEn,
    required String titleBn,
    String description = '',
    bool isDefault = false,
    required MobileLayoutRules layoutRules,
    required MobileAllowedValues allowedValues,
  }) {
    final cleanRole = actorRole.trim().toUpperCase();
    if (cleanRole != 'SUPERADMIN' && cleanRole != 'SUPER_ADMIN' && cleanRole != 'PLATFORM_OPERATOR') {
      return MobileFormTemplateResult.permissionDenied(
        'PLATFORM_CATALOG_OWNERSHIP_PROTECTED',
        'Tenant users cannot mutate global dosage-form templates.',
        'টেন্যান্ট ব্যবহারকারীরা গ্লোবাল ডোজ-ফর্ম টেমপ্লেট তৈরি বা পরিবর্তন করতে পারবেন না।',
      );
    }

    if (dosageFormCode.trim().isEmpty) {
      return MobileFormTemplateResult.error('ERR_INVALID_DOSAGE_FORM', 'Dosage form code is required.', 'ডোজ-ফর্ম কোড আবশ্যক।');
    }

    if (templateCode.trim().length < 3) {
      return MobileFormTemplateResult.error('ERR_INVALID_TEMPLATE_CODE', 'Template code must be at least 3 characters.', 'টেমপ্লেট কোড নূন্যতম ৩ অক্ষরের হতে হবে।');
    }

    if (layoutRules.sections.isEmpty) {
      return MobileFormTemplateResult.error('ERR_INVALID_LAYOUT', 'Layout rules must contain at least one section.', 'লেআউট নিয়মে নূন্যতম একটি সেকশন থাকতে হবে।');
    }

    if (allowedValues.strengthUnits.isEmpty) {
      return MobileFormTemplateResult.error('ERR_INVALID_ALLOWED_VALUES', 'Allowed values must contain strength units.', 'অনুমোদিত মানে মাত্রার একক থাকতে হবে।');
    }

    final hash = computeImmutableHash(dosageFormCode, templateCode, templateVersion, layoutRules.gridColumns, allowedValues.strengthUnits);
    final tmpl = MobileMedicineFormTemplate(
      templateId: 'tmpl-${DateTime.now().microsecondsSinceEpoch.toRadixString(16)}',
      dosageFormCode: dosageFormCode.trim().toUpperCase(),
      dosageFormNameEn: dosageFormCode.trim(),
      dosageFormNameBn: dosageFormCode.trim(),
      templateCode: templateCode.trim().toUpperCase(),
      templateVersion: templateVersion.trim(),
      titleEn: titleEn.trim(),
      titleBn: titleBn.trim(),
      description: description.trim(),
      isActive: true,
      isDefault: isDefault,
      layoutRules: layoutRules,
      allowedValues: allowedValues,
      immutableVersionHash: hash,
      createdAt: DateTime.now(),
    );

    registerTemplate(tmpl);
    return MobileFormTemplateResult.success(tmpl);
  }
}
