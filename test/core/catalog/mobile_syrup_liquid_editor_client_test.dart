// test/core/catalog/mobile_syrup_liquid_editor_client_test.dart
// Unit tests for MobileSyrupLiquidEditorClient (P142)

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/catalog/mobile_syrup_liquid_editor_client.dart';

void main() {
  group('MobileSyrupLiquidEditorClient Tests', () {
    late MobileSyrupLiquidEditorClient client;

    setUp(() {
      client = MobileSyrupLiquidEditorClient();
    });

    test('validatePayload accepts valid syrup configuration', () {
      final payload = {
        'dosage_form': 'SYRUP',
        'concentration_value': 120.0,
        'concentration_unit': 'mg/5ml',
        'bottle_volume_ml': 60.0,
        'sale_unit': 'Bottle',
        'route': 'Oral',
        'storage_policy': 'ROOM_TEMPERATURE_BELOW_30C',
      };

      final res = client.validatePayload(payload);
      expect(res.isValid, isTrue);
      expect(res.errorCode, isNull);
    });

    test('validatePayload rejects standalone mass unit with ERR_INVALID_STRENGTH_DIMENSION_FOR_LIQUID', () {
      final payload = {
        'dosage_form': 'SYRUP',
        'concentration_value': 500.0,
        'concentration_unit': 'mg', // Invalid dimension!
        'bottle_volume_ml': 100.0,
        'sale_unit': 'Bottle',
        'route': 'Oral',
        'storage_policy': 'ROOM_TEMPERATURE_BELOW_30C',
      };

      final res = client.validatePayload(payload);
      expect(res.isValid, isFalse);
      expect(res.errorCode, equals('ERR_INVALID_STRENGTH_DIMENSION_FOR_LIQUID'));
    });

    test('validatePayload rejects solid tablet packaging field tablets_per_strip', () {
      final payload = {
        'dosage_form': 'SYRUP',
        'concentration_value': 120.0,
        'concentration_unit': 'mg/5ml',
        'bottle_volume_ml': 60.0,
        'sale_unit': 'Bottle',
        'route': 'Oral',
        'storage_policy': 'ROOM_TEMPERATURE_BELOW_30C',
        'tablets_per_strip': 10, // Hidden solid field!
      };

      final res = client.validatePayload(payload);
      expect(res.isValid, isFalse);
      expect(res.errorCode, equals('ERR_HIDDEN_FIELD_VALUE_REJECTED'));
    });

    test('validatePayload rejects bottle volume <= 0', () {
      final payload = {
        'dosage_form': 'SYRUP',
        'concentration_value': 120.0,
        'concentration_unit': 'mg/5ml',
        'bottle_volume_ml': 0.0,
        'sale_unit': 'Bottle',
        'route': 'Oral',
        'storage_policy': 'ROOM_TEMPERATURE_BELOW_30C',
      };

      final res = client.validatePayload(payload);
      expect(res.isValid, isFalse);
      expect(res.errorCode, equals('ERR_INVALID_BOTTLE_VOLUME'));
    });

    test('validatePayload rejects solid sale unit Strip for liquid', () {
      final payload = {
        'dosage_form': 'SYRUP',
        'concentration_value': 120.0,
        'concentration_unit': 'mg/5ml',
        'bottle_volume_ml': 60.0,
        'sale_unit': 'Strip', // Invalid sale unit!
        'route': 'Oral',
        'storage_policy': 'ROOM_TEMPERATURE_BELOW_30C',
      };

      final res = client.validatePayload(payload);
      expect(res.isValid, isFalse);
      expect(res.errorCode, equals('ERR_INVALID_SALE_UNIT_FOR_LIQUID'));
    });

    test('validatePayload rejects non-oral route Intravenous', () {
      final payload = {
        'dosage_form': 'SYRUP',
        'concentration_value': 120.0,
        'concentration_unit': 'mg/5ml',
        'bottle_volume_ml': 60.0,
        'sale_unit': 'Bottle',
        'route': 'Intravenous', // Invalid route!
        'storage_policy': 'ROOM_TEMPERATURE_BELOW_30C',
      };

      final res = client.validatePayload(payload);
      expect(res.isValid, isFalse);
      expect(res.errorCode, equals('ERR_INVALID_ROUTE_FOR_DOSAGE_FORM'));
    });

    test('validatePayload enforces reconstitution water on dry syrup', () {
      final payload = {
        'dosage_form': 'DRY_SYRUP_RECONSTITUTED',
        'concentration_value': 125.0,
        'concentration_unit': 'mg/5ml',
        'bottle_volume_ml': 100.0,
        'sale_unit': 'Bottle',
        'route': 'Oral',
        'storage_policy': 'REFRIGERATE_AFTER_RECONSTITUTION_2_8C',
        'is_reconstitution_required': true,
      };

      final res = client.validatePayload(payload);
      expect(res.isValid, isFalse);
      expect(res.errorCode, equals('ERR_RECONSTITUTION_WATER_REQUIRED'));

      payload['reconstitution_water_ml'] = 75.0;
      final resOk = client.validatePayload(payload);
      expect(resOk.isValid, isTrue);
    });

    test('MobileSyrupLiquidConfig serialization and caching', () {
      final config = MobileSyrupLiquidConfig(
        configId: 'slc-napa-syr',
        productId: 'prod-napa-syr',
        brandName: 'Napa Syrup 60mL',
        genericName: 'Paracetamol',
        dosageForm: 'SYRUP',
        concentrationValue: 120.0,
        concentrationUnit: 'mg/5ml',
        bottleVolumeMl: 60.0,
        saleUnit: 'Bottle',
        route: 'Oral',
        storagePolicy: 'ROOM_TEMPERATURE_BELOW_30C',
        measuringDevice: 'MEASURING_CUP',
        isReconstitutionRequired: false,
        flavor: 'Strawberry',
        isActive: true,
      );

      final map = config.toJson();
      expect(map['config_id'], equals('slc-napa-syr'));
      expect(map['bottle_volume_ml'], equals(60.0));

      final restored = MobileSyrupLiquidConfig.fromJson(map);
      expect(restored.brandName, equals('Napa Syrup 60mL'));
      expect(restored.concentrationUnit, equals('mg/5ml'));

      client.cacheConfig(restored);
      final cached = client.getCachedConfig('prod-napa-syr');
      expect(cached, isNotNull);
      expect(cached?.bottleVolumeMl, equals(60.0));
      expect(client.getLocalConfigs().length, equals(1));
    });

    test('bilingual labels presentation', () {
      expect(client.getLabel('bottle_volume_ml', 'en'), equals('Bottle Volume (mL)'));
      expect(client.getLabel('bottle_volume_ml', 'bn'), equals('বোতলের আয়তন (মি.লি.)'));
      expect(client.getLabel('concentration_unit', 'en'), equals('Concentration Unit'));
      expect(client.getLabel('concentration_unit', 'bn'), equals('ঘনমাত্রার একক'));
    });
  });
}
