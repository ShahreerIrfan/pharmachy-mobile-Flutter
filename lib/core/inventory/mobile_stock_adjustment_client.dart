/// mobile_stock_adjustment_client.dart
/// Architecture Decision: ADR-0205 (P205).
/// Phase 11: Inventory, Warehouse, Cold Chain & Transfers.
///
/// Mobile owner/manager client for Nontrivial Inventory Adjustments,
/// Maker-Checker separation of duties, mandatory DGDA reason codes,
/// and SHA-256 tamper-evident difference events.

import 'dart:convert';
import 'package:crypto/crypto.dart';

enum MobileStockAdjustmentReasonCode {
  breakageSpillage('Breakage or Spillage', 'ভাঙন বা তরল অপচয়'),
  expirySpoilage('Expired / Deteriorated Medicine', 'মেয়াদোত্তীর্ণ বা নষ্ট ওষুধ'),
  theftPilferage('Theft or Unaccounted Pilferage', 'চুরি বা হিসাববিহীন অপচয়'),
  coldChainExcursion('Cold-Chain Temperature Excursion', 'কোল্ড-চেইন তাপমাত্রা বিচ্যুতি'),
  dispensingErrorReversal('Dispensing / Billing Error Reversal', 'বিতরণ বা বিলিং ত্রুটি সংশোধন'),
  supplierShortShipment('Supplier Short Shipment Variance', 'সরবরাহকারীর ঘাটতি চালান'),
  regulatorySeizureDgda('DGDA Regulatory Seizure / Quarantine', 'ডিজিডিএ নিয়ন্ত্রক বাজেয়াপ্ত বা কোয়ারেন্টাইন'),
  auditCountVariance('Physical Audit Variance Correction', 'শারীরিক অডিট গণনা পার্থক্য'),
  other('Other Documented Adjustment', 'অন্যান্য নথিভুক্ত সমন্বয়');

  final String labelEn;
  final String labelBn;

  const MobileStockAdjustmentReasonCode(this.labelEn, this.labelBn);
}

enum MobileStockAdjustmentStatus {
  pending('Pending Review', 'অনুমোদনের অপেক্ষায়'),
  approved('Approved & Posted', 'অনুমোদিত ও পোস্টকৃত'),
  rejected('Rejected', 'প্রত্যাখ্যাত'),
  reversed('Reversed / Offset', 'বাতিল / বিপরীত সমন্বয়');

  final String labelEn;
  final String labelBn;

  const MobileStockAdjustmentStatus(this.labelEn, this.labelBn);
}

class MobileStockAdjustmentRecord {
  final String adjustmentId;
  final String tenantId;
  final String branchId;
  final String productId;
  final String productName;
  final String batchNumber;
  final int quantityDelta;
  final double unitCostBdt;
  final double totalCostImpactBdt;
  final MobileStockAdjustmentReasonCode reasonCode;
  final String reasonNotes;
  final bool isNontrivial;
  MobileStockAdjustmentStatus status;
  final String proposedByUserId;
  String? approvedByUserId;
  DateTime? approvedAt;
  String? ledgerEntryId;
  bool isReversed;
  String? reversalReason;
  String? reversalOfId;
  final String supportingDocumentRef;
  final DateTime createdAt;

  MobileStockAdjustmentRecord({
    required this.adjustmentId,
    required this.tenantId,
    required this.branchId,
    required this.productId,
    required this.productName,
    required this.batchNumber,
    required this.quantityDelta,
    required this.unitCostBdt,
    required this.totalCostImpactBdt,
    required this.reasonCode,
    required this.reasonNotes,
    required this.isNontrivial,
    required this.status,
    required this.proposedByUserId,
    this.approvedByUserId,
    this.approvedAt,
    this.ledgerEntryId,
    this.isReversed = false,
    this.reversalReason,
    this.reversalOfId,
    required this.supportingDocumentRef,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'adjustment_id': adjustmentId,
        'tenant_id': tenantId,
        'branch_id': branchId,
        'product_id': productId,
        'product_name': productName,
        'batch_number': batchNumber,
        'quantity_delta': quantityDelta,
        'unit_cost_bdt': unitCostBdt,
        'total_cost_impact_bdt': totalCostImpactBdt,
        'reason_code': reasonCode.name,
        'reason_notes': reasonNotes,
        'is_nontrivial': isNontrivial,
        'status': status.name,
        'proposed_by_user_id': proposedByUserId,
        'approved_by_user_id': approvedByUserId,
        'approved_at': approvedAt?.toIso8601String(),
        'ledger_entry_id': ledgerEntryId,
        'is_reversed': isReversed,
        'reversal_reason': reversalReason,
        'reversal_of_id': reversalOfId,
        'supporting_document_ref': supportingDocumentRef,
        'created_at': createdAt.toIso8601String(),
      };
}

class MobileStockAdjustmentDifferenceEvent {
  final String eventId;
  final String adjustmentId;
  final String productName;
  final String batchNumber;
  final int preAdjustmentQuantity;
  final int postAdjustmentQuantity;
  final int quantityDelta;
  final double unitCostBdt;
  final double totalCostImpactBdt;
  final bool isNontrivial;
  final MobileStockAdjustmentReasonCode reasonCode;
  final String ledgerEntryId;
  final String immutableEventHash;
  final DateTime createdAt;

  MobileStockAdjustmentDifferenceEvent({
    required this.eventId,
    required this.adjustmentId,
    required this.productName,
    required this.batchNumber,
    required this.preAdjustmentQuantity,
    required this.postAdjustmentQuantity,
    required this.quantityDelta,
    required this.unitCostBdt,
    required this.totalCostImpactBdt,
    required this.isNontrivial,
    required this.reasonCode,
    required this.ledgerEntryId,
    required this.immutableEventHash,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'event_id': eventId,
        'adjustment_id': adjustmentId,
        'product_name': productName,
        'batch_number': batchNumber,
        'pre_adjustment_quantity': preAdjustmentQuantity,
        'post_adjustment_quantity': postAdjustmentQuantity,
        'quantity_delta': quantityDelta,
        'unit_cost_bdt': unitCostBdt,
        'total_cost_impact_bdt': totalCostImpactBdt,
        'is_nontrivial': isNontrivial,
        'reason_code': reasonCode.name,
        'ledger_entry_id': ledgerEntryId,
        'immutable_event_hash': immutableEventHash,
        'created_at': createdAt.toIso8601String(),
      };
}

class MobileStockAdjustmentClient {
  static const int nontrivialQtyThreshold = 10;
  static const double nontrivialCostThreshold = 500.0;

  static const Set<String> _allowedProposerRoles = {
    'PHARMACY_OWNER',
    'BRANCH_MANAGER',
    'PLATFORM_SUPER_ADMIN',
    'STAFF_PHARMACIST',
    'PHARMACIST',
    'INVENTORY_CLERK',
    'TENANT_OWNER',
  };

  static const Set<String> _allowedApproverRoles = {
    'PHARMACY_OWNER',
    'BRANCH_MANAGER',
    'PLATFORM_SUPER_ADMIN',
    'TENANT_OWNER',
  };

  static int _counter = 0;
  static String _nextId(String prefix) =>
      '$prefix-${DateTime.now().millisecondsSinceEpoch}-${++_counter}';

  final Map<String, MobileStockAdjustmentRecord> adjustments = {};
  final Map<String, List<MobileStockAdjustmentDifferenceEvent>> differenceEvents = {};
  final Map<String, int> batchStockQuantities = {};

  void setBatchStock(String batchNumber, int quantity) {
    batchStockQuantities[batchNumber] = quantity;
  }

  int getBatchStock(String batchNumber) => batchStockQuantities[batchNumber] ?? 0;

  static bool isNontrivialAdjustment({
    required int quantityDelta,
    required double totalCost,
    bool isNarcotic = false,
    bool requiresColdChain = false,
    bool isQuarantined = false,
  }) {
    if (quantityDelta.abs() >= nontrivialQtyThreshold) return true;
    if (totalCost.abs() >= nontrivialCostThreshold) return true;
    if (isNarcotic || requiresColdChain || isQuarantined) return true;
    return false;
  }

  MobileStockAdjustmentRecord proposeAdjustment({
    required String tenantId,
    required String branchId,
    required String productId,
    required String productName,
    required String batchNumber,
    required int quantityDelta,
    required double unitCost,
    required MobileStockAdjustmentReasonCode reasonCode,
    required String reasonNotes,
    String supportingDocumentRef = '',
    required String actorUserId,
    required String actorRole,
    bool isNarcotic = false,
    bool requiresColdChain = false,
    bool isQuarantined = false,
  }) {
    final roleUpper = actorRole.toUpperCase();
    if (roleUpper == 'CASHIER') {
      throw StateError('ERR_STAFF_ROLE_DENIED: Cashiers cannot propose stock adjustments.');
    }
    if (!_allowedProposerRoles.contains(roleUpper)) {
      throw StateError('ERR_STAFF_ROLE_DENIED: Role not authorized to propose adjustments.');
    }

    if (quantityDelta == 0) {
      throw ArgumentError('ERR_ZERO_DELTA: Stock adjustment quantity delta cannot be zero.');
    }

    final trimmedNotes = reasonNotes.trim();
    if (trimmedNotes.length < 10) {
      throw ArgumentError('ERR_MANDATORY_REASON_REQUIRED: Reason must be at least 10 characters.');
    }

    final currentStock = getBatchStock(batchNumber);
    if (quantityDelta < 0 && (currentStock + quantityDelta) < 0) {
      throw ArgumentError('ERR_INSUFFICIENT_STOCK: Cannot reduce more than available batch stock.');
    }

    final totalCost = unitCost * quantityDelta.abs();
    final nontrivial = isNontrivialAdjustment(
      quantityDelta: quantityDelta,
      totalCost: totalCost,
      isNarcotic: isNarcotic,
      requiresColdChain: requiresColdChain,
      isQuarantined: isQuarantined,
    );

    final adjId = _nextId('adj');
    final record = MobileStockAdjustmentRecord(
      adjustmentId: adjId,
      tenantId: tenantId,
      branchId: branchId,
      productId: productId,
      productName: productName,
      batchNumber: batchNumber,
      quantityDelta: quantityDelta,
      unitCostBdt: unitCost,
      totalCostImpactBdt: totalCost,
      reasonCode: reasonCode,
      reasonNotes: trimmedNotes,
      isNontrivial: nontrivial,
      status: MobileStockAdjustmentStatus.pending,
      proposedByUserId: actorUserId,
      supportingDocumentRef: supportingDocumentRef.trim(),
      createdAt: DateTime.now(),
    );

    adjustments[adjId] = record;
    return record;
  }

  MobileStockAdjustmentRecord approveAdjustment({
    required String adjustmentId,
    required String checkerUserId,
    required String checkerRole,
    String checkerNotes = '',
  }) {
    final adj = adjustments[adjustmentId];
    if (adj == null) {
      throw StateError('Adjustment not found: $adjustmentId');
    }

    final roleUpper = checkerRole.toUpperCase();
    if (!_allowedApproverRoles.contains(roleUpper)) {
      throw StateError('ERR_APPROVER_ROLE_DENIED: Role not authorized to approve adjustments.');
    }

    if (adj.status == MobileStockAdjustmentStatus.approved) {
      throw StateError('ERR_ALREADY_APPROVED: Adjustment has already been approved.');
    }

    if (adj.status != MobileStockAdjustmentStatus.pending) {
      throw StateError('Adjustment cannot be approved from status: ${adj.status.name}');
    }

    // Maker-Checker anti-self-approval rule
    if (adj.isNontrivial && checkerUserId == adj.proposedByUserId) {
      throw StateError(
          'ERR_MAKER_CHECKER_SELF_APPROVAL: Proposer cannot approve their own nontrivial adjustment.');
    }

    final preQty = getBatchStock(adj.batchNumber);
    final postQty = preQty + adj.quantityDelta;
    batchStockQuantities[adj.batchNumber] = postQty;

    final ledgerId = _nextId('stkled');
    adj.status = MobileStockAdjustmentStatus.approved;
    adj.approvedByUserId = checkerUserId;
    adj.approvedAt = DateTime.now();
    adj.ledgerEntryId = ledgerId;

    final eventId = _nextId('adjevt');
    final payloadToHash =
        '$eventId|${adj.adjustmentId}|${adj.batchNumber}|$preQty|$postQty|${adj.quantityDelta}|$ledgerId';
    final hash = sha256.convert(utf8.encode(payloadToHash)).toString();

    final diffEvent = MobileStockAdjustmentDifferenceEvent(
      eventId: eventId,
      adjustmentId: adj.adjustmentId,
      productName: adj.productName,
      batchNumber: adj.batchNumber,
      preAdjustmentQuantity: preQty,
      postAdjustmentQuantity: postQty,
      quantityDelta: adj.quantityDelta,
      unitCostBdt: adj.unitCostBdt,
      totalCostImpactBdt: adj.totalCostImpactBdt,
      isNontrivial: adj.isNontrivial,
      reasonCode: adj.reasonCode,
      ledgerEntryId: ledgerId,
      immutableEventHash: hash,
      createdAt: DateTime.now(),
    );

    differenceEvents.putIfAbsent(adj.adjustmentId, () => []).add(diffEvent);
    return adj;
  }

  MobileStockAdjustmentRecord rejectAdjustment({
    required String adjustmentId,
    required String checkerUserId,
    required String checkerRole,
    required String rejectionReason,
  }) {
    final adj = adjustments[adjustmentId];
    if (adj == null) {
      throw StateError('Adjustment not found: $adjustmentId');
    }

    final roleUpper = checkerRole.toUpperCase();
    if (!_allowedApproverRoles.contains(roleUpper)) {
      throw StateError('ERR_APPROVER_ROLE_DENIED: Role not authorized to reject adjustments.');
    }

    if (adj.status != MobileStockAdjustmentStatus.pending) {
      throw StateError('Cannot reject adjustment from status: ${adj.status.name}');
    }

    final trimmed = rejectionReason.trim();
    if (trimmed.length < 5) {
      throw ArgumentError('ERR_REJECTION_REASON_REQUIRED: Specific rejection explanation required.');
    }

    adj.status = MobileStockAdjustmentStatus.rejected;
    adj.approvedByUserId = checkerUserId;
    adj.approvedAt = DateTime.now();
    adj.reversalReason = trimmed;
    return adj;
  }

  MobileStockAdjustmentRecord reverseAdjustment({
    required String adjustmentId,
    required String actorUserId,
    required String actorRole,
    required String reversalReason,
  }) {
    final orig = adjustments[adjustmentId];
    if (orig == null) {
      throw StateError('Adjustment not found: $adjustmentId');
    }

    final roleUpper = actorRole.toUpperCase();
    if (!_allowedApproverRoles.contains(roleUpper)) {
      throw StateError('ERR_APPROVER_ROLE_DENIED: Role not authorized to reverse adjustments.');
    }

    if (orig.status != MobileStockAdjustmentStatus.approved) {
      throw StateError('Only APPROVED adjustments can be reversed.');
    }

    if (orig.isReversed) {
      throw StateError('ERR_ALREADY_REVERSED: Adjustment has already been reversed.');
    }

    final trimmed = reversalReason.trim();
    if (trimmed.length < 10) {
      throw ArgumentError(
          'ERR_REVERSAL_REASON_REQUIRED: Reversal reason must be at least 10 characters.');
    }

    final preQty = getBatchStock(orig.batchNumber);
    final revDelta = -orig.quantityDelta;
    final postQty = preQty + revDelta;
    batchStockQuantities[orig.batchNumber] = postQty;

    orig.isReversed = true;
    orig.reversalReason = trimmed;

    final revId = _nextId('adj-rev');
    final revLedgerId = _nextId('stkled');

    final revRecord = MobileStockAdjustmentRecord(
      adjustmentId: revId,
      tenantId: orig.tenantId,
      branchId: orig.branchId,
      productId: orig.productId,
      productName: orig.productName,
      batchNumber: orig.batchNumber,
      quantityDelta: revDelta,
      unitCostBdt: orig.unitCostBdt,
      totalCostImpactBdt: orig.totalCostImpactBdt,
      reasonCode: orig.reasonCode,
      reasonNotes: 'Offset reversal: $trimmed',
      isNontrivial: orig.isNontrivial,
      status: MobileStockAdjustmentStatus.approved,
      proposedByUserId: actorUserId,
      approvedByUserId: actorUserId,
      approvedAt: DateTime.now(),
      ledgerEntryId: revLedgerId,
      reversalOfId: orig.adjustmentId,
      supportingDocumentRef: 'REV-${orig.adjustmentId}',
      createdAt: DateTime.now(),
    );

    adjustments[revId] = revRecord;

    final revEventId = _nextId('adjevt');
    final payloadToHash =
        '$revEventId|$revId|${orig.batchNumber}|$preQty|$postQty|$revDelta|$revLedgerId';
    final hash = sha256.convert(utf8.encode(payloadToHash)).toString();

    final diffEvent = MobileStockAdjustmentDifferenceEvent(
      eventId: revEventId,
      adjustmentId: revId,
      productName: orig.productName,
      batchNumber: orig.batchNumber,
      preAdjustmentQuantity: preQty,
      postAdjustmentQuantity: postQty,
      quantityDelta: revDelta,
      unitCostBdt: orig.unitCostBdt,
      totalCostImpactBdt: orig.totalCostImpactBdt,
      isNontrivial: orig.isNontrivial,
      reasonCode: orig.reasonCode,
      ledgerEntryId: revLedgerId,
      immutableEventHash: hash,
      createdAt: DateTime.now(),
    );

    differenceEvents.putIfAbsent(revId, () => []).add(diffEvent);
    return revRecord;
  }

  List<MobileStockAdjustmentDifferenceEvent> getDifferenceEvents(String adjustmentId) {
    return differenceEvents[adjustmentId] ?? [];
  }
}

