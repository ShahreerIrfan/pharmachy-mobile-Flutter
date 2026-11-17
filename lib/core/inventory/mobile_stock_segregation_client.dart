/// mobile_stock_segregation_client.dart
/// Architecture Decision: ADR-0207 (P207).
/// Phase 11: Inventory, Warehouse, Cold Chain & Transfers.

import 'dart:convert';
import 'package:crypto/crypto.dart';

enum MobileSegregationCategory {
  damaged('Damaged / Broken Packaging', 'ভাঙন বা ক্ষতিগ্রস্ত প্যাকেজিং'),
  suspiciousCounterfeit('Suspicious / Suspected Counterfeit', 'সন্দেহভাজন নকল ওষুধ'),
  recalled('Manufacturer / DGDA Recalled Lot', 'উত্পাদক বা ডিজিডিএ প্রত্যাহারকৃত লট'),
  returnedCustomer('Customer Returned', 'গ্রাহক ফেরত'),
  coldChainBreach('Suspected Cold Chain Breach', 'কোল্ড চেইন বিঘ্নিত');

  final String labelEn;
  final String labelBn;

  const MobileSegregationCategory(this.labelEn, this.labelBn);
}

enum MobileSegregationStatus {
  segregated('Held in Segregation', 'পৃথকীকরণে সংরক্ষিত'),
  releasedToSellable('Released to Sellable', 'বিক্রয়যোগ্য স্টকে অবমুক্ত'),
  movedToQuarantine('Escalated to Quarantine', 'কোয়ারেন্টাইনে স্থানান্তরিত'),
  returnedToSupplier('Returned to Supplier', 'সরবরাহকারীকে ফেরত'),
  disposedWrittenOff('Disposed & Written Off', 'অপসারিত ও অবলোপনকৃত');

  final String labelEn;
  final String labelBn;

  const MobileSegregationStatus(this.labelEn, this.labelBn);
}

class MobileBatchStockItem {
  final String batchId;
  final String batchNumber;
  int quantityBaseUnits;
  int reservedQuantityBaseUnits;
  final double unitCost;
  String storageLocation;
  final bool isExpired;

  MobileBatchStockItem({
    required this.batchId,
    required this.batchNumber,
    required this.quantityBaseUnits,
    this.reservedQuantityBaseUnits = 0,
    required this.unitCost,
    required this.storageLocation,
    this.isExpired = false,
  });

  int get availableQuantity => (quantityBaseUnits - reservedQuantityBaseUnits).clamp(0, quantityBaseUnits);
}

class MobileSegregationRecord {
  final String segregationId;
  final String tenantId;
  final String branchId;
  final String batchId;
  final String batchNumber;
  final int segregatedQuantity;
  final double unitCostBdt;
  final double totalCostImpactBdt;
  final MobileSegregationCategory category;
  MobileSegregationStatus status;
  String segregationLocation;
  final String reasonNotes;
  final String segregatedByUserId;
  final DateTime segregatedAt;
  String? inspectedByUserId;
  DateTime? inspectedAt;
  String? releaseJustification;
  String? actionedByUserId;
  DateTime? actionedAt;
  String? dispositionReference;
  String? ledgerEntryId;
  final String immutableHash;

  MobileSegregationRecord({
    required this.segregationId,
    required this.tenantId,
    required this.branchId,
    required this.batchId,
    required this.batchNumber,
    required this.segregatedQuantity,
    required this.unitCostBdt,
    required this.totalCostImpactBdt,
    required this.category,
    required this.status,
    required this.segregationLocation,
    required this.reasonNotes,
    required this.segregatedByUserId,
    required this.segregatedAt,
    this.inspectedByUserId,
    this.inspectedAt,
    this.releaseJustification,
    this.actionedByUserId,
    this.actionedAt,
    this.dispositionReference,
    this.ledgerEntryId,
    required this.immutableHash,
  });
}

class MobileStockSegregationClient {
  static const Set<String> _staffRoles = {
    'PHARMACY_OWNER', 'BRANCH_MANAGER', 'PLATFORM_SUPER_ADMIN',
    'STAFF_PHARMACIST', 'PHARMACIST', 'INVENTORY_CLERK', 'TENANT_OWNER'
  };

  static const Set<String> _qaRoles = {
    'PHARMACY_OWNER', 'BRANCH_MANAGER', 'PLATFORM_SUPER_ADMIN',
    'STAFF_PHARMACIST', 'PHARMACIST', 'TENANT_OWNER'
  };

  static int _counter = 0;
  static String _nextId(String prefix) =>
      '$prefix-${DateTime.now().millisecondsSinceEpoch}-${++_counter}';

  final Map<String, MobileBatchStockItem> batches = {};
  final Map<String, MobileSegregationRecord> records = {};

  void registerBatch(MobileBatchStockItem batch) {
    batches[batch.batchId] = batch;
  }

  MobileBatchStockItem? getBatch(String batchId) => batches[batchId];

  MobileSegregationRecord segregateStock({
    required String tenantId,
    required String branchId,
    required String batchId,
    required int quantity,
    required MobileSegregationCategory category,
    required String reasonNotes,
    String segregationLocation = 'SEGREGATION-HOLD',
    required String actorUserId,
    required String actorRole,
  }) {
    final roleUpper = actorRole.toUpperCase();
    if (roleUpper == 'CASHIER') {
      throw StateError('ERR_STAFF_ROLE_DENIED: Cashiers cannot segregate inventory.');
    }
    if (!_staffRoles.contains(roleUpper)) {
      throw StateError('ERR_STAFF_ROLE_DENIED: Role not authorized.');
    }

    if (quantity <= 0) {
      throw ArgumentError('Quantity must be greater than zero.');
    }

    final batch = batches[batchId];
    if (batch == null) {
      throw StateError('Batch not found: $batchId');
    }

    if (quantity > batch.availableQuantity) {
      throw ArgumentError('Cannot segregate more than available units.');
    }

    batch.reservedQuantityBaseUnits += quantity;

    final segId = _nextId('seg');
    final totalCost = batch.unitCost * quantity;
    final loc = segregationLocation.trim().isNotEmpty ? segregationLocation.trim() : 'SEGREGATION-HOLD';
    final raw = '$segId|${batch.batchNumber}|$quantity|${category.name}';
    final hash = sha256.convert(utf8.encode(raw)).toString();

    final rec = MobileSegregationRecord(
      segregationId: segId,
      tenantId: tenantId,
      branchId: branchId,
      batchId: batch.batchId,
      batchNumber: batch.batchNumber,
      segregatedQuantity: quantity,
      unitCostBdt: batch.unitCost,
      totalCostImpactBdt: totalCost,
      category: category,
      status: MobileSegregationStatus.segregated,
      segregationLocation: loc,
      reasonNotes: reasonNotes,
      segregatedByUserId: actorUserId,
      segregatedAt: DateTime.now(),
      immutableHash: hash,
    );
    records[segId] = rec;
    return rec;
  }

  MobileSegregationRecord releaseToSellable({
    required String segregationId,
    required String justification,
    String newStorageLocation = 'SHELF-ACTIVE',
    required String inspectorUserId,
    required String inspectorRole,
  }) {
    final roleUpper = inspectorRole.toUpperCase();
    if (!_qaRoles.contains(roleUpper)) {
      throw StateError('ERR_QA_ROLE_REQUIRED: QA authority required to release stock.');
    }

    final rec = records[segregationId];
    if (rec == null) throw StateError('Record not found.');

    if (rec.status != MobileSegregationStatus.segregated) {
      throw StateError('Cannot release record from status: ${rec.status.name}');
    }

    if (rec.category == MobileSegregationCategory.recalled ||
        rec.category == MobileSegregationCategory.suspiciousCounterfeit) {
      throw StateError('ERR_PROHIBITED_RELEASE: Recalled or counterfeit items cannot be released.');
    }

    final batch = batches[rec.batchId];
    if (batch != null && batch.isExpired) {
      throw StateError('ERR_EXPIRED_BATCH_CANNOT_BE_RELEASED: Cannot release expired batch.');
    }

    if (justification.trim().length < 15) {
      throw ArgumentError('ERR_RELEASE_JUSTIFICATION_REQUIRED: Detailed justification (min 15 chars) required.');
    }

    if (batch != null) {
      batch.reservedQuantityBaseUnits = (batch.reservedQuantityBaseUnits - rec.segregatedQuantity).clamp(0, batch.quantityBaseUnits);
      if (newStorageLocation.trim().isNotEmpty) {
        batch.storageLocation = newStorageLocation.trim();
      }
    }

    rec.status = MobileSegregationStatus.releasedToSellable;
    rec.inspectedByUserId = inspectorUserId;
    rec.inspectedAt = DateTime.now();
    rec.releaseJustification = justification.trim();
    rec.actionedByUserId = inspectorUserId;
    rec.actionedAt = DateTime.now();
    return rec;
  }

  MobileSegregationRecord disposeOrReturnStock({
    required String segregationId,
    required MobileSegregationStatus actionType,
    required String dispositionReference,
    String notes = '',
    required String actorUserId,
    required String actorRole,
  }) {
    final roleUpper = actorRole.toUpperCase();
    if (!_qaRoles.contains(roleUpper)) {
      throw StateError('ERR_QA_ROLE_REQUIRED: QA authority required.');
    }

    final rec = records[segregationId];
    if (rec == null) throw StateError('Record not found.');

    final batch = batches[rec.batchId];
    if (batch != null) {
      batch.quantityBaseUnits = (batch.quantityBaseUnits - rec.segregatedQuantity).clamp(0, batch.quantityBaseUnits);
      batch.reservedQuantityBaseUnits = (batch.reservedQuantityBaseUnits - rec.segregatedQuantity).clamp(0, batch.quantityBaseUnits);
    }

    rec.status = actionType;
    rec.actionedByUserId = actorUserId;
    rec.actionedAt = DateTime.now();
    rec.dispositionReference = dispositionReference;
    rec.ledgerEntryId = _nextId('stkled');
    return rec;
  }
}
