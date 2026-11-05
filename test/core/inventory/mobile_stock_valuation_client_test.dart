import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/inventory/mobile_stock_valuation_client.dart';

void main() {
  group('MobileStockValuationClient Tests (P179)', () {
    late MobileStockValuationClient managerClient;
    late MobileStockValuationClient cashierClient;
    late List<MobileCostLotItem> testLots;
    late List<MobileSaleAllocationItem> testAllocations;
    final today = DateTime.now();

    setUp(() {
      managerClient = MobileStockValuationClient(
        tenantId: 'tenant-dhaka',
        branchId: 'branch-banani',
        userRole: 'BRANCH_MANAGER',
        userId: 'mgr_001',
      );

      cashierClient = MobileStockValuationClient(
        tenantId: 'tenant-dhaka',
        branchId: 'branch-banani',
        userRole: 'CASHIER',
        userId: 'csh_001',
      );

      testLots = [
        MobileCostLotItem(
          lotId: 'lot-01',
          tenantId: 'tenant-dhaka',
          branchId: 'branch-banani',
          productId: 'prod-napa',
          brandName: 'Napa Extra 500mg',
          genericName: 'Paracetamol',
          dosageForm: 'Tablet',
          purchaseDate: today.subtract(const Duration(days: 10)),
          remainingQuantity: 100,
          unitCost: 2.0,
          mrpUnit: 3.0,
        ),
        MobileCostLotItem(
          lotId: 'lot-02',
          tenantId: 'tenant-dhaka',
          branchId: 'branch-banani',
          productId: 'prod-napa',
          brandName: 'Napa Extra 500mg',
          genericName: 'Paracetamol',
          dosageForm: 'Tablet',
          purchaseDate: today.subtract(const Duration(days: 45)),
          remainingQuantity: 50,
          unitCost: 2.2,
          mrpUnit: 3.0,
        ),
        MobileCostLotItem(
          lotId: 'lot-03',
          tenantId: 'tenant-dhaka',
          branchId: 'branch-banani',
          productId: 'prod-seclo',
          brandName: 'Seclo 20mg',
          genericName: 'Omeprazole',
          dosageForm: 'Capsule',
          purchaseDate: today.subtract(const Duration(days: 100)),
          remainingQuantity: 40,
          unitCost: 5.0,
          mrpUnit: 7.0,
        ),
      ];

      testAllocations = [
        MobileSaleAllocationItem(
          allocationId: 'alloc-01',
          tenantId: 'tenant-dhaka',
          branchId: 'branch-banani',
          productId: 'prod-napa',
          saleDate: today.subtract(const Duration(days: 2)),
          quantityBaseUnits: 20,
          totalSellingPrice: 60.0,
          totalCost: 40.0,
          grossProfit: 20.0,
        ),
      ];
    });

    test('Test 1: Manager calculates valid FIFO actual valuation, MRP retail valuation, and aging buckets', () {
      final res = managerClient.calculateValuation(
        costLots: testLots,
        allocations: testAllocations,
        asOfDate: today,
        costingMethod: 'FIFO_ACTUAL',
      );

      expect(res.success, isTrue);
      expect(res.data, isNotNull);

      final data = res.data!;
      expect(data.totalQuantityBaseUnits, equals(190));
      expect(data.totalProductsCount, equals(2));

      // Cost Valuation: 100*2 + 50*2.2 + 40*5 = 200 + 110 + 200 = 510.0
      expect(data.totalCostValuationBdt, closeTo(510.0, 0.001));

      // Retail Valuation: 150*3 + 40*7 = 450 + 280 = 730.0
      expect(data.totalRetailValuationBdt, closeTo(730.0, 0.001));

      // Potential Margin = 730 - 510 = 220.0
      expect(data.potentialGrossMarginBdt, closeTo(220.0, 0.001));
      expect(data.potentialMarginPct, closeTo(30.14, 0.01));

      // Aging Buckets:
      expect(data.agingSummary['days_0_to_30']!.quantityBaseUnits, equals(100));
      expect(data.agingSummary['days_0_to_30']!.costValuationBdt, closeTo(200.0, 0.001));

      expect(data.agingSummary['days_31_to_60']!.quantityBaseUnits, equals(50));
      expect(data.agingSummary['days_31_to_60']!.costValuationBdt, closeTo(110.0, 0.001));

      expect(data.agingSummary['days_91_to_180']!.quantityBaseUnits, equals(40));
      expect(data.agingSummary['days_91_to_180']!.costValuationBdt, closeTo(200.0, 0.001));
    });

    test('Test 2: Realized margin is derived accurately from immutable lot allocations', () {
      final res = managerClient.calculateValuation(
        costLots: testLots,
        allocations: testAllocations,
        asOfDate: today,
      );

      expect(res.success, isTrue);
      final realized = res.data!.realizedMargin;

      expect(realized.allocationsCount, equals(1));
      expect(realized.totalRevenueBdt, closeTo(60.0, 0.001));
      expect(realized.totalCogsBdt, closeTo(40.0, 0.001));
      expect(realized.realizedGrossProfitBdt, closeTo(20.0, 0.001));
      expect(realized.realizedMarginPct, closeTo(33.33, 0.01));
    });

    test('Test 3: Cashier role is strictly denied access to valuation metrics', () {
      final res = cashierClient.calculateValuation(
        costLots: testLots,
        allocations: testAllocations,
      );

      expect(res.success, isFalse);
      expect(res.errorCode, equals('ERR_PERMISSION_DENIED'));
      expect(res.messageEn, isNotEmpty);
      expect(res.messageBn, isNotEmpty);
    });

    test('Test 4: Point-in-time valuation snapshot creation and audit persistence', () {
      final res = managerClient.createSnapshot(
        costLots: testLots,
        allocations: testAllocations,
        asOfDate: today,
        notes: 'End of month review',
      );

      expect(res.success, isTrue);
      expect(res.data, isNotNull);

      final snap = res.data!;
      expect(snap.snapshotId.startsWith('valsnap-'), isTrue);
      expect(snap.totalQuantityBaseUnits, equals(190));
      expect(snap.totalCostValuationBdt, closeTo(510.0, 0.001));
      expect(snap.totalRetailValuationBdt, closeTo(730.0, 0.001));
      expect(snap.notes, equals('End of month review'));
    });
  });
}
