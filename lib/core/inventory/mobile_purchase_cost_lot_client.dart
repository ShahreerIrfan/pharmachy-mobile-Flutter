/// MobilePurchaseCostLotClient
/// Architecture Decision: ADR-0167 (P167).
/// Phase 09: Packaging, Unit Conversion, Batches & Cost Lots.
///
/// Purchase cost lot allocation, FIFO COGS derivation, and inventory asset
/// valuation engine for Flutter Mobile Manager.
library;

class MobileCostLotRecord {
  final String lotId;
  final String tenantId;
  final String branchId;
  final String productId;
  final String productBrandName;
  final String batchId;
  final String batchNumber;
  final String? supplierId;
  final String supplierName;
  final String purchaseOrderNumber;
  final String grnNumber;
  final DateTime purchaseDate;
  final double unitCost;
  final int initialQuantity;
  int remainingQuantity;
  String status;
  bool isActive;

  MobileCostLotRecord({
    required this.lotId,
    required this.tenantId,
    required this.branchId,
    required this.productId,
    this.productBrandName = '',
    required this.batchId,
    required this.batchNumber,
    this.supplierId,
    this.supplierName = '',
    this.purchaseOrderNumber = '',
    this.grnNumber = '',
    required this.purchaseDate,
    required this.unitCost,
    required this.initialQuantity,
    required this.remainingQuantity,
    this.status = 'ACTIVE',
    this.isActive = true,
  });

  bool get isAvailable => isActive && status == 'ACTIVE' && remainingQuantity > 0;
}

class MobileLotAllocation {
  final String lotId;
  final String batchId;
  final String batchNumber;
  final int unitsAllocated;
  final double unitCost;
  final double lotCogs;

  const MobileLotAllocation({
    required this.lotId,
    required this.batchId,
    required this.batchNumber,
    required this.unitsAllocated,
    required this.unitCost,
    required this.lotCogs,
  });
}

class MobileCogsAllocationResult {
  final bool isSuccessful;
  final String? errorCode;
  final String messageEn;
  final String messageBn;
  final int totalUnits;
  final double totalCogs;
  final double effectiveUnitCogs;
  final List<MobileLotAllocation> allocations;

  const MobileCogsAllocationResult({
    required this.isSuccessful,
    this.errorCode,
    required this.messageEn,
    required this.messageBn,
    required this.totalUnits,
    required this.totalCogs,
    required this.effectiveUnitCogs,
    required this.allocations,
  });

  factory MobileCogsAllocationResult.success({
    required int totalUnits,
    required double totalCogs,
    required double effectiveUnitCogs,
    required List<MobileLotAllocation> allocations,
  }) {
    return MobileCogsAllocationResult(
      isSuccessful: true,
      errorCode: null,
      messageEn: 'COGS allocated successfully across purchase lots.',
      messageBn: 'ক্রয় লটসমূহের মধ্যে সিওজিএস (COGS) সফলভাবে বরাদ্দ করা হয়েছে।',
      totalUnits: totalUnits,
      totalCogs: totalCogs,
      effectiveUnitCogs: effectiveUnitCogs,
      allocations: allocations,
    );
  }

  factory MobileCogsAllocationResult.failure({
    required String errorCode,
    required String messageEn,
    required String messageBn,
  }) {
    return MobileCogsAllocationResult(
      isSuccessful: false,
      errorCode: errorCode,
      messageEn: messageEn,
      messageBn: messageBn,
      totalUnits: 0,
      totalCogs: 0.0,
      effectiveUnitCogs: 0.0,
      allocations: const [],
    );
  }
}

class MobileLotReversalResult {
  final bool isSuccessful;
  final int totalRestoredUnits;
  final double totalRestoredCogs;
  final String reason;

  const MobileLotReversalResult({
    required this.isSuccessful,
    required this.totalRestoredUnits,
    required this.totalRestoredCogs,
    required this.reason,
  });
}

class MobilePurchaseCostLotClient {
  /// Allocates requested quantity across active purchase cost lots in FIFO order.
  static MobileCogsAllocationResult allocateCogs({
    required List<MobileCostLotRecord> candidateLots,
    required int requestedUnits,
  }) {
    if (requestedUnits <= 0) {
      return MobileCogsAllocationResult.failure(
        errorCode: 'ERR_INVALID_QUANTITY',
        messageEn: 'Requested quantity must be positive.',
        messageBn: 'অনুরোধকৃত পরিমাণ অবশ্যই শূন্যের চেয়ে বেশি হতে হবে।',
      );
    }

    if (candidateLots.isEmpty) {
      return MobileCogsAllocationResult.failure(
        errorCode: 'ERR_NO_COST_LOTS',
        messageEn: 'No purchase cost lots available for allocation.',
        messageBn: 'বরাদ্দের জন্য কোনো ক্রয় খরচ লট পাওয়া যায়নি।',
      );
    }

    final activeLots = <MobileCostLotRecord>[];
    int availableTotal = 0;
    for (final lot in candidateLots) {
      if (lot.isAvailable) {
        activeLots.add(lot);
        availableTotal += lot.remainingQuantity;
      }
    }

    if (availableTotal < requestedUnits) {
      return MobileCogsAllocationResult.failure(
        errorCode: 'ERR_INSUFFICIENT_COST_LOT_STOCK',
        messageEn:
            'Insufficient purchase cost lot stock. Requested $requestedUnits, available $availableTotal.',
        messageBn:
            'ক্রয় লটে পর্যাপ্ত স্টক নেই। চাওয়া হয়েছে $requestedUnits, অবশিষ্ট $availableTotal।',
      );
    }

    // Sort FIFO by purchaseDate, then lotId
    activeLots.sort((a, b) {
      final cmp = a.purchaseDate.compareTo(b.purchaseDate);
      if (cmp != 0) return cmp;
      return a.lotId.compareTo(b.lotId);
    });

    int needed = requestedUnits;
    double totalCogs = 0.0;
    final allocations = <MobileLotAllocation>[];

    for (final lot in activeLots) {
      final take = lot.remainingQuantity < needed ? lot.remainingQuantity : needed;
      final lotCogs = take * lot.unitCost;
      totalCogs += lotCogs;

      lot.remainingQuantity -= take;
      if (lot.remainingQuantity == 0) {
        lot.status = 'DEPLETED';
      }

      allocations.add(
        MobileLotAllocation(
          lotId: lot.lotId,
          batchId: lot.batchId,
          batchNumber: lot.batchNumber,
          unitsAllocated: take,
          unitCost: lot.unitCost,
          lotCogs: double.parse(lotCogs.toStringAsFixed(4)),
        ),
      );

      needed -= take;
      if (needed == 0) break;
    }

    final effectiveUnitCogs =
        double.parse((totalCogs / requestedUnits).toStringAsFixed(4));

    return MobileCogsAllocationResult.success(
      totalUnits: requestedUnits,
      totalCogs: double.parse(totalCogs.toStringAsFixed(4)),
      effectiveUnitCogs: effectiveUnitCogs,
      allocations: allocations,
    );
  }

  /// Reverses previous allocations, restoring stock back into originating cost lots.
  static MobileLotReversalResult reverseAllocation({
    required List<MobileCostLotRecord> lots,
    required List<MobileLotAllocation> allocations,
    String reason = 'Customer Return / Void',
  }) {
    if (lots.isEmpty || allocations.isEmpty) {
      return MobileLotReversalResult(
        isSuccessful: false,
        totalRestoredUnits: 0,
        totalRestoredCogs: 0.0,
        reason: reason,
      );
    }

    final lotMap = {for (var l in lots) l.lotId: l};
    int restoredUnits = 0;
    double restoredCogs = 0.0;

    for (final alloc in allocations) {
      final lot = lotMap[alloc.lotId];
      if (lot != null) {
        lot.remainingQuantity += alloc.unitsAllocated;
        if (lot.status == 'DEPLETED') {
          lot.status = 'ACTIVE';
        }
        restoredUnits += alloc.unitsAllocated;
        restoredCogs += alloc.lotCogs;
      }
    }

    return MobileLotReversalResult(
      isSuccessful: true,
      totalRestoredUnits: restoredUnits,
      totalRestoredCogs: double.parse(restoredCogs.toStringAsFixed(4)),
      reason: reason,
    );
  }

  /// Computes aggregate balance sheet inventory valuation across active lots.
  static double computeInventoryValuation(List<MobileCostLotRecord> lots) {
    double total = 0.0;
    for (final l in lots) {
      if (l.isActive && l.status != 'REVERSED') {
        total += l.remainingQuantity * l.unitCost;
      }
    }
    return double.parse(total.toStringAsFixed(4));
  }
}

