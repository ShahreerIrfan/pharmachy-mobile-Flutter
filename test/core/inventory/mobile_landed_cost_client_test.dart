import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/inventory/mobile_landed_cost_client.dart';

void main() {
  group('MobileLandedCostClient Tests (P176)', () {
    late Map<String, MobileLandedCostExpense> sharedStore;
    late MobileLandedCostClient managerClient;
    late MobileLandedCostClient cashierClient;
    late List<MobileCostLotInput> sampleLots;

    setUp(() {
      sharedStore = <String, MobileLandedCostExpense>{};

      managerClient = MobileLandedCostClient(
        tenantId: 'tenant-dhaka',
        branchId: 'branch-banani',
        userRole: 'STORE_MANAGER',
        userId: 'mgr_001',
        sharedStore: sharedStore,
      );

      cashierClient = MobileLandedCostClient(
        tenantId: 'tenant-dhaka',
        branchId: 'branch-banani',
        userRole: 'CASHIER',
        userId: 'csh_001',
        sharedStore: sharedStore,
      );

      sampleLots = [
        const MobileCostLotInput(
          costLotId: 'lot-001',
          batchId: 'bat-001',
          productId: 'prod-001',
          productName: 'Paracetamol 500mg',
          basePurchaseUnitCost: 10.0,
          initialQuantity: 100,
        ),
        const MobileCostLotInput(
          costLotId: 'lot-002',
          batchId: 'bat-002',
          productId: 'prod-002',
          productName: 'Amoxicillin 250mg',
          basePurchaseUnitCost: 15.0,
          initialQuantity: 200,
        ),
        const MobileCostLotInput(
          costLotId: 'lot-003',
          batchId: 'bat-003',
          productId: 'prod-003',
          productName: 'Omeprazole 20mg',
          basePurchaseUnitCost: 20.0,
          initialQuantity: 50,
        ),
      ];
    });

    test('Test 1: Pro-rata by value allocation preserves exact penny conservation without drift', () {
      const totalExpense = 750.35; // Odd amount testing penny conservation

      final result = managerClient.previewAllocations(
        totalExpense,
        MobileAllocationMethod.byValue,
        sampleLots,
      );

      expect(result.success, isTrue);
      expect(result.data, isNotNull);
      expect(result.data!.length, equals(3));

      var sumAllocated = 0.0;
      for (final line in result.data!) {
        sumAllocated += line.allocatedExpenseAmount;
        expect(line.landedUnitCost > line.basePurchaseUnitCost, isTrue);
      }

      // Conservation invariant: sum of line allocations equals total down to 4 decimals
      expect(sumAllocated.toStringAsFixed(4), equals(totalExpense.toStringAsFixed(4)));
    });

    test('Test 2: Pro-rata by quantity allocation distributes based on base units', () {
      const totalExpense = 350.0; // 350 total units -> Exactly 1.00 BDT per unit

      final result = managerClient.previewAllocations(
        totalExpense,
        MobileAllocationMethod.byQuantity,
        sampleLots,
      );

      expect(result.success, isTrue);
      final lines = result.data!;
      expect(lines.length, equals(3));

      expect(lines[0].allocatedExpenseAmount, closeTo(100.0, 0.0001));
      expect(lines[1].allocatedExpenseAmount, closeTo(200.0, 0.0001));
      expect(lines[2].allocatedExpenseAmount, closeTo(50.0, 0.0001));

      expect(lines[0].landedUnitCost, closeTo(11.0, 0.0001));
      expect(lines[1].landedUnitCost, closeTo(16.0, 0.0001));
      expect(lines[2].landedUnitCost, closeTo(21.0, 0.0001));
    });

    test('Test 3: Store manager successfully posts landed cost expense and capitalizes lots', () {
      const freightAmount = 500.0;

      final postResult = managerClient.createAndPostLandedCost(
        grnId: 'grn-2026-001',
        expenseType: MobileExpenseType.transportFreight,
        allocationMethod: MobileAllocationMethod.byValue,
        totalExpenseBdt: freightAmount,
        invoiceOrReference: 'TRUCK-INV-9988',
        carrierOrVendor: 'Sundarban Courier',
        notes: 'Transport for cold chain and general medicines',
        lots: sampleLots,
      );

      expect(postResult.success, isTrue);
      expect(postResult.data, isNotNull);
      expect(postResult.data!.status, equals(MobileLandedCostStatus.posted));
      expect(postResult.data!.lines.length, equals(3));
      expect(postResult.data!.carrierOrVendor, equals('Sundarban Courier'));

      final listResult = managerClient.listExpenses();
      expect(listResult.success, isTrue);
      expect(listResult.data!.length, equals(1));
    });

    test('Test 4: Cashier permission is denied, and manager can reverse posted landed cost', () {
      final cashierPost = cashierClient.createAndPostLandedCost(
        grnId: 'grn-2026-002',
        expenseType: MobileExpenseType.handlingLabor,
        allocationMethod: MobileAllocationMethod.byValue,
        totalExpenseBdt: 200.0,
        invoiceOrReference: 'LABOR-01',
        carrierOrVendor: 'Local Labor',
        notes: 'Unloading charges',
        lots: sampleLots,
      );
      expect(cashierPost.success, isFalse);
      expect(cashierPost.errorCode, equals('ERR_PERMISSION_DENIED'));

      final mgrPost = managerClient.createAndPostLandedCost(
        grnId: 'grn-2026-002',
        expenseType: MobileExpenseType.handlingLabor,
        allocationMethod: MobileAllocationMethod.byValue,
        totalExpenseBdt: 200.0,
        invoiceOrReference: 'LABOR-01',
        carrierOrVendor: 'Local Labor',
        notes: 'Unloading charges',
        lots: sampleLots,
      );
      expect(mgrPost.success, isTrue);
      final expenseId = mgrPost.data!.expenseId;

      final cashierRev = cashierClient.reverseLandedCost(
        expenseId: expenseId,
        reason: 'Mistaken entry',
      );
      expect(cashierRev.success, isFalse);
      expect(cashierRev.errorCode, equals('ERR_PERMISSION_DENIED'));

      final mgrRev = managerClient.reverseLandedCost(
        expenseId: expenseId,
        reason: 'Supplier reimbursed the handling charge',
      );
      expect(mgrRev.success, isTrue);
      expect(mgrRev.data!.status, equals(MobileLandedCostStatus.reversed));
      expect(mgrRev.data!.reversalReason, equals('Supplier reimbursed the handling charge'));

      final doubleRev = managerClient.reverseLandedCost(
        expenseId: expenseId,
        reason: 'Second reversal attempt',
      );
      expect(doubleRev.success, isFalse);
      expect(doubleRev.errorCode, equals('ERR_ALREADY_REVERSED'));
    });
  });
}
