// test/core/catalog/mobile_tablet_capsule_editor_client_test.dart
// Unit tests for MobileTabletCapsuleEditorClient (P141)

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/catalog/mobile_tablet_capsule_editor_client.dart';

void main() {
  group('MobileTabletCapsuleEditorClient Tests', () {
    late MobileTabletCapsuleEditorClient client;

    setUp(() {
      client = MobileTabletCapsuleEditorClient();
    });

    test('calculateBoxSize computes product of strip and unit counts', () {
      expect(client.calculateBoxSize(10, 10), equals(100));
      expect(client.calculateBoxSize(12, 20), equals(240));
      expect(client.calculateBoxSize(0, 10), equals(0));
    });

    test('validatePayload accepts valid tablet configuration', () {
      final payload = {
        'dosage_form': 'TABLET',
        'dose_strength': 500.0,
        'strength_unit': 'mg',
        'tablets_per_strip': 10,
        'strips_per_box': 10,
        'box_size': 100,
        'loose_sale_eligible': true,
        'route': 'Oral',
        'storage_policy': 'ROOM_TEMPERATURE_DRY',
      };

      final res = client.validatePayload(payload);
      expect(res.isValid, isTrue);
      expect(res.errorCode, isNull);
      expect(res.computedBoxSize, equals(100));
    });

    test('validatePayload rejects dimension mismatch with ERR_DIMENSION_CONSISTENCY_MISMATCH', () {
      final payload = {
        'dosage_form': 'TABLET',
        'dose_strength': 500.0,
        'strength_unit': 'mg',
        'tablets_per_strip': 10,
        'strips_per_box': 10,
        'box_size': 130, // Discrepancy!
        'loose_sale_eligible': true,
        'route': 'Oral',
        'storage_policy': 'ROOM_TEMPERATURE_DRY',
      };

      final res = client.validatePayload(payload);
      expect(res.isValid, isFalse);
      expect(res.errorCode, equals('ERR_DIMENSION_CONSISTENCY_MISMATCH'));
    });

    test('validatePayload rejects effervescent tablet with loose sale enabled', () {
      final payload = {
        'dosage_form': 'EFFERVESCENT_TABLET',
        'dose_strength': 1000.0,
        'strength_unit': 'mg',
        'tablets_per_strip': 10,
        'strips_per_box': 2,
        'box_size': 20,
        'loose_sale_eligible': true, // Prohibited!
        'route': 'Effervescent',
        'storage_policy': 'PROTECT_FROM_MOISTURE_LIGHT',
      };

      final res = client.validatePayload(payload);
      expect(res.isValid, isFalse);
      expect(res.errorCode, equals('ERR_LOOSE_SALE_NOT_PERMITTED'));

      // Succeeds when loose_sale_eligible is false
      payload['loose_sale_eligible'] = false;
      final resOk = client.validatePayload(payload);
      expect(resOk.isValid, isTrue);
    });

    test('validatePayload rejects hidden liquid field volume_ml', () {
      final payload = {
        'dosage_form': 'TABLET',
        'dose_strength': 500.0,
        'strength_unit': 'mg',
        'tablets_per_strip': 10,
        'strips_per_box': 10,
        'box_size': 100,
        'loose_sale_eligible': true,
        'route': 'Oral',
        'storage_policy': 'ROOM_TEMPERATURE_DRY',
        'volume_ml': 100.0, // Hidden field!
      };

      final res = client.validatePayload(payload);
      expect(res.isValid, isFalse);
      expect(res.errorCode, equals('ERR_HIDDEN_FIELD_VALUE_REJECTED'));
    });

    test('validatePayload rejects invalid route for tablet form', () {
      final payload = {
        'dosage_form': 'TABLET',
        'dose_strength': 500.0,
        'strength_unit': 'mg',
        'tablets_per_strip': 10,
        'strips_per_box': 10,
        'box_size': 100,
        'loose_sale_eligible': true,
        'route': 'Intravenous', // Invalid route!
        'storage_policy': 'ROOM_TEMPERATURE_DRY',
      };

      final res = client.validatePayload(payload);
      expect(res.isValid, isFalse);
      expect(res.errorCode, equals('ERR_INVALID_ROUTE_FOR_DOSAGE_FORM'));
    });

    test('MobileTabletCapsuleConfig serialization and caching', () {
      final config = MobileTabletCapsuleConfig(
        configId: 'tcc-napa-500',
        productId: 'prod-napa-500',
        brandName: 'Napa 500mg',
        genericName: 'Paracetamol',
        dosageForm: 'TABLET',
        doseStrength: 500.0,
        strengthUnit: 'mg',
        tabletsPerStrip: 10,
        stripsPerBox: 10,
        boxSize: 100,
        looseSaleEligible: true,
        route: 'Oral',
        storagePolicy: 'ROOM_TEMPERATURE_DRY',
        isScored: true,
        coatingType: 'FILM_COATED',
        isActive: true,
      );

      final map = config.toJson();
      expect(map['config_id'], equals('tcc-napa-500'));
      expect(map['box_size'], equals(100));

      final restored = MobileTabletCapsuleConfig.fromJson(map);
      expect(restored.brandName, equals('Napa 500mg'));
      expect(restored.looseSaleEligible, isTrue);

      client.cacheConfig(restored);
      final cached = client.getCachedConfig('prod-napa-500');
      expect(cached, isNotNull);
      expect(cached?.boxSize, equals(100));
      expect(client.getLocalConfigs().length, equals(1));
    });

    test('bilingual labels presentation', () {
      expect(client.getLabel('tablets_per_strip', 'en'), equals('Tablets Per Strip'));
      expect(client.getLabel('tablets_per_strip', 'bn'), equals('পাতা প্রতি ট্যাবলেট'));
      expect(client.getLabel('loose_sale_eligible', 'en'), equals('Loose Sale Eligible'));
      expect(client.getLabel('loose_sale_eligible', 'bn'), equals('খুচরা বিক্রয়যোগ্য'));
    });
  });
}
