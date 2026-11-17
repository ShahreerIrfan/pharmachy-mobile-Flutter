/// mobile_stock_movement_correction_client.dart
/// Architecture Decision: ADR-0217 (P217).
/// Phase 11: Inventory, Warehouse, Cold Chain & Transfers.
///
/// Mobile Manager Client for Audited Stock Movement Corrections:
/// - Reverses incorrect posted inventory moves using compensating entries.
/// - Bars direct row overwrites and deletions on posted ledger records.
/// - Enforces double-reversal prevention and negative stock guards.
/// - Role-based authorization (Cashier denied).

enum MobileCorrectionReason {
  mistypedQuantity('Mistyped Quantity Count', 'ভুল পরিমাণ টাইপ'),
  wrongBatchAllocation('Wrong Batch Stock Selected', 'ভুল ব্যাচ নির্বাচন'),
  duplicatePosting('Duplicate Movement Posting', 'ডুপ্লিকেট মুভমেন্ট পোস্টিং'),
  systemGlitchRecovery('Sync Glitch Recovery', 'সিংক ত্রুটি সংশোধন'),
  damagedInHandling('Damaged in Handling', 'মুভমেন্টে ক্ষতিগ্রস্ত'),
  dgdaAuditOrder('DGDA Audit Correction', 'ডিজিডিএ অডিট নির্দেশ'),
  otherOperationalError('Other Operational Correction', 'অন্যান্য অপারেশনাল ত্রুটি');

  final String labelEn;
  final String labelBn;

  const MobileCorrectionReason(this.labelEn, this.labelBn);
}

enum MobileCorrectionStatus {
  completed('Compensating Movement Executed', 'কমপেনসেটিং মুভমেন্ট সম্পন্ন'),
  rejected('Correction Rejected', 'সংশোধন বাতিল');

  final String labelEn;
  final String labelBn;

  const MobileCorrectionStatus(this.labelEn, this.labelBn);
}

class MobileMovementCorrection {
  final String correctionId;
  final String tenantId;
  final String branchId;
  final String originalEntryId;
  final String compensatingEntryId;
  final String productId;
  final String batchNumber;
  final MobileCorrectionReason reason;
  final String explanation;
  final int reversedQuantityDelta;
  final double unitCostBdt;
  final double totalCostImpactBdt;
  final MobileCorrectionStatus status;
  final DateTime createdAt;

  MobileMovementCorrection({
    required this.correctionId,
    required this.tenantId,
    required this.branchId,
    required this.originalEntryId,
    required this.compensatingEntryId,
    required this.productId,
    required this.batchNumber,
    required this.reason,
    required this.explanation,
    required this.reversedQuantityDelta,
    required this.unitCostBdt,
    required this.totalCostImpactBdt,
    required this.status,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'correction_id': correctionId,
    'tenant_id': tenantId,
    'branch_id': branchId,
    'original_entry_id': originalEntryId,
    'compensating_entry_id': compensatingEntryId,
    'product_id': productId,
    'batch_number': batchNumber,
    'reason': reason.name,
    'explanation': explanation,
    'reversed_quantity_delta': reversedQuantityDelta,
    'unit_cost_bdt': unitCostBdt,
    'total_cost_impact_bdt': totalCostImpactBdt,
    'status': status.name,
    'created_at': createdAt.toIso8601String(),
  };
}

class MobileStockMovementCorrectionClient {
  final Map<String, MobileMovementCorrection> _correctionCache = {};
  final Set<String> _reversedOriginalEntries = {};

  static const Set<String> _allowedRoles = {
    'PHARMACY_OWNER',
    'BRANCH_MANAGER',
    'SUPERADMIN',
    'STAFF_PHARMACIST',
    'PROCUREMENT_OFFICER',
    'CHIEF_PHARMACIST',
    'AUDITOR',
  };

  void _assertCorrectionRole(String userRole) {
    if (userRole.toUpperCase() == 'CASHIER' || !_allowedRoles.contains(userRole.toUpperCase())) {
      throw StateError('Cashiers are strictly forbidden from performing movement corrections.');
    }
  }

  MobileMovementCorrection executeCorrection({
    required String userRole,
    required String tenantId,
    required String branchId,
    required String originalEntryId,
    required int originalDelta,
    required int currentBatchStock,
    required double unitCostBdt,
    required String productId,
    required String batchNumber,
    required MobileCorrectionReason reason,
    required String explanation,
  }) {
    _assertCorrectionRole(userRole);

    if (explanation.trim().length < 5) {
      throw ArgumentError('A descriptive explanation of at least 5 characters is required.');
    }

    if (_reversedOriginalEntries.contains(originalEntryId)) {
      throw StateError('Original stock movement entry $originalEntryId has already been reversed.');
    }

    final int reversedDelta = -originalDelta;
    final int newBalance = currentBatchStock + reversedDelta;

    if (newBalance < 0) {
      throw StateError('Reversal of $reversedDelta units would cause negative batch stock (current: $currentBatchStock).');
    }

    final double totalCost = double.parse((unitCostBdt * reversedDelta.abs()).toStringAsFixed(2));
    final String correctionId = 'correc-mob-${DateTime.now().millisecondsSinceEpoch}';
    final String compensatingEntryId = 'stkld-rev-mob-${DateTime.now().millisecondsSinceEpoch}';

    final correction = MobileMovementCorrection(
      correctionId: correctionId,
      tenantId: tenantId,
      branchId: branchId,
      originalEntryId: originalEntryId,
      compensatingEntryId: compensatingEntryId,
      productId: productId,
      batchNumber: batchNumber,
      reason: reason,
      explanation: explanation,
      reversedQuantityDelta: reversedDelta,
      unitCostBdt: unitCostBdt,
      totalCostImpactBdt: totalCost,
      status: MobileCorrectionStatus.completed,
      createdAt: DateTime.now(),
    );

    _correctionCache[correctionId] = correction;
    _reversedOriginalEntries.add(originalEntryId);

    return correction;
  }

  MobileMovementCorrection? getCorrection(String correctionId) {
    return _correctionCache[correctionId];
  }

  bool isReversed(String originalEntryId) {
    return _reversedOriginalEntries.contains(originalEntryId);
  }
}
