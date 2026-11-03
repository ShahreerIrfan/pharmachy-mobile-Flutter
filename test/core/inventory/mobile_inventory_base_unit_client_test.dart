import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/inventory/mobile_inventory_base_unit_client.dart';

void main() {
  late MobileInventoryBaseUnitClient client;
  late MobileStrategyConfig tabletConfig;
  late MobileStrategyConfig vialConfig;

  setUp(() {
    client = MobileInventoryBaseUnitClient();

    tabletConfig = const MobileStrategyConfig(
      strategyId: 'ibus-tablet-01',
      productId: 'prod-napa-500',
      baseUnit: 'TABLET',
      isIndivisible: true,
      allowDecimalQuantities: false,
      decimalPlacesAllowed: 0,
      minimumDispenseQuantity: 1.0,
      packUnitLabel: 'BOX',
      intermediateUnitLabel: 'STRIP',
      packToIntermediateMultiplier: 10,
      intermediateToBaseMultiplier: 10,
      totalBaseUnitsPerPack: 100,
      costPerBaseUnit: 0.80,
      mrpPerBaseUnit: 1.20,
    );

    vialConfig = const MobileStrategyConfig(
      strategyId: 'ibus-vial-01',
      productId: 'prod-rocephin-1g',
      baseUnit: 'VIAL',
      isIndivisible: true,
      allowDecimalQuantities: false,
      decimalPlacesAllowed: 0,
      minimumDispenseQuantity: 1.0,
      packUnitLabel: 'BOX',
      intermediateUnitLabel: 'TRAY',
      packToIntermediateMultiplier: 1,
      intermediateToBaseMultiplier: 5,
      totalBaseUnitsPerPack: 5,
      costPerBaseUnit: 150.0,
      mrpPerBaseUnit: 190.0,
    );
  });

  group('MobileInventoryBaseUnitClient Tests (P161)', () {
    test('1. Valid scenario: Pack to base conversion computes exact valuation', () {
      final result = client.convertToBaseUnits(
        quantity: 2.0,
        unitTier: 'PACK',
        config: tabletConfig,
      );

      expect(result.success, isTrue);
      expect(result.baseUnitQuantity, 200.0);
      expect(result.costValuationBdt, closeTo(160.0, 0.0001));
      expect(result.mrpValuationBdt, closeTo(240.0, 0.0001));
    });

    test('2. Valid scenario: Intermediate strip to base conversion', () {
      final result = client.convertToBaseUnits(
        quantity: 3.0,
        unitTier: 'INTERMEDIATE',
        config: tabletConfig,
      );

      expect(result.success, isTrue);
      expect(result.baseUnitQuantity, 30.0);
      expect(result.costValuationBdt, closeTo(24.0, 0.0001));
      expect(result.mrpValuationBdt, closeTo(36.0, 0.0001));
    });

    test('3. Invalid scenario: Fractional conversion on indivisible vial is strictly rejected', () {
      final result = client.convertToBaseUnits(
        quantity: 0.5,
        unitTier: 'PACK',
        config: vialConfig,
      );

      expect(result.success, isFalse);
      expect(result.errorCode, 'ERR_INDIVISIBLE_UNIT_FRACTION');
      expect(result.errorMessageBn, isNotNull);
    });

    test('4. Reversal / Unpacking: 125 base units decomposes to 1 box, 2 strips, 5 loose tablets', () {
      final result = client.decomposeBaseUnits(
        totalBaseUnits: 125,
        config: tabletConfig,
      );

      expect(result.totalBaseUnits, 125);
      expect(result.packs, 1);
      expect(result.intermediate, 2);
      expect(result.looseBase, 5);
      expect(result.baseUnit, 'TABLET');
    });

    test('5. Dispense validation: Below minimum quantity is rejected', () {
      final errors = client.validateDispenseQuantity(
        quantity: 0.5,
        config: tabletConfig,
      );

      expect(errors, contains('ERR_BELOW_MINIMUM_DISPENSE_QTY'));
    });

    test('6. Dispense validation: Indivisible fractional piece is rejected', () {
      final errors = client.validateDispenseQuantity(
        quantity: 2.5,
        config: vialConfig,
      );

      expect(errors, contains('ERR_INDIVISIBLE_UNIT_FRACTION'));
    });

    test('7. Role authorization: Cashier blocked from strategy configuration', () {
      expect(client.canConfigureStrategy('OWNER'), isTrue);
      expect(client.canConfigureStrategy('MANAGER'), isTrue);
      expect(client.canConfigureStrategy('PHARMACIST'), isTrue);
      expect(client.canConfigureStrategy('CASHIER'), isFalse);
      expect(client.canConfigureStrategy(null), isFalse);
    });
  });
}

