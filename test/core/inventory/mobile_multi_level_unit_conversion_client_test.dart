import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/inventory/mobile_multi_level_unit_conversion_client.dart';

void main() {
  late MobileMultiLevelUnitConversionClient client;
  late MobileConversionPolicy unsplitTabletPolicy;
  late MobileConversionPolicy splittableTabletPolicy;

  setUp(() {
    client = MobileMultiLevelUnitConversionClient();

    unsplitTabletPolicy = const MobileConversionPolicy(
      policyId: 'ucp-01',
      productId: 'prod-napa-500',
      isSplittable: false,
      allowedSplitFractions: [1.0],
      clinicalDosingUnit: 'MG',
      dosingConversionRatio: 500.0,
      prohibitedDosingUnits: {'ML', 'L', 'PUFF', 'ACTUATION', 'DROP', 'VIAL', 'AMPOULE'},
    );

    splittableTabletPolicy = const MobileConversionPolicy(
      policyId: 'ucp-02',
      productId: 'prod-biso-5',
      isSplittable: true,
      allowedSplitFractions: [0.5, 1.0],
      clinicalDosingUnit: 'MG',
      dosingConversionRatio: 5.0,
      prohibitedDosingUnits: {'ML', 'L', 'PUFF', 'ACTUATION', 'DROP', 'VIAL'},
    );
  });

  group('MobileMultiLevelUnitConversionClient Tests (P163)', () {
    test('1. Valid scenario: Multi-tier packaging conversion calculates exact quantities', () {
      final res = client.convertMultiLevel(
        quantity: 2.0,
        fromUnit: 'BOX',
        toUnit: 'TABLET',
        packagingMultiplier: 100,
        dosageForm: 'Tablet',
        policy: unsplitTabletPolicy,
        costPerBaseUnit: 0.80,
        mrpPerBaseUnit: 1.20,
      );

      expect(res.success, isTrue);
      expect(res.convertedQuantity, 200.0);
      expect(res.costValuationBdt, closeTo(160.0, 0.0001));
      expect(res.mrpValuationBdt, closeTo(240.0, 0.0001));
    });

    test('2. Guardrail: Fractional tablet blocked on unsplit tablet', () {
      final report = client.validateDispense(
        unit: 'TABLET',
        quantity: 1.5,
        dosageForm: 'Tablet',
        policy: unsplitTabletPolicy,
      );

      expect(report.isValid, isFalse);
      expect(report.errorCode, 'ERR_FRACTIONAL_TABLET_NOT_ALLOWED');
    });

    test('3. Splittable tablet allows authorized half-tablet split (0.5 and 2.5)', () {
      final report1 = client.validateDispense(
        unit: 'TABLET',
        quantity: 0.5,
        dosageForm: 'Tablet',
        policy: splittableTabletPolicy,
      );
      expect(report1.isValid, isTrue);

      final report2 = client.validateDispense(
        unit: 'TABLET',
        quantity: 2.5,
        dosageForm: 'Tablet',
        policy: splittableTabletPolicy,
      );
      expect(report2.isValid, isTrue);
    });

    test('4. Guardrail: Inappropriate dosing-unit conversion (Tablet to ML or PUFF) blocked', () {
      final report1 = client.validateDispense(
        unit: 'ML',
        quantity: 10.0,
        dosageForm: 'Tablet',
        policy: unsplitTabletPolicy,
      );
      expect(report1.isValid, isFalse);
      expect(report1.errorCode, 'ERR_INCOMPATIBLE_DOSING_UNIT');

      final report2 = client.validateDispense(
        unit: 'PUFF',
        quantity: 2.0,
        dosageForm: 'Tablet',
        policy: unsplitTabletPolicy,
      );
      expect(report2.isValid, isFalse);
      expect(report2.errorCode, 'ERR_INCOMPATIBLE_DOSING_UNIT');
    });

    test('5. Clinical calculation: Tablets to active substance MG calculates potency', () {
      final res = client.convertMultiLevel(
        quantity: 2.0,
        fromUnit: 'TABLET',
        toUnit: 'MG',
        packagingMultiplier: 1,
        dosageForm: 'Tablet',
        policy: unsplitTabletPolicy,
      );

      expect(res.success, isTrue);
      expect(res.isClinicalDosingCalculation, isTrue);
      expect(res.convertedQuantity, 1000.0);
    });

    test('6. Guardrail: Indivisible unit fraction (0.5 Vial) blocked', () {
      final report = client.validateDispense(
        unit: 'VIAL',
        quantity: 0.5,
        dosageForm: 'Injection',
        policy: null,
      );

      expect(report.isValid, isFalse);
      expect(report.errorCode, 'ERR_INDIVISIBLE_UNIT_FRACTION');
    });

    test('7. Role authorization: Cashier blocked from configuring unit conversion policy', () {
      expect(client.canConfigurePolicy('OWNER'), isTrue);
      expect(client.canConfigurePolicy('MANAGER'), isTrue);
      expect(client.canConfigurePolicy('PHARMACIST'), isTrue);
      expect(client.canConfigurePolicy('CASHIER'), isFalse);
      expect(client.canConfigurePolicy(null), isFalse);
    });
  });
}

