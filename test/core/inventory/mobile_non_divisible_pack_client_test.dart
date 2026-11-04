import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/inventory/mobile_non_divisible_pack_client.dart';

void main() {
  group('MobileNonDivisiblePackClient Tests (P165)', () {
    late MobileNonDivisiblePackClient client;
    late MobileNonDivisiblePolicy insulinPenPolicy;
    late MobileNonDivisiblePolicy sterileBoxPolicy;
    late MobileNonDivisiblePolicy hospitalSplittablePolicy;

    setUp(() {
      client = const MobileNonDivisiblePackClient();

      insulinPenPolicy = const MobileNonDivisiblePolicy(
        policyId: 'ndpp-mob-01',
        tenantId: 'ten-01',
        branchId: 'br-01',
        productId: 'prod-lantus-pen',
        productName: 'Lantus SoloStar Pen',
        containerType: 'INSULIN_PEN',
        isSplittingAllowed: false,
        requirePharmacistApproval: true,
        approvedBreakFactor: 1,
        subUnitLabel: 'PEN',
        prohibitionReason: 'Pre-filled sterile insulin cartridge cannot be fractured or broken.',
      );

      sterileBoxPolicy = const MobileNonDivisiblePolicy(
        policyId: 'ndpp-mob-02',
        tenantId: 'ten-01',
        branchId: 'br-01',
        productId: 'prod-rocephin-box',
        productName: 'Rocephin 1g Sterile Box of 5 Vials',
        containerType: 'STERILE_VIAL_BOX',
        isSplittingAllowed: false,
        requirePharmacistApproval: true,
        approvedBreakFactor: 5,
        subUnitLabel: 'VIAL',
        prohibitionReason: 'Sealed sterile box integrity must be maintained.',
      );

      hospitalSplittablePolicy = const MobileNonDivisiblePolicy(
        policyId: 'ndpp-mob-03',
        tenantId: 'ten-01',
        branchId: 'br-01',
        productId: 'prod-morph-amp',
        productName: 'Morphine 10mg/ml Ampoule Box',
        containerType: 'STERILE_VIAL_BOX',
        isSplittingAllowed: true,
        requirePharmacistApproval: true,
        approvedBreakFactor: 10,
        subUnitLabel: 'AMPOULE',
        exemptionProtocols: {'HOSPITAL_INPATIENT', 'ICU_EMERGENCY_DOSE'},
      );
    });

    test('1. Valid scenario: Whole unit dispensing of insulin pens is allowed', () {
      final res = client.validateDispense(
        policy: insulinPenPolicy,
        requestedQuantity: 2.0,
        userRole: 'CASHIER',
      );

      expect(res.isAllowed, isTrue);
      expect(res.containerType, equals('INSULIN_PEN'));
      expect(res.errorCode, isNull);
    });

    test('2. Guardrail: Fractional quantity of an insulin pen is strictly rejected', () {
      final res = client.validateDispense(
        policy: insulinPenPolicy,
        requestedQuantity: 1.5,
        userRole: 'STAFF_PHARMACIST',
      );

      expect(res.isAllowed, isFalse);
      expect(res.errorCode, equals('ERR_NON_DIVISIBLE_CONTAINER_SPLIT_PROHIBITED'));
      expect(res.errorMessageEn, contains('Fractional dispensing'));
      expect(res.errorMessageBn, contains('নিষিদ্ধ'));
    });

    test('3. Guardrail: Splitting sealed box without approved rules is rejected', () {
      final res = client.validateDispense(
        policy: sterileBoxPolicy,
        requestedQuantity: 1.0,
        isSplitRequest: true,
        userRole: 'STAFF_PHARMACIST',
      );

      expect(res.isAllowed, isFalse);
      expect(res.errorCode, equals('ERR_NON_DIVISIBLE_CONTAINER_SPLIT_PROHIBITED'));
      expect(res.errorMessageEn, contains('Breaking sealed container'));
    });

    test('4. Protocol requirement: Splitting allowed pack without valid exemption protocol is rejected', () {
      final res = client.validateDispense(
        policy: hospitalSplittablePolicy,
        requestedQuantity: 1.0,
        isSplitRequest: true,
        exemptionProtocol: 'UNKNOWN_PROTOCOL',
        userRole: 'STAFF_PHARMACIST',
      );

      expect(res.isAllowed, isFalse);
      expect(res.errorCode, equals('ERR_INVALID_EXEMPTION_PROTOCOL'));
    });

    test('5. RBAC Guardrail: Cashier cannot unilaterally authorize container splitting', () {
      final res = client.validateDispense(
        policy: hospitalSplittablePolicy,
        requestedQuantity: 1.0,
        isSplitRequest: true,
        exemptionProtocol: 'HOSPITAL_INPATIENT',
        userRole: 'CASHIER',
      );

      expect(res.isAllowed, isFalse);
      expect(res.errorCode, equals('ERR_ROLE_UNAUTHORIZED'));
      expect(res.errorMessageEn, contains('Cashier role cannot authorize'));
    });

    test('6. Authorized split: Pharmacist with valid clinical protocol can approve container split', () {
      final res = client.validateDispense(
        policy: hospitalSplittablePolicy,
        requestedQuantity: 1.0,
        isSplitRequest: true,
        exemptionProtocol: 'HOSPITAL_INPATIENT',
        userRole: 'STAFF_PHARMACIST',
      );

      expect(res.isAllowed, isTrue);
      expect(res.errorCode, isNull);
      expect(res.approvedBreakFactor, equals(10));
    });

    test('7. FEFO Allocation: Checkouts deduct from earliest unexpired batch', () {
      final today = DateTime(2026, 11, 4);

      final bEarly = MobileBatchStockItem(
        batchId: 'b-01',
        batchNumber: 'PEN-EARLY',
        expiryDate: DateTime(2026, 12, 1),
        quantityBaseUnits: 3,
      );
      final bLate = MobileBatchStockItem(
        batchId: 'b-02',
        batchNumber: 'PEN-LATE',
        expiryDate: DateTime(2027, 6, 1),
        quantityBaseUnits: 10,
      );

      final checkout = client.executeCheckout(
        policy: insulinPenPolicy,
        availableBatches: [bLate, bEarly],
        requestedQuantity: 4.0,
        userRole: 'CASHIER',
        unitPrice: 850.00,
        asOfDate: today,
      );

      expect(checkout.success, isTrue);
      expect(checkout.allocations.length, equals(2));
      expect(checkout.allocations[0].batchId, equals('b-01'));
      expect(checkout.allocations[0].deductedBaseUnits, equals(3));
      expect(bEarly.quantityBaseUnits, equals(0));

      expect(checkout.allocations[1].batchId, equals('b-02'));
      expect(checkout.allocations[1].deductedBaseUnits, equals(1));
      expect(bLate.quantityBaseUnits, equals(9));
    });

    test('8. Reversal: Sale reversal re-credits exact deducted integer base units', () {
      final today = DateTime(2026, 11, 4);

      final batch = MobileBatchStockItem(
        batchId: 'b-01',
        batchNumber: 'PEN-01',
        expiryDate: DateTime(2027, 1, 1),
        quantityBaseUnits: 5,
      );
      final lookup = {batch.batchId: batch};

      final checkout = client.executeCheckout(
        policy: insulinPenPolicy,
        availableBatches: [batch],
        requestedQuantity: 2.0,
        userRole: 'CASHIER',
        unitPrice: 850.00,
        asOfDate: today,
      );

      expect(checkout.success, isTrue);
      expect(batch.quantityBaseUnits, equals(3)); // 5 - 2

      final reversed = client.reverseSale(checkout: checkout, batchLookup: lookup);
      expect(reversed, isTrue);
      expect(batch.quantityBaseUnits, equals(5)); // Restored
    });
  });
}
