import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/inventory/mobile_purchase_cost_lot_client.dart';

void main() {
  group('MobilePurchaseCostLotClient COGS Allocation Tests (P167)', () {
    test('allocates COGS from single lot when remaining quantity is sufficient', () {
      final lot = MobileCostLotRecord(
        lotId: 'pcl-1',
        tenantId: 'ten-1',
        branchId: 'br-1',
        productId: 'prod-1',
        productBrandName: 'Napa Extra',
        batchId: 'bat-1',
        batchNumber: 'B-101',
        purchaseDate: DateTime(2026, 1, 10),
        unitCost: 2.10,
        initialQuantity: 100,
        remainingQuantity: 100,
      );

      final res = MobilePurchaseCostLotClient.allocateCogs(
        candidateLots: [lot],
        requestedUnits: 40,
      );

      expect(res.isSuccessful, isTrue);
      expect(res.errorCode, isNull);
      expect(res.totalUnits, 40);
      expect(res.totalCogs, 84.0);
      expect(res.effectiveUnitCogs, 2.10);
      expect(lot.remainingQuantity, 60);
      expect(lot.status, 'ACTIVE');
    });

    test('allocates multi-tier FIFO across distinct cost lots with exact COGS', () {
      // Lot 1 received on Jan 10 @ 2.10 BDT (100 units)
      final lot1 = MobileCostLotRecord(
        lotId: 'pcl-1',
        tenantId: 'ten-1',
        branchId: 'br-1',
        productId: 'prod-1',
        batchId: 'bat-1',
        batchNumber: 'B-101',
        purchaseDate: DateTime(2026, 1, 10),
        unitCost: 2.10,
        initialQuantity: 100,
        remainingQuantity: 100,
      );

      // Lot 2 received on Jan 25 @ 2.35 BDT (50 units)
      final lot2 = MobileCostLotRecord(
        lotId: 'pcl-2',
        tenantId: 'ten-1',
        branchId: 'br-1',
        productId: 'prod-1',
        batchId: 'bat-1',
        batchNumber: 'B-101',
        purchaseDate: DateTime(2026, 1, 25),
        unitCost: 2.35,
        initialQuantity: 50,
        remainingQuantity: 50,
      );

      // 120 units: 100 from Lot 1 (210 BDT) + 20 from Lot 2 (47 BDT) = 257 BDT
      final res = MobilePurchaseCostLotClient.allocateCogs(
        candidateLots: [lot2, lot1], // Unsorted
        requestedUnits: 120,
      );

      expect(res.isSuccessful, isTrue);
      expect(res.totalUnits, 120);
      expect(res.totalCogs, 257.0);
      expect(res.effectiveUnitCogs, 2.1417);

      expect(lot1.remainingQuantity, 0);
      expect(lot1.status, 'DEPLETED');
      expect(lot2.remainingQuantity, 30);
      expect(lot2.status, 'ACTIVE');

      expect(res.allocations.length, 2);
      expect(res.allocations[0].unitsAllocated, 100);
      expect(res.allocations[0].lotCogs, 210.0);
      expect(res.allocations[1].unitsAllocated, 20);
      expect(res.allocations[1].lotCogs, 47.0);
    });

    test('fails when requested quantity exceeds available lot stock', () {
      final lot = MobileCostLotRecord(
        lotId: 'pcl-1',
        tenantId: 'ten-1',
        branchId: 'br-1',
        productId: 'prod-1',
        batchId: 'bat-1',
        batchNumber: 'B-101',
        purchaseDate: DateTime(2026, 1, 10),
        unitCost: 2.10,
        initialQuantity: 50,
        remainingQuantity: 20,
      );

      final res = MobilePurchaseCostLotClient.allocateCogs(
        candidateLots: [lot],
        requestedUnits: 25,
      );

      expect(res.isSuccessful, isFalse);
      expect(res.errorCode, 'ERR_INSUFFICIENT_COST_LOT_STOCK');
      expect(res.messageBn, contains('পর্যাপ্ত স্টক নেই'));
      expect(lot.remainingQuantity, 20);
    });

    test('skips depleted or inactive lots during FIFO allocation', () {
      final depleted = MobileCostLotRecord(
        lotId: 'pcl-dep',
        tenantId: 'ten-1',
        branchId: 'br-1',
        productId: 'prod-1',
        batchId: 'bat-1',
        batchNumber: 'B-101',
        purchaseDate: DateTime(2025, 12, 1),
        unitCost: 1.90,
        initialQuantity: 50,
        remainingQuantity: 0,
        status: 'DEPLETED',
      );

      final active = MobileCostLotRecord(
        lotId: 'pcl-act',
        tenantId: 'ten-1',
        branchId: 'br-1',
        productId: 'prod-1',
        batchId: 'bat-1',
        batchNumber: 'B-101',
        purchaseDate: DateTime(2026, 1, 10),
        unitCost: 2.10,
        initialQuantity: 50,
        remainingQuantity: 50,
      );

      final res = MobilePurchaseCostLotClient.allocateCogs(
        candidateLots: [depleted, active],
        requestedUnits: 15,
      );

      expect(res.isSuccessful, isTrue);
      expect(res.allocations.length, 1);
      expect(res.allocations[0].lotId, 'pcl-act');
      expect(active.remainingQuantity, 35);
    });
  });

  group('MobilePurchaseCostLotClient Reversal & Valuation Tests', () {
    test('restores lot quantities and re-activates depleted lot on reversal', () {
      final lot = MobileCostLotRecord(
        lotId: 'pcl-rev',
        tenantId: 'ten-1',
        branchId: 'br-1',
        productId: 'prod-1',
        batchId: 'bat-1',
        batchNumber: 'B-101',
        purchaseDate: DateTime(2026, 1, 10),
        unitCost: 2.10,
        initialQuantity: 50,
        remainingQuantity: 0,
        status: 'DEPLETED',
      );

      const alloc = MobileLotAllocation(
        lotId: 'pcl-rev',
        batchId: 'bat-1',
        batchNumber: 'B-101',
        unitsAllocated: 25,
        unitCost: 2.10,
        lotCogs: 52.50,
      );

      final res = MobilePurchaseCostLotClient.reverseAllocation(
        lots: [lot],
        allocations: const [alloc],
        reason: 'Customer Return',
      );

      expect(res.isSuccessful, isTrue);
      expect(res.totalRestoredUnits, 25);
      expect(res.totalRestoredCogs, 52.50);
      expect(lot.remainingQuantity, 25);
      expect(lot.status, 'ACTIVE');
    });

    test('accurately calculates total inventory asset valuation', () {
      final lot1 = MobileCostLotRecord(
        lotId: 'l1',
        tenantId: 't1',
        branchId: 'b1',
        productId: 'p1',
        batchId: 'bat1',
        batchNumber: 'B1',
        purchaseDate: DateTime(2026, 1, 10),
        unitCost: 2.00,
        initialQuantity: 100,
        remainingQuantity: 50,
      ); // 50 * 2.00 = 100

      final lot2 = MobileCostLotRecord(
        lotId: 'l2',
        tenantId: 't1',
        branchId: 'b1',
        productId: 'p1',
        batchId: 'bat1',
        batchNumber: 'B1',
        purchaseDate: DateTime(2026, 1, 20),
        unitCost: 2.50,
        initialQuantity: 100,
        remainingQuantity: 40,
      ); // 40 * 2.50 = 100

      final valuation = MobilePurchaseCostLotClient.computeInventoryValuation([lot1, lot2]);
      expect(valuation, 200.0);
    });
  });
}

