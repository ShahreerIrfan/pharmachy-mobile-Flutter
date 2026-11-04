/// MobileFefoAllocationClient
/// Architecture Decision: ADR-0169 (P169).
/// Phase 09: Packaging, Unit Conversion, Batches & Cost Lots.
///
/// Deterministic First-Expired, First-Out (FEFO) Inventory Allocation Engine
/// for Flutter Mobile Manager. Enforces hard expiry blocks, quarantine/recall exclusions,
/// active reservation deduction, and 4-tier deterministic tie-breaker sorting.
library;

class MobileBatchRecord implements Comparable<MobileBatchRecord> {
  final String batchId;
  final String batchNumber;
  final DateTime expiryDate;
  final DateTime purchaseDate;
  int totalQuantityBaseUnits;
  int reservedQuantityBaseUnits;
  final double costPerUnit;
  bool isQuarantined;
  bool isRecalled;
  bool isActive;

  MobileBatchRecord({
    required this.batchId,
    required this.batchNumber,
    required this.expiryDate,
    required this.purchaseDate,
    required this.totalQuantityBaseUnits,
    this.reservedQuantityBaseUnits = 0,
    required this.costPerUnit,
    this.isQuarantined = false,
    this.isRecalled = false,
    this.isActive = true,
  });

  int get availableQuantity {
    final diff = totalQuantityBaseUnits - reservedQuantityBaseUnits;
    return diff > 0 ? diff : 0;
  }

  bool isDispensable(DateTime asOfDate) {
    if (!isActive || isQuarantined || isRecalled) {
      return false;
    }
    // Strict healthcare check: batch must expire AFTER asOfDate
    final dateOnly = DateTime(asOfDate.year, asOfDate.month, asOfDate.day);
    final expDateOnly = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
    if (!expDateOnly.isAfter(dateOnly)) {
      return false;
    }
    return availableQuantity > 0;
  }

  @override
  int compareTo(MobileBatchRecord other) {
    // Tier 1: Expiry date ASC (earliest first)
    final expCompare = expiryDate.compareTo(other.expiryDate);
    if (expCompare != 0) return expCompare;

    // Tier 2: Purchase date ASC (FIFO tie-breaker)
    final purchCompare = purchaseDate.compareTo(other.purchaseDate);
    if (purchCompare != 0) return purchCompare;

    // Tier 3: Batch number ASC (lexicographical tie-breaker)
    final numCompare = batchNumber.compareTo(other.batchNumber);
    if (numCompare != 0) return numCompare;

    // Tier 4: Primary key batchId ASC
    return batchId.compareTo(other.batchId);
  }
}

class MobileBatchAllocation {
  final String batchId;
  final String batchNumber;
  final DateTime expiryDate;
  final DateTime purchaseDate;
  final int allocatedUnits;
  final double unitCost;
  final double lotCogs;
  final String? reservationId;

  const MobileBatchAllocation({
    required this.batchId,
    required this.batchNumber,
    required this.expiryDate,
    required this.purchaseDate,
    required this.allocatedUnits,
    required this.unitCost,
    required this.lotCogs,
    this.reservationId,
  });
}

class MobileAllocationResult {
  final bool isSuccessful;
  final String? errorCode;
  final String messageEn;
  final String messageBn;
  final String productId;
  final int requestedUnits;
  final int allocatedUnits;
  final double totalCogs;
  final bool isFullyAllocated;
  final List<MobileBatchAllocation> allocations;

  const MobileAllocationResult({
    required this.isSuccessful,
    this.errorCode,
    required this.messageEn,
    required this.messageBn,
    required this.productId,
    required this.requestedUnits,
    required this.allocatedUnits,
    required this.totalCogs,
    required this.isFullyAllocated,
    required this.allocations,
  });

  factory MobileAllocationResult.success({
    required String productId,
    required int requestedUnits,
    required double totalCogs,
    required List<MobileBatchAllocation> allocations,
  }) {
    return MobileAllocationResult(
      isSuccessful: true,
      errorCode: null,
      messageEn: 'FEFO allocation completed successfully.',
      messageBn: 'FEFO ব্যাচ বরাদ্দ সফলভাবে সম্পন্ন হয়েছে।',
      productId: productId,
      requestedUnits: requestedUnits,
      allocatedUnits: requestedUnits,
      totalCogs: totalCogs,
      isFullyAllocated: true,
      allocations: allocations,
    );
  }

  factory MobileAllocationResult.failure({
    required String errorCode,
    required String messageEn,
    required String messageBn,
    required String productId,
    required int requestedUnits,
    required int allocatedUnits,
  }) {
    return MobileAllocationResult(
      isSuccessful: false,
      errorCode: errorCode,
      messageEn: messageEn,
      messageBn: messageBn,
      productId: productId,
      requestedUnits: requestedUnits,
      allocatedUnits: allocatedUnits,
      totalCogs: 0.0,
      isFullyAllocated: false,
      allocations: const [],
    );
  }
}

class MobileFefoAllocationClient {
  /// Executes deterministic FEFO allocation and optional concurrency reservation.
  static MobileAllocationResult allocateFefo({
    required String productId,
    required List<MobileBatchRecord> batches,
    required int requestedUnits,
    required DateTime asOfDate,
    bool reserve = false,
  }) {
    if (requestedUnits <= 0) {
      return MobileAllocationResult.failure(
        errorCode: 'ERR_INVALID_QUANTITY',
        messageEn: 'Requested quantity must be a positive integer.',
        messageBn: 'অনুরোধকৃত পরিমাণ অবশ্যই ধনাত্মক পূর্ণসংখ্যা হতে হবে।',
        productId: productId,
        requestedUnits: requestedUnits,
        allocatedUnits: 0,
      );
    }

    // 1. Filter eligible candidate batches
    final candidates = batches.where((b) => b.isDispensable(asOfDate)).toList();

    if (candidates.isEmpty) {
      return MobileAllocationResult.failure(
        errorCode: 'ERR_NO_ELIGIBLE_BATCHES',
        messageEn: 'No eligible FEFO batches available for product.',
        messageBn: 'এই ওষুধের জন্য কোন যোগ্য FEFO ব্যাচ পাওয়া যায়নি।',
        productId: productId,
        requestedUnits: requestedUnits,
        allocatedUnits: 0,
      );
    }

    // 2. Sort candidate batches using deterministic 4-tier cascade
    candidates.sort();

    int remainingNeeded = requestedUnits;
    final allocations = <MobileBatchAllocation>[];
    double totalCogs = 0.0;

    for (final b in candidates) {
      final avail = b.availableQuantity;
      if (avail <= 0) continue;

      final take = avail < remainingNeeded ? avail : remainingNeeded;
      final lotCogs = b.costPerUnit * take;
      totalCogs += lotCogs;

      String? reservationId;
      if (reserve) {
        reservationId = 'resv-${DateTime.now().millisecondsSinceEpoch}-${b.batchId}';
        b.reservedQuantityBaseUnits += take;
      }

      allocations.add(
        MobileBatchAllocation(
          batchId: b.batchId,
          batchNumber: b.batchNumber,
          expiryDate: b.expiryDate,
          purchaseDate: b.purchaseDate,
          allocatedUnits: take,
          unitCost: b.costPerUnit,
          lotCogs: lotCogs,
          reservationId: reservationId,
        ),
      );

      remainingNeeded -= take;
      if (remainingNeeded == 0) break;
    }

    if (remainingNeeded > 0) {
      // Roll back reservations if partially allocated
      if (reserve) {
        for (final alloc in allocations) {
          for (final b in candidates) {
            if (b.batchId == alloc.batchId) {
              final newResv = b.reservedQuantityBaseUnits - alloc.allocatedUnits;
              b.reservedQuantityBaseUnits = newResv > 0 ? newResv : 0;
              break;
            }
          }
        }
      }
      final availableTotal = requestedUnits - remainingNeeded;
      return MobileAllocationResult.failure(
        errorCode: 'ERR_INSUFFICIENT_STOCK',
        messageEn:
            'Insufficient dispensable stock: requested $requestedUnits, available $availableTotal.',
        messageBn:
            'অপর্যাপ্ত স্টক: অনুরোধকৃত $requestedUnits, বর্তমান স্টক $availableTotal।',
        productId: productId,
        requestedUnits: requestedUnits,
        allocatedUnits: availableTotal,
      );
    }

    return MobileAllocationResult.success(
      productId: productId,
      requestedUnits: requestedUnits,
      totalCogs: totalCogs,
      allocations: allocations,
    );
  }

  /// Commits an active reservation upon successful checkout.
  static bool commitReservation(MobileBatchRecord batch, int reservedUnits) {
    if (reservedUnits <= 0) return false;
    final newTotal = batch.totalQuantityBaseUnits - reservedUnits;
    final newResv = batch.reservedQuantityBaseUnits - reservedUnits;
    batch.totalQuantityBaseUnits = newTotal > 0 ? newTotal : 0;
    batch.reservedQuantityBaseUnits = newResv > 0 ? newResv : 0;
    return true;
  }

  /// Releases an active reservation upon checkout cancellation.
  static bool releaseReservation(MobileBatchRecord batch, int reservedUnits) {
    if (reservedUnits <= 0) return false;
    final newResv = batch.reservedQuantityBaseUnits - reservedUnits;
    batch.reservedQuantityBaseUnits = newResv > 0 ? newResv : 0;
    return true;
  }
}

