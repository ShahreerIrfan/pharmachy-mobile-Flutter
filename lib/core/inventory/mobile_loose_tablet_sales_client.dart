/// MobileLooseTabletSalesClient
/// Architecture Decision: ADR-0164 (P164).
/// Phase 09: Packaging, Unit Conversion, Batches & Cost Lots.
///
/// Mobile loose tablet sales and partial strip dispensing engine for Flutter Mobile Manager.
/// Enforces blister-integrity guardrails, exact base-piece stock conservation, and FEFO allocation.
library;

class MobileLooseSalesPolicy {
  final String configId;
  final String tenantId;
  final String? branchId;
  final String productId;
  final String productName;
  final bool allowLooseSales;
  final int minLooseDispenseUnits;
  final int maxLooseDispenseUnits;
  final int stripSizePieces;
  final double stripMrp;
  final double looseUnitMrp;
  final bool applyLooseUnitSurcharge;
  final double looseSurchargePercentage;
  final String prohibitionReason;

  const MobileLooseSalesPolicy({
    required this.configId,
    required this.tenantId,
    this.branchId,
    required this.productId,
    this.productName = '',
    this.allowLooseSales = true,
    this.minLooseDispenseUnits = 1,
    this.maxLooseDispenseUnits = 100,
    this.stripSizePieces = 10,
    this.stripMrp = 0.0,
    this.looseUnitMrp = 0.0,
    this.applyLooseUnitSurcharge = false,
    this.looseSurchargePercentage = 0.0,
    this.prohibitionReason = '',
  });
}

class MobileBatchStockItem {
  final String batchId;
  final String batchNumber;
  final DateTime expiryDate;
  int quantityBaseUnits;
  final bool isQuarantined;

  MobileBatchStockItem({
    required this.batchId,
    required this.batchNumber,
    required this.expiryDate,
    required this.quantityBaseUnits,
    this.isQuarantined = false,
  });

  bool isExpired(DateTime asOfDate) {
    return expiryDate.isBefore(asOfDate) ||
        (expiryDate.year == asOfDate.year &&
            expiryDate.month == asOfDate.month &&
            expiryDate.day == asOfDate.day);
  }
}

class MobileQuoteCalculation {
  final bool isAllowed;
  final String? errorCode;
  final String? errorMessageEn;
  final String? errorMessageBn;
  final int normalizedStrips;
  final int normalizedLoosePieces;
  final int totalBaseUnits;
  final double stripTotal;
  final double looseTotal;
  final double surchargeAmount;
  final double finalQuoteAmount;
  final int availableStockBaseUnits;
  final bool isStockSufficient;

  const MobileQuoteCalculation({
    required this.isAllowed,
    this.errorCode,
    this.errorMessageEn,
    this.errorMessageBn,
    required this.normalizedStrips,
    required this.normalizedLoosePieces,
    required this.totalBaseUnits,
    required this.stripTotal,
    required this.looseTotal,
    required this.surchargeAmount,
    required this.finalQuoteAmount,
    required this.availableStockBaseUnits,
    required this.isStockSufficient,
  });

  factory MobileQuoteCalculation.prohibited({
    required String reason,
    required int availableStock,
  }) {
    final en = 'Loose tablet sales prohibited: ${reason.isNotEmpty ? reason : "Blister integrity guardrail."}';
    final bn = 'এই ঔষধের খোলা ট্যাবলেট বিক্রি নিষিদ্ধ: ${reason.isNotEmpty ? reason : "ব্লিষ্টার ও আর্দ্রতা সুরক্ষা নীতি।"}';
    return MobileQuoteCalculation(
      isAllowed: false,
      errorCode: 'ERR_LOOSE_TABLET_SALES_PROHIBITED',
      errorMessageEn: en,
      errorMessageBn: bn,
      normalizedStrips: 0,
      normalizedLoosePieces: 0,
      totalBaseUnits: 0,
      stripTotal: 0.0,
      looseTotal: 0.0,
      surchargeAmount: 0.0,
      finalQuoteAmount: 0.0,
      availableStockBaseUnits: availableStock,
      isStockSufficient: false,
    );
  }

  factory MobileQuoteCalculation.invalidQuantity({
    required String en,
    required String bn,
  }) {
    return MobileQuoteCalculation(
      isAllowed: false,
      errorCode: 'ERR_INVALID_QUANTITY',
      errorMessageEn: en,
      errorMessageBn: bn,
      normalizedStrips: 0,
      normalizedLoosePieces: 0,
      totalBaseUnits: 0,
      stripTotal: 0.0,
      looseTotal: 0.0,
      surchargeAmount: 0.0,
      finalQuoteAmount: 0.0,
      availableStockBaseUnits: 0,
      isStockSufficient: false,
    );
  }
}

class MobileBatchAllocation {
  final String batchId;
  final String batchNumber;
  final DateTime expiryDate;
  final int deductedBaseUnits;
  final double subtotalBdt;

  const MobileBatchAllocation({
    required this.batchId,
    required this.batchNumber,
    required this.expiryDate,
    required this.deductedBaseUnits,
    required this.subtotalBdt,
  });
}

class MobileCheckoutExecution {
  final bool success;
  final String? invoiceId;
  final String? invoiceNumber;
  final String? errorCode;
  final String? errorMessageEn;
  final String? errorMessageBn;
  final MobileQuoteCalculation quote;
  final List<MobileBatchAllocation> allocations;

  const MobileCheckoutExecution({
    required this.success,
    this.invoiceId,
    this.invoiceNumber,
    this.errorCode,
    this.errorMessageEn,
    this.errorMessageBn,
    required this.quote,
    this.allocations = const [],
  });

  factory MobileCheckoutExecution.failure({
    required String code,
    required String en,
    required String bn,
    required MobileQuoteCalculation quote,
  }) {
    return MobileCheckoutExecution(
      success: false,
      errorCode: code,
      errorMessageEn: en,
      errorMessageBn: bn,
      quote: quote,
      allocations: const [],
    );
  }
}

class MobileLooseTabletSalesClient {
  const MobileLooseTabletSalesClient();

  /// Calculates quote with normalized strips, loose units, exact prices, and prohibition checks.
  MobileQuoteCalculation calculateQuote({
    required MobileLooseSalesPolicy policy,
    int strips = 0,
    int loosePieces = 0,
    int? totalPieces,
    int availableStockBaseUnits = 0,
  }) {
    int normalizedStrips;
    int normalizedLoose;
    int totalUnits;

    if (totalPieces != null) {
      if (totalPieces <= 0) {
        return MobileQuoteCalculation.invalidQuantity(
          en: 'Total pieces must be positive.',
          bn: 'মোট ট্যাবলেটের পরিমাণ ধনাত্মক হতে হবে।',
        );
      }
      normalizedStrips = totalPieces ~/ policy.stripSizePieces;
      normalizedLoose = totalPieces % policy.stripSizePieces;
      totalUnits = totalPieces;
    } else {
      if (strips < 0 || loosePieces < 0) {
        return MobileQuoteCalculation.invalidQuantity(
          en: 'Quantities cannot be negative.',
          bn: 'পরিমাণ ঋণাত্মক হতে পারে না।',
        );
      }
      normalizedStrips = strips + (loosePieces ~/ policy.stripSizePieces);
      normalizedLoose = loosePieces % policy.stripSizePieces;
      totalUnits = (normalizedStrips * policy.stripSizePieces) + normalizedLoose;
      if (totalUnits <= 0) {
        return MobileQuoteCalculation.invalidQuantity(
          en: 'Requested quantity must be positive.',
          bn: 'মোট ট্যাবলেটের পরিমাণ শূন্যের বেশি হতে হবে।',
        );
      }
    }

    // Guardrail: Prohibited loose tablet sales
    if (!policy.allowLooseSales && normalizedLoose > 0) {
      return MobileQuoteCalculation.prohibited(
        reason: policy.prohibitionReason,
        availableStock: availableStockBaseUnits,
      );
    }

    // Min loose units limit check
    if (normalizedLoose > 0 && normalizedLoose < policy.minLooseDispenseUnits) {
      return MobileQuoteCalculation(
        isAllowed: false,
        errorCode: 'ERR_BELOW_MIN_LOOSE_DISPENSE',
        errorMessageEn: 'Minimum loose units is ${policy.minLooseDispenseUnits} pieces.',
        errorMessageBn: 'নূন্যতম খোলা ট্যাবলেটের পরিমাণ ${policy.minLooseDispenseUnits} টি।',
        normalizedStrips: normalizedStrips,
        normalizedLoosePieces: normalizedLoose,
        totalBaseUnits: totalUnits,
        stripTotal: 0.0,
        looseTotal: 0.0,
        surchargeAmount: 0.0,
        finalQuoteAmount: 0.0,
        availableStockBaseUnits: availableStockBaseUnits,
        isStockSufficient: false,
      );
    }

    final stripTotal = double.parse((policy.stripMrp * normalizedStrips).toStringAsFixed(2));
    double effectiveLooseMrp = policy.looseUnitMrp;
    double surchargeAmount = 0.0;

    if (policy.applyLooseUnitSurcharge && policy.looseSurchargePercentage > 0.0) {
      final surchargeFactor = 1.0 + (policy.looseSurchargePercentage / 100.0);
      effectiveLooseMrp = policy.looseUnitMrp * surchargeFactor;
      surchargeAmount = double.parse(
        ((effectiveLooseMrp - policy.looseUnitMrp) * normalizedLoose).toStringAsFixed(2),
      );
    }

    final looseTotal = double.parse((effectiveLooseMrp * normalizedLoose).toStringAsFixed(2));
    final finalAmount = double.parse((stripTotal + looseTotal).toStringAsFixed(2));
    final isSufficient = availableStockBaseUnits >= totalUnits;

    return MobileQuoteCalculation(
      isAllowed: true,
      normalizedStrips: normalizedStrips,
      normalizedLoosePieces: normalizedLoose,
      totalBaseUnits: totalUnits,
      stripTotal: stripTotal,
      looseTotal: looseTotal,
      surchargeAmount: surchargeAmount,
      finalQuoteAmount: finalAmount,
      availableStockBaseUnits: availableStockBaseUnits,
      isStockSufficient: isSufficient,
    );
  }

  /// Executes atomic FEFO batch checkout, deducting integer base units.
  MobileCheckoutExecution executeCheckout({
    required MobileLooseSalesPolicy policy,
    required List<MobileBatchStockItem> availableBatches,
    int strips = 0,
    int loosePieces = 0,
    int? totalPieces,
    String customerName = 'Walk-in Customer',
    String customerPhone = '',
    String paymentMethod = 'CASH',
    DateTime? asOfDate,
  }) {
    final today = asOfDate ?? DateTime.now();

    int activeStock = 0;
    for (final b in availableBatches) {
      if (!b.isQuarantined && !b.isExpired(today)) {
        activeStock += b.quantityBaseUnits;
      }
    }

    final quote = calculateQuote(
      policy: policy,
      strips: strips,
      loosePieces: loosePieces,
      totalPieces: totalPieces,
      availableStockBaseUnits: activeStock,
    );

    if (!quote.isAllowed) {
      return MobileCheckoutExecution.failure(
        code: quote.errorCode ?? 'ERR_UNKNOWN',
        en: quote.errorMessageEn ?? '',
        bn: quote.errorMessageBn ?? '',
        quote: quote,
      );
    }

    if (quote.totalBaseUnits > activeStock) {
      return MobileCheckoutExecution.failure(
        code: 'ERR_INSUFFICIENT_STOCK',
        en: 'Insufficient unexpired stock available. Required: ${quote.totalBaseUnits}, Available: $activeStock',
        bn: 'পর্যাপ্ত মেয়াদযুক্ত স্টক নেই। প্রয়োজনীয়: ${quote.totalBaseUnits}, মজুদ: $activeStock',
        quote: quote,
      );
    }

    // Sort valid batches by expiry date (FEFO)
    final candidateBatches = availableBatches
        .where((b) => !b.isQuarantined && !b.isExpired(today) && b.quantityBaseUnits > 0)
        .toList()
      ..sort((a, b) {
        final cmp = a.expiryDate.compareTo(b.expiryDate);
        return cmp != 0 ? cmp : a.batchNumber.compareTo(b.batchNumber);
      });

    final allocations = <MobileBatchAllocation>[];
    int remainingToDeduct = quote.totalBaseUnits;
    final unitPrice = quote.finalQuoteAmount / quote.totalBaseUnits;

    for (final b in candidateBatches) {
      if (remainingToDeduct <= 0) break;
      final deduct = remainingToDeduct < b.quantityBaseUnits ? remainingToDeduct : b.quantityBaseUnits;
      b.quantityBaseUnits -= deduct;

      final subtotal = double.parse((unitPrice * deduct).toStringAsFixed(2));
      allocations.add(MobileBatchAllocation(
        batchId: b.batchId,
        batchNumber: b.batchNumber,
        expiryDate: b.expiryDate,
        deductedBaseUnits: deduct,
        subtotalBdt: subtotal,
      ));
      remainingToDeduct -= deduct;
    }

    final nowStr = '${today.year}${today.month.toString().padLeft(2, '0')}${today.day.toString().padLeft(2, '0')}';
    final invId = 'inv_${DateTime.now().microsecondsSinceEpoch}';
    final invNum = 'INV-$nowStr-${invId.substring(invId.length - 6).toUpperCase()}';

    return MobileCheckoutExecution(
      success: true,
      invoiceId: invId,
      invoiceNumber: invNum,
      quote: quote,
      allocations: allocations,
    );
  }

  /// Reverses a loose sale, re-crediting integer units back to corresponding batches.
  bool reverseSale({
    required MobileCheckoutExecution execution,
    required Map<String, MobileBatchStockItem> batchLookup,
  }) {
    if (!execution.success || execution.allocations.isEmpty) {
      return false;
    }

    for (final alloc in execution.allocations) {
      final batch = batchLookup[alloc.batchId];
      if (batch != null) {
        batch.quantityBaseUnits += alloc.deductedBaseUnits;
      }
    }
    return true;
  }
}
