import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/inventory/mobile_stock_ledger_client.dart';

void main() {
  group('MobileStockLedgerClient Tests (ADR-0201 / P201)', () {
    late MobileStockLedgerClient managerClient;
    late MobileStockLedgerClient cashierClient;

    setUp(() {
      managerClient = MobileStockLedgerClient(
        tenantId: 'tenant-dhaka-01',
        branchId: 'branch-main',
        userRole: 'BRANCH_MANAGER',
        userId: 'usr-mgr-101',
      );

      cashierClient = MobileStockLedgerClient(
        tenantId: 'tenant-dhaka-01',
        branchId: 'branch-main',
        userRole: 'CASHIER',
        userId: 'usr-cashier-102',
      );
    });

    test('1. Record positive inward movement conserves balance and computes hash', () {
      final entry = managerClient.recordMovement(
        productId: 'prod-napa-500',
        productName: 'Napa Extra 500mg',
        batchNumber: 'BCH-202611-001',
        movementType: MobileStockMovementType.purchaseReceipt,
        quantityDelta: 100,
        sourceEntityType: 'GOODS_RECEIPT_NOTE',
        sourceEntityId: 'grn-001',
        sourceReference: 'GRN-202611-001',
        unitCost: 2.25,
        unitPrice: 3.50,
      );

      expect(entry.balanceBefore, equals(0));
      expect(entry.balanceAfter, equals(100));
      expect(entry.quantityDelta, equals(100));
      expect(entry.balanceAfter, equals(entry.balanceBefore + entry.quantityDelta));
      expect(entry.totalCost, equals(225.0));
      expect(entry.verificationHash.isNotEmpty, isTrue);
    });

    test('2. Outward dispense decrements balance accurately', () {
      managerClient.setInitialBatchBalance('BCH-202611-002', 60);

      final entry = managerClient.recordMovement(
        productId: 'prod-napa-500',
        productName: 'Napa Extra 500mg',
        batchNumber: 'BCH-202611-002',
        movementType: MobileStockMovementType.saleDispense,
        quantityDelta: -15,
        sourceEntityType: 'SALE_INVOICE',
        sourceEntityId: 'inv-101',
        sourceReference: 'INV-202611-0088',
        unitCost: 2.25,
        unitPrice: 3.50,
      );

      expect(entry.balanceBefore, equals(60));
      expect(entry.balanceAfter, equals(45));
      expect(entry.quantityDelta, equals(-15));
      expect(entry.balanceAfter, equals(entry.balanceBefore + entry.quantityDelta));
    });

    test('3. Zero delta throws ArgumentError', () {
      expect(
        () => managerClient.recordMovement(
          productId: 'prod-napa-500',
          productName: 'Napa Extra 500mg',
          batchNumber: 'BCH-202611-003',
          movementType: MobileStockMovementType.stockAdjustmentIn,
          quantityDelta: 0,
          sourceEntityType: 'AUDIT',
          sourceEntityId: 'aud-001',
          sourceReference: 'AUD-001',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('4. Insufficient stock reduction throws StateError', () {
      managerClient.setInitialBatchBalance('BCH-202611-004', 10);

      expect(
        () => managerClient.recordMovement(
          productId: 'prod-napa-500',
          productName: 'Napa Extra 500mg',
          batchNumber: 'BCH-202611-004',
          movementType: MobileStockMovementType.saleDispense,
          quantityDelta: -25,
          sourceEntityType: 'SALE',
          sourceEntityId: 'sale-ovf',
          sourceReference: 'SALE-OVF',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('5. Reconciliation verifies balanced ledger', () {
      managerClient.recordMovement(
        productId: 'prod-napa-500',
        productName: 'Napa Extra 500mg',
        batchNumber: 'BCH-202611-005',
        movementType: MobileStockMovementType.purchaseReceipt,
        quantityDelta: 80,
        sourceEntityType: 'GRN',
        sourceEntityId: 'grn-80',
        sourceReference: 'GRN-80',
        unitCost: 2.0,
      );

      managerClient.recordMovement(
        productId: 'prod-napa-500',
        productName: 'Napa Extra 500mg',
        batchNumber: 'BCH-202611-005',
        movementType: MobileStockMovementType.saleDispense,
        quantityDelta: -30,
        sourceEntityType: 'SALE',
        sourceEntityId: 'sale-30',
        sourceReference: 'SALE-30',
        unitCost: 2.0,
      );

      final recon = managerClient.reconcileBatch('BCH-202611-005');
      expect(recon.isBalanced, isTrue);
      expect(recon.recordedQuantity, equals(50));
      expect(recon.ledgerSum, equals(50));
      expect(recon.discrepancy, equals(0));
      expect(recon.tamperDetected, isFalse);
      expect(recon.totalEntries, equals(2));
    });

    test('6. Cashier access is denied with StateError', () {
      expect(
        () => cashierClient.recordMovement(
          productId: 'prod-napa-500',
          productName: 'Napa Extra 500mg',
          batchNumber: 'BCH-202611-006',
          movementType: MobileStockMovementType.stockAdjustmentIn,
          quantityDelta: 10,
          sourceEntityType: 'ADJ',
          sourceEntityId: 'adj-01',
          sourceReference: 'ADJ-01',
        ),
        throwsA(isA<StateError>()),
      );
    });
  });
}
