import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/inventory/mobile_loose_tablet_sales_client.dart';

void main() {
  group('MobileLooseTabletSalesClient Tests (P164)', () {
    late MobileLooseTabletSalesClient client;
    late MobileLooseSalesPolicy allowedPolicy;
    late MobileLooseSalesPolicy prohibitedPolicy;
    late MobileLooseSalesPolicy surchargePolicy;

    setUp(() {
      client = const MobileLooseTabletSalesClient();

      allowedPolicy = const MobileLooseSalesPolicy(
        configId: 'ltsc-mob-01',
        tenantId: 'ten-01',
        branchId: 'br-01',
        productId: 'prod-para-500',
        productName: 'Napa 500mg Tablet',
        allowLooseSales: true,
        minLooseDispenseUnits: 1,
        maxLooseDispenseUnits: 100,
        stripSizePieces: 10,
        stripMrp: 30.00,
        looseUnitMrp: 3.00,
        applyLooseUnitSurcharge: false,
        looseSurchargePercentage: 0.0,
      );

      prohibitedPolicy = const MobileLooseSalesPolicy(
        configId: 'ltsc-mob-02',
        tenantId: 'ten-01',
        branchId: 'br-01',
        productId: 'prod-vitc-eff',
        productName: 'Ceevit Effervescent 1000mg',
        allowLooseSales: false,
        minLooseDispenseUnits: 1,
        maxLooseDispenseUnits: 50,
        stripSizePieces: 10,
        stripMrp: 150.00,
        looseUnitMrp: 15.00,
        applyLooseUnitSurcharge: false,
        looseSurchargePercentage: 0.0,
        prohibitionReason: 'Hygroscopic formulation degrades upon breaking blister seal.',
      );

      surchargePolicy = const MobileLooseSalesPolicy(
        configId: 'ltsc-mob-03',
        tenantId: 'ten-01',
        branchId: 'br-01',
        productId: 'prod-azithro-500',
        productName: 'Zimax 500mg',
        allowLooseSales: true,
        minLooseDispenseUnits: 1,
        maxLooseDispenseUnits: 100,
        stripSizePieces: 10,
        stripMrp: 350.00,
        looseUnitMrp: 35.00,
        applyLooseUnitSurcharge: true,
        looseSurchargePercentage: 10.0, // 10% surcharge on loose
      );
    });

    test('1. Quote calculation: Exact strip and loose pieces price with zero drift', () {
      final quote = client.calculateQuote(
        policy: allowedPolicy,
        strips: 1,
        loosePieces: 4,
        availableStockBaseUnits: 100,
      );

      expect(quote.isAllowed, isTrue);
      expect(quote.normalizedStrips, equals(1));
      expect(quote.normalizedLoosePieces, equals(4));
      expect(quote.totalBaseUnits, equals(14));
      expect(quote.stripTotal, equals(30.00));
      expect(quote.looseTotal, equals(12.00));
      expect(quote.finalQuoteAmount, equals(42.00));
      expect(quote.isStockSufficient, isTrue);
    });

    test('2. Prohibition guardrail: Loose tablet sales rejected for hygroscopic medicines', () {
      final quote = client.calculateQuote(
        policy: prohibitedPolicy,
        strips: 0,
        loosePieces: 3,
        availableStockBaseUnits: 100,
      );

      expect(quote.isAllowed, isFalse);
      expect(quote.errorCode, equals('ERR_LOOSE_TABLET_SALES_PROHIBITED'));
      expect(quote.errorMessageEn, contains('Hygroscopic'));
      expect(quote.errorMessageBn, contains('নিষিদ্ধ'));
    });

    test('3. Full strips permitted even when loose tablets are prohibited', () {
      final quote = client.calculateQuote(
        policy: prohibitedPolicy,
        strips: 2,
        loosePieces: 0,
        availableStockBaseUnits: 50,
      );

      expect(quote.isAllowed, isTrue);
      expect(quote.normalizedStrips, equals(2));
      expect(quote.normalizedLoosePieces, equals(0));
      expect(quote.totalBaseUnits, equals(20));
      expect(quote.finalQuoteAmount, equals(300.00));
    });

    test('4. Surcharge calculation: Loose unit surcharge applies only to loose pieces', () {
      final quote = client.calculateQuote(
        policy: surchargePolicy,
        strips: 1,
        loosePieces: 2,
        availableStockBaseUnits: 100,
      );

      expect(quote.isAllowed, isTrue);
      expect(quote.normalizedStrips, equals(1));
      expect(quote.normalizedLoosePieces, equals(2));
      expect(quote.totalBaseUnits, equals(12));
      expect(quote.stripTotal, equals(350.00));
      expect(quote.looseTotal, equals(77.00)); // 2 * (35 * 1.10 = 38.50)
      expect(quote.finalQuoteAmount, equals(427.00));
    });

    test('5. FEFO Allocation: Checkouts deduct from earliest unexpired batch first', () {
      final today = DateTime(2026, 11, 4);

      final batchEarly = MobileBatchStockItem(
        batchId: 'batch-01',
        batchNumber: 'B-EARLY',
        expiryDate: DateTime(2026, 12, 1),
        quantityBaseUnits: 10,
      );
      final batchLate = MobileBatchStockItem(
        batchId: 'batch-02',
        batchNumber: 'B-LATE',
        expiryDate: DateTime(2027, 6, 1),
        quantityBaseUnits: 50,
      );

      final batches = [batchLate, batchEarly];

      final checkout = client.executeCheckout(
        policy: allowedPolicy,
        availableBatches: batches,
        strips: 1,
        loosePieces: 4,
        asOfDate: today,
      );

      expect(checkout.success, isTrue);
      expect(checkout.allocations.length, equals(2));
      expect(checkout.allocations[0].batchId, equals('batch-01'));
      expect(checkout.allocations[0].deductedBaseUnits, equals(10));
      expect(batchEarly.quantityBaseUnits, equals(0));

      expect(checkout.allocations[1].batchId, equals('batch-02'));
      expect(checkout.allocations[1].deductedBaseUnits, equals(4));
      expect(batchLate.quantityBaseUnits, equals(46));
    });

    test('6. Compliance: Expired batches excluded from checkout', () {
      final today = DateTime(2026, 11, 4);

      final expiredBatch = MobileBatchStockItem(
        batchId: 'batch-exp',
        batchNumber: 'B-EXPIRED',
        expiryDate: DateTime(2026, 11, 3), // Expired yesterday
        quantityBaseUnits: 100,
      );

      final checkout = client.executeCheckout(
        policy: allowedPolicy,
        availableBatches: [expiredBatch],
        strips: 0,
        loosePieces: 5,
        asOfDate: today,
      );

      expect(checkout.success, isFalse);
      expect(checkout.errorCode, equals('ERR_INSUFFICIENT_STOCK'));
      expect(expiredBatch.quantityBaseUnits, equals(100)); // Untouched
    });

    test('7. Stock conservation: Reversal re-credits exact deducted integer units', () {
      final today = DateTime(2026, 11, 4);

      final batch = MobileBatchStockItem(
        batchId: 'batch-01',
        batchNumber: 'B-01',
        expiryDate: DateTime(2027, 1, 1),
        quantityBaseUnits: 30,
      );
      final lookup = {batch.batchId: batch};

      final checkout = client.executeCheckout(
        policy: allowedPolicy,
        availableBatches: [batch],
        strips: 0,
        loosePieces: 7,
        asOfDate: today,
      );

      expect(checkout.success, isTrue);
      expect(batch.quantityBaseUnits, equals(23)); // 30 - 7

      final reversed = client.reverseSale(
        execution: checkout,
        batchLookup: lookup,
      );
      expect(reversed, isTrue);
      expect(batch.quantityBaseUnits, equals(30)); // Restored
    });
  });
}
