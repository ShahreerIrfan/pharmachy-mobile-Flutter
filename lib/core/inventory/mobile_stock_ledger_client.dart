import 'dart:convert';

/// mobile_stock_ledger_client.dart
/// Architecture Decision: ADR-0201 (P201).
/// Phase 11: Inventory, Warehouse, Cold Chain & Transfers.
///
/// Mobile owner/manager client for append-only stock movement ledger.
/// Enforces conservation equation: balanceAfter = balanceBefore + quantityDelta.
/// Computes tamper-evident verification hashes.
/// Strictly denies Cashier access (ERR_STAFF_ROLE_DENIED).

enum MobileStockMovementType {
  purchaseReceipt('Purchase Receipt (GRN Inward)', 'ক্রয় রসিদ (ইনওয়ার্ড)'),
  saleDispense('Sale Dispense (Invoice Outward)', 'বিক্রয় বিতরণ (আউটওয়ার্ড)'),
  customerReturn('Customer Sale Return', 'গ্রাহক বিক্রয় ফেরত'),
  purchaseReturn('Supplier Purchase Return', 'সরবরাহকারী ক্রয় ফেরত'),
  transferOut('Branch Transfer Outward', 'শাখা স্থানান্তর বহির্গামী'),
  transferIn('Branch Transfer Inward', 'শাখা স্থানান্তর অন্তর্মুখী'),
  expiryDisposal('Expired Stock Disposal', 'মেয়াদোত্তীর্ণ ওষুধ অপসারণ'),
  stockAdjustmentIn('Inventory Positive Adjustment', 'শারীরিক গণনা বৃদ্ধি সমন্বয়'),
  stockAdjustmentOut('Inventory Negative Adjustment', 'শারীরিক গণনা হ্রাস সমন্বয়'),
  quarantineHold('Quality / DGDA Quarantine Hold', 'কোয়ারেন্টাইন আটক'),
  quarantineRelease('Quality Quarantine Release', 'কোয়ারেন্টাইন মুক্তি');

  final String labelEn;
  final String labelBn;

  const MobileStockMovementType(this.labelEn, this.labelBn);
}

class MobileStockLedgerEntry {
  final String entryId;
  final String tenantId;
  final String branchId;
  final String productId;
  final String productName;
  final String batchNumber;
  final String movementType;
  final int quantityDelta;
  final int balanceBefore;
  final int balanceAfter;
  final double unitCost;
  final double totalCost;
  final double unitPrice;
  final String sourceEntityType;
  final String sourceEntityId;
  final String sourceReference;
  final bool isColdChain;
  final String storageLocation;
  final String notes;
  final String verificationHash;
  final String? postedBy;
  final DateTime postedAt;

  const MobileStockLedgerEntry({
    required this.entryId,
    required this.tenantId,
    required this.branchId,
    required this.productId,
    required this.productName,
    required this.batchNumber,
    required this.movementType,
    required this.quantityDelta,
    required this.balanceBefore,
    required this.balanceAfter,
    required this.unitCost,
    required this.totalCost,
    required this.unitPrice,
    required this.sourceEntityType,
    required this.sourceEntityId,
    required this.sourceReference,
    required this.isColdChain,
    required this.storageLocation,
    required this.notes,
    required this.verificationHash,
    this.postedBy,
    required this.postedAt,
  });

  Map<String, dynamic> toJson() => {
    'entry_id': entryId,
    'tenant_id': tenantId,
    'branch_id': branchId,
    'product_id': productId,
    'product_name': productName,
    'batch_number': batchNumber,
    'movement_type': movementType,
    'quantity_delta': quantityDelta,
    'balance_before': balanceBefore,
    'balance_after': balanceAfter,
    'unit_cost': unitCost,
    'total_cost': totalCost,
    'unit_price': unitPrice,
    'source_entity_type': sourceEntityType,
    'source_entity_id': sourceEntityId,
    'source_reference': sourceReference,
    'is_cold_chain': isColdChain,
    'storage_location': storageLocation,
    'notes': notes,
    'verification_hash': verificationHash,
    'posted_by': postedBy,
    'posted_at': postedAt.toIso8601String(),
  };
}

class MobileStockReconciliationResult {
  final String tenantId;
  final String batchNumber;
  final int? recordedQuantity;
  final int ledgerSum;
  final int discrepancy;
  final bool isBalanced;
  final bool tamperDetected;
  final int totalEntries;

  const MobileStockReconciliationResult({
    required this.tenantId,
    required this.batchNumber,
    this.recordedQuantity,
    required this.ledgerSum,
    required this.discrepancy,
    required this.isBalanced,
    required this.tamperDetected,
    required this.totalEntries,
  });
}

class MobileStockLedgerClient {
  final String tenantId;
  final String branchId;
  final String userRole;
  final String userId;
  final bool isOffline;

  final Map<String, MobileStockLedgerEntry> _ledgerStore = {};
  final Map<String, int> _batchBalanceStore = {};

  MobileStockLedgerClient({
    required this.tenantId,
    required this.branchId,
    required this.userRole,
    required this.userId,
    this.isOffline = false,
  });

  void _assertInventoryRole() {
    final role = userRole.toUpperCase();
    if (role == 'CASHIER') {
      throw StateError('ERR_STAFF_ROLE_DENIED: Cashiers are denied access to the audit stock ledger.');
    }
  }

  static String computeVerificationHash({
    required String entryId,
    required String tenantId,
    required String branchId,
    required String productId,
    required String batchNumber,
    required String movementType,
    required int quantityDelta,
    required int balanceBefore,
    required int balanceAfter,
    required double totalCost,
    required String sourceEntityId,
    required String postedAtIso,
  }) {
    final raw = '$entryId|$tenantId|$branchId|$productId|$batchNumber|$movementType|$quantityDelta|$balanceBefore|$balanceAfter|${totalCost.toStringAsFixed(4)}|$sourceEntityId|$postedAtIso';
    final bytes = utf8.encode(raw);
    int hash = 0xcbf29ce484222325;
    for (var b in bytes) {
      hash ^= b;
      hash = (hash * 0x100000001b3) & 0x7fffffffffffffff;
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }

  void setInitialBatchBalance(String batchNumber, int initialBalance) {
    final key = '$tenantId:$branchId:$batchNumber'.toLowerCase();
    _batchBalanceStore[key] = initialBalance;
  }

  MobileStockLedgerEntry recordMovement({
    required String productId,
    required String productName,
    required String batchNumber,
    required MobileStockMovementType movementType,
    required int quantityDelta,
    required String sourceEntityType,
    required String sourceEntityId,
    required String sourceReference,
    double unitCost = 0.0,
    double unitPrice = 0.0,
    bool isColdChain = false,
    String storageLocation = '',
    String notes = '',
  }) {
    _assertInventoryRole();

    if (quantityDelta == 0) {
      throw ArgumentError('ERR_ZERO_DELTA: Stock movement quantityDelta cannot be zero.');
    }

    final batchKey = '$tenantId:$branchId:$batchNumber'.toLowerCase();
    final currentBalance = _batchBalanceStore[batchKey] ?? 0;
    final newBalance = currentBalance + quantityDelta;

    if (newBalance < 0) {
      throw StateError('ERR_INSUFFICIENT_STOCK: Batch $batchNumber has $currentBalance units, cannot deduct ${quantityDelta.abs()} units.');
    }

    // Invariant check
    if (newBalance != currentBalance + quantityDelta) {
      throw StateError('ERR_CONSERVATION_VIOLATION: balanceAfter must equal balanceBefore + quantityDelta');
    }

    final totalCost = (quantityDelta.abs() * unitCost);
    final now = DateTime.now().toUtc();
    final entryId = 'stkld-${_ledgerStore.length + 1}-${DateTime.now().microsecondsSinceEpoch.toRadixString(16)}';

    final hash = computeVerificationHash(
      entryId: entryId,
      tenantId: tenantId,
      branchId: branchId,
      productId: productId,
      batchNumber: batchNumber,
      movementType: movementType.name,
      quantityDelta: quantityDelta,
      balanceBefore: currentBalance,
      balanceAfter: newBalance,
      totalCost: totalCost,
      sourceEntityId: sourceEntityId,
      postedAtIso: now.toIso8601String(),
    );

    final entry = MobileStockLedgerEntry(
      entryId: entryId,
      tenantId: tenantId,
      branchId: branchId,
      productId: productId,
      productName: productName,
      batchNumber: batchNumber,
      movementType: movementType.name,
      quantityDelta: quantityDelta,
      balanceBefore: currentBalance,
      balanceAfter: newBalance,
      unitCost: unitCost,
      totalCost: totalCost,
      unitPrice: unitPrice,
      sourceEntityType: sourceEntityType,
      sourceEntityId: sourceEntityId,
      sourceReference: sourceReference,
      isColdChain: isColdChain,
      storageLocation: storageLocation,
      notes: notes,
      verificationHash: hash,
      postedBy: userId,
      postedAt: now,
    );

    _ledgerStore[entryId] = entry;
    _batchBalanceStore[batchKey] = newBalance;
    return entry;
  }

  List<MobileStockLedgerEntry> getBatchTrail(String batchNumber) {
    _assertInventoryRole();
    return _ledgerStore.values
        .where((e) => e.tenantId == tenantId && e.batchNumber.toLowerCase() == batchNumber.toLowerCase())
        .toList();
  }

  MobileStockReconciliationResult reconcileBatch(String batchNumber) {
    _assertInventoryRole();
    final trail = getBatchTrail(batchNumber);
    int sumDelta = 0;
    bool tamperDetected = false;

    for (var entry in trail) {
      sumDelta += entry.quantityDelta;
      final expectedHash = computeVerificationHash(
        entryId: entry.entryId,
        tenantId: entry.tenantId,
        branchId: entry.branchId,
        productId: entry.productId,
        batchNumber: entry.batchNumber,
        movementType: entry.movementType,
        quantityDelta: entry.quantityDelta,
        balanceBefore: entry.balanceBefore,
        balanceAfter: entry.balanceAfter,
        totalCost: entry.totalCost,
        sourceEntityId: entry.sourceEntityId,
        postedAtIso: entry.postedAt.toIso8601String(),
      );
      if (expectedHash != entry.verificationHash) {
        tamperDetected = true;
      }
    }

    final batchKey = '$tenantId:$branchId:$batchNumber'.toLowerCase();
    final recordedQty = _batchBalanceStore[batchKey];
    final discrepancy = recordedQty != null ? (recordedQty - sumDelta) : 0;
    final isBalanced = (discrepancy == 0) && !tamperDetected;

    return MobileStockReconciliationResult(
      tenantId: tenantId,
      batchNumber: batchNumber,
      recordedQuantity: recordedQty,
      ledgerSum: sumDelta,
      discrepancy: discrepancy,
      isBalanced: isBalanced,
      tamperDetected: tamperDetected,
      totalEntries: trail.length,
    );
  }
}
