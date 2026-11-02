import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/catalog/mobile_dynamic_condition_evaluator.dart';

void main() {
  group('P125 Mobile Dynamic Condition Evaluator Tests', () {
    late MobileDynamicConditionEvaluator evaluator;

    setUp(() {
      evaluator = MobileDynamicConditionEvaluator();
    });

    test('P125-M1: Valid tablet evaluation resolves active and hidden fields', () {
      final payload = {
        'brand_name': 'Napa Extra',
        'generic_name': 'Paracetamol + Caffeine',
        'dosage_form': 'TABLET',
        'manufacturer': 'Beximco',
        'strength': '500mg+65mg',
        'strips_per_box': 20,
        'units_per_strip': 10,
        'is_cold_chain': false,
      };

      final res = evaluator.evaluateAndValidate(payload, strictHiddenCheck: true);
      expect(res.isValid, isTrue);
      expect(res.uiStatus, MobileEvaluationUiStatus.success);
      expect(res.activeFields.contains('strips_per_box'), isTrue);
      expect(res.hiddenFields.contains('volume_ml'), isTrue);
      expect(res.hiddenFields.contains('min_temperature_celsius'), isTrue);
      expect(res.sanitizedPayload['volume_ml'], isNull);
    });

    test('P125-M2: Zero-Trust Guard strictly rejects data submitted in hidden fields', () {
      final payload = {
        'brand_name': 'Tusca Syrup',
        'generic_name': 'Dextromethorphan',
        'dosage_form': 'SYRUP',
        'manufacturer': 'Square',
        'strength': '10mg/5mL',
        'volume_ml': 100.0,
        'strips_per_box': 10, // Hidden field!
      };

      final res = evaluator.evaluateAndValidate(payload, strictHiddenCheck: true);
      expect(res.isValid, isFalse);
      expect(res.uiStatus, MobileEvaluationUiStatus.error);
      expect(res.errorCode, 'ERR_HIDDEN_FIELD_VALUE_REJECTED');
      expect(res.messageEn.contains('strips_per_box'), isTrue);
    });

    test('P125-M3: Zero-Trust Guard prunes hidden fields safely when non-strict sanitization requested', () {
      final payload = {
        'brand_name': 'Tusca Syrup',
        'generic_name': 'Dextromethorphan',
        'dosage_form': 'SYRUP',
        'manufacturer': 'Square',
        'strength': '10mg/5mL',
        'volume_ml': 100.0,
        'strips_per_box': 10,
      };

      final res = evaluator.evaluateAndValidate(payload, strictHiddenCheck: false);
      expect(res.isValid, isTrue);
      expect(res.prunedHiddenFields.contains('strips_per_box'), isTrue);
      expect(res.sanitizedPayload['strips_per_box'], isNull);
    });

    test('P125-M4: Ambient medicine with is_cold_chain=false rejects hidden temperature data', () {
      final payload = {
        'brand_name': 'Napa 500',
        'generic_name': 'Paracetamol',
        'dosage_form': 'TABLET',
        'manufacturer': 'Beximco',
        'strength': '500mg',
        'strips_per_box': 20,
        'units_per_strip': 10,
        'is_cold_chain': false,
        'min_temperature_celsius': 2.0,
      };

      final res = evaluator.evaluateAndValidate(payload, strictHiddenCheck: true);
      expect(res.isValid, isFalse);
      expect(res.errorCode, 'ERR_HIDDEN_FIELD_VALUE_REJECTED');
    });

    test('P125-M5: Type safety checks invalid negative number range', () {
      final payload = {
        'brand_name': 'Ace Plus',
        'generic_name': 'Paracetamol',
        'dosage_form': 'TABLET',
        'manufacturer': 'Square',
        'strength': '500mg',
        'strips_per_box': -5,
        'units_per_strip': 10,
      };

      final res = evaluator.evaluateAndValidate(payload, strictHiddenCheck: true);
      expect(res.isValid, isFalse);
      expect(res.errorCode, 'ERR_INVALID_NUMBER_RANGE');
    });

    test('P125-M6: Invalid select option fails taxonomy validation', () {
      final payload = {
        'brand_name': 'Ace Plus',
        'generic_name': 'Paracetamol',
        'dosage_form': 'UNKNOWN_DOSAGE_FORM',
        'manufacturer': 'Square',
        'strength': '500mg',
      };

      final res = evaluator.evaluateAndValidate(payload, strictHiddenCheck: true);
      expect(res.isValid, isFalse);
      expect(res.errorCode, 'ERR_INVALID_SELECT_OPTION');
    });
  });
}
