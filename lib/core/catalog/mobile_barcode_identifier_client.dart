// lib/core/catalog/mobile_barcode_identifier_client.dart
// Architecture Decision: ADR-0136
// Phase 07: Milestone M04 - Shared Medicine Catalog & Dynamic Packaging Units (P136)

import 'dart:convert';
import 'dart:typed_data';

enum MobileBarcodeUiStatus {
  success,
  error,
  permissionDenied,
  empty,
  offline,
}

/// Standard FIPS 180-4 SHA-256 implementation in pure Dart
class MobileBarcodeSha256 {
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

class MobileBarcodeRecord {
  final String identifierId;
  final String tenantId;
  final String targetId;
  final String targetEntityType;
  final String targetName;
  final double resolvedMrp;
  final String barcodeValue;
  final String identifierType;
  final String packagingLevel;
  int priorityOrder;
  final int packQuantityMultiplier;
  final String description;
  bool isActive;
  int versionNumber;
  String immutableHash;
  final DateTime? createdAt;
  DateTime? updatedAt;

  MobileBarcodeRecord({
    required this.identifierId,
    required this.tenantId,
    required this.targetId,
    required this.targetEntityType,
    this.targetName = '',
    required this.resolvedMrp,
    required this.barcodeValue,
    required this.identifierType,
    required this.packagingLevel,
    required this.priorityOrder,
    required this.packQuantityMultiplier,
    this.description = '',
    this.isActive = true,
    required this.versionNumber,
    required this.immutableHash,
    this.createdAt,
    this.updatedAt,
  });

  factory MobileBarcodeRecord.fromJson(Map<String, dynamic> json) {
    return MobileBarcodeRecord(
      identifierId: (json['identifier_id'] as String?) ?? '',
      tenantId: (json['tenant_id'] as String?) ?? 'platform',
      targetId: (json['product_id'] as String?) ??
          (json['non_medicine_item_id'] as String?) ??
          (json['variant_id'] as String?) ??
          (json['target_id'] as String?) ??
          '',
      targetEntityType: (json['target_entity_type'] as String?) ?? 'MEDICINE',
      targetName: (json['target_name'] as String?) ?? '',
      resolvedMrp: double.tryParse(json['resolved_mrp']?.toString() ?? '0.0') ?? 0.0,
      barcodeValue: (json['barcode_value'] as String?) ?? '',
      identifierType: (json['identifier_type'] as String?) ?? 'PRIMARY_EAN13_GTIN',
      packagingLevel: (json['packaging_level'] as String?) ?? 'UNIT',
      priorityOrder: (json['priority_order'] as num?)?.toInt() ?? 1,
      packQuantityMultiplier: (json['pack_quantity_multiplier'] as num?)?.toInt() ?? 1,
      description: (json['description'] as String?) ?? '',
      isActive: (json['is_active'] as bool?) ?? true,
      versionNumber: (json['version_number'] as num?)?.toInt() ?? 1,
      immutableHash: (json['immutable_hash'] as String?) ?? '',
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'identifier_id': identifierId,
        'tenant_id': tenantId,
        'target_id': targetId,
        'target_entity_type': targetEntityType,
        'target_name': targetName,
        'resolved_mrp': resolvedMrp.toStringAsFixed(2),
        'barcode_value': barcodeValue,
        'identifier_type': identifierType,
        'packaging_level': packagingLevel,
        'priority_order': priorityOrder,
        'pack_quantity_multiplier': packQuantityMultiplier,
        'description': description,
        'is_active': isActive,
        'version_number': versionNumber,
        'immutable_hash': immutableHash,
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };
}

class MobileScanResolution {
  final bool matched;
  final String barcodeValue;
  final MobileBarcodeRecord? identifierRecord;
  final double resolvedMrp;
  final String resolvedPackagingLevel;
  final int packQuantityMultiplier;

  MobileScanResolution({
    required this.matched,
    required this.barcodeValue,
    this.identifierRecord,
    required this.resolvedMrp,
    required this.resolvedPackagingLevel,
    required this.packQuantityMultiplier,
  });

  factory MobileScanResolution.fromJson(Map<String, dynamic> json) {
    return MobileScanResolution(
      matched: (json['matched'] as bool?) ?? false,
      barcodeValue: (json['barcode_value'] as String?) ?? '',
      identifierRecord: json['identifier_record'] != null
          ? MobileBarcodeRecord.fromJson(json['identifier_record'] as Map<String, dynamic>)
          : null,
      resolvedMrp: double.tryParse(json['resolved_mrp']?.toString() ?? '0.0') ?? 0.0,
      resolvedPackagingLevel: (json['resolved_packaging_level'] as String?) ?? 'UNIT',
      packQuantityMultiplier: (json['pack_quantity_multiplier'] as num?)?.toInt() ?? 1,
    );
  }
}

class MobileBarcodeResult<T> {
  final MobileBarcodeUiStatus status;
  final T? data;
  final String? errorCode;
  final String messageEn;
  final String messageBn;

  const MobileBarcodeResult._({
    required this.status,
    this.data,
    this.errorCode,
    required this.messageEn,
    required this.messageBn,
  });

  factory MobileBarcodeResult.success(T data) => MobileBarcodeResult._(
        status: MobileBarcodeUiStatus.success,
        data: data,
        messageEn: 'Operation completed successfully.',
        messageBn: 'অপারেশন সফলভাবে সম্পন্ন হয়েছে।',
      );

  factory MobileBarcodeResult.empty(String en, String bn) => MobileBarcodeResult._(
        status: MobileBarcodeUiStatus.empty,
        errorCode: 'EMPTY_RESULT',
        messageEn: en,
        messageBn: bn,
      );

  factory MobileBarcodeResult.offline(T data) => MobileBarcodeResult._(
        status: MobileBarcodeUiStatus.offline,
        data: data,
        errorCode: 'STATUS_OFFLINE_CACHE',
        messageEn: 'Operating in offline cached mode.',
        messageBn: 'অফলাইন ক্যাশড মোড সক্রিয়।',
      );

  factory MobileBarcodeResult.permissionDenied(String code, String en, String bn) => MobileBarcodeResult._(
        status: MobileBarcodeUiStatus.permissionDenied,
        errorCode: code,
        messageEn: en,
        messageBn: bn,
      );

  factory MobileBarcodeResult.error(String code, String en, String bn) => MobileBarcodeResult._(
        status: MobileBarcodeUiStatus.error,
        errorCode: code,
        messageEn: en,
        messageBn: bn,
      );
}

class MobileBarcodeIdentifierClient {
  static int _counter = 0;
  final Map<String, MobileBarcodeRecord> _store = {};
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

  String _computeHash(String identId, String tenantId, String barcode, String type, String level, int priority, int version) {
    final raw = '$identId|$tenantId|$barcode|$type|$level|$priority|$version';
    return MobileBarcodeSha256.hashString(raw);
  }

  MobileBarcodeResult<MobileBarcodeRecord> registerBarcode({
    required String tenantId,
    required String targetId,
    String targetEntityType = 'MEDICINE',
    String targetName = '',
    double resolvedMrp = 0.0,
    required String barcodeValue,
    String identifierType = 'PRIMARY_EAN13_GTIN',
    String packagingLevel = 'UNIT',
    int? priorityOrder,
    int? packQuantityMultiplier,
    String description = '',
    required String userRole,
  }) {
    if (!_isAuthorizedManager(userRole)) {
      return MobileBarcodeResult.permissionDenied(
        'ERR_STAFF_ROLE_DENIED',
        'Cashiers cannot register or mutate barcode identifiers.',
        'ক্যাশিয়াররা নতুন বারকোড নিবন্ধন বা পরিবর্তন করতে পারবেন না।',
      );
    }

    final cleanBarcode = barcodeValue.trim();
    if (cleanBarcode.length < 3) {
      return MobileBarcodeResult.error(
        'ERR_INVALID_BARCODE',
        'Barcode must be at least 3 characters.',
        'বারকোড ন্যূনতম ৩ অক্ষর হতে হবে।',
      );
    }

    final effTenant = tenantId.trim().isEmpty ? 'platform' : tenantId.trim();

    // Check contextual uniqueness
    for (final r in _store.values) {
      if (r.isActive && (r.tenantId == 'platform' || r.tenantId == effTenant)) {
        if (r.barcodeValue.toLowerCase() == cleanBarcode.toLowerCase()) {
          if (r.targetId != targetId) {
            return MobileBarcodeResult.error(
              'ERR_BARCODE_ALREADY_ASSIGNED',
              "Barcode '$cleanBarcode' is already active and assigned to another item in tenant context.",
              'বারকোডটি ইতিমধ্যে এই ফার্মেসির অন্য পণ্যের সাথে যুক্ত।',
            );
          }
        }
      }
    }

    // Default multiplier
    int multiplier;
    if (packQuantityMultiplier != null && packQuantityMultiplier >= 1) {
      multiplier = packQuantityMultiplier;
    } else {
      if (packagingLevel == 'UNIT') {
        multiplier = 1;
      } else if (packagingLevel == 'STRIP') {
        multiplier = 10;
      } else if (packagingLevel == 'BOX') {
        multiplier = 100;
      } else if (packagingLevel == 'SHIPPER_CARTON') {
        multiplier = 1000;
      } else {
        multiplier = 1;
      }
    }

    // Default priority
    int priority;
    if (priorityOrder != null && priorityOrder >= 1) {
      priority = priorityOrder;
    } else {
      if (identifierType == 'PRIMARY_EAN13_GTIN' || identifierType == 'INTERNAL_STORE_BARCODE') {
        priority = 1;
      } else if (packagingLevel == 'STRIP') {
        priority = 2;
      } else if (packagingLevel == 'BOX') {
        priority = 3;
      } else {
        priority = 4;
      }
    }

    final identId = 'bar-mob-${DateTime.now().microsecondsSinceEpoch.toRadixString(16)}-${++_counter}';
    final hash = _computeHash(identId, effTenant, cleanBarcode, identifierType, packagingLevel, priority, 1);

    final record = MobileBarcodeRecord(
      identifierId: identId,
      tenantId: effTenant,
      targetId: targetId,
      targetEntityType: targetEntityType,
      targetName: targetName,
      resolvedMrp: resolvedMrp,
      barcodeValue: cleanBarcode,
      identifierType: identifierType,
      packagingLevel: packagingLevel,
      priorityOrder: priority,
      packQuantityMultiplier: multiplier,
      description: description,
      isActive: true,
      versionNumber: 1,
      immutableHash: hash,
      createdAt: DateTime.now(),
    );

    _store[identId] = record;

    if (isOffline) {
      return MobileBarcodeResult.offline(record);
    }
    return MobileBarcodeResult.success(record);
  }

  MobileBarcodeResult<MobileScanResolution> resolveBarcode({
    String? tenantId,
    required String scanCode,
  }) {
    final cleanCode = scanCode.trim();
    if (cleanCode.isEmpty) {
      return MobileBarcodeResult.empty(
        'No barcode scanned.',
        'কোন বারকোড স্ক্যান করা হয়নি।',
      );
    }

    final matches = <MobileBarcodeRecord>[];
    for (final r in _store.values) {
      if (!r.isActive) continue;
      if (tenantId != null && r.tenantId != 'platform' && r.tenantId != tenantId) {
        continue;
      }
      if (r.barcodeValue.toLowerCase() == cleanCode.toLowerCase()) {
        matches.add(r);
      }
    }

    if (matches.isEmpty) {
      return MobileBarcodeResult.empty(
        'Barcode not recognized in catalog.',
        'বারকোডটি ক্যাটালগে পাওয়া যায়নি।',
      );
    }

    // Sort by priorityOrder ASC (1 is highest), then versionNumber DESC
    matches.sort((a, b) {
      final cmp = a.priorityOrder.compareTo(b.priorityOrder);
      if (cmp != 0) return cmp;
      return b.versionNumber.compareTo(a.versionNumber);
    });

    final best = matches.first;
    final res = MobileScanResolution(
      matched: true,
      barcodeValue: cleanCode,
      identifierRecord: best,
      resolvedMrp: best.resolvedMrp,
      resolvedPackagingLevel: best.packagingLevel,
      packQuantityMultiplier: best.packQuantityMultiplier,
    );

    if (isOffline) {
      return MobileBarcodeResult.offline(res);
    }
    return MobileBarcodeResult.success(res);
  }

  MobileBarcodeResult<MobileBarcodeRecord> updatePriority({
    required String identifierId,
    required String actorTenantId,
    required String userRole,
    required int newPriority,
  }) {
    if (!_isAuthorizedManager(userRole)) {
      return MobileBarcodeResult.permissionDenied(
        'ERR_STAFF_ROLE_DENIED',
        'Cashiers cannot update barcode priority.',
        'ক্যাশিয়াররা বারকোড অগ্রাধিকার পরিবর্তন করতে পারবেন না।',
      );
    }

    final r = _store[identifierId];
    if (r == null) {
      return MobileBarcodeResult.error(
        'ERR_IDENTIFIER_NOT_FOUND',
        'Barcode identifier not found.',
        'বারকোড পাওয়া যায়নি।',
      );
    }

    final isSuperadmin = userRole.trim().toUpperCase() == 'SUPERADMIN';
    if (!isSuperadmin && r.tenantId != 'platform' && r.tenantId != actorTenantId) {
      return MobileBarcodeResult.permissionDenied(
        'ERR_CROSS_TENANT_ACCESS',
        'Cannot mutate barcode identifier belonging to another tenant.',
        'অন্য ফার্মেসির বারকোড পরিবর্তন করা নিষিদ্ধ।',
      );
    }

    r.priorityOrder = newPriority < 1 ? 1 : newPriority;
    r.versionNumber += 1;
    r.immutableHash = _computeHash(r.identifierId, r.tenantId, r.barcodeValue, r.identifierType, r.packagingLevel, r.priorityOrder, r.versionNumber);
    r.updatedAt = DateTime.now();

    if (isOffline) {
      return MobileBarcodeResult.offline(r);
    }
    return MobileBarcodeResult.success(r);
  }

  MobileBarcodeResult<MobileBarcodeRecord> archiveBarcode({
    required String identifierId,
    required String actorTenantId,
    required String userRole,
    String reason = '',
  }) {
    if (!_isAuthorizedManager(userRole)) {
      return MobileBarcodeResult.permissionDenied(
        'ERR_STAFF_ROLE_DENIED',
        'Cashiers cannot archive barcode identifiers.',
        'ক্যাশিয়াররা বারকোড আর্কাইভ করতে পারবেন না।',
      );
    }

    final r = _store[identifierId];
    if (r == null) {
      return MobileBarcodeResult.error(
        'ERR_IDENTIFIER_NOT_FOUND',
        'Barcode identifier not found.',
        'বারকোড পাওয়া যায়নি।',
      );
    }

    final isSuperadmin = userRole.trim().toUpperCase() == 'SUPERADMIN';
    if (!isSuperadmin && r.tenantId != 'platform' && r.tenantId != actorTenantId) {
      return MobileBarcodeResult.permissionDenied(
        'ERR_CROSS_TENANT_ACCESS',
        'Cannot archive barcode belonging to another tenant.',
        'অন্য ফার্মেসির বারকোড আর্কাইভ করা নিষিদ্ধ।',
      );
    }

    r.isActive = false;
    r.updatedAt = DateTime.now();

    if (isOffline) {
      return MobileBarcodeResult.offline(r);
    }
    return MobileBarcodeResult.success(r);
  }
}
