/// MobileNonDivisiblePackClient
/// Architecture Decision: ADR-0165 (P165).
/// Phase 09: Packaging, Unit Conversion, Batches & Cost Lots.
///
/// Mobile non-divisible pack and sterile container guardrail engine for Flutter Mobile Manager.
/// Enforces blister/device integrity for insulin pens, inhalers, eye drop bottles, diagnostic kits,
/// and clinical exemption protocol requirements.
library;

class MobileNonDivisiblePolicy {
  final String policyId;
  final String tenantId;
  final String? branchId;
  final String productId;
  final String productName;
  final String containerType;
  final bool isSplittingAllowed;
  final bool requirePharmacistApproval;
  final int approvedBreakFactor;
  final String subUnitLabel;
  final String prohibitionReason;
  final Set<String> exemptionProtocols;

  const MobileNonDivisiblePolicy({
    required this.policyId,
    required this.tenantId,
    this.branchId,
    required this.productId,
    this.productName = '',
    this.containerType = 'SEALED_BOX',
    this.isSplittingAllowed = false,
    this.requirePharmacistApproval = true,
    this.approvedBreakFactor = 1,
    this.subUnitLabel = 'PIECE',
    this.prohibitionReason = '',
    this.exemptionProtocols = const {},
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

class MobileValidationResult {
  final bool isAllowed;
  final String? errorCode;
  final String? errorMessageEn;
  final String? errorMessageBn;
  final String productId;
  final String containerType;
  final bool isSplittingAllowed;
  final int approvedBreakFactor;
  final String subUnitLabel;
  final bool isSplitRequest;
  final String? exemptionProtocol;

  const MobileValidationResult({
    required this.isAllowed,
    this.errorCode,
    this.errorMessageEn,
    this.errorMessageBn,
    required this.productId,
    required this.containerType,
    required this.isSplittingAllowed,
    required this.approvedBreakFactor,
    required this.subUnitLabel,
    this.isSplitRequest = false,
    this.exemptionProtocol,
  });

  factory MobileValidationResult.ok(MobileNonDivisiblePolicy? policy, {bool isSplit = false, String? protocol}) {
    return MobileValidationResult(
      isAllowed: true,
      productId: policy?.productId ?? '',
      containerType: policy?.containerType ?? 'STANDARD_PACK',
      isSplittingAllowed: policy?.isSplittingAllowed ?? true,
      approvedBreakFactor: policy?.approvedBreakFactor ?? 1,
      subUnitLabel: policy?.subUnitLabel ?? 'PIECE',
      isSplitRequest: isSplit,
      exemptionProtocol: protocol,
    );
  }

  factory MobileValidationResult.failure({
    required String code,
    required String en,
    required String bn,
    MobileNonDivisiblePolicy? policy,
    bool isSplit = false,
    String? protocol,
  }) {
    return MobileValidationResult(
      isAllowed: false,
      errorCode: code,
      errorMessageEn: en,
      errorMessageBn: bn,
      productId: policy?.productId ?? '',
      containerType: policy?.containerType ?? 'UNKNOWN',
      isSplittingAllowed: policy?.isSplittingAllowed ?? false,
      approvedBreakFactor: policy?.approvedBreakFactor ?? 1,
      subUnitLabel: policy?.subUnitLabel ?? 'PIECE',
      isSplitRequest: isSplit,
      exemptionProtocol: protocol,
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

class MobileCheckoutResult {
  final bool success;
  final String? invoiceId;
  final String? invoiceNumber;
  final String? errorCode;
  final String? errorMessageEn;
  final String? errorMessageBn;
  final MobileValidationResult validation;
  final List<MobileBatchAllocation> allocations;

  const MobileCheckoutResult({
    required this.success,
    this.invoiceId,
    this.invoiceNumber,
    this.errorCode,
    this.errorMessageEn,
    this.errorMessageBn,
    required this.validation,
    this.allocations = const [],
  });

  factory MobileCheckoutResult.failure({
    required String code,
    required String en,
    required String bn,
    required MobileValidationResult val,
  }) {
    return MobileCheckoutResult(
      success: false,
      errorCode: code,
      errorMessageEn: en,
      errorMessageBn: bn,
      validation: val,
      allocations: const [],
    );
  }
}

class MobileNonDivisiblePackClient {
  const MobileNonDivisiblePackClient();

  /// Pre-flight validation against container integrity and clinical exemption protocols.
  MobileValidationResult validateDispense({
    MobileNonDivisiblePolicy? policy,
    required double requestedQuantity,
    bool isSplitRequest = false,
    String? exemptionProtocol,
    String? userRole,
  }) {
    if (requestedQuantity <= 0.0) {
      return MobileValidationResult.failure(
        code: 'ERR_INVALID_QUANTITY',
        en: 'Requested quantity must be positive.',
        bn: 'পরিমাণ শূন্যের বেশি হতে হবে।',
        policy: policy,
        isSplit: isSplitRequest,
        protocol: exemptionProtocol,
      );
    }

    if (policy == null) {
      return MobileValidationResult.ok(null, isSplit: isSplitRequest, protocol: exemptionProtocol);
    }

    // 1. Fractional quantity guardrail
    if (requestedQuantity % 1.0 != 0.0) {
      final en = 'Fractional dispensing of non-divisible container (${policy.containerType}) is strictly prohibited.';
      final bn = 'অবিভাজ্য কন্টেইনারের (${policy.containerType}) ভগ্নাংশ বা আংশিক বিক্রয় সম্পূর্ণ নিষিদ্ধ।';
      return MobileValidationResult.failure(
        code: 'ERR_NON_DIVISIBLE_CONTAINER_SPLIT_PROHIBITED',
        en: en,
        bn: bn,
        policy: policy,
        isSplit: isSplitRequest,
        protocol: exemptionProtocol,
      );
    }

    // 2. Container splitting checks
    if (isSplitRequest) {
      if (!policy.isSplittingAllowed) {
        final en = 'Breaking sealed container (${policy.containerType}) is strictly prohibited: ${policy.prohibitionReason}';
        final bn = 'সিল্ড কন্টেইনার ভেঙে বিক্রি করা সম্পূর্ণ নিষিদ্ধ: ${policy.prohibitionReason}';
        return MobileValidationResult.failure(
          code: 'ERR_NON_DIVISIBLE_CONTAINER_SPLIT_PROHIBITED',
          en: en,
          bn: bn,
          policy: policy,
          isSplit: isSplitRequest,
          protocol: exemptionProtocol,
        );
      }

      // Exemption protocol check
      if (policy.exemptionProtocols.isNotEmpty) {
        final protoUpper = exemptionProtocol?.trim().toUpperCase() ?? '';
        if (!policy.exemptionProtocols.contains(protoUpper)) {
          final en = 'Approved clinical exemption protocol required to split container. Permitted: ${policy.exemptionProtocols}';
          const bn = 'কন্টেইনার বিভাজনের জন্য অনুমোদিত ক্লিনিক্যাল প্রোটোকল প্রয়োজন।';
          return MobileValidationResult.failure(
            code: 'ERR_INVALID_EXEMPTION_PROTOCOL',
            en: en,
            bn: bn,
            policy: policy,
            isSplit: isSplitRequest,
            protocol: exemptionProtocol,
          );
        }
      }

      // Role check: Cashier cannot unilaterally authorize splitting
      if (policy.requirePharmacistApproval) {
        final r = userRole?.trim().toUpperCase();
        if (r == null || r == 'CASHIER') {
          const en = 'Cashier role cannot authorize breaking a non-divisible container. Pharmacist or Manager sign-off required.';
          const bn = 'ক্যাশিয়ার কর্তৃক অবিভাজ্য কন্টেইনার বিভাজনের অনুমোদন দেওয়া নিষিদ্ধ। ফার্মাসিস্টের অনুমোদন আবশ্যক।';
          return MobileValidationResult.failure(
            code: 'ERR_ROLE_UNAUTHORIZED',
            en: en,
            bn: bn,
            policy: policy,
            isSplit: isSplitRequest,
            protocol: exemptionProtocol,
          );
        }
      }
    }

    return MobileValidationResult.ok(policy, isSplit: isSplitRequest, protocol: exemptionProtocol);
  }

  /// Executes atomic FEFO batch checkout.
  MobileCheckoutResult executeCheckout({
    MobileNonDivisiblePolicy? policy,
    required List<MobileBatchStockItem> availableBatches,
    required double requestedQuantity,
    bool isSplitRequest = false,
    String? exemptionProtocol,
    String? userRole,
    double unitPrice = 0.0,
    DateTime? asOfDate,
  }) {
    final today = asOfDate ?? DateTime.now();

    final val = validateDispense(
      policy: policy,
      requestedQuantity: requestedQuantity,
      isSplitRequest: isSplitRequest,
      exemptionProtocol: exemptionProtocol,
      userRole: userRole,
    );

    if (!val.isAllowed) {
      return MobileCheckoutResult.failure(
        code: val.errorCode ?? 'ERR_VALIDATION_FAILED',
        en: val.errorMessageEn ?? '',
        bn: val.errorMessageBn ?? '',
        val: val,
      );
    }

    final totalUnits = requestedQuantity.toInt();
    int activeStock = 0;
    for (final b in availableBatches) {
      if (!b.isQuarantined && !b.isExpired(today)) {
        activeStock += b.quantityBaseUnits;
      }
    }

    if (totalUnits > activeStock) {
      return MobileCheckoutResult.failure(
        code: 'ERR_INSUFFICIENT_STOCK',
        en: 'Insufficient unexpired stock available. Required: $totalUnits, Available: $activeStock',
        bn: 'পর্যাপ্ত মেয়াদযুক্ত স্টক নেই। প্রয়োজনীয়: $totalUnits, মজুদ: $activeStock',
        val: val,
      );
    }

    // Sort candidate batches by FEFO
    final candidateBatches = availableBatches
        .where((b) => !b.isQuarantined && !b.isExpired(today) && b.quantityBaseUnits > 0)
        .toList()
      ..sort((a, b) {
        final cmp = a.expiryDate.compareTo(b.expiryDate);
        return cmp != 0 ? cmp : a.batchNumber.compareTo(b.batchNumber);
      });

    final allocations = <MobileBatchAllocation>[];
    int remaining = totalUnits;

    for (final b in candidateBatches) {
      if (remaining <= 0) break;
      final deduct = remaining < b.quantityBaseUnits ? remaining : b.quantityBaseUnits;
      b.quantityBaseUnits -= deduct;

      final subtotal = double.parse((unitPrice * deduct).toStringAsFixed(2));
      allocations.add(MobileBatchAllocation(
        batchId: b.batchId,
        batchNumber: b.batchNumber,
        expiryDate: b.expiryDate,
        deductedBaseUnits: deduct,
        subtotalBdt: subtotal,
      ));
      remaining -= deduct;
    }

    final nowStr = '${today.year}${today.month.toString().padLeft(2, '0')}${today.day.toString().padLeft(2, '0')}';
    final invId = 'inv_${DateTime.now().microsecondsSinceEpoch}';
    final invNum = 'INV-$nowStr-${invId.substring(invId.length - 6).toUpperCase()}';

    return MobileCheckoutResult(
      success: true,
      invoiceId: invId,
      invoiceNumber: invNum,
      validation: val,
      allocations: allocations,
    );
  }

  /// Reverses a non-divisible pack sale, re-crediting integer units back to batches.
  bool reverseSale({
    required MobileCheckoutResult checkout,
    required Map<String, MobileBatchStockItem> batchLookup,
  }) {
    if (!checkout.success || checkout.allocations.isEmpty) {
      return false;
    }

    for (final alloc in checkout.allocations) {
      final batch = batchLookup[alloc.batchId];
      if (batch != null) {
        batch.quantityBaseUnits += alloc.deductedBaseUnits;
      }
    }
    return true;
  }
}
