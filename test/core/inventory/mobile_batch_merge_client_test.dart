import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/inventory/mobile_batch_merge_client.dart';

void main() {
  group('MobileBatchMergeClient Tests (P178)', () {
    late Map<String, MobileBatchMergeRecord> sharedStore;
    late MobileBatchMergeClient managerClient;
    late MobileBatchMergeClient cashierClient;

    late MobileBatchItem sourceTwin;
    late MobileBatchItem targetTwin;

    setUp(() {
      sharedStore = <String, MobileBatchMergeRecord>{};

      managerClient = MobileBatchMergeClient(
        tenantId: 'tenant-dhaka',
        branchId: 'branch-banani',
        userRole: 'BRANCH_MANAGER',
        userId: 'mgr_001',
        sharedStore: sharedStore,
      );

      cashierClient = MobileBatchMergeClient(
        tenantId: 'tenant-dhaka',
        branchId: 'branch-banani',
        userRole: 'CASHIER',
        userId: 'csh_001',
        sharedStore: sharedStore,
      );

      final commonExpiry = DateTime.now().add(const Duration(days: 365));

      // Source: 40 units @ 10.00 BDT
      sourceTwin = MobileBatchItem(
        batchId: 'bat-src-01',
        tenantId: 'tenant-dhaka',
        branchId: 'branch-banani',
        productId: 'prod-napa',
        productName: 'Napa Extra 500mg',
        batchNumber: 'BN-2026-X',
        expiryDate: commonExpiry,
        quantityBaseUnits: 40,
        costPerUnit: 10.0,
      );

      // Target: 60 units @ 12.00 BDT
      // Weighted cost = (40*10 + 60*12) / 100 = 11.2000 BDT
      targetTwin = MobileBatchItem(
        batchId: 'bat-tgt-01',
        tenantId: 'tenant-dhaka',
        branchId: 'branch-banani',
        productId: 'prod-napa',
        productName: 'Napa Extra 500mg',
        batchNumber: 'BN-2026-X',
        expiryDate: commonExpiry,
        quantityBaseUnits: 60,
        costPerUnit: 12.0,
      );
    });

    test('Test 1: Safe batch merge succeeds for identical manufacturer lot & expiry with weighted cost', () {
      final preFlight = managerClient.validateMergeCompatibility(sourceTwin, targetTwin);
      expect(preFlight.canMerge, isTrue);
      expect(preFlight.blockers.isEmpty, isTrue);
      expect(preFlight.projectedTargetQuantity, equals(100));
      expect(preFlight.projectedTargetCostPerUnit, closeTo(11.20, 0.0001));

      final res = managerClient.executeMerge(
        source: sourceTwin,
        target: targetTwin,
        reason: 'Consolidating split delivery invoice shipments',
      );

      expect(res.success, isTrue);
      expect(res.data, isNotNull);
      expect(res.data!.mergedQuantityBaseUnits, equals(40));
      expect(res.data!.targetCostPerUnitAfter, closeTo(11.20, 0.0001));

      expect(targetTwin.quantityBaseUnits, equals(100));
      expect(targetTwin.costPerUnit, closeTo(11.20, 0.0001));
      expect(sourceTwin.quantityBaseUnits, equals(0));
      expect(sourceTwin.status, equals('DEPLETED'));
    });

    test('Test 2: Mismatched manufacturer batch reference is strictly blocked from merging', () {
      final diffLotSource = MobileBatchItem(
        batchId: 'bat-diff-01',
        tenantId: 'tenant-dhaka',
        branchId: 'branch-banani',
        productId: 'prod-napa',
        productName: 'Napa Extra 500mg',
        batchNumber: 'BN-2026-Y', // Different manufacturer batch number!
        expiryDate: sourceTwin.expiryDate,
        quantityBaseUnits: 40,
        costPerUnit: 10.0,
      );

      final preFlight = managerClient.validateMergeCompatibility(diffLotSource, targetTwin);
      expect(preFlight.canMerge, isFalse);
      expect(preFlight.blockers.contains('ERR_MANUFACTURER_BATCH_MISMATCH'), isTrue);

      final execRes = managerClient.executeMerge(
        source: diffLotSource,
        target: targetTwin,
        reason: 'Attempting invalid lot merge',
      );
      expect(execRes.success, isFalse);
      expect(execRes.errorCode, equals('ERR_MANUFACTURER_BATCH_MISMATCH'));
    });

    test('Test 3: Mismatched expiry dates corrupt FEFO and are strictly blocked', () {
      final diffExpirySource = MobileBatchItem(
        batchId: 'bat-diff-exp',
        tenantId: 'tenant-dhaka',
        branchId: 'branch-banani',
        productId: 'prod-napa',
        productName: 'Napa Extra 500mg',
        batchNumber: 'BN-2026-X',
        expiryDate: sourceTwin.expiryDate.subtract(const Duration(days: 60)), // 2 months earlier!
        quantityBaseUnits: 40,
        costPerUnit: 10.0,
      );

      final preFlight = managerClient.validateMergeCompatibility(diffExpirySource, targetTwin);
      expect(preFlight.canMerge, isFalse);
      expect(preFlight.blockers.contains('ERR_EXPIRY_DATE_MISMATCH'), isTrue);

      final execRes = managerClient.executeMerge(
        source: diffExpirySource,
        target: targetTwin,
        reason: 'Attempting differing expiry merge',
      );
      expect(execRes.success, isFalse);
      expect(execRes.errorCode, equals('ERR_EXPIRY_DATE_MISMATCH'));
    });

    test('Test 4: Recalled/quarantined batches are blocked, cashier is denied, and manager can reverse', () {
      sourceTwin.status = 'RECALLED';
      final recalledRes = managerClient.executeMerge(
        source: sourceTwin,
        target: targetTwin,
        reason: 'Merging recalled stock',
      );
      expect(recalledRes.success, isFalse);
      expect(recalledRes.errorCode, equals('ERR_BATCH_RECALLED'));
      sourceTwin.status = 'ACTIVE';

      // Cashier role denied
      final cashierRes = cashierClient.executeMerge(
        source: sourceTwin,
        target: targetTwin,
        reason: 'Cashier consolidation',
      );
      expect(cashierRes.success, isFalse);
      expect(cashierRes.errorCode, equals('ERR_PERMISSION_DENIED'));

      // Valid merge
      final validMerge = managerClient.executeMerge(
        source: sourceTwin,
        target: targetTwin,
        reason: 'Valid shipment consolidation',
      );
      expect(validMerge.success, isTrue);
      final mergeId = validMerge.data!.mergeId;

      // Reversal
      final revRes = managerClient.reverseMerge(
        mergeId: mergeId,
        source: sourceTwin,
        target: targetTwin,
        reason: 'Accidental merge consolidation',
      );
      expect(revRes.success, isTrue);
      expect(revRes.data!.isReversed, isTrue);

      expect(sourceTwin.quantityBaseUnits, equals(40));
      expect(sourceTwin.status, equals('ACTIVE'));
      expect(targetTwin.quantityBaseUnits, equals(60));
      expect(targetTwin.costPerUnit, closeTo(12.0, 0.0001));

      // Double reversal blocked
      final doubleRev = managerClient.reverseMerge(
        mergeId: mergeId,
        source: sourceTwin,
        target: targetTwin,
        reason: 'Second reversal',
      );
      expect(doubleRev.success, isFalse);
      expect(doubleRev.errorCode, equals('ERR_ALREADY_REVERSED'));
    });
  });
}

