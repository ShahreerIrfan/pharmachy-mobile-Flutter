import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/inventory/mobile_return_inspection_client.dart';

void main() {
  group('MobileReturnInspectionClient Tests (P177)', () {
    late Map<String, MobileReturnSafetyInspection> sharedStore;
    late MobileReturnInspectionClient pharmacistClient;
    late MobileReturnInspectionClient cashierClient;
    late MobileReturnInspectionClient managerClient;

    late MobileSaleAllocationLookup validAlloc;
    late MobileSaleAllocationLookup expiredAlloc;

    setUp(() {
      sharedStore = <String, MobileReturnSafetyInspection>{};

      pharmacistClient = MobileReturnInspectionClient(
        tenantId: 'tenant-dhaka',
        branchId: 'branch-banani',
        userRole: 'STAFF_PHARMACIST',
        userId: 'pharm_001',
        sharedStore: sharedStore,
      );

      cashierClient = MobileReturnInspectionClient(
        tenantId: 'tenant-dhaka',
        branchId: 'branch-banani',
        userRole: 'CASHIER',
        userId: 'cashier_001',
        sharedStore: sharedStore,
      );

      managerClient = MobileReturnInspectionClient(
        tenantId: 'tenant-dhaka',
        branchId: 'branch-banani',
        userRole: 'BRANCH_MANAGER',
        userId: 'mgr_001',
        sharedStore: sharedStore,
      );

      validAlloc = MobileSaleAllocationLookup(
        allocationId: 'sall-001',
        tenantId: 'tenant-dhaka',
        branchId: 'branch-banani',
        invoiceId: 'inv-2026-001',
        productId: 'prod-napa',
        productName: 'Napa Extra 500mg',
        batchId: 'bat-001',
        batchNumber: 'BAT-2026-A',
        costLotId: 'lot-001',
        quantityBaseUnits: 10,
        returnedQuantityBaseUnits: 0,
        unitSellingPrice: 10.0,
        unitCost: 7.5,
        batchExpiryDate: DateTime.now().add(const Duration(days: 180)),
        isBatchQuarantined: false,
      );

      expiredAlloc = MobileSaleAllocationLookup(
        allocationId: 'sall-002',
        tenantId: 'tenant-dhaka',
        branchId: 'branch-banani',
        invoiceId: 'inv-2026-002',
        productId: 'prod-seclo',
        productName: 'Seclo 20mg',
        batchId: 'bat-002',
        batchNumber: 'BAT-2026-EXP',
        costLotId: 'lot-002',
        quantityBaseUnits: 5,
        returnedQuantityBaseUnits: 0,
        unitSellingPrice: 7.0,
        unitCost: 4.5,
        batchExpiryDate: DateTime.now().subtract(const Duration(days: 2)),
        isBatchQuarantined: false,
      );
    });

    test('Test 1: Pharmacist inspects and restocks valid return with exact valuation', () {
      final res = pharmacistClient.inspectAndProcessReturn(
        alloc: validAlloc,
        returnedQty: 4,
        isSealIntact: true,
        isPackagingUndamaged: true,
        isStorageConditionVerified: true,
        isUnexpired: true,
        disposition: MobileReturnDisposition.restockApproved,
        customerReason: 'Extra strips',
        inspectionNotes: 'Visual and seal verified',
      );

      expect(res.success, isTrue);
      expect(res.data, isNotNull);
      expect(res.data!.disposition, equals(MobileReturnDisposition.restockApproved));
      expect(res.data!.returnedQuantityBaseUnits, equals(4));
      expect(res.data!.refundAmount, closeTo(40.0, 0.0001));
      expect(res.data!.restockedCogs, closeTo(30.0, 0.0001));
      expect(validAlloc.returnedQuantityBaseUnits, equals(4));
      expect(validAlloc.maxReturnableUnits, equals(6));
    });

    test('Test 2: Failed safety inspection blocks restock, successfully routes to quarantine hold', () {
      final failedRestock = pharmacistClient.inspectAndProcessReturn(
        alloc: validAlloc,
        returnedQty: 2,
        isSealIntact: false, // Broken seal!
        isPackagingUndamaged: true,
        isStorageConditionVerified: true,
        isUnexpired: true,
        disposition: MobileReturnDisposition.restockApproved,
      );

      expect(failedRestock.success, isFalse);
      expect(failedRestock.errorCode, equals('ERR_FAILED_SAFETY_INSPECTION_CANNOT_RESTOCK'));

      // Divert to quarantine hold succeeds
      final quarantineRes = pharmacistClient.inspectAndProcessReturn(
        alloc: validAlloc,
        returnedQty: 2,
        isSealIntact: false,
        isPackagingUndamaged: true,
        isStorageConditionVerified: true,
        isUnexpired: true,
        disposition: MobileReturnDisposition.quarantineHold,
        customerReason: 'Open seal return',
        inspectionNotes: 'Held in quarantine for inspection',
      );

      expect(quarantineRes.success, isTrue);
      expect(quarantineRes.data!.disposition, equals(MobileReturnDisposition.quarantineHold));
      expect(quarantineRes.data!.refundAmount, closeTo(20.0, 0.0001));
      expect(quarantineRes.data!.restockedCogs, equals(0.0));
    });

    test('Test 3: Attempting to restock an expired batch is blocked with clinical error', () {
      final res = pharmacistClient.inspectAndProcessReturn(
        alloc: expiredAlloc,
        returnedQty: 2,
        isSealIntact: true,
        isPackagingUndamaged: true,
        isStorageConditionVerified: true,
        isUnexpired: true,
        disposition: MobileReturnDisposition.restockApproved,
      );

      expect(res.success, isFalse);
      expect(res.errorCode, equals('ERR_BATCH_EXPIRED_NO_RESTOCK'));

      // Routing to damaged/destroy succeeds
      final destroyRes = pharmacistClient.inspectAndProcessReturn(
        alloc: expiredAlloc,
        returnedQty: 2,
        isSealIntact: true,
        isPackagingUndamaged: true,
        isStorageConditionVerified: true,
        isUnexpired: true,
        disposition: MobileReturnDisposition.damagedDestroy,
        customerReason: 'Expired medicine',
      );

      expect(destroyRes.success, isTrue);
      expect(destroyRes.data!.disposition, equals(MobileReturnDisposition.damagedDestroy));
    });

    test('Test 4: Cashier permission is denied, and manager can reverse inspection with audit', () {
      final cashierRes = cashierClient.inspectAndProcessReturn(
        alloc: validAlloc,
        returnedQty: 2,
        disposition: MobileReturnDisposition.restockApproved,
      );
      expect(cashierRes.success, isFalse);
      expect(cashierRes.errorCode, equals('ERR_PERMISSION_DENIED'));

      final pharmRes = pharmacistClient.inspectAndProcessReturn(
        alloc: validAlloc,
        returnedQty: 2,
        disposition: MobileReturnDisposition.restockApproved,
      );
      expect(pharmRes.success, isTrue);
      final inspId = pharmRes.data!.inspectionId;

      final cashierRev = cashierClient.reverseInspection(
        inspectionId: inspId,
        reason: 'Unauthorized cashier reversal attempt',
      );
      expect(cashierRev.success, isFalse);
      expect(cashierRev.errorCode, equals('ERR_PERMISSION_DENIED'));

      final mgrRev = managerClient.reverseInspection(
        inspectionId: inspId,
        reason: 'Secondary inspection showed damaged blister foil',
      );
      expect(mgrRev.success, isTrue);
      expect(mgrRev.data!.isReversed, isTrue);
      expect(mgrRev.data!.reversalReason, equals('Secondary inspection showed damaged blister foil'));

      final doubleRev = managerClient.reverseInspection(
        inspectionId: inspId,
        reason: 'Another reversal attempt',
      );
      expect(doubleRev.success, isFalse);
      expect(doubleRev.errorCode, equals('ERR_ALREADY_REVERSED'));
    });
  });
}

