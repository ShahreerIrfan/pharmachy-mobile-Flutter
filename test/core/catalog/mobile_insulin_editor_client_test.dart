// test/core/catalog/mobile_insulin_editor_client_test.dart
// Unit tests for MobileInsulinEditorClient (P145)

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/catalog/mobile_insulin_editor_client.dart';

void main() {
  group('MobileInsulinEditorClient Tests', () {
    late MobileInsulinEditorClient client;

    setUp(() {
      client = MobileInsulinEditorClient();
    });

    test('validatePayload accepts valid insulin configuration', () {
      final payload = {
        'action_category': 'PREMIXED_BIPHASIC',
        'delivery_device': 'PEN_DISPOSABLE',
        'concentration_iu_per_ml': 100,
        'volume_ml': 3.0,
        'total_units': 300,
        'in_use_shelf_life_days': 28,
        'excursion_action': 'QUARANTINE_FOR_PHARMACIST_ASSESSMENT',
      };

      final res = client.validatePayload(payload);
      expect(res.isValid, isTrue);
      expect(res.errorCode, isNull);
    });

    test('validatePayload rejects dimension consistency mismatch (total_units != conc * vol)', () {
      final payload = {
        'action_category': 'PREMIXED_BIPHASIC',
        'delivery_device': 'PEN_DISPOSABLE',
        'concentration_iu_per_ml': 100,
        'volume_ml': 3.0,
        'total_units': 400, // Mismatch! 100 * 3.0 = 300 != 400
        'in_use_shelf_life_days': 28,
        'excursion_action': 'QUARANTINE_FOR_PHARMACIST_ASSESSMENT',
      };

      final res = client.validatePayload(payload);
      expect(res.isValid, isFalse);
      expect(res.errorCode, equals('ERR_DIMENSION_CONSISTENCY_MISMATCH'));
    });

    test('validatePayload rejects solid oral packaging attributes', () {
      final payload = {
        'action_category': 'PREMIXED_BIPHASIC',
        'delivery_device': 'PEN_DISPOSABLE',
        'concentration_iu_per_ml': 100,
        'volume_ml': 3.0,
        'total_units': 300,
        'in_use_shelf_life_days': 28,
        'excursion_action': 'QUARANTINE_FOR_PHARMACIST_ASSESSMENT',
        'strips_per_box': 5, // Prohibited solid field
      };

      final res = client.validatePayload(payload);
      expect(res.isValid, isFalse);
      expect(res.errorCode, equals('ERR_HIDDEN_FIELD_VALUE_REJECTED'));
    });

    test('validatePayload rejects invalid insulin concentration', () {
      final payload = {
        'action_category': 'PREMIXED_BIPHASIC',
        'delivery_device': 'PEN_DISPOSABLE',
        'concentration_iu_per_ml': 150, // Invalid concentration
        'volume_ml': 3.0,
        'total_units': 450,
        'in_use_shelf_life_days': 28,
        'excursion_action': 'QUARANTINE_FOR_PHARMACIST_ASSESSMENT',
      };

      final res = client.validatePayload(payload);
      expect(res.isValid, isFalse);
      expect(res.errorCode, equals('ERR_INVALID_INSULIN_CONCENTRATION'));
    });

    test('validatePayload rejects out-of-bounds in-use shelf life (must be 14 - 56 days)', () {
      final payload = {
        'action_category': 'PREMIXED_BIPHASIC',
        'delivery_device': 'PEN_DISPOSABLE',
        'concentration_iu_per_ml': 100,
        'volume_ml': 3.0,
        'total_units': 300,
        'in_use_shelf_life_days': 10, // Below 14 days
        'excursion_action': 'QUARANTINE_FOR_PHARMACIST_ASSESSMENT',
      };

      final resLow = client.validatePayload(payload);
      expect(resLow.isValid, isFalse);
      expect(resLow.errorCode, equals('ERR_INVALID_IN_USE_SHELF_LIFE'));

      payload['in_use_shelf_life_days'] = 65; // Above 56 days
      final resHigh = client.validatePayload(payload);
      expect(resHigh.isValid, isFalse);
      expect(resHigh.errorCode, equals('ERR_INVALID_IN_USE_SHELF_LIFE'));
    });

    test('calculateTotalUnits computes accurate count', () {
      expect(client.calculateTotalUnits(100, 3.0), equals(300));
      expect(client.calculateTotalUnits(100, 10.0), equals(1000));
      expect(client.calculateTotalUnits(200, 3.0), equals(600));
    });

    test('local caching and retrieval functions correctly', () {
      final config = MobileInsulinConfig(
        configId: 'ins-novo-1',
        productId: 'prod-novo-1',
        brandName: 'NovoMix 30 FlexPen',
        genericName: 'Biphasic Insulin Aspart',
        tenantId: 'tn-1',
        actionCategory: 'PREMIXED_BIPHASIC',
        deliveryDevice: 'PEN_DISPOSABLE',
        concentrationIuPerMl: 100,
        volumeMl: 3.0,
        totalUnits: 300,
        inUseShelfLifeDays: 28,
        unopenedMinTempCelsius: 2.0,
        unopenedMaxTempCelsius: 8.0,
        inUseMaxTempCelsius: 30.0,
        excursionAction: 'QUARANTINE_FOR_PHARMACIST_ASSESSMENT',
        patientCounselingEn: 'Store in fridge.',
        patientCounselingBn: 'ফ্রিজে রাখুন।',
        isActive: true,
      );

      client.putCache('ins-novo-1', config);
      expect(client.getFromCache('ins-novo-1'), isNotNull);
      expect(client.getFromCache('ins-novo-1')!.brandName, equals('NovoMix 30 FlexPen'));
      expect(client.getAllCached().length, equals(1));

      client.clearCache();
      expect(client.getFromCache('ins-novo-1'), isNull);
    });

    test('bilingual label helper returns expected strings', () {
      expect(client.getLabel('action_category', 'en'), equals('Action Profile'));
      expect(client.getLabel('action_category', 'bn'), equals('কার্যকারিতার ধরন'));
      expect(client.getLabel('total_units', 'en'), equals('Total Units (IU)'));
      expect(client.getLabel('total_units', 'bn'), equals('মোট সক্রিয় ইউনিট (আইইউ)'));
      expect(client.getLabel('excursion_action', 'en'), equals('Excursion Protocol'));
      expect(client.getLabel('excursion_action', 'bn'), equals('তাপমাত্রা বিচ্যুতিতে করণীয়'));
    });

    test('toJson and fromJson maintain data integrity', () {
      final map = {
        'config_id': 'ins-123',
        'product_id': 'prod-123',
        'brand_name': 'Lantus Solostar',
        'generic_name': 'Insulin Glargine',
        'tenant_id': 'tn-1',
        'action_category': 'LONG_ACTING_ANALOG',
        'delivery_device': 'PEN_DISPOSABLE',
        'concentration_iu_per_ml': 100,
        'volume_ml': 3.0,
        'total_units': 300,
        'in_use_shelf_life_days': 28,
        'unopened_min_temp_celsius': 2.0,
        'unopened_max_temp_celsius': 8.0,
        'in_use_max_temp_celsius': 30.0,
        'excursion_action': 'QUARANTINE_FOR_PHARMACIST_ASSESSMENT',
        'patient_counseling_en': '',
        'patient_counseling_bn': '',
        'is_active': true,
      };

      final config = MobileInsulinConfig.fromJson(map);
      expect(config.configId, equals('ins-123'));
      expect(config.totalUnits, equals(300));
      expect(config.actionCategory, equals('LONG_ACTING_ANALOG'));

      final serialized = config.toJson();
      expect(serialized['config_id'], equals('ins-123'));
      expect(serialized['total_units'], equals(300));
    });
  });
}

