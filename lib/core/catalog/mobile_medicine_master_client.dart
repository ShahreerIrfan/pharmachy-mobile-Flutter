// lib/core/catalog/mobile_medicine_master_client.dart
// Architecture Decision: ADR-0121
// Phase 07: Milestone M04 - Shared Medicine Catalog & Dynamic Packaging Units (P121)

enum MobileCatalogUiStatus {
  loading,
  success,
  empty,
  offline,
  error,
  permissionDenied,
}

class MobileMedicineRecord {
  final String productId;
  final String brandName;
  final String genericName;
  final String dosageForm;
  final String strength;
  final String manufacturer;
  final String route;
  final String barcode;
  final double mrpUnit;
  final String dgdaDarNumber;
  final String curationStatus;
  final int versionNumber;
  final String immutableVersionHash;

  const MobileMedicineRecord({
    required this.productId,
    required this.brandName,
    required this.genericName,
    required this.dosageForm,
    required this.strength,
    required this.manufacturer,
    this.route = 'Oral',
    this.barcode = '',
    required this.mrpUnit,
    this.dgdaDarNumber = '',
    this.curationStatus = 'APPROVED',
    this.versionNumber = 1,
    this.immutableVersionHash = '',
  });

  factory MobileMedicineRecord.fromJson(Map<String, dynamic> json) {
    return MobileMedicineRecord(
      productId: json['product_id'] ?? '',
      brandName: json['brand_name'] ?? '',
      genericName: json['generic_name'] ?? '',
      dosageForm: json['dosage_form'] ?? '',
      strength: json['strength'] ?? '',
      manufacturer: json['manufacturer'] ?? '',
      route: json['route'] ?? 'Oral',
      barcode: json['barcode'] ?? '',
      mrpUnit: (json['mrp_unit'] is num)
          ? (json['mrp_unit'] as num).toDouble()
          : double.tryParse(json['mrp_unit']?.toString() ?? '0') ?? 0.0,
      dgdaDarNumber: json['dgda_dar_number'] ?? '',
      curationStatus: json['curation_status'] ?? 'APPROVED',
      versionNumber: json['version_number'] ?? 1,
      immutableVersionHash: json['immutable_version_hash'] ?? '',
    );
  }
}

class MobileCatalogResult {
  final MobileCatalogUiStatus uiStatus;
  final List<MobileMedicineRecord> medicines;
  final String? errorCode;
  final String messageEn;
  final String messageBn;

  const MobileCatalogResult({
    required this.uiStatus,
    this.medicines = const [],
    this.errorCode,
    required this.messageEn,
    required this.messageBn,
  });

  factory MobileCatalogResult.success(List<MobileMedicineRecord> items) {
    if (items.isEmpty) {
      return const MobileCatalogResult(
        uiStatus: MobileCatalogUiStatus.empty,
        medicines: [],
        messageEn: 'No medicines found.',
        messageBn: 'কোনো ওষুধ পাওয়া যায়নি।',
      );
    }
    return MobileCatalogResult(
      uiStatus: MobileCatalogUiStatus.success,
      medicines: items,
      messageEn: 'Found ${items.length} medicine(s).',
      messageBn: '${items.length} টি ওষুধ পাওয়া গেছে।',
    );
  }

  factory MobileCatalogResult.error({
    required MobileCatalogUiStatus status,
    required String code,
    required String msgEn,
    required String msgBn,
  }) {
    return MobileCatalogResult(
      uiStatus: status,
      errorCode: code,
      messageEn: msgEn,
      messageBn: msgBn,
    );
  }
}

class MobileMedicineMasterClient {
  MobileCatalogResult searchCatalog({
    required List<MobileMedicineRecord> catalog,
    String query = '',
    String? filterRoute,
    String? filterDosageForm,
  }) {
    final q = query.trim().toLowerCase();

    final matched = catalog.where((m) {
      if (m.curationStatus.toUpperCase() != 'APPROVED') return false;
      if (filterRoute != null && filterRoute.isNotEmpty && m.route.toLowerCase() != filterRoute.toLowerCase()) {
        return false;
      }
      if (filterDosageForm != null && filterDosageForm.isNotEmpty && m.dosageForm.toLowerCase() != filterDosageForm.toLowerCase()) {
        return false;
      }
      if (q.isEmpty) return true;
      if (m.barcode.isNotEmpty && m.barcode == q) return true;
      return m.brandName.toLowerCase().contains(q) ||
          m.genericName.toLowerCase().contains(q) ||
          m.manufacturer.toLowerCase().contains(q) ||
          m.dgdaDarNumber.toLowerCase().contains(q);
    }).toList();

    return MobileCatalogResult.success(matched);
  }

  MobileCatalogResult attemptMutateMaster({
    required String callerRole,
    required MobileMedicineRecord item,
  }) {
    final role = callerRole.toUpperCase();
    if (role != 'SUPERADMIN' && role != 'PLATFORM_OPERATOR') {
      return MobileCatalogResult.error(
        status: MobileCatalogUiStatus.permissionDenied,
        code: 'PLATFORM_CATALOG_OWNERSHIP_PROTECTED',
        msgEn: 'Global medicine catalog is centrally protected. Tenants cannot modify master records.',
        msgBn: 'গ্লোবাল মেডিসিন ক্যাটালগ কেন্দ্রীয়ভাবে সুরক্ষিত। কোনো ফার্মেসি এটি পরিবর্তন বা মুছতে পারবে না।',
      );
    }
    return MobileCatalogResult.success([item]);
  }
}
