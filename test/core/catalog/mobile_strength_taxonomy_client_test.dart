import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/catalog/mobile_strength_taxonomy_client.dart';

void main() {
  group('P123 Mobile Strength Measurement Taxonomy & Conversion Tests', () {
    late MobileStrengthTaxonomyClient client;

    setUp(() {
      client = MobileStrengthTaxonomyClient();
    });

    test('P123-M1: Valid intra-family conversion for MASS (g to mg, mg to g)', () {
      final res1 = client.convertStrength(1.0, 'g', 'mg');
      expect(res1.uiStatus, MobileStrengthUiStatus.success);
      expect(res1.isCompatible, isTrue);
      expect(res1.convertedValue, 1000.0);
      expect(res1.formattedResult, '1000 mg');

      final res2 = client.convertStrength(500.0, 'mg', 'g');
      expect(res2.uiStatus, MobileStrengthUiStatus.success);
      expect(res2.convertedValue, 0.5);
    });

    test('P123-M2: Valid intra-family conversion for VOLUME (L to mL)', () {
      final res = client.convertStrength(2.5, 'L', 'ml');
      expect(res.uiStatus, MobileStrengthUiStatus.success);
      expect(res.isCompatible, isTrue);
      expect(res.convertedValue, 2500.0);
      expect(res.formattedResult, '2500 ml');
    });

    test('P123-M3: Guard strictly prevents cross-family conversion (MASS to VOLUME: mg to mL)', () {
      final res = client.convertStrength(500.0, 'mg', 'ml');
      expect(res.uiStatus, MobileStrengthUiStatus.error);
      expect(res.isCompatible, isFalse);
      expect(res.errorCode, 'ERR_INCOMPATIBLE_UNIT_CONVERSION');
      expect(res.messageEn.contains('strictly forbidden'), isTrue);
      expect(res.messageBn.contains('নিষিদ্ধ'), isTrue);
    });

    test('P123-M4: Guard strictly prevents cross-family conversion (MASS to PERCENTAGE: mg to %)', () {
      final res = client.convertStrength(100.0, 'mg', '%');
      expect(res.uiStatus, MobileStrengthUiStatus.error);
      expect(res.errorCode, 'ERR_INCOMPATIBLE_UNIT_CONVERSION');
    });

    test('P123-M5: Parses standard strength strings (e.g. 500 mg, 250mg/5mL, 0.5%)', () {
      final p1 = client.parseStrength('500 mg');
      expect(p1.numericValue, 500.0);
      expect(p1.unit, 'mg');
      expect(p1.family, MobileMeasurementFamily.mass);
      expect(p1.isComposite, isFalse);

      final p2 = client.parseStrength('250mg/5ml');
      expect(p2.numericValue, 250.0);
      expect(p2.unit, 'mg/5ml');
      expect(p2.family, MobileMeasurementFamily.concentration);

      final p3 = client.parseStrength('0.5%');
      expect(p3.numericValue, 0.5);
      expect(p3.unit, '%');
      expect(p3.family, MobileMeasurementFamily.percentage);
    });

    test('P123-M6: Composite strength strings parsed with composite flag (e.g. 500mg+65mg)', () {
      final comp = client.parseStrength('500mg+65mg');
      expect(comp.numericValue, 500.0);
      expect(comp.unit, 'mg');
      expect(comp.isComposite, isTrue);
    });

    test('P123-M7: Unknown unit rejected with ERR_UNKNOWN_STRENGTH_UNIT', () {
      final res = client.convertStrength(10.0, 'invalid_unit', 'mg');
      expect(res.uiStatus, MobileStrengthUiStatus.error);
      expect(res.errorCode, 'ERR_UNKNOWN_STRENGTH_UNIT');
    });
  });
}
