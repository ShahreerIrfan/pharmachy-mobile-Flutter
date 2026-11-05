/// MobileReturnInspectionClient
/// Architecture Decision: ADR-0177 (P177).
/// Phase 09: Packaging, Unit Conversion, Batches & Cost Lots.
///
/// Flutter mobile client governing sales return safety inspections,
/// pharmacist verification, exact lot/batch restocking, and clinical quarantine hold routing.
library;

enum MobileReturnDisposition {
  restockApproved(
    labelEn: 'Restock to Original Batch & Lot',
    labelBn: 'মূল ব্যাচ ও লটে পুনর্বহাল',
  ),
  quarantineHold(
    labelEn: 'Quarantine Hold for QA Investigation',
    labelBn: 'কোয়ারেন্টাইন স্থিতি (বিতরণ নিষিদ্ধ)',
  ),
  damagedDestroy(
    labelEn: 'Damaged / Disposed - Do Not Restock',
    labelBn: 'নষ্ট বা বিনষ্ট / স্টক থেকে বাতিল',
  );

  final String labelEn;
  final String labelBn;

  const MobileReturnDisposition({
    required this.labelEn,
    required this.labelBn,
  });
}

class MobileSaleAllocationLookup {
  final String allocationId;
  final String tenantId;
  final String branchId;
  final String invoiceId;
  final String productId;
  final String productName;
  final String batchId;
  final String batchNumber;
  final String? costLotId;
  final int quantityBaseUnits;
  int returnedQuantityBaseUnits;
  final double unitSellingPrice;
  final double unitCost;
  final DateTime? batchExpiryDate;
  final bool isBatchQuarantined;

  MobileSaleAllocationLookup({
    required this.allocationId,
    required this.tenantId,
    required this.branchId,
    required this.invoiceId,
    required this.productId,
    required this.productName,
    required this.batchId,
    required this.batchNumber,
    this.costLotId,
    required this.quantityBaseUnits,
    this.returnedQuantityBaseUnits = 0,
    required this.unitSellingPrice,
    required this.unitCost,
    this.batchExpiryDate,
    this.isBatchQuarantined = false,
  });

  int get maxReturnableUnits =>
      (quantityBaseUnits - returnedQuantityBaseUnits) > 0
          ? (quantityBaseUnits - returnedQuantityBaseUnits)
          : 0;
}

class MobileReturnSafetyInspection {
  final String inspectionId;
  final String tenantId;
  final String branchId;
  final String allocationId;
  final String invoiceId;
  final String productId;
  final String productName;
  final String batchId;
  final String batchNumber;
  final String? costLotId;
  final int returnedQuantityBaseUnits;
  final MobileReturnDisposition disposition;
  final bool isSealIntact;
  final bool isPackagingUndamaged;
  final bool isStorageConditionVerified;
  final bool isUnexpired;
  final double? temperatureReadingCelsius;
  final String inspectorId;
  final String customerReason;
  final String inspectionNotes;
  final double refundAmount;
  final double restockedCogs;
  bool isReversed;
  String? reversalReason;
  DateTime? reversedAt;
  final DateTime createdAt;

  MobileReturnSafetyInspection({
    required this.inspectionId,
    required this.tenantId,
    required this.branchId,
    required this.allocationId,
    required this.invoiceId,
    required this.productId,
    required this.productName,
    required this.batchId,
    required this.batchNumber,
    this.costLotId,
    required this.returnedQuantityBaseUnits,
    required this.disposition,
    this.isSealIntact = true,
    this.isPackagingUndamaged = true,
    this.isStorageConditionVerified = true,
    this.isUnexpired = true,
    this.temperatureReadingCelsius,
    required this.inspectorId,
    this.customerReason = '',
    this.inspectionNotes = '',
    required this.refundAmount,
    required this.restockedCogs,
    this.isReversed = false,
    this.reversalReason,
    this.reversedAt,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'inspection_id': inspectionId,
      'tenant_id': tenantId,
      'branch_id': branchId,
      'allocation_id': allocationId,
      'invoice_id': invoiceId,
      'product_id': productId,
      'product_name': productName,
      'batch_id': batchId,
      'batch_number': batchNumber,
      'cost_lot_id': costLotId,
      'returned_quantity_base_units': returnedQuantityBaseUnits,
      'disposition': disposition.name.toUpperCase(),
      'is_seal_intact': isSealIntact,
      'is_packaging_undamaged': isPackagingUndamaged,
      'is_storage_condition_verified': isStorageConditionVerified,
      'is_unexpired': isUnexpired,
      'temperature_reading_celsius': temperatureReadingCelsius,
      'inspector_id': inspectorId,
      'customer_reason': customerReason,
      'inspection_notes': inspectionNotes,
      'refund_amount': refundAmount.toStringAsFixed(4),
      'restocked_cogs': restockedCogs.toStringAsFixed(4),
      'is_reversed': isReversed,
      'reversal_reason': reversalReason,
      'reversed_at': reversedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class MobileReturnInspectionResult<T> {
  final bool success;
  final T? data;
  final String? errorCode;
  final String messageEn;
  final String messageBn;

  const MobileReturnInspectionResult._({
    required this.success,
    this.data,
    this.errorCode,
    required this.messageEn,
    required this.messageBn,
  });

  factory MobileReturnInspectionResult.ok(T data, String msgEn, String msgBn) {
    return MobileReturnInspectionResult._(
      success: true,
      data: data,
      messageEn: msgEn,
      messageBn: msgBn,
    );
  }

  factory MobileReturnInspectionResult.error(String code, String msgEn, String msgBn) {
    return MobileReturnInspectionResult._(
      success: false,
      errorCode: code,
      messageEn: msgEn,
      messageBn: msgBn,
    );
  }
}

class MobileReturnInspectionClient {
  static int _idCounter = 0;

  final String tenantId;
  final String branchId;
  final String userRole;
  final String userId;
  final bool isOffline;
  final Map<String, MobileReturnSafetyInspection> inspectionStore;

  MobileReturnInspectionClient({
    required this.tenantId,
    required this.branchId,
    required this.userRole,
    required this.userId,
    this.isOffline = false,
    Map<String, MobileReturnSafetyInspection>? sharedStore,
  }) : inspectionStore = sharedStore ?? <String, MobileReturnSafetyInspection>{};

  bool get isPharmacistOrManager =>
      userRole.toUpperCase() == 'STAFF_PHARMACIST' ||
      userRole.toUpperCase() == 'BRANCH_MANAGER' ||
      userRole.toUpperCase() == 'PHARMACY_OWNER' ||
      userRole.toUpperCase() == 'SUPERADMIN';

  bool get isManagerOrOwner =>
      userRole.toUpperCase() == 'BRANCH_MANAGER' ||
      userRole.toUpperCase() == 'PHARMACY_OWNER' ||
      userRole.toUpperCase() == 'SUPERADMIN';

  String _generateUniqueId(String prefix) {
    _idCounter++;
    final ts = DateTime.now().millisecondsSinceEpoch % 1000000;
    return '$prefix-$ts-$_idCounter';
  }

  /// Inspect and process sales return against an exact lot allocation.
  MobileReturnInspectionResult<MobileReturnSafetyInspection> inspectAndProcessReturn({
    required MobileSaleAllocationLookup alloc,
    required int returnedQty,
    bool isSealIntact = true,
    bool isPackagingUndamaged = true,
    bool isStorageConditionVerified = true,
    bool isUnexpired = true,
    double? temperatureReadingCelsius,
    required MobileReturnDisposition disposition,
    String customerReason = '',
    String inspectionNotes = '',
  }) {
    if (!isPharmacistOrManager) {
      return MobileReturnInspectionResult.error(
        'ERR_PERMISSION_DENIED',
        'Safety inspection and return disposition requires a registered pharmacist or manager.',
        'ওষুধ ফেরত পরিদর্শন এবং পুনর্বহালের সিদ্ধান্ত কেবল রেজিস্টার্ড ফার্মাসিস্ট বা ম্যানেজারের এখতিয়ারাধীন।',
      );
    }

    if (alloc.tenantId != tenantId) {
      return MobileReturnInspectionResult.error(
        'ERR_CROSS_TENANT_ACCESS',
        'Cross-tenant return operations are strictly barred.',
        'ভিন্ন প্রতিষ্ঠানের ওষুধ ফেরত প্রক্রিয়া নিষিদ্ধ।',
      );
    }

    if (alloc.branchId != branchId) {
      return MobileReturnInspectionResult.error(
        'ERR_CROSS_BRANCH_RETURN',
        'Return must be processed in the originating dispensing branch.',
        'ওষুধ অবশ্যই যে শাখা থেকে বিক্রি হয়েছিল সে শাখাতেই ফেরত গ্রহণ করতে হবে।',
      );
    }

    if (returnedQty <= 0) {
      return MobileReturnInspectionResult.error(
        'ERR_INVALID_QUANTITY',
        'Returned quantity must be a positive integer.',
        'ফেরত পরিমাণ অবশ্যই ধনাত্মক পূর্ণসংখ্যা হতে হবে।',
      );
    }

    final maxReturnable = alloc.maxReturnableUnits;
    if (returnedQty > maxReturnable) {
      return MobileReturnInspectionResult.error(
        'ERR_RETURN_EXCEEDS_DISPENSED',
        'Returned quantity ($returnedQty) exceeds max returnable dispensed units ($maxReturnable).',
        'ফেরতের পরিমাণ বিক্রিত অবশিষ্ট পরিমাণের চেয়ে বেশি হতে পারে না।',
      );
    }

    // Clinical safety rules for restock
    if (disposition == MobileReturnDisposition.restockApproved) {
      if (!isSealIntact || !isPackagingUndamaged || !isStorageConditionVerified || !isUnexpired) {
        return MobileReturnInspectionResult.error(
          'ERR_FAILED_SAFETY_INSPECTION_CANNOT_RESTOCK',
          'Medicine failing safety inspection cannot be restocked. Route to QUARANTINE_HOLD or DAMAGED_DESTROY.',
          'নিরাপত্তা পরীক্ষায় অকৃতকার্য ওষুধ তাকে পুনর্বহাল নিষিদ্ধ। কোয়ারেন্টাইন বা নষ্ট হিসেবে চিহ্নিত করুন।',
        );
      }

      if (alloc.batchExpiryDate != null && !alloc.batchExpiryDate!.isAfter(DateTime.now())) {
        return MobileReturnInspectionResult.error(
          'ERR_BATCH_EXPIRED_NO_RESTOCK',
          'Batch is expired. Expired stock cannot be restocked for patient dispensing.',
          'ব্যাচের মেয়াদ উত্তীর্ণ হয়েছে। মেয়াদোত্তীর্ণ ওষুধ বিক্রির জন্য পুনরায় তাকে ওঠানো নিষিদ্ধ।',
        );
      }

      if (alloc.isBatchQuarantined) {
        return MobileReturnInspectionResult.error(
          'ERR_BATCH_QUARANTINED_NO_RESTOCK',
          'Batch is currently quarantined. Cannot restock into active inventory.',
          'উক্ত ব্যাচটি বর্তমানে কোয়ারেন্টাইনে রয়েছে। সক্রিয় স্টকে যোগ করা সম্ভব নয়।',
        );
      }
    }

    final refundAmount = (alloc.unitSellingPrice * returnedQty * 10000).round() / 10000.0;
    final restockedCogs = disposition == MobileReturnDisposition.restockApproved
        ? (alloc.unitCost * returnedQty * 10000).round() / 10000.0
        : 0.0;

    alloc.returnedQuantityBaseUnits += returnedQty;

    final inspectionId = _generateUniqueId('retinsp');
    final inspection = MobileReturnSafetyInspection(
      inspectionId: inspectionId,
      tenantId: tenantId,
      branchId: branchId,
      allocationId: alloc.allocationId,
      invoiceId: alloc.invoiceId,
      productId: alloc.productId,
      productName: alloc.productName,
      batchId: alloc.batchId,
      batchNumber: alloc.batchNumber,
      costLotId: alloc.costLotId,
      returnedQuantityBaseUnits: returnedQty,
      disposition: disposition,
      isSealIntact: isSealIntact,
      isPackagingUndamaged: isPackagingUndamaged,
      isStorageConditionVerified: isStorageConditionVerified,
      isUnexpired: isUnexpired,
      temperatureReadingCelsius: temperatureReadingCelsius,
      inspectorId: userId,
      customerReason: customerReason,
      inspectionNotes: inspectionNotes,
      refundAmount: refundAmount,
      restockedCogs: restockedCogs,
      createdAt: DateTime.now(),
    );

    inspectionStore[inspectionId] = inspection;

    return MobileReturnInspectionResult.ok(
      inspection,
      'Return safety inspection processed successfully.',
      'ফেরত ওষুধের নিরাপত্তা পরিদর্শন ও স্টক সমন্বয় সফলভাবে সম্পন্ন হয়েছে।',
    );
  }

  /// Reverse an approved return inspection.
  MobileReturnInspectionResult<MobileReturnSafetyInspection> reverseInspection({
    required String inspectionId,
    required String reason,
  }) {
    if (!isManagerOrOwner) {
      return MobileReturnInspectionResult.error(
        'ERR_PERMISSION_DENIED',
        'Only branch managers or owners can reverse return safety inspections.',
        'কেবল ব্রাঞ্চ ম্যানেজার বা মালিক ওষুধ ফেরত সিদ্ধান্ত বাতিল করতে পারেন।',
      );
    }

    if (reason.trim().length < 10) {
      return MobileReturnInspectionResult.error(
        'ERR_AUDIT_REASON_REQUIRED',
        'A valid reason of at least 10 characters is required for inspection reversal.',
        'ফেরত সিদ্ধান্ত বাতিলের জন্য ন্যূনতম ১০ অক্ষরের সুস্পষ্ট কারণ আবশ্যক।',
      );
    }

    final existing = inspectionStore[inspectionId];
    if (existing == null) {
      return MobileReturnInspectionResult.error(
        'ERR_INSPECTION_NOT_FOUND',
        'Return safety inspection record not found.',
        'ফেরত পরিদর্শনের রেকর্ড পাওয়া যায়নি।',
      );
    }

    if (existing.tenantId != tenantId || existing.branchId != branchId) {
      return MobileReturnInspectionResult.error(
        'ERR_CROSS_BRANCH_ACCESS',
        'Cannot reverse inspection from another branch or tenant.',
        'ভিন্ন শাখা বা প্রতিষ্ঠানের পরিদর্শন রেকর্ড বাতিল করা নিষিদ্ধ।',
      );
    }

    if (existing.isReversed) {
      return MobileReturnInspectionResult.error(
        'ERR_ALREADY_REVERSED',
        'This return inspection has already been reversed.',
        'এই পরিদর্শন সিদ্ধান্তটি পূর্বেই বাতিল করা হয়েছে।',
      );
    }

    existing.isReversed = true;
    existing.reversalReason = reason.trim();
    existing.reversedAt = DateTime.now();

    return MobileReturnInspectionResult.ok(
      existing,
      'Return safety inspection reversed successfully.',
      'ওষুধ ফেরত সিদ্ধান্ত সফলভাবে বাতিল ও সমন্বয় করা হয়েছে।',
    );
  }

  MobileReturnInspectionResult<List<MobileReturnSafetyInspection>> listInspections() {
    final list = inspectionStore.values
        .where((e) => e.tenantId == tenantId && e.branchId == branchId)
        .toList();
    return MobileReturnInspectionResult.ok(list, 'Inspections retrieved.', 'পরিদর্শন তালিকা প্রাপ্ত হয়েছে।');
  }

  MobileReturnInspectionResult<MobileReturnSafetyInspection> getInspection(String inspectionId) {
    final exp = inspectionStore[inspectionId];
    if (exp == null || exp.tenantId != tenantId || exp.branchId != branchId) {
      return MobileReturnInspectionResult.error('ERR_INSPECTION_NOT_FOUND', 'Inspection not found.', 'পরিদর্শন রেকর্ড পাওয়া যায়নি।');
    }
    return MobileReturnInspectionResult.ok(exp, 'Inspection found.', 'পরিদর্শন রেকর্ড প্রাপ্ত হয়েছে।');
  }
}

