import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/catalog/mobile_medicine_editor_schema_client.dart';

void main() {
  group('P124 Mobile Medicine Editor Schema Tests', () {
    late MobileMedicineEditorSchemaClient client;

    setUp(() {
      client = MobileMedicineEditorSchemaClient();
    });

    test('P124-M1: Active schema loaded with standard sections and v1.0 versioning', () {
      final schema = client.activeSchema;
      expect(schema.schemaVersion, 'v1.0');
      expect(schema.isActive, isTrue);
      expect(schema.sections.length, 4);
    });

    test('P124-M2: Dynamic visibility handles conditional sections for TABLET vs SYRUP', () {
      final tablet = {'dosage_form': 'TABLET'};
      expect(client.isFieldVisible('strips_per_box', tablet), isTrue);
      expect(client.isFieldRequired('strips_per_box', tablet), isTrue);
      expect(client.isFieldVisible('volume_ml', tablet), isFalse);

      final syrup = {'dosage_form': 'SYRUP'};
      expect(client.isFieldVisible('strips_per_box', syrup), isFalse);
      expect(client.isFieldVisible('volume_ml', syrup), isTrue);
      expect(client.isFieldRequired('volume_ml', syrup), isTrue);
    });

    test('P124-M3: Valid tablet payload passes schema validation', () {
      final values = {
        'brand_name': 'Napa Extra',
        'generic_name': 'Paracetamol + Caffeine',
        'dosage_form': 'TABLET',
        'manufacturer': 'Beximco Pharmaceuticals Ltd.',
        'strength': '500mg+65mg',
        'strips_per_box': 20,
        'units_per_strip': 10,
      };

      final res = client.validateForm(values);
      expect(res.isValid, isTrue);
      expect(res.uiStatus, MobileEditorUiStatus.success);
      expect(res.schemaVersion, 'v1.0');
    });

    test('P124-M4: Incomplete basic payload fails validation with ERR_SCHEMA_VALIDATION_FAILED', () {
      final values = {
        'brand_name': '',
        'generic_name': 'Paracetamol',
        'dosage_form': 'TABLET',
      };

      final res = client.validateForm(values);
      expect(res.isValid, isFalse);
      expect(res.uiStatus, MobileEditorUiStatus.error);
      expect(res.errorCode, 'ERR_SCHEMA_VALIDATION_FAILED');
      expect(res.missingFields.contains('brand_name'), isTrue);
    });

    test('P124-M5: Missing conditional strip fields for TABLET fails with ERR_CONDITIONAL_FIELD_REQUIRED', () {
      final values = {
        'brand_name': 'Ace Plus',
        'generic_name': 'Paracetamol + Caffeine',
        'dosage_form': 'TABLET',
        'manufacturer': 'Square Pharmaceuticals Ltd.',
        'strength': '500mg+65mg',
      };

      final res = client.validateForm(values);
      expect(res.isValid, isFalse);
      expect(res.errorCode, 'ERR_CONDITIONAL_FIELD_REQUIRED');
      expect(res.missingFields.contains('strips_per_box'), isTrue);
    });

    test('P124-M6: Inverted cold-chain temperature range fails with ERR_INVALID_TEMPERATURE_RANGE', () {
      final values = {
        'brand_name': 'Insulin Glargine',
        'generic_name': 'Insulin Glargine',
        'dosage_form': 'INJECTION',
        'manufacturer': 'Novo Nordisk',
        'strength': '100 IU/mL',
        'is_cold_chain': true,
        'min_temperature_celsius': 10.0,
        'max_temperature_celsius': 5.0,
      };

      final res = client.validateForm(values);
      expect(res.isValid, isFalse);
      expect(res.errorCode, 'ERR_INVALID_TEMPERATURE_RANGE');
    });

    test('P124-M7: Pharmacy owner mutation blocked with PLATFORM_CATALOG_OWNERSHIP_PROTECTED', () {
      final res = client.attemptPublishSchema(
        callerRole: 'PHARMACY_OWNER',
        version: 'v2.0',
      );
      expect(res.isValid, isFalse);
      expect(res.uiStatus, MobileEditorUiStatus.permissionDenied);
      expect(res.errorCode, 'PLATFORM_CATALOG_OWNERSHIP_PROTECTED');
    });
  });
}
