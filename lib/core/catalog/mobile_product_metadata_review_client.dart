// lib/core/catalog/mobile_product_metadata_review_client.dart
// Architecture Decision: ADR-0133
// Phase 07: Milestone M04 - Shared Medicine Catalog & Dynamic Packaging Units (P133)

import 'dart:convert';
import 'dart:typed_data';

/// Standard FIPS 180-4 SHA-256 implementation in pure Dart
class ReviewSha256 {
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

enum MobileReviewUiStatus {
  success,
  error,
  permissionDenied,
  empty,
  offline,
}

class MobileFieldDiff {
  final String field;
  final dynamic oldValue;
  final dynamic newValue;

  const MobileFieldDiff({
    required this.field,
    required this.oldValue,
    required this.newValue,
  });

  factory MobileFieldDiff.fromJson(String fieldName, Map<String, dynamic> json) {
    return MobileFieldDiff(
      field: fieldName,
      oldValue: json['old_value'],
      newValue: json['new_value'],
    );
  }

  Map<String, dynamic> toJson() => {
        'old_value': oldValue,
        'new_value': newValue,
      };

  @override
  String toString() => '[$field: $oldValue -> $newValue]';
}

class MobileProductMetadataReview {
  final String reviewId;
  final String productId;
  final String productBrandName;
  final String changeType;
  String status; // PENDING_REVIEW, APPROVED, REJECTED, CHANGES_REQUESTED
  final Map<String, MobileFieldDiff> proposedDiff;
  final String? submitterEmail;
  final DateTime? submittedAt;
  String? reviewerEmail;
  DateTime? reviewedAt;
  String reviewNotes;
  String reviewHash;
  final DateTime? createdAt;

  MobileProductMetadataReview({
    required this.reviewId,
    required this.productId,
    required this.productBrandName,
    required this.changeType,
    required this.status,
    required this.proposedDiff,
    this.submitterEmail,
    this.submittedAt,
    this.reviewerEmail,
    this.reviewedAt,
    this.reviewNotes = '',
    required this.reviewHash,
    this.createdAt,
  });

  factory MobileProductMetadataReview.fromJson(Map<String, dynamic> json) {
    final rawDiff = (json['proposed_diff'] as Map<String, dynamic>?) ?? {};
    final diffMap = <String, MobileFieldDiff>{};
    rawDiff.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        diffMap[key] = MobileFieldDiff.fromJson(key, value);
      }
    });

    return MobileProductMetadataReview(
      reviewId: (json['review_id'] as String?) ?? '',
      productId: (json['product_id'] as String?) ?? '',
      productBrandName: (json['product_brand_name'] as String?) ?? '',
      changeType: (json['change_type'] as String?) ?? 'METADATA_UPDATE',
      status: (json['status'] as String?) ?? 'PENDING_REVIEW',
      proposedDiff: diffMap,
      submitterEmail: json['submitter_email'] as String?,
      submittedAt: json['submitted_at'] != null ? DateTime.tryParse(json['submitted_at'].toString()) : null,
      reviewerEmail: json['reviewer_email'] as String?,
      reviewedAt: json['reviewed_at'] != null ? DateTime.tryParse(json['reviewed_at'].toString()) : null,
      reviewNotes: (json['review_notes'] as String?) ?? '',
      reviewHash: (json['review_hash'] as String?) ?? '',
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    final diffJson = <String, dynamic>{};
    proposedDiff.forEach((k, v) => diffJson[k] = v.toJson());

    return {
      'review_id': reviewId,
      'product_id': productId,
      'product_brand_name': productBrandName,
      'change_type': changeType,
      'status': status,
      'proposed_diff': diffJson,
      'submitter_email': submitterEmail,
      'submitted_at': submittedAt?.toIso8601String(),
      'reviewer_email': reviewerEmail,
      'reviewed_at': reviewedAt?.toIso8601String(),
      'review_notes': reviewNotes,
      'review_hash': reviewHash,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}

class MobileReviewResult<T> {
  final MobileReviewUiStatus status;
  final T? data;
  final String? errorCode;
  final String messageEn;
  final String messageBn;

  const MobileReviewResult({
    required this.status,
    this.data,
    this.errorCode,
    required this.messageEn,
    required this.messageBn,
  });

  static MobileReviewResult<T> success<T>(T data) {
    return MobileReviewResult<T>(
      status: MobileReviewUiStatus.success,
      data: data,
      messageEn: 'Operation completed successfully.',
      messageBn: 'অপারেশন সফলভাবে সম্পন্ন হয়েছে।',
    );
  }

  static MobileReviewResult<T> empty<T>(String en, String bn) {
    return MobileReviewResult<T>(
      status: MobileReviewUiStatus.empty,
      errorCode: 'EMPTY_RESULT',
      messageEn: en,
      messageBn: bn,
    );
  }

  static MobileReviewResult<T> offline<T>(T data) {
    return MobileReviewResult<T>(
      status: MobileReviewUiStatus.offline,
      data: data,
      errorCode: 'STATUS_OFFLINE_CACHE',
      messageEn: 'Operating in offline cached review mode.',
      messageBn: 'অফলাইন ক্যাশড রিভিউ মোড সক্রিয়।',
    );
  }

  static MobileReviewResult<T> permissionDenied<T>(String code, String en, String bn) {
    return MobileReviewResult<T>(
      status: MobileReviewUiStatus.permissionDenied,
      errorCode: code,
      messageEn: en,
      messageBn: bn,
    );
  }

  static MobileReviewResult<T> error<T>(String code, String en, String bn) {
    return MobileReviewResult<T>(
      status: MobileReviewUiStatus.error,
      errorCode: code,
      messageEn: en,
      messageBn: bn,
    );
  }
}

class MobileProductMetadataReviewClient {
  final Map<String, MobileProductMetadataReview> _reviewStore = {};
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

  MobileReviewResult<MobileProductMetadataReview> proposeReview({
    required String productId,
    String changeType = 'METADATA_UPDATE',
    required Map<String, dynamic> proposedChanges,
    required String submitterEmail,
    required String userRole,
    String submissionNotes = '',
  }) {
    if (!_isAuthorizedRole(userRole)) {
      return MobileReviewResult.permissionDenied(
        'ERR_STAFF_ROLE_DENIED',
        'Cashiers cannot propose medicine metadata changes.',
        'ক্যাশিয়াররা মেডিসিন মেটাডাটা রিভিউ প্রস্তাব করতে পারবেন না।',
      );
    }

    final product = _productCatalogStore[productId];
    if (product == null) {
      return MobileReviewResult.error(
        'ERR_PRODUCT_NOT_FOUND',
        'Medicine product \'$productId\' not found in catalog.',
        'মেডিসিন পণ্যটি ক্যাটালগে পাওয়া যায়নি।',
      );
    }

    if (proposedChanges.isEmpty) {
      return MobileReviewResult.error(
        'ERR_NO_PROPOSED_CHANGES',
        'No metadata fields proposed for review.',
        'রিভিউ করার জন্য কোন ফিল্ড পাওয়া যায়নি।',
      );
    }

    final diffMap = <String, MobileFieldDiff>{};
    proposedChanges.forEach((field, newVal) {
      final oldVal = product[field];
      diffMap[field] = MobileFieldDiff(field: field, oldValue: oldVal, newValue: newVal);
    });

    final reviewId = 'rev-mob-${DateTime.now().microsecondsSinceEpoch.toRadixString(16)}';
    final now = DateTime.now().toUtc();
    final brandName = (product['brand_name'] as String?) ?? '';

    final hash = _computeReviewHash(reviewId, productId, 'PENDING_REVIEW', now.toIso8601String());

    final review = MobileProductMetadataReview(
      reviewId: reviewId,
      productId: productId,
      productBrandName: brandName,
      changeType: changeType,
      status: 'PENDING_REVIEW',
      proposedDiff: diffMap,
      submitterEmail: submitterEmail,
      submittedAt: now,
      reviewHash: hash,
      createdAt: now,
    );

    _reviewStore[reviewId] = review;
    product['curation_status'] = 'UNDER_REVIEW';

    if (isOffline) {
      return MobileReviewResult.offline(review);
    }
    return MobileReviewResult.success(review);
  }

  MobileReviewResult<MobileProductMetadataReview> approveReview({
    required String reviewId,
    required String reviewerEmail,
    required String reviewerRole,
    required String reviewNotes,
  }) {
    if (!_isAuthorizedRole(reviewerRole)) {
      return MobileReviewResult.permissionDenied(
        'ERR_STAFF_ROLE_DENIED',
        'Cashiers cannot approve medicine metadata reviews.',
        'ক্যাশিয়াররা মেডিসিন মেটাডাটা রিভিউ অনুমোদন করতে পারবেন না।',
      );
    }

    final review = _reviewStore[reviewId];
    if (review == null) {
      return MobileReviewResult.error(
        'ERR_REVIEW_NOT_FOUND',
        'Review record \'$reviewId\' not found.',
        'রিভিউ রেকর্ডটি পাওয়া যায়নি।',
      );
    }

    if (review.status != 'PENDING_REVIEW') {
      return MobileReviewResult.error(
        'ERR_REVIEW_ALREADY_DECIDED',
        'Review has already been finalized as ${review.status}',
        'রিভিউটি ইতিমধ্যে নিষ্পন্ন হয়েছে।',
      );
    }

    // Four-Eyes Principle / Dual Control
    final isSuperAdmin = reviewerRole.trim().toUpperCase() == 'SUPERADMIN';
    if (review.submitterEmail != null &&
        review.submitterEmail!.trim().toLowerCase() == reviewerEmail.trim().toLowerCase() &&
        !isSuperAdmin) {
      return MobileReviewResult.permissionDenied(
        'ERR_FOUR_EYES_PRINCIPLE_VIOLATION',
        'Submitter cannot approve their own review proposal under Four-Eyes rule.',
        'প্রস্তাবকারী নিজে নিজের রিভিউ অনুমোদন করতে পারবেন না।',
      );
    }

    if (reviewNotes.trim().length < 5) {
      return MobileReviewResult.error(
        'ERR_INVALID_REVIEW_NOTES',
        'Review approval justification must be at least 5 characters.',
        'অনুমোদনের জন্য ন্যূনতম ৫ অক্ষরের নোট প্রদান করতে হবে।',
      );
    }

    // Atomic merge into product store
    final product = _productCatalogStore[review.productId];
    if (product != null) {
      review.proposedDiff.forEach((k, diff) {
        product[k] = diff.newValue;
      });
      product['curation_status'] = 'APPROVED';
      final currentVer = (product['version_number'] as num?)?.toInt() ?? 1;
      product['version_number'] = currentVer + 1;
    }

    final now = DateTime.now().toUtc();
    review.status = 'APPROVED';
    review.reviewerEmail = reviewerEmail;
    review.reviewedAt = now;
    review.reviewNotes = reviewNotes.trim();
    review.reviewHash = _computeReviewHash(review.reviewId, review.productId, review.status, now.toIso8601String());

    if (isOffline) {
      return MobileReviewResult.offline(review);
    }
    return MobileReviewResult.success(review);
  }

  MobileReviewResult<MobileProductMetadataReview> rejectReview({
    required String reviewId,
    required String reviewerEmail,
    required String reviewerRole,
    required String reviewNotes,
  }) {
    if (!_isAuthorizedRole(reviewerRole)) {
      return MobileReviewResult.permissionDenied(
        'ERR_STAFF_ROLE_DENIED',
        'Cashiers cannot reject medicine metadata reviews.',
        'ক্যাশিয়াররা রিভিউ প্রত্যাখ্যান করতে পারবেন না।',
      );
    }

    final review = _reviewStore[reviewId];
    if (review == null) {
      return MobileReviewResult.error(
        'ERR_REVIEW_NOT_FOUND',
        'Review record \'$reviewId\' not found.',
        'রিভিউ রেকর্ডটি পাওয়া যায়নি।',
      );
    }

    if (review.status != 'PENDING_REVIEW') {
      return MobileReviewResult.error(
        'ERR_REVIEW_ALREADY_DECIDED',
        'Review has already been finalized as ${review.status}',
        'রিভিউটি ইতিমধ্যে নিষ্পন্ন হয়েছে।',
      );
    }

    if (reviewNotes.trim().length < 5) {
      return MobileReviewResult.error(
        'ERR_INVALID_REVIEW_NOTES',
        'Review rejection justification must be at least 5 characters.',
        'প্রত্যাখ্যানের জন্য ন্যূনতম ৫ অক্ষরের কারণ প্রদান করতে হবে।',
      );
    }

    final now = DateTime.now().toUtc();
    review.status = 'REJECTED';
    review.reviewerEmail = reviewerEmail;
    review.reviewedAt = now;
    review.reviewNotes = reviewNotes.trim();
    review.reviewHash = _computeReviewHash(review.reviewId, review.productId, review.status, now.toIso8601String());

    if (isOffline) {
      return MobileReviewResult.offline(review);
    }
    return MobileReviewResult.success(review);
  }

  MobileReviewResult<List<MobileProductMetadataReview>> getPendingReviews(String? userRole) {
    if (!_isAuthorizedRole(userRole)) {
      return MobileReviewResult.permissionDenied(
        'ERR_STAFF_ROLE_DENIED',
        'Cashiers cannot access the pending metadata review queue.',
        'ক্যাশিয়াররা অপেক্ষমাণ রিভিউ তালিকা দেখতে পারবেন না।',
      );
    }

    final pending = _reviewStore.values.where((r) => r.status == 'PENDING_REVIEW').toList();

    if (pending.isEmpty) {
      return MobileReviewResult.empty(
        'No pending reviews found in queue.',
        'কোন অপেক্ষমাণ রিভিউ নেই।',
      );
    }

    if (isOffline) {
      return MobileReviewResult.offline(pending);
    }
    return MobileReviewResult.success(pending);
  }

  MobileReviewResult<List<MobileProductMetadataReview>> getReviewHistory(String productId) {
    final history = _reviewStore.values.where((r) => r.productId == productId).toList();

    if (isOffline) {
      return MobileReviewResult.offline(history);
    }
    return MobileReviewResult.success(history);
  }

  String _computeReviewHash(String reviewId, String productId, String status, String timestamp) {
    final raw = '$reviewId:$productId:$status:$timestamp';
    return ReviewSha256.hashString(raw);
  }
}
