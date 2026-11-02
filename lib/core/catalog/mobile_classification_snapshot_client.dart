// lib/core/catalog/mobile_classification_snapshot_client.dart
// Architecture Decision: ADR-0130
// Phase 07: Milestone M04 - Shared Medicine Catalog & Dynamic Packaging Units (P130)

import 'dart:convert';
import 'dart:typed_data';

enum MobileClassificationUiStatus {
  success,
  error,
  permissionDenied,
  empty,
  offline,
}

enum MobileClassificationType {
  otc,
  prescriptionOnly,
  narcoticScheduled,
  antimicrobialAccess,
  antimicrobialWatch,
  antimicrobialReserve,
  recalled,
  banned;

  static MobileClassificationType fromWire(String raw) {
    switch (raw.toUpperCase().trim()) {
      case 'OTC':
        return MobileClassificationType.otc;
      case 'PRESCRIPTION_ONLY':
        return MobileClassificationType.prescriptionOnly;
      case 'NARCOTIC_SCHEDULED':
        return MobileClassificationType.narcoticScheduled;
      case 'ANTIMICROBIAL_ACCESS':
        return MobileClassificationType.antimicrobialAccess;
      case 'ANTIMICROBIAL_WATCH':
        return MobileClassificationType.antimicrobialWatch;
      case 'ANTIMICROBIAL_RESERVE':
        return MobileClassificationType.antimicrobialReserve;
      case 'RECALLED':
        return MobileClassificationType.recalled;
      case 'BANNED':
        return MobileClassificationType.banned;
      default:
        return MobileClassificationType.otc;
    }
  }

  String toWire() {
    switch (this) {
      case MobileClassificationType.otc:
        return 'OTC';
      case MobileClassificationType.prescriptionOnly:
        return 'PRESCRIPTION_ONLY';
      case MobileClassificationType.narcoticScheduled:
        return 'NARCOTIC_SCHEDULED';
      case MobileClassificationType.antimicrobialAccess:
        return 'ANTIMICROBIAL_ACCESS';
      case MobileClassificationType.antimicrobialWatch:
        return 'ANTIMICROBIAL_WATCH';
      case MobileClassificationType.antimicrobialReserve:
        return 'ANTIMICROBIAL_RESERVE';
      case MobileClassificationType.recalled:
        return 'RECALLED';
      case MobileClassificationType.banned:
        return 'BANNED';
    }
  }
}

class MobileMasterMedicine {
  final String productId;
  final String brandName;
  final String genericName;
  bool isPrescriptionOnly;
  bool isNarcotic;
  bool isAntibiotic;
  String curationStatus;

  MobileMasterMedicine({
    required this.productId,
    required this.brandName,
    required this.genericName,
    this.isPrescriptionOnly = false,
    this.isNarcotic = false,
    this.isAntibiotic = false,
    this.curationStatus = 'APPROVED',
  });
}

class MobileClassificationSnapshot {
  final String snapshotId;
  final String productId;
  final int versionNumber;
  final MobileClassificationType classificationType;
  final String regulatorySource;
  final DateTime effectiveFrom;
  DateTime? effectiveTo;
  bool isCurrent;
  final bool isDispensingBlocked;
  final String? reviewerEmail;
  final DateTime? reviewedAt;
  final String reviewNotes;
  final String immutableHash;
  final DateTime createdAt;

  MobileClassificationSnapshot({
    required this.snapshotId,
    required this.productId,
    required this.versionNumber,
    required this.classificationType,
    required this.regulatorySource,
    required this.effectiveFrom,
    this.effectiveTo,
    this.isCurrent = true,
    required this.isDispensingBlocked,
    this.reviewerEmail,
    this.reviewedAt,
    required this.reviewNotes,
    required this.immutableHash,
    required this.createdAt,
  });

  factory MobileClassificationSnapshot.fromJson(Map<String, dynamic> json) {
    return MobileClassificationSnapshot(
      snapshotId: (json['snapshot_id'] as String?) ?? '',
      productId: (json['product_id'] as String?) ?? '',
      versionNumber: (json['version_number'] as num?)?.toInt() ?? 1,
      classificationType: MobileClassificationType.fromWire(json['classification_type']?.toString() ?? 'OTC'),
      regulatorySource: (json['regulatory_source'] as String?) ?? '',
      effectiveFrom: DateTime.tryParse(json['effective_from']?.toString() ?? '') ?? DateTime.now(),
      effectiveTo: json['effective_to'] != null ? DateTime.tryParse(json['effective_to'].toString()) : null,
      isCurrent: (json['is_current'] as bool?) ?? true,
      isDispensingBlocked: (json['is_dispensing_blocked'] as bool?) ?? false,
      reviewerEmail: json['reviewer_email'] as String?,
      reviewedAt: json['reviewed_at'] != null ? DateTime.tryParse(json['reviewed_at'].toString()) : null,
      reviewNotes: (json['review_notes'] as String?) ?? '',
      immutableHash: (json['immutable_hash'] as String?) ?? '',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'snapshot_id': snapshotId,
      'product_id': productId,
      'version_number': versionNumber,
      'classification_type': classificationType.toWire(),
      'regulatory_source': regulatorySource,
      'effective_from': effectiveFrom.toIso8601String(),
      'effective_to': effectiveTo?.toIso8601String(),
      'is_current': isCurrent,
      'is_dispensing_blocked': isDispensingBlocked,
      'reviewer_email': reviewerEmail,
      'reviewed_at': reviewedAt?.toIso8601String(),
      'review_notes': reviewNotes,
      'immutable_hash': immutableHash,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class MobileClassificationResult<T> {
  final MobileClassificationUiStatus status;
  final T? data;
  final String? errorCode;
  final String messageEn;
  final String messageBn;

  const MobileClassificationResult({
    required this.status,
    this.data,
    this.errorCode,
    required this.messageEn,
    required this.messageBn,
  });

  static MobileClassificationResult<T> success<T>(T data) {
    return MobileClassificationResult<T>(
      status: MobileClassificationUiStatus.success,
      data: data,
      messageEn: 'Operation completed successfully.',
      messageBn: 'অপারেশন সফলভাবে সম্পন্ন হয়েছে।',
    );
  }

  static MobileClassificationResult<T> offline<T>(T data) {
    return MobileClassificationResult<T>(
      status: MobileClassificationUiStatus.offline,
      data: data,
      errorCode: 'STATUS_OFFLINE_CACHE',
      messageEn: 'Operating in offline mode. Snapshot served from local verified cache.',
      messageBn: 'অফলাইন মোড সক্রিয়। লোকাল ক্যাশ থেকে তথ্য প্রদর্শিত হচ্ছে।',
    );
  }

  static MobileClassificationResult<T> permissionDenied<T>(String code, String en, String bn) {
    return MobileClassificationResult<T>(
      status: MobileClassificationUiStatus.permissionDenied,
      errorCode: code,
      messageEn: en,
      messageBn: bn,
    );
  }

  static MobileClassificationResult<T> error<T>(String code, String en, String bn) {
    return MobileClassificationResult<T>(
      status: MobileClassificationUiStatus.error,
      errorCode: code,
      messageEn: en,
      messageBn: bn,
    );
  }

  static MobileClassificationResult<T> empty<T>(String en, String bn) {
    return MobileClassificationResult<T>(
      status: MobileClassificationUiStatus.empty,
      errorCode: 'ERR_NOT_FOUND',
      messageEn: en,
      messageBn: bn,
    );
  }
}

/// Standard FIPS 180-4 SHA-256 implementation in pure Dart
class DartSha256 {
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

class MobileClassificationSnapshotClient {
  final Map<String, MobileMasterMedicine> _medicineRegistry = {};
  final Map<String, List<MobileClassificationSnapshot>> _snapshotStore = {};
  final Map<String, MobileClassificationSnapshot> _offlineSnapshotCache = {};
  bool _isOffline = false;

  void registerMasterMedicine(MobileMasterMedicine medicine) {
    _medicineRegistry[medicine.productId] = medicine;
  }

  MobileMasterMedicine? getMasterMedicine(String productId) {
    return _medicineRegistry[productId];
  }

  void setOfflineMode(bool offline) {
    _isOffline = offline;
  }

  bool isOfflineMode() => _isOffline;

  static String computeImmutableHash(
    String productId,
    int versionNumber,
    MobileClassificationType type,
    String regulatorySource,
    DateTime effectiveFrom,
  ) {
    final raw = '$productId|$versionNumber|${type.toWire()}|${regulatorySource.trim()}|${effectiveFrom.toIso8601String()}';
    return DartSha256.hashString(raw);
  }

  MobileClassificationResult<MobileClassificationSnapshot> createSnapshot({
    required String actorRole,
    required String actorEmail,
    required String productId,
    required MobileClassificationType type,
    required String regulatorySource,
    DateTime? effectiveFrom,
    required String reviewNotes,
  }) {
    // 1. RBAC Guard: Superadmin / Platform Operator only
    final cleanRole = actorRole.trim().toUpperCase();
    if (cleanRole != 'SUPERADMIN' && cleanRole != 'SUPER_ADMIN' && cleanRole != 'PLATFORM_OPERATOR') {
      return MobileClassificationResult.permissionDenied(
        'PLATFORM_CATALOG_OWNERSHIP_PROTECTED',
        'Tenant users cannot mutate global regulatory medicine classification snapshots.',
        'টেন্যান্ট ব্যবহারকারীরা গ্লোবাল ওষুধ ক্লাসিফিকেশন স্ন্যাপশট পরিবর্তন করতে পারবেন না।',
      );
    }

    // 2. Validate Product Existence
    final product = _medicineRegistry[productId];
    if (product == null) {
      return MobileClassificationResult.error(
        'ERR_PRODUCT_NOT_FOUND',
        "Medicine product '$productId' not found in global catalog.",
        "ওষুধ প্রোডাক্ট '$productId' ক্যাটালগে পাওয়া যায়নি।",
      );
    }

    if (regulatorySource.trim().length < 3) {
      return MobileClassificationResult.error(
        'ERR_INVALID_REGULATORY_SOURCE',
        'Regulatory source reference must be at least 3 characters.',
        'রেগুলেটরি রেফারেন্স নূন্যতম ৩ অক্ষরের হতে হবে।',
      );
    }

    if (reviewNotes.trim().length < 5) {
      return MobileClassificationResult.error(
        'ERR_INVALID_REVIEW_NOTES',
        'Review and justification notes must be at least 5 characters.',
        'পর্যালোচনা নোট নূন্যতম ৫ অক্ষরের হতে হবে।',
      );
    }

    final effFrom = effectiveFrom ?? DateTime.now();
    final history = _snapshotStore.putIfAbsent(productId, () => []);

    int nextVersion = 1;
    for (final s in history) {
      if (s.isCurrent) {
        s.isCurrent = false;
        s.effectiveTo = effFrom;
      }
      if (s.versionNumber >= nextVersion) {
        nextVersion = s.versionNumber + 1;
      }
    }

    final isBlocked = (type == MobileClassificationType.recalled || type == MobileClassificationType.banned);
    final hash = computeImmutableHash(productId, nextVersion, type, regulatorySource, effFrom);

    final snapshot = MobileClassificationSnapshot(
      snapshotId: 'mcs-${DateTime.now().microsecondsSinceEpoch.toRadixString(16)}',
      productId: productId,
      versionNumber: nextVersion,
      classificationType: type,
      regulatorySource: regulatorySource.trim(),
      effectiveFrom: effFrom,
      effectiveTo: null,
      isCurrent: true,
      isDispensingBlocked: isBlocked,
      reviewerEmail: actorEmail,
      reviewedAt: DateTime.now(),
      reviewNotes: reviewNotes.trim(),
      immutableHash: hash,
      createdAt: DateTime.now(),
    );

    history.add(snapshot);
    _offlineSnapshotCache[productId] = snapshot;

    // Synchronize Master Medicine Flags
    if (type == MobileClassificationType.recalled) {
      product.curationStatus = 'RECALLED';
    } else if (type == MobileClassificationType.banned) {
      product.curationStatus = 'SUSPENDED';
    } else if (type == MobileClassificationType.prescriptionOnly) {
      product.isPrescriptionOnly = true;
    } else if (type == MobileClassificationType.narcoticScheduled) {
      product.isPrescriptionOnly = true;
      product.isNarcotic = true;
    } else if (type == MobileClassificationType.antimicrobialAccess ||
        type == MobileClassificationType.antimicrobialWatch ||
        type == MobileClassificationType.antimicrobialReserve) {
      product.isPrescriptionOnly = true;
      product.isAntibiotic = true;
    } else if (type == MobileClassificationType.otc) {
      product.isPrescriptionOnly = false;
      product.isNarcotic = false;
      product.isAntibiotic = false;
    }

    return MobileClassificationResult.success(snapshot);
  }

  MobileClassificationResult<MobileClassificationSnapshot> getCurrentSnapshot(String productId) {
    if (_isOffline) {
      final cached = _offlineSnapshotCache[productId];
      if (cached != null) {
        return MobileClassificationResult.offline(cached);
      }
      return MobileClassificationResult.empty(
        "No cached classification found offline for product '$productId'.",
        "অফলাইনে '$productId' পণ্যের কোনো ক্যাশ স্ন্যাপশট পাওয়া যায়নি।",
      );
    }

    final history = _snapshotStore[productId];
    if (history != null) {
      for (final s in history) {
        if (s.isCurrent) {
          return MobileClassificationResult.success(s);
        }
      }
    }

    return MobileClassificationResult.empty(
      "No active classification snapshot found for product '$productId'.",
      "'$productId' পণ্যের জন্য কোনো সক্রিয় ক্লাসিফিকেশন স্ন্যাপশট পাওয়া যায়নি।",
    );
  }

  MobileClassificationResult<MobileClassificationSnapshot> getPointInTimeSnapshot(
    String productId,
    DateTime targetTime,
  ) {
    final history = _snapshotStore[productId];
    if (history == null || history.isEmpty) {
      return MobileClassificationResult.empty(
        "No snapshots recorded for medicine '$productId'.",
        "ওষুধ '$productId'-এর কোনো স্ন্যাপশট রেকর্ড পাওয়া যায়নি।",
      );
    }

    MobileClassificationSnapshot? resolved;
    for (final s in history) {
      final afterOrAtFrom = !s.effectiveFrom.isAfter(targetTime);
      final beforeTo = (s.effectiveTo == null || s.effectiveTo!.isAfter(targetTime));
      if (afterOrAtFrom && beforeTo) {
        if (resolved == null || s.versionNumber > resolved.versionNumber) {
          resolved = s;
        }
      }
    }

    if (resolved == null) {
      return MobileClassificationResult.empty(
        'No classification snapshot was effective at the requested timestamp.',
        'অনুরোধকৃত সময়ে কোনো কার্যকর ক্লাসিফিকেশন স্ন্যাপশট পাওয়া যায়নি।',
      );
    }

    return MobileClassificationResult.success(resolved);
  }

  bool isDispensingBlocked(String productId) {
    final current = getCurrentSnapshot(productId);
    if (current.data != null) {
      return current.data!.isDispensingBlocked;
    }
    return false;
  }

  List<MobileClassificationSnapshot> getSnapshotHistory(String productId) {
    final history = _snapshotStore[productId];
    if (history == null) {
      return [];
    }
    final sorted = List<MobileClassificationSnapshot>.from(history);
    sorted.sort((a, b) => b.versionNumber.compareTo(a.versionNumber));
    return sorted;
  }
}
