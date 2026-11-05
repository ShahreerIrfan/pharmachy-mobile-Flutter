/// MobileLandedCostClient
/// Architecture Decision: ADR-0176 (P176).
/// Phase 09: Packaging, Unit Conversion, Batches & Cost Lots.
///
/// Flutter mobile client handling landed freight, transport, handling,
/// and cold-chain logistics cost allocation across purchase cost lots
/// with exact paisa conservation, GAAP/IAS 2 inventory capitalization,
/// and audited reversals.
library;

enum MobileExpenseType {
  transportFreight(
    labelEn: 'Transport & Freight',
    labelBn: 'পরিবহন ও ভাড়া খরচ',
  ),
  handlingLabor(
    labelEn: 'Handling & Unloading Labor',
    labelBn: 'পণ্য খালাস ও হ্যান্ডলিং মজুরি',
  ),
  insuranceTariff(
    labelEn: 'Transit Insurance & Tariff',
    labelBn: 'পরিবহন বীমা ও আমদানি শুল্ক',
  ),
  coldChainLogistics(
    labelEn: 'Cold-Chain Ice/Refrigeration',
    labelBn: 'কোল্ড-চেইন আইস ও ফ্রিজিং খরচ',
  ),
  regulatoryFee(
    labelEn: 'DGDA / Port Regulatory Clearing Fee',
    labelBn: 'ডিজিডিএ / পোর্ট ছাড়পত্র ফি',
  ),
  other(
    labelEn: 'Other Landed Incidental',
    labelBn: 'অন্যান্য প্রত্যক্ষ খরচ',
  );

  final String labelEn;
  final String labelBn;

  const MobileExpenseType({required this.labelEn, required this.labelBn});
}

enum MobileAllocationMethod {
  byValue(
    labelEn: 'Pro-Rata by Purchase Value',
    labelBn: 'ক্রয়মূল্য অনুপাতে বণ্টন',
  ),
  byQuantity(
    labelEn: 'Pro-Rata by Quantity',
    labelBn: 'পরিমাণ অনুপাতে বণ্টন',
  ),
  manualEqual(
    labelEn: 'Equal Split Across Cost Lots',
    labelBn: 'সমান ভাগে বণ্টন',
  );

  final String labelEn;
  final String labelBn;

  const MobileAllocationMethod({required this.labelEn, required this.labelBn});
}

enum MobileLandedCostStatus {
  draft(labelEn: 'Draft Calculation', labelBn: 'খসড়া হিসাব'),
  posted(labelEn: 'Posted & Capitalized', labelBn: 'পোস্টকৃত ও মূল্যায়িত'),
  reversed(labelEn: 'Reversed', labelBn: 'বাতিল ও সমন্বয়কৃত');

  final String labelEn;
  final String labelBn;

  const MobileLandedCostStatus({required this.labelEn, required this.labelBn});
}

class MobileCostLotInput {
  final String costLotId;
  final String batchId;
  final String productId;
  final String productName;
  final double basePurchaseUnitCost;
  final int initialQuantity;

  const MobileCostLotInput({
    required this.costLotId,
    required this.batchId,
    required this.productId,
    required this.productName,
    required this.basePurchaseUnitCost,
    required this.initialQuantity,
  });

  double get lineValue => basePurchaseUnitCost * initialQuantity;
}

class MobileLandedCostAllocationLine {
  final String lineId;
  final String costLotId;
  final String batchId;
  final String productId;
  final String productName;
  final double basePurchaseUnitCost;
  final int initialQuantity;
  final double lineValue;
  final double allocationFactor;
  final double allocatedExpenseAmount;
  final double landedUnitCost;

  const MobileLandedCostAllocationLine({
    required this.lineId,
    required this.costLotId,
    required this.batchId,
    required this.productId,
    required this.productName,
    required this.basePurchaseUnitCost,
    required this.initialQuantity,
    required this.lineValue,
    required this.allocationFactor,
    required this.allocatedExpenseAmount,
    required this.landedUnitCost,
  });

  Map<String, dynamic> toJson() {
    return {
      'line_id': lineId,
      'cost_lot_id': costLotId,
      'batch_id': batchId,
      'product_id': productId,
      'product_name': productName,
      'base_purchase_unit_cost': basePurchaseUnitCost.toStringAsFixed(4),
      'initial_quantity': initialQuantity,
      'line_value': lineValue.toStringAsFixed(4),
      'allocation_factor': allocationFactor.toStringAsFixed(6),
      'allocated_expense_amount': allocatedExpenseAmount.toStringAsFixed(4),
      'landed_unit_cost': landedUnitCost.toStringAsFixed(4),
    };
  }
}

class MobileLandedCostExpense {
  final String expenseId;
  final String tenantId;
  final String branchId;
  final String grnId;
  final MobileExpenseType expenseType;
  final MobileAllocationMethod allocationMethod;
  final double totalExpenseBdt;
  final String invoiceOrReference;
  final String carrierOrVendor;
  final String notes;
  MobileLandedCostStatus status;
  final String recordedBy;
  final DateTime createdAt;
  DateTime? reversedAt;
  String? reversedBy;
  String? reversalReason;
  final List<MobileLandedCostAllocationLine> lines;

  MobileLandedCostExpense({
    required this.expenseId,
    required this.tenantId,
    required this.branchId,
    required this.grnId,
    required this.expenseType,
    required this.allocationMethod,
    required this.totalExpenseBdt,
    required this.invoiceOrReference,
    required this.carrierOrVendor,
    required this.notes,
    this.status = MobileLandedCostStatus.posted,
    required this.recordedBy,
    required this.createdAt,
    this.reversedAt,
    this.reversedBy,
    this.reversalReason,
    required this.lines,
  });

  Map<String, dynamic> toJson() {
    return {
      'expense_id': expenseId,
      'tenant_id': tenantId,
      'branch_id': branchId,
      'grn_id': grnId,
      'expense_type': expenseType.name.toUpperCase(),
      'allocation_method': allocationMethod.name.toUpperCase(),
      'total_expense_bdt': totalExpenseBdt.toStringAsFixed(4),
      'invoice_or_reference': invoiceOrReference,
      'carrier_or_vendor': carrierOrVendor,
      'notes': notes,
      'status': status.name.toUpperCase(),
      'recorded_by': recordedBy,
      'created_at': createdAt.toIso8601String(),
      'reversed_at': reversedAt?.toIso8601String(),
      'reversed_by': reversedBy,
      'reversal_reason': reversalReason,
      'lines': lines.map((l) => l.toJson()).toList(),
    };
  }
}

class MobileLandedCostResult<T> {
  final bool success;
  final T? data;
  final String? errorCode;
  final String messageEn;
  final String messageBn;

  const MobileLandedCostResult._({
    required this.success,
    this.data,
    this.errorCode,
    required this.messageEn,
    required this.messageBn,
  });

  factory MobileLandedCostResult.ok(T data, String msgEn, String msgBn) {
    return MobileLandedCostResult._(
      success: true,
      data: data,
      messageEn: msgEn,
      messageBn: msgBn,
    );
  }

  factory MobileLandedCostResult.error(String code, String msgEn, String msgBn) {
    return MobileLandedCostResult._(
      success: false,
      errorCode: code,
      messageEn: msgEn,
      messageBn: msgBn,
    );
  }
}

class MobileLandedCostClient {
  static int _idCounter = 0;

  final String tenantId;
  final String branchId;
  final String userRole;
  final String userId;
  final bool isOffline;
  final Map<String, MobileLandedCostExpense> expenseStore;

  MobileLandedCostClient({
    required this.tenantId,
    required this.branchId,
    required this.userRole,
    required this.userId,
    this.isOffline = false,
    Map<String, MobileLandedCostExpense>? sharedStore,
  }) : expenseStore = sharedStore ?? <String, MobileLandedCostExpense>{};

  bool get isAuthorized =>
      userRole.toUpperCase() == 'TENANT_ADMIN' ||
      userRole.toUpperCase() == 'STORE_MANAGER' ||
      userRole.toUpperCase() == 'PHARMACY_OWNER';

  String _generateUniqueId(String prefix) {
    _idCounter++;
    final ts = DateTime.now().millisecondsSinceEpoch % 1000000;
    return '$prefix-$ts-$_idCounter';
  }

  /// Pure allocation calculation preview with exact penny / paisa conservation.
  MobileLandedCostResult<List<MobileLandedCostAllocationLine>> previewAllocations(
    double totalExpenseBdt,
    MobileAllocationMethod method,
    List<MobileCostLotInput> lots,
  ) {
    if (totalExpenseBdt <= 0.0) {
      return MobileLandedCostResult.error(
        'ERR_INVALID_AMOUNT',
        'Total landed cost expense must be greater than zero.',
        'মোট ল্যান্ডেড খরচ শূন্যের বেশি হতে হবে।',
      );
    }

    if (lots.isEmpty) {
      return MobileLandedCostResult.error(
        'ERR_NO_LOTS',
        'At least one cost lot must be provided for allocation.',
        'খরচ বণ্টনের জন্য অন্তত একটি কস্ট লট নির্বাচন করতে হবে।',
      );
    }

    // Convert total to integer fraction of 4 decimal places (1 unit = 0.0001 BDT)
    final totalUnits = (totalExpenseBdt * 10000.0).round();
    final lines = <MobileLandedCostAllocationLine>[];

    if (method == MobileAllocationMethod.byQuantity) {
      final totalQty = lots.fold<int>(0, (sum, l) => sum + l.initialQuantity);
      if (totalQty <= 0) {
        return MobileLandedCostResult.error(
          'ERR_ZERO_QUANTITY',
          'Total initial quantity cannot be zero.',
          'মোট প্রারম্ভিক পরিমাণ শূন্য হতে পারে না।',
        );
      }

      var runningUnits = 0;
      var maxQtyIdx = 0;
      var maxQty = -1;

      for (var i = 0; i < lots.length; i++) {
        final lot = lots[i];
        if (lot.initialQuantity > maxQty) {
          maxQty = lot.initialQuantity;
          maxQtyIdx = i;
        }

        final factor = lot.initialQuantity / totalQty;
        // Pro-rata integer units: (totalUnits * qty) / totalQty
        final allocatedUnits = ((totalUnits * lot.initialQuantity) / totalQty).round();
        runningUnits += allocatedUnits;

        final allocatedAmt = allocatedUnits / 10000.0;
        final perUnitAdd = allocatedAmt / lot.initialQuantity;
        final landedUnit = lot.basePurchaseUnitCost + perUnitAdd;

        lines.add(
          MobileLandedCostAllocationLine(
            lineId: _generateUniqueId('line'),
            costLotId: lot.costLotId,
            batchId: lot.batchId,
            productId: lot.productId,
            productName: lot.productName,
            basePurchaseUnitCost: lot.basePurchaseUnitCost,
            initialQuantity: lot.initialQuantity,
            lineValue: lot.lineValue,
            allocationFactor: factor,
            allocatedExpenseAmount: allocatedAmt,
            landedUnitCost: landedUnit,
          ),
        );
      }

      // Remainder paisa correction for 100% exact penny conservation
      final remainderUnits = totalUnits - runningUnits;
      if (remainderUnits != 0 && maxQtyIdx < lines.length) {
        final old = lines[maxQtyIdx];
        final fixedUnits = (old.allocatedExpenseAmount * 10000.0).round() + remainderUnits;
        final fixedAmt = fixedUnits / 10000.0;
        final fixedLanded = old.basePurchaseUnitCost + (fixedAmt / old.initialQuantity);

        lines[maxQtyIdx] = MobileLandedCostAllocationLine(
          lineId: old.lineId,
          costLotId: old.costLotId,
          batchId: old.batchId,
          productId: old.productId,
          productName: old.productName,
          basePurchaseUnitCost: old.basePurchaseUnitCost,
          initialQuantity: old.initialQuantity,
          lineValue: old.lineValue,
          allocationFactor: old.allocationFactor,
          allocatedExpenseAmount: fixedAmt,
          landedUnitCost: fixedLanded,
        );
      }
    } else if (method == MobileAllocationMethod.manualEqual) {
      final count = lots.length;
      final equalUnits = totalUnits ~/ count;
      var runningUnits = 0;

      for (var i = 0; i < count; i++) {
        final lot = lots[i];
        final factor = 1.0 / count;
        runningUnits += equalUnits;

        final allocatedAmt = equalUnits / 10000.0;
        final perUnitAdd = allocatedAmt / lot.initialQuantity;
        final landedUnit = lot.basePurchaseUnitCost + perUnitAdd;

        lines.add(
          MobileLandedCostAllocationLine(
            lineId: _generateUniqueId('line'),
            costLotId: lot.costLotId,
            batchId: lot.batchId,
            productId: lot.productId,
            productName: lot.productName,
            basePurchaseUnitCost: lot.basePurchaseUnitCost,
            initialQuantity: lot.initialQuantity,
            lineValue: lot.lineValue,
            allocationFactor: factor,
            allocatedExpenseAmount: allocatedAmt,
            landedUnitCost: landedUnit,
          ),
        );
      }

      final remainderUnits = totalUnits - runningUnits;
      if (remainderUnits != 0 && lines.isNotEmpty) {
        final old = lines.first;
        final fixedUnits = (old.allocatedExpenseAmount * 10000.0).round() + remainderUnits;
        final fixedAmt = fixedUnits / 10000.0;
        final fixedLanded = old.basePurchaseUnitCost + (fixedAmt / old.initialQuantity);

        lines[0] = MobileLandedCostAllocationLine(
          lineId: old.lineId,
          costLotId: old.costLotId,
          batchId: old.batchId,
          productId: old.productId,
          productName: old.productName,
          basePurchaseUnitCost: old.basePurchaseUnitCost,
          initialQuantity: old.initialQuantity,
          lineValue: old.lineValue,
          allocationFactor: old.allocationFactor,
          allocatedExpenseAmount: fixedAmt,
          landedUnitCost: fixedLanded,
        );
      }
    } else {
      // Default: byValue
      final totalValue = lots.fold<double>(0.0, (sum, l) => sum + l.lineValue);
      if (totalValue <= 0.0) {
        return MobileLandedCostResult.error(
          'ERR_ZERO_PURCHASE_VALUE',
          'Total purchase value must be greater than zero for value-based allocation.',
          'মূল্য অনুপাতে বণ্টনের জন্য মোট ক্রয়মূল্য শূন্যের বেশি হতে হবে।',
        );
      }

      var runningUnits = 0;
      var maxValueIdx = 0;
      var maxValue = -1.0;

      for (var i = 0; i < lots.length; i++) {
        final lot = lots[i];
        if (lot.lineValue > maxValue) {
          maxValue = lot.lineValue;
          maxValueIdx = i;
        }

        final factor = lot.lineValue / totalValue;
        final allocatedUnits = ((totalUnits * lot.lineValue) / totalValue).round();
        runningUnits += allocatedUnits;

        final allocatedAmt = allocatedUnits / 10000.0;
        final perUnitAdd = allocatedAmt / lot.initialQuantity;
        final landedUnit = lot.basePurchaseUnitCost + perUnitAdd;

        lines.add(
          MobileLandedCostAllocationLine(
            lineId: _generateUniqueId('line'),
            costLotId: lot.costLotId,
            batchId: lot.batchId,
            productId: lot.productId,
            productName: lot.productName,
            basePurchaseUnitCost: lot.basePurchaseUnitCost,
            initialQuantity: lot.initialQuantity,
            lineValue: lot.lineValue,
            allocationFactor: factor,
            allocatedExpenseAmount: allocatedAmt,
            landedUnitCost: landedUnit,
          ),
        );
      }

      final remainderUnits = totalUnits - runningUnits;
      if (remainderUnits != 0 && maxValueIdx < lines.length) {
        final old = lines[maxValueIdx];
        final fixedUnits = (old.allocatedExpenseAmount * 10000.0).round() + remainderUnits;
        final fixedAmt = fixedUnits / 10000.0;
        final fixedLanded = old.basePurchaseUnitCost + (fixedAmt / old.initialQuantity);

        lines[maxValueIdx] = MobileLandedCostAllocationLine(
          lineId: old.lineId,
          costLotId: old.costLotId,
          batchId: old.batchId,
          productId: old.productId,
          productName: old.productName,
          basePurchaseUnitCost: old.basePurchaseUnitCost,
          initialQuantity: old.initialQuantity,
          lineValue: old.lineValue,
          allocationFactor: old.allocationFactor,
          allocatedExpenseAmount: fixedAmt,
          landedUnitCost: fixedLanded,
        );
      }
    }

    return MobileLandedCostResult.ok(
      lines,
      'Allocations previewed successfully.',
      'ল্যান্ডেড খরচ বণ্টন সফলভাবে হিসাব করা হয়েছে।',
    );
  }

  /// Create and post landed cost expense, capitalizing lots.
  MobileLandedCostResult<MobileLandedCostExpense> createAndPostLandedCost({
    required String grnId,
    required MobileExpenseType expenseType,
    required MobileAllocationMethod allocationMethod,
    required double totalExpenseBdt,
    required String invoiceOrReference,
    required String carrierOrVendor,
    required String notes,
    required List<MobileCostLotInput> lots,
  }) {
    if (!isAuthorized) {
      return MobileLandedCostResult.error(
        'ERR_PERMISSION_DENIED',
        'Cashiers and unauthorized personnel cannot post landed cost capitalization.',
        'ক্যাশিয়ার বা সাধারণ বিক্রয়কর্মীদের ল্যান্ডেড খরচ যুক্ত করার অনুমতি নেই।',
      );
    }

    final previewRes = previewAllocations(totalExpenseBdt, allocationMethod, lots);
    if (!previewRes.success) {
      return MobileLandedCostResult.error(
        previewRes.errorCode!,
        previewRes.messageEn,
        previewRes.messageBn,
      );
    }

    final expenseId = _generateUniqueId('lc');
    final expense = MobileLandedCostExpense(
      expenseId: expenseId,
      tenantId: tenantId,
      branchId: branchId,
      grnId: grnId,
      expenseType: expenseType,
      allocationMethod: allocationMethod,
      totalExpenseBdt: totalExpenseBdt,
      invoiceOrReference: invoiceOrReference,
      carrierOrVendor: carrierOrVendor,
      notes: notes,
      status: MobileLandedCostStatus.posted,
      recordedBy: userId,
      createdAt: DateTime.now(),
      lines: previewRes.data!,
    );

    expenseStore[expenseId] = expense;

    return MobileLandedCostResult.ok(
      expense,
      'Landed cost posted and capitalized successfully.',
      'ল্যান্ডেড খরচ সফলভাবে পোস্ট এবং কস্ট লটে সমন্বয় করা হয়েছে।',
    );
  }

  /// Reverses an existing landed cost allocation.
  MobileLandedCostResult<MobileLandedCostExpense> reverseLandedCost({
    required String expenseId,
    required String reason,
  }) {
    if (!isAuthorized) {
      return MobileLandedCostResult.error(
        'ERR_PERMISSION_DENIED',
        'Cashiers and unauthorized personnel cannot reverse landed cost capitalization.',
        'ক্যাশিয়ার বা সাধারণ বিক্রয়কর্মীদের ল্যান্ডেড খরচ বাতিল করার অনুমতি নেই।',
      );
    }

    if (reason.trim().length < 5) {
      return MobileLandedCostResult.error(
        'ERR_REASON_REQUIRED',
        'A valid reason of at least 5 characters is required for reversal.',
        'ল্যান্ডেড খরচ বাতিলের জন্য সুস্পষ্ট কারণ উল্লেখ করা আবশ্যক।',
      );
    }

    final existing = expenseStore[expenseId];
    if (existing == null) {
      return MobileLandedCostResult.error(
        'ERR_NOT_FOUND',
        'Landed cost expense record not found.',
        'ল্যান্ডেড খরচের রেকর্ড পাওয়া যায়নি।',
      );
    }

    if (existing.tenantId != tenantId || existing.branchId != branchId) {
      return MobileLandedCostResult.error(
        'ERR_CROSS_BRANCH_ACCESS',
        'Cannot reverse landed cost from another tenant or branch.',
        'অন্য শাখা বা প্রতিষ্ঠানের ল্যান্ডেড খরচ বাতিল করা নিষিদ্ধ।',
      );
    }

    if (existing.status == MobileLandedCostStatus.reversed) {
      return MobileLandedCostResult.error(
        'ERR_ALREADY_REVERSED',
        'This landed cost expense has already been reversed.',
        'এই ল্যান্ডেড খরচটি পূর্বেই বাতিল করা হয়েছে।',
      );
    }

    existing.status = MobileLandedCostStatus.reversed;
    existing.reversedAt = DateTime.now();
    existing.reversedBy = userId;
    existing.reversalReason = reason;

    return MobileLandedCostResult.ok(
      existing,
      'Landed cost expense reversed successfully.',
      'ল্যান্ডেড খরচ সফলভাবে বাতিল করা হয়েছে এবং মূল খরচ পুনর্বহাল করা হয়েছে।',
    );
  }

  MobileLandedCostResult<List<MobileLandedCostExpense>> listExpenses() {
    final list = expenseStore.values
        .where((e) => e.tenantId == tenantId && e.branchId == branchId)
        .toList();
    return MobileLandedCostResult.ok(list, 'Expenses retrieved.', 'খরচ তালিকা প্রাপ্ত হয়েছে।');
  }

  MobileLandedCostResult<MobileLandedCostExpense> getExpense(String expenseId) {
    final exp = expenseStore[expenseId];
    if (exp == null || exp.tenantId != tenantId || exp.branchId != branchId) {
      return MobileLandedCostResult.error('ERR_NOT_FOUND', 'Expense not found.', 'খরচ পাওয়া যায়নি।');
    }
    return MobileLandedCostResult.ok(exp, 'Expense found.', 'খরচ পাওয়া গেছে।');
  }
}

