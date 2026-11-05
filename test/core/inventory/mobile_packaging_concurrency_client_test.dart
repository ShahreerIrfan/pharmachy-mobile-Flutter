import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/inventory/mobile_packaging_concurrency_client.dart';

void main() {
  group('MobilePackagingConcurrencyClient Tests (P180)', () {
    late MobilePackagingConcurrencyClient managerClient;
    late MobilePackagingConcurrencyClient cashierClient;
    late List<MobileBatchStockItem> testBatches;
    final today = DateTime.now();

    setUp(() {
      managerClient = MobilePackagingConcurrencyClient(
        tenantId: 'tenant-dhaka',
        branchId: 'branch-banani',
        userRole: 'BRANCH_MANAGER',
        userId: 'mgr_001',
      );

      cashierClient = MobilePackagingConcurrencyClient(
        tenantId: 'tenant-dhaka',
        branchId: 'branch-banani',
        userRole: 'CASHIER',
        userId: 'csh_001',
      );

      testBatches = [
        MobileBatchStockItem(
          batchId: 'bat-01',
          batchNumber: 'BN-NAPA-EARLY',
          expiryDate: today.add(const Duration(days: 60)), // 2 months
          purchaseDate: today.subtract(const Duration(days: 30)),
          quantityBaseUnits: 40,
          reservedQuantityBaseUnits: 0,
          costPerUnit: 2.0,
        ),
        MobileBatchStockItem(
          batchId: 'bat-02',
          batchNumber: 'BN-NAPA-LATE',
          expiryDate: today.add(const Duration(days: 365)), // 12 months
          purchaseDate: today.subtract(const Duration(days: 10)),
          quantityBaseUnits: 60,
          reservedQuantityBaseUnits: 0,
          costPerUnit: 2.2,
        ),
      ];
    });

    test('Test 1: Multi-threaded concurrent checkouts enforce exact stock conservation and zero overselling', () {
      // Total stock = 100 units. 20 checkouts @ 4 units = 80 units
      final res = managerClient.runConcurrentCheckoutSimulation(
        candidateBatches: testBatches,
        productId: 'prod-napa',
        concurrencyLevel: 10,
        requestsPerThread: 2,
        unitsPerRequest: 4,
      );

      expect(res.success, isTrue);
      expect(res.data, isNotNull);

      final audit = res.data!;
      expect(audit.totalRequests, equals(20));
      expect(audit.successfulTransactions, equals(20));
      expect(audit.rejectedOversells, equals(0));
      expect(audit.initialStockBaseUnits, equals(100));
      expect(audit.finalStockBaseUnits, equals(20));
      expect(audit.totalAllocatedBaseUnits, equals(80));
      expect(audit.stockConserved, isTrue);
      expect(audit.fefoOrderVerified, isTrue);
      expect(audit.integerUnitsVerified, isTrue);
    });

    test('Test 2: Excess demand under high concurrency cleanly rejects oversells while preserving stock conservation', () {
      // Total stock = 100 units. 30 checkouts @ 5 units = 150 units demanded (exceeds 100)
      final res = managerClient.runConcurrentCheckoutSimulation(
        candidateBatches: testBatches,
        productId: 'prod-napa',
        concurrencyLevel: 15,
        requestsPerThread: 2,
        unitsPerRequest: 5,
      );

      expect(res.success, isTrue);
      final audit = res.data!;

      expect(audit.totalRequests, equals(30));
      expect(audit.successfulTransactions, equals(20)); // 20 * 5 = 100
      expect(audit.rejectedOversells, equals(10));
      expect(audit.initialStockBaseUnits, equals(100));
      expect(audit.finalStockBaseUnits, equals(0));
      expect(audit.totalAllocatedBaseUnits, equals(100));
      expect(audit.stockConserved, isTrue);
    });

    test('Test 3: FEFO batch consumption strictly depletes earlier expiry first under concurrent checkout', () {
      final res = managerClient.runConcurrentCheckoutSimulation(
        candidateBatches: testBatches,
        productId: 'prod-napa',
        concurrencyLevel: 10,
        requestsPerThread: 1,
        unitsPerRequest: 4,
      );

      expect(res.success, isTrue);
      // Batch 1 (earlier expiry) should be completely depleted
      expect(testBatches[0].quantityBaseUnits, equals(0));
      // Batch 2 (later expiry) should retain all 60 units
      expect(testBatches[1].quantityBaseUnits, equals(60));
    });

    test('Test 4: Cashier role is strictly denied access to concurrency diagnostic runs', () {
      final res = cashierClient.runConcurrentCheckoutSimulation(
        candidateBatches: testBatches,
        productId: 'prod-napa',
      );

      expect(res.success, isFalse);
      expect(res.errorCode, equals('ERR_PERMISSION_DENIED'));
      expect(res.messageEn, isNotEmpty);
      expect(res.messageBn, isNotEmpty);
    });
  });
}

