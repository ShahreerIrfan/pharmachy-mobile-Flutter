import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/inventory/mobile_sale_lot_allocation_client.dart';

void main() {
  group('MobileSaleLotAllocationClient Tests (P170)', () {
    late MobileLotAllocationItem alloc1;
    late MobileLotAllocationItem alloc2;

    setUp(() {
      // Alloc 1: 50 units sold at 3.00, purchase cost 2.00
      alloc1 = MobileLotAllocationItem(
        allocationId: 'sall-001',
        invoiceId: 'inv-101',
        invoiceNumber: 'INV-2026-001',
        customerName: 'Rahim Ahmed',
        customerPhone: '+8801711111111',
        productId: 'prod-napa-extra',
        productBrandName: 'Napa Extra 500mg',
        batchId: 'bat-001',
        batchNumber: 'BX-2026-A',
        costLotId: 'pcl-001',
        quantityBaseUnits: 50,
        unitSellingPrice: 3.00,
        unitCost: 2.00,
      );

      // Alloc 2: 20 units sold at 3.00, purchase cost 2.20
      alloc2 = MobileLotAllocationItem(
        allocationId: 'sall-002',
        invoiceId: 'inv-102',
        invoiceNumber: 'INV-2026-002',
        customerName: 'Karim Uddin',
        customerPhone: '+8801722222222',
        productId: 'prod-napa-extra',
        productBrandName: 'Napa Extra 500mg',
        batchId: 'bat-002',
        batchNumber: 'BX-2026-B',
        costLotId: 'pcl-002',
        quantityBaseUnits: 20,
        unitSellingPrice: 3.00,
        unitCost: 2.20,
      );
    });

    test('1. Derives exact unblended gross profit and margin percentage per lot allocation', () {
      expect(alloc1.totalSellingPrice, equals(150.00));
      expect(alloc1.totalCost, equals(100.00));
      expect(alloc1.grossProfit, equals(50.00));
      expect(alloc1.profitMarginPct, equals(33.33));

      expect(alloc2.totalSellingPrice, equals(60.00));
      expect(alloc2.totalCost, equals(44.00));
      expect(alloc2.grossProfit, equals(16.00));
      expect(alloc2.profitMarginPct, equals(26.67));
    });

    test('2. Processes partial and full returns, strictly preventing excess returns', () {
      // 1. Partial return: 20 units out of 50
      final partialRes = MobileSaleLotAllocationClient.processReturn(alloc1, 20);
      expect(partialRes.isSuccessful, isTrue);
      expect(partialRes.returnedUnits, equals(20));
      expect(partialRes.refundAmount, equals(60.00));
      expect(partialRes.refundedCogs, equals(40.00));
      expect(alloc1.returnedQuantityBaseUnits, equals(20));
      expect(alloc1.status, equals('PARTIALLY_RETURNED'));
      expect(alloc1.netRetainedUnits, equals(30));

      // 2. Excess return rejection
      final excessRes = MobileSaleLotAllocationClient.processReturn(alloc1, 35);
      expect(excessRes.isSuccessful, isFalse);
      expect(excessRes.errorCode, equals('ERR_RETURN_EXCEEDS_DISPENSED'));

      // 3. Complete remaining return: 30 units
      final fullRes = MobileSaleLotAllocationClient.processReturn(alloc1, 30);
      expect(fullRes.isSuccessful, isTrue);
      expect(alloc1.returnedQuantityBaseUnits, equals(50));
      expect(alloc1.netRetainedUnits, equals(0));
      expect(alloc1.status, equals('FULLY_RETURNED'));
    });

    test('3. Traces statutory DGDA recall patient exposure across invoices and customers', () {
      final alloc3 = MobileLotAllocationItem(
        allocationId: 'sall-003',
        invoiceId: 'inv-103',
        invoiceNumber: 'INV-2026-003',
        customerName: 'Nasima Begum',
        customerPhone: '+8801733333333',
        productId: 'prod-napa-extra',
        batchId: 'bat-001', // Same batch
        batchNumber: 'BX-2026-A',
        quantityBaseUnits: 30,
        unitSellingPrice: 3.00,
        unitCost: 2.00,
      );

      final recallTrace = MobileSaleLotAllocationClient.traceRecallImpact(
        [alloc1, alloc2, alloc3],
        'bat-001',
      );

      expect(recallTrace.batchId, equals('bat-001'));
      expect(recallTrace.totalDispensedUnits, equals(80)); // 50 + 30
      expect(recallTrace.totalReturnedUnits, equals(0));
      expect(recallTrace.netPatientExposureUnits, equals(80));
      expect(recallTrace.affectedInvoicesCount, equals(2));
      expect(recallTrace.affectedCustomers.length, equals(2));
      expect(recallTrace.affectedCustomers[0].customerName, equals('Rahim Ahmed'));
      expect(recallTrace.affectedCustomers[1].customerName, equals('Nasima Begum'));
    });

    test('4. Aggregates profit analytics across multiple allocations', () {
      final analytics = MobileSaleLotAllocationClient.computeProfitAnalytics([alloc1, alloc2]);

      expect(analytics.totalRevenue, equals(210.00));
      expect(analytics.totalCogs, equals(144.00));
      expect(analytics.grossProfit, equals(66.00));
      expect(analytics.profitMarginPct, equals(31.43));
      expect(analytics.totalUnitsSold, equals(70));
      expect(analytics.allocationsCount, equals(2));
    });
  });
}

