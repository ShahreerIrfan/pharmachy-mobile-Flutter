// lib/core/catalog/mobile_medicine_variant_client.dart
// Architecture Decision: ADR-0126
// Phase 07: Milestone M04 - Shared Medicine Catalog & Dynamic Packaging Units (P126)

enum MobileVariantUiStatus {
  loading,
  success,
  empty,
  offline,
  error,
  permissionDenied,
}

class MobileMedicineVariantRecord {
  final String variantId;
  final String productId;
  final String sku;
  final String variantName;
  final String brandName;
  final String genericName;
  final String dosageForm;
  final String manufacturer;
  final String strength;
  final String packSize;
  final int packSizeNumeric;
  final String route;
  final String containerType;
  final String barcode;
  final double mrpUnit;
  final double costUnit;
  final double mrpPack;
  final double costPack;
  final bool isPrescriptionRequired;
  final bool isNarcotic;
  final bool isAntibiotic;
  final bool isColdChain;
  final bool isActive;

  const MobileMedicineVariantRecord({
    required this.variantId,
    required this.productId,
    required this.sku,
    required this.variantName,
    required this.brandName,
    required this.genericName,
    required this.dosageForm,
    required this.manufacturer,
    required this.strength,
    required this.packSize,
    required this.packSizeNumeric,
    this.route = 'Oral',
    this.containerType = 'BLISTER_PACK',
    this.barcode = '',
    required this.mrpUnit,
    required this.costUnit,
    required this.mrpPack,
    required this.costPack,
    this.isPrescriptionRequired = false,
    this.isNarcotic = false,
    this.isAntibiotic = false,
    this.isColdChain = false,
    this.isActive = true,
  });

  factory MobileMedicineVariantRecord.fromJson(Map<String, dynamic> json) {
    return MobileMedicineVariantRecord(
      variantId: json['variant_id'] ?? '',
      productId: json['product_id'] ?? '',
      sku: json['sku'] ?? '',
      variantName: json['variant_name'] ?? '',
      brandName: json['brand_name'] ?? '',
      genericName: json['generic_name'] ?? '',
      dosageForm: json['dosage_form'] ?? '',
      manufacturer: json['manufacturer'] ?? '',
      strength: json['strength'] ?? '',
      packSize: json['pack_size'] ?? '',
      packSizeNumeric: json['pack_size_numeric'] ?? 1,
      route: json['route'] ?? 'Oral',
      containerType: json['container_type'] ?? 'BLISTER_PACK',
      barcode: json['barcode'] ?? '',
      mrpUnit: double.tryParse(json['mrp_unit']?.toString() ?? '0') ?? 0.0,
      costUnit: double.tryParse(json['cost_unit']?.toString() ?? '0') ?? 0.0,
      mrpPack: double.tryParse(json['mrp_pack']?.toString() ?? '0') ?? 0.0,
      costPack: double.tryParse(json['cost_pack']?.toString() ?? '0') ?? 0.0,
      isPrescriptionRequired: json['is_prescription_required'] ?? false,
      isNarcotic: json['is_narcotic'] ?? false,
      isAntibiotic: json['is_antibiotic'] ?? false,
      isColdChain: json['is_cold_chain'] ?? false,
      isActive: json['is_active'] ?? true,
    );
  }
}

class MobileVariantResult {
  final MobileVariantUiStatus uiStatus;
  final List<MobileMedicineVariantRecord> variants;
  final String? errorCode;
  final String messageEn;
  final String messageBn;

  const MobileVariantResult({
    required this.uiStatus,
    this.variants = const [],
    this.errorCode,
    required this.messageEn,
    required this.messageBn,
  });

  factory MobileVariantResult.success(List<MobileMedicineVariantRecord> list) {
    if (list.isEmpty) {
      return const MobileVariantResult(
        uiStatus: MobileVariantUiStatus.empty,
        variants: [],
        messageEn: 'No medicine variants found.',
        messageBn: 'কোনো মেডিসিন ভ্যারিয়েন্ট পাওয়া যায়নি।',
      );
    }
    return MobileVariantResult(
      uiStatus: MobileVariantUiStatus.success,
      variants: list,
      messageEn: 'Loaded ${list.length} variant(s).',
      messageBn: '${list.length} টি ভ্যারিয়েন্ট লোড হয়েছে।',
    );
  }

  factory MobileVariantResult.error({
    required MobileVariantUiStatus status,
    required String code,
    required String msgEn,
    required String msgBn,
  }) {
    return MobileVariantResult(
      uiStatus: status,
      errorCode: code,
      messageEn: msgEn,
      messageBn: msgBn,
    );
  }
}

class MobileMedicineVariantClient {
  final Map<String, MobileMedicineVariantRecord> _cache = {};

  void registerVariant(MobileMedicineVariantRecord record) {
    _cache[record.variantId] = record;
  }

  MobileVariantResult lookupByBarcode(String barcode) {
    final clean = barcode.trim().toLowerCase();
    if (clean.isEmpty) {
      return MobileVariantResult.error(
        status: MobileVariantUiStatus.error,
        code: 'ERR_INVALID_BARCODE',
        msgEn: 'Barcode cannot be empty.',
        msgBn: 'বারকোড খালি হতে পারে না।',
      );
    }

    final matches = _cache.values.where((v) => v.barcode.toLowerCase() == clean).toList();
    return MobileVariantResult.success(matches);
  }

  MobileVariantResult lookupBySku(String sku) {
    final clean = sku.trim().toLowerCase();
    if (clean.isEmpty) {
      return MobileVariantResult.error(
        status: MobileVariantUiStatus.error,
        code: 'ERR_INVALID_SKU',
        msgEn: 'SKU cannot be empty.',
        msgBn: 'SKU খালি হতে পারে না।',
      );
    }

    final matches = _cache.values.where((v) => v.sku.toLowerCase() == clean).toList();
    return MobileVariantResult.success(matches);
  }

  MobileVariantResult searchVariants(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      return MobileVariantResult.success(_cache.values.toList());
    }

    final matches = _cache.values.where((v) {
      return v.variantName.toLowerCase().contains(q) ||
          v.sku.toLowerCase().contains(q) ||
          v.barcode.toLowerCase().contains(q) ||
          v.brandName.toLowerCase().contains(q) ||
          v.genericName.toLowerCase().contains(q);
    }).toList();

    return MobileVariantResult.success(matches);
  }

  MobileVariantResult attemptCreateVariant({
    required String callerRole,
    required MobileMedicineVariantRecord variant,
  }) {
    final role = callerRole.toUpperCase();
    if (role != 'SUPERADMIN' && role != 'PLATFORM_OPERATOR') {
      return MobileVariantResult.error(
        status: MobileVariantUiStatus.permissionDenied,
        code: 'PLATFORM_CATALOG_OWNERSHIP_PROTECTED',
        msgEn: 'Medicine variants and master catalog entries are centrally curated by platform administrators.',
        msgBn: 'ঔষধ ভ্যারিয়েন্ট ও ক্যাটালগ এন্ট্রি কেন্দ্রীয়ভাবে প্ল্যাটফর্ম অ্যাডমিনিস্ট্রেটর দ্বারা পরিচালিত।',
      );
    }
    registerVariant(variant);
    return MobileVariantResult.success([variant]);
  }
}
