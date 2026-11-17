/// mobile_stock_quarantine_client.dart
/// Architecture Decision: ADR-0206 (P206).
/// Phase 11: Inventory, Warehouse, Cold Chain & Transfers.

import 'dart:convert';
import 'package:crypto/crypto.dart';

enum MobileQuarantineReason {
  batchExpired('Batch Passed Expiry Date', 'মেয়াদোত্তীর্ণ ব্যাচ'),
  nearExpiryThreshold('Near-Expiry Sale Cutoff', 'মেয়াদ শেষের কাছাকাছি বিক্রয় সীমাবদ্ধতা'),
  coldChainExcursion('Cold-Chain Temperature Breach', 'কোল্ড-চেইন তাপমাত্রা বিচ্যুতি'),
  qualityDefect('Quality / Blister Foil Defect', 'গুণগত ত্রুটি / নষ্ট ফয়েল'),
  dgdaMandate('DGDA Regulatory Mandate', 'ডিজিডিএ নিয়ন্ত্রক নির্দেশনা'),
  recall('Manufacturer Batch Recall', 'উত্পাদক কর্তৃক প্রত্যাহার');

  final String labelEn;
  final String labelBn;

  const MobileQuarantineReason(this.labelEn, this.labelBn);
}

enum MobileQuarantineStatus {
  quarantined('Held in Quarantine', 'কোয়ারেন্টাইনে সংরক্ষিত'),
  released('Released to Active Stock', 'সক্রিয় স্টকে ছাড়কৃত'),
  disposed('Safely Disposed', 'নিরাপদে অপসারিত'),
  returnedToSupplier('Returned to Supplier', 'সরবরাহকারীকে ফেরত'),
  destroyed('Destroyed Supervised', 'তত্ত্বাবধানে ধ্বংসকৃত');

  final String labelEn;
  final String labelBn;

  const MobileQuarantineStatus(this.labelEn, this.labelBn);
}

class MobileBatchItem {
  final String batchId;
  final String batchNumber;
  final DateTime expiryDate;
  int quantityBaseUnits;
  final double unitCost;
  String storageLocation;
  bool isQuarantined;
  String status;

  MobileBatchItem({
    required this.batchId,
    required this.batchNumber,
    required this.expiryDate,
    required this.quantityBaseUnits,
    required this.unitCost,
    required this.storageLocation,
    this.isQuarantined = false,
    this.status = 'ACTIVE',
  });
}

class MobileQuarantineRecord {
  final String quarantineId;
  final String tenantId;
  final String branchId;
  final String batchId;
  final String batchNumber;
  final int quarantinedQuantity;
  final double unitCostBdt;
  final double totalCostImpactBdt;
  final MobileQuarantineReason reason;
  MobileQuarantineStatus status;
  final String quarantineNotes;
  String quarantineLocation;
  final String quarantinedByUserId;
  final DateTime quarantinedAt;
  String? actionedByUserId;
  DateTime? actionedAt;
  String? actionNotes;
  String? disposalCertificateRef;
  String? ledgerEntryId;
  final String immutableHash;

  MobileQuarantineRecord({
    required this.quarantineId,
    required this.tenantId,
    required this.branchId,
    required this.batchId,
    required this.batchNumber,
    required this.quarantinedQuantity,
    required this.unitCostBdt,
    required this.totalCostImpactBdt,
    required this.reason,
    required this.status,
    required this.quarantineNotes,
    required this.quarantineLocation,
    required this.quarantinedByUserId,
    required this.quarantinedAt,
    this.actionedByUserId,
    this.actionedAt,
    this.actionNotes,
    this.disposalCertificateRef,
    this.ledgerEntryId,
    required this.immutableHash,
  });
}

class MobileStockQuarantineClient {
  static const Set<String> _allowedRoles = {
    'PHARMACY_OWNER', 'BRANCH_MANAGER', 'PLATFORM_SUPER_ADMIN',
    'STAFF_PHARMACIST', 'PHARMACIST', 'INVENTORY_CLERK', 'TENANT_OWNER'
  };

  static const Set<String> _actionRoles = {
    'PHARMACY_OWNER', 'BRANCH_MANAGER', 'PLATFORM_SUPER_ADMIN', 'TENANT_OWNER'
  };

  static int _counter = 0;
  static String _nextId(String prefix) =>
      '$prefix-${DateTime.now().millisecondsSinceEpoch}-${++_counter}';

  final Map<String, MobileBatchItem> batches = {};
  final Map<String, MobileQuarantineRecord> records = {};

  void registerBatch(MobileBatchItem batch) {
    batches[batch.batchId] = batch;
  }

  MobileBatchItem? getBatch(String batchId) => batches[batchId];

  void assertSaleAllowed(String batchId) {
    final batch = batches[batchId];
    if (batch == null) {
      throw StateError('Batch not found: $batchId');
    }
    if (batch.isQuarantined || batch.status.toUpperCase() == 'QUARANTINED') {
      throw StateError('ERR_EXPIRED_STOCK_SALE_PROHIBITED: Batch is held in quarantine.');
    }
    final now = DateTime.now();
    if (batch.expiryDate.isBefore(now)) {
      throw StateError('ERR_EXPIRED_STOCK_SALE_PROHIBITED: Batch is expired.');
    }
  }

  MobileQuarantineRecord quarantineBatch({
    required String tenantId,
    required String branchId,
    required String batchId,
    required MobileQuarantineReason reason,
    String notes = '',
    String quarantineLocation = 'QUARANTINE-ZONE',
    required String actorUserId,
    required String actorRole,
  }) {
    final roleUpper = actorRole.toUpperCase();
    if (roleUpper == 'CASHIER') {
      throw StateError('ERR_STAFF_ROLE_DENIED: Cashiers cannot quarantine inventory.');
    }
    if (!_allowedRoles.contains(roleUpper)) {
      throw StateError('ERR_STAFF_ROLE_DENIED: Role not authorized.');
    }

    final batch = batches[batchId];
    if (batch == null) {
      throw StateError('Batch not found: $batchId');
    }
    if (batch.isQuarantined) {
      throw StateError('ERR_ALREADY_QUARANTINED: Batch is already quarantined.');
    }

    final loc = quarantineLocation.trim().isNotEmpty ? quarantineLocation.trim() : 'QUARANTINE-ZONE';
    batch.isQuarantined = true;
    batch.status = 'QUARANTINED';
    batch.storageLocation = loc;

    final qId = _nextId('quar');
    final totalCost = batch.unitCost * batch.quantityBaseUnits;
    final raw = '$qId|${batch.batchNumber}|${batch.quantityBaseUnits}|${reason.name}';
    final hash = sha256.convert(utf8.encode(raw)).toString();

    final rec = MobileQuarantineRecord(
      quarantineId: qId,
      tenantId: tenantId,
      branchId: branchId,
      batchId: batch.batchId,
      batchNumber: batch.batchNumber,
      quarantinedQuantity: batch.quantityBaseUnits,
      unitCostBdt: batch.unitCost,
      totalCostImpactBdt: totalCost,
      reason: reason,
      status: MobileQuarantineStatus.quarantined,
      quarantineNotes: notes,
      quarantineLocation: loc,
      quarantinedByUserId: actorUserId,
      quarantinedAt: DateTime.now(),
      immutableHash: hash,
    );
    rec.ledgerEntryId = _nextId('stkled');
    records[qId] = rec;
    return rec;
  }

  List<MobileQuarantineRecord> sweepExpiredBatches({
    required String tenantId,
    required String branchId,
    required String actorUserId,
    required String actorRole,
  }) {
    final swept = <MobileQuarantineRecord>[];
    final now = DateTime.now();
    for (final b in batches.values) {
      if (!b.isQuarantined && b.expiryDate.isBefore(now) && b.quantityBaseUnits > 0) {
        swept.add(quarantineBatch(
          tenantId: tenantId,
          branchId: branchId,
          batchId: b.batchId,
          reason: MobileQuarantineReason.batchExpired,
          notes: 'Automated sweep',
          quarantineLocation: 'QUARANTINE-ZONE',
          actorUserId: actorUserId,
          actorRole: actorRole,
        ));
      }
    }
    return swept;
  }

  MobileQuarantineRecord approveDisposal({
    required String quarantineId,
    required MobileQuarantineStatus actionType,
    String certRef = '',
    String actionNotes = '',
    required String actorUserId,
    required String actorRole,
  }) {
    final roleUpper = actorRole.toUpperCase();
    if (!_actionRoles.contains(roleUpper)) {
      throw StateError('ERR_ACTION_ROLE_DENIED: Manager privilege required.');
    }

    final rec = records[quarantineId];
    if (rec == null) throw StateError('Quarantine record not found.');
    if (rec.status != MobileQuarantineStatus.quarantined) {
      throw StateError('Cannot action non-quarantined record.');
    }

    final batch = batches[rec.batchId];
    if (batch != null) {
      batch.quantityBaseUnits = 0;
      batch.status = 'DEPLETED';
    }

    rec.status = actionType;
    rec.actionedByUserId = actorUserId;
    rec.actionedAt = DateTime.now();
    rec.disposalCertificateRef = certRef;
    rec.actionNotes = actionNotes;
    return rec;
  }

  MobileQuarantineRecord releaseQuarantine({
    required String quarantineId,
    required String releaseReason,
    required String newStorageLocation,
    required String actorUserId,
    required String actorRole,
  }) {
    final roleUpper = actorRole.toUpperCase();
    if (!_actionRoles.contains(roleUpper)) {
      throw StateError('ERR_ACTION_ROLE_DENIED: Manager privilege required.');
    }

    final rec = records[quarantineId];
    if (rec == null) throw StateError('Quarantine record not found.');

    final batch = batches[rec.batchId];
    if (batch != null && batch.expiryDate.isBefore(DateTime.now())) {
      throw StateError('ERR_EXPIRED_BATCH_CANNOT_BE_RELEASED: Cannot release expired batch.');
    }

    if (releaseReason.trim().length < 10) {
      throw ArgumentError('Release reason must be at least 10 characters.');
    }

    if (batch != null) {
      batch.isQuarantined = false;
      batch.status = 'ACTIVE';
      batch.storageLocation = newStorageLocation;
    }

    rec.status = MobileQuarantineStatus.released;
    rec.actionedByUserId = actorUserId;
    rec.actionedAt = DateTime.now();
    rec.actionNotes = releaseReason.trim();
    return rec;
  }
}

