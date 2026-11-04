/// MobileBatchEntityClient
/// Architecture Decision: ADR-0166 (P166).
/// Phase 09: Packaging, Unit Conversion, Batches & Cost Lots.
///
/// Mobile batch entity, FEFO allocation, and statutory recall governance
/// engine for Flutter Mobile Manager.
library;

class MobileBatchEntity {
  final String batchId;
  final String tenantId;
  final String branchId;
  final String productId;
  final String productBrandName;
  final String batchNumber;
  final String manufacturerName;
  int quantityBaseUnits;
  final double costPerUnit;
  final DateTime? manufacturingDate;
  final DateTime expiryDate;
  String status;
  final String storageCondition;
  final String lotReference;
  final int quarantineLeadDays;
  bool isQuarantined;
  String? recallNoticeId;
  String recallReason;
  bool isActive;

  MobileBatchEntity({
    required this.batchId,
    required this.tenantId,
    required this.branchId,
    required this.productId,
    this.productBrandName = '',
    required this.batchNumber,
    this.manufacturerName = '',
    required this.quantityBaseUnits,
    required this.costPerUnit,
    this.manufacturingDate,
    required this.expiryDate,
    this.status = 'ACTIVE',
    this.storageCondition = 'ROOM_TEMPERATURE_15_25C',
    this.lotReference = '',
    this.quarantineLeadDays = 30,
    this.isQuarantined = false,
    this.recallNoticeId,
    this.recallReason = '',
    this.isActive = true,
  });

  bool isExpired(DateTime asOfDate) {
    return expiryDate.isBefore(asOfDate) ||
        (expiryDate.year == asOfDate.year &&
            expiryDate.month == asOfDate.month &&
            expiryDate.day == asOfDate.day);
  }

  bool isDispensable(DateTime asOfDate) {
    if (!isActive || status != 'ACTIVE') return false;
    if (isQuarantined || recallNoticeId != null || status == 'RECALLED') {
      return false;
    }
    if (isExpired(asOfDate)) return false;
    return quantityBaseUnits > 0;
  }
}

class MobileRecallNotice {
  final String noticeId;
  final String noticeNumber;
  final String productId;
  final String recallScope; // NATIONWIDE_ALL_BATCHES or BATCH_SPECIFIC
  final Set<String> affectedBatchNumbers;
  final String reason;
  final bool isActive;

  const MobileRecallNotice({
    required this.noticeId,
    required this.noticeNumber,
    required this.productId,
    this.recallScope = 'NATIONWIDE_ALL_BATCHES',
    this.affectedBatchNumbers = const {},
    this.reason = '',
    this.isActive = true,
  });

  bool affectsBatch(String candidateBatchNumber) {
    if (!isActive) return false;
    if (recallScope == 'BATCH_SPECIFIC') {
      return affectedBatchNumbers.contains(candidateBatchNumber);
    }
    return true; // Nationwide notice covers all batches
  }
}

class MobileBatchDispenseResult {
  final bool isDispensable;
  final String? errorCode;
  final String messageEn;
  final String messageBn;
  final String? batchId;
  final int availableUnits;

  const MobileBatchDispenseResult({
    required this.isDispensable,
    this.errorCode,
    required this.messageEn,
    required this.messageBn,
    this.batchId,
    required this.availableUnits,
  });

  factory MobileBatchDispenseResult.success({
    required String batchId,
    required int availableUnits,
  }) {
    return MobileBatchDispenseResult(
      isDispensable: true,
      errorCode: null,
      messageEn: 'Batch verified and ready for dispensing.',
      messageBn: 'ব্যাচ যাচাই সফল এবং বিক্রয়ের জন্য প্রস্তুত।',
      batchId: batchId,
      availableUnits: availableUnits,
    );
  }

  factory MobileBatchDispenseResult.failed({
    required String errorCode,
    required String messageEn,
    required String messageBn,
    String? batchId,
    int availableUnits = 0,
  }) {
    return MobileBatchDispenseResult(
      isDispensable: false,
      errorCode: errorCode,
      messageEn: messageEn,
      messageBn: messageBn,
      batchId: batchId,
      availableUnits: availableUnits,
    );
  }
}

class MobileBatchValidationResult {
  final bool isValid;
  final String? errorCode;
  final String message;

  const MobileBatchValidationResult({
    required this.isValid,
    this.errorCode,
    required this.message,
  });

  factory MobileBatchValidationResult.valid() {
    return const MobileBatchValidationResult(
      isValid: true,
      errorCode: null,
      message: 'Validation passed.',
    );
  }

  factory MobileBatchValidationResult.error(String errorCode, String message) {
    return MobileBatchValidationResult(
      isValid: false,
      errorCode: errorCode,
      message: message,
    );
  }
}

class MobileBatchEntityClient {
  /// Validates chronological order of manufacturing and expiry dates.
  static MobileBatchValidationResult validateBatchDates({
    DateTime? mfgDate,
    required DateTime? expiryDate,
    required DateTime today,
  }) {
    if (expiryDate == null) {
      return MobileBatchValidationResult.error(
        'ERR_MISSING_EXPIRY_DATE',
        'Expiry date is mandatory.',
      );
    }
    if (mfgDate != null &&
        (expiryDate.isBefore(mfgDate) || expiryDate.isAtSameMomentAs(mfgDate))) {
      return MobileBatchValidationResult.error(
        'ERR_EXPIRY_BEFORE_MANUFACTURING',
        'Expiry date must be strictly after manufacturing date.',
      );
    }
    if (expiryDate.isBefore(today) ||
        (expiryDate.year == today.year &&
            expiryDate.month == today.month &&
            expiryDate.day == today.day)) {
      return MobileBatchValidationResult.error(
        'ERR_BATCH_EXPIRED_ON_CREATION',
        'Batch is expired and cannot be registered as active.',
      );
    }
    return MobileBatchValidationResult.valid();
  }

  /// Evaluates batch dispensability against recalls, expiry, quarantine, and stock.
  static MobileBatchDispenseResult evaluateDispensability({
    required MobileBatchEntity? batch,
    MobileRecallNotice? recallNotice,
    int requestedUnits = 1,
    required DateTime today,
  }) {
    if (batch == null) {
      return MobileBatchDispenseResult.failed(
        errorCode: 'ERR_BATCH_NOT_FOUND',
        messageEn: 'Batch not found in local cache.',
        messageBn: 'ক্যাশে ব্যাচ খুঁজে পাওয়া যায়নি।',
        availableUnits: 0,
      );
    }

    // Check statutory recall notice
    if (recallNotice != null && recallNotice.affectsBatch(batch.batchNumber)) {
      return MobileBatchDispenseResult.failed(
        errorCode: 'ERR_BATCH_RECALLED',
        messageEn:
            'Batch ${batch.batchNumber} is subject to statutory recall: ${recallNotice.reason}.',
        messageBn:
            'ঔষধের ব্যাচ ${batch.batchNumber} প্রত্যাহার (Recall) করা হয়েছে। বিক্রয় সম্পূর্ণ নিষিদ্ধ।',
        batchId: batch.batchId,
        availableUnits: batch.quantityBaseUnits,
      );
    }

    if (batch.status == 'RECALLED' || batch.recallNoticeId != null) {
      return MobileBatchDispenseResult.failed(
        errorCode: 'ERR_BATCH_RECALLED',
        messageEn: 'Batch ${batch.batchNumber} is recalled. Dispensing blocked.',
        messageBn:
            'ঔষধের ব্যাচ ${batch.batchNumber} প্রত্যাহারকৃত। বিক্রয় সম্পূর্ণ নিষিদ্ধ।',
        batchId: batch.batchId,
        availableUnits: batch.quantityBaseUnits,
      );
    }

    // Expiry check
    if (batch.status == 'EXPIRED' || batch.isExpired(today)) {
      return MobileBatchDispenseResult.failed(
        errorCode: 'ERR_BATCH_EXPIRED',
        messageEn:
            'Batch ${batch.batchNumber} has expired. Dispensing strictly prohibited.',
        messageBn:
            'ঔষধের ব্যাচ ${batch.batchNumber} এর মেয়াদ উত্তীর্ণ হয়ে গেছে। বিক্রয় নিষিদ্ধ।',
        batchId: batch.batchId,
        availableUnits: batch.quantityBaseUnits,
      );
    }

    // Quarantine check
    if (batch.isQuarantined || batch.status == 'QUARANTINED') {
      return MobileBatchDispenseResult.failed(
        errorCode: 'ERR_BATCH_QUARANTINED',
        messageEn:
            'Batch ${batch.batchNumber} is quarantined. Clinical clearance required.',
        messageBn:
            'ঔষধের ব্যাচ ${batch.batchNumber} কোয়ারেন্টাইনে রয়েছে। ফার্মাসিস্টের অনুমোদন আবশ্যক।',
        batchId: batch.batchId,
        availableUnits: batch.quantityBaseUnits,
      );
    }

    // Archived check
    if (!batch.isActive || batch.status == 'ARCHIVED') {
      return MobileBatchDispenseResult.failed(
        errorCode: 'ERR_BATCH_ARCHIVED',
        messageEn: 'Batch ${batch.batchNumber} is archived.',
        messageBn: 'ঔষধের ব্যাচ ${batch.batchNumber} আর্কাইভ করা হয়েছে।',
        batchId: batch.batchId,
        availableUnits: batch.quantityBaseUnits,
      );
    }

    // Stock sufficiency check
    if (batch.quantityBaseUnits < requestedUnits) {
      return MobileBatchDispenseResult.failed(
        errorCode: 'ERR_INSUFFICIENT_STOCK',
        messageEn:
            'Insufficient stock for batch ${batch.batchNumber}: requested $requestedUnits, available ${batch.quantityBaseUnits}.',
        messageBn:
            'ব্যাচ ${batch.batchNumber}-এ পর্যাপ্ত স্টক নেই: চাওয়া হয়েছে $requestedUnits, আছে ${batch.quantityBaseUnits}।',
        batchId: batch.batchId,
        availableUnits: batch.quantityBaseUnits,
      );
    }

    return MobileBatchDispenseResult.success(
      batchId: batch.batchId,
      availableUnits: batch.quantityBaseUnits,
    );
  }

  /// Selects the earliest-expiring valid dispensable batch per FEFO rules.
  static MobileBatchEntity? selectFefoBatch({
    required List<MobileBatchEntity> batches,
    String? productId,
    int requestedUnits = 1,
    required DateTime today,
  }) {
    if (batches.isEmpty) return null;

    final candidates = <MobileBatchEntity>[];
    for (final b in batches) {
      if (productId != null && b.productId != productId) continue;
      final res = evaluateDispensability(
        batch: b,
        requestedUnits: requestedUnits,
        today: today,
      );
      if (res.isDispensable) {
        candidates.add(b);
      }
    }

    if (candidates.isEmpty) return null;

    candidates.sort((a, b) {
      final cmp = a.expiryDate.compareTo(b.expiryDate);
      if (cmp != 0) return cmp;
      return a.batchNumber.compareTo(b.batchNumber);
    });

    return candidates.first;
  }

  /// Deducts integer base units and sets status to DEPLETED when stock hits 0.
  static bool deductBatchStock(MobileBatchEntity batch, int units) {
    if (units <= 0 || batch.quantityBaseUnits < units) return false;
    batch.quantityBaseUnits -= units;
    if (batch.quantityBaseUnits == 0) {
      batch.status = 'DEPLETED';
    }
    return true;
  }
}

