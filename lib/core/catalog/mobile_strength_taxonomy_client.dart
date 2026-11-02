// lib/core/catalog/mobile_strength_taxonomy_client.dart
// Architecture Decision: ADR-0123
// Phase 07: Milestone M04 - Shared Medicine Catalog & Dynamic Packaging Units (P123)

enum MobileStrengthUiStatus {
  loading,
  success,
  empty,
  offline,
  error,
  permissionDenied,
}

enum MobileMeasurementFamily {
  mass,
  volume,
  percentage,
  concentration,
  biological,
}

extension MobileMeasurementFamilyExt on MobileMeasurementFamily {
  String get familyName {
    switch (this) {
      case MobileMeasurementFamily.mass:
        return 'MASS';
      case MobileMeasurementFamily.volume:
        return 'VOLUME';
      case MobileMeasurementFamily.percentage:
        return 'PERCENTAGE';
      case MobileMeasurementFamily.concentration:
        return 'CONCENTRATION';
      case MobileMeasurementFamily.biological:
        return 'BIOLOGICAL';
    }
  }

  String get labelEn {
    switch (this) {
      case MobileMeasurementFamily.mass:
        return 'Mass / Weight';
      case MobileMeasurementFamily.volume:
        return 'Liquid Volume';
      case MobileMeasurementFamily.percentage:
        return 'Percentage Concentration';
      case MobileMeasurementFamily.concentration:
        return 'Dosing Concentration';
      case MobileMeasurementFamily.biological:
        return 'Biological Units';
    }
  }

  String get labelBn {
    switch (this) {
      case MobileMeasurementFamily.mass:
        return 'ওজন / ভর';
      case MobileMeasurementFamily.volume:
        return 'তরল আয়তন';
      case MobileMeasurementFamily.percentage:
        return 'শতাংশ মাত্রা';
      case MobileMeasurementFamily.concentration:
        return 'ডোজের মাত্রা';
      case MobileMeasurementFamily.biological:
        return 'বায়োলজিক্যাল ইউনিট';
    }
  }
}

class MobileUnitDefinition {
  final String unitCode;
  final MobileMeasurementFamily family;
  final double ratioToBase;
  final String nameEn;
  final String nameBn;

  const MobileUnitDefinition({
    required this.unitCode,
    required this.family,
    required this.ratioToBase,
    required this.nameEn,
    required this.nameBn,
  });
}

class MobileParsedStrength {
  final String rawStrength;
  final double numericValue;
  final String unit;
  final MobileMeasurementFamily family;
  final bool isComposite;

  const MobileParsedStrength({
    required this.rawStrength,
    required this.numericValue,
    required this.unit,
    required this.family,
    required this.isComposite,
  });
}

class MobileStrengthConversionResult {
  final MobileStrengthUiStatus uiStatus;
  final double originalValue;
  final String fromUnit;
  final MobileMeasurementFamily? fromFamily;
  final double convertedValue;
  final String toUnit;
  final MobileMeasurementFamily? toFamily;
  final bool isCompatible;
  final String formattedResult;
  final String? errorCode;
  final String messageEn;
  final String messageBn;

  const MobileStrengthConversionResult({
    required this.uiStatus,
    this.originalValue = 0.0,
    this.fromUnit = '',
    this.fromFamily,
    this.convertedValue = 0.0,
    this.toUnit = '',
    this.toFamily,
    this.isCompatible = false,
    this.formattedResult = '',
    this.errorCode,
    required this.messageEn,
    required this.messageBn,
  });

  factory MobileStrengthConversionResult.success({
    required double originalValue,
    required String fromUnit,
    required MobileMeasurementFamily fromFamily,
    required double convertedValue,
    required String toUnit,
    required MobileMeasurementFamily toFamily,
  }) {
    // Format nicely without trailing zeros
    final formattedNum = convertedValue.toStringAsFixed(6).replaceAll(RegExp(r'\.?0+$'), '');
    return MobileStrengthConversionResult(
      uiStatus: MobileStrengthUiStatus.success,
      originalValue: originalValue,
      fromUnit: fromUnit,
      fromFamily: fromFamily,
      convertedValue: convertedValue,
      toUnit: toUnit,
      toFamily: toFamily,
      isCompatible: true,
      formattedResult: '$formattedNum $toUnit',
      messageEn: 'Converted successfully.',
      messageBn: 'সফলভাবে রূপান্তর সম্পন্ন হয়েছে।',
    );
  }

  factory MobileStrengthConversionResult.error({
    required MobileStrengthUiStatus status,
    required String code,
    required String msgEn,
    required String msgBn,
  }) {
    return MobileStrengthConversionResult(
      uiStatus: status,
      errorCode: code,
      messageEn: msgEn,
      messageBn: msgBn,
    );
  }
}

class MobileStrengthTaxonomyClient {
  final String baseUrl;
  final Map<String, MobileUnitDefinition> _registry = {};

  MobileStrengthTaxonomyClient({
    this.baseUrl = 'http://127.0.0.1:8000',
  }) {
    _initDefaultTaxonomy();
  }

  void _initDefaultTaxonomy() {
    // MASS
    _register('mg', MobileMeasurementFamily.mass, 1.0, 'Milligram', 'মিলিগ্রাম');
    _register('g', MobileMeasurementFamily.mass, 1000.0, 'Gram', 'গ্রাম');
    _register('mcg', MobileMeasurementFamily.mass, 0.001, 'Microgram', 'মাইক্রোগ্রাম');
    _register('ug', MobileMeasurementFamily.mass, 0.001, 'Microgram', 'মাইক্রোগ্রাম');

    // VOLUME
    _register('ml', MobileMeasurementFamily.volume, 1.0, 'Milliliter', 'মিলিলিটার');
    _register('l', MobileMeasurementFamily.volume, 1000.0, 'Liter', 'লিটার');

    // PERCENTAGE
    _register('%', MobileMeasurementFamily.percentage, 1.0, 'Percentage', 'শতাংশ মাত্রা');

    // CONCENTRATION
    _register('mg/5ml', MobileMeasurementFamily.concentration, 1.0, 'Milligrams per 5 mL', 'মিলিগ্রাম প্রতি ৫ মিলি');
    _register('mg/ml', MobileMeasurementFamily.concentration, 5.0, 'Milligrams per mL', 'মিলিগ্রাম প্রতি মিলি');
    _register('mcg/ml', MobileMeasurementFamily.concentration, 0.005, 'Micrograms per mL', 'মাইক্রোগ্রাম প্রতি মিলি');

    // BIOLOGICAL
    _register('iu', MobileMeasurementFamily.biological, 1.0, 'International Unit', 'আন্তর্জাতিক ইউনিট');
    _register('iu/ml', MobileMeasurementFamily.biological, 1.0, 'International Units per mL', 'আইইউ প্রতি মিলি');
  }

  void _register(String code, MobileMeasurementFamily family, double ratio, String nameEn, String nameBn) {
    final norm = normalizeUnit(code);
    _registry[norm] = MobileUnitDefinition(
      unitCode: norm,
      family: family,
      ratioToBase: ratio,
      nameEn: nameEn,
      nameBn: nameBn,
    );
  }

  String normalizeUnit(String code) {
    final s = code.trim().toLowerCase();
    if (s == '%' || s == 'percent' || s == 'percentage') {
      return '%';
    }
    return s;
  }

  MobileUnitDefinition? getUnit(String code) {
    return _registry[normalizeUnit(code)];
  }

  MobileMeasurementFamily? getFamily(String code) {
    return getUnit(code)?.family;
  }

  bool isCompatible(String fromUnit, String toUnit) {
    final f1 = getFamily(fromUnit);
    final f2 = getFamily(toUnit);
    if (f1 == null || f2 == null) return false;
    return f1 == f2;
  }

  MobileStrengthConversionResult convertStrength(double value, String fromUnit, String toUnit) {
    final normFrom = normalizeUnit(fromUnit);
    final normTo = normalizeUnit(toUnit);

    final fromDef = getUnit(normFrom);
    final toDef = getUnit(normTo);

    if (fromDef == null) {
      return MobileStrengthConversionResult.error(
        status: MobileStrengthUiStatus.error,
        code: 'ERR_UNKNOWN_STRENGTH_UNIT',
        msgEn: "Source unit '$fromUnit' is not recognized.",
        msgBn: 'উৎস পরিমাপের ইউনিটটি অনুমোদিত নয়।',
      );
    }

    if (toDef == null) {
      return MobileStrengthConversionResult.error(
        status: MobileStrengthUiStatus.error,
        code: 'ERR_UNKNOWN_STRENGTH_UNIT',
        msgEn: "Target unit '$toUnit' is not recognized.",
        msgBn: 'লক্ষ্য পরিমাপের ইউনিটটি অনুমোদিত নয়।',
      );
    }

    // INCOMPATIBLE UNIT CONVERSION GUARD
    if (fromDef.family != toDef.family) {
      return MobileStrengthConversionResult.error(
        status: MobileStrengthUiStatus.error,
        code: 'ERR_INCOMPATIBLE_UNIT_CONVERSION',
        msgEn: "Incompatible unit conversion from '$fromUnit' (${fromDef.family.familyName}) to '$toUnit' (${toDef.family.familyName}). Cross-family conversion is strictly forbidden.",
        msgBn: 'অসঙ্গতিপূর্ণ পরিমাপের ইউনিট রূপান্তর সম্পূর্ণ নিষিদ্ধ।',
      );
    }

    final baseVal = value * fromDef.ratioToBase;
    final targetVal = baseVal / toDef.ratioToBase;

    return MobileStrengthConversionResult.success(
      originalValue: value,
      fromUnit: normFrom,
      fromFamily: fromDef.family,
      convertedValue: targetVal,
      toUnit: normTo,
      toFamily: toDef.family,
    );
  }

  MobileParsedStrength parseStrength(String raw) {
    final cleaned = raw.trim();
    if (cleaned.isEmpty) {
      throw ArgumentError('ERR_INVALID_STRENGTH_STRING: Strength string cannot be empty.');
    }

    final reg = RegExp(r'^\s*([0-9]+(?:\.[0-9]+)?)\s*([a-zA-Z%]+(?:/[0-9]*[a-zA-Z]+)?)\s*$');
    final match = reg.firstMatch(cleaned);

    if (match != null) {
      final numVal = double.parse(match.group(1)!);
      final unit = normalizeUnit(match.group(2)!);
      final fam = getFamily(unit);
      if (fam == null) {
        throw ArgumentError("ERR_UNKNOWN_STRENGTH_UNIT: Unrecognized unit '$unit'.");
      }
      return MobileParsedStrength(
        rawStrength: cleaned,
        numericValue: numVal,
        unit: unit,
        family: fam,
        isComposite: false,
      );
    }

    // Composite fallback (e.g. 500mg+65mg)
    final compReg = RegExp(r'^\s*([0-9]+(?:\.[0-9]+)?)\s*([a-zA-Z%]+)');
    final compMatch = compReg.firstMatch(cleaned);
    if (compMatch != null) {
      final numVal = double.parse(compMatch.group(1)!);
      final unit = normalizeUnit(compMatch.group(2)!);
      final fam = getFamily(unit) ?? MobileMeasurementFamily.mass;
      return MobileParsedStrength(
        rawStrength: cleaned,
        numericValue: numVal,
        unit: unit,
        family: fam,
        isComposite: true,
      );
    }

    throw ArgumentError("ERR_UNPARSEABLE_STRENGTH: Could not parse strength from '$cleaned'.");
  }

  Future<MobileStrengthConversionResult> convertRemote({
    required double value,
    required String fromUnit,
    required String toUnit,
    required String token,
    Future<Map<String, dynamic>> Function(String url, Map<String, dynamic> body)? transport,
  }) async {
    if (transport == null) {
      // Local fallback execution
      return convertStrength(value, fromUnit, toUnit);
    }
    try {
      final data = await transport(
        '$baseUrl/api/v2/medicines/strength-taxonomy/convert/',
        {
          'value': value,
          'from_unit': fromUnit,
          'to_unit': toUnit,
        },
      );
      if (data.containsKey('error_code')) {
        return MobileStrengthConversionResult.error(
          status: MobileStrengthUiStatus.error,
          code: data['error_code'],
          msgEn: data['message_en'] ?? 'Conversion failed.',
          msgBn: data['message_bn'] ?? 'রূপান্তর ব্যর্থ হয়েছে।',
        );
      }
      return MobileStrengthConversionResult.success(
        originalValue: double.parse(data['original_value'].toString()),
        fromUnit: data['from_unit'],
        fromFamily: getFamily(data['from_unit']) ?? MobileMeasurementFamily.mass,
        convertedValue: double.parse(data['converted_value'].toString()),
        toUnit: data['to_unit'],
        toFamily: getFamily(data['to_unit']) ?? MobileMeasurementFamily.mass,
      );
    } catch (e) {
      return MobileStrengthConversionResult.error(
        status: MobileStrengthUiStatus.offline,
        code: 'ERR_OFFLINE_NETWORK',
        msgEn: 'Network unreachable. Client falling back to local taxonomy.',
        msgBn: 'নেটওয়ার্ক সংযোগ নেই। লোকাল ট্যাক্সোনমি ব্যবহার করা হচ্ছে।',
      );
    }
  }
}
