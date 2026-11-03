/// mobile_dynamic_medicine_form_engine.dart
/// Architecture Decision: ADR-0157 (P157).
/// Phase 08: Specialized Item & Multi-Tier Packaging Formulation Editors.
///
/// Mobile dynamic medicine form engine for Flutter.
/// Schema-driven forms, multi-tiered DTO validation, and state preservation
/// across dosage form family switches.
library;

enum MobileUiStatus {
  loading,
  success,
  empty,
  error,
  permissionDenied,
  offline,
}

class InlineValidationError {
  final String groupCode;
  final String fieldName;
  final String errorCode;
  final String messageEn;
  final String messageBn;
  final int tabIndex;

  InlineValidationError({
    required this.groupCode,
    required this.fieldName,
    required this.errorCode,
    required this.messageEn,
    required this.messageBn,
    required this.tabIndex,
  });

  Map<String, dynamic> toJson() => {
        'group_code': groupCode,
        'field_name': fieldName,
        'error_code': errorCode,
        'message_en': messageEn,
        'message_bn': messageBn,
        'tab_index': tabIndex,
      };
}

class FormFieldConfig {
  final String fieldName;
  final String labelEn;
  final String labelBn;
  final String controlType;
  final bool isMandatory;
  final int tabIndex;
  final String desktopGridWidth;
  final String keyboardMnemonic;
  final String ariaLabel;

  FormFieldConfig({
    required this.fieldName,
    required this.labelEn,
    required this.labelBn,
    required this.controlType,
    required this.isMandatory,
    required this.tabIndex,
    this.desktopGridWidth = 'HALF',
    this.keyboardMnemonic = '',
    this.ariaLabel = '',
  });
}

class FormGroupConfig {
  final String groupCode;
  final int displayOrder;
  final String titleEn;
  final String titleBn;
  final bool isCollapsible;
  final bool defaultCollapsed;
  final String keyboardMnemonic;
  final List<FormFieldConfig> fields;

  FormGroupConfig({
    required this.groupCode,
    required this.displayOrder,
    required this.titleEn,
    required this.titleBn,
    required this.isCollapsible,
    required this.defaultCollapsed,
    this.keyboardMnemonic = '',
    required this.fields,
  });
}

class MobileDynamicMedicineFormEngine {
  static const Set<String> commonMonographFields = {
    'brand_name',
    'brand_name_bn',
    'generic_name',
    'generic_name_bn',
    'manufacturer',
    'dar_number',
    'cost_unit',
    'mrp_unit',
    'vat_percentage',
    'prescription_required',
    'is_antibiotic',
    'is_narcotic',
    'requires_cold_chain',
    'storage_condition',
    'storage_temperature_celsius_min',
    'storage_temperature_celsius_max',
    'handling_alert',
  };

  String currentDosageForm;
  final Map<String, dynamic> _currentFormValues = {};
  final Map<String, Map<String, dynamic>> _retainedFormCache = {};
  final List<InlineValidationError> _activeErrors = [];
  MobileUiStatus uiStatus = MobileUiStatus.empty;
  String statusMessage = '';

  MobileDynamicMedicineFormEngine([this.currentDosageForm = 'TABLET_CAPSULE']);

  void initializeForm(String dosageForm) {
    currentDosageForm = dosageForm;
    _currentFormValues.clear();
    _retainedFormCache.clear();
    _activeErrors.clear();
    uiStatus = MobileUiStatus.empty;
    statusMessage = '';
  }

  void switchDosageForm(String newDosageForm) {
    if (newDosageForm.trim().isEmpty || newDosageForm == currentDosageForm) {
      return;
    }

    // 1. Separate common from form-specific fields
    final Map<String, dynamic> commonValues = {};
    final Map<String, dynamic> formSpecificValues = {};

    for (final entry in _currentFormValues.entries) {
      if (commonMonographFields.contains(entry.key)) {
        commonValues[entry.key] = entry.value;
      } else {
        formSpecificValues[entry.key] = entry.value;
      }
    }

    // 2. Cache previous form-specific parameters
    if (currentDosageForm.isNotEmpty) {
      _retainedFormCache[currentDosageForm] = formSpecificValues;
    }

    // 3. Switch active form
    currentDosageForm = newDosageForm;

    // 4. Rebuild active values with preserved common attributes
    _currentFormValues.clear();
    _currentFormValues.addAll(commonValues);

    // 5. Restore cached fields if previously visited
    if (_retainedFormCache.containsKey(newDosageForm)) {
      final cached = _retainedFormCache[newDosageForm];
      if (cached != null) {
        _currentFormValues.addAll(cached);
      }
    }

    _activeErrors.clear();
    uiStatus = MobileUiStatus.empty;
    statusMessage = 'Switched dosage form to $newDosageForm';
  }

  void setFieldValue(String fieldName, dynamic value) {
    if (fieldName.trim().isNotEmpty) {
      if (value == null) {
        _currentFormValues.remove(fieldName);
      } else {
        _currentFormValues[fieldName] = value;
      }
    }
  }

  dynamic getFieldValue(String fieldName) => _currentFormValues[fieldName];

  Map<String, dynamic> get currentFormValues => Map.unmodifiable(_currentFormValues);

  Map<String, Map<String, dynamic>> get retainedFormCache => Map.unmodifiable(_retainedFormCache);

  List<InlineValidationError> get activeErrors => List.unmodifiable(_activeErrors);

  bool canMutateForm(String? userRole) {
    if (userRole == null || userRole.trim().isEmpty) return false;
    final normalized = userRole.trim().toUpperCase();
    return normalized != 'CASHIER';
  }

  List<InlineValidationError> validateFormData() {
    _activeErrors.clear();

    // 1. Mandatory Common Fields
    _checkMandatory('GENERAL_IDENTIFICATION', 'brand_name', 'Brand Name', 'ব্র্যান্ডের নাম', 1);
    _checkMandatory('GENERAL_IDENTIFICATION', 'generic_name', 'Generic Name', 'জেনেরিক নাম', 2);
    _checkMandatory('GENERAL_IDENTIFICATION', 'dar_number', 'DAR Registration No', 'ডিএআর রেজিস্ট্রেশন নম্বর', 4);
    _checkMandatory('FINANCIAL_PRICING', 'cost_unit', 'Unit Cost Price', 'ক্রয়মূল্য', 40);
    _checkMandatory('FINANCIAL_PRICING', 'mrp_unit', 'Maximum Retail Price (MRP)', 'খুচরা বিক্রয়মূল্য', 41);

    // 2. Pricing Validations
    final costVal = _currentFormValues['cost_unit'];
    final mrpVal = _currentFormValues['mrp_unit'];

    num? cost;
    num? mrp;

    if (costVal != null) {
      try {
        cost = num.parse(costVal.toString());
        if (cost < 0) {
          _activeErrors.add(InlineValidationError(
            groupCode: 'FINANCIAL_PRICING',
            fieldName: 'cost_unit',
            errorCode: 'ERR_NEGATIVE_COST',
            messageEn: 'Unit cost price cannot be negative.',
            messageBn: 'ক্রয়মূল্য ঋণাত্মক হতে পারে না।',
            tabIndex: 40,
          ));
        }
      } catch (_) {}
    }

    if (mrpVal != null) {
      try {
        mrp = num.parse(mrpVal.toString());
        if (mrp <= 0) {
          _activeErrors.add(InlineValidationError(
            groupCode: 'FINANCIAL_PRICING',
            fieldName: 'mrp_unit',
            errorCode: 'ERR_INVALID_MRP',
            messageEn: 'MRP must be greater than zero.',
            messageBn: 'খুচরা বিক্রয়মূল্য অবশ্যই শূন্যের বেশি হতে হবে।',
            tabIndex: 41,
          ));
        } else if (cost != null && mrp < cost) {
          _activeErrors.add(InlineValidationError(
            groupCode: 'FINANCIAL_PRICING',
            fieldName: 'mrp_unit',
            errorCode: 'ERR_MRP_BELOW_COST',
            messageEn: 'MRP ($mrp) cannot be less than purchase cost ($cost).',
            messageBn: 'খুচরা বিক্রয়মূল্য ($mrp) ক্রয়মূল্যের ($cost) চেয়ে কম হতে পারে না।',
            tabIndex: 41,
          ));
        }
      } catch (_) {}
    }

    // 3. Packaging Dimension Multipliers
    final pieces = _currentFormValues['pieces_per_strip'];
    final strips = _currentFormValues['strips_per_pack'];
    final total = _currentFormValues['total_pieces_per_pack'];
    if (pieces != null && strips != null && total != null) {
      try {
        final p = int.parse(pieces.toString());
        final s = int.parse(strips.toString());
        final t = int.parse(total.toString());
        if (p > 0 && s > 0 && t != (p * s)) {
          _activeErrors.add(InlineValidationError(
            groupCode: 'PACKAGING_DIMENSIONS',
            fieldName: 'total_pieces_per_pack',
            errorCode: 'ERR_DIMENSION_MISMATCH',
            messageEn: 'Total pieces ($t) does not equal pieces * strips (${p * s}).',
            messageBn: 'প্যাকের মোট পিস ও স্ট্রিপের হিসাবের গরমিল।',
            tabIndex: 12,
          ));
        }
      } catch (_) {}
    }

    // 4. Storage Temperature Ordering
    final minT = _currentFormValues['storage_temperature_celsius_min'];
    final maxT = _currentFormValues['storage_temperature_celsius_max'];
    if (minT != null && maxT != null) {
      try {
        final minVal = num.parse(minT.toString());
        final maxVal = num.parse(maxT.toString());
        if (minVal > maxVal) {
          _activeErrors.add(InlineValidationError(
            groupCode: 'STORAGE_AND_COLD_CHAIN',
            fieldName: 'storage_temperature_celsius_min',
            errorCode: 'ERR_INVALID_TEMPERATURE_RANGE',
            messageEn: 'Minimum temperature cannot exceed maximum temperature.',
            messageBn: 'সর্বনিম্ন তাপমাত্রা সর্বোচ্চ তাপমাত্রার চেয়ে বেশি হতে পারে না।',
            tabIndex: 22,
          ));
        }
      } catch (_) {}
    }

    // 5. Formulation Specific Checks
    _validateFormSpecific();

    return List.unmodifiable(_activeErrors);
  }

  void _checkMandatory(String groupCode, String fieldName, String labelEn, String labelBn, int tabIndex) {
    final val = _currentFormValues[fieldName];
    if (val == null || val.toString().trim().isEmpty) {
      _activeErrors.add(InlineValidationError(
        groupCode: groupCode,
        fieldName: fieldName,
        errorCode: 'ERR_MANDATORY_FIELD_MISSING',
        messageEn: "Field '$labelEn' is mandatory.",
        messageBn: "'$labelBn' ফিল্ডটি পূরণ করা আবশ্যক।",
        tabIndex: tabIndex,
      ));
    }
  }

  void _validateFormSpecific() {
    final form = currentDosageForm.toUpperCase();
    if (form == 'INHALER') {
      _checkMandatory('FORM_SPECIFIC_PARAMETERS', 'dose_per_actuation', 'Dose per Actuation', 'প্রতি পাফে মাত্রা', 5);
      _checkMandatory('FORM_SPECIFIC_PARAMETERS', 'actuations_per_device', 'Actuations per Inhaler', 'মোট পাফ সংখ্যা', 6);
    } else if (form == 'DROPS') {
      _checkMandatory('FORM_SPECIFIC_PARAMETERS', 'volume_ml', 'Volume (mL)', 'বোতলের আয়তন (মিলি)', 5);
      _checkMandatory('FORM_SPECIFIC_PARAMETERS', 'drop_category', 'Drop Category', 'ড্রপের ধরণ', 6);
    } else if (form == 'TOPICAL_CREAM') {
      _checkMandatory('FORM_SPECIFIC_PARAMETERS', 'tube_size_grams', 'Tube Size (g)', 'টিউবের ওজন (গ্রাম)', 5);
      _checkMandatory('FORM_SPECIFIC_PARAMETERS', 'application_site', 'Application Site', 'ব্যবহারের স্থান', 6);
    } else if (form == 'SACHET_POWDER') {
      _checkMandatory('FORM_SPECIFIC_PARAMETERS', 'grams_per_sachet', 'Weight per Sachet (g)', 'প্রতি স্যাশের ওজন (গ্রাম)', 5);
      _checkMandatory('FORM_SPECIFIC_PARAMETERS', 'sachets_per_pack', 'Sachets per Pack', 'প্যাকে স্যাশের সংখ্যা', 6);
    } else if (form == 'SUPPOSITORY') {
      _checkMandatory('FORM_SPECIFIC_PARAMETERS', 'piece_count', 'Piece Count', 'পিস সংখ্যা', 5);
      _checkMandatory('FORM_SPECIFIC_PARAMETERS', 'administration_route', 'Administration Route', 'প্রয়োগ রুট', 6);
    } else if (form == 'DEVICE_CONSUMABLE') {
      _checkMandatory('FORM_SPECIFIC_PARAMETERS', 'device_type', 'Device Type', 'ডিভাইসের ধরণ', 5);
    }
  }

  bool submitForm(String? userRole) {
    if (!canMutateForm(userRole)) {
      uiStatus = MobileUiStatus.permissionDenied;
      statusMessage = 'Cashier role has read-only access to master catalog definitions.';
      return false;
    }

    validateFormData();

    if (_activeErrors.isNotEmpty) {
      uiStatus = MobileUiStatus.error;
      statusMessage = 'Validation failed with ${_activeErrors.length} errors.';
      return false;
    }

    uiStatus = MobileUiStatus.success;
    statusMessage = 'Form successfully validated and submitted.';
    return true;
  }
}
