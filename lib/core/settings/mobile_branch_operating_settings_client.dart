// lib/core/settings/mobile_branch_operating_settings_client.dart
// Architecture Decision: ADR-0116 (P116)
// Phase 06: Milestone M03 - Offline-First Desktop POS & Owner Visibility.

enum MobileBranchSettingsUiStatus {
  loading,
  success,
  error,
  permissionDenied,
  offline,
}

class MobileReceiptFormat {
  final String paperWidth;
  final String headerText;
  final String footerText;
  final bool showTaxBreakdown;
  final String language;

  const MobileReceiptFormat({
    this.paperWidth = '80mm',
    this.headerText = '',
    this.footerText = '',
    this.showTaxBreakdown = true,
    this.language = 'BILINGUAL',
  });

  factory MobileReceiptFormat.fromJson(Map<String, dynamic> json) {
    return MobileReceiptFormat(
      paperWidth: json['paper_width']?.toString() ?? '80mm',
      headerText: json['header_text']?.toString() ?? '',
      footerText: json['footer_text']?.toString() ?? '',
      showTaxBreakdown: json['show_tax_breakdown'] != false,
      language: json['language']?.toString() ?? 'BILINGUAL',
    );
  }
}

class MobileBranchSettingsRecord {
  final String settingsId;
  final String tenantId;
  final String branchId;
  final String branchName;
  final MobileReceiptFormat receiptFormat;
  final Map<String, dynamic> operatingHours;
  final List<dynamic> storageZones;
  final Map<String, dynamic> lowStockThresholds;
  final Map<String, dynamic> taxDefaults;
  final Map<String, dynamic> devicePolicies;

  const MobileBranchSettingsRecord({
    required this.settingsId,
    required this.tenantId,
    required this.branchId,
    required this.branchName,
    required this.receiptFormat,
    this.operatingHours = const {},
    this.storageZones = const [],
    this.lowStockThresholds = const {},
    this.taxDefaults = const {},
    this.devicePolicies = const {},
  });

  factory MobileBranchSettingsRecord.fromJson(Map<String, dynamic> json) {
    return MobileBranchSettingsRecord(
      settingsId: json['settings_id']?.toString() ?? '',
      tenantId: json['tenant_id']?.toString() ?? '',
      branchId: json['branch_id']?.toString() ?? '',
      branchName: json['branch_name']?.toString() ?? '',
      receiptFormat: MobileReceiptFormat.fromJson(json['receipt_format'] is Map<String, dynamic> ? json['receipt_format'] : {}),
      operatingHours: json['operating_hours'] is Map<String, dynamic> ? json['operating_hours'] : {},
      storageZones: json['storage_zones'] is List<dynamic> ? json['storage_zones'] : [],
      lowStockThresholds: json['low_stock_thresholds'] is Map<String, dynamic> ? json['low_stock_thresholds'] : {},
      taxDefaults: json['tax_defaults'] is Map<String, dynamic> ? json['tax_defaults'] : {},
      devicePolicies: json['device_policies'] is Map<String, dynamic> ? json['device_policies'] : {},
    );
  }
}

class MobileBranchSettingsOpResult {
  final MobileBranchSettingsUiStatus uiStatus;
  final MobileBranchSettingsRecord? record;
  final String? errorCode;
  final String messageEn;
  final String messageBn;

  const MobileBranchSettingsOpResult({
    required this.uiStatus,
    this.record,
    this.errorCode,
    required this.messageEn,
    required this.messageBn,
  });

  factory MobileBranchSettingsOpResult.success(MobileBranchSettingsRecord record) {
    return MobileBranchSettingsOpResult(
      uiStatus: MobileBranchSettingsUiStatus.success,
      record: record,
      messageEn: 'Branch operating settings loaded successfully.',
      messageBn: 'ব্রাঞ্চ অপারেটিং সেটিংস সফলভাবে লোড হয়েছে।',
    );
  }

  factory MobileBranchSettingsOpResult.error({
    required MobileBranchSettingsUiStatus status,
    required String errorCode,
    required String msgEn,
    required String msgBn,
  }) {
    return MobileBranchSettingsOpResult(
      uiStatus: status,
      errorCode: errorCode,
      messageEn: msgEn,
      messageBn: msgBn,
    );
  }
}

class MobileBranchOperatingSettingsClient {
  MobileBranchSettingsOpResult evaluateAccess({
    required String callerRole,
    required String callerTenantId,
    String? callerBranchId,
    required MobileBranchSettingsRecord record,
    bool isWriteOperation = false,
  }) {
    if (callerTenantId != record.tenantId && callerRole != 'SUPERADMIN') {
      return MobileBranchSettingsOpResult.error(
        status: MobileBranchSettingsUiStatus.permissionDenied,
        errorCode: 'ERR_CROSS_TENANT_VIOLATION',
        msgEn: 'Cross-tenant access forbidden.',
        msgBn: 'অন্য টেন্যান্টের সেটিংস অ্যাক্সেস করা যাবে না।',
      );
    }

    final isOwner = callerRole == 'PHARMACY_OWNER' || callerRole == 'SUPERADMIN';
    final isManager = callerRole == 'BRANCH_MANAGER';

    if (isWriteOperation) {
      if (!isOwner && !isManager) {
        return MobileBranchSettingsOpResult.error(
          status: MobileBranchSettingsUiStatus.permissionDenied,
          errorCode: 'ERR_PERMISSION_DENIED',
          msgEn: 'Staff members lack permission to modify branch operating settings.',
          msgBn: 'স্টাফদের ব্রাঞ্চ সেটিংস পরিবর্তনের অনুমতি নেই।',
        );
      }
      if (isManager && callerBranchId != record.branchId) {
        return MobileBranchSettingsOpResult.error(
          status: MobileBranchSettingsUiStatus.permissionDenied,
          errorCode: 'ERR_CROSS_BRANCH_VIOLATION',
          msgEn: 'Branch managers cannot modify foreign branch settings.',
          msgBn: 'শাখা ব্যবস্থাপক অন্য শাখার সেটিংস পরিবর্তন করতে পারবেন না।',
        );
      }
    }

    return MobileBranchSettingsOpResult.success(record);
  }
}

