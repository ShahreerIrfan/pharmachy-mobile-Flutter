import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/inventory/mobile_batch_receipt_linking_client.dart';

void main() {
  group('MobileBatchReceiptLinkingClient Tests (P168)', () {
    late MobileGrnNote testGrn;
    late MobileGrnLine line1;

    setUp(() {
      line1 = MobileGrnLine(
        lineId: 'line-001',
        productId: 'prod-napa-500',
        productBrandName: 'Napa 500mg Tablet',
        orderedQuantityBaseUnits: 500,
        receivedQuantityBaseUnits: 500,
        unitCost: 1.20,
      );

      testGrn = MobileGrnNote(
        grnId: 'grn-001',
        grnNumber: 'GRN-2026-001',
        tenantId: 'tenant-test',
        branchId: 'branch-dhanmondi',
        supplierId: 'supp-beximco',
        supplierName: 'Beximco Pharmaceuticals Ltd.',
        receiptDate: DateTime(2026, 11, 4),
        status: 'RECEIVED',
        lines: [line1],
      );
    });

    test('1. Successfully binds multiple distinct batches to a single GRN line item', () {
      final alloc1 = MobileBatchAllocation(
        linkId: 'link-001',
        batchId: 'batch-001',
        batchNumber: 'BX-2026-A',
        quantityBaseUnits: 300,
        unitCost: 1.20,
      );
      final alloc2 = MobileBatchAllocation(
        linkId: 'link-002',
        batchId: 'batch-002',
        batchNumber: 'BX-2026-B',
        quantityBaseUnits: 200,
        unitCost: 1.20,
      );

      final added1 = MobileBatchReceiptLinkingClient.addBatchAllocationToLine(line1, alloc1);
      final added2 = MobileBatchReceiptLinkingClient.addBatchAllocationToLine(line1, alloc2);

      expect(added1, isTrue);
      expect(added2, isTrue);
      expect(line1.allocations.length, equals(2));
      expect(line1.allocatedQuantity, equals(500));
      expect(line1.isFullyAllocated, isTrue);
    });

    test('2. Rejects allocation when total allocated units exceed line received quantity', () {
      final alloc1 = MobileBatchAllocation(
        linkId: 'link-001',
        batchId: 'batch-001',
        batchNumber: 'BX-2026-A',
        quantityBaseUnits: 400,
        unitCost: 1.20,
      );
      final alloc2 = MobileBatchAllocation(
        linkId: 'link-002',
        batchId: 'batch-002',
        batchNumber: 'BX-2026-B',
        quantityBaseUnits: 150, // 400 + 150 = 550 > 500
        unitCost: 1.20,
      );

      final added1 = MobileBatchReceiptLinkingClient.addBatchAllocationToLine(line1, alloc1);
      final added2 = MobileBatchReceiptLinkingClient.addBatchAllocationToLine(line1, alloc2);

      expect(added1, isTrue);
      expect(added2, isFalse);
      expect(line1.allocatedQuantity, equals(400));
      expect(line1.isFullyAllocated, isFalse);
    });

    test('3. Blocks posting when one or more lines are not fully allocated', () {
      final alloc1 = MobileBatchAllocation(
        linkId: 'link-001',
        batchId: 'batch-001',
        batchNumber: 'BX-2026-A',
        quantityBaseUnits: 300, // 300 < 500
        unitCost: 1.20,
      );
      MobileBatchReceiptLinkingClient.addBatchAllocationToLine(line1, alloc1);

      final stockMap = <String, int>{'batch-001': 0};
      final result = MobileBatchReceiptLinkingClient.postGrn(testGrn, stockMap);

      expect(result.isSuccessful, isFalse);
      expect(result.errorCode, equals('ERR_ALLOCATION_MISMATCH'));
      expect(testGrn.isPosted, isFalse);
      expect(stockMap['batch-001'], equals(0));
    });

    test('4. Posts GRN and increments batch stock exactly once across all allocations', () {
      MobileBatchReceiptLinkingClient.addBatchAllocationToLine(
        line1,
        MobileBatchAllocation(
          linkId: 'link-001',
          batchId: 'batch-001',
          batchNumber: 'BX-2026-A',
          quantityBaseUnits: 300,
          unitCost: 1.20,
        ),
      );
      MobileBatchReceiptLinkingClient.addBatchAllocationToLine(
        line1,
        MobileBatchAllocation(
          linkId: 'link-002',
          batchId: 'batch-002',
          batchNumber: 'BX-2026-B',
          quantityBaseUnits: 200,
          unitCost: 1.20,
        ),
      );

      final stockMap = <String, int>{'batch-001': 50, 'batch-002': 100};
      final result = MobileBatchReceiptLinkingClient.postGrn(testGrn, stockMap);

      expect(result.isSuccessful, isTrue);
      expect(result.postedAllocationsCount, equals(2));
      expect(result.totalQuantityIncremented, equals(500));
      expect(testGrn.isPosted, isTrue);
      expect(stockMap['batch-001'], equals(350));
      expect(stockMap['batch-002'], equals(300));
      expect(line1.allocations.every((a) => a.isPosted), isTrue);
    });

    test('5. Blocks duplicate posting and prevents duplicate stock increments', () {
      MobileBatchReceiptLinkingClient.addBatchAllocationToLine(
        line1,
        MobileBatchAllocation(
          linkId: 'link-001',
          batchId: 'batch-001',
          batchNumber: 'BX-2026-A',
          quantityBaseUnits: 500,
          unitCost: 1.20,
        ),
      );

      final stockMap = <String, int>{'batch-001': 0};
      final post1 = MobileBatchReceiptLinkingClient.postGrn(testGrn, stockMap);
      expect(post1.isSuccessful, isTrue);
      expect(stockMap['batch-001'], equals(500));

      // Attempt second post on already posted GRN
      final post2 = MobileBatchReceiptLinkingClient.postGrn(testGrn, stockMap);
      expect(post2.isSuccessful, isFalse);
      expect(post2.errorCode, equals('ERR_ALREADY_POSTED'));
      // Stock remains exactly 500, never doubled
      expect(stockMap['batch-001'], equals(500));
    });

    test('6. Successfully reverses posted GRN and deducts inventory', () {
      MobileBatchReceiptLinkingClient.addBatchAllocationToLine(
        line1,
        MobileBatchAllocation(
          linkId: 'link-001',
          batchId: 'batch-001',
          batchNumber: 'BX-2026-A',
          quantityBaseUnits: 500,
          unitCost: 1.20,
        ),
      );

      final stockMap = <String, int>{'batch-001': 0};
      MobileBatchReceiptLinkingClient.postGrn(testGrn, stockMap);
      expect(stockMap['batch-001'], equals(500));

      final reversal = MobileBatchReceiptLinkingClient.reverseGrn(testGrn, stockMap);
      expect(reversal.isSuccessful, isTrue);
      expect(reversal.totalQuantityDecremented, equals(500));
      expect(stockMap['batch-001'], equals(0));
      expect(testGrn.status, equals('REVERSED'));
    });

    test('7. Blocks reversal if stock from this GRN has already been consumed / dispensed', () {
      MobileBatchReceiptLinkingClient.addBatchAllocationToLine(
        line1,
        MobileBatchAllocation(
          linkId: 'link-001',
          batchId: 'batch-001',
          batchNumber: 'BX-2026-A',
          quantityBaseUnits: 500,
          unitCost: 1.20,
        ),
      );

      final stockMap = <String, int>{'batch-001': 0};
      MobileBatchReceiptLinkingClient.postGrn(testGrn, stockMap);

      // Simulate partial sales/consumption: stock drops from 500 to 200
      stockMap['batch-001'] = 200;

      final reversal = MobileBatchReceiptLinkingClient.reverseGrn(testGrn, stockMap);
      expect(reversal.isSuccessful, isFalse);
      expect(reversal.errorCode, equals('ERR_CANNOT_REVERSE_CONSUMED_STOCK'));
      expect(testGrn.status, equals('POSTED'));
      expect(stockMap['batch-001'], equals(200));
    });
  });
}
