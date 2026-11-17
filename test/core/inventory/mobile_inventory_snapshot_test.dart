import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/inventory/mobile_inventory_snapshot_client.dart';

void main() {
  group('P215: MobileInventorySnapshotClient Tests', () {
    late MobileInventorySnapshotClient client;

    setUp(() {
      client = MobileInventorySnapshotClient();
    });

    test('1. Generates snapshot checkpoint and validates mathematical reconciliation', () {
      final line1 = MobileSnapshotLineItem(
        productId: 'prod-ins-01',
        productName: 'Mixtard 30 100IU',
        batchNumber: 'MIX-001',
        quantityBaseUnits: 40,
        unitCost: 420.0,
        isColdChain: true,
        ledgerDeltaSum: 40,
      );

      final line2 = MobileSnapshotLineItem(
        productId: 'prod-napa-01',
        productName: 'Napa Extend 665mg',
        batchNumber: 'NAP-002',
        quantityBaseUnits: 150,
        unitCost: 2.0,
        isColdChain: false,
        ledgerDeltaSum: 150,
      );

      final snapshot = client.generateSnapshot(
        userRole: 'PHARMACY_OWNER',
        tenantId: 'ten-united',
        branchId: 'br-main',
        checkpointType: MobileSnapshotCheckpointType.dailyEod,
        lines: [line1, line2],
        ledgerEntriesCount: 12,
      );

      expect(snapshot.totalProducts, 2);
      expect(snapshot.totalBatches, 2);
      expect(snapshot.totalQuantity, 190);
      expect(snapshot.totalValuation, 420.0 * 40 + 2.0 * 150);
      expect(snapshot.isReconciled, isTrue);
      expect(snapshot.sha256Checksum, isNotEmpty);
      expect(client.verifyIntegrity(snapshot), isTrue);
    });

    test('2. Fails cryptographic integrity if line items are tampered with', () {
      final line1 = MobileSnapshotLineItem(
        productId: 'prod-001',
        productName: 'Test Item',
        batchNumber: 'BAT-01',
        quantityBaseUnits: 50,
        unitCost: 10.0,
        ledgerDeltaSum: 50,
      );

      final snapshot = client.generateSnapshot(
        userRole: 'BRANCH_MANAGER',
        tenantId: 'ten-01',
        branchId: 'br-01',
        checkpointType: MobileSnapshotCheckpointType.cycleCount,
        lines: [line1],
        ledgerEntriesCount: 5,
      );

      expect(client.verifyIntegrity(snapshot), isTrue);

      // Create tampered checkpoint with forged quantity in line item
      final tamperedLine = MobileSnapshotLineItem(
        productId: 'prod-001',
        productName: 'Test Item',
        batchNumber: 'BAT-01',
        quantityBaseUnits: 999, // tampered
        unitCost: 10.0,
        ledgerDeltaSum: 50,
      );

      final tamperedSnapshot = MobileSnapshotCheckpoint(
        snapshotId: snapshot.snapshotId,
        tenantId: snapshot.tenantId,
        branchId: snapshot.branchId,
        checkpointType: snapshot.checkpointType,
        asOfTimestamp: snapshot.asOfTimestamp,
        totalProducts: snapshot.totalProducts,
        totalBatches: snapshot.totalBatches,
        totalQuantity: 999,
        totalValuation: 9990.0,
        ledgerEntriesCount: snapshot.ledgerEntriesCount,
        sha256Checksum: snapshot.sha256Checksum, // old hash
        isReconciled: snapshot.isReconciled,
        lineItems: [tamperedLine],
      );

      expect(client.verifyIntegrity(tamperedSnapshot), isFalse);
    });

    test('3. Denies CASHIER role with StateError', () {
      expect(
        () => client.generateSnapshot(
          userRole: 'CASHIER',
          tenantId: 'ten-01',
          branchId: 'br-01',
          checkpointType: MobileSnapshotCheckpointType.dailyEod,
          lines: [],
          ledgerEntriesCount: 0,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('4. Correctly flags reconciliation discrepancy when ledger sum mismatch occurs', () {
      final discrepantLine = MobileSnapshotLineItem(
        productId: 'prod-disc',
        productName: 'Discrepant Medicine',
        batchNumber: 'DISC-01',
        quantityBaseUnits: 50,
        unitCost: 10.0,
        ledgerDeltaSum: 40, // Discrepancy of 10
      );

      expect(discrepantLine.discrepancy, 10);

      final snapshot = client.generateSnapshot(
        userRole: 'STAFF_PHARMACIST',
        tenantId: 'ten-01',
        branchId: 'br-01',
        checkpointType: MobileSnapshotCheckpointType.cycleCount,
        lines: [discrepantLine],
        ledgerEntriesCount: 4,
      );

      expect(snapshot.isReconciled, isFalse);
    });
  });
}
