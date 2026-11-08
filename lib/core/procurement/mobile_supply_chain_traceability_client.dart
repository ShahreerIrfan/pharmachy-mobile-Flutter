// mobile_supply_chain_traceability_client.dart
// Architecture Decision: ADR-0197 (P197).
// Phase 10: Suppliers, Purchase Orders & Supply Chain.
//
// Flutter mobile client governing Supply-Chain Traceability:
// - Traces each medicine lot through supplier, PO, shipment, GRN, storage, and sales.
// - Computes physical stock reconciliation and cold-chain integrity flags.
// - Generates audited traceability records with cryptographic verification hashes.

import 'dart:convert';
import 'package:crypto/crypto.dart';

class MobileProductTrace {
  final String productId;
  final String brandName;
  final String genericName;
  final String strength;
  final String dosageForm;
  final String manufacturer;
  final bool requiresColdChain;

  MobileProductTrace({
    required this.productId,
    this.brandName = '',
    this.genericName = '',
    this.strength = '',
    this.dosageForm = '',
    this.manufacturer = '',
    this.requiresColdChain = false,
  });

  Map<String, dynamic> toJson() => {
        'product_id': productId,
        'brand_name': brandName,
        'generic_name': genericName,
        'strength': strength,
        'dosage_form': dosageForm,
        'manufacturer': manufacturer,
        'requires_cold_chain': requiresColdChain,
      };
}

class MobileBatchTrace {
  final String batchId;
  final String batchNumber;
  final String lotReference;
  final String? expiryDate;
  final double costPerUnit;
  final String status;
  final String storageCondition;
  final bool isQuarantined;
  final String? recallNotice;
  final int availableQuantity;

  MobileBatchTrace({
    required this.batchId,
    required this.batchNumber,
    this.lotReference = '',
    this.expiryDate,
    this.costPerUnit = 0.0,
    this.status = 'ACTIVE',
    this.storageCondition = '',
    this.isQuarantined = false,
    this.recallNotice,
    this.availableQuantity = 0,
  });

  Map<String, dynamic> toJson() => {
        'batch_id': batchId,
        'batch_number': batchNumber,
        'lot_reference': lotReference,
        'expiry_date': expiryDate,
        'cost_per_unit': costPerUnit.toStringAsFixed(4),
        'status': status,
        'storage_condition': storageCondition,
        'is_quarantined': isQuarantined,
        'recall_notice': recallNotice,
        'available_quantity': availableQuantity,
      };
}

class MobileDownstreamSale {
  final String allocationId;
  final String invoiceNumber;
  final String dispensedAt;
  final int quantityDispensed;
  final int quantityReturned;
  final double unitSellingPrice;
  final bool isReturned;

  MobileDownstreamSale({
    required this.allocationId,
    this.invoiceNumber = '',
    required this.dispensedAt,
    this.quantityDispensed = 0,
    this.quantityReturned = 0,
    this.unitSellingPrice = 0.0,
    this.isReturned = false,
  });

  Map<String, dynamic> toJson() => {
        'allocation_id': allocationId,
        'invoice_number': invoiceNumber,
        'dispensed_at': dispensedAt,
        'quantity_dispensed': quantityDispensed,
        'quantity_returned': quantityReturned,
        'unit_selling_price': unitSellingPrice.toStringAsFixed(4),
        'is_returned': isReturned,
      };
}

class MobileReconciliation {
  final int totalReceivedQuantity;
  final int totalDispensedQuantity;
  final int totalReturnedQuantity;
  final int currentStockOnHand;
  final int discrepancyQuantity;
  final bool coldChainBreachedInTransit;

  MobileReconciliation({
    this.totalReceivedQuantity = 0,
    this.totalDispensedQuantity = 0,
    this.totalReturnedQuantity = 0,
    this.currentStockOnHand = 0,
    this.discrepancyQuantity = 0,
    this.coldChainBreachedInTransit = false,
  });

  Map<String, dynamic> toJson() => {
        'total_received_quantity': totalReceivedQuantity,
        'total_dispensed_quantity': totalDispensedQuantity,
        'total_returned_quantity': totalReturnedQuantity,
        'current_stock_on_hand': currentStockOnHand,
        'discrepancy_quantity': discrepancyQuantity,
        'cold_chain_breached_in_transit': coldChainBreachedInTransit,
      };
}

class MobileBatchLineage {
  final MobileProductTrace product;
  final MobileBatchTrace batch;
  final List<String> poNumbers;
  final List<String> grnNumbers;
  final List<String> shipmentConsignments;
  final List<MobileDownstreamSale> sales;
  final MobileReconciliation reconciliation;

  MobileBatchLineage({
    required this.product,
    required this.batch,
    this.poNumbers = const [],
    this.grnNumbers = const [],
    this.shipmentConsignments = const [],
    this.sales = const [],
    required this.reconciliation,
  });

  Map<String, dynamic> toJson() => {
        'product': product.toJson(),
        'batch': batch.toJson(),
        'po_numbers': poNumbers,
        'grn_numbers': grnNumbers,
        'shipment_consignments': shipmentConsignments,
        'sales': sales.map((s) => s.toJson()).toList(),
        'reconciliation': reconciliation.toJson(),
      };
}

class MobileTraceabilityRecord {
  final String traceId;
  final String traceNumber;
  final String tenantId;
  final String branchId;
  final String productId;
  final String productName;
  final String batchNumber;
  final String lotReference;
  final String auditPurpose;
  final MobileReconciliation reconciliation;
  final String immutableVerificationHash;
  final String? generatedBy;
  final DateTime generatedAt;
  final String notes;
  final MobileBatchLineage lineage;

  MobileTraceabilityRecord({
    required this.traceId,
    required this.traceNumber,
    required this.tenantId,
    required this.branchId,
    required this.productId,
    this.productName = '',
    required this.batchNumber,
    this.lotReference = '',
    this.auditPurpose = 'INTERNAL_AUDIT',
    required this.reconciliation,
    required this.immutableVerificationHash,
    this.generatedBy,
    DateTime? generatedAt,
    this.notes = '',
    required this.lineage,
  }) : generatedAt = generatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'trace_id': traceId,
        'trace_number': traceNumber,
        'tenant_id': tenantId,
        'branch_id': branchId,
        'product_id': productId,
        'product_name': productName,
        'batch_number': batchNumber,
        'lot_reference': lotReference,
        'audit_purpose': auditPurpose,
        'reconciliation': reconciliation.toJson(),
        'immutable_verification_hash': immutableVerificationHash,
        'generated_by': generatedBy,
        'generated_at': generatedAt.toIso8601String(),
        'notes': notes,
        'lineage': lineage.toJson(),
      };
}

class MobileSupplyChainTraceabilityClient {
  final String tenantId;
  final String branchId;
  final String userRole;
  final String userId;
  final bool isOffline;
  final Map<String, MobileTraceabilityRecord> recordStore;

  static const Set<String> _allowedTraceRoles = {
    'BRANCH_MANAGER',
    'PHARMACY_OWNER',
    'SUPERADMIN',
    'STAFF_PHARMACIST',
    'PROCUREMENT_OFFICER',
    'INVENTORY_CLERK',
    'AUDITOR',
  };

  MobileSupplyChainTraceabilityClient({
    required this.tenantId,
    required this.branchId,
    required this.userRole,
    required this.userId,
    this.isOffline = false,
    Map<String, MobileTraceabilityRecord>? recordStore,
  }) : recordStore = recordStore ?? {};

  void _assertTraceRole() {
    if (userRole.toUpperCase() == 'CASHIER' ||
        !_allowedTraceRoles.contains(userRole.toUpperCase())) {
      throw Exception(
          'ERR_STAFF_ROLE_DENIED: Staff role $userRole cannot access supply chain traceability.');
    }
  }

  static String computeVerificationHash({
    required String traceId,
    required String tenantId,
    required String batchNumber,
    required int totalReceived,
    required int totalDispensed,
    required int currentStock,
    required bool coldChainBreached,
    required String auditPurpose,
    DateTime? generatedAt,
  }) {
    final raw =
        '$traceId|$tenantId|$batchNumber|$totalReceived|$totalDispensed|$currentStock|$coldChainBreached|$auditPurpose|${generatedAt?.toIso8601String() ?? ""}';
    return sha256.convert(utf8.encode(raw)).toString();
  }

  MobileTraceabilityRecord generateTraceabilityRecord({
    required MobileBatchLineage lineage,
    String auditPurpose = 'INTERNAL_AUDIT',
    String notes = '',
  }) {
    _assertTraceRole();

    final trcId =
        'trc-${recordStore.length + 1}-${DateTime.now().microsecondsSinceEpoch.toString().substring(7)}';
    final trcNum = 'TRC-${recordStore.length + 1}-${DateTime.now().millisecondsSinceEpoch}';
    final now = DateTime.now();

    final rec = lineage.reconciliation;
    final hash = computeVerificationHash(
      traceId: trcId,
      tenantId: tenantId,
      batchNumber: lineage.batch.batchNumber,
      totalReceived: rec.totalReceivedQuantity,
      totalDispensed: rec.totalDispensedQuantity,
      currentStock: rec.currentStockOnHand,
      coldChainBreached: rec.coldChainBreachedInTransit,
      auditPurpose: auditPurpose,
      generatedAt: now,
    );

    final record = MobileTraceabilityRecord(
      traceId: trcId,
      traceNumber: trcNum,
      tenantId: tenantId,
      branchId: branchId,
      productId: lineage.product.productId,
      productName: lineage.product.brandName,
      batchNumber: lineage.batch.batchNumber,
      lotReference: lineage.batch.lotReference,
      auditPurpose: auditPurpose,
      reconciliation: rec,
      immutableVerificationHash: hash,
      generatedBy: userId,
      generatedAt: now,
      notes: notes,
      lineage: lineage,
    );

    recordStore[trcId] = record;
    return record;
  }

  MobileTraceabilityRecord getTraceabilityRecord(String traceId) {
    final record = recordStore[traceId];
    if (record == null) {
      throw Exception('ERR_TRACE_NOT_FOUND: Trace record $traceId not found.');
    }
    return record;
  }

  List<MobileTraceabilityRecord> listTraceabilityRecords({String? auditPurposeFilter}) {
    final list = recordStore.values.toList();
    if (auditPurposeFilter == null || auditPurposeFilter.isEmpty) return list;
    return list
        .where((r) => r.auditPurpose.toUpperCase() == auditPurposeFilter.toUpperCase())
        .toList();
  }
}
