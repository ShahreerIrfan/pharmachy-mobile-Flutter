// test/core/catalog/mobile_injection_vial_editor_client_test.dart
// Unit tests for MobileInjectionVialEditorClient (P144)

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/catalog/mobile_injection_vial_editor_client.dart';

void main() {
  group('MobileInjectionVialEditorClient Tests', () {
    late MobileInjectionVialEditorClient client;

    setUp(() {
      client = MobileInjectionVialEditorClient();
    });

    test('validatePayload accepts valid injection vial configuration', () {
      final payload = {
        'dosage_form': 'INJECTION_SOLUTION',
        'container_type': 'VIAL_SINGLE_DOSE',
        'strength_value': 100.0,
        'strength_unit': 'mg/ml',
        'fill_volume_ml': 2.0,
        'sterile_route': 'IV',
        'is_cold_chain_required': false,
      };

      final res = client.validatePayload(payload);
      expect(res.isValid, isTrue);
      expect(res.errorCode, isNull);
    });

    test('validatePayload rejects oral route for parenteral injectables', () {
      final payload = {
        'dosage_form': 'INJECTION_SOLUTION',
        'container_type': 'VIAL_SINGLE_DOSE',
        'strength_value': 100.0,
        'strength_unit': 'mg/ml',
        'fill_volume_ml': 2.0,
        'sterile_route': 'ORAL', // Non-parenteral
      };

      final res = client.validatePayload(payload);
      expect(res.isValid, isFalse);
      expect(res.errorCode, equals('ERR_INVALID_STERILE_ROUTE'));
    });

    test('validatePayload rejects solid oral packaging attributes', () {
      final payload = {
        'dosage_form': 'INJECTION_SOLUTION',
        'container_type': 'VIAL_SINGLE_DOSE',
        'strength_value': 100.0,
        'strength_unit': 'mg/ml',
        'fill_volume_ml': 2.0,
        'sterile_route': 'IV',
        'tablets_per_strip': 10, // Hidden solid field
      };

      final res = client.validatePayload(payload);
      expect(res.isValid, isFalse);
      expect(res.errorCode, equals('ERR_HIDDEN_FIELD_VALUE_REJECTED'));
    });

    test('validatePayload rejects invalid cold-chain temperature range (min >= max)', () {
      final payload = {
        'dosage_form': 'INJECTION_SUSPENSION',
        'container_type': 'VIAL_MULTI_DOSE',
        'strength_value': 100.0,
        'strength_unit': 'iu/ml',
        'fill_volume_ml': 10.0,
        'sterile_route': 'SC',
        'is_cold_chain_required': true,
        'min_storage_temp_celsius': 10.0,
        'max_storage_temp_celsius': 2.0,
      };

      final res = client.validatePayload(payload);
      expect(res.isValid, isFalse);
      expect(res.errorCode, equals('ERR_INVALID_TEMPERATURE_RANGE'));
    });

    test('validatePayload rejects preservative on single-dose glass ampoule', () {
      final payload = {
        'dosage_form': 'INJECTION_SOLUTION',
        'container_type': 'AMPOULE_GLASS',
        'strength_value': 50.0,
        'strength_unit': 'mg/ml',
        'fill_volume_ml': 1.0,
        'sterile_route': 'IM',
        'has_preservative': true, // Prohibited on single-dose ampoules
      };

      final res = client.validatePayload(payload);
      expect(res.isValid, isFalse);
      expect(res.errorCode, equals('ERR_SINGLE_DOSE_PRESERVATIVE_PROHIBITED'));
    });

    test('validatePayload enforces diluent requirements for lyophilized powder injections', () {
      final payload = {
        'dosage_form': 'INJECTION_POWDER_LYOPHILIZED',
        'container_type': 'VIAL_SINGLE_DOSE',
        'strength_value': 1.0,
        'strength_unit': 'g/vial',
        'fill_volume_ml': 10.0,
        'sterile_route': 'IV',
        'requires_diluent': true,
      };

      final res = client.validatePayload(payload);
      expect(res.isValid, isFalse);
      expect(res.errorCode, equals('ERR_DILUENT_REQUIRED'));

      payload['diluent_type'] = 'WATER_FOR_INJECTION';
      payload['diluent_volume_ml'] = 10.0;
      final passRes = client.validatePayload(payload);
      expect(passRes.isValid, isTrue);
    });

    test('validatePayload rejects invalid strength units', () {
      final payload = {
        'dosage_form': 'INJECTION_SOLUTION',
        'container_type': 'VIAL_SINGLE_DOSE',
        'strength_value': 100.0,
        'strength_unit': 'mg/tablet', // Invalid for injectables
        'fill_volume_ml': 2.0,
        'sterile_route': 'IV',
      };

      final res = client.validatePayload(payload);
      expect(res.isValid, isFalse);
      expect(res.errorCode, equals('ERR_INVALID_STRENGTH_UNIT'));
    });

    test('local caching and retrieval functions correctly', () {
      final config = MobileInjectionVialConfig(
        configId: 'ivc-ins-1',
        productId: 'prod-ins-1',
        brandName: 'Insulatard',
        genericName: 'Insulin NPH',
        tenantId: 'tn-1',
        dosageForm: 'INJECTION_SUSPENSION',
        containerType: 'VIAL_MULTI_DOSE',
        strengthValue: 100.0,
        strengthUnit: 'iu/ml',
        fillVolumeMl: 10.0,
        sterileRoute: 'SC',
        isColdChainRequired: true,
        minStorageTempCelsius: 2.0,
        maxStorageTempCelsius: 8.0,
        hasPreservative: true,
        requiresDiluent: false,
        diluentType: 'NONE',
        isActive: true,
      );

      client.putCache('ivc-ins-1', config);
      expect(client.getFromCache('ivc-ins-1'), isNotNull);
      expect(client.getFromCache('ivc-ins-1')!.brandName, equals('Insulatard'));
      expect(client.getAllCached().length, equals(1));

      client.clearCache();
      expect(client.getFromCache('ivc-ins-1'), isNull);
    });

    test('bilingual label helper returns expected strings', () {
      expect(client.getLabel('container_type', 'en'), equals('Container Type'));
      expect(client.getLabel('container_type', 'bn'), equals('কনটেইনারের ধরন'));
      expect(client.getLabel('sterile_route', 'en'), equals('Sterile Route'));
      expect(client.getLabel('sterile_route', 'bn'), equals('প্রয়োগের স্টেরাইল রুট'));
      expect(client.getLabel('is_cold_chain_required', 'en'), equals('Cold-Chain Required'));
      expect(client.getLabel('is_cold_chain_required', 'bn'), equals('কোল্ড চেইন আবশ্যক'));
    });

    test('toJson and fromJson maintain data integrity', () {
      final map = {
        'config_id': 'ivc-123',
        'product_id': 'prod-123',
        'brand_name': 'Rocphin 1g',
        'generic_name': 'Ceftriaxone',
        'tenant_id': 'tn-1',
        'dosage_form': 'INJECTION_POWDER_LYOPHILIZED',
        'container_type': 'VIAL_SINGLE_DOSE',
        'strength_value': 1.0,
        'strength_unit': 'g/vial',
        'fill_volume_ml': 10.0,
        'sterile_route': 'IV',
        'is_cold_chain_required': false,
        'has_preservative': false,
        'requires_diluent': true,
        'diluent_type': 'WATER_FOR_INJECTION',
        'diluent_volume_ml': 10.0,
        'is_active': true,
      };

      final config = MobileInjectionVialConfig.fromJson(map);
      expect(config.configId, equals('ivc-123'));
      expect(config.strengthValue, equals(1.0));
      expect(config.diluentType, equals('WATER_FOR_INJECTION'));

      final serialized = config.toJson();
      expect(serialized['config_id'], equals('ivc-123'));
      expect(serialized['diluent_type'], equals('WATER_FOR_INJECTION'));
    });
  });
}
