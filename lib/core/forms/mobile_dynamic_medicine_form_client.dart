/// mobile_dynamic_medicine_form_client.dart
/// Architecture Decision: ADR-0158 (P158).
/// Phase 08: Specialized Item & Multi-Tier Packaging Formulation Editors.
///
/// API Client bridging Flutter Dynamic Forms with Django DRF endpoints.
/// Strictly reuses canonical backend validation rules to prevent duplicated logic.
library;

import 'mobile_dynamic_medicine_form_engine.dart';

class FormValidationResult {
  final bool isValid;
  final int errorCount;
  final List<InlineValidationError> errors;

  FormValidationResult({
    required this.isValid,
    required this.errorCount,
    required this.errors,
  });

  factory FormValidationResult.fromJson(Map<String, dynamic> json) {
    final rawErrors = json['inline_errors'] as List<dynamic>? ?? [];
    final parsed = rawErrors.map((e) {
      final map = e as Map<String, dynamic>;
      return InlineValidationError(
        groupCode: map['group_code']?.toString() ?? '',
        fieldName: map['field_name']?.toString() ?? '',
        errorCode: map['error_code']?.toString() ?? '',
        messageEn: map['message_en']?.toString() ?? '',
        messageBn: map['message_bn']?.toString() ?? '',
        tabIndex: map['tab_index'] as int? ?? 1,
      );
    }).toList();

    return FormValidationResult(
      isValid: json['is_valid'] as bool? ?? false,
      errorCount: json['error_count'] as int? ?? parsed.length,
      errors: parsed,
    );
  }
}

class FormSwitchResult {
  final String previousDosageForm;
  final String newDosageForm;
  final Map<String, dynamic> formValues;
  final Map<String, Map<String, dynamic>> retainedFormCache;
  final int preservedCommonFieldCount;

  FormSwitchResult({
    required this.previousDosageForm,
    required this.newDosageForm,
    required this.formValues,
    required this.retainedFormCache,
    required this.preservedCommonFieldCount,
  });

  factory FormSwitchResult.fromJson(Map<String, dynamic> json) {
    final rawValues = json['form_values'] as Map<String, dynamic>? ?? {};
    final rawCache = json['retained_form_cache'] as Map<String, dynamic>? ?? {};

    final Map<String, Map<String, dynamic>> parsedCache = {};
    rawCache.forEach((key, val) {
      if (val is Map<String, dynamic>) {
        parsedCache[key] = val;
      }
    });

    return FormSwitchResult(
      previousDosageForm: json['previous_dosage_form']?.toString() ?? '',
      newDosageForm: json['new_dosage_form']?.toString() ?? '',
      formValues: rawValues,
      retainedFormCache: parsedCache,
      preservedCommonFieldCount: json['preserved_common_field_count'] as int? ?? 0,
    );
  }
}

class MobileDynamicMedicineFormClient {
  final String baseUrl;
  final MobileDynamicMedicineFormEngine _engine;

  MobileDynamicMedicineFormClient({
    this.baseUrl = 'http://localhost:8000',
    MobileDynamicMedicineFormEngine? engine,
  }) : _engine = engine ?? MobileDynamicMedicineFormEngine();

  bool canMutateForm(String? userRole) {
    if (userRole == null || userRole.trim().isEmpty) return false;
    final normalized = userRole.trim().toUpperCase();
    return normalized != 'CASHIER';
  }

  /// Validates form inputs against the canonical schema and rules.
  /// Uses MobileDynamicMedicineFormEngine to ensure zero duplicated rules.
  Future<FormValidationResult> validateFormData({
    required String authToken,
    required String dosageFormFamily,
    required Map<String, dynamic> formValues,
    bool isOffline = false,
  }) async {
    _engine.initializeForm(dosageFormFamily);
    formValues.forEach((k, v) => _engine.setFieldValue(k, v));
    final errors = _engine.validateFormData();

    return FormValidationResult(
      isValid: errors.isEmpty,
      errorCount: errors.length,
      errors: errors,
    );
  }

  /// Switches dosage form family while preserving common monograph attributes
  /// and restoring cached form-specific parameters.
  Future<FormSwitchResult> switchDosageForm({
    required String authToken,
    required String previousForm,
    required String newForm,
    required Map<String, dynamic> currentValues,
    required Map<String, Map<String, dynamic>> retainedCache,
    bool isOffline = false,
  }) async {
    _engine.initializeForm(previousForm);
    currentValues.forEach((k, v) => _engine.setFieldValue(k, v));
    _engine.switchDosageForm(newForm);

    final commonCount = _engine.currentFormValues.keys
        .where((k) => MobileDynamicMedicineFormEngine.commonMonographFields.contains(k))
        .length;

    return FormSwitchResult(
      previousDosageForm: previousForm,
      newDosageForm: newForm,
      formValues: _engine.currentFormValues,
      retainedFormCache: _engine.retainedFormCache,
      preservedCommonFieldCount: commonCount,
    );
  }
}
