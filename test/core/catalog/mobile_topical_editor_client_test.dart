// test/core/catalog/mobile_topical_editor_client_test.dart
// Unit tests for MobileTopicalEditorClient (P148)

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/catalog/mobile_topical_editor_client.dart';

void main() {
  group('MobileTopicalEditorClient Tests', () {
    test('validateDraftPayload accepts valid topical cream configuration', () {
      final payload = {
        'product_id': 'prod-001',
        'formulation_type': 'CREAM',
        'administration_route': 'TOPICAL_CUTANEOUS',
        'container_type': 'TUBE_ALUMINUM',
        'net_weight_grams': 15.0,
        'concentration_value': 1.0,
        'concentration_unit': 'PERCENT_W_W',
        'is_sterile': false,
        'opened_shelf_life_days': 28,
        'storage_condition': 'ROOM_15_25',
      };

      final res = MobileTopicalEditorClient.validateDraftPayload(payload);
      expect(res.isValid, isTrue);
      expect(res.errorCode, isNull);
    });

    test('validateDraftPayload rejects solid oral packaging attributes', () {
      final payload = {
        'product_id': 'prod-001',
        'formulation_type': 'OINTMENT',
        'administration_route': 'TOPICAL_CUTANEOUS',
        'container_type': 'TUBE_ALUMINUM',
        'net_weight_grams': 15.0,
        'concentration_value': 2.0,
        'strips_per_box': 5, // Prohibited solid field
      };

      final res = MobileTopicalEditorClient.validateDraftPayload(payload);
      expect(res.isValid, isFalse);
      expect(res.errorCode, equals('ERR_HIDDEN_FIELD_VALUE_REJECTED'));
    });

    test('validateDraftPayload rejects needle gauge field', () {
      final payload = {
        'product_id': 'prod-001',
        'formulation_type': 'GEL',
        'administration_route': 'TOPICAL_CUTANEOUS',
        'container_type': 'TUBE_PLASTIC',
        'net_weight_grams': 20.0,
        'concentration_value': 1.0,
        'needle_gauge': '27G', // Prohibited injectable field
      };

      final res = MobileTopicalEditorClient.validateDraftPayload(payload);
      expect(res.isValid, isFalse);
      expect(res.errorCode, equals('ERR_HIDDEN_FIELD_VALUE_REJECTED'));
    });

    test('validateDraftPayload rejects invalid formulation type', () {
      final payload = {
        'product_id': 'prod-001',
        'formulation_type': 'TABLET',
        'administration_route': 'TOPICAL_CUTANEOUS',
        'container_type': 'TUBE_ALUMINUM',
        'net_weight_grams': 15.0,
        'concentration_value': 1.0,
      };

      final res = MobileTopicalEditorClient.validateDraftPayload(payload);
      expect(res.isValid, isFalse);
      expect(res.errorCode, equals('ERR_INVALID_FORMULATION_TYPE'));
    });

    test('validateDraftPayload rejects invalid administration route', () {
      final payload = {
        'product_id': 'prod-001',
        'formulation_type': 'OINTMENT',
        'administration_route': 'INTRAVENOUS',
        'container_type': 'TUBE_ALUMINUM',
        'net_weight_grams': 15.0,
        'concentration_value': 1.0,
      };

      final res = MobileTopicalEditorClient.validateDraftPayload(payload);
      expect(res.isValid, isFalse);
      expect(res.errorCode, equals('ERR_INVALID_TOPICAL_ROUTE'));
    });

    test('validateDraftPayload rejects non-positive net weight', () {
      final payload = {
        'product_id': 'prod-001',
        'formulation_type': 'CREAM',
        'administration_route': 'TOPICAL_CUTANEOUS',
        'container_type': 'TUBE_ALUMINUM',
        'net_weight_grams': 0.0,
        'concentration_value': 1.0,
      };

      final res = MobileTopicalEditorClient.validateDraftPayload(payload);
      expect(res.isValid, isFalse);
      expect(res.errorCode, equals('ERR_INVALID_NET_WEIGHT'));
    });

    test('validateDraftPayload enforces ophthalmic sterility mandate', () {
      final payloadNonSterile = {
        'product_id': 'prod-001',
        'formulation_type': 'OINTMENT',
        'administration_route': 'TOPICAL_OPHTHALMIC',
        'container_type': 'TUBE_ALUMINUM',
        'net_weight_grams': 3.5,
        'concentration_value': 0.5,
        'is_sterile': false,
        'opened_shelf_life_days': 28,
      };
      final resNonSterile = MobileTopicalEditorClient.validateDraftPayload(payloadNonSterile);
      expect(resNonSterile.isValid, isFalse);
      expect(resNonSterile.errorCode, equals('ERR_OPHTHALMIC_STERILITY_MANDATORY'));

      final payloadSterile = {
        'product_id': 'prod-001',
        'formulation_type': 'OINTMENT',
        'administration_route': 'TOPICAL_OPHTHALMIC',
        'container_type': 'TUBE_ALUMINUM',
        'net_weight_grams': 3.5,
        'concentration_value': 0.5,
        'is_sterile': true,
        'opened_shelf_life_days': 28,
      };
      final resSterile = MobileTopicalEditorClient.validateDraftPayload(payloadSterile);
      expect(resSterile.isValid, isTrue);
    });

    test('validateDraftPayload rejects ophthalmic opened shelf life > 28 days', () {
      final payload = {
        'product_id': 'prod-001',
        'formulation_type': 'OINTMENT',
        'administration_route': 'TOPICAL_OPHTHALMIC',
        'container_type': 'TUBE_ALUMINUM',
        'net_weight_grams': 3.5,
        'concentration_value': 0.5,
        'is_sterile': true,
        'opened_shelf_life_days': 60,
      };
      final res = MobileTopicalEditorClient.validateDraftPayload(payload);
      expect(res.isValid, isFalse);
      expect(res.errorCode, equals('ERR_INVALID_OPENED_SHELF_LIFE'));
    });

    test('MobileTopicalRecord serialization and deserialization', () {
      final jsonMap = {
        'config_id': 'cfg-topical-001',
        'product_id': 'prod-001',
        'tenant_id': 'tenant-test',
        'formulation_type': 'CREAM',
        'administration_route': 'TOPICAL_CUTANEOUS',
        'container_type': 'TUBE_ALUMINUM',
        'net_weight_grams': 15.0,
        'concentration_value': 1.0,
        'concentration_unit': 'PERCENT_W_W',
        'is_sterile': false,
        'applicator_included': false,
        'opened_shelf_life_days': 28,
        'storage_condition': 'ROOM_15_25',
        'patient_instructions_en': 'Apply thin layer',
        'patient_instructions_bn': 'পাতলা প্রলেপ দিন',
        'is_active': true,
      };

      final record = MobileTopicalRecord.fromJson(jsonMap);
      expect(record.configId, equals('cfg-topical-001'));
      expect(record.netWeightGrams, equals(15.0));
      expect(record.concentrationValue, equals(1.0));
      expect(record.formulationType, equals('CREAM'));

      final outJson = record.toJson();
      expect(outJson['formulation_type'], equals('CREAM'));
      expect(outJson['net_weight_grams'], equals('15.00'));
      expect(outJson['container_type'], equals('TUBE_ALUMINUM'));
    });
  });
}

