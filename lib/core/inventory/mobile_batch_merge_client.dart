/// MobileBatchMergeClient
/// Architecture Decision: ADR-0178 (P178).
/// Phase 09: Packaging, Unit Conversion, Batches & Cost Lots.
///
/// Flutter mobile client enforcing clinical and regulatory safety guards
/// against merging incompatible pharmaceutical batches.
library;

class MobileBatchItem {
  final String batchId;
  final String tenantId;
  final String branchId;
  final String productId;
  final String productName;
  final String batchNumber;
  final DateTime expiryDate;
  int quantityBaseUnits;
  int reservedQuantityBaseUnits;
  double costPerUnit;
  String status;
  bool isQuarantined;

  MobileBatchItem({
    required this.batchId,
    required this.tenantId,
    required this.branchId,
    required this.productId,
    required this.productName,
    required this.batchNumber,
    required this.expiryDate,
    required this.quantityBaseUnits,
    this.reservedQuantityBaseUnits = 0,
    required this.costPerUnit,
    this.status = 'ACTIVE',
    this.isQuarantined = false,
  });

  int get availableQuantityBaseUnits =>
      (quantityBaseUnits - reservedQuantityBaseUnits) > 0
          ? (quantityBaseUnits - reservedQuantityBaseUnits)
          : 0;

  Map<String, dynamic> toJson() {
    return {
      'batch_id': batchId,
      'tenant_id': tenantId,
      'branch_id': branchId,
      'product_id': productId,
      'product_name': productName,
      'batch_number': batchNumber,
      'expiry_date': expiryDate.toIso8601String().split('T').first,
      'quantity_base_units': quantityBaseUnits,
      'reserved_quantity_base_units': reservedQuantityBaseUnits,
      'cost_per_unit': costPerUnit.toStringAsFixed(4),
      'status': status,
      'is_quarantined': isQuarantined,
    };
  }
}

class MobileBatchMergeRecord {
  final String mergeId;
  final String tenantId;
  final String branchId;
  final String productId;
  final String productName;
  final String sourceBatchId;
  final String targetBatchId;
  final String batchNumber;
  final DateTime expiryDate;
  final int mergedQuantityBaseUnits;
  final double sourceCostPerUnitBefore;
  final double targetCostPerUnitBefore;
  final double targetCostPerUnitAfter;
  final String reason;
  final String mergedBy;
  bool isReversed;
  String? reversalReason;
  DateTime? reversedAt;
  final DateTime createdAt;

  MobileBatchMergeRecord({
    required this.mergeId,
    required this.tenantId,
    required this.branchId,
    required this.productId,
    required this.productName,
    required this.sourceBatchId,
    required this.targetBatchId,
    required this.batchNumber,
    required this.expiryDate,
    required this.mergedQuantityBaseUnits,
    required this.sourceCostPerUnitBefore,
    required this.targetCostPerUnitBefore,
    required this.targetCostPerUnitAfter,
    required this.reason,
    required this.mergedBy,
    this.isReversed = false,
    this.reversalReason,
    this.reversedAt,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'merge_id': mergeId,
      'tenant_id': tenantId,
      'branch_id': branchId,
      'product_id': productId,
      'product_name': productName,
      'source_batch_id': sourceBatchId,
      'target_batch_id': targetBatchId,
      'batch_number': batchNumber,
      'expiry_date': expiryDate.toIso8601String().split('T').first,
      'merged_quantity_base_units': mergedQuantityBaseUnits,
      'source_cost_per_unit_before': sourceCostPerUnitBefore.toStringAsFixed(4),
      'target_cost_per_unit_before': targetCostPerUnitBefore.toStringAsFixed(4),
      'target_cost_per_unit_after': targetCostPerUnitAfter.toStringAsFixed(4),
      'reason': reason,
      'merged_by': mergedBy,
      'is_reversed': isReversed,
      'reversal_reason': reversalReason,
      'reversed_at': reversedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class MobileBatchMergeValidationResult {
  final bool canMerge;
  final List<String> blockers;
  final int projectedTargetQuantity;
  final double projectedTargetCostPerUnit;

  const MobileBatchMergeValidationResult({
    required this.canMerge,
    required this.blockers,
    required this.projectedTargetQuantity,
    required this.projectedTargetCostPerUnit,
  });
}

class MobileBatchMergeResult<T> {
  final bool success;
  final T? data;
  final String? errorCode;
  final String messageEn;
  final String messageBn;

  const MobileBatchMergeResult._({
    required this.success,
    this.data,
    this.errorCode,
    required this.messageEn,
    required this.messageBn,
  });

  factory MobileBatchMergeResult.ok(T data, String msgEn, String msgBn) {
    return MobileBatchMergeResult._(
      success: true,
      data: data,
      messageEn: msgEn,
      messageBn: msgBn,
    );
  }

  factory MobileBatchMergeResult.error(String code, String msgEn, String msgBn) {
    return MobileBatchMergeResult._(
      success: false,
      errorCode: code,
      messageEn: msgEn,
      messageBn: msgBn,
    );
  }
}

class MobileBatchMergeClient {
  static int _idCounter = 0;

  final String tenantId;
  final String branchId;
  final String userRole;
  final String userId;
  final bool isOffline;
  final Map<String, MobileBatchMergeRecord> mergeStore;

  MobileBatchMergeClient({
    required this.tenantId,
    required this.branchId,
    required this.userRole,
    required this.userId,
    this.isOffline = false,
    Map<String, MobileBatchMergeRecord>? sharedStore,
  }) : mergeStore = sharedStore ?? <String, MobileBatchMergeRecord>{};

  bool get isAuthorizedManager =>
      userRole.toUpperCase() == 'BRANCH_MANAGER' ||
      userRole.toUpperCase() == 'PHARMACY_OWNER' ||
      userRole.toUpperCase() == 'SUPERADMIN';

  String _generateUniqueId(String prefix) {
    _idCounter++;
    final ts = DateTime.now().millisecondsSinceEpoch % 1000000;
    return '$prefix-$ts-$_idCounter';
  }

  /// Inspects compatibility constraints between two batches without mutating state.
  MobileBatchMergeValidationResult validateMergeCompatibility(
    MobileBatchItem source,
    MobileBatchItem target,
  ) {
    final blockers = <String>[];

    if (source.batchId == target.batchId) {
      blockers.add('ERR_CANNOT_MERGE_SAME_BATCH');
    }

    if (source.tenantId != target.tenantId) {
      blockers.add('ERR_CROSS_TENANT_ACCESS');
    }

    if (source.branchId != target.branchId) {
      blockers.add('ERR_BRANCH_MISMATCH');
    }

    if (source.productId != target.productId) {
      blockers.add('ERR_PRODUCT_MISMATCH');
    }

    if (source.batchNumber.trim().toUpperCase() != target.batchNumber.trim().toUpperCase()) {
      blockers.add('ERR_MANUFACTURER_BATCH_MISMATCH');
    }

    final sourceExp = source.expiryDate.toIso8601String().split('T').first;
    final targetExp = target.expiryDate.toIso8601String().split('T').first;
    if (sourceExp != targetExp) {
      blockers.add('ERR_EXPIRY_DATE_MISMATCH');
    }

    final now = DateTime.now();
    if (!source.expiryDate.isAfter(now)) {
      blockers.add('ERR_SOURCE_BATCH_EXPIRED');
    }
    if (!target.expiryDate.isAfter(now)) {
      blockers.add('ERR_TARGET_BATCH_EXPIRED');
    }

    if (source.status.toUpperCase() == 'RECALLED' || target.status.toUpperCase() == 'RECALLED') {
      blockers.add('ERR_BATCH_RECALLED');
    }

    if (source.isQuarantined ||
        target.isQuarantined ||
        source.status.toUpperCase() == 'QUARANTINED' ||
        target.status.toUpperCase() == 'QUARANTINED') {
      blockers.add('ERR_BATCH_QUARANTINED');
    }

    if (source.quantityBaseUnits <= 0) {
      blockers.add('ERR_SOURCE_BATCH_EMPTY');
    }

    if (source.reservedQuantityBaseUnits > 0) {
      blockers.add('ERR_SOURCE_BATCH_HAS_RESERVATIONS');
    }

    final canMerge = blockers.isEmpty;
    final projectedQty = target.quantityBaseUnits + source.quantityBaseUnits;

    var projectedCost = target.costPerUnit;
    if (projectedQty > 0) {
      final totalValue =
          (target.costPerUnit * target.quantityBaseUnits) + (source.costPerUnit * source.quantityBaseUnits);
      projectedCost = (totalValue * 10000 / projectedQty).round() / 10000.0;
    }

    return MobileBatchMergeValidationResult(
      canMerge: canMerge,
      blockers: blockers,
      projectedTargetQuantity: projectedQty,
      projectedTargetCostPerUnit: projectedCost,
    );
  }

  /// Executes an audited batch consolidation.
  MobileBatchMergeResult<MobileBatchMergeRecord> executeMerge({
    required MobileBatchItem source,
    required MobileBatchItem target,
    required String reason,
  }) {
    if (!isAuthorizedManager) {
      return MobileBatchMergeResult.error(
        'ERR_PERMISSION_DENIED',
        'Batch consolidation and merge authorization requires a branch manager or owner.',
        'ব্যাচ একত্রীকরণ কেবল ব্রাঞ্চ ম্যানেজার বা মালিকের অনুমোদনসাপেক্ষ।',
      );
    }

    if (reason.trim().length < 10) {
      return MobileBatchMergeResult.error(
        'ERR_AUDIT_REASON_REQUIRED',
        'A valid reason of at least 10 characters is mandatory for batch consolidation.',
        'ব্যাচ একত্রীকরণের জন্য ন্যূনতম ১০ অক্ষরের সুনির্দিষ্ট কারণ উল্লেখ আবশ্যক।',
      );
    }

    final val = validateMergeCompatibility(source, target);
    if (!val.canMerge) {
      final firstBlocker = val.blockers.first;
      return MobileBatchMergeResult.error(
        firstBlocker,
        'Batch merge blocked due to clinical/regulatory incompatibility: $firstBlocker',
        'ক্লিনিক্যাল বা রেগুলেটরি বিধিনিষেধের কারণে ব্যাচ একত্রীকরণ সম্ভব নয়: $firstBlocker',
      );
    }

    final mergedQty = source.quantityBaseUnits;
    final sourceCostBefore = source.costPerUnit;
    final targetCostBefore = target.costPerUnit;
    final targetCostAfter = val.projectedTargetCostPerUnit;

    target.quantityBaseUnits += mergedQty;
    target.costPerUnit = targetCostAfter;

    source.quantityBaseUnits = 0;
    source.status = 'DEPLETED';

    final mergeId = _generateUniqueId('bmerge');
    final record = MobileBatchMergeRecord(
      mergeId: mergeId,
      tenantId: tenantId,
      branchId: branchId,
      productId: target.productId,
      productName: target.productName,
      sourceBatchId: source.batchId,
      targetBatchId: target.batchId,
      batchNumber: target.batchNumber,
      expiryDate: target.expiryDate,
      mergedQuantityBaseUnits: mergedQty,
      sourceCostPerUnitBefore: sourceCostBefore,
      targetCostPerUnitBefore: targetCostBefore,
      targetCostPerUnitAfter: targetCostAfter,
      reason: reason.trim(),
      mergedBy: userId,
      createdAt: DateTime.now(),
    );

    mergeStore[mergeId] = record;

    return MobileBatchMergeResult.ok(
      record,
      'Batch merge executed successfully.',
      'ব্যাচ সফলভাবে একত্রীকরণ এবং কস্ট সমন্বয় করা হয়েছে।',
    );
  }

  /// Reverses an executed batch merge.
  MobileBatchMergeResult<MobileBatchMergeRecord> reverseMerge({
    required String mergeId,
    required MobileBatchItem source,
    required MobileBatchItem target,
    required String reason,
  }) {
    if (!isAuthorizedManager) {
      return MobileBatchMergeResult.error(
        'ERR_PERMISSION_DENIED',
        'Only branch managers or owners can reverse a batch merge.',
        'কেবল ব্রাঞ্চ ম্যানেজার বা মালিক ব্যাচ একত্রীকরণ বাতিল করতে পারেন।',
      );
    }

    if (reason.trim().length < 10) {
      return MobileBatchMergeResult.error(
        'ERR_AUDIT_REASON_REQUIRED',
        'A valid reason of at least 10 characters is required for merge reversal.',
        'একত্রীকরণ বাতিলের জন্য ন্যূনতম ১০ অক্ষরের সুস্পষ্ট কারণ উল্লেখ আবশ্যক।',
      );
    }

    final existing = mergeStore[mergeId];
    if (existing == null) {
      return MobileBatchMergeResult.error(
        'ERR_MERGE_RECORD_NOT_FOUND',
        'Batch merge record not found.',
        'ব্যাচ একত্রীকরণ রেকর্ড পাওয়া যায়নি।',
      );
    }

    if (existing.tenantId != tenantId || existing.branchId != branchId) {
      return MobileBatchMergeResult.error(
        'ERR_CROSS_BRANCH_ACCESS',
        'Cannot reverse merge record from another branch or tenant.',
        'ভিন্ন শাখা বা প্রতিষ্ঠানের রেকর্ড বাতিল করা নিষিদ্ধ।',
      );
    }

    if (existing.isReversed) {
      return MobileBatchMergeResult.error(
        'ERR_ALREADY_REVERSED',
        'This batch merge has already been reversed.',
        'এই ব্যাচ একত্রীকরণটি পূর্বেই বাতিল করা হয়েছে।',
      );
    }

    final mergedQty = existing.mergedQuantityBaseUnits;
    if (target.availableQuantityBaseUnits < mergedQty) {
      return MobileBatchMergeResult.error(
        'ERR_INSUFFICIENT_STOCK_FOR_REVERSAL',
        'Target batch does not have sufficient unreserved stock to restore source batch.',
        'টার্গেট ব্যাচে পর্যাপ্ত মুক্ত স্টক না থাকায় একত্রীকরণ বাতিল করা সম্ভব নয়।',
      );
    }

    target.quantityBaseUnits -= mergedQty;
    target.costPerUnit = existing.targetCostPerUnitBefore;

    source.quantityBaseUnits = mergedQty;
    source.status = 'ACTIVE';
    source.costPerUnit = existing.sourceCostPerUnitBefore;

    existing.isReversed = true;
    existing.reversalReason = reason.trim();
    existing.reversedAt = DateTime.now();

    return MobileBatchMergeResult.ok(
      existing,
      'Batch merge reversed successfully.',
      'ব্যাচ একত্রীকরণ সফলভাবে বাতিল করা হয়েছে এবং স্টক পুনরুদ্ধার করা হয়েছে।',
    );
  }

  MobileBatchMergeResult<List<MobileBatchMergeRecord>> listMerges() {
    final list = mergeStore.values
        .where((e) => e.tenantId == tenantId && e.branchId == branchId)
        .toList();
    return MobileBatchMergeResult.ok(list, 'Merge records retrieved.', 'একত্রীকরণ তালিকা প্রাপ্ত হয়েছে।');
  }

  MobileBatchMergeResult<MobileBatchMergeRecord> getMerge(String mergeId) {
    final rec = mergeStore[mergeId];
    if (rec == null || rec.tenantId != tenantId || rec.branchId != branchId) {
      return MobileBatchMergeResult.error('ERR_MERGE_RECORD_NOT_FOUND', 'Merge record not found.', 'রেকর্ড পাওয়া যায়নি।');
    }
    return MobileBatchMergeResult.ok(rec, 'Merge record found.', 'রেকর্ড প্রাপ্ত হয়েছে।');
  }
}
