/// MobileStockCorrectionClient
/// Architecture Decision: ADR-0174 (P174).
/// Phase 09: Packaging, Unit Conversion, Batches & Cost Lots.
///
/// Flutter mobile client governing audited stock adjustments,
/// dual-authorization manager workflows, and reversible ledger entries.
library;

enum MobileAdjustmentType {
  damage(labelEn: 'Damaged in Storage / Handling', labelBn: 'স্টোরেজে বা হ্যান্ডলিংয়ে ক্ষতিগ্রস্ত'),
  expiryRemoval(labelEn: 'Expired Stock Removal', labelBn: 'মেয়াদোত্তীর্ণ ওষুধ সরানো'),
  countCorrection(labelEn: 'Physical Count Correction', labelBn: 'শারীরিক গণনা সংশোধন'),
  internalUse(labelEn: 'Internal Clinic / Store Use', labelBn: 'অভ্যন্তরীণ ক্লিনিক / ডিসপেনসারি ব্যবহার'),
  theftLoss(labelEn: 'Theft or Unaccounted Loss', labelBn: 'চুরি বা অপ্রদর্শিত অপচয়'),
  foundSurplus(labelEn: 'Found Physical Surplus', labelBn: 'শারীরিক অতিরিক্ত মজুদ প্রাপ্তি');

  final String labelEn;
  final String labelBn;

  const MobileAdjustmentType({required this.labelEn, required this.labelBn});
}

enum MobileCorrectionStatus {
  pending(labelEn: 'Pending Approval', labelBn: 'অনুমোদনের অপেক্ষায়'),
  approved(labelEn: 'Approved & Posted', labelBn: 'অনুমোদিত ও পোস্টকৃত'),
  rejected(labelEn: 'Rejected', labelBn: 'প্রত্যাখ্যাত'),
  reversed(labelEn: 'Reversed', labelBn: 'বাতিল ও সমন্বয়কৃত');

  final String labelEn;
  final String labelBn;

  const MobileCorrectionStatus({required this.labelEn, required this.labelBn});
}

class MobileStockAdjustment {
  final String adjustmentId;
  final String tenantId;
  final String branchId;
  final String productId;
  final String batchId;
  final String? costLotId;
  final MobileAdjustmentType adjustmentType;
  final int quantityDelta;
  final double unitCostBdt;
  final double totalCostImpact;
  final String reason;
  MobileCorrectionStatus status;
  final String? proposedBy;
  String? approvedBy;
  DateTime? approvedAt;
  final String? reversalOfId;
  bool isReversed;
  String? reversalReason;
  final String supportingDocumentRef;

  MobileStockAdjustment({
    required this.adjustmentId,
    required this.tenantId,
    required this.branchId,
    required this.productId,
    required this.batchId,
    this.costLotId,
    required this.adjustmentType,
    required this.quantityDelta,
    required this.unitCostBdt,
    required this.totalCostImpact,
    required this.reason,
    this.status = MobileCorrectionStatus.pending,
    this.proposedBy,
    this.approvedBy,
    this.approvedAt,
    this.reversalOfId,
    this.isReversed = false,
    this.reversalReason,
    this.supportingDocumentRef = '',
  });

  Map<String, dynamic> toJson() {
    return {
      'adjustment_id': adjustmentId,
      'tenant_id': tenantId,
      'branch_id': branchId,
      'product_id': productId,
      'batch_id': batchId,
      'cost_lot_id': costLotId,
      'adjustment_type': adjustmentType.name.toUpperCase(),
      'quantity_delta': quantityDelta,
      'unit_cost_bdt': unitCostBdt.toStringAsFixed(4),
      'total_cost_impact': totalCostImpact.toStringAsFixed(4),
      'reason': reason,
      'status': status.name.toUpperCase(),
      'proposed_by': proposedBy,
      'approved_by': approvedBy,
      'approved_at': approvedAt?.toIso8601String(),
      'reversal_of_id': reversalOfId,
      'is_reversed': isReversed,
      'reversal_reason': reversalReason,
      'supporting_document_ref': supportingDocumentRef,
    };
  }
}

class MobileClientResponse<T> {
  final bool success;
  final T? data;
  final String? errorCode;
  final String messageEn;
  final String messageBn;

  MobileClientResponse._({
    required this.success,
    this.data,
    this.errorCode,
    required this.messageEn,
    required this.messageBn,
  });

  factory MobileClientResponse.ok(
    T data, {
    String messageEn = 'Success',
    String messageBn = 'সফল',
  }) {
    return MobileClientResponse._(
      success: true,
      data: data,
      messageEn: messageEn,
      messageBn: messageBn,
    );
  }

  factory MobileClientResponse.failure(
    String errorCode, {
    String messageEn = 'An error occurred.',
    String messageBn = 'একটি ত্রুটি ঘটেছে।',
  }) {
    return MobileClientResponse._(
      success: false,
      errorCode: errorCode,
      messageEn: messageEn,
      messageBn: messageBn,
    );
  }
}

class MobileStockCorrectionClient {
  final String tenantId;
  final String branchId;
  final String userRole;
  final String username;
  final bool isTenantSuspended;
  final Map<String, MobileStockAdjustment> ledgerStore;

  MobileStockCorrectionClient({
    required this.tenantId,
    required this.branchId,
    this.userRole = 'BRANCH_MANAGER',
    this.username = 'manager1',
    this.isTenantSuspended = false,
    Map<String, MobileStockAdjustment>? sharedStore,
  }) : ledgerStore = sharedStore ?? {};

  bool get canApprove {
    switch (userRole.toUpperCase()) {
      case 'BRANCH_MANAGER':
      case 'PHARMACY_OWNER':
      case 'SUPERADMIN':
      case 'OWNER_ADMIN':
      case 'ADMIN':
        return true;
      default:
        return false;
    }
  }

  static int _idCounter = 0;
  static String _generateId() {
    _idCounter++;
    final ts = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    final suffix = ts.length >= 8 ? ts.substring(ts.length - 8) : ts.padLeft(8, '0');
    final counterPart = (_idCounter & 0xffff).toRadixString(16).padLeft(4, '0');
    return 'stkadj-$suffix$counterPart';
  }

  MobileClientResponse<MobileStockAdjustment> proposeAdjustment({
    required String productId,
    required String batchId,
    String? costLotId,
    required MobileAdjustmentType adjustmentType,
    required int quantityDelta,
    required double unitCostBdt,
    required String reason,
    String supportingDocumentRef = '',
  }) {
    if (isTenantSuspended) {
      return MobileClientResponse.failure(
        'ERR_TENANT_SUSPENDED',
        messageEn: 'Tenant subscription is suspended.',
        messageBn: 'গ্রাহক সাবস্ক্রিপশন স্থগিত রয়েছে।',
      );
    }

    if (quantityDelta == 0) {
      return MobileClientResponse.failure(
        'ERR_ZERO_QUANTITY_DELTA',
        messageEn: 'Quantity delta cannot be zero.',
        messageBn: 'স্টক পরিবর্তনের পরিমাণ শূন্য হতে পারে না।',
      );
    }

    final cleanedReason = reason.trim();
    if (cleanedReason.length < 10) {
      return MobileClientResponse.failure(
        'ERR_AUDIT_REASON_REQUIRED',
        messageEn: 'A reasoned justification (minimum 10 characters) is strictly mandatory.',
        messageBn: 'যথাযথ নিরীক্ষা কারণ (কমপক্ষে ১০ অক্ষর) আবশ্যক।',
      );
    }

    final totalImpact = unitCostBdt * quantityDelta.abs();
    final adjId = _generateId();

    final record = MobileStockAdjustment(
      adjustmentId: adjId,
      tenantId: tenantId,
      branchId: branchId,
      productId: productId,
      batchId: batchId,
      costLotId: costLotId,
      adjustmentType: adjustmentType,
      quantityDelta: quantityDelta,
      unitCostBdt: unitCostBdt,
      totalCostImpact: totalImpact,
      reason: cleanedReason,
      status: MobileCorrectionStatus.pending,
      proposedBy: username,
      supportingDocumentRef: supportingDocumentRef,
    );

    ledgerStore[adjId] = record;
    return MobileClientResponse.ok(
      record,
      messageEn: 'Stock adjustment proposed successfully.',
      messageBn: 'স্টক সমন্বয় প্রস্তাব সফলভাবে জমা হয়েছে।',
    );
  }

  MobileClientResponse<MobileStockAdjustment> approveAdjustment({
    required String adjustmentId,
    required int currentPhysicalQty,
    required int currentReservedQty,
  }) {
    if (isTenantSuspended) {
      return MobileClientResponse.failure(
        'ERR_TENANT_SUSPENDED',
        messageEn: 'Tenant subscription is suspended.',
        messageBn: 'গ্রাহক সাবস্ক্রিপশন স্থগিত রয়েছে।',
      );
    }

    if (!canApprove) {
      return MobileClientResponse.failure(
        'ERR_PERMISSION_DENIED',
        messageEn: 'Only Branch Managers or Pharmacy Owners can approve adjustments.',
        messageBn: 'শুধুমাত্র ব্রাঞ্চ ম্যানেজার বা ফার্মেসি মালিক স্টক সমন্বয় অনুমোদন করতে পারেন।',
      );
    }

    final record = ledgerStore[adjustmentId];
    if (record == null) {
      return MobileClientResponse.failure(
        'ERR_ADJUSTMENT_NOT_FOUND',
        messageEn: 'Adjustment record not found.',
        messageBn: 'স্টক সমন্বয় রেকর্ডটি পাওয়া যায়নি।',
      );
    }

    if (record.status != MobileCorrectionStatus.pending) {
      return MobileClientResponse.failure(
        'ERR_INVALID_ADJUSTMENT_STATUS',
        messageEn: 'Only PENDING adjustments can be approved.',
        messageBn: 'কেবলমাত্র অপেক্ষারত সমন্বয় অনুমোদন করা সম্ভব।',
      );
    }

    if (record.quantityDelta < 0) {
      final availableUnreserved = currentPhysicalQty - currentReservedQty;
      if (availableUnreserved < record.quantityDelta.abs()) {
        return MobileClientResponse.failure(
          'ERR_INSUFFICIENT_UNRESERVED_STOCK',
          messageEn: 'Cannot reduce stock below active cart reservations.',
          messageBn: 'সক্রিয় কার্ট রিজার্ভেশনের নিচে স্টক কমানো যাবে না।',
        );
      }
    }

    record.status = MobileCorrectionStatus.approved;
    record.approvedBy = username;
    record.approvedAt = DateTime.now();

    return MobileClientResponse.ok(
      record,
      messageEn: 'Stock adjustment approved and posted.',
      messageBn: 'স্টক সমন্বয় অনুমোদিত ও পোস্ট করা হয়েছে।',
    );
  }

  MobileClientResponse<MobileStockAdjustment> rejectAdjustment({
    required String adjustmentId,
    required String reason,
  }) {
    if (isTenantSuspended) {
      return MobileClientResponse.failure(
        'ERR_TENANT_SUSPENDED',
        messageEn: 'Tenant subscription is suspended.',
        messageBn: 'গ্রাহক সাবস্ক্রিপশন স্থগিত রয়েছে।',
      );
    }

    if (!canApprove) {
      return MobileClientResponse.failure(
        'ERR_PERMISSION_DENIED',
        messageEn: 'Only Branch Managers or Pharmacy Owners can reject adjustments.',
        messageBn: 'শুধুমাত্র ব্রাঞ্চ ম্যানেজার বা ফার্মেসি মালিক স্টক সমন্বয় প্রত্যাখ্যান করতে পারেন।',
      );
    }

    final record = ledgerStore[adjustmentId];
    if (record == null) {
      return MobileClientResponse.failure(
        'ERR_ADJUSTMENT_NOT_FOUND',
        messageEn: 'Adjustment record not found.',
        messageBn: 'স্টক সমন্বয় রেকর্ডটি পাওয়া যায়নি।',
      );
    }

    if (record.status != MobileCorrectionStatus.pending) {
      return MobileClientResponse.failure(
        'ERR_INVALID_ADJUSTMENT_STATUS',
        messageEn: 'Only PENDING adjustments can be rejected.',
        messageBn: 'কেবলমাত্র অপেক্ষারত সমন্বয় প্রত্যাখ্যান করা সম্ভব।',
      );
    }

    final cleanedReason = reason.trim();
    if (cleanedReason.length < 10) {
      return MobileClientResponse.failure(
        'ERR_AUDIT_REASON_REQUIRED',
        messageEn: 'A valid rejection explanation (minimum 10 characters) is required.',
        messageBn: 'কমপক্ষে ১০ অক্ষরের প্রত্যাখ্যান কারণ আবশ্যক।',
      );
    }

    record.status = MobileCorrectionStatus.rejected;
    record.reversalReason = cleanedReason;
    record.approvedBy = username;
    record.approvedAt = DateTime.now();

    return MobileClientResponse.ok(
      record,
      messageEn: 'Stock adjustment rejected.',
      messageBn: 'স্টক সমন্বয় প্রত্যাখ্যাত হয়েছে।',
    );
  }

  MobileClientResponse<MobileStockAdjustment> reverseAdjustment({
    required String adjustmentId,
    required String reason,
    required int currentPhysicalQty,
    required int currentReservedQty,
  }) {
    if (isTenantSuspended) {
      return MobileClientResponse.failure(
        'ERR_TENANT_SUSPENDED',
        messageEn: 'Tenant subscription is suspended.',
        messageBn: 'গ্রাহক সাবস্ক্রিপশন স্থগিত রয়েছে।',
      );
    }

    if (!canApprove) {
      return MobileClientResponse.failure(
        'ERR_PERMISSION_DENIED',
        messageEn: 'Only Branch Managers or Pharmacy Owners can reverse adjustments.',
        messageBn: 'শুধুমাত্র ব্রাঞ্চ ম্যানেজার বা ফার্মেসি মালিক স্টক সমন্বয় বাতিল ও রিভার্স করতে পারেন।',
      );
    }

    final original = ledgerStore[adjustmentId];
    if (original == null) {
      return MobileClientResponse.failure(
        'ERR_ADJUSTMENT_NOT_FOUND',
        messageEn: 'Adjustment record not found.',
        messageBn: 'স্টক সমন্বয় রেকর্ডটি পাওয়া যায়নি।',
      );
    }

    if (original.isReversed || original.status == MobileCorrectionStatus.reversed) {
      return MobileClientResponse.failure(
        'ERR_ALREADY_REVERSED',
        messageEn: 'Adjustment has already been reversed.',
        messageBn: 'সমন্বয়টি ইতিমধ্যে রিভার্স করা হয়েছে।',
      );
    }

    if (original.status != MobileCorrectionStatus.approved) {
      return MobileClientResponse.failure(
        'ERR_CANNOT_REVERSE_UNAPPROVED',
        messageEn: 'Only APPROVED adjustments can be reversed.',
        messageBn: 'শুধুমাত্র অনুমোদিত সমন্বয় রিভার্স করা সম্ভব।',
      );
    }

    final cleanedReason = reason.trim();
    if (cleanedReason.length < 10) {
      return MobileClientResponse.failure(
        'ERR_AUDIT_REASON_REQUIRED',
        messageEn: 'A valid reversal justification (minimum 10 characters) is mandatory.',
        messageBn: 'কমপক্ষে ১০ অক্ষরের রিভার্সাল কারণ আবশ্যক।',
      );
    }

    final reversingDelta = -original.quantityDelta;
    if (reversingDelta < 0) {
      final availableUnreserved = currentPhysicalQty - currentReservedQty;
      if (availableUnreserved < reversingDelta.abs()) {
        return MobileClientResponse.failure(
          'ERR_INSUFFICIENT_UNRESERVED_STOCK',
          messageEn: 'Cannot reverse adjustment due to active cart reservations.',
          messageBn: 'সক্রিয় কার্ট রিজার্ভেশনের কারণে রিভার্স করা সম্ভব নয়।',
        );
      }
    }

    final revId = _generateId();

    final reversalRecord = MobileStockAdjustment(
      adjustmentId: revId,
      tenantId: original.tenantId,
      branchId: original.branchId,
      productId: original.productId,
      batchId: original.batchId,
      costLotId: original.costLotId,
      adjustmentType: original.adjustmentType,
      quantityDelta: reversingDelta,
      unitCostBdt: original.unitCostBdt,
      totalCostImpact: original.totalCostImpact,
      reason: 'Reversal of ${original.adjustmentId}: $cleanedReason',
      status: MobileCorrectionStatus.approved,
      proposedBy: username,
      approvedBy: username,
      approvedAt: DateTime.now(),
      reversalOfId: original.adjustmentId,
      isReversed: false,
      supportingDocumentRef: original.supportingDocumentRef,
    );

    original.isReversed = true;
    original.status = MobileCorrectionStatus.reversed;
    original.reversalReason = cleanedReason;

    ledgerStore[revId] = reversalRecord;
    return MobileClientResponse.ok(
      reversalRecord,
      messageEn: 'Stock adjustment reversed successfully.',
      messageBn: 'স্টক সমন্বয় সফলভাবে রিভার্স করা হয়েছে।',
    );
  }
}
