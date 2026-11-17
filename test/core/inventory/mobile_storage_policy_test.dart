// test/core/inventory/mobile_storage_policy_test.dart
// Unit tests for P213: Storage policy enforcement (Flutter Mobile Manager App)

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/inventory/mobile_storage_policy_client.dart';

void main() {
  group('P213: Mobile Storage Policy Enforcement Tests', () {
    late MobileStoragePolicyClient client;
    late MobileStorageLocationInfo fridge;
    late MobileStorageLocationInfo shelf;

    setUp(() {
      client = MobileStoragePolicyClient();
      fridge = MobileStorageLocationInfo(
        locationId: 'loc-fridge-01',
        branchId: 'br-central-01',
        code: 'FRIDGE-01',
        name: 'Biologicals Refrigerator',
        locationType: MobileStorageLocationType.fridge,
        isColdCapable: true,
        minTemp: 2.0,
        maxTemp: 8.0,
      );
      shelf = MobileStorageLocationInfo(
        locationId: 'loc-shelf-01',
        branchId: 'br-central-01',
        code: 'SHELF-A',
        name: 'General Ambient Shelf',
        locationType: MobileStorageLocationType.shelf,
        isColdCapable: false,
      );
    });

    test('P213-M-1: Cold-chain medicine assigned to cold-capable fridge succeeds', () {
      final batch = MobileBatchAssignment(
        batchId: 'bat-01',
        batchNumber: 'BATCH-INS-01',
        productName: 'Insulin Glargine 100IU',
        requiresColdChain: true,
        storageLocationCode: 'UNASSIGNED',
        quantityUnits: 50,
      );

      final result = client.relocateBatch(
        userRole: 'STAFF_PHARMACIST',
        batch: batch,
        targetLocation: fridge,
      );

      expect(result.storageLocationCode, equals('FRIDGE-01'));
    });

    test('P213-M-2: Cold-chain medicine assigned to ambient shelf throws ArgumentError', () {
      final batch = MobileBatchAssignment(
        batchId: 'bat-01',
        batchNumber: 'BATCH-INS-01',
        productName: 'Insulin Glargine 100IU',
        requiresColdChain: true,
        storageLocationCode: 'FRIDGE-01',
        quantityUnits: 50,
      );

      expect(
        () => client.relocateBatch(
          userRole: 'STAFF_PHARMACIST',
          batch: batch,
          targetLocation: shelf,
        ),
        throwsArgumentError,
      );
    });

    test('P213-M-3: Policy override allowed with documented clinical justification', () {
      final batch = MobileBatchAssignment(
        batchId: 'bat-01',
        batchNumber: 'BATCH-INS-01',
        productName: 'Insulin Glargine 100IU',
        requiresColdChain: true,
        storageLocationCode: 'FRIDGE-01',
        quantityUnits: 10,
      );

      final result = client.relocateBatch(
        userRole: 'STAFF_PHARMACIST',
        batch: batch,
        targetLocation: shelf,
        overrideJustification: 'Room temperature transit approved for under 4 hours.',
      );

      expect(result.storageLocationCode, equals('SHELF-A'));
    });

    test('P213-M-4: Cashier role is strictly forbidden from relocating stock', () {
      final batch = MobileBatchAssignment(
        batchId: 'bat-01',
        batchNumber: 'BATCH-INS-01',
        productName: 'Insulin Glargine 100IU',
        requiresColdChain: true,
        storageLocationCode: 'FRIDGE-01',
        quantityUnits: 50,
      );

      expect(
        () => client.relocateBatch(
          userRole: 'CASHIER',
          batch: batch,
          targetLocation: fridge,
        ),
        throwsException,
      );
    });

    test('P213-M-5: Branch storage compliance audit correctly flags violations', () {
      final batches = [
        MobileBatchAssignment(batchId: 'b1', batchNumber: 'B-01', productName: 'Insulin', requiresColdChain: true, storageLocationCode: 'FRIDGE-01', quantityUnits: 30),
        MobileBatchAssignment(batchId: 'b2', batchNumber: 'B-02', productName: 'Paracetamol', requiresColdChain: false, storageLocationCode: 'SHELF-A', quantityUnits: 100),
        MobileBatchAssignment(batchId: 'b3', batchNumber: 'B-03', productName: 'Rabies Vaccine', requiresColdChain: true, storageLocationCode: 'SHELF-A', quantityUnits: 20), // Violation!
      ];

      final locations = {
        'FRIDGE-01': fridge,
        'SHELF-A': shelf,
      };

      final audit = client.auditBranchCompliance(batches: batches, locationsMap: locations);
      expect(audit['total_batches'], equals(3));
      expect(audit['compliant_count'], equals(2));
      expect(audit['violation_count'], equals(1));
    });
  });
}

