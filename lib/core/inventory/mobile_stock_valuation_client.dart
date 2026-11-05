import 'dart:math';

/// mobile_stock_valuation_client.dart
/// Architecture Decision: ADR-0179 (P179).
/// Phase 09: Packaging, Unit Conversion, Batches & Cost Lots.
///
/// Flutter mobile manager client providing offline/online stock valuation,
/// FIFO actual cost, 5-tier aging analysis, and realized margin tracking.

class MobileCostLotItem {
  final String lotId;
  final String tenantId;
  final String branchId;
  final String productId;
  final String brandName;
  final String genericName;
  final String dosageForm;
  final DateTime purchaseDate;
  final int remainingQuantity;
  final double unitCost;
  final double mrpUnit;

  const MobileCostLotItem({
    required this.lotId,
    required this.tenantId,
    required this.branchId,
    required this.productId,
    required this.brandName,
    required this.genericName,
    required this.dosageForm,
    required this.purchaseDate,
    required this.remainingQuantity,
    required this.unitCost,
    required this.mrpUnit,
  });
}

class MobileSaleAllocationItem {
  final String allocationId;
  final String tenantId;
  final String branchId;
  final String productId;
  final DateTime saleDate;
  final int quantityBaseUnits;
  final double totalSellingPrice;
  final double totalCost;
  final double grossProfit;

  const MobileSaleAllocationItem({
    required this.allocationId,
    required this.tenantId,
    required this.branchId,
    required this.productId,
    required this.saleDate,
    required this.quantityBaseUnits,
    required this.totalSellingPrice,
    required this.totalCost,
    required this.grossProfit,
  });
}

class MobileAgingBucket {
  final String label;
  final int quantityBaseUnits;
  final double costValuationBdt;
  final double pctOfTotalCost;

  const MobileAgingBucket({
    required this.label,
    required this.quantityBaseUnits,
    required this.costValuationBdt,
    required this.pctOfTotalCost,
  });

  Map<String, dynamic> toJson() => {
    'label': label,
    'quantity_base_units': quantityBaseUnits,
    'cost_valuation_bdt': costValuationBdt.toStringAsFixed(4),
    'pct_of_total_cost': pctOfTotalCost.toStringAsFixed(2),
  };
}

class MobileProductValuationItem {
  final String productId;
  final String brandName;
  final String genericName;
  final String dosageForm;
  final int quantityBaseUnits;
  final double costValuationBdt;
  final double retailValuationBdt;
  final double potentialMarginPct;
  final double unitCostEffective;
  final double mrpUnit;

  const MobileProductValuationItem({
    required this.productId,
    required this.brandName,
    required this.genericName,
    required this.dosageForm,
    required this.quantityBaseUnits,
    required this.costValuationBdt,
    required this.retailValuationBdt,
    required this.potentialMarginPct,
    required this.unitCostEffective,
    required this.mrpUnit,
  });

  Map<String, dynamic> toJson() => {
    'product_id': productId,
    'brand_name': brandName,
    'generic_name': genericName,
    'dosage_form': dosageForm,
    'quantity_base_units': quantityBaseUnits,
    'cost_valuation_bdt': costValuationBdt.toStringAsFixed(4),
    'retail_valuation_bdt': retailValuationBdt.toStringAsFixed(4),
    'potential_margin_pct': potentialMarginPct.toStringAsFixed(2),
    'unit_cost_effective': unitCostEffective.toStringAsFixed(4),
    'mrp_unit': mrpUnit.toStringAsFixed(4),
  };
}

class MobileRealizedMarginSummary {
  final int allocationsCount;
  final double totalRevenueBdt;
  final double totalCogsBdt;
  final double realizedGrossProfitBdt;
  final double realizedMarginPct;

  const MobileRealizedMarginSummary({
    required this.allocationsCount,
    required this.totalRevenueBdt,
    required this.totalCogsBdt,
    required this.realizedGrossProfitBdt,
    required this.realizedMarginPct,
  });

  Map<String, dynamic> toJson() => {
    'allocations_count': allocationsCount,
    'total_revenue_bdt': totalRevenueBdt.toStringAsFixed(4),
    'total_cogs_bdt': totalCogsBdt.toStringAsFixed(4),
    'realized_gross_profit_bdt': realizedGrossProfitBdt.toStringAsFixed(4),
    'realized_margin_pct': realizedMarginPct.toStringAsFixed(2),
  };
}

class MobileValuationSummary {
  final String tenantId;
  final String branchId;
  final DateTime asOfDate;
  final String costingMethod;
  final int totalProductsCount;
  final int totalQuantityBaseUnits;
  final double totalCostValuationBdt;
  final double totalRetailValuationBdt;
  final double potentialGrossMarginBdt;
  final double potentialMarginPct;
  final Map<String, MobileAgingBucket> agingSummary;
  final MobileRealizedMarginSummary realizedMargin;
  final List<MobileProductValuationItem> productBreakdown;

  const MobileValuationSummary({
    required this.tenantId,
    required this.branchId,
    required this.asOfDate,
    required this.costingMethod,
    required this.totalProductsCount,
    required this.totalQuantityBaseUnits,
    required this.totalCostValuationBdt,
    required this.totalRetailValuationBdt,
    required this.potentialGrossMarginBdt,
    required this.potentialMarginPct,
    required this.agingSummary,
    required this.realizedMargin,
    required this.productBreakdown,
  });
}

class MobileValuationSnapshot {
  final String snapshotId;
  final String tenantId;
  final String branchId;
  final DateTime valuationDate;
  final String costingMethod;
  final int totalQuantityBaseUnits;
  final double totalCostValuationBdt;
  final double totalRetailValuationBdt;
  final double potentialGrossMarginBdt;
  final double potentialMarginPct;
  final String notes;
  final DateTime createdAt;

  const MobileValuationSnapshot({
    required this.snapshotId,
    required this.tenantId,
    required this.branchId,
    required this.valuationDate,
    required this.costingMethod,
    required this.totalQuantityBaseUnits,
    required this.totalCostValuationBdt,
    required this.totalRetailValuationBdt,
    required this.potentialGrossMarginBdt,
    required this.potentialMarginPct,
    required this.notes,
    required this.createdAt,
  });
}

class MobileStockValuationResult<T> {
  final bool success;
  final T? data;
  final String? errorCode;
  final String messageEn;
  final String messageBn;

  const MobileStockValuationResult._({
    required this.success,
    this.data,
    this.errorCode,
    required this.messageEn,
    required this.messageBn,
  });

  factory MobileStockValuationResult.ok(T data, String msgEn, String msgBn) {
    return MobileStockValuationResult._(
      success: true,
      data: data,
      messageEn: msgEn,
      messageBn: msgBn,
    );
  }

  factory MobileStockValuationResult.fail(String err, String msgEn, String msgBn) {
    return MobileStockValuationResult._(
      success: false,
      errorCode: err,
      messageEn: msgEn,
      messageBn: msgBn,
    );
  }
}

class MobileStockValuationClient {
  final String tenantId;
  final String branchId;
  final String userRole;
  final String userId;
  final bool isOffline;
  final Map<String, MobileValuationSnapshot> _snapshotStore = {};

  MobileStockValuationClient({
    required this.tenantId,
    required this.branchId,
    required this.userRole,
    required this.userId,
    this.isOffline = false,
  });

  bool get isAuthorized =>
      userRole == 'BRANCH_MANAGER' ||
      userRole == 'PHARMACY_OWNER' ||
      userRole == 'SUPERADMIN' ||
      userRole == 'STAFF_PHARMACIST' ||
      userRole == 'AUDITOR';

  MobileStockValuationResult<MobileValuationSummary> calculateValuation({
    required List<MobileCostLotItem> costLots,
    List<MobileSaleAllocationItem>? allocations,
    DateTime? asOfDate,
    String costingMethod = 'FIFO_ACTUAL',
  }) {
    if (!isAuthorized) {
      return MobileStockValuationResult.fail(
        'ERR_PERMISSION_DENIED',
        'Cashier role is unauthorized to view inventory valuation and margin metrics.',
        'ক্যাশিয়ারদের ইনভেন্টরি মূল্যায়ন এবং লাভের হিসাব দেখার অনুমতি নেই।',
      );
    }

    final method = costingMethod.toUpperCase();
    if (method != 'FIFO_ACTUAL' && method != 'WEIGHTED_AVERAGE') {
      return MobileStockValuationResult.fail(
        'ERR_INVALID_VALUATION_INPUT',
        'Invalid costing method. Must be FIFO_ACTUAL or WEIGHTED_AVERAGE.',
        'অবৈধ কস্টিং পদ্ধতি। FIFO_ACTUAL অথবা WEIGHTED_AVERAGE নির্বাচন করুন।',
      );
    }

    final date = asOfDate ?? DateTime.now();

    int totalUnits = 0;
    double totalCost = 0.0;
    double totalRetail = 0.0;

    final bucketUnits = <String, int>{
      'days_0_to_30': 0,
      'days_31_to_60': 0,
      'days_61_to_90': 0,
      'days_91_to_180': 0,
      'days_181_plus': 0,
    };
    final bucketCost = <String, double>{
      'days_0_to_30': 0.0,
      'days_31_to_60': 0.0,
      'days_61_to_90': 0.0,
      'days_91_to_180': 0.0,
      'days_181_plus': 0.0,
    };

    final productLots = <String, List<MobileCostLotItem>>{};

    for (final lot in costLots) {
      if (lot.tenantId != tenantId || lot.branchId != branchId) continue;
      if (lot.purchaseDate.isAfter(date)) continue;
      if (lot.remainingQuantity <= 0) continue;

      final qty = lot.remainingQuantity;
      final costVal = qty * lot.unitCost;
      final retailVal = qty * lot.mrpUnit;

      totalUnits += qty;
      totalCost += costVal;
      totalRetail += retailVal;

      final days = date.difference(lot.purchaseDate).inDays;
      String bKey;
      if (days <= 30) {
        bKey = 'days_0_to_30';
      } else if (days <= 60) {
        bKey = 'days_31_to_60';
      } else if (days <= 90) {
        bKey = 'days_61_to_90';
      } else if (days <= 180) {
        bKey = 'days_91_to_180';
      } else {
        bKey = 'days_181_plus';
      }

      bucketUnits[bKey] = (bucketUnits[bKey] ?? 0) + qty;
      bucketCost[bKey] = (bucketCost[bKey] ?? 0.0) + costVal;

      productLots.putIfAbsent(lot.productId, () => []).add(lot);
    }

    final potentialGrossMargin = totalRetail - totalCost;
    final potentialMarginPct = totalRetail > 0 ? (potentialGrossMargin / totalRetail) * 100.0 : 0.0;

    final agingLabels = {
      'days_0_to_30': '0 - 30 Days (Fresh)',
      'days_31_to_60': '31 - 60 Days (Normal)',
      'days_61_to_90': '61 - 90 Days (Moderate)',
      'days_91_to_180': '91 - 180 Days (Slow-Moving)',
      'days_181_plus': '181+ Days (Aged / Dormant)',
    };

    final agingSummary = <String, MobileAgingBucket>{};
    for (final bKey in bucketUnits.keys) {
      final bUnits = bucketUnits[bKey]!;
      final bCost = bucketCost[bKey]!;
      final bPct = totalCost > 0 ? (bCost / totalCost) * 100.0 : 0.0;
      agingSummary[bKey] = MobileAgingBucket(
        label: agingLabels[bKey]!,
        quantityBaseUnits: bUnits,
        costValuationBdt: bCost,
        pctOfTotalCost: bPct,
      );
    }

    final productBreakdown = <MobileProductValuationItem>[];
    for (final entry in productLots.entries) {
      final lots = entry.value;
      if (lots.isEmpty) continue;
      final first = lots.first;
      int pQty = 0;
      double pCost = 0.0;
      double pRetail = 0.0;

      for (final l in lots) {
        pQty += l.remainingQuantity;
        pCost += l.remainingQuantity * l.unitCost;
        pRetail += l.remainingQuantity * l.mrpUnit;
      }

      final pMargin = pRetail - pCost;
      final pMarginPct = pRetail > 0 ? (pMargin / pRetail) * 100.0 : 0.0;
      final effCost = pQty > 0 ? pCost / pQty : 0.0;

      productBreakdown.add(MobileProductValuationItem(
        productId: first.productId,
        brandName: first.brandName,
        genericName: first.genericName,
        dosageForm: first.dosageForm,
        quantityBaseUnits: pQty,
        costValuationBdt: pCost,
        retailValuationBdt: pRetail,
        potentialMarginPct: pMarginPct,
        unitCostEffective: effCost,
        mrpUnit: first.mrpUnit,
      ));
    }

    int allocCount = 0;
    double realizedRev = 0.0;
    double realizedCogs = 0.0;
    double realizedProfit = 0.0;

    if (allocations != null) {
      for (final a in allocations) {
        if (a.tenantId != tenantId || a.branchId != branchId) continue;
        allocCount++;
        realizedRev += a.totalSellingPrice;
        realizedCogs += a.totalCost;
        realizedProfit += a.grossProfit;
      }
    }

    final realizedMarginPct = realizedRev > 0 ? (realizedProfit / realizedRev) * 100.0 : 0.0;
    final realizedSummary = MobileRealizedMarginSummary(
      allocationsCount: allocCount,
      totalRevenueBdt: realizedRev,
      totalCogsBdt: realizedCogs,
      realizedGrossProfitBdt: realizedProfit,
      realizedMarginPct: realizedMarginPct,
    );

    final summary = MobileValuationSummary(
      tenantId: tenantId,
      branchId: branchId,
      asOfDate: date,
      costingMethod: method,
      totalProductsCount: productBreakdown.length,
      totalQuantityBaseUnits: totalUnits,
      totalCostValuationBdt: totalCost,
      totalRetailValuationBdt: totalRetail,
      potentialGrossMarginBdt: potentialGrossMargin,
      potentialMarginPct: potentialMarginPct,
      agingSummary: agingSummary,
      realizedMargin: realizedSummary,
      productBreakdown: productBreakdown,
    );

    return MobileStockValuationResult.ok(
      summary,
      'Stock valuation calculated successfully.',
      'ইনভেন্টরি মূল্যায়ন সফলভাবে সম্পন্ন হয়েছে।',
    );
  }

  MobileStockValuationResult<MobileValuationSnapshot> createSnapshot({
    required List<MobileCostLotItem> costLots,
    List<MobileSaleAllocationItem>? allocations,
    DateTime? asOfDate,
    String costingMethod = 'FIFO_ACTUAL',
    String notes = '',
  }) {
    final res = calculateValuation(
      costLots: costLots,
      allocations: allocations,
      asOfDate: asOfDate,
      costingMethod: costingMethod,
    );
    if (!res.success) {
      return MobileStockValuationResult.fail(res.errorCode!, res.messageEn, res.messageBn);
    }

    final s = res.data!;
    final randomSuffix = Random().nextInt(1000000).toString().padLeft(6, '0');
    final snapId = 'valsnap-$randomSuffix';

    final snapshot = MobileValuationSnapshot(
      snapshotId: snapId,
      tenantId: tenantId,
      branchId: branchId,
      valuationDate: s.asOfDate,
      costingMethod: s.costingMethod,
      totalQuantityBaseUnits: s.totalQuantityBaseUnits,
      totalCostValuationBdt: s.totalCostValuationBdt,
      totalRetailValuationBdt: s.totalRetailValuationBdt,
      potentialGrossMarginBdt: s.potentialGrossMarginBdt,
      potentialMarginPct: s.potentialMarginPct,
      notes: notes,
      createdAt: DateTime.now(),
    );

    _snapshotStore[snapId] = snapshot;
    return MobileStockValuationResult.ok(
      snapshot,
      'Valuation snapshot saved successfully.',
      'মূল্যায়ন স্ন্যাপশট সফলভাবে সংরক্ষিত হয়েছে।',
    );
  }
}

