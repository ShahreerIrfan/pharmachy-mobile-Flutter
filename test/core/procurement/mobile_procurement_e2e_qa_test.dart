import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/procurement/mobile_procurement_e2e_qa_client.dart';

void main() {
  group('MobileProcurementE2EQaClient Tests (ADR-0200 / P200)', () {
    late MobileProcurementE2EQaClient managerClient;
    late MobileProcurementE2EQaClient cashierClient;

    setUp(() {
      managerClient = MobileProcurementE2EQaClient(
        tenantId: 'tenant-dhaka-01',
        branchId: 'branch-main',
        userRole: 'BRANCH_MANAGER',
        userId: 'usr-mgr-01',
      );

      cashierClient = MobileProcurementE2EQaClient(
        tenantId: 'tenant-dhaka-01',
        branchId: 'branch-main',
        userRole: 'CASHIER',
        userId: 'usr-cashier-02',
      );
    });

    test('1. Full procurement cycle executes successfully', () {
      final res = managerClient.executeFullProcurementCycle(
        supplierId: 'sup-square-01',
        productId: 'prod-napa-500',
        orderedQuantity: 100,
        unitCost: 25.0,
      );

      expect(res.status, equals('PASSED'));
      expect(res.orderedQuantity, equals(100));
      expect(res.receivedQuantity, equals(100));
      expect(res.totalCost, equals(2500.0));
      expect(res.finalSupplierBalance, equals(0.0));
      expect(res.verificationHash.isNotEmpty, isTrue);
    });

    test('2. Duplicate receipt conflict is blocked', () {
      final res = managerClient.executeFullProcurementCycle(
        supplierId: 'sup-square-01',
        productId: 'prod-napa-500',
        orderedQuantity: 50,
        unitCost: 10.0,
      );

      expect(
        () => managerClient.verifyDuplicateConflict(res.poNumber),
        throwsA(isA<StateError>()),
      );
    });

    test('3. Purchase return reversal decrements lot and reduces payable', () {
      final ret = managerClient.verifyPurchaseReturnReversal(
        costLotId: 'lot-test-101',
        returnQuantity: 20,
        unitCost: 15.0,
        supplierId: 'sup-square-01',
      );

      expect(ret.remainingLotQuantity, equals(80));
      expect(ret.refundAmount, equals(300.0));
      expect(ret.supplierBalanceAfter, equals(-300.0));
    });

    test('4. Zero ordered quantity throws ArgumentError', () {
      expect(
        () => managerClient.executeFullProcurementCycle(
          supplierId: 'sup-square-01',
          productId: 'prod-napa-500',
          orderedQuantity: 0,
          unitCost: 25.0,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('5. Cashier access is rejected with StateError', () {
      expect(
        () => cashierClient.executeFullProcurementCycle(
          supplierId: 'sup-square-01',
          productId: 'prod-napa-500',
          orderedQuantity: 10,
          unitCost: 25.0,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('6. Over return beyond lot capacity throws ArgumentError', () {
      expect(
        () => managerClient.verifyPurchaseReturnReversal(
          costLotId: 'lot-small-01',
          returnQuantity: 150,
          unitCost: 10.0,
          supplierId: 'sup-square-01',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}

