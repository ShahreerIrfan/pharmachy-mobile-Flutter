// lib/core/catalog/mobile_medicine_details_preview_client.dart
// Architecture Decision: ADR-0138
// Phase 07: Milestone M04 - Shared Medicine Catalog & Dynamic Packaging Units (P138)

import 'dart:convert';
import 'dart:typed_data';

enum MobilePreviewUiStatus {
  success,
  error,
  permissionDenied,
  empty,
  offline,
}

/// Standard FIPS 180-4 SHA-256 implementation in pure Dart
class MobilePreviewSha256 {
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

class MobilePackagingTier {
  final String packagingLevel;
  final int multiplier;
  final String barcodeValue;
  final int priorityOrder;

  MobilePackagingTier({
    required this.packagingLevel,
    required this.multiplier,
    this.barcodeValue = '',
    this.priorityOrder = 1,
  });

  factory MobilePackagingTier.fromJson(Map<String, dynamic> json) => MobilePackagingTier(
        packagingLevel: (json['packaging_level'] as String?) ?? 'UNIT',
        multiplier: (json['multiplier'] as num?)?.toInt() ?? 1,
        barcodeValue: (json['barcode_value'] as String?) ?? '',
        priorityOrder: (json['priority_order'] as num?)?.toInt() ?? 1,
      );

  Map<String, dynamic> toJson() => {
        'packaging_level': packagingLevel,
        'multiplier': multiplier,
        'barcode_value': barcodeValue,
        'priority_order': priorityOrder,
      };
}

class MobileVariantSummary {
  final String variantId;
  final String sku;
  final String variantName;
  final String strength;
  final String packSize;
  final int packSizeNumeric;
  final String containerType;
  final double mrpPack;
  final double costPack;
  final String barcode;

  MobileVariantSummary({
    required this.variantId,
    required this.sku,
    required this.variantName,
    this.strength = '',
    this.packSize = '',
    required this.packSizeNumeric,
    this.containerType = 'BLISTER_PACK',
    required this.mrpPack,
    this.costPack = 0.0,
    this.barcode = '',
  });

  factory MobileVariantSummary.fromJson(Map<String, dynamic> json) => MobileVariantSummary(
        variantId: (json['variant_id'] as String?) ?? '',
        sku: (json['sku'] as String?) ?? '',
        variantName: (json['variant_name'] as String?) ?? '',
        strength: (json['strength'] as String?) ?? '',
        packSize: (json['pack_size'] as String?) ?? '',
        packSizeNumeric: (json['pack_size_numeric'] as num?)?.toInt() ?? 1,
        containerType: (json['container_type'] as String?) ?? 'BLISTER_PACK',
        mrpPack: double.tryParse(json['mrp_pack']?.toString() ?? '0.0') ?? 0.0,
        costPack: double.tryParse(json['cost_pack']?.toString() ?? '0.0') ?? 0.0,
        barcode: (json['barcode'] as String?) ?? '',
      );

  Map<String, dynamic> toJson() => {
        'variant_id': variantId,
        'sku': sku,
        'variant_name': variantName,
        'strength': strength,
        'pack_size': packSize,
        'pack_size_numeric': packSizeNumeric,
        'container_type': containerType,
        'mrp_pack': mrpPack.toStringAsFixed(2),
        'cost_pack': costPack.toStringAsFixed(2),
        'barcode': barcode,
      };
}

class MobileActiveRecall {
  final String noticeNumber;
  final String regulatoryAuthority;
  final String lifecycleStatus;
  final String reason;
  final String actionRequired;

  MobileActiveRecall({
    required this.noticeNumber,
    required this.regulatoryAuthority,
    required this.lifecycleStatus,
    required this.reason,
    this.actionRequired = '',
  });

  factory MobileActiveRecall.fromJson(Map<String, dynamic> json) => MobileActiveRecall(
        noticeNumber: (json['notice_number'] as String?) ?? '',
        regulatoryAuthority: (json['regulatory_authority'] as String?) ?? '',
        lifecycleStatus: (json['lifecycle_status'] as String?) ?? '',
        reason: (json['reason'] as String?) ?? '',
        actionRequired: (json['action_required'] as String?) ?? '',
      );

  Map<String, dynamic> toJson() => {
        'notice_number': noticeNumber,
        'regulatory_authority': regulatoryAuthority,
        'lifecycle_status': lifecycleStatus,
        'reason': reason,
        'action_required': actionRequired,
      };
}

class MobileMedicinePreviewRecord {
  final String productId;
  final String brandName;
  final String brandNameBn;
  final String genericName;
  final String genericNameBn;
  final String manufacturer;
  final String dgdaDarNumber;
  final String curationStatus;

  final String dosageForm;
  final String strength;
  final double? strengthNumeric;
  final String strengthUnit;
  final String strengthUnitFamily;
  final String route;
  final String primaryBarcode;

  final double mrpUnit;
  final double? costUnit;
  final double effectiveMrpUnit;
  final bool hasTenantOverride;
  final String localBrandName;
  final String shelfLocation;

  final bool isPrescriptionOnly;
  final bool isNarcotic;
  final bool isAntibiotic;
  final String antimicrobialClassification;
  final String rxClassificationLabel;
  final String rxClassificationLabelBn;

  final bool requiresColdChain;
  final double? minTempCelsius;
  final double? maxTempCelsius;
  final String storageInstructions;
  final String storageInstructionsBn;

  final List<MobilePackagingTier> packagingHierarchy;
  final List<MobileVariantSummary> variants;

  final bool isRecalled;
  final bool isDiscontinued;
  final bool isDispensingBlocked;
  final MobileActiveRecall? activeRecallNotice;
  final String immutablePreviewHash;

  MobileMedicinePreviewRecord({
    required this.productId,
    required this.brandName,
    this.brandNameBn = '',
    required this.genericName,
    this.genericNameBn = '',
    required this.manufacturer,
    this.dgdaDarNumber = '',
    this.curationStatus = 'APPROVED',
    required this.dosageForm,
    required this.strength,
    this.strengthNumeric,
    this.strengthUnit = 'mg',
    this.strengthUnitFamily = 'MASS',
    this.route = 'Oral',
    this.primaryBarcode = '',
    required this.mrpUnit,
    this.costUnit,
    required this.effectiveMrpUnit,
    this.hasTenantOverride = false,
    this.localBrandName = '',
    this.shelfLocation = '',
    this.isPrescriptionOnly = false,
    this.isNarcotic = false,
    this.isAntibiotic = false,
    this.antimicrobialClassification = 'NONE',
    required this.rxClassificationLabel,
    required this.rxClassificationLabelBn,
    this.requiresColdChain = false,
    this.minTempCelsius,
    this.maxTempCelsius,
    required this.storageInstructions,
    required this.storageInstructionsBn,
    this.packagingHierarchy = const [],
    this.variants = const [],
    this.isRecalled = false,
    this.isDiscontinued = false,
    this.isDispensingBlocked = false,
    this.activeRecallNotice,
    required this.immutablePreviewHash,
  });

  factory MobileMedicinePreviewRecord.fromJson(Map<String, dynamic> json) {
    return MobileMedicinePreviewRecord(
      productId: (json['product_id'] as String?) ?? '',
      brandName: (json['brand_name'] as String?) ?? '',
      brandNameBn: (json['brand_name_bn'] as String?) ?? '',
      genericName: (json['generic_name'] as String?) ?? '',
      genericNameBn: (json['generic_name_bn'] as String?) ?? '',
      manufacturer: (json['manufacturer'] as String?) ?? '',
      dgdaDarNumber: (json['dgda_dar_number'] as String?) ?? '',
      curationStatus: (json['curation_status'] as String?) ?? 'APPROVED',
      dosageForm: (json['dosage_form'] as String?) ?? '',
      strength: (json['strength'] as String?) ?? '',
      strengthNumeric: (json['strength_numeric'] as num?)?.toDouble(),
      strengthUnit: (json['strength_unit'] as String?) ?? 'mg',
      strengthUnitFamily: (json['strength_unit_family'] as String?) ?? 'MASS',
      route: (json['route'] as String?) ?? 'Oral',
      primaryBarcode: (json['primary_barcode'] as String?) ?? '',
      mrpUnit: double.tryParse(json['mrp_unit']?.toString() ?? '0.0') ?? 0.0,
      costUnit: json['cost_unit'] != null ? double.tryParse(json['cost_unit'].toString()) : null,
      effectiveMrpUnit: double.tryParse(json['effective_mrp_unit']?.toString() ?? '0.0') ?? 0.0,
      hasTenantOverride: (json['has_tenant_override'] as bool?) ?? false,
      localBrandName: (json['local_brand_name'] as String?) ?? '',
      shelfLocation: (json['shelf_location'] as String?) ?? '',
      isPrescriptionOnly: (json['is_prescription_only'] as bool?) ?? false,
      isNarcotic: (json['is_narcotic'] as bool?) ?? false,
      isAntibiotic: (json['is_antibiotic'] as bool?) ?? false,
      antimicrobialClassification: (json['antimicrobial_classification'] as String?) ?? 'NONE',
      rxClassificationLabel: (json['rx_classification_label'] as String?) ?? '',
      rxClassificationLabelBn: (json['rx_classification_label_bn'] as String?) ?? '',
      requiresColdChain: (json['requires_cold_chain'] as bool?) ?? false,
      minTempCelsius: (json['min_temp_celsius'] as num?)?.toDouble(),
      maxTempCelsius: (json['max_temp_celsius'] as num?)?.toDouble(),
      storageInstructions: (json['storage_instructions'] as String?) ?? '',
      storageInstructionsBn: (json['storage_instructions_bn'] as String?) ?? '',
      packagingHierarchy: (json['packaging_hierarchy'] as List<dynamic>?)
              ?.map((e) => MobilePackagingTier.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      variants: (json['variants'] as List<dynamic>?)
              ?.map((e) => MobileVariantSummary.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      isRecalled: (json['is_recalled'] as bool?) ?? false,
      isDiscontinued: (json['is_discontinued'] as bool?) ?? false,
      isDispensingBlocked: (json['is_dispensing_blocked'] as bool?) ?? false,
      activeRecallNotice: json['active_recall_notice'] != null
          ? MobileActiveRecall.fromJson(json['active_recall_notice'] as Map<String, dynamic>)
          : null,
      immutablePreviewHash: (json['immutable_preview_hash'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'product_id': productId,
        'brand_name': brandName,
        'brand_name_bn': brandNameBn,
        'generic_name': genericName,
        'generic_name_bn': genericNameBn,
        'manufacturer': manufacturer,
        'dgda_dar_number': dgdaDarNumber,
        'curation_status': curationStatus,
        'dosage_form': dosageForm,
        'strength': strength,
        'strength_numeric': strengthNumeric,
        'strength_unit': strengthUnit,
        'strength_unit_family': strengthUnitFamily,
        'route': route,
        'primary_barcode': primaryBarcode,
        'mrp_unit': mrpUnit.toStringAsFixed(2),
        'cost_unit': costUnit?.toStringAsFixed(2),
        'effective_mrp_unit': effectiveMrpUnit.toStringAsFixed(2),
        'has_tenant_override': hasTenantOverride,
        'local_brand_name': localBrandName,
        'shelf_location': shelfLocation,
        'is_prescription_only': isPrescriptionOnly,
        'is_narcotic': isNarcotic,
        'is_antibiotic': isAntibiotic,
        'antimicrobial_classification': antimicrobialClassification,
        'rx_classification_label': rxClassificationLabel,
        'rx_classification_label_bn': rxClassificationLabelBn,
        'requires_cold_chain': requiresColdChain,
        'min_temp_celsius': minTempCelsius,
        'max_temp_celsius': maxTempCelsius,
        'storage_instructions': storageInstructions,
        'storage_instructions_bn': storageInstructionsBn,
        'packaging_hierarchy': packagingHierarchy.map((e) => e.toJson()).toList(),
        'variants': variants.map((e) => e.toJson()).toList(),
        'is_recalled': isRecalled,
        'is_discontinued': isDiscontinued,
        'is_dispensing_blocked': isDispensingBlocked,
        'active_recall_notice': activeRecallNotice?.toJson(),
        'immutable_preview_hash': immutablePreviewHash,
      };
}

class MobilePreviewResult<T> {
  final MobilePreviewUiStatus status;
  final T? data;
  final String? errorCode;
  final String messageEn;
  final String messageBn;

  const MobilePreviewResult._({
    required this.status,
    this.data,
    this.errorCode,
    required this.messageEn,
    required this.messageBn,
  });

  factory MobilePreviewResult.success(T data) => MobilePreviewResult._(
        status: MobilePreviewUiStatus.success,
        data: data,
        messageEn: 'Operation completed successfully.',
        messageBn: 'অপারেশন সফলভাবে সম্পন্ন হয়েছে।',
      );

  factory MobilePreviewResult.empty(String en, String bn) => MobilePreviewResult._(
        status: MobilePreviewUiStatus.empty,
        errorCode: 'EMPTY_RESULT',
        messageEn: en,
        messageBn: bn,
      );

  factory MobilePreviewResult.offline(T data) => MobilePreviewResult._(
        status: MobilePreviewUiStatus.offline,
        data: data,
        errorCode: 'STATUS_OFFLINE_CACHE',
        messageEn: 'Operating in offline cached mode.',
        messageBn: 'অফলাইন ক্যাশড মোড সক্রিয়।',
      );

  factory MobilePreviewResult.permissionDenied(String code, String en, String bn) => MobilePreviewResult._(
        status: MobilePreviewUiStatus.permissionDenied,
        errorCode: code,
        messageEn: en,
        messageBn: bn,
      );

  factory MobilePreviewResult.error(String code, String en, String bn) => MobilePreviewResult._(
        status: MobilePreviewUiStatus.error,
        errorCode: code,
        messageEn: en,
        messageBn: bn,
      );
}

class MobileMedicineDetailsPreviewClient {
  final Map<String, MobileMedicinePreviewRecord> _previewStore = {};
  final Map<String, Map<String, dynamic>> _overrideStore = {};
  final Map<String, MobileActiveRecall> _recallStore = {};
  bool isOffline = false;

  bool _isAuthorizedManager(String? role) {
    if (role == null) return false;
    final r = role.trim().toUpperCase();
    return r == 'SUPERADMIN' ||
        r == 'PLATFORM_OPERATOR' ||
        r == 'OWNER' ||
        r == 'PHARMACY_OWNER' ||
        r == 'MANAGER' ||
        r == 'BRANCH_MANAGER' ||
        r == 'PHARMACIST' ||
        r == 'STAFF_PHARMACIST';
  }

  void registerMedicine(MobileMedicinePreviewRecord record) {
    _previewStore[record.productId] = record;
  }

  void setTenantOverride({
    required String tenantId,
    required String productId,
    required double customMrp,
    String localBrand = '',
    String shelf = '',
  }) {
    _overrideStore['$tenantId|$productId'] = {
      'customMrp': customMrp,
      'localBrand': localBrand,
      'shelf': shelf,
    };
  }

  void setRecallNotice({
    required String productId,
    required MobileActiveRecall recall,
  }) {
    _recallStore[productId] = recall;
  }

  String _computePreviewHash(String id, String brand, String form, String strength, double mrp, bool blocked) {
    final raw = '$id|$brand|$form|$strength|${mrp.toStringAsFixed(2)}|$blocked';
    return MobilePreviewSha256.hashString(raw);
  }

  MobilePreviewResult<MobileMedicinePreviewRecord> getMedicinePreview({
    String? targetTenantId,
    String? actorTenantId,
    required String productId,
    required String userRole,
  }) {
    if (productId.trim().isEmpty) {
      return MobilePreviewResult.error(
        'ERR_INVALID_PRODUCT_ID',
        'Product ID is required.',
        'ওষুধের আইডি প্রয়োজন।',
      );
    }

    final isSuperadmin = userRole.trim().toUpperCase() == 'SUPERADMIN';

    // Cross-tenant guard
    if (targetTenantId != null && !isSuperadmin) {
      if (actorTenantId != null && targetTenantId.trim().toLowerCase() != actorTenantId.trim().toLowerCase()) {
        return MobilePreviewResult.permissionDenied(
          'ERR_CROSS_TENANT_ACCESS',
          'Cannot query medicine details preview with overrides from another tenant.',
          'অন্য ফার্মেসির মেটাডাটা সহ প্রিভিউ দেখার অনুমতি নেই।',
        );
      }
    }

    final base = _previewStore[productId];
    if (base == null) {
      return MobilePreviewResult.error(
        'ERR_PRODUCT_NOT_FOUND',
        'Medicine product not found.',
        'ওষুধটি পাওয়া যায়নি।',
      );
    }

    final effTenant = targetTenantId ?? actorTenantId;
    double effectiveMrp = base.mrpUnit;
    bool hasOverride = false;
    String localBrand = base.localBrandName;
    String shelf = base.shelfLocation;

    if (effTenant != null) {
      final ov = _overrideStore['$effTenant|$productId'];
      if (ov != null) {
        hasOverride = true;
        effectiveMrp = ov['customMrp'] as double;
        localBrand = ov['localBrand'] as String;
        shelf = ov['shelf'] as String;
      }
    }

    final recall = _recallStore[productId];
    final isRecalled = base.isRecalled || (recall != null && recall.lifecycleStatus.toUpperCase() == 'RECALLED');
    final isDispensingBlocked = base.isDispensingBlocked || isRecalled;

    // Mask wholesale cost price for Cashier role
    final double? visibleCost = _isAuthorizedManager(userRole) ? base.costUnit : null;

    final hash = _computePreviewHash(base.productId, base.brandName, base.dosageForm, base.strength, effectiveMrp, isDispensingBlocked);

    final resolved = MobileMedicinePreviewRecord(
      productId: base.productId,
      brandName: base.brandName,
      brandNameBn: base.brandNameBn,
      genericName: base.genericName,
      genericNameBn: base.genericNameBn,
      manufacturer: base.manufacturer,
      dgdaDarNumber: base.dgdaDarNumber,
      curationStatus: base.curationStatus,
      dosageForm: base.dosageForm,
      strength: base.strength,
      strengthNumeric: base.strengthNumeric,
      strengthUnit: base.strengthUnit,
      strengthUnitFamily: base.strengthUnitFamily,
      route: base.route,
      primaryBarcode: base.primaryBarcode,
      mrpUnit: base.mrpUnit,
      costUnit: visibleCost,
      effectiveMrpUnit: effectiveMrp,
      hasTenantOverride: hasOverride,
      localBrandName: localBrand,
      shelfLocation: shelf,
      isPrescriptionOnly: base.isPrescriptionOnly,
      isNarcotic: base.isNarcotic,
      isAntibiotic: base.isAntibiotic,
      antimicrobialClassification: base.antimicrobialClassification,
      rxClassificationLabel: base.rxClassificationLabel,
      rxClassificationLabelBn: base.rxClassificationLabelBn,
      requiresColdChain: base.requiresColdChain,
      minTempCelsius: base.minTempCelsius,
      maxTempCelsius: base.maxTempCelsius,
      storageInstructions: base.storageInstructions,
      storageInstructionsBn: base.storageInstructionsBn,
      packagingHierarchy: base.packagingHierarchy,
      variants: base.variants,
      isRecalled: isRecalled,
      isDiscontinued: base.isDiscontinued,
      isDispensingBlocked: isDispensingBlocked,
      activeRecallNotice: recall ?? base.activeRecallNotice,
      immutablePreviewHash: hash,
    );

    if (isOffline) {
      return MobilePreviewResult.offline(resolved);
    }
    return MobilePreviewResult.success(resolved);
  }
}
