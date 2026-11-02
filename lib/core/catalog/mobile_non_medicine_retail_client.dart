// lib/core/catalog/mobile_non_medicine_retail_client.dart
// Architecture Decision: ADR-0135
// Phase 07: Milestone M04 - Shared Medicine Catalog & Dynamic Packaging Units (P135)

import 'dart:convert';
import 'dart:typed_data';

enum MobileNonMedicineUiStatus {
  success,
  error,
  permissionDenied,
  empty,
  offline,
}

/// Standard FIPS 180-4 SHA-256 implementation in pure Dart
class MobileRetailSha256 {
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

class MobileNonMedicineRetailItem {
  final String itemId;
  final String tenantId;
  String name;
  String nameBn;
  String category;
  String brandName;
  String manufacturerOrDistributor;
  String barcode;
  String sku;
  double mrp;
  double costPrice;
  double vatPercent;
  String unitOfMeasure;
  bool requiresColdChain;
  String storageInstructions;
  final bool isMedicine = false;
  final bool isPrescriptionOnly = false;
  final bool isAntibiotic = false;
  final bool isNarcotic = false;
  bool isActive;
  int versionNumber;
  String immutableHash;
  final DateTime? createdAt;
  DateTime? updatedAt;

  MobileNonMedicineRetailItem({
    required this.itemId,
    required this.tenantId,
    required this.name,
    this.nameBn = '',
    required this.category,
    this.brandName = '',
    this.manufacturerOrDistributor = '',
    this.barcode = '',
    this.sku = '',
    required this.mrp,
    this.costPrice = 0.0,
    this.vatPercent = 0.0,
    this.unitOfMeasure = 'PIECE',
    this.requiresColdChain = false,
    this.storageInstructions = '',
    this.isActive = true,
    required this.versionNumber,
    required this.immutableHash,
    this.createdAt,
    this.updatedAt,
  });

  factory MobileNonMedicineRetailItem.fromJson(Map<String, dynamic> json) {
    return MobileNonMedicineRetailItem(
      itemId: (json['item_id'] as String?) ?? '',
      tenantId: (json['tenant_id'] as String?) ?? 'platform',
      name: (json['name'] as String?) ?? '',
      nameBn: (json['name_bn'] as String?) ?? '',
      category: (json['category'] as String?) ?? 'SURGICAL_WOUND_CARE',
      brandName: (json['brand_name'] as String?) ?? '',
      manufacturerOrDistributor: (json['manufacturer_or_distributor'] as String?) ?? '',
      barcode: (json['barcode'] as String?) ?? '',
      sku: (json['sku'] as String?) ?? '',
      mrp: double.tryParse(json['mrp']?.toString() ?? '0.0') ?? 0.0,
      costPrice: double.tryParse(json['cost_price']?.toString() ?? '0.0') ?? 0.0,
      vatPercent: double.tryParse(json['vat_percent']?.toString() ?? '0.0') ?? 0.0,
      unitOfMeasure: (json['unit_of_measure'] as String?) ?? 'PIECE',
      requiresColdChain: (json['requires_cold_chain'] as bool?) ?? false,
      storageInstructions: (json['storage_instructions'] as String?) ?? '',
      isActive: (json['is_active'] as bool?) ?? true,
      versionNumber: (json['version_number'] as num?)?.toInt() ?? 1,
      immutableHash: (json['immutable_hash'] as String?) ?? '',
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'item_id': itemId,
        'tenant_id': tenantId,
        'name': name,
        'name_bn': nameBn,
        'category': category,
        'brand_name': brandName,
        'manufacturer_or_distributor': manufacturerOrDistributor,
        'barcode': barcode,
        'sku': sku,
        'mrp': mrp.toStringAsFixed(2),
        'cost_price': costPrice.toStringAsFixed(2),
        'vat_percent': vatPercent.toStringAsFixed(2),
        'unit_of_measure': unitOfMeasure,
        'requires_cold_chain': requiresColdChain,
        'storage_instructions': storageInstructions,
        'is_medicine': false,
        'is_prescription_only': false,
        'is_antibiotic': false,
        'is_narcotic': false,
        'is_active': isActive,
        'version_number': versionNumber,
        'immutable_hash': immutableHash,
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };
}

class MobileNonMedicineResult<T> {
  final MobileNonMedicineUiStatus status;
  final T? data;
  final String? errorCode;
  final String messageEn;
  final String messageBn;

  const MobileNonMedicineResult({
    required this.status,
    this.data,
    this.errorCode,
    required this.messageEn,
    required this.messageBn,
  });

  static MobileNonMedicineResult<T> success<T>(T data) {
    return MobileNonMedicineResult<T>(
      status: MobileNonMedicineUiStatus.success,
      data: data,
      messageEn: 'Operation completed successfully.',
      messageBn: 'অপারেশন সফলভাবে সম্পন্ন হয়েছে।',
    );
  }

  static MobileNonMedicineResult<T> empty<T>(String en, String bn) {
    return MobileNonMedicineResult<T>(
      status: MobileNonMedicineUiStatus.empty,
      errorCode: 'EMPTY_RESULT',
      messageEn: en,
      messageBn: bn,
    );
  }

  static MobileNonMedicineResult<T> offline<T>(T data) {
    return MobileNonMedicineResult<T>(
      status: MobileNonMedicineUiStatus.offline,
      data: data,
      errorCode: 'STATUS_OFFLINE_CACHE',
      messageEn: 'Operating in offline cached retail catalog mode.',
      messageBn: 'অফলাইন ক্যাশড মোড সক্রিয়।',
    );
  }

  static MobileNonMedicineResult<T> permissionDenied<T>(String code, String en, String bn) {
    return MobileNonMedicineResult<T>(
      status: MobileNonMedicineUiStatus.permissionDenied,
      errorCode: code,
      messageEn: en,
      messageBn: bn,
    );
  }

  static MobileNonMedicineResult<T> error<T>(String code, String en, String bn) {
    return MobileNonMedicineResult<T>(
      status: MobileNonMedicineUiStatus.error,
      errorCode: code,
      messageEn: en,
      messageBn: bn,
    );
  }
}

class MobileNonMedicineRetailClient {
  final Map<String, MobileNonMedicineRetailItem> _itemStore = {};
  bool isOffline = false;

  bool _isAuthorizedManager(String? role) {
    if (role == null) return false;
    final r = role.trim().toUpperCase();
    return r == 'SUPERADMIN' ||
        r == 'PLATFORM_OPERATOR' ||
        r == 'PHARMACY_OWNER' ||
        r == 'OWNER' ||
        r == 'BRANCH_MANAGER' ||
        r == 'MANAGER' ||
        r == 'STAFF_PHARMACIST' ||
        r == 'PHARMACIST';
  }

  MobileNonMedicineResult<MobileNonMedicineRetailItem> createItem({
    required String tenantId,
    required String name,
    String nameBn = '',
    required String category,
    String brandName = '',
    String manufacturerOrDistributor = '',
    String barcode = '',
    String sku = '',
    required double mrp,
    double costPrice = 0.0,
    double vatPercent = 0.0,
    String unitOfMeasure = 'PIECE',
    bool requiresColdChain = false,
    String storageInstructions = '',
    bool attemptPrescriptionFlag = false,
    bool attemptAntibioticFlag = false,
    required String userRole,
  }) {
    // Regulatory Boundary Guard
    if (attemptPrescriptionFlag || attemptAntibioticFlag) {
      return MobileNonMedicineResult.error(
        'ERR_NON_MEDICINE_REGULATORY_RESTRICTION',
        'Non-medicine retail items cannot be marked as prescription-only or antibiotic. Regulatory controls are strictly medicine-specific.',
        'নন-মেডিসিন রিটেইল পণ্যে প্রেসক্রিপশন বা অ্যান্টিবায়োটিক ফ্ল্যাগ দেওয়া সম্পূর্ণ নিষিদ্ধ।',
      );
    }

    if (!_isAuthorizedManager(userRole)) {
      return MobileNonMedicineResult.permissionDenied(
        'ERR_STAFF_ROLE_DENIED',
        'Cashiers cannot create or mutate non-medicine retail items.',
        'ক্যাশিয়াররা নতুন রিটেইল পণ্য তৈরি বা পরিবর্তন করতে পারবেন না।',
      );
    }

    if (name.trim().length < 2) {
      return MobileNonMedicineResult.error(
        'ERR_INVALID_NAME',
        'Item name must be at least 2 characters.',
        'পণ্যের নাম ন্যূনতম ২ অক্ষর হতে হবে।',
      );
    }

    if (mrp <= 0.0) {
      return MobileNonMedicineResult.error(
        'ERR_INVALID_MRP',
        'MRP must be greater than 0.00.',
        'এমআরপি অবশ্যই ০.০০ এর বেশি হতে হবে।',
      );
    }

    final cleanBarcode = barcode.trim();
    if (cleanBarcode.isNotEmpty) {
      for (final r in _itemStore.values) {
        if (r.tenantId == tenantId && r.barcode.toLowerCase() == cleanBarcode.toLowerCase()) {
          return MobileNonMedicineResult.error(
            'ERR_DUPLICATE_BARCODE',
            'Barcode already exists for this tenant.',
            'এই বারকোডের পণ্য ইতিমধ্যে বিদ্যমান।',
          );
        }
      }
    }

    final itemId = 'nmi-mob-${DateTime.now().microsecondsSinceEpoch.toRadixString(16)}';
    final now = DateTime.now().toUtc();
    final rawHash = '$itemId|$tenantId|$category|$cleanBarcode|${mrp.toStringAsFixed(2)}|${vatPercent.toStringAsFixed(2)}|1';
    final hash = MobileRetailSha256.hashString(rawHash);

    final item = MobileNonMedicineRetailItem(
      itemId: itemId,
      tenantId: tenantId,
      name: name.trim(),
      nameBn: nameBn.trim(),
      category: category,
      brandName: brandName.trim(),
      manufacturerOrDistributor: manufacturerOrDistributor.trim(),
      barcode: cleanBarcode,
      sku: sku.trim(),
      mrp: mrp,
      costPrice: costPrice,
      vatPercent: vatPercent,
      unitOfMeasure: unitOfMeasure.trim().isEmpty ? 'PIECE' : unitOfMeasure.trim(),
      requiresColdChain: requiresColdChain,
      storageInstructions: storageInstructions.trim(),
      isActive: true,
      versionNumber: 1,
      immutableHash: hash,
      createdAt: now,
      updatedAt: now,
    );

    _itemStore[itemId] = item;

    if (isOffline) {
      return MobileNonMedicineResult.offline(item);
    }
    return MobileNonMedicineResult.success(item);
  }

  MobileNonMedicineResult<MobileNonMedicineRetailItem> updateItem({
    required String itemId,
    required String actorTenantId,
    required String userRole,
    String? newName,
    double? newMrp,
    double? newCostPrice,
    bool attemptPrescriptionFlag = false,
  }) {
    if (attemptPrescriptionFlag) {
      return MobileNonMedicineResult.error(
        'ERR_NON_MEDICINE_REGULATORY_RESTRICTION',
        'Non-medicine retail items cannot be marked as prescription-only.',
        'নন-মেডিসিন রিটেইল পণ্যে প্রেসক্রিপশন ফ্ল্যাগ দেওয়া সম্পূর্ণ নিষিদ্ধ।',
      );
    }

    if (!_isAuthorizedManager(userRole)) {
      return MobileNonMedicineResult.permissionDenied(
        'ERR_STAFF_ROLE_DENIED',
        'Cashiers cannot update retail items.',
        'ক্যাশিয়াররা রিটেইল পণ্য আপডেট করতে পারবেন না।',
      );
    }

    final item = _itemStore[itemId];
    if (item == null) {
      return MobileNonMedicineResult.error(
        'ERR_ITEM_NOT_FOUND',
        'Retail item not found.',
        'পণ্যটি পাওয়া যায়নি।',
      );
    }

    final isSuperadmin = userRole.trim().toUpperCase() == 'SUPERADMIN';
    if (!isSuperadmin && item.tenantId != 'platform' && item.tenantId != actorTenantId) {
      return MobileNonMedicineResult.permissionDenied(
        'ERR_CROSS_TENANT_ACCESS',
        'Cannot mutate retail item belonging to another tenant.',
        'অন্য ফার্মেসির রিটেইল পণ্য পরিবর্তন করা সম্পূর্ণ নিষিদ্ধ।',
      );
    }

    if (newName != null && newName.trim().length >= 2) {
      item.name = newName.trim();
    }
    if (newMrp != null && newMrp > 0.0) {
      item.mrp = newMrp;
    }
    if (newCostPrice != null && newCostPrice >= 0.0) {
      item.costPrice = newCostPrice;
    }

    item.versionNumber += 1;
    final rawHash = '${item.itemId}|${item.tenantId}|${item.category}|${item.barcode}|${item.mrp.toStringAsFixed(2)}|${item.vatPercent.toStringAsFixed(2)}|${item.versionNumber}';
    item.immutableHash = MobileRetailSha256.hashString(rawHash);
    item.updatedAt = DateTime.now().toUtc();

    if (isOffline) {
      return MobileNonMedicineResult.offline(item);
    }
    return MobileNonMedicineResult.success(item);
  }

  MobileNonMedicineResult<List<MobileNonMedicineRetailItem>> searchItems({
    String? tenantId,
    String? query,
    String? category,
  }) {
    final q = query?.trim().toLowerCase() ?? '';
    final list = _itemStore.values.where((r) {
      if (tenantId != null && r.tenantId != 'platform' && r.tenantId != tenantId) {
        return false;
      }
      if (category != null && r.category != category) {
        return false;
      }
      if (q.isNotEmpty) {
        final match = r.name.toLowerCase().contains(q) ||
            r.barcode.toLowerCase().contains(q) ||
            r.brandName.toLowerCase().contains(q);
        if (!match) return false;
      }
      return true;
    }).toList();

    if (list.isEmpty) {
      return MobileNonMedicineResult.empty('No retail items found.', 'কোন রিটেইল পণ্য পাওয়া যায়নি।');
    }

    if (isOffline) {
      return MobileNonMedicineResult.offline(list);
    }
    return MobileNonMedicineResult.success(list);
  }

  MobileNonMedicineResult<MobileNonMedicineRetailItem> archiveItem({
    required String itemId,
    required String actorTenantId,
    required String userRole,
  }) {
    if (!_isAuthorizedManager(userRole)) {
      return MobileNonMedicineResult.permissionDenied(
        'ERR_STAFF_ROLE_DENIED',
        'Cashiers cannot archive retail items.',
        'ক্যাশিয়াররা রিটেইল পণ্য আর্কাইভ করতে পারবেন না।',
      );
    }

    final item = _itemStore[itemId];
    if (item == null) {
      return MobileNonMedicineResult.error('ERR_ITEM_NOT_FOUND', 'Retail item not found.', 'পণ্যটি পাওয়া যায়নি।');
    }

    final isSuperadmin = userRole.trim().toUpperCase() == 'SUPERADMIN';
    if (!isSuperadmin && item.tenantId != 'platform' && item.tenantId != actorTenantId) {
      return MobileNonMedicineResult.permissionDenied(
        'ERR_CROSS_TENANT_ACCESS',
        'Cannot archive retail item belonging to another tenant.',
        'অন্য ফার্মেসির রিটেইল পণ্য আর্কাইভ করা নিষিদ্ধ।',
      );
    }

    item.isActive = false;
    item.updatedAt = DateTime.now().toUtc();

    if (isOffline) {
      return MobileNonMedicineResult.offline(item);
    }
    return MobileNonMedicineResult.success(item);
  }
}
