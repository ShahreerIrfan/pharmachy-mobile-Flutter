// test/core/catalog/mobile_inhaler_editor_client_test.dart
// Unit tests for MobileInhalerEditorClient (P146)

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/catalog/mobile_inhaler_editor_client.dart';

void main() {
  group('MobileInhalerEditorClient Tests', () {
    test('validateDraftPayload accepts valid pressurized MDI inhaler', () {
      final payload = {
        'product_id': 'prod-001',
        'device_type': 'MDI_PRESSURIZED',
        'administration_route': 'ORAL_INHALATION',
        'dose_per_actuation': 100.0,
        'dose_unit': 'MCG',
        'total_actuations': 200,
        'total_active_content': 20000.0,
        'has_dose_counter': true,
        'storage_condition': 'ROOM_15_25',
      };

      final res = MobileInhalerEditorClient.validateDraftPayload(payload);
      expect(res.isValid, isTrue);
      expect(res.errorCode, isNull);
    });

    test('validateDraftPayload rejects solid oral packaging attributes', () {
      final payload = {
        'product_id': 'prod-001',
        'device_type': 'MDI_PRESSURIZED',
        'administration_route': 'ORAL_INHALATION',
        'dose_per_actuation': 100.0,
        'total_actuations': 200,
        'strips_per_box': 5, // Prohibited solid field
      };

      final res = MobileInhalerEditorClient.validateDraftPayload(payload);
      expect(res.isValid, isFalse);
      expect(res.errorCode, equals('ERR_HIDDEN_FIELD_VALUE_REJECTED'));
    });

    test('validateDraftPayload rejects needle gauge field', () {
      final payload = {
        'product_id': 'prod-001',
        'device_type': 'DPI_DRY_POWDER',
        'administration_route': 'ORAL_INHALATION',
        'dose_per_actuation': 50.0,
        'total_actuations': 60,
        'needle_gauge': '30G', // Prohibited injectable field
      };

      final res = MobileInhalerEditorClient.validateDraftPayload(payload);
      expect(res.isValid, isFalse);
      expect(res.errorCode, equals('ERR_HIDDEN_FIELD_VALUE_REJECTED'));
    });

    test('validateDraftPayload rejects invalid device type', () {
      final payload = {
        'product_id': 'prod-001',
        'device_type': 'INJECTION_PEN',
        'administration_route': 'ORAL_INHALATION',
        'dose_per_actuation': 100.0,
        'total_actuations': 200,
      };

      final res = MobileInhalerEditorClient.validateDraftPayload(payload);
      expect(res.isValid, isFalse);
      expect(res.errorCode, equals('ERR_INVALID_DEVICE_TYPE'));
    });

    test('validateDraftPayload rejects invalid administration route', () {
      final payload = {
        'product_id': 'prod-001',
        'device_type': 'MDI_PRESSURIZED',
        'administration_route': 'INTRAVENOUS',
        'dose_per_actuation': 100.0,
        'total_actuations': 200,
      };

      final res = MobileInhalerEditorClient.validateDraftPayload(payload);
      expect(res.isValid, isFalse);
      expect(res.errorCode, equals('ERR_INVALID_ADMINISTRATION_ROUTE'));
    });

    test('validateDraftPayload rejects non-positive dose per actuation', () {
      final payload = {
        'product_id': 'prod-001',
        'device_type': 'MDI_PRESSURIZED',
        'administration_route': 'ORAL_INHALATION',
        'dose_per_actuation': 0.0,
        'total_actuations': 200,
      };

      final res = MobileInhalerEditorClient.validateDraftPayload(payload);
      expect(res.isValid, isFalse);
      expect(res.errorCode, equals('ERR_INVALID_DOSE_PER_ACTUATION'));
    });

    test('validateDraftPayload rejects out-of-range actuations (< 10 or > 1000)', () {
      final payloadLow = {
        'product_id': 'prod-001',
        'device_type': 'MDI_PRESSURIZED',
        'administration_route': 'ORAL_INHALATION',
        'dose_per_actuation': 100.0,
        'total_actuations': 4,
      };
      expect(MobileInhalerEditorClient.validateDraftPayload(payloadLow).errorCode, equals('ERR_INVALID_ACTUATIONS_COUNT'));

      final payloadHigh = {
        'product_id': 'prod-001',
        'device_type': 'MDI_PRESSURIZED',
        'administration_route': 'ORAL_INHALATION',
        'dose_per_actuation': 100.0,
        'total_actuations': 1200,
      };
      expect(MobileInhalerEditorClient.validateDraftPayload(payloadHigh).errorCode, equals('ERR_INVALID_ACTUATIONS_COUNT'));
    });

    test('validateDraftPayload rejects dimension consistency mismatch', () {
      final payload = {
        'product_id': 'prod-001',
        'device_type': 'MDI_PRESSURIZED',
        'administration_route': 'ORAL_INHALATION',
        'dose_per_actuation': 100.0,
        'total_actuations': 200,
        'total_active_content': 25000.0, // 100 * 200 = 20000 != 25000
      };

      final res = MobileInhalerEditorClient.validateDraftPayload(payload);
      expect(res.isValid, isFalse);
      expect(res.errorCode, equals('ERR_DIMENSION_CONSISTENCY_MISMATCH'));
    });

    test('MobileInhalerRecord serialization and deserialization', () {
      final jsonMap = {
        'config_id': 'cfg-001',
        'product_id': 'prod-001',
        'tenant_id': 'tenant-test',
        'device_type': 'MDI_PRESSURIZED',
        'administration_route': 'ORAL_INHALATION',
        'dose_per_actuation': 100.0,
        'dose_unit': 'MCG',
        'total_actuations': 200,
        'total_active_content': 20000.0,
        'has_dose_counter': true,
        'has_spacer_included': false,
        'storage_condition': 'ROOM_15_25',
        'priming_required': true,
        'priming_puffs': 2,
        'canister_pressure_warning': true,
        'patient_instructions_en': 'Inhale 1 puff',
        'patient_instructions_bn': '১ পাফ ইনহেল করুন',
        'is_active': true,
      };

      final record = MobileInhalerRecord.fromJson(jsonMap);
      expect(record.configId, equals('cfg-001'));
      expect(record.dosePerActuation, equals(100.0));
      expect(record.totalActuations, equals(200));
      expect(record.hasDoseCounter, isTrue);

      final outJson = record.toJson();
      expect(outJson['device_type'], equals('MDI_PRESSURIZED'));
      expect(outJson['dose_unit'], equals('MCG'));
      expect(outJson['total_actuations'], equals(200));
    });
  });
}

