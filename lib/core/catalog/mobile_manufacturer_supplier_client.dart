// lib/core/catalog/mobile_manufacturer_supplier_client.dart
// Architecture Decision: ADR-0127
// Phase 07: Milestone M04 - Shared Medicine Catalog & Dynamic Packaging Units (P127)

enum MobileMergeUiStatus {
  success,
  error,
  permissionDenied,
  empty,
  offline,
}

class MobileManufacturerRecord {
  final String manufacturerId;
  final String name;
  final String nameBn;
  final String code;
  final String dgdaLicenseNo;
  final bool isActive;
  final String? mergedIntoId;

  const MobileManufacturerRecord({
    required this.manufacturerId,
    required this.name,
    this.nameBn = '',
    required this.code,
    this.dgdaLicenseNo = '',
    this.isActive = true,
    this.mergedIntoId,
  });

  factory MobileManufacturerRecord.fromJson(Map<String, dynamic> json) {
    return MobileManufacturerRecord(
      manufacturerId: json['manufacturer_id'] ?? '',
      name: json['name'] ?? '',
      nameBn: json['name_bn'] ?? '',
      code: json['code'] ?? '',
      dgdaLicenseNo: json['dgda_license_no'] ?? '',
      isActive: json['is_active'] ?? true,
      mergedIntoId: json['merged_into_id'],
    );
  }
}

class MobileSupplierRecord {
  final String supplierId;
  final String tenantId;
  final String name;
  final String contactPerson;
  final String phone;
  final String email;
  final String dlNumber;
  bool isActive;
  String? mergedIntoId;

  MobileSupplierRecord({
    required this.supplierId,
    required this.tenantId,
    required this.name,
    this.contactPerson = '',
    this.phone = '',
    this.email = '',
    this.dlNumber = '',
    this.isActive = true,
    this.mergedIntoId,
  });

  factory MobileSupplierRecord.fromJson(Map<String, dynamic> json) {
    return MobileSupplierRecord(
      supplierId: json['supplier_id'] ?? '',
      tenantId: json['tenant_id'] ?? '',
      name: json['name'] ?? '',
      contactPerson: json['contact_person'] ?? '',
      phone: json['phone'] ?? '',
      email: json['email'] ?? '',
      dlNumber: json['dl_number'] ?? '',
      isActive: json['is_active'] ?? true,
      mergedIntoId: json['merged_into_id'],
    );
  }
}

class MobileMergeResult {
  final MobileMergeUiStatus uiStatus;
  final bool isMerged;
  final String sourceId;
  final String targetId;
  final String targetName;
  final String? errorCode;
  final String messageEn;
  final String messageBn;

  const MobileMergeResult({
    required this.uiStatus,
    required this.isMerged,
    this.sourceId = '',
    this.targetId = '',
    this.targetName = '',
    this.errorCode,
    required this.messageEn,
    required this.messageBn,
  });

  factory MobileMergeResult.success({
    required String sourceId,
    required String targetId,
    required String targetName,
  }) {
    return MobileMergeResult(
      uiStatus: MobileMergeUiStatus.success,
      isMerged: true,
      sourceId: sourceId,
      targetId: targetId,
      targetName: targetName,
      messageEn: 'Merged successfully into $targetName.',
      messageBn: '$targetName-এ সফলভাবে মার্জ সম্পন্ন হয়েছে।',
    );
  }

  factory MobileMergeResult.error({
    required MobileMergeUiStatus status,
    required String code,
    required String msgEn,
    required String msgBn,
  }) {
    return MobileMergeResult(
      uiStatus: status,
      isMerged: false,
      errorCode: code,
      messageEn: msgEn,
      messageBn: msgBn,
    );
  }
}

class MobileManufacturerSupplierClient {
  final Map<String, MobileManufacturerRecord> _manufacturers = {};
  final Map<String, MobileSupplierRecord> _suppliers = {};

  void registerManufacturer(MobileManufacturerRecord m) {
    _manufacturers[m.manufacturerId] = m;
  }

  void registerSupplier(MobileSupplierRecord s) {
    _suppliers[s.supplierId] = s;
  }

  List<MobileManufacturerRecord> listActiveManufacturers() {
    return _manufacturers.values.where((m) => m.isActive && m.mergedIntoId == null).toList();
  }

  List<MobileSupplierRecord> listActiveSuppliers(String tenantId) {
    return _suppliers.values.where((s) => s.tenantId == tenantId && s.isActive && s.mergedIntoId == null).toList();
  }

  MobileMergeResult mergeSuppliers({
    required String tenantId,
    required String callerRole,
    required String sourceId,
    required String targetId,
    String reason = 'Consolidation of duplicate supplier records',
  }) {
    final role = callerRole.toUpperCase();
    if (role == 'CASHIER') {
      return MobileMergeResult.error(
        status: MobileMergeUiStatus.permissionDenied,
        code: 'ERR_STAFF_ROLE_DENIED',
        msgEn: 'Cashier role is not permitted to merge suppliers.',
        msgBn: 'ক্যাশিয়ার সরবরাহকারী মার্জ করার অনুমতিপ্রাপ্ত নন।',
      );
    }

    if (sourceId == targetId) {
      return MobileMergeResult.error(
        status: MobileMergeUiStatus.error,
        code: 'ERR_CANNOT_MERGE_SELF',
        msgEn: 'Cannot merge a supplier into itself.',
        msgBn: 'একই সরবরাহকারীকে নিজের সাথে মার্জ করা যাবে না।',
      );
    }

    final source = _suppliers[sourceId];
    final target = _suppliers[targetId];

    if (source == null || target == null) {
      return MobileMergeResult.error(
        status: MobileMergeUiStatus.error,
        code: 'ERR_SUPPLIER_NOT_FOUND',
        msgEn: 'Source or target supplier not found.',
        msgBn: 'সরবরাহকারী পাওয়া যায়নি।',
      );
    }

    // Strict tenant isolation
    if (source.tenantId != tenantId || target.tenantId != tenantId) {
      return MobileMergeResult.error(
        status: MobileMergeUiStatus.permissionDenied,
        code: 'ERR_CROSS_TENANT_ACCESS',
        msgEn: 'Cross-tenant supplier merge is strictly forbidden.',
        msgBn: 'ভিন্ন ফার্মেসির সরবরাহকারী প্রতিষ্ঠান মার্জ করা সম্পূর্ণ নিষিদ্ধ।',
      );
    }

    if (!target.isActive || target.mergedIntoId != null) {
      return MobileMergeResult.error(
        status: MobileMergeUiStatus.error,
        code: 'ERR_TARGET_ALREADY_MERGED',
        msgEn: 'Target supplier is inactive or already merged.',
        msgBn: 'লক্ষ্য সরবরাহকারীটি ইতিমধ্যে নিষ্ক্রিয় বা মার্জ করা হয়েছে।',
      );
    }

    source.isActive = false;
    source.mergedIntoId = target.supplierId;

    return MobileMergeResult.success(
      sourceId: sourceId,
      targetId: targetId,
      targetName: target.name,
    );
  }

  MobileMergeResult attemptCreateManufacturer({
    required String callerRole,
    required MobileManufacturerRecord record,
  }) {
    final role = callerRole.toUpperCase();
    if (role != 'SUPERADMIN' && role != 'PLATFORM_OPERATOR') {
      return MobileMergeResult.error(
        status: MobileMergeUiStatus.permissionDenied,
        code: 'PLATFORM_CATALOG_OWNERSHIP_PROTECTED',
        msgEn: 'Pharmaceutical manufacturers are centrally curated by platform administrators.',
        msgBn: 'ঔষধ প্রস্তুতকারক প্রতিষ্ঠানসমূহ কেন্দ্রীয়ভাবে প্ল্যাটফর্ম অ্যাডমিনিস্ট্রেটর দ্বারা পরিচালিত।',
      );
    }
    registerManufacturer(record);
    return MobileMergeResult.success(
      sourceId: record.manufacturerId,
      targetId: record.manufacturerId,
      targetName: record.name,
    );
  }
}
