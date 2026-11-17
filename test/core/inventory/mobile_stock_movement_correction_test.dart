import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/inventory/mobile_stock_movement_correction_client.dart';

void main() {
  group('P217: MobileStockMovementCorrectionClient Tests', () {
    late MobileStockMovementCorrectionClient client;

    setUp(() {
      client = MobileStockMovementCorrectionClient();
    });

    test('1. Valid scenario: Reversal via compensating entry', () {
      final correction = client.executeCorrection(
        userRole: 'PHARMACY_OWNER',
        tenantId: 'ten-united',
        branchId: 'br-central',
        originalEntryId: 'stkld-orig-001',
        originalDelta: -10, // original outward dispense
        currentBatchStock: 40,
        unitCostBdt: 2.50,
        productId: 'prod-nap-01',
        batchNumber: 'NAP-001',
        reason: MobileCorrectionReason.mistypedQuantity,
        explanation: 'Erroneous dispense entry. Reversing to restore 10 units.',
      );

      expect(correction.originalEntryId, 'stkld-orig-001');
      expect(correction.reversedQuantityDelta, 10);
      expect(correction.unitCostBdt, 2.50);
      expect(correction.totalCostImpactBdt, 25.00);
      expect(correction.status, MobileCorrectionStatus.completed);
      expect(client.isReversed('stkld-orig-001'), isTrue);
    });

    test('2. Prevents double-reversal of the same entry', () {
      client.executeCorrection(
        userRole: 'BRANCH_MANAGER',
        tenantId: 'ten-01',
        branchId: 'br-01',
        originalEntryId: 'stkld-orig-002',
        originalDelta: -5,
        currentBatchStock: 50,
        unitCostBdt: 10.0,
        productId: 'prod-01',
        batchNumber: 'BAT-01',
        reason: MobileCorrectionReason.mistypedQuantity,
        explanation: 'Legitimate correction first time.',
      );

      expect(
        () => client.executeCorrection(
          userRole: 'BRANCH_MANAGER',
          tenantId: 'ten-01',
          branchId: 'br-01',
          originalEntryId: 'stkld-orig-002',
          originalDelta: -5,
          currentBatchStock: 55,
          unitCostBdt: 10.0,
          productId: 'prod-01',
          batchNumber: 'BAT-01',
          reason: MobileCorrectionReason.mistypedQuantity,
          explanation: 'Second duplicate correction.',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('3. Blocks reversal that would cause negative batch stock', () {
      expect(
        () => client.executeCorrection(
          userRole: 'STAFF_PHARMACIST',
          tenantId: 'ten-01',
          branchId: 'br-01',
          originalEntryId: 'stkld-in-001',
          originalDelta: 50, // inward +50 -> reversal -50
          currentBatchStock: 20, // 20 - 50 = -30
          unitCostBdt: 5.0,
          productId: 'prod-01',
          batchNumber: 'BAT-01',
          reason: MobileCorrectionReason.duplicatePosting,
          explanation: 'Reversal exceeding physical stock.',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('4. Denies CASHIER role with StateError', () {
      expect(
        () => client.executeCorrection(
          userRole: 'CASHIER',
          tenantId: 'ten-01',
          branchId: 'br-01',
          originalEntryId: 'stkld-orig-003',
          originalDelta: -1,
          currentBatchStock: 10,
          unitCostBdt: 10.0,
          productId: 'prod-01',
          batchNumber: 'BAT-01',
          reason: MobileCorrectionReason.mistypedQuantity,
          explanation: 'Cashier unauthorized attempt.',
        ),
        throwsA(isA<StateError>()),
      );
    });
  });
}
