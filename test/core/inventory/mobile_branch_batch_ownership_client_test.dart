import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/inventory/mobile_branch_batch_ownership_client.dart';

void main() {
  group('P175 MobileBranchBatchOwnershipClient Tests', () {
    late Map<String, MobileBranchBatch> sharedStore;
    late MobileBranchBatchOwnershipClient cashierBranch1;
    late MobileBranchBatchOwnershipClient ownerClient;

    setUp(() {
      sharedStore = <String, MobileBranchBatch>{};

      // Batch in Branch 1 (Gulshan) - 60 units
      final b1 = MobileBranchBatch(
        batchId: 'bat-gulshan-01',
        tenantId: 'tenant-dhaka',
        branchId: 'branch-gulshan',
        branchName: 'Gulshan Branch',
        productId: 'prod-ace',
        productName: 'Ace Plus 500mg',
        batchNumber: 'BAT-2026-M1',
        quantityBaseUnits: 60,
        reservedQuantityBaseUnits: 10,
        expiryDate: DateTime.now().add(const Duration(days: 180)),
        costPerUnit: 3.00,
        isDispensable: true,
      );
      sharedStore[b1.batchId] = b1;

      // Batch in Branch 2 (Uttara) - 90 units (Same manufacturer batch, different branch)
      final b2 = MobileBranchBatch(
        batchId: 'bat-uttara-01',
        tenantId: 'tenant-dhaka',
        branchId: 'branch-uttara',
        branchName: 'Uttara Branch',
        productId: 'prod-ace',
        productName: 'Ace Plus 500mg',
        batchNumber: 'BAT-2026-M1',
        quantityBaseUnits: 90,
        reservedQuantityBaseUnits: 0,
        expiryDate: DateTime.now().add(const Duration(days: 180)),
        costPerUnit: 3.00,
        isDispensable: true,
      );
      sharedStore[b2.batchId] = b2;

      cashierBranch1 = MobileBranchBatchOwnershipClient(
        tenantId: 'tenant-dhaka',
        activeBranchId: 'branch-gulshan',
        activeBranchName: 'Gulshan Branch',
        userRole: 'CASHIER',
        username: 'cashier_gulshan',
        sharedStore: sharedStore,
      );

      ownerClient = MobileBranchBatchOwnershipClient(
        tenantId: 'tenant-dhaka',
        activeBranchId: 'branch-gulshan',
        activeBranchName: 'Gulshan Branch',
        userRole: 'PHARMACY_OWNER',
        username: 'owner_farhan',
        sharedStore: sharedStore,
      );
    });

    test('Test 1: Cashier is restricted to active terminal branch and cross-branch access is blocked', () {
      // Query active branch succeeds
      final activeRes = cashierBranch1.listBatchesForActiveTerminal();
      expect(activeRes.success, isTrue);
      expect(activeRes.data!.length, equals(1));
      expect(activeRes.data!.first.batchId, equals('bat-gulshan-01'));

      // Attempting to query Uttara branch as cashier is blocked
      final crossRes = cashierBranch1.listBatchesForActiveTerminal(requestedBranchId: 'branch-uttara');
      expect(crossRes.success, isFalse);
      expect(crossRes.errorCode, equals('ERR_CROSS_BRANCH_ACCESS'));
    });

    test('Test 2: Validate checkout dispense cart in active branch', () {
      final items = [
        const MobileDispenseItem(batchId: 'bat-gulshan-01', quantity: 15),
      ];
      final res = cashierBranch1.validateDispenseCart(items);

      expect(res.success, isTrue);
      expect(res.data!.length, equals(1));
      expect(res.data!.first.batchId, equals('bat-gulshan-01'));
    });

    test('Test 3: Cross-branch stock mixing in checkout is strictly barred', () {
      // Cashier at Gulshan attempts to checkout Uttara branch batch
      final items = [
        const MobileDispenseItem(batchId: 'bat-uttara-01', quantity: 10),
      ];
      final res = cashierBranch1.validateDispenseCart(items);

      expect(res.success, isFalse);
      expect(res.errorCode, equals('ERR_CROSS_BRANCH_DISPENSE_BLOCKED'));
      expect(res.messageEn.contains('Cross-branch stock mixing is strictly barred'), isTrue);
    });

    test('Test 4: Pharmacy Owner views multi-branch segregated inventory breakdown', () {
      final res = ownerClient.getMedicineMultiBranchSummary(
        'prod-ace',
        authorizedBranches: ['branch-gulshan', 'branch-uttara'],
      );

      expect(res.success, isTrue);
      expect(res.data!.length, equals(2));

      // Branch 1: Gulshan
      final gulshan = res.data![0];
      expect(gulshan.branchId, equals('branch-gulshan'));
      expect(gulshan.quantityOnHand, equals(60));
      expect(gulshan.quantityReserved, equals(10));
      expect(gulshan.quantityAvailable, equals(50));
      expect(gulshan.batches.length, equals(1));

      // Branch 2: Uttara
      final uttara = res.data![1];
      expect(uttara.branchId, equals('branch-uttara'));
      expect(uttara.quantityOnHand, equals(90));
      expect(uttara.quantityReserved, equals(0));
      expect(uttara.quantityAvailable, equals(90));
      expect(uttara.batches.length, equals(1));

      // Non-owner (cashier) is barred from multi-branch summaries
      final cashierSummary = cashierBranch1.getMedicineMultiBranchSummary(
        'prod-ace',
        authorizedBranches: ['branch-gulshan', 'branch-uttara'],
      );
      expect(cashierSummary.success, isFalse);
      expect(cashierSummary.errorCode, equals('ERR_PERMISSION_DENIED'));
    });
  });
}

