// lib/core/catalog/mobile_catalogue_recall_client.dart
// Architecture Decision: ADR-0137
// Phase 07: Milestone M04 - Shared Medicine Catalog & Dynamic Packaging Units (P137)

import 'dart:convert';
import 'dart:typed_data';

enum MobileRecallUiStatus {
  success,
  error,
  permissionDenied,
  empty,
  offline,
}

/// Standard FIPS 180-4 SHA-256 implementation in pure Dart
class MobileRecallSha256 {
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

class MobileRecallNoticeRecord {
  final String noticeId;
  final String tenantId;
  final String productId;
  final String targetName;
  String lifecycleStatus;
  final String recallScope;
  final List<String> affectedBatchNumbers;
  final String regulatoryAuthority;
  final String noticeNumber;
  final String reason;
  final DateTime effectiveDate;
  String actionRequired;
  bool isActive;
  bool get isDispensingBlocked =>
      isActive && (lifecycleStatus == 'RECALLED' || lifecycleStatus == 'WITHDRAWN' || lifecycleStatus == 'QUARANTINED');
  int versionNumber;
  String immutableHash;
  final DateTime? createdAt;
  DateTime? updatedAt;

  MobileRecallNoticeRecord({
    required this.noticeId,
    required this.tenantId,
    required this.productId,
    this.targetName = '',
    required this.lifecycleStatus,
    this.recallScope = 'NATIONWIDE_ALL_BATCHES',
    this.affectedBatchNumbers = const [],
    required this.regulatoryAuthority,
    required this.noticeNumber,
    required this.reason,
    required this.effectiveDate,
    this.actionRequired = '',
    this.isActive = true,
    required this.versionNumber,
    required this.immutableHash,
    this.createdAt,
    this.updatedAt,
  });

  factory MobileRecallNoticeRecord.fromJson(Map<String, dynamic> json) {
    return MobileRecallNoticeRecord(
      noticeId: (json['notice_id'] as String?) ?? '',
      tenantId: (json['tenant_id'] as String?) ?? 'platform',
      productId: (json['product_id'] as String?) ?? (json['non_medicine_item_id'] as String?) ?? '',
      targetName: (json['target_name'] as String?) ?? '',
      lifecycleStatus: (json['lifecycle_status'] as String?) ?? 'RECALLED',
      recallScope: (json['recall_scope'] as String?) ?? 'NATIONWIDE_ALL_BATCHES',
      affectedBatchNumbers: (json['affected_batch_numbers'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      regulatoryAuthority: (json['regulatory_authority'] as String?) ?? '',
      noticeNumber: (json['notice_number'] as String?) ?? '',
      reason: (json['reason'] as String?) ?? '',
      effectiveDate: json['effective_date'] != null
          ? DateTime.tryParse(json['effective_date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      actionRequired: (json['action_required'] as String?) ?? '',
      isActive: (json['is_active'] as bool?) ?? true,
      versionNumber: (json['version_number'] as num?)?.toInt() ?? 1,
      immutableHash: (json['immutable_hash'] as String?) ?? '',
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'notice_id': noticeId,
        'tenant_id': tenantId,
        'product_id': productId,
        'target_name': targetName,
        'lifecycle_status': lifecycleStatus,
        'recall_scope': recallScope,
        'affected_batch_numbers': affectedBatchNumbers,
        'regulatory_authority': regulatoryAuthority,
        'notice_number': noticeNumber,
        'reason': reason,
        'effective_date': effectiveDate.toIso8601String(),
        'action_required': actionRequired,
        'is_active': isActive,
        'is_dispensing_blocked': isDispensingBlocked,
        'version_number': versionNumber,
        'immutable_hash': immutableHash,
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };
}

class MobileDispenseCheckResult {
  final bool blocked;
  final String lifecycleStatus;
  final String noticeNumber;
  final String reason;
  final String actionRequired;
  final List<String> affectedBatchNumbers;

  MobileDispenseCheckResult({
    required this.blocked,
    required this.lifecycleStatus,
    this.noticeNumber = '',
    this.reason = '',
    this.actionRequired = '',
    this.affectedBatchNumbers = const [],
  });
}

class MobileRecallResult<T> {
  final MobileRecallUiStatus status;
  final T? data;
  final String? errorCode;
  final String messageEn;
  final String messageBn;

  const MobileRecallResult._({
    required this.status,
    this.data,
    this.errorCode,
    required this.messageEn,
    required this.messageBn,
  });

  factory MobileRecallResult.success(T data) => MobileRecallResult._(
        status: MobileRecallUiStatus.success,
        data: data,
        messageEn: 'Operation completed successfully.',
        messageBn: 'অপারেশন সফলভাবে সম্পন্ন হয়েছে।',
      );

  factory MobileRecallResult.empty(String en, String bn) => MobileRecallResult._(
        status: MobileRecallUiStatus.empty,
        errorCode: 'EMPTY_RESULT',
        messageEn: en,
        messageBn: bn,
      );

  factory MobileRecallResult.offline(T data) => MobileRecallResult._(
        status: MobileRecallUiStatus.offline,
        data: data,
        errorCode: 'STATUS_OFFLINE_CACHE',
        messageEn: 'Operating in offline cached mode.',
        messageBn: 'অফলাইন ক্যাশড মোড সক্রিয়।',
      );

  factory MobileRecallResult.permissionDenied(String code, String en, String bn) => MobileRecallResult._(
        status: MobileRecallUiStatus.permissionDenied,
        errorCode: code,
        messageEn: en,
        messageBn: bn,
      );

  factory MobileRecallResult.error(String code, String en, String bn) => MobileRecallResult._(
        status: MobileRecallUiStatus.error,
        errorCode: code,
        messageEn: en,
        messageBn: bn,
      );
}

class MobileCatalogueRecallClient {
  static int _counter = 0;
  final Map<String, MobileRecallNoticeRecord> _store = {};
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

  String _computeHash(String noticeId, String tenantId, String productId, String status, String noticeNum, int version) {
    final raw = '$noticeId|$tenantId|$productId|$status|$noticeNum|$version';
    return MobileRecallSha256.hashString(raw);
  }

  MobileRecallResult<MobileRecallNoticeRecord> publishNotice({
    required String tenantId,
    required String productId,
    String targetName = '',
    String lifecycleStatus = 'RECALLED',
    String recallScope = 'NATIONWIDE_ALL_BATCHES',
    List<String> affectedBatchNumbers = const [],
    required String regulatoryAuthority,
    required String noticeNumber,
    required String reason,
    String actionRequired = '',
    required String userRole,
  }) {
    if (!_isAuthorizedManager(userRole)) {
      return MobileRecallResult.permissionDenied(
        'ERR_STAFF_ROLE_DENIED',
        'Cashiers cannot publish, modify, or lift recall notices.',
        'ক্যাশিয়াররা রিকল নোটিশ প্রকাশ, পরিবর্তন বা প্রত্যাহার করতে পারবেন না।',
      );
    }

    if (productId.trim().isEmpty) {
      return MobileRecallResult.error(
        'ERR_INVALID_PRODUCT',
        'Product ID is required.',
        'ওষুধের আইডি প্রয়োজন।',
      );
    }

    final cleanNoticeNum = noticeNumber.trim();
    if (cleanNoticeNum.length < 3) {
      return MobileRecallResult.error(
        'ERR_INVALID_NOTICE_NUMBER',
        'Notice number must be at least 3 characters.',
        'নোটিশ নম্বর ন্যূনতম ৩ অক্ষর হতে হবে।',
      );
    }

    final cleanReason = reason.trim();
    if (cleanReason.length < 5) {
      return MobileRecallResult.error(
        'ERR_INVALID_REASON',
        'Reason must be at least 5 characters.',
        'রিকলের কারণ ন্যূনতম ৫ অক্ষর হতে হবে।',
      );
    }

    final effTenant = tenantId.trim().isEmpty ? 'platform' : tenantId.trim();
    final noticeId = 'rec-mob-${DateTime.now().microsecondsSinceEpoch.toRadixString(16)}-${++_counter}';
    final hash = _computeHash(noticeId, effTenant, productId, lifecycleStatus, cleanNoticeNum, 1);

    final record = MobileRecallNoticeRecord(
      noticeId: noticeId,
      tenantId: effTenant,
      productId: productId,
      targetName: targetName,
      lifecycleStatus: lifecycleStatus,
      recallScope: recallScope,
      affectedBatchNumbers: affectedBatchNumbers,
      regulatoryAuthority: regulatoryAuthority,
      noticeNumber: cleanNoticeNum,
      reason: cleanReason,
      effectiveDate: DateTime.now(),
      actionRequired: actionRequired,
      isActive: true,
      versionNumber: 1,
      immutableHash: hash,
      createdAt: DateTime.now(),
    );

    _store[noticeId] = record;

    if (isOffline) {
      return MobileRecallResult.offline(record);
    }
    return MobileRecallResult.success(record);
  }

  MobileRecallResult<MobileDispenseCheckResult> checkRecallStatus({
    String? tenantId,
    required String productId,
    String? batchNumber,
  }) {
    if (productId.trim().isEmpty) {
      return MobileRecallResult.empty(
        'No product specified.',
        'কোন ওষুধ নির্দিষ্ট করা হয়নি।',
      );
    }

    final cleanProd = productId.trim();
    final cleanBatch = batchNumber?.trim() ?? '';

    for (final r in _store.values) {
      if (!r.isActive) continue;
      if (tenantId != null && r.tenantId != 'platform' && r.tenantId != tenantId) {
        continue;
      }
      if (r.productId != cleanProd) continue;

      if (r.isDispensingBlocked) {
        if (r.recallScope == 'SPECIFIC_BATCHES') {
          if (cleanBatch.isNotEmpty) {
            for (final b in r.affectedBatchNumbers) {
              if (b.toLowerCase() == cleanBatch.toLowerCase()) {
                final res = MobileDispenseCheckResult(
                  blocked: true,
                  lifecycleStatus: r.lifecycleStatus,
                  noticeNumber: r.noticeNumber,
                  reason: r.reason,
                  actionRequired: r.actionRequired,
                  affectedBatchNumbers: r.affectedBatchNumbers,
                );
                return isOffline ? MobileRecallResult.offline(res) : MobileRecallResult.success(res);
              }
            }
          }
        } else {
          final res = MobileDispenseCheckResult(
            blocked: true,
            lifecycleStatus: r.lifecycleStatus,
            noticeNumber: r.noticeNumber,
            reason: r.reason,
            actionRequired: r.actionRequired,
            affectedBatchNumbers: r.affectedBatchNumbers,
          );
          return isOffline ? MobileRecallResult.offline(res) : MobileRecallResult.success(res);
        }
      } else if (r.lifecycleStatus == 'DISCONTINUED') {
        final res = MobileDispenseCheckResult(
          blocked: false,
          lifecycleStatus: 'DISCONTINUED',
          noticeNumber: r.noticeNumber,
          reason: r.reason,
          actionRequired: r.actionRequired,
          affectedBatchNumbers: const [],
        );
        return isOffline ? MobileRecallResult.offline(res) : MobileRecallResult.success(res);
      }
    }

    final safe = MobileDispenseCheckResult(
      blocked: false,
      lifecycleStatus: 'ACTIVE',
      noticeNumber: '',
      reason: '',
      actionRequired: '',
      affectedBatchNumbers: const [],
    );
    return isOffline ? MobileRecallResult.offline(safe) : MobileRecallResult.success(safe);
  }

  MobileRecallResult<MobileDispenseCheckResult> validateDispense({
    String? tenantId,
    required String productId,
    String? batchNumber,
  }) {
    final check = checkRecallStatus(tenantId: tenantId, productId: productId, batchNumber: batchNumber);
    if (check.data != null && check.data!.blocked) {
      return MobileRecallResult.error(
        'ERR_PRODUCT_RECALLED_DISPENSING_BLOCKED',
        'Dispensing blocked: Product or batch has an active statutory safety recall (${check.data!.noticeNumber}).',
        'ওষুধ প্রদান নিষিদ্ধ: পণ্য বা ব্যাচটিতে সক্রিয় সরকারি সেফটি রিকল রয়েছে।',
      );
    }
    return check;
  }

  MobileRecallResult<MobileRecallNoticeRecord> liftNotice({
    required String noticeId,
    required String actorTenantId,
    required String userRole,
    String resolutionNotes = '',
  }) {
    if (!_isAuthorizedManager(userRole)) {
      return MobileRecallResult.permissionDenied(
        'ERR_STAFF_ROLE_DENIED',
        'Cashiers cannot lift recall notices.',
        'ক্যাশিয়াররা রিকল নোটিশ প্রত্যাহার করতে পারবেন না।',
      );
    }

    final r = _store[noticeId];
    if (r == null) {
      return MobileRecallResult.error(
        'ERR_NOTICE_NOT_FOUND',
        'Recall notice not found.',
        'রিকল নোটিশ পাওয়া যায়নি।',
      );
    }

    final isSuperadmin = userRole.trim().toUpperCase() == 'SUPERADMIN';
    if (!isSuperadmin && r.tenantId != 'platform' && r.tenantId != actorTenantId) {
      return MobileRecallResult.permissionDenied(
        'ERR_CROSS_TENANT_ACCESS',
        'Cannot lift recall notice belonging to another tenant.',
        'অন্য ফার্মেসির রিকল নোটিশ প্রত্যাহার করা নিষিদ্ধ।',
      );
    }

    r.isActive = false;
    r.lifecycleStatus = 'LIFTED';
    r.actionRequired = 'RECALL LIFTED: ${resolutionNotes.trim()}';
    r.versionNumber += 1;
    r.immutableHash = _computeHash(r.noticeId, r.tenantId, r.productId, r.lifecycleStatus, r.noticeNumber, r.versionNumber);
    r.updatedAt = DateTime.now();

    if (isOffline) {
      return MobileRecallResult.offline(r);
    }
    return MobileRecallResult.success(r);
  }
}
