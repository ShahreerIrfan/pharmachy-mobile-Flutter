/// mobile_interbranch_transfer_client.dart
/// Architecture Decision: ADR-0208, ADR-0209, ADR-0210 (P210).
/// Phase 11: Inventory, Warehouse, Cold Chain & Transfers.

import 'dart:convert';

enum MobileTransferStatus {
  requested('Transfer Requested', 'স্থানান্তর অনুরোধকৃত'),
  approved('Transfer Approved', 'স্থানান্তর অনুমোদিত'),
  dispatched('In Transit / Dispatched', 'চালান প্রেরণকৃত'),
  received('Received & Fully Reconciled', 'গৃহীত ও সম্পূর্ণরূপে সমন্বিত'),
  partiallyReceived('Partially Received', 'আংশিক প্রাপ্ত'),
  reconciled('Reconciled with Discrepancy', 'অনৈক্যসহ সমন্বিত'),
  rejected('Transfer Rejected', 'স্থানান্তর প্রত্যাখ্যাত'),
  cancelled('Transfer Cancelled', 'স্থানান্তর বাতিলকৃত');

  final String labelEn;
  final String labelBn;

  const MobileTransferStatus(this.labelEn, this.labelBn);
}

enum MobileTransferPriority {
  standard('Standard', 'সাধারণ'),
  urgent('Urgent', 'জরুরী'),
  emergency('Emergency / Life-Saving', 'জরুরী জীবনরক্ষাকারী');

  final String labelEn;
  final String labelBn;

  const MobileTransferPriority(this.labelEn, this.labelBn);
}

enum MobileTransferCostPolicy {
  atCost('At Original Purchase Lot Cost (Zero Markup)', 'মূল ক্রয়মূল্যে (কোনো অতিরিক্ত চার্জ ছাড়া)'),
  landedMarkup('Percentage Logistics Markup', 'শতাংশ লজিস্টিকস মার্কআপ'),
  fixedFee('Flat Allocated Transfer Fee', 'নির্দিষ্ট হ্যান্ডলিং ফি');

  final String labelEn;
  final String labelBn;

  const MobileTransferCostPolicy(this.labelEn, this.labelBn);
}

class MobileTransferItem {
  final String itemId;
  final String batchId;
  final String medicineId;
  final String medicineName;
  final String batchNumber;
  final String lotReference;
  final String expiryDate;
  final int quantityRequested;
  int quantityDispatched;
  int quantityReceived;
  int quantityReceivedGood;
  int quantityReceivedDamaged;
  int quantityLost;
  double originalCostPerUnit;
  double transferredCostPerUnit;
  String discrepancyReason;
  String damageStorageLocation;
  bool isReconciled;

  MobileTransferItem({
    required this.itemId,
    required this.batchId,
    required this.medicineId,
    required this.medicineName,
    required this.batchNumber,
    this.lotReference = '',
    this.expiryDate = '2027-12-31',
    required this.quantityRequested,
    this.quantityDispatched = 0,
    this.quantityReceived = 0,
    this.quantityReceivedGood = 0,
    this.quantityReceivedDamaged = 0,
    this.quantityLost = 0,
    this.originalCostPerUnit = 0.0,
    this.transferredCostPerUnit = 0.0,
    this.discrepancyReason = '',
    this.damageStorageLocation = '',
    this.isReconciled = false,
  });

  Map<String, dynamic> toJson() => {
    'item_id': itemId,
    'batch_id': batchId,
    'medicine_id': medicineId,
    'medicine_name': medicineName,
    'batch_number': batchNumber,
    'lot_reference': lotReference,
    'expiry_date': expiryDate,
    'quantity_requested': quantityRequested,
    'quantity_dispatched': quantityDispatched,
    'quantity_received': quantityReceived,
    'quantity_received_good': quantityReceivedGood,
    'quantity_received_damaged': quantityReceivedDamaged,
    'quantity_lost': quantityLost,
    'original_cost_per_unit': originalCostPerUnit,
    'transferred_cost_per_unit': transferredCostPerUnit,
    'discrepancy_reason': discrepancyReason,
    'damage_storage_location': damageStorageLocation,
    'is_reconciled': isReconciled,
  };
}

class MobileReconciliationLine {
  final String itemId;
  final int quantityGood;
  final int quantityDamaged;
  final int quantityLost;
  final String discrepancyReason;
  final String damageStorageLocation;

  MobileReconciliationLine({
    required this.itemId,
    required this.quantityGood,
    required this.quantityDamaged,
    required this.quantityLost,
    this.discrepancyReason = '',
    this.damageStorageLocation = 'QUARANTINE-DAMAGED',
  });
}

class MobileTransferRequest {
  final String transferId;
  final String transferNumber;
  final String tenantId;
  final String sourceBranchId;
  final String destinationBranchId;
  MobileTransferStatus status;
  final MobileTransferPriority priority;
  final MobileTransferCostPolicy costPolicy;
  final double markupPercentage;
  final double logisticsFee;
  final String notes;
  final String requestedBy;
  String? approvedBy;
  String? dispatchedBy;
  String? receivedBy;
  String? reconciledBy;
  DateTime? reconciledAt;
  String? reconciliationNotes;
  String? rejectionReason;
  int totalUnitsRequested;
  int totalUnitsDispatched;
  int totalUnitsReceived;
  int totalUnitsReceivedGood;
  int totalUnitsReceivedDamaged;
  int totalUnitsLost;
  final List<MobileTransferItem> items;
  final DateTime createdAt;
  DateTime updatedAt;

  MobileTransferRequest({
    required this.transferId,
    required this.transferNumber,
    required this.tenantId,
    required this.sourceBranchId,
    required this.destinationBranchId,
    this.status = MobileTransferStatus.requested,
    this.priority = MobileTransferPriority.standard,
    this.costPolicy = MobileTransferCostPolicy.atCost,
    this.markupPercentage = 0.0,
    this.logisticsFee = 0.0,
    required this.notes,
    required this.requestedBy,
    this.approvedBy,
    this.dispatchedBy,
    this.receivedBy,
    this.reconciledBy,
    this.reconciledAt,
    this.reconciliationNotes,
    this.rejectionReason,
    this.totalUnitsRequested = 0,
    this.totalUnitsDispatched = 0,
    this.totalUnitsReceived = 0,
    this.totalUnitsReceivedGood = 0,
    this.totalUnitsReceivedDamaged = 0,
    this.totalUnitsLost = 0,
    required this.items,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'transfer_id': transferId,
    'transfer_number': transferNumber,
    'tenant_id': tenantId,
    'source_branch_id': sourceBranchId,
    'destination_branch_id': destinationBranchId,
    'status': status.name,
    'priority': priority.name,
    'cost_policy': costPolicy.name,
    'markup_percentage': markupPercentage,
    'logistics_fee': logisticsFee,
    'notes': notes,
    'requested_by': requestedBy,
    'approved_by': approvedBy,
    'dispatched_by': dispatchedBy,
    'received_by': receivedBy,
    'reconciled_by': reconciledBy,
    'reconciled_at': reconciledAt?.toIso8601String(),
    'reconciliation_notes': reconciliationNotes,
    'total_units_requested': totalUnitsRequested,
    'total_units_dispatched': totalUnitsDispatched,
    'total_units_received': totalUnitsReceived,
    'total_units_received_good': totalUnitsReceivedGood,
    'total_units_received_damaged': totalUnitsReceivedDamaged,
    'total_units_lost': totalUnitsLost,
    'items': items.map((i) => i.toJson()).toList(),
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };
}

class MobileBatchStock {
  final String batchId;
  final String branchId;
  final String medicineId;
  final String batchNumber;
  final String lotReference;
  final String expiryDate;
  int quantityBaseUnits;
  int reservedQuantityBaseUnits;
  double costPerUnit;
  double originalCostPerUnit;
  double transferMarkupBdt;
  String? originBatchId;
  String? originBranchId;
  bool isQuarantined;

  MobileBatchStock({
    required this.batchId,
    required this.branchId,
    required this.medicineId,
    required this.batchNumber,
    this.lotReference = '',
    this.expiryDate = '2027-12-31',
    required this.quantityBaseUnits,
    this.reservedQuantityBaseUnits = 0,
    this.costPerUnit = 0.0,
    this.originalCostPerUnit = 0.0,
    this.transferMarkupBdt = 0.0,
    this.originBatchId,
    this.originBranchId,
    this.isQuarantined = false,
  });

  int get availableQuantity {
    if (isQuarantined) return 0;
    return (quantityBaseUnits - reservedQuantityBaseUnits) > 0
        ? (quantityBaseUnits - reservedQuantityBaseUnits)
        : 0;
  }
}

class MobileInterBranchTransferClient {
  final Map<String, MobileTransferRequest> _transfers = {};
  final Map<String, MobileBatchStock> _batches = {};

  void registerBatch(MobileBatchStock batch) {
    _batches[batch.batchId] = batch;
  }

  MobileBatchStock? getBatch(String batchId) => _batches[batchId];
  MobileTransferRequest? getTransfer(String transferId) => _transfers[transferId];

  void _checkStaffRole(String role) {
    final allowed = ['PHARMACIST', 'BRANCH_MANAGER', 'OWNER', 'ADMIN'];
    if (!allowed.contains(role.toUpperCase())) {
      throw StateError('ERR_STAFF_ROLE_DENIED: Role $role is not authorized for transfers.');
    }
  }

  MobileTransferRequest requestTransfer({
    required String tenantId,
    required String sourceBranchId,
    required String destinationBranchId,
    required String requestedBy,
    required String staffRole,
    MobileTransferPriority priority = MobileTransferPriority.standard,
    MobileTransferCostPolicy costPolicy = MobileTransferCostPolicy.atCost,
    double markupPercentage = 0.0,
    double logisticsFee = 0.0,
    required List<MobileTransferItem> items,
    required String notes,
  }) {
    _checkStaffRole(staffRole);

    if (sourceBranchId == destinationBranchId) {
      throw ArgumentError('ERR_SAME_BRANCH_TRANSFER: Source and destination branches must differ.');
    }
    if (items.isEmpty) {
      throw ArgumentError('ERR_EMPTY_TRANSFER: Items list cannot be empty.');
    }

    int totalReq = 0;
    for (final item in items) {
      if (item.quantityRequested <= 0) {
        throw ArgumentError('ERR_INVALID_QUANTITY: Requested quantity must be positive.');
      }
      final batch = _batches[item.batchId];
      if (batch == null) {
        throw ArgumentError('ERR_BATCH_NOT_FOUND: Batch ${item.batchId} not found.');
      }
      if (batch.branchId != sourceBranchId) {
        throw StateError('ERR_BRANCH_MISMATCH: Batch does not belong to source branch.');
      }
      if (batch.availableQuantity < item.quantityRequested) {
        throw StateError('ERR_INSUFFICIENT_STOCK: Available ${batch.availableQuantity} < Requested ${item.quantityRequested}');
      }
      totalReq += item.quantityRequested;

      // Calculate cost policy
      item.originalCostPerUnit = batch.costPerUnit;
      if (costPolicy == MobileTransferCostPolicy.landedMarkup && markupPercentage > 0) {
        item.transferredCostPerUnit = batch.costPerUnit * (1.0 + markupPercentage / 100.0);
      } else if (costPolicy == MobileTransferCostPolicy.fixedFee && logisticsFee > 0) {
        item.transferredCostPerUnit = batch.costPerUnit + (logisticsFee / item.quantityRequested);
      } else {
        item.transferredCostPerUnit = batch.costPerUnit;
      }
    }

    // Apply reservations
    for (final item in items) {
      _batches[item.batchId]!.reservedQuantityBaseUnits += item.quantityRequested;
    }

    final id = 'TRF-${DateTime.now().millisecondsSinceEpoch}';
    final transfer = MobileTransferRequest(
      transferId: id,
      transferNumber: 'TRF-NUM-${_transfers.length + 1}',
      tenantId: tenantId,
      sourceBranchId: sourceBranchId,
      destinationBranchId: destinationBranchId,
      priority: priority,
      costPolicy: costPolicy,
      markupPercentage: markupPercentage,
      logisticsFee: logisticsFee,
      notes: notes,
      requestedBy: requestedBy,
      items: items,
      totalUnitsRequested: totalReq,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _transfers[id] = transfer;
    return transfer;
  }

  MobileTransferRequest approveTransfer({
    required String transferId,
    required String approvedBy,
    required String staffRole,
  }) {
    _checkStaffRole(staffRole);
    final transfer = _transfers[transferId];
    if (transfer == null) throw ArgumentError('ERR_TRANSFER_NOT_FOUND');
    if (transfer.status != MobileTransferStatus.requested) {
      throw StateError('ERR_INVALID_TRANSITION: Transfer must be requested.');
    }
    transfer.status = MobileTransferStatus.approved;
    transfer.approvedBy = approvedBy;
    transfer.updatedAt = DateTime.now();
    return transfer;
  }

  MobileTransferRequest dispatchTransfer({
    required String transferId,
    required String dispatchedBy,
    required String staffRole,
  }) {
    _checkStaffRole(staffRole);
    final transfer = _transfers[transferId];
    if (transfer == null) throw ArgumentError('ERR_TRANSFER_NOT_FOUND');
    if (transfer.status != MobileTransferStatus.approved) {
      throw StateError('ERR_INVALID_TRANSITION: Transfer must be approved.');
    }

    int totalDisp = 0;
    for (final item in transfer.items) {
      final batch = _batches[item.batchId];
      if (batch != null) {
        batch.reservedQuantityBaseUnits -= item.quantityRequested;
        batch.quantityBaseUnits -= item.quantityRequested;
      }
      item.quantityDispatched = item.quantityRequested;
      totalDisp += item.quantityDispatched;
    }

    transfer.status = MobileTransferStatus.dispatched;
    transfer.dispatchedBy = dispatchedBy;
    transfer.totalUnitsDispatched = totalDisp;
    transfer.updatedAt = DateTime.now();
    return transfer;
  }

  MobileTransferRequest reconcileTransfer({
    required String transferId,
    required String actorUser,
    required String staffRole,
    required List<MobileReconciliationLine> lines,
    required String notes,
    Map<String, MobileBatchStock>? destinationGoodBatches,
    Map<String, MobileBatchStock>? destinationDamageBatches,
  }) {
    _checkStaffRole(staffRole);
    final transfer = _transfers[transferId];
    if (transfer == null) throw ArgumentError('ERR_TRANSFER_NOT_FOUND');
    if (transfer.status == MobileTransferStatus.received || transfer.status == MobileTransferStatus.reconciled) {
      throw StateError('ERR_TRANSFER_ALREADY_RECEIVED: Transfer already received.');
    }
    if (transfer.status != MobileTransferStatus.dispatched) {
      throw StateError('ERR_INVALID_TRANSITION: Transfer must be dispatched before receiving.');
    }

    final lineMap = {for (var l in lines) l.itemId: l};

    bool hasDiscrepancy = false;
    int totalGood = 0;
    int totalDamaged = 0;
    int totalLost = 0;

    for (final item in transfer.items) {
      final line = lineMap[item.itemId];
      final good = line?.quantityGood ?? item.quantityDispatched;
      final damaged = line?.quantityDamaged ?? 0;
      final lost = line?.quantityLost ?? 0;

      if (good < 0 || damaged < 0 || lost < 0) {
        throw ArgumentError('ERR_INVALID_QUANTITY: Quantities must be non-negative.');
      }

      final sum = good + damaged + lost;
      if (sum != item.quantityDispatched) {
        throw StateError('ERR_DISCREPANCY_CONSERVATION: Good ($good) + Damaged ($damaged) + Lost ($lost) != Dispatched (${item.quantityDispatched})');
      }

      if (damaged > 0 || lost > 0) {
        hasDiscrepancy = true;
      }

      // 1. Credit Good Stock with Lot Cost Continuity
      if (good > 0 && destinationGoodBatches != null && destinationGoodBatches.containsKey(item.medicineId)) {
        final destBatch = destinationGoodBatches[item.medicineId]!;

        // Prohibit modifying manufacturer expiry date
        if (destBatch.expiryDate != item.expiryDate) {
          throw StateError('ERR_EXPIRY_DATE_ALTERATION_PROHIBITED: Transferred batch expiry (${item.expiryDate}) conflicts with existing (${destBatch.expiryDate}).');
        }

        // Weighted Average Cost calculation
        if (destBatch.quantityBaseUnits > 0) {
          final existVal = destBatch.costPerUnit * destBatch.quantityBaseUnits;
          final inVal = item.transferredCostPerUnit * good;
          final totalQty = destBatch.quantityBaseUnits + good;
          destBatch.costPerUnit = double.parse(((existVal + inVal) / totalQty).toStringAsFixed(4));
        } else {
          destBatch.costPerUnit = item.transferredCostPerUnit;
        }

        destBatch.quantityBaseUnits += good;
        destBatch.originBatchId = item.batchId;
        destBatch.originBranchId = transfer.sourceBranchId;
        destBatch.originalCostPerUnit = item.originalCostPerUnit;
        destBatch.transferMarkupBdt = item.transferredCostPerUnit - item.originalCostPerUnit;
      }

      // 2. Credit Damaged Stock to Quarantined batch (zero sellable availability)
      if (damaged > 0 && destinationDamageBatches != null && destinationDamageBatches.containsKey(item.medicineId)) {
        final dmgBatch = destinationDamageBatches[item.medicineId]!;
        dmgBatch.isQuarantined = true;
        dmgBatch.quantityBaseUnits += damaged;
        dmgBatch.originBatchId = item.batchId;
        dmgBatch.originBranchId = transfer.sourceBranchId;
        dmgBatch.costPerUnit = item.transferredCostPerUnit;
      }

      item.quantityReceivedGood = good;
      item.quantityReceivedDamaged = damaged;
      item.quantityLost = lost;
      item.quantityReceived = good + damaged;
      item.discrepancyReason = line?.discrepancyReason ?? '';
      item.damageStorageLocation = line?.damageStorageLocation ?? '';
      item.isReconciled = true;

      totalGood += good;
      totalDamaged += damaged;
      totalLost += lost;
    }

    transfer.status = hasDiscrepancy ? MobileTransferStatus.reconciled : MobileTransferStatus.received;
    transfer.receivedBy = actorUser;
    transfer.reconciledBy = actorUser;
    transfer.reconciledAt = DateTime.now();
    transfer.reconciliationNotes = notes;
    transfer.totalUnitsReceived = totalGood + totalDamaged;
    transfer.totalUnitsReceivedGood = totalGood;
    transfer.totalUnitsReceivedDamaged = totalDamaged;
    transfer.totalUnitsLost = totalLost;
    transfer.updatedAt = DateTime.now();

    return transfer;
  }
}
