/// MobileBatchReceiptLinkingClient
/// Architecture Decision: ADR-0168 (P168).
/// Phase 09: Packaging, Unit Conversion, Batches & Cost Lots.
///
/// Goods Received Note (GRN) to verified batch linking engine for Flutter Mobile Manager.
/// Guarantees that each receipt line binds to one or more verified manufacturer batches
/// and purchase cost lots without duplicate stock increments.
library;

class MobileBatchAllocation {
  final String linkId;
  final String batchId;
  final String batchNumber;
  int quantityBaseUnits;
  final double unitCost;
  bool isPosted;

  MobileBatchAllocation({
    required this.linkId,
    required this.batchId,
    required this.batchNumber,
    required this.quantityBaseUnits,
    required this.unitCost,
    this.isPosted = false,
  });

  Map<String, dynamic> toJson() => {
    'link_id': linkId,
    'batch_id': batchId,
    'batch_number': batchNumber,
    'quantity_base_units': quantityBaseUnits,
    'unit_cost': unitCost,
    'is_posted': isPosted,
  };
}

class MobileGrnLine {
  final String lineId;
  final String productId;
  final String productBrandName;
  final int orderedQuantityBaseUnits;
  final int receivedQuantityBaseUnits;
  final double unitCost;
  bool isFullyAllocated;
  final List<MobileBatchAllocation> allocations;

  MobileGrnLine({
    required this.lineId,
    required this.productId,
    this.productBrandName = '',
    required this.orderedQuantityBaseUnits,
    required this.receivedQuantityBaseUnits,
    required this.unitCost,
    this.isFullyAllocated = false,
    List<MobileBatchAllocation>? allocations,
  }) : allocations = allocations ?? [];

  int get allocatedQuantity {
    return allocations.fold(0, (sum, item) => sum + item.quantityBaseUnits);
  }

  bool canAddAllocation(int quantity) {
    return allocatedQuantity + quantity <= receivedQuantityBaseUnits;
  }
}

class MobileGrnNote {
  final String grnId;
  final String grnNumber;
  final String tenantId;
  final String branchId;
  final String? supplierId;
  final String supplierName;
  final String purchaseOrderNumber;
  final String supplierInvoiceNumber;
  final DateTime receiptDate;
  String status;
  final List<MobileGrnLine> lines;

  MobileGrnNote({
    required this.grnId,
    required this.grnNumber,
    required this.tenantId,
    required this.branchId,
    this.supplierId,
    this.supplierName = '',
    this.purchaseOrderNumber = '',
    this.supplierInvoiceNumber = '',
    required this.receiptDate,
    this.status = 'DRAFT',
    List<MobileGrnLine>? lines,
  }) : lines = lines ?? [];

  bool get isPosted => status.toUpperCase() == 'POSTED';

  bool get isAllLinesFullyAllocated {
    if (lines.isEmpty) return false;
    for (final line in lines) {
      if (line.allocatedQuantity != line.receivedQuantityBaseUnits) {
        return false;
      }
    }
    return true;
  }
}

class MobilePostingResult {
  final bool isSuccessful;
  final String? errorCode;
  final String messageEn;
  final String messageBn;
  final int postedAllocationsCount;
  final int totalQuantityIncremented;

  const MobilePostingResult({
    required this.isSuccessful,
    this.errorCode,
    required this.messageEn,
    required this.messageBn,
    required this.postedAllocationsCount,
    required this.totalQuantityIncremented,
  });

  factory MobilePostingResult.success({
    required int count,
    required int totalQty,
  }) {
    return MobilePostingResult(
      isSuccessful: true,
      errorCode: null,
      messageEn: 'GRN posted to inventory successfully. Stock incremented exactly once.',
      messageBn: 'জিআরএন সফলভাবে ইনভেন্টরিতে পোস্ট করা হয়েছে। স্টক নির্ভুলভাবে বৃদ্ধি পেয়েছে।',
      postedAllocationsCount: count,
      totalQuantityIncremented: totalQty,
    );
  }

  factory MobilePostingResult.failure({
    required String errorCode,
    required String messageEn,
    required String messageBn,
  }) {
    return MobilePostingResult(
      isSuccessful: false,
      errorCode: errorCode,
      messageEn: messageEn,
      messageBn: messageBn,
      postedAllocationsCount: 0,
      totalQuantityIncremented: 0,
    );
  }
}

class MobileReversalResult {
  final bool isSuccessful;
  final String? errorCode;
  final String messageEn;
  final String messageBn;
  final int totalQuantityDecremented;

  const MobileReversalResult({
    required this.isSuccessful,
    this.errorCode,
    required this.messageEn,
    required this.messageBn,
    required this.totalQuantityDecremented,
  });

  factory MobileReversalResult.success({required int totalQty}) {
    return MobileReversalResult(
      isSuccessful: true,
      errorCode: null,
      messageEn: 'GRN reversed successfully. Stock deducted cleanly.',
      messageBn: 'জিআরএন সফলভাবে রিভার্স করা হয়েছে এবং স্টক সমন্বয় করা হয়েছে।',
      totalQuantityDecremented: totalQty,
    );
  }

  factory MobileReversalResult.failure({
    required String errorCode,
    required String messageEn,
    required String messageBn,
  }) {
    return MobileReversalResult(
      isSuccessful: false,
      errorCode: errorCode,
      messageEn: messageEn,
      messageBn: messageBn,
      totalQuantityDecremented: 0,
    );
  }
}

class MobileBatchReceiptLinkingClient {
  /// Binds a batch allocation to a line, verifying capacity limits.
  static bool addBatchAllocationToLine(
    MobileGrnLine line,
    MobileBatchAllocation newAllocation,
  ) {
    if (!line.canAddAllocation(newAllocation.quantityBaseUnits)) {
      return false;
    }

    // Check if batch is already allocated on this line
    for (final existing in line.allocations) {
      if (existing.batchId == newAllocation.batchId) {
        existing.quantityBaseUnits += newAllocation.quantityBaseUnits;
        line.isFullyAllocated =
            line.allocatedQuantity == line.receivedQuantityBaseUnits;
        return true;
      }
    }

    line.allocations.add(newAllocation);
    line.isFullyAllocated =
        line.allocatedQuantity == line.receivedQuantityBaseUnits;
    return true;
  }

  /// Posts the GRN to inventory idempotently.
  /// Anti-duplicate post guardrail prevents double stock increments.
  static MobilePostingResult postGrn(
    MobileGrnNote grn,
    Map<String, int> batchStockMap,
  ) {
    // Anti-duplicate posting guardrail
    if (grn.isPosted) {
      return MobilePostingResult.failure(
        errorCode: 'ERR_ALREADY_POSTED',
        messageEn:
            'GRN is already posted. Duplicate inventory increments are strictly prohibited.',
        messageBn:
            'জিআরএন ইতোমধ্যে পোস্ট করা হয়েছে। ডুপ্লিকেট স্টক বৃদ্ধি সম্পূর্ণ নিষিদ্ধ।',
      );
    }

    final normalizedStatus = grn.status.toUpperCase();
    if (normalizedStatus == 'CANCELLED' || normalizedStatus == 'REVERSED') {
      return MobilePostingResult.failure(
        errorCode: 'ERR_GRN_INACTIVE',
        messageEn: 'Cannot post ${grn.status} GRN.',
        messageBn: 'বাতিল বা রিভার্স করা জিআরএন পোস্ট করা অসম্ভব।',
      );
    }

    if (!grn.isAllLinesFullyAllocated) {
      return MobilePostingResult.failure(
        errorCode: 'ERR_ALLOCATION_MISMATCH',
        messageEn:
            'Cannot post GRN: one or more lines are not fully allocated to verified batches.',
        messageBn:
            'জিআরএন পোস্ট করা যাচ্ছে না: এক বা একাধিক লাইনে ব্যাচ বরাদ্দ অসম্পূর্ণ।',
      );
    }

    int count = 0;
    int totalQty = 0;

    for (final line in grn.lines) {
      for (final alloc in line.allocations) {
        if (alloc.isPosted) {
          continue;
        }

        final current = batchStockMap[alloc.batchId] ?? 0;
        batchStockMap[alloc.batchId] = current + alloc.quantityBaseUnits;

        alloc.isPosted = true;
        count++;
        totalQty += alloc.quantityBaseUnits;
      }
    }

    grn.status = 'POSTED';
    return MobilePostingResult.success(count: count, totalQty: totalQty);
  }

  /// Reverses a posted GRN, deducting stock if it hasn't already been consumed.
  static MobileReversalResult reverseGrn(
    MobileGrnNote grn,
    Map<String, int> batchStockMap,
  ) {
    if (!grn.isPosted) {
      grn.status = 'CANCELLED';
      return MobileReversalResult.success(totalQty: 0);
    }

    // Verify stock has not already been consumed/dispensed
    for (final line in grn.lines) {
      for (final alloc in line.allocations) {
        if (alloc.isPosted) {
          final currentStock = batchStockMap[alloc.batchId] ?? 0;
          if (currentStock < alloc.quantityBaseUnits) {
            return MobileReversalResult.failure(
              errorCode: 'ERR_CANNOT_REVERSE_CONSUMED_STOCK',
              messageEn:
                  'Cannot reverse GRN; stock for batch ${alloc.batchNumber} has already been consumed.',
              messageBn:
                  'জিআরএন রিভার্স করা যাচ্ছে না; ব্যাচ ${alloc.batchNumber}-এর স্টক ইতোমধ্যে বিক্রয় হয়েছে।',
            );
          }
        }
      }
    }

    int totalDecremented = 0;
    for (final line in grn.lines) {
      for (final alloc in line.allocations) {
        if (alloc.isPosted) {
          final currentStock = batchStockMap[alloc.batchId] ?? 0;
          final updated = currentStock - alloc.quantityBaseUnits;
          batchStockMap[alloc.batchId] = updated > 0 ? updated : 0;
          alloc.isPosted = false;
          totalDecremented += alloc.quantityBaseUnits;
        }
      }
    }

    grn.status = 'REVERSED';
    return MobileReversalResult.success(totalQty: totalDecremented);
  }
}

