import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/forms/mobile_dynamic_medicine_form_engine.dart';

void main() {
  group('MobileDynamicMedicineFormEngine Tests (P157)', () {
    late MobileDynamicMedicineFormEngine engine;

    setUp(() {
      engine = MobileDynamicMedicineFormEngine('TABLET_CAPSULE');
    });

    test('1. Dosage form switching retains common fields and caches form-specific parameters', () {
      engine.setFieldValue('brand_name', 'Napa Extra');
      engine.setFieldValue('brand_name_bn', 'নাপা এক্সট্রা');
      engine.setFieldValue('generic_name', 'Paracetamol + Caffeine');
      engine.setFieldValue('dar_number', '012-345-678');
      engine.setFieldValue('cost_unit', 2.10);
      engine.setFieldValue('mrp_unit', 3.00);
      engine.setFieldValue('pieces_per_strip', 10);
      engine.setFieldValue('strips_per_pack', 10);
      engine.setFieldValue('total_pieces_per_pack', 100);

      // Switch to INHALER
      engine.switchDosageForm('INHALER');
      expect(engine.currentDosageForm, equals('INHALER'));

      // Common fields must persist
      expect(engine.getFieldValue('brand_name'), equals('Napa Extra'));
      expect(engine.getFieldValue('brand_name_bn'), equals('নাপা এক্সট্রা'));
      expect(engine.getFieldValue('generic_name'), equals('Paracetamol + Caffeine'));
      expect(engine.getFieldValue('dar_number'), equals('012-345-678'));
      expect(engine.getFieldValue('cost_unit'), equals(2.10));
      expect(engine.getFieldValue('mrp_unit'), equals(3.00));

      // Specific fields removed from current
      expect(engine.getFieldValue('pieces_per_strip'), isNull);

      // Cached in retainedFormCache
      expect(engine.retainedFormCache.containsKey('TABLET_CAPSULE'), isTrue);
      expect(engine.retainedFormCache['TABLET_CAPSULE']!['pieces_per_strip'], equals(10));

      // Enter inhaler specifics
      engine.setFieldValue('dose_per_actuation', '100mcg');
      engine.setFieldValue('actuations_per_device', 200);

      // Switch back to TABLET_CAPSULE
      engine.switchDosageForm('TABLET_CAPSULE');
      expect(engine.currentDosageForm, equals('TABLET_CAPSULE'));

      // Common fields still exist
      expect(engine.getFieldValue('brand_name'), equals('Napa Extra'));

      // Restored from cache!
      expect(engine.getFieldValue('pieces_per_strip'), equals(10));
      expect(engine.getFieldValue('strips_per_pack'), equals(10));
      expect(engine.getFieldValue('total_pieces_per_pack'), equals(100));

      // Inhaler cached
      expect(engine.retainedFormCache.containsKey('INHALER'), isTrue);
      expect(engine.retainedFormCache['INHALER']!['dose_per_actuation'], equals('100mcg'));
    });

    test('2. Inline errors generated for missing mandatory fields', () {
      final errors = engine.validateFormData();
      expect(errors, isNotEmpty);

      final errorFields = errors.map((e) => e.fieldName).toList();
      expect(errorFields, contains('brand_name'));
      expect(errorFields, contains('generic_name'));
      expect(errorFields, contains('dar_number'));
      expect(errorFields, contains('cost_unit'));
      expect(errorFields, contains('mrp_unit'));
    });

    test('3. Pricing rules detect negative cost, zero MRP, and MRP below cost', () {
      engine.setFieldValue('brand_name', 'Azithromycin');
      engine.setFieldValue('generic_name', 'Azithromycin');
      engine.setFieldValue('dar_number', '001-002-003');

      // Negative cost
      engine.setFieldValue('cost_unit', -10);
      engine.setFieldValue('mrp_unit', 15);
      var errors = engine.validateFormData();
      expect(errors.any((e) => e.errorCode == 'ERR_NEGATIVE_COST'), isTrue);

      // Zero MRP
      engine.setFieldValue('cost_unit', 10);
      engine.setFieldValue('mrp_unit', 0);
      errors = engine.validateFormData();
      expect(errors.any((e) => e.errorCode == 'ERR_INVALID_MRP'), isTrue);

      // MRP below cost
      engine.setFieldValue('cost_unit', 20);
      engine.setFieldValue('mrp_unit', 18);
      errors = engine.validateFormData();
      expect(errors.any((e) => e.errorCode == 'ERR_MRP_BELOW_COST'), isTrue);
    });

    test('4. Packaging dimension mismatch error', () {
      engine.setFieldValue('brand_name', 'Seclo 20');
      engine.setFieldValue('generic_name', 'Omeprazole');
      engine.setFieldValue('dar_number', '001-222-333');
      engine.setFieldValue('cost_unit', 4.00);
      engine.setFieldValue('mrp_unit', 6.00);

      engine.setFieldValue('pieces_per_strip', 10);
      engine.setFieldValue('strips_per_pack', 10);
      engine.setFieldValue('total_pieces_per_pack', 80); // Mismatch: 10 * 10 != 80

      final errors = engine.validateFormData();
      expect(errors.any((e) => e.errorCode == 'ERR_DIMENSION_MISMATCH'), isTrue);
    });

    test('5. Storage temperature range ordering error', () {
      engine.setFieldValue('brand_name', 'Insulin');
      engine.setFieldValue('generic_name', 'Insulin Glargine');
      engine.setFieldValue('dar_number', '007-888-999');
      engine.setFieldValue('cost_unit', 500);
      engine.setFieldValue('mrp_unit', 600);

      engine.setFieldValue('storage_temperature_celsius_min', 25);
      engine.setFieldValue('storage_temperature_celsius_max', 8);

      final errors = engine.validateFormData();
      expect(errors.any((e) => e.errorCode == 'ERR_INVALID_TEMPERATURE_RANGE'), isTrue);
    });

    test('6. Formulation-specific validation for INHALER and DROPS', () {
      engine.setFieldValue('brand_name', 'Ventolin');
      engine.setFieldValue('generic_name', 'Salbutamol');
      engine.setFieldValue('dar_number', '001-002-003');
      engine.setFieldValue('cost_unit', 100);
      engine.setFieldValue('mrp_unit', 150);

      engine.switchDosageForm('INHALER');
      var errors = engine.validateFormData();
      expect(errors.any((e) => e.fieldName == 'dose_per_actuation'), isTrue);
      expect(errors.any((e) => e.fieldName == 'actuations_per_device'), isTrue);

      engine.setFieldValue('dose_per_actuation', '100mcg');
      engine.setFieldValue('actuations_per_device', 200);
      errors = engine.validateFormData();
      expect(errors, isEmpty);

      engine.switchDosageForm('DROPS');
      errors = engine.validateFormData();
      expect(errors.any((e) => e.fieldName == 'volume_ml'), isTrue);
      expect(errors.any((e) => e.fieldName == 'drop_category'), isTrue);
    });

    test('7. RBAC restricts Cashier from submitting forms', () {
      engine.setFieldValue('brand_name', 'Napa 500');
      engine.setFieldValue('generic_name', 'Paracetamol');
      engine.setFieldValue('dar_number', '001-001-001');
      engine.setFieldValue('cost_unit', 1.00);
      engine.setFieldValue('mrp_unit', 1.50);

      expect(engine.canMutateForm('CASHIER'), isFalse);
      var submitted = engine.submitForm('CASHIER');
      expect(submitted, isFalse);
      expect(engine.uiStatus, equals(MobileUiStatus.permissionDenied));

      expect(engine.canMutateForm('STAFF_PHARMACIST'), isTrue);
      submitted = engine.submitForm('STAFF_PHARMACIST');
      expect(submitted, isTrue);
      expect(engine.uiStatus, equals(MobileUiStatus.success));
    });
  });
}
