import 'package:flutter/foundation.dart';

/// MobileDynamicFieldGroupLayoutClient
/// Architecture Decision: ADR-0152 (P152).
/// Phase 08: Milestone M04 / M05 - Specialized Item & Consumable Editors.
///
/// Flutter mobile client for dynamic field group rendering,
/// keyboard focus order, bilingual labels, and inline error feedback.
enum LayoutUiStatus {
  loading,
  success,
  empty,
  error,
  permissionDenied,
  offline,
}

@immutable
class MobileFieldDefinition {
  final String fieldName;
  final int tabIndex;
  final String labelEn;
  final String labelBn;
  final String controlType;
  final bool isMandatory;
  final String desktopGridWidth;
  final String keyboardMnemonic;
  final String ariaLabel;

  const MobileFieldDefinition({
    required this.fieldName,
    required this.tabIndex,
    required this.labelEn,
    required this.labelBn,
    required this.controlType,
    this.isMandatory = false,
    this.desktopGridWidth = 'HALF',
    this.keyboardMnemonic = '',
    this.ariaLabel = '',
  });

  factory MobileFieldDefinition.fromJson(Map<String, dynamic> json) {
    return MobileFieldDefinition(
      fieldName: json['field_name'] as String,
      tabIndex: json['tab_index'] as int? ?? 1,
      labelEn: json['label_en'] as String? ?? '',
      labelBn: json['label_bn'] as String? ?? '',
      controlType: json['control_type'] as String? ?? 'TEXT_INPUT',
      isMandatory: json['is_mandatory'] as bool? ?? false,
      desktopGridWidth: json['desktop_grid_width'] as String? ?? 'HALF',
      keyboardMnemonic: json['keyboard_mnemonic'] as String? ?? '',
      ariaLabel: json['aria_label'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'field_name': fieldName,
      'tab_index': tabIndex,
      'label_en': labelEn,
      'label_bn': labelBn,
      'control_type': controlType,
      'is_mandatory': isMandatory,
      'desktop_grid_width': desktopGridWidth,
      'keyboard_mnemonic': keyboardMnemonic,
      'aria_label': ariaLabel,
    };
  }
}

@immutable
class MobileFieldLayoutGroup {
  final String groupCode;
  final int displayOrder;
  final String titleEn;
  final String titleBn;
  final bool isCollapsible;
  final bool defaultCollapsed;
  final String keyboardShortcutMnemonic;
  final String displayDensity;
  final Map<String, dynamic> visibilityCondition;
  final List<MobileFieldDefinition> fields;
  final bool isVisible;

  const MobileFieldLayoutGroup({
    required this.groupCode,
    required this.displayOrder,
    required this.titleEn,
    required this.titleBn,
    this.isCollapsible = true,
    this.defaultCollapsed = false,
    this.keyboardShortcutMnemonic = '',
    this.displayDensity = 'COMFORTABLE',
    this.visibilityCondition = const {},
    this.fields = const [],
    this.isVisible = true,
  });

  factory MobileFieldLayoutGroup.fromJson(Map<String, dynamic> json) {
    final fieldsRaw = json['fields'] as List<dynamic>? ?? [];
    return MobileFieldLayoutGroup(
      groupCode: json['group_code'] as String,
      displayOrder: json['display_order'] as int? ?? 1,
      titleEn: json['title_en'] as String? ?? '',
      titleBn: json['title_bn'] as String? ?? '',
      isCollapsible: json['is_collapsible'] as bool? ?? true,
      defaultCollapsed: json['default_collapsed'] as bool? ?? false,
      keyboardShortcutMnemonic: json['keyboard_shortcut_mnemonic'] as String? ?? '',
      displayDensity: json['display_density'] as String? ?? 'COMFORTABLE',
      visibilityCondition: json['visibility_condition'] as Map<String, dynamic>? ?? const {},
      fields: fieldsRaw.map((f) => MobileFieldDefinition.fromJson(f as Map<String, dynamic>)).toList(),
      isVisible: json['is_visible'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'group_code': groupCode,
      'display_order': displayOrder,
      'title_en': titleEn,
      'title_bn': titleBn,
      'is_collapsible': isCollapsible,
      'default_collapsed': defaultCollapsed,
      'keyboard_shortcut_mnemonic': keyboardShortcutMnemonic,
      'display_density': displayDensity,
      'visibility_condition': visibilityCondition,
      'fields': fields.map((f) => f.toJson()).toList(),
      'is_visible': isVisible,
    };
  }
}

@immutable
class MobileInlineError {
  final String groupCode;
  final String fieldName;
  final String errorCode;
  final String messageEn;
  final String messageBn;
  final int tabIndex;

  const MobileInlineError({
    required this.groupCode,
    required this.fieldName,
    required this.errorCode,
    required this.messageEn,
    required this.messageBn,
    required this.tabIndex,
  });

  Map<String, dynamic> toJson() {
    return {
      'group_code': groupCode,
      'field_name': fieldName,
      'error_code': errorCode,
      'message_en': messageEn,
      'message_bn': messageBn,
      'tab_index': tabIndex,
    };
  }
}

class MobileDynamicFieldGroupLayoutClient {
  /// Evaluates whether a field group is visible given parent form values.
  bool evaluateVisibility(Map<String, dynamic>? condition, Map<String, dynamic>? formValues) {
    if (condition == null || condition.isEmpty) {
      return true;
    }

    final field = condition['field'] as String?;
    final operator = (condition['operator'] as String? ?? 'EQUALS').toUpperCase();
    final expected = condition['value'];

    if (field == null) {
      return true;
    }

    final actual = formValues != null ? formValues[field] : null;
    final actualStr = actual != null ? actual.toString().trim().toUpperCase() : '';

    if (operator == 'EQUALS') {
      if (expected is bool) {
        return (actual == true) == expected;
      }
      return actualStr == (expected != null ? expected.toString().toUpperCase() : '');
    } else if (operator == 'IN') {
      if (expected is List) {
        return expected.any((item) => actualStr == item.toString().toUpperCase());
      }
      return false;
    } else if (operator == 'NOT_EQUALS') {
      return actualStr != (expected != null ? expected.toString().toUpperCase() : '');
    }

    return true;
  }

  /// Linear keyboard focus tab sequence traversal across visible groups.
  List<MobileFieldDefinition> resolveTabSequence(List<MobileFieldLayoutGroup>? groups) {
    if (groups == null || groups.isEmpty) {
      return const [];
    }

    final sortedGroups = groups.where((g) => g.isVisible).toList()
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

    final List<MobileFieldDefinition> allFields = [];
    for (final group in sortedGroups) {
      allFields.addAll(group.fields);
    }
    allFields.sort((a, b) => a.tabIndex.compareTo(b.tabIndex));

    return allFields;
  }

  /// Aggregates inline errors for missing mandatory fields and cross-field constraints.
  List<MobileInlineError> validateFormInputs(
    List<MobileFieldLayoutGroup>? groups,
    Map<String, dynamic>? formValues,
  ) {
    final List<MobileInlineError> errors = [];
    if (groups == null) {
      return errors;
    }

    for (final group in groups) {
      if (!group.isVisible) {
        continue;
      }

      for (final field in group.fields) {
        final val = formValues != null ? formValues[field.fieldName] : null;
        if (field.isMandatory && (val == null || val.toString().trim().isEmpty)) {
          errors.add(MobileInlineError(
            groupCode: group.groupCode,
            fieldName: field.fieldName,
            errorCode: 'ERR_MANDATORY_FIELD_MISSING',
            messageEn: "Field '${field.labelEn}' is mandatory.",
            messageBn: "'${field.labelBn}' ফিল্ডটি পূরণ করা আবশ্যক।",
            tabIndex: field.tabIndex,
          ));
        }
      }
    }

    // Packaging dimensions validation
    if (formValues != null &&
        formValues.containsKey('pieces_per_strip') &&
        formValues.containsKey('strips_per_pack') &&
        formValues.containsKey('total_pieces_per_pack')) {
      final p = int.tryParse(formValues['pieces_per_strip'].toString()) ?? 0;
      final s = int.tryParse(formValues['strips_per_pack'].toString()) ?? 0;
      final t = int.tryParse(formValues['total_pieces_per_pack'].toString()) ?? 0;
      if (p > 0 && s > 0 && t != p * s) {
        errors.add(MobileInlineError(
          groupCode: 'PACKAGING_DIMENSIONS',
          fieldName: 'total_pieces_per_pack',
          errorCode: 'ERR_DIMENSION_MISMATCH',
          messageEn: 'Total pieces ($t) does not equal pieces * strips (${p * s}).',
          messageBn: 'প্যাকের মোট পিস ও স্ট্রিপের হিসাবের গরমিল।',
          tabIndex: 12,
        ));
      }
    }

    // Temperature range validation
    if (formValues != null &&
        formValues.containsKey('storage_temperature_celsius_min') &&
        formValues.containsKey('storage_temperature_celsius_max')) {
      final minTemp = double.tryParse(formValues['storage_temperature_celsius_min'].toString());
      final maxTemp = double.tryParse(formValues['storage_temperature_celsius_max'].toString());
      if (minTemp != null && maxTemp != null && minTemp > maxTemp) {
        errors.add(const MobileInlineError(
          groupCode: 'STORAGE_AND_COLD_CHAIN',
          fieldName: 'storage_temperature_celsius_min',
          errorCode: 'ERR_INVALID_TEMPERATURE_RANGE',
          messageEn: 'Minimum temperature cannot exceed maximum temperature.',
          messageBn: 'সর্বনিম্ন তাপমাত্রা সর্বোচ্চ তাপমাত্রার চেয়ে বেশি হতে পারে না।',
          tabIndex: 22,
        ));
      }
    }

    return errors;
  }
}

