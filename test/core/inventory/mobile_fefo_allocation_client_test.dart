import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/inventory/mobile_fefo_allocation_client.dart';

void main() {
  group('MobileFefoAllocationClient Tests (P169)', () {
    late DateTime today;
    late MobileBatchRecord batchExpiringSoon;
    late MobileBatchRecord batchExpiringLater;
    late MobileBatchRecord batchExpired;
    late MobileBatchRecord batchQuarantined;
    late MobileBatchRecord batchRecalled;

    setUp(() {
      today = DateTime(2026, 11, 4);

      batchExpiringSoon = MobileBatchRecord(
        batchId: 'bat-001',
        batchNumber: 'BX-2026-EARLY',
        expiryDate: today.add(const Duration(days: 30)),
        purchaseDate: today.subtract(const Duration(days: 10)),
        totalQuantityBaseUnits: 100,
        reservedQuantityBaseUnits: 0,
        costPerUnit: 1.20,
      );

      batchExpiringLater = MobileBatchRecord(
        batchId: 'bat-002',
        batchNumber: 'BX-2026-LATER',
        expiryDate: today.add(const Duration(days: 120)),
        purchaseDate: today.subtract(const Duration(days: 5)),
        totalQuantityBaseUnits: 200,
        reservedQuantityBaseUnits: 0,
        costPerUnit: 1.25,
      );

      batchExpired = MobileBatchRecord(
        batchId: 'bat-003',
        batchNumber: 'BX-2026-EXPIRED',
        expiryDate: today.subtract(const Duration(days: 2)),
        purchaseDate: today.subtract(const Duration(days: 100)),
        totalQuantityBaseUnits: 500,
        costPerUnit: 1.00,
      );

      batchQuarantined = MobileBatchRecord(
        batchId: 'bat-004',
        batchNumber: 'BX-2026-QUARANTINED',
        expiryDate: today.add(const Duration(days: 60)),
        purchaseDate: today.subtract(const Duration(days: 20)),
        totalQuantityBaseUnits: 300,
        costPerUnit: 1.10,
        isQuarantined: true,
      );

      batchRecalled = MobileBatchRecord(
        batchId: 'bat-005',
        batchNumber: 'BX-2026-RECALLED',
        expiryDate: today.add(const Duration(days: 90)),
        purchaseDate: today.subtract(const Duration(days: 15)),
        totalQuantityBaseUnits: 400,
        costPerUnit: 1.15,
        isRecalled: true,
      );
    });

    test('1. Allocates from earliest expiring batch first (FEFO principle)', () {
      final batches = [batchExpiringLater, batchExpiringSoon];

      final res = MobileFefoAllocationClient.allocateFefo(
        productId: 'prod-napa-500',
        batches: batches,
        requestedUnits: 60,
        asOfDate: today,
      );

      expect(res.isSuccessful, isTrue);
      expect(res.allocations.length, equals(1));
      expect(res.allocations[0].batchId, equals('bat-001'));
      expect(res.allocations[0].allocatedUnits, equals(60));
      expect(res.totalCogs, closeTo(72.0, 0.001));
    });

    test('2. Splits allocation across multiple batches when first batch capacity is exceeded', () {
      final batches = [batchExpiringLater, batchExpiringSoon];

      final res = MobileFefoAllocationClient.allocateFefo(
        productId: 'prod-napa-500',
        batches: batches,
        requestedUnits: 150,
        asOfDate: today,
      );

      expect(res.isSuccessful, isTrue);
      expect(res.allocations.length, equals(2));
      expect(res.allocations[0].batchId, equals('bat-001'));
      expect(res.allocations[0].allocatedUnits, equals(100));
      expect(res.allocations[1].batchId, equals('bat-002'));
      expect(res.allocations[1].allocatedUnits, equals(50));
      expect(res.totalCogs, closeTo(182.50, 0.001));
    });

    test('3. Applies deterministic tie-breaker cascade when expiry dates are identical', () {
      final batchSameExpOlderPurchase = MobileBatchRecord(
        batchId: 'bat-tie-1',
        batchNumber: 'BX-TIE-B',
        expiryDate: today.add(const Duration(days: 60)),
        purchaseDate: today.subtract(const Duration(days: 20)), // Older
        totalQuantityBaseUnits: 50,
        costPerUnit: 1.20,
      );

      final batchSameExpNewerPurchase = MobileBatchRecord(
        batchId: 'bat-tie-2',
        batchNumber: 'BX-TIE-A',
        expiryDate: today.add(const Duration(days: 60)),
        purchaseDate: today.subtract(const Duration(days: 5)), // Newer
        totalQuantityBaseUnits: 50,
        costPerUnit: 1.20,
      );

      final batches = [batchSameExpNewerPurchase, batchSameExpOlderPurchase];

      final res = MobileFefoAllocationClient.allocateFefo(
        productId: 'prod-napa-500',
        batches: batches,
        requestedUnits: 30,
        asOfDate: today,
      );

      expect(res.isSuccessful, isTrue);
      expect(res.allocations.length, equals(1));
      // FIFO tie-breaker: older purchase date picked first
      expect(res.allocations[0].batchId, equals('bat-tie-1'));
    });

    test('4. Strictly excludes expired, quarantined, and recalled batches', () {
      final batches = [batchExpired, batchQuarantined, batchRecalled];

      final res = MobileFefoAllocationClient.allocateFefo(
        productId: 'prod-napa-500',
        batches: batches,
        requestedUnits: 10,
        asOfDate: today,
      );

      expect(res.isSuccessful, isFalse);
      expect(res.errorCode, equals('ERR_NO_ELIGIBLE_BATCHES'));
      expect(res.allocations.isEmpty, isTrue);
    });

    test('5. Active reservations reduce available stock and prevent overselling', () {
      batchExpiringSoon.reservedQuantityBaseUnits = 80;
      expect(batchExpiringSoon.availableQuantity, equals(20));

      final batches = [batchExpiringSoon];

      final res = MobileFefoAllocationClient.allocateFefo(
        productId: 'prod-napa-500',
        batches: batches,
        requestedUnits: 30,
        asOfDate: today,
      );

      expect(res.isSuccessful, isFalse);
      expect(res.errorCode, equals('ERR_INSUFFICIENT_STOCK'));
      expect(res.allocatedUnits, equals(20));
    });

    test('6. Atomic reservation lifecycle: reserve, commit, and release', () {
      final batches = [batchExpiringSoon];

      // 1. Allocate with reservation
      final res = MobileFefoAllocationClient.allocateFefo(
        productId: 'prod-napa-500',
        batches: batches,
        requestedUnits: 40,
        asOfDate: today,
        reserve: true,
      );

      expect(res.isSuccessful, isTrue);
      expect(batchExpiringSoon.reservedQuantityBaseUnits, equals(40));
      expect(batchExpiringSoon.availableQuantity, equals(60));
      expect(res.allocations[0].reservationId, isNotNull);

      // 2. Commit reservation on POS sale checkout
      final committed = MobileFefoAllocationClient.commitReservation(batchExpiringSoon, 40);
      expect(committed, isTrue);
      expect(batchExpiringSoon.totalQuantityBaseUnits, equals(60));
      expect(batchExpiringSoon.reservedQuantityBaseUnits, equals(0));
      expect(batchExpiringSoon.availableQuantity, equals(60));

      // 3. New reservation and release
      MobileFefoAllocationClient.allocateFefo(
        productId: 'prod-napa-500',
        batches: batches,
        requestedUnits: 20,
        asOfDate: today,
        reserve: true,
      );
      expect(batchExpiringSoon.reservedQuantityBaseUnits, equals(20));

      final released = MobileFefoAllocationClient.releaseReservation(batchExpiringSoon, 20);
      expect(released, isTrue);
      expect(batchExpiringSoon.reservedQuantityBaseUnits, equals(0));
      expect(batchExpiringSoon.availableQuantity, equals(60));
    });
  });
}

