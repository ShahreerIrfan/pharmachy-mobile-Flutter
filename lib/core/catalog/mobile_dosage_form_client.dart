// lib/core/catalog/mobile_dosage_form_client.dart
// Architecture Decision: ADR-0122
// Phase 07: Milestone M04 - Shared Medicine Catalog & Dynamic Packaging Units (P122)

enum MobileDosageFormUiStatus {
  loading,
  success,
  empty,
  offline,
  error,
  permissionDenied,
}

class MobileDosageFormRecord {
  final String formId;
  final String formCode;
  final String nameEn;
  final String nameBn;
  final String category;
  final String defaultRoute;
  final booleanIsStripApplicable;
  final bool isVolumeApplicable;
  final bool isColdChainApplicable;
  final int displayOrder;
  final bool isActive;
  final List<dynamic> fieldGroups;

  const MobileDosageFormRecord({
    required this.formId,
    required this.formCode,
    required this.nameEn,
    required this.nameBn,
    required this.category,
    required this.defaultRoute,
    this.booleanIsStripApplicable = true,
    this.isVolumeApplicable = false,
    this.isColdChainApplicable = false,
    this.displayOrder = 10,
    this.isActive = true,
    this.fieldGroups = const [],
  });

  bool get isStripApplicable => booleanIsStripApplicable;

  factory MobileDosageFormRecord.fromJson(Map<String, dynamic> json) {
    return MobileDosageFormRecord(
      formId: json['form_id'] ?? '',
      formCode: json['form_code'] ?? '',
      nameEn: json['name_en'] ?? '',
      nameBn: json['name_bn'] ?? '',
      category: json['category'] ?? 'SOLID',
      defaultRoute: json['default_route'] ?? 'Oral',
      booleanIsStripApplicable: json['is_strip_applicable'] ?? false,
      isVolumeApplicable: json['is_volume_applicable'] ?? false,
      isColdChainApplicable: json['is_cold_chain_applicable'] ?? false,
      displayOrder: json['display_order'] ?? 10,
      isActive: json['is_active'] ?? true,
      fieldGroups: json['field_groups'] is List ? json['field_groups'] : [],
    );
  }
}

class MobileDosageFormResult {
  final MobileDosageFormUiStatus uiStatus;
  final List<MobileDosageFormRecord> forms;
  final String? errorCode;
  final String messageEn;
  final String messageBn;

  const MobileDosageFormResult({
    required this.uiStatus,
    this.forms = const [],
    this.errorCode,
    required this.messageEn,
    required this.messageBn,
  });

  factory MobileDosageFormResult.success(List<MobileDosageFormRecord> forms) {
    if (forms.isEmpty) {
      return const MobileDosageFormResult(
        uiStatus: MobileDosageFormUiStatus.empty,
        forms: [],
        messageEn: 'No dosage forms registered.',
        messageBn: 'কোনো ডোসেজ ফরম পাওয়া যায়নি।',
      );
    }
    return MobileDosageFormResult(
      uiStatus: MobileDosageFormUiStatus.success,
      forms: forms,
      messageEn: 'Loaded ${forms.length} dosage form(s).',
      messageBn: '${forms.length} টি ডোসেজ ফরম লোড হয়েছে।',
    );
  }

  factory MobileDosageFormResult.error({
    required MobileDosageFormUiStatus status,
    required String code,
    required String msgEn,
    required String msgBn,
  }) {
    return MobileDosageFormResult(
      uiStatus: status,
      errorCode: code,
      messageEn: msgEn,
      messageBn: msgBn,
    );
  }
}

class MobileDosageFormClient {
  MobileDosageFormResult filterForms({
    required List<MobileDosageFormRecord> forms,
    String? category,
    bool? stripApplicableOnly,
  }) {
    final filtered = forms.where((f) {
      if (!f.isActive) return false;
      if (category != null && category.isNotEmpty && f.category.toLowerCase() != category.toLowerCase()) {
        return false;
      }
      if (stripApplicableOnly != null && f.isStripApplicable != stripApplicableOnly) {
        return false;
      }
      return true;
    }).toList();

    filtered.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    return MobileDosageFormResult.success(filtered);
  }

  MobileDosageFormResult attemptCreateForm({
    required String callerRole,
    required MobileDosageFormRecord form,
  }) {
    final role = callerRole.toUpperCase();
    if (role != 'SUPERADMIN' && role != 'PLATFORM_OPERATOR') {
      return MobileDosageFormResult.error(
        status: MobileDosageFormUiStatus.permissionDenied,
        code: 'PLATFORM_CATALOG_OWNERSHIP_PROTECTED',
        msgEn: 'Dosage form definitions are centrally managed by platform administrators.',
        msgBn: 'ডোসেজ ফরম সংজ্ঞা কেন্দ্রীয়ভাবে সংরক্ষিত। কোনো ফার্মেসি এটি পরিবর্তন করতে পারবে না।',
      );
    }
    return MobileDosageFormResult.success([form]);
  }
}
