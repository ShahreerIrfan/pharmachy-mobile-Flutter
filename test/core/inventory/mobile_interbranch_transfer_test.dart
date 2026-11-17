/// mobile_interbranch_transfer_test.dart
/// Architecture Decision: ADR-0208, ADR-0209, ADR-0210 (P210).
/// Phase 11: Inventory, Warehouse, Cold Chain & Transfers.

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/inventory/mobile_interbranch_transfer_client.dart';

void main() {
  group('MobileInterBranchTransferClient Tests (P210)', () {
    late MobileInterBranchTransferClient client;

    setUp(() {
      client = MobileInterBranchTransferClient();
      client.registerBatch(MobileBatchStock(
        batchId: 'batch-source-01',
        branchId: 'branch-main',
        medicineId: 'med-cefixime',
        batchNumber: 'BATCH-CEF-001',
        lotReference: 'LOT-CEF-2026-X1',
        expiryDate: '2027-12-31',
        quantityBaseUnits: 100,
        costPerUnit: 20.0,
      ));
    });

    test('Requesting transfer applies markup policy and reserves stock', () {
      final item = MobileTransferItem(
        itemId: 'item-01',
        batchId: 'batch-source-01',
        medicineId: 'med-cefixime',
        medicineName: 'Cefixime 200mg',
        batchNumber: 'BATCH-CEF-001',
        lotReference: 'LOT-CEF-2026-X1',
        expiryDate: '2027-12-31',
        quantityRequested: 40,
      );

      final transfer = client.requestTransfer(
        tenantId: 'tenant-001',
        sourceBranchId: 'branch-main',
        destinationBranchId: 'branch-dhanmondi',
        requestedBy: 'usr-pharm',
        staffRole: 'PHARMACIST',
        priority: MobileTransferPriority.urgent,
        costPolicy: MobileTransferCostPolicy.landedMarkup,
        markupPercentage: 10.0, // 20 + 10% = 22.0
        items: [item],
        notes: 'Urgent clinic request',
      );

      expect(transfer.status, equals(MobileTransferStatus.requested));
      final batch = client.getBatch('batch-source-01')!;
      expect(batch.reservedQuantityBaseUnits, equals(40));
      expect(batch.availableQuantity, equals(60));
      expect(item.transferredCostPerUnit, equals(22.0));
      expect(item.originalCostPerUnit, equals(20.0));
    });

    test('Lot cost continuity & weighted average cost calculation', () {
      final item = MobileTransferItem(
        itemId: 'item-01',
        batchId: 'batch-source-01',
        medicineId: 'med-cefixime',
        medicineName: 'Cefixime 200mg',
        batchNumber: 'BATCH-CEF-001',
        lotReference: 'LOT-CEF-2026-X1',
        expiryDate: '2027-12-31',
        quantityRequested: 50,
      );

      final transfer = client.requestTransfer(
        tenantId: 'tenant-001',
        sourceBranchId: 'branch-main',
        destinationBranchId: 'branch-gulshan',
        requestedBy: 'usr-mgr',
        staffRole: 'BRANCH_MANAGER',
        costPolicy: MobileTransferCostPolicy.landedMarkup,
        markupPercentage: 10.0, // 20 + 10% = 22.0
        items: [item],
        notes: 'Monthly distribution',
      );

      client.approveTransfer(transferId: transfer.transferId, approvedBy: 'usr-owner', staffRole: 'OWNER');
      client.dispatchTransfer(transferId: transfer.transferId, dispatchedBy: 'usr-pharm', staffRole: 'PHARMACIST');

      // Destination batch already has 50 units @ 20.0
      final destGoodBatch = MobileBatchStock(
        batchId: 'batch-dest-good',
        branchId: 'branch-gulshan',
        medicineId: 'med-cefixime',
        batchNumber: 'BATCH-CEF-001',
        lotReference: 'LOT-CEF-2026-X1',
        expiryDate: '2027-12-31',
        quantityBaseUnits: 50,
        costPerUnit: 20.0,
      );

      final reconLine = MobileReconciliationLine(
        itemId: 'item-01',
        quantityGood: 50,
        quantityDamaged: 0,
        quantityLost: 0,
      );

      final reconciled = client.reconcileTransfer(
        transferId: transfer.transferId,
        actorUser: 'usr-receiver',
        staffRole: 'PHARMACIST',
        lines: [reconLine],
        notes: 'Inspection verified by pharmacist',
        destinationGoodBatches: {'med-cefixime': destGoodBatch},
      );

      expect(reconciled.status, equals(MobileTransferStatus.received));
      expect(destGoodBatch.quantityBaseUnits, equals(100));
      // (50*20 + 50*22) / 100 = 21.0
      expect(destGoodBatch.costPerUnit, equals(21.0));
      expect(destGoodBatch.originBatchId, equals('batch-source-01'));
      expect(destGoodBatch.originBranchId, equals('branch-main'));
    });

    test('Expiry alteration prohibited throws StateError', () {
      final item = MobileTransferItem(
        itemId: 'item-02',
        batchId: 'batch-source-01',
        medicineId: 'med-cefixime',
        medicineName: 'Cefixime 200mg',
        batchNumber: 'BATCH-CEF-001',
        lotReference: 'LOT-CEF-2026-X1',
        expiryDate: '2027-12-31',
        quantityRequested: 50,
      );

      final transfer = client.requestTransfer(
        tenantId: 'tenant-001',
        sourceBranchId: 'branch-main',
        destinationBranchId: 'branch-uttara',
        requestedBy: 'usr-pharm',
        staffRole: 'PHARMACIST',
        items: [item],
        notes: 'Test',
      );
      client.approveTransfer(transferId: transfer.transferId, approvedBy: 'usr-mgr', staffRole: 'BRANCH_MANAGER');
      client.dispatchTransfer(transferId: transfer.transferId, dispatchedBy: 'usr-pharm', staffRole: 'PHARMACIST');

      // Conflicting expiry date!
      final conflictBatch = MobileBatchStock(
        batchId: 'batch-conflict',
        branchId: 'branch-uttara',
        medicineId: 'med-cefixime',
        batchNumber: 'BATCH-CEF-001',
        expiryDate: '2028-06-30', // Different!
        quantityBaseUnits: 10,
        costPerUnit: 20.0,
      );

      final line = MobileReconciliationLine(
        itemId: 'item-02',
        quantityGood: 50,
        quantityDamaged: 0,
        quantityLost: 0,
      );

      expect(
        () => client.reconcileTransfer(
          transferId: transfer.transferId,
          actorUser: 'usr-pharm',
          staffRole: 'PHARMACIST',
          lines: [line],
          notes: 'Conflict test',
          destinationGoodBatches: {'med-cefixime': conflictBatch},
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('Duplicate reconciliation throws StateError', () {
      final item = MobileTransferItem(
        itemId: 'item-03',
        batchId: 'batch-source-01',
        medicineId: 'med-cefixime',
        medicineName: 'Cefixime 200mg',
        batchNumber: 'BATCH-CEF-001',
        quantityRequested: 20,
      );

      final transfer = client.requestTransfer(
        tenantId: 'tenant-001',
        sourceBranchId: 'branch-main',
        destinationBranchId: 'branch-uttara',
        requestedBy: 'usr-pharm',
        staffRole: 'PHARMACIST',
        items: [item],
        notes: 'Test',
      );
      client.approveTransfer(transferId: transfer.transferId, approvedBy: 'usr-mgr', staffRole: 'BRANCH_MANAGER');
      client.dispatchTransfer(transferId: transfer.transferId, dispatchedBy: 'usr-pharm', staffRole: 'PHARMACIST');

      final line = MobileReconciliationLine(
        itemId: 'item-03',
        quantityGood: 20,
        quantityDamaged: 0,
        quantityLost: 0,
      );

      client.reconcileTransfer(
        transferId: transfer.transferId,
        actorUser: 'usr-pharm',
        staffRole: 'PHARMACIST',
        lines: [line],
        notes: 'First receipt',
      );

      expect(
        () => client.reconcileTransfer(
          transferId: transfer.transferId,
          actorUser: 'usr-pharm',
          staffRole: 'PHARMACIST',
          lines: [line],
          notes: 'Duplicate receipt attempt',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('Cashier role throws StateError', () {
      final item = MobileTransferItem(
        itemId: 'item-04',
        batchId: 'batch-source-01',
        medicineId: 'med-cefixime',
        medicineName: 'Cefixime 200mg',
        batchNumber: 'BATCH-CEF-001',
        quantityRequested: 10,
      );

      expect(
        () => client.requestTransfer(
          tenantId: 'tenant-001',
          sourceBranchId: 'branch-main',
          destinationBranchId: 'branch-uttara',
          requestedBy: 'usr-cashier',
          staffRole: 'CASHIER',
          items: [item],
          notes: 'Cashier attempt',
        ),
        throwsA(isA<StateError>()),
      );
    });
  });
}
