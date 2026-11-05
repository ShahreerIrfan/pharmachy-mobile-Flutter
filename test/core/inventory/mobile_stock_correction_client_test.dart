import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/inventory/mobile_stock_correction_client.dart';

void main() {
  group('P174 MobileStockCorrectionClient Tests', () {
    test('Test 1: Proposing adjustment creates PENDING record with validations', () {
      final client = MobileStockCorrectionClient(
        tenantId: 'tenant-dhaka',
        branchId: 'branch-gulshan',
        userRole: 'CASHIER',
        username: 'cashier_rafi',
      );

      // Zero delta rejected
      final zeroRes = client.proposeAdjustment(
        productId: 'med-ace',
        batchId: 'batch-ace-01',
        adjustmentType: MobileAdjustmentType.damage,
        quantityDelta: 0,
        unitCostBdt: 3.25,
        reason: 'Valid audit reason text',
      );
      expect(zeroRes.success, isFalse);
      expect(zeroRes.errorCode, equals('ERR_ZERO_QUANTITY_DELTA'));

      // Short reason (< 10 chars) rejected
      final shortRes = client.proposeAdjustment(
        productId: 'med-ace',
        batchId: 'batch-ace-01',
        adjustmentType: MobileAdjustmentType.damage,
        quantityDelta: -4,
        unitCostBdt: 3.25,
        reason: 'leak',
      );
      expect(shortRes.success, isFalse);
      expect(shortRes.errorCode, equals('ERR_AUDIT_REASON_REQUIRED'));

      // Valid proposal
      final validRes = client.proposeAdjustment(
        productId: 'med-ace',
        batchId: 'batch-ace-01',
        costLotId: 'lot-ace-101',
        adjustmentType: MobileAdjustmentType.damage,
        quantityDelta: -6,
        unitCostBdt: 3.25,
        reason: 'Water dripping from cooler damaged blister strip',
        supportingDocumentRef: 'INC-2026-99',
      );
      expect(validRes.success, isTrue);
      expect(validRes.data, isNotNull);
      expect(validRes.data!.status, equals(MobileCorrectionStatus.pending));
      expect(validRes.data!.quantityDelta, equals(-6));
      expect(validRes.data!.totalCostImpact, closeTo(19.50, 0.001));
      expect(validRes.data!.adjustmentId.startsWith('stkadj-'), isTrue);
    });

    test('Test 2: Dual authorization and reservation safety on approval', () {
      final sharedStore = <String, MobileStockAdjustment>{};
      final cashier = MobileStockCorrectionClient(
        tenantId: 'tenant-dhaka',
        branchId: 'branch-gulshan',
        userRole: 'CASHIER',
        username: 'cashier_rafi',
        sharedStore: sharedStore,
      );

      final prop = cashier.proposeAdjustment(
        productId: 'med-napa',
        batchId: 'batch-napa-9',
        adjustmentType: MobileAdjustmentType.expiryRemoval,
        quantityDelta: -15,
        unitCostBdt: 2.50,
        reason: 'Expired lot pulled from front shelves for destruction',
      );
      expect(prop.success, isTrue);
      final adjId = prop.data!.adjustmentId;

      // Cashier cannot approve
      final cashierApprove = cashier.approveAdjustment(
        adjustmentId: adjId,
        currentPhysicalQty: 80,
        currentReservedQty: 10,
      );
      expect(cashierApprove.success, isFalse);
      expect(cashierApprove.errorCode, equals('ERR_PERMISSION_DENIED'));

      final manager = MobileStockCorrectionClient(
        tenantId: 'tenant-dhaka',
        branchId: 'branch-gulshan',
        userRole: 'BRANCH_MANAGER',
        username: 'manager_tariq',
        sharedStore: sharedStore,
      );

      // Reservation conflict: physical 20, reserved 12 -> unreserved 8 < 15
      final conflictApprove = manager.approveAdjustment(
        adjustmentId: adjId,
        currentPhysicalQty: 20,
        currentReservedQty: 12,
      );
      expect(conflictApprove.success, isFalse);
      expect(conflictApprove.errorCode, equals('ERR_INSUFFICIENT_UNRESERVED_STOCK'));

      // Sufficient unreserved stock: physical 80, reserved 10 -> unreserved 70 >= 15
      final validApprove = manager.approveAdjustment(
        adjustmentId: adjId,
        currentPhysicalQty: 80,
        currentReservedQty: 10,
      );
      expect(validApprove.success, isTrue);
      expect(validApprove.data!.status, equals(MobileCorrectionStatus.approved));
      expect(validApprove.data!.approvedBy, equals('manager_tariq'));
      expect(validApprove.data!.approvedAt, isNotNull);
    });

    test('Test 3: Reject pending adjustment with audit reason', () {
      final client = MobileStockCorrectionClient(
        tenantId: 'tenant-dhaka',
        branchId: 'branch-gulshan',
        userRole: 'BRANCH_MANAGER',
        username: 'manager_tariq',
      );

      final prop = client.proposeAdjustment(
        productId: 'med-napa',
        batchId: 'batch-napa-9',
        adjustmentType: MobileAdjustmentType.countCorrection,
        quantityDelta: 20,
        unitCostBdt: 2.00,
        reason: 'Surplus noted during afternoon count',
      );
      expect(prop.success, isTrue);
      final adjId = prop.data!.adjustmentId;

      // Short rejection reason
      final shortReject = client.rejectAdjustment(
        adjustmentId: adjId,
        reason: 'denied',
      );
      expect(shortReject.success, isFalse);
      expect(shortReject.errorCode, equals('ERR_AUDIT_REASON_REQUIRED'));

      // Valid rejection
      final okReject = client.rejectAdjustment(
        adjustmentId: adjId,
        reason: 'Double-checked carton box; count was correctly accounted for in reserve rack',
      );
      expect(okReject.success, isTrue);
      expect(okReject.data!.status, equals(MobileCorrectionStatus.rejected));
    });

    test('Test 4: Reversing approved adjustment creates symmetrical compensating entry', () {
      final owner = MobileStockCorrectionClient(
        tenantId: 'tenant-dhaka',
        branchId: 'branch-gulshan',
        userRole: 'PHARMACY_OWNER',
        username: 'owner_farhan',
      );

      final prop = owner.proposeAdjustment(
        productId: 'med-napa',
        batchId: 'batch-napa-9',
        adjustmentType: MobileAdjustmentType.theftLoss,
        quantityDelta: -5,
        unitCostBdt: 4.00,
        reason: 'Discrepancy at counter shelf audit',
      );
      expect(prop.success, isTrue);
      final adjId = prop.data!.adjustmentId;

      owner.approveAdjustment(
        adjustmentId: adjId,
        currentPhysicalQty: 40,
        currentReservedQty: 0,
      );

      // Reversal
      final rev = owner.reverseAdjustment(
        adjustmentId: adjId,
        reason: 'Bottles located in mislabeled back storage bin',
        currentPhysicalQty: 35,
        currentReservedQty: 0,
      );
      expect(rev.success, isTrue);
      expect(rev.data!.status, equals(MobileCorrectionStatus.approved));
      expect(rev.data!.quantityDelta, equals(5)); // +5 opposite delta
      expect(rev.data!.reversalOfId, equals(adjId));

      // Re-reversal barred
      final doubleRev = owner.reverseAdjustment(
        adjustmentId: adjId,
        reason: 'Attempting to reverse already reversed record',
        currentPhysicalQty: 40,
        currentReservedQty: 0,
      );
      expect(doubleRev.success, isFalse);
      expect(doubleRev.errorCode, equals('ERR_ALREADY_REVERSED'));
    });
  });
}
