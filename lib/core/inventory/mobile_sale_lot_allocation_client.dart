/// MobileSaleLotAllocationClient
/// Architecture Decision: ADR-0170 (P170).
/// Phase 09: Packaging, Unit Conversion, Batches & Cost Lots.
///
/// Mobile client engine managing sale item lot allocation records, DGDA recall
/// patient traceability, controlled sales return restock, and unblended profit analytics.
library;

class MobileLotAllocationItem {
  final String allocationId;
  final String invoiceId;
  final String invoiceNumber;
  final String customerName;
  final String customerPhone;
  final String productId;
  final String productBrandName;
  final String batchId;
  final String batchNumber;
  final String? costLotId;
  final int quantityBaseUnits;
  int returnedQuantityBaseUnits;
  final double unitSellingPrice;
  final double unitCost;
  late final double totalSellingPrice;
  late final double totalCost;
  late double grossProfit;
  late double profitMarginPct;
  String status;
  bool isReturned;

  MobileLotAllocationItem({
    required this.allocationId,
    required this.invoiceId,
    this.invoiceNumber = '',
    this.customerName = 'Walk-in Customer',
    this.customerPhone = '',
    required this.productId,
    this.productBrandName = '',
    required this.batchId,
    required this.batchNumber,
    this.costLotId,
    required this.quantityBaseUnits,
    this.returnedQuantityBaseUnits = 0,
    required this.unitSellingPrice,
    required this.unitCost,
    this.status = 'COMMITTED',
  }) : isReturned = returnedQuantityBaseUnits > 0 {
    totalSellingPrice = unitSellingPrice * quantityBaseUnits;
    totalCost = unitCost * quantityBaseUnits;
    grossProfit = totalSellingPrice - totalCost;
    if (totalSellingPrice > 0) {
      profitMarginPct = double.parse(((grossProfit / totalSellingPrice) * 100).toStringAsFixed(2));
    } else {
      profitMarginPct = 0.0;
    }
  }

  int get netRetainedUnits {
    final net = quantityBaseUnits - returnedQuantityBaseUnits;
    return net > 0 ? net : 0;
  }

  bool canReturn(int units) {
    return units > 0 && units <= netRetainedUnits;
  }
}

class MobileCustomerTrace {
  final String allocationId;
  final String invoiceId;
  final String invoiceNumber;
  final String customerName;
  final String customerPhone;
  final int quantityDispensed;
  final int quantityReturned;
  final int netQuantityWithCustomer;

  const MobileCustomerTrace({
    required this.allocationId,
    required this.invoiceId,
    required this.invoiceNumber,
    required this.customerName,
    required this.customerPhone,
    required this.quantityDispensed,
    required this.quantityReturned,
    required this.netQuantityWithCustomer,
  });
}

class MobileReturnResult {
  final bool isSuccessful;
  final String? errorCode;
  final String messageEn;
  final String messageBn;
  final String allocationId;
  final int returnedUnits;
  final double refundAmount;
  final double refundedCogs;

  const MobileReturnResult({
    required this.isSuccessful,
    this.errorCode,
    required this.messageEn,
    required this.messageBn,
    required this.allocationId,
    required this.returnedUnits,
    required this.refundAmount,
    required this.refundedCogs,
  });

  factory MobileReturnResult.success({
    required String allocationId,
    required int units,
    required double refundAmount,
    required double refundedCogs,
  }) {
    return MobileReturnResult(
      isSuccessful: true,
      errorCode: null,
      messageEn: 'Return processed successfully and stock restored.',
      messageBn: 'বিক্রয় ফেরত সফলভাবে প্রক্রিয়া করা হয়েছে এবং স্টক পুনরুদ্ধার করা হয়েছে।',
      allocationId: allocationId,
      returnedUnits: units,
      refundAmount: refundAmount,
      refundedCogs: refundedCogs,
    );
  }

  factory MobileReturnResult.failure({
    required String errorCode,
    required String messageEn,
    required String messageBn,
    required String allocationId,
  }) {
    return MobileReturnResult(
      isSuccessful: false,
      errorCode: errorCode,
      messageEn: messageEn,
      messageBn: messageBn,
      allocationId: allocationId,
      returnedUnits: 0,
      refundAmount: 0.0,
      refundedCogs: 0.0,
    );
  }
}

class MobileRecallImpactResult {
  final String batchId;
  final int totalDispensedUnits;
  final int totalReturnedUnits;
  final int netPatientExposureUnits;
  final int affectedInvoicesCount;
  final List<MobileCustomerTrace> affectedCustomers;

  const MobileRecallImpactResult({
    required this.batchId,
    required this.totalDispensedUnits,
    required this.totalReturnedUnits,
    required this.netPatientExposureUnits,
    required this.affectedInvoicesCount,
    required this.affectedCustomers,
  });
}

class MobileProfitAnalyticsResult {
  final double totalRevenue;
  final double totalCogs;
  final double grossProfit;
  final double profitMarginPct;
  final int totalUnitsSold;
  final int totalUnitsReturned;
  final int netUnitsRetained;
  final int allocationsCount;

  const MobileProfitAnalyticsResult({
    required this.totalRevenue,
    required this.totalCogs,
    required this.grossProfit,
    required this.profitMarginPct,
    required this.totalUnitsSold,
    required this.totalUnitsReturned,
    required this.netUnitsRetained,
    required this.allocationsCount,
  });
}

class MobileSaleLotAllocationClient {
  /// Processes a return against an existing lot allocation.
  static MobileReturnResult processReturn(
    MobileLotAllocationItem allocation,
    int returnQuantity,
  ) {
    if (returnQuantity <= 0) {
      return MobileReturnResult.failure(
        errorCode: 'ERR_INVALID_QUANTITY',
        messageEn: 'Return quantity must be positive.',
        messageBn: 'ফেরত পরিমাণ অবশ্যই ধনাত্মক হতে হবে।',
        allocationId: allocation.allocationId,
      );
    }
    if (!allocation.canReturn(returnQuantity)) {
      return MobileReturnResult.failure(
        errorCode: 'ERR_RETURN_EXCEEDS_DISPENSED',
        messageEn:
            'Return quantity exceeds net retained units (${allocation.netRetainedUnits}).',
        messageBn: 'ফেরতের পরিমাণ গ্রাহকের কাছে অবশিষ্ট পরিমাণের বেশি।',
        allocationId: allocation.allocationId,
      );
    }

    allocation.returnedQuantityBaseUnits += returnQuantity;
    allocation.isReturned = true;
    if (allocation.returnedQuantityBaseUnits == allocation.quantityBaseUnits) {
      allocation.status = 'FULLY_RETURNED';
    } else {
      allocation.status = 'PARTIALLY_RETURNED';
    }

    final refundAmount = allocation.unitSellingPrice * returnQuantity;
    final refundedCogs = allocation.unitCost * returnQuantity;

    return MobileReturnResult.success(
      allocationId: allocation.allocationId,
      units: returnQuantity,
      refundAmount: refundAmount,
      refundedCogs: refundedCogs,
    );
  }

  /// Traces DGDA recall patient exposure across invoices and customers.
  static MobileRecallImpactResult traceRecallImpact(
    List<MobileLotAllocationItem> allocations,
    String targetBatchId,
  ) {
    int dispensed = 0;
    int returned = 0;
    final invoiceSet = <String>{};
    final customers = <MobileCustomerTrace>[];

    for (final a in allocations) {
      if (targetBatchId.isEmpty || a.batchId == targetBatchId) {
        dispensed += a.quantityBaseUnits;
        returned += a.returnedQuantityBaseUnits;
        invoiceSet.add(a.invoiceId);
        customers.add(
          MobileCustomerTrace(
            allocationId: a.allocationId,
            invoiceId: a.invoiceId,
            invoiceNumber: a.invoiceNumber,
            customerName: a.customerName,
            customerPhone: a.customerPhone,
            quantityDispensed: a.quantityBaseUnits,
            quantityReturned: a.returnedQuantityBaseUnits,
            netQuantityWithCustomer: a.quantityBaseUnits - a.returnedQuantityBaseUnits,
          ),
        );
      }
    }

    return MobileRecallImpactResult(
      batchId: targetBatchId,
      totalDispensedUnits: dispensed,
      totalReturnedUnits: returned,
      netPatientExposureUnits: dispensed - returned,
      affectedInvoicesCount: invoiceSet.length,
      affectedCustomers: customers,
    );
  }

  /// Computes exact unblended gross profit analytics across allocations.
  static MobileProfitAnalyticsResult computeProfitAnalytics(
    List<MobileLotAllocationItem> allocations,
  ) {
    double totalRev = 0.0;
    double totalCost = 0.0;
    int totalUnits = 0;
    int totalReturned = 0;

    for (final a in allocations) {
      totalRev += a.totalSellingPrice;
      totalCost += a.totalCost;
      totalUnits += a.quantityBaseUnits;
      totalReturned += a.returnedQuantityBaseUnits;
    }

    final grossProfit = totalRev - totalCost;
    final marginPct = totalRev > 0
        ? double.parse(((grossProfit / totalRev) * 100).toStringAsFixed(2))
        : 0.0;

    return MobileProfitAnalyticsResult(
      totalRevenue: totalRev,
      totalCogs: totalCost,
      grossProfit: grossProfit,
      profitMarginPct: marginPct,
      totalUnitsSold: totalUnits,
      totalUnitsReturned: totalReturned,
      netUnitsRetained: totalUnits - totalReturned,
      allocationsCount: allocations.length,
    );
  }
}

