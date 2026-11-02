// lib/core/catalog/mobile_regulatory_source_client.dart
// Architecture Decision: ADR-0134
// Phase 07: Milestone M04 - Shared Medicine Catalog & Dynamic Packaging Units (P134)

import 'dart:convert';
import 'dart:typed_data';

enum MobileRegulatoryUiStatus {
  success,
  error,
  permissionDenied,
  empty,
  offline,
}

/// Standard FIPS 180-4 SHA-256 implementation in pure Dart
class MobileRegulatorySha256 {
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

class MobileStorageRuleSpecs {
  final bool requiresColdChain;
  final double? minTempCelsius;
  final double? maxTempCelsius;
  final bool protectFromLight;
  final int? maxHumidityPercent;
  final String handlingInstructions;

  const MobileStorageRuleSpecs({
    this.requiresColdChain = false,
    this.minTempCelsius,
    this.maxTempCelsius,
    this.protectFromLight = false,
    this.maxHumidityPercent,
    this.handlingInstructions = '',
  });

  factory MobileStorageRuleSpecs.fromJson(Map<String, dynamic> json) {
    return MobileStorageRuleSpecs(
      requiresColdChain: (json['requires_cold_chain'] as bool?) ?? false,
      minTempCelsius: (json['min_temp_celsius'] as num?)?.toDouble(),
      maxTempCelsius: (json['max_temp_celsius'] as num?)?.toDouble(),
      protectFromLight: (json['protect_from_light'] as bool?) ?? false,
      maxHumidityPercent: (json['max_humidity_percent'] as num?)?.toInt(),
      handlingInstructions: (json['handling_instructions'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'requires_cold_chain': requiresColdChain,
        'min_temp_celsius': minTempCelsius,
        'max_temp_celsius': maxTempCelsius,
        'protect_from_light': protectFromLight,
        'max_humidity_percent': maxHumidityPercent,
        'handling_instructions': handlingInstructions,
      };
}

class MobileClassificationSpecs {
  final String classificationType;
  final bool isAntibiotic;
  final bool isNarcotic;
  final String specialDispensingConditions;

  const MobileClassificationSpecs({
    this.classificationType = 'OTC',
    this.isAntibiotic = false,
    this.isNarcotic = false,
    this.specialDispensingConditions = '',
  });

  factory MobileClassificationSpecs.fromJson(Map<String, dynamic> json) {
    return MobileClassificationSpecs(
      classificationType: (json['classification_type'] as String?) ?? 'OTC',
      isAntibiotic: (json['is_antibiotic'] as bool?) ?? false,
      isNarcotic: (json['is_narcotic'] as bool?) ?? false,
      specialDispensingConditions: (json['special_dispensing_conditions'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'classification_type': classificationType,
        'is_antibiotic': isAntibiotic,
        'is_narcotic': isNarcotic,
        'special_dispensing_conditions': specialDispensingConditions,
      };
}

class MobileRegulatorySourceAttachment {
  final String attachmentId;
  final String productId;
  final String productBrandName;
  final String sourceType;
  final String ruleTarget;
  final String documentReferenceNumber;
  final String issuingAuthority;
  final DateTime? publicationDate;
  final DateTime effectiveDate;
  final int reviewCycleMonths;
  final DateTime nextReviewDueDate;
  final String sourceUrl;
  final MobileStorageRuleSpecs? storageSpecs;
  final MobileClassificationSpecs? classificationSpecs;
  final int versionNumber;
  bool isActive;
  final String immutableSourceHash;
  final String? reviewerEmail;
  final DateTime? reviewedAt;
  String reviewNotes;
  final DateTime? createdAt;

  MobileRegulatorySourceAttachment({
    required this.attachmentId,
    required this.productId,
    required this.productBrandName,
    required this.sourceType,
    required this.ruleTarget,
    required this.documentReferenceNumber,
    required this.issuingAuthority,
    this.publicationDate,
    required this.effectiveDate,
    required this.reviewCycleMonths,
    required this.nextReviewDueDate,
    this.sourceUrl = '',
    this.storageSpecs,
    this.classificationSpecs,
    required this.versionNumber,
    this.isActive = true,
    required this.immutableSourceHash,
    this.reviewerEmail,
    this.reviewedAt,
    this.reviewNotes = '',
    this.createdAt,
  });

  factory MobileRegulatorySourceAttachment.fromJson(Map<String, dynamic> json) {
    return MobileRegulatorySourceAttachment(
      attachmentId: (json['attachment_id'] as String?) ?? '',
      productId: (json['product_id'] as String?) ?? '',
      productBrandName: (json['product_brand_name'] as String?) ?? '',
      sourceType: (json['source_type'] as String?) ?? 'DGDA_GAZETTE',
      ruleTarget: (json['rule_target'] as String?) ?? 'CLASSIFICATION_AND_STORAGE',
      documentReferenceNumber: (json['document_reference_number'] as String?) ?? '',
      issuingAuthority: (json['issuing_authority'] as String?) ?? '',
      publicationDate: json['publication_date'] != null ? DateTime.tryParse(json['publication_date'].toString()) : null,
      effectiveDate: DateTime.tryParse(json['effective_date'].toString()) ?? DateTime.now(),
      reviewCycleMonths: (json['review_cycle_months'] as num?)?.toInt() ?? 12,
      nextReviewDueDate: DateTime.tryParse(json['next_review_due_date'].toString()) ?? DateTime.now(),
      sourceUrl: (json['source_url'] as String?) ?? '',
      storageSpecs: json['storage_rule_specs'] != null
          ? MobileStorageRuleSpecs.fromJson(json['storage_rule_specs'] as Map<String, dynamic>)
          : null,
      classificationSpecs: json['classification_specs'] != null
          ? MobileClassificationSpecs.fromJson(json['classification_specs'] as Map<String, dynamic>)
          : null,
      versionNumber: (json['version_number'] as num?)?.toInt() ?? 1,
      isActive: (json['is_active'] as bool?) ?? true,
      immutableSourceHash: (json['immutable_source_hash'] as String?) ?? '',
      reviewerEmail: json['reviewer_email'] as String?,
      reviewedAt: json['reviewed_at'] != null ? DateTime.tryParse(json['reviewed_at'].toString()) : null,
      reviewNotes: (json['review_notes'] as String?) ?? '',
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'attachment_id': attachmentId,
        'product_id': productId,
        'product_brand_name': productBrandName,
        'source_type': sourceType,
        'rule_target': ruleTarget,
        'document_reference_number': documentReferenceNumber,
        'issuing_authority': issuingAuthority,
        'publication_date': publicationDate?.toIso8601String().split('T').first,
        'effective_date': effectiveDate.toIso8601String().split('T').first,
        'review_cycle_months': reviewCycleMonths,
        'next_review_due_date': nextReviewDueDate.toIso8601String().split('T').first,
        'source_url': sourceUrl,
        'storage_rule_specs': storageSpecs?.toJson(),
        'classification_specs': classificationSpecs?.toJson(),
        'version_number': versionNumber,
        'is_active': isActive,
        'immutable_source_hash': immutableSourceHash,
        'reviewer_email': reviewerEmail,
        'reviewed_at': reviewedAt?.toIso8601String(),
        'review_notes': reviewNotes,
        'created_at': createdAt?.toIso8601String(),
      };
}

class MobileRegulatoryResult<T> {
  final MobileRegulatoryUiStatus status;
  final T? data;
  final String? errorCode;
  final String messageEn;
  final String messageBn;

  const MobileRegulatoryResult({
    required this.status,
    this.data,
    this.errorCode,
    required this.messageEn,
    required this.messageBn,
  });

  static MobileRegulatoryResult<T> success<T>(T data) {
    return MobileRegulatoryResult<T>(
      status: MobileRegulatoryUiStatus.success,
      data: data,
      messageEn: 'Operation completed successfully.',
      messageBn: 'অপারেশন সফলভাবে সম্পন্ন হয়েছে।',
    );
  }

  static MobileRegulatoryResult<T> empty<T>(String en, String bn) {
    return MobileRegulatoryResult<T>(
      status: MobileRegulatoryUiStatus.empty,
      errorCode: 'EMPTY_RESULT',
      messageEn: en,
      messageBn: bn,
    );
  }

  static MobileRegulatoryResult<T> offline<T>(T data) {
    return MobileRegulatoryResult<T>(
      status: MobileRegulatoryUiStatus.offline,
      data: data,
      errorCode: 'STATUS_OFFLINE_CACHE',
      messageEn: 'Operating in offline cached regulatory mode.',
      messageBn: 'অফলাইন ক্যাশড মোড সক্রিয়।',
    );
  }

  static MobileRegulatoryResult<T> permissionDenied<T>(String code, String en, String bn) {
    return MobileRegulatoryResult<T>(
      status: MobileRegulatoryUiStatus.permissionDenied,
      errorCode: code,
      messageEn: en,
      messageBn: bn,
    );
  }

  static MobileRegulatoryResult<T> error<T>(String code, String en, String bn) {
    return MobileRegulatoryResult<T>(
      status: MobileRegulatoryUiStatus.error,
      errorCode: code,
      messageEn: en,
      messageBn: bn,
    );
  }
}

class MobileRegulatorySourceClient {
  final Map<String, MobileRegulatorySourceAttachment> _attachmentStore = {};
  final Map<String, Map<String, dynamic>> _productCatalogStore = {};
  bool isOffline = false;

  void registerProduct(String productId, Map<String, dynamic> initialAttributes) {
    _productCatalogStore[productId] = Map<String, dynamic>.from(initialAttributes);
  }

  Map<String, dynamic>? getProduct(String productId) {
    final p = _productCatalogStore[productId];
    return p != null ? Map<String, dynamic>.from(p) : null;
  }

  bool _isAuthorizedRole(String? role) {
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

  MobileRegulatoryResult<MobileRegulatorySourceAttachment> attachSource({
    required String productId,
    required String sourceType,
    required String ruleTarget,
    required String documentReferenceNumber,
    required String issuingAuthority,
    required DateTime effectiveDate,
    DateTime? publicationDate,
    int reviewCycleMonths = 12,
    DateTime? nextReviewDueDate,
    String sourceUrl = '',
    MobileStorageRuleSpecs? storageSpecs,
    MobileClassificationSpecs? classificationSpecs,
    required String userRole,
    String? reviewerEmail,
    String reviewNotes = '',
  }) {
    if (!_isAuthorizedRole(userRole)) {
      return MobileRegulatoryResult.permissionDenied(
        'ERR_STAFF_ROLE_DENIED',
        'Cashiers cannot attach or mutate regulatory and storage rules.',
        'ক্যাশিয়াররা রেগুলেটরি বা স্টোরেজ রুল পরিবর্তন করতে পারবেন না।',
      );
    }

    final product = _productCatalogStore[productId];
    if (product == null) {
      return MobileRegulatoryResult.error(
        'ERR_PRODUCT_NOT_FOUND',
        'Medicine product \'$productId\' not found.',
        'মেডিসিন পণ্যটি পাওয়া যায়নি।',
      );
    }

    if (documentReferenceNumber.trim().isEmpty) {
      return MobileRegulatoryResult.error(
        'ERR_INVALID_INPUT',
        'documentReferenceNumber is required.',
        'ডকুমেন্ট রেফারেন্স নম্বর প্রদান আবশ্যক।',
      );
    }

    final dueDate = nextReviewDueDate ??
        effectiveDate.add(Duration(days: (reviewCycleMonths > 0 ? reviewCycleMonths : 12) * 30));
    if (dueDate.isBefore(effectiveDate)) {
      return MobileRegulatoryResult.error(
        'ERR_INVALID_REVIEW_DATE',
        'next_review_due_date cannot be earlier than effective_date.',
        'পরবর্তী রিভিউয়ের তারিখ কার্যকর তারিখের পূর্বে হতে পারবে না।',
      );
    }

    // Storage Rule Validation
    if (ruleTarget == 'STORAGE_CONDITION' || ruleTarget == 'CLASSIFICATION_AND_STORAGE') {
      if (storageSpecs != null && storageSpecs.requiresColdChain) {
        if (storageSpecs.minTempCelsius == null || storageSpecs.maxTempCelsius == null) {
          return MobileRegulatoryResult.error(
            'ERR_COLD_CHAIN_SPECS_REQUIRED',
            'Cold chain storage rules require both min_temp_celsius and max_temp_celsius.',
            'কোল্ড চেইনের জন্য সর্বনিম্ন ও সর্বোচ্চ তাপমাত্রা উভয়ই আবশ্যক।',
          );
        }
        if (storageSpecs.minTempCelsius! >= storageSpecs.maxTempCelsius!) {
          return MobileRegulatoryResult.error(
            'ERR_COLD_CHAIN_BOUNDARY_VIOLATION',
            'Cold chain rule violation: min_temp_celsius must be strictly less than max_temp_celsius.',
            'কোল্ড চেইনে সর্বনিম্ন তাপমাত্রা অবশ্যই সর্বোচ্চ তাপমাত্রার কম হতে হবে।',
          );
        }
        product['requires_cold_chain'] = true;
        product['min_temp_celsius'] = storageSpecs.minTempCelsius;
        product['max_temp_celsius'] = storageSpecs.maxTempCelsius;
      } else {
        product['requires_cold_chain'] = false;
      }
    }

    // Classification Rule Validation
    if (ruleTarget == 'CLASSIFICATION' || ruleTarget == 'CLASSIFICATION_AND_STORAGE') {
      if (classificationSpecs != null) {
        final cType = classificationSpecs.classificationType.trim().toUpperCase();
        if (cType == 'PRESCRIPTION_ONLY' || cType == 'POM') {
          product['is_prescription_only'] = true;
        }
        if (classificationSpecs.isAntibiotic) {
          product['is_antibiotic'] = true;
        }
        if (classificationSpecs.isNarcotic) {
          product['is_narcotic'] = true;
        }
      }
    }

    int existingMaxVer = 0;
    for (final r in _attachmentStore.values) {
      if (r.productId == productId &&
          r.documentReferenceNumber.trim().toLowerCase() == documentReferenceNumber.trim().toLowerCase()) {
        if (r.versionNumber > existingMaxVer) {
          existingMaxVer = r.versionNumber;
        }
      }
    }
    final versionNumber = existingMaxVer + 1;

    final attachmentId = 'reg-src-mob-${DateTime.now().microsecondsSinceEpoch.toRadixString(16)}';
    final effStr = effectiveDate.toIso8601String().split('T').first;
    final hashRaw = '$productId|$documentReferenceNumber|$versionNumber|$sourceType|$ruleTarget|$effStr';
    final hash = MobileRegulatorySha256.hashString(hashRaw);

    final brandName = (product['brand_name'] as String?) ?? '';
    final now = DateTime.now().toUtc();

    final record = MobileRegulatorySourceAttachment(
      attachmentId: attachmentId,
      productId: productId,
      productBrandName: brandName,
      sourceType: sourceType,
      ruleTarget: ruleTarget,
      documentReferenceNumber: documentReferenceNumber.trim(),
      issuingAuthority: issuingAuthority.trim(),
      publicationDate: publicationDate,
      effectiveDate: effectiveDate,
      reviewCycleMonths: reviewCycleMonths,
      nextReviewDueDate: dueDate,
      sourceUrl: sourceUrl,
      storageSpecs: storageSpecs,
      classificationSpecs: classificationSpecs,
      versionNumber: versionNumber,
      isActive: true,
      immutableSourceHash: hash,
      reviewerEmail: reviewerEmail,
      reviewedAt: now,
      reviewNotes: reviewNotes,
      createdAt: now,
    );

    _attachmentStore[attachmentId] = record;
    product['regulatory_source'] = documentReferenceNumber.trim();

    if (isOffline) {
      return MobileRegulatoryResult.offline(record);
    }
    return MobileRegulatoryResult.success(record);
  }

  MobileRegulatoryResult<List<MobileRegulatorySourceAttachment>> getDueReviews(DateTime? cutoffDate) {
    final target = cutoffDate ?? DateTime.now();
    final dueList = _attachmentStore.values.where((r) {
      return r.isActive && (r.nextReviewDueDate.isBefore(target) || r.nextReviewDueDate.isAtSameMomentAs(target));
    }).toList();

    dueList.sort((a, b) => a.nextReviewDueDate.compareTo(b.nextReviewDueDate));

    if (dueList.isEmpty) {
      return MobileRegulatoryResult.empty(
        'No regulatory sources due for periodic review.',
        'পুনঃপর্যালোচনার জন্য কোন রেগুলেটরি সোর্স নেই।',
      );
    }

    if (isOffline) {
      return MobileRegulatoryResult.offline(dueList);
    }
    return MobileRegulatoryResult.success(dueList);
  }

  MobileRegulatoryResult<List<MobileRegulatorySourceAttachment>> searchAttachments({
    String? productId,
    String? search,
    String? ruleTarget,
  }) {
    final query = search?.trim().toLowerCase() ?? '';
    final results = _attachmentStore.values.where((r) {
      if (productId != null && r.productId != productId) return false;
      if (ruleTarget != null && r.ruleTarget != ruleTarget) return false;
      if (query.isNotEmpty) {
        final match = r.documentReferenceNumber.toLowerCase().contains(query) ||
            r.issuingAuthority.toLowerCase().contains(query) ||
            r.productId.toLowerCase().contains(query);
        if (!match) return false;
      }
      return true;
    }).toList();

    if (isOffline) {
      return MobileRegulatoryResult.offline(results);
    }
    return MobileRegulatoryResult.success(results);
  }

  MobileRegulatoryResult<MobileRegulatorySourceAttachment> archiveAttachment({
    required String attachmentId,
    required String userRole,
    String reason = '',
  }) {
    if (!_isAuthorizedRole(userRole)) {
      return MobileRegulatoryResult.permissionDenied(
        'ERR_STAFF_ROLE_DENIED',
        'Cashiers cannot archive regulatory source attachments.',
        'ক্যাশিয়াররা রেগুলেটরি সোর্স আর্কাইভ করতে পারবেন না।',
      );
    }

    final record = _attachmentStore[attachmentId];
    if (record == null) {
      return MobileRegulatoryResult.error(
        'ERR_ATTACHMENT_NOT_FOUND',
        'Attachment \'$attachmentId\' not found.',
        'রেগুলেটরি রেকর্ডটি পাওয়া যায়নি।',
      );
    }

    record.isActive = false;
    record.reviewNotes = ('${record.reviewNotes} [Archived: $reason]').trim();

    if (isOffline) {
      return MobileRegulatoryResult.offline(record);
    }
    return MobileRegulatoryResult.success(record);
  }
}
